# Script para inicializar recursos AWS no LocalStack
# Execute após docker-compose up -d

Write-Host "🚀 Inicializando recursos AWS no LocalStack..." -ForegroundColor Cyan

# Aguardar LocalStack ficar pronto
Write-Host "`n⏳ Aguardando LocalStack ficar pronto..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

# 1. Criar bucket S3
Write-Host "`n📦 1. Criando bucket S3 'shopping-images'..." -ForegroundColor Green
docker exec localstack-main awslocal s3 mb s3://shopping-images 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ Bucket criado com sucesso!" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Bucket já existe ou erro ao criar" -ForegroundColor Yellow
}

# 2. Configurar ACL do bucket
Write-Host "`n🔓 2. Configurando ACL público para o bucket..." -ForegroundColor Green
docker exec localstack-main awslocal s3api put-bucket-acl --bucket shopping-images --acl public-read 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ ACL configurado com sucesso!" -ForegroundColor Green
}

# 3. Criar fila SQS
Write-Host "`n📬 3. Criando fila SQS 'shopping-tasks-queue'..." -ForegroundColor Green
$sqsResult = docker exec localstack-main awslocal sqs create-queue --queue-name shopping-tasks-queue 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ Fila criada com sucesso!" -ForegroundColor Green
    Write-Host "   $sqsResult" -ForegroundColor DarkGray
} else {
    Write-Host "   ⚠️  Fila já existe ou erro ao criar" -ForegroundColor Yellow
}

# 4. Criar tópico SNS
Write-Host "`n📢 4. Criando tópico SNS 'shopping-notifications'..." -ForegroundColor Green
$snsResult = docker exec localstack-main awslocal sns create-topic --name shopping-notifications 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ Tópico criado com sucesso!" -ForegroundColor Green
    Write-Host "   $snsResult" -ForegroundColor DarkGray
} else {
    Write-Host "   ⚠️  Tópico já existe ou erro ao criar" -ForegroundColor Yellow
}

# 5. Criar tabela DynamoDB
Write-Host "`n🗄️  5. Criando tabela DynamoDB 'ShoppingTasks'..." -ForegroundColor Green
docker exec localstack-main awslocal dynamodb create-table `
    --table-name ShoppingTasks `
    --attribute-definitions AttributeName=id,AttributeType=S AttributeName=createdAt,AttributeType=N `
    --key-schema AttributeName=id,KeyType=HASH AttributeName=createdAt,KeyType=RANGE `
    --billing-mode PAY_PER_REQUEST 2>$null | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ Tabela criada com sucesso!" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Tabela já existe ou erro ao criar" -ForegroundColor Yellow
}

# 6. Listar recursos criados
Write-Host "`n📋 6. Listando recursos criados..." -ForegroundColor Cyan

Write-Host "`n   Buckets S3:" -ForegroundColor White
docker exec localstack-main awslocal s3 ls

Write-Host "`n   Filas SQS:" -ForegroundColor White
docker exec localstack-main awslocal sqs list-queues

Write-Host "`n   Tópicos SNS:" -ForegroundColor White
docker exec localstack-main awslocal sns list-topics

Write-Host "`n   Tabelas DynamoDB:" -ForegroundColor White
docker exec localstack-main awslocal dynamodb list-tables

Write-Host "`n✨ Inicialização concluída!" -ForegroundColor Green
Write-Host "`n💡 Dica: Execute 'docker-compose logs -f' para ver os logs em tempo real`n" -ForegroundColor Yellow
