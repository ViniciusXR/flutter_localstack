const express = require('express');
const multer = require('multer');
const { S3Client, PutObjectCommand, ListObjectsV2Command } = require('@aws-sdk/client-s3');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand, ScanCommand } = require('@aws-sdk/lib-dynamodb');
const { SQSClient, SendMessageCommand } = require('@aws-sdk/client-sqs');
const { SNSClient, PublishCommand } = require('@aws-sdk/client-sns');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Configurar AWS SDK v3 para usar LocalStack
const awsConfig = {
  endpoint: process.env.AWS_ENDPOINT || 'http://localhost:4566',
  region: process.env.AWS_REGION || 'us-east-1',
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'test',
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || 'test',
  },
  forcePathStyle: true, // Necessário para LocalStack
};

// URL pública do LocalStack para retornar nas respostas
// (diferente do endpoint interno usado pelo backend)
const PUBLIC_LOCALSTACK_URL = process.env.PUBLIC_LOCALSTACK_URL || 'http://10.0.2.2:4566';

const s3Client = new S3Client(awsConfig);
const dynamoDBClient = new DynamoDBClient(awsConfig);
const docClient = DynamoDBDocumentClient.from(dynamoDBClient);
const sqsClient = new SQSClient(awsConfig);
const snsClient = new SNSClient(awsConfig);

const BUCKET_NAME = 'shopping-images';
const SQS_QUEUE_URL = process.env.SQS_QUEUE_URL || 'http://localhost:4566/000000000000/shopping-tasks-queue';
const SNS_TOPIC_ARN = process.env.SNS_TOPIC_ARN || 'arn:aws:sns:us-east-1:000000000000:shopping-notifications';
const DYNAMODB_TABLE = 'ShoppingTasks';

// Configurar multer para processar upload de arquivos
const storage = multer.memoryStorage();
const upload = multer({ storage: storage });

// Endpoint de health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', message: 'Backend is running' });
});

// Endpoint para upload de imagem (Base64)
app.post('/api/upload/base64', async (req, res) => {
  try {
    const { imageBase64, taskId, fileName } = req.body;

    if (!imageBase64) {
      return res.status(400).json({ error: 'Image data is required' });
    }

    // Remover o prefixo data:image/...;base64, se existir
    const base64Data = imageBase64.replace(/^data:image\/\w+;base64,/, '');
    const buffer = Buffer.from(base64Data, 'base64');

    // Gerar nome único para o arquivo
    const fileKey = `images/${taskId || uuidv4()}/${fileName || Date.now()}.jpg`;

    // Upload para S3
    const command = new PutObjectCommand({
      Bucket: BUCKET_NAME,
      Key: fileKey,
      Body: buffer,
      ContentType: 'image/jpeg',
      ACL: 'public-read'
    });

    await s3Client.send(command);
    const imageUrl = `${awsConfig.endpoint}/${BUCKET_NAME}/${fileKey}`;

    res.json({
      success: true,
      message: 'Image uploaded successfully',
      imageUrl: imageUrl,
      key: fileKey
    });

  } catch (error) {
    console.error('Error uploading image:', error);
    res.status(500).json({ error: 'Failed to upload image', details: error.message });
  }
});

// Endpoint para upload de imagem (Multipart)
app.post('/api/upload/multipart', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    const { taskId } = req.body;
    const fileKey = `images/${taskId || uuidv4()}/${Date.now()}_${req.file.originalname}`;

    // Upload para S3
    const command = new PutObjectCommand({
      Bucket: BUCKET_NAME,
      Key: fileKey,
      Body: req.file.buffer,
      ContentType: req.file.mimetype,
      ACL: 'public-read'
    });

    await s3Client.send(command);
    const imageUrl = `${PUBLIC_LOCALSTACK_URL}/${BUCKET_NAME}/${fileKey}`;

    res.json({
      success: true,
      message: 'Image uploaded successfully',
      imageUrl: imageUrl,
      key: fileKey
    });

  } catch (error) {
    console.error('Error uploading image:', error);
    res.status(500).json({ error: 'Failed to upload image', details: error.message });
  }
});

// Endpoint para salvar tarefa completa (com imagem, SQS, SNS e DynamoDB)
app.post('/api/tasks', async (req, res) => {
  try {
    const { id, title, description, imageBase64, location, createdAt } = req.body;

    let imageUrl = null;

    // 1. Upload da imagem para S3 (se fornecida)
    if (imageBase64) {
      const base64Data = imageBase64.replace(/^data:image\/\w+;base64,/, '');
      const buffer = Buffer.from(base64Data, 'base64');
      const fileKey = `images/${id}/${Date.now()}.jpg`;

      const command = new PutObjectCommand({
        Bucket: BUCKET_NAME,
        Key: fileKey,
        Body: buffer,
        ContentType: 'image/jpeg',
        ACL: 'public-read'
      });

      await s3Client.send(command);
      imageUrl = `${PUBLIC_LOCALSTACK_URL}/${BUCKET_NAME}/${fileKey}`;
    }

    // 2. Salvar no DynamoDB
    const taskData = {
      id,
      title,
      description,
      imageUrl,
      location,
      createdAt: createdAt || Date.now(),
      updatedAt: Date.now()
    };

    await docClient.send(new PutCommand({
      TableName: DYNAMODB_TABLE,
      Item: taskData
    }));

    // 3. Enviar mensagem para SQS
    await sqsClient.send(new SendMessageCommand({
      QueueUrl: SQS_QUEUE_URL,
      MessageBody: JSON.stringify({
        action: 'task_created',
        taskId: id,
        timestamp: Date.now()
      })
    }));

    // 4. Publicar notificação no SNS
    await snsClient.send(new PublishCommand({
      TopicArn: SNS_TOPIC_ARN,
      Message: JSON.stringify({
        event: 'task_created',
        taskId: id,
        title,
        timestamp: Date.now()
      }),
      Subject: 'Nova tarefa criada'
    }));

    res.json({
      success: true,
      message: 'Task saved successfully',
      task: taskData
    });

  } catch (error) {
    console.error('Error saving task:', error);
    res.status(500).json({ error: 'Failed to save task', details: error.message });
  }
});

// Endpoint para listar tarefas do DynamoDB
app.get('/api/tasks', async (req, res) => {
  try {
    const result = await docClient.send(new ScanCommand({
      TableName: DYNAMODB_TABLE
    }));

    res.json({
      success: true,
      tasks: result.Items || []
    });

  } catch (error) {
    console.error('Error fetching tasks:', error);
    res.status(500).json({ error: 'Failed to fetch tasks', details: error.message });
  }
});

// Endpoint para listar imagens do S3
app.get('/api/images', async (req, res) => {
  try {
    const command = new ListObjectsV2Command({
      Bucket: BUCKET_NAME
    });

    const result = await s3Client.send(command);

    // Construir URLs completas para as imagens usando a URL pública
    // (10.0.2.2 para emulador Android acessar o host)
    const imagesWithUrls = (result.Contents || []).map(item => ({
      ...item,
      url: `${PUBLIC_LOCALSTACK_URL}/${BUCKET_NAME}/${item.Key}`
    }));

    res.json({
      success: true,
      images: imagesWithUrls
    });

  } catch (error) {
    console.error('Error listing images:', error);
    res.status(500).json({ error: 'Failed to list images', details: error.message });
  }
});

// Iniciar servidor
app.listen(PORT, () => {
  console.log(`🚀 Backend server running on port ${PORT}`);
  console.log(`📍 Health check: http://localhost:${PORT}/health`);
  console.log(`☁️  AWS Endpoint: ${awsConfig.endpoint}`);
  console.log(`✨ Using AWS SDK v3`);
});
