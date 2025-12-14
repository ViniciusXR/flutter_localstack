# Flutter LocalStack - Cloud Simulation App

Aplicativo Flutter que demonstra integração com serviços AWS simulados localmente usando LocalStack. O projeto inclui armazenamento dual (SQLite local + LocalStack na nuvem) para tarefas, com interface de abas para gerenciar ambos os destinos.

## 🎯 Objetivo

Demonstrar armazenamento híbrido local/nuvem com:
- 💾 **SQLite**: Armazenamento local no dispositivo
- ☁️ **LocalStack**: Simulação completa de serviços AWS
  - S3 para armazenamento de fotos
  - DynamoDB para dados de tarefas
  - SQS para processamento de filas
  - SNS para notificações pub/sub

## ✨ Funcionalidades

### Interface do App
- 📑 **Dual Tabs**: Alterne entre tarefas locais (SQLite) e tarefas na nuvem (LocalStack)
- 🎯 **Seletor de Destino**: Escolha onde salvar ao criar tarefas (SQLite ou LocalStack)
- 📊 **Estatísticas**: Visualize total, pendentes e concluídas em cada aba
- 🎨 **Visual Consistente**: Mesmo design para ambas as abas (gradientes azul/laranja)

### Backend & Cloud
- 📸 Upload de fotos para S3
- 💾 Persistência de dados no DynamoDB
- 📨 Mensageria assíncrona com SQS
- 🔔 Notificações pub/sub com SNS
- 🌐 Backend RESTful com Node.js/Express (containerizado)
- 🐳 Orquestração completa com Docker Compose

## 🚀 Quick Start

### Pré-requisitos

- ✅ Docker Desktop instalado e rodando
- ✅ Flutter SDK instalado
- ✅ PowerShell (Windows)

### Iniciar o Projeto (1 comando!)

```powershell
# Subir LocalStack + Backend + Criar recursos AWS automaticamente
docker-compose up -d
```

Aguarde ~10 segundos para os containers ficarem prontos.

### Verificar Status

```powershell
docker-compose ps
```

Saída esperada:
```
NAME              IMAGE                         STATUS
flutter-backend   flutter_localstack-backend    Up
localstack-main   localstack/localstack:latest  Up (healthy)
localstack-init   localstack/localstack:latest  Exited (0)
```

### Ver Recursos Criados

```powershell
docker logs localstack-init
```

Deve mostrar:
- ✅ Bucket S3: `shopping-images`
- ✅ Tabela DynamoDB: `ShoppingTasks`  
- ✅ Fila SQS: `shopping-tasks-queue`
- ✅ Tópico SNS: `shopping-notifications`

### Executar o App Flutter

```powershell
flutter run
```

**Pronto!** O app já está conectado ao backend rodando em Docker. 🎉

## 📁 Estrutura do Projeto

```
flutter_localstack/
├── lib/
│   ├── main.dart                               # App principal
│   ├── screens/
│   │   ├── task_list_screen.dart              # Lista com abas SQLite/LocalStack
│   │   ├── task_form_screen.dart              # Formulário com seletor de destino
│   │   ├── cloud_upload_example.dart          # Upload direto para S3
│   │   └── localstack_viewer_screen.dart      # Visualizador de imagens S3
│   ├── services/
│   │   ├── cloud_service.dart                 # Cliente HTTP para backend
│   │   └── database_service.dart              # SQLite local
│   ├── models/
│   │   └── task.dart                          # Modelo de dados
│   └── widgets/
│       └── task_card.dart                     # Card de tarefa
├── backend/
│   ├── server.js                              # API REST Express
│   ├── package.json                           # Dependências Node.js
│   └── Dockerfile                             # Imagem Docker do backend
├── docker-compose.yml                         # Orquestração completa
|
└── README.md                                  # Este arquivo
```

## 🔧 Arquitetura

### Docker Compose Services

O `docker-compose.yml` gerencia 3 containers:

1. **localstack** - LocalStack Community Edition
   - Porta: 4566
   - Serviços: S3, DynamoDB, SQS, SNS
   - Health check automático

2. **backend** - Node.js/Express API
   - Porta: 3000
   - Aguarda LocalStack ficar healthy antes de iniciar
   - Variáveis de ambiente pré-configuradas

3. **init-resources** - Inicialização automática
   - Cria bucket S3, tabela DynamoDB, fila SQS, tópico SNS
   - Executa uma vez e para
   - Logs disponíveis via `docker logs localstack-init`

### Fluxo de Dados

```
Flutter App (Mobile)
    ↓
    ↓ HTTP (10.0.2.2:3000)
    ↓
Backend Node.js (Docker)
    ↓
    ↓ AWS SDK (localstack:4566)
    ↓
LocalStack (Docker)
    ├── S3 (imagens)
    ├── DynamoDB (tarefas)
    ├── SQS (mensagens)
    └── SNS (notificações)
```

## 🎯 Como Usar o App

### 1. Visualizar Tarefas

O app possui **duas abas**:

- **SQLite (Local)** 📱
  - Cor azul
  - Dados armazenados no dispositivo
  - Funciona offline
  - Sincronização manual com backend

- **LocalStack (Nuvem)** ☁️
  - Cor laranja
  - Dados no DynamoDB (LocalStack)
  - Requer conexão com backend
  - Imagens armazenadas no S3

### 2. Criar Nova Tarefa

1. Clique no botão **+** (FloatingActionButton)
2. Preencha título e descrição
3. (Opcional) Adicione fotos
4. (Opcional) Capture localização GPS
5. **Escolha o destino**:
   - 📱 SQLite: Salva localmente
   - ☁️ LocalStack: Salva na nuvem simulada
6. Clique em "Salvar"

### 3. Visualizar Imagens do S3

- Acesse a tela "LocalStack Viewer"
- Veja todas as imagens do bucket `shopping-images`
- URLs acessíveis do emulador Android: `http://10.0.2.2:4566/...`

## 🧪 Endpoints do Backend

### Health Check
```bash
curl http://localhost:3000/health
# Resposta: {"status":"ok","message":"Backend is running"}
```

### Listar Imagens do S3
```bash
curl http://localhost:3000/api/images
# Resposta: {"success":true,"images":[...]}
```

### Listar Tarefas do DynamoDB
```bash
curl http://localhost:3000/api/tasks
# Resposta: {"success":true,"tasks":[...]}
```

### Salvar Tarefa Completa
```bash
curl -X POST http://localhost:3000/api/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Teste",
    "description": "Descrição teste",
    "imageBase64": "..."
  }'
```

## 📚 Comandos Úteis

### Docker & LocalStack

```powershell
# Ver logs em tempo real
docker-compose logs -f

# Logs apenas do LocalStack
docker-compose logs -f localstack

# Logs apenas do backend
docker-compose logs -f backend

# Ver logs da inicialização
docker logs localstack-init

# Parar tudo
docker-compose down

# Parar e limpar volumes (reseta dados)
docker-compose down -v

# Reiniciar apenas um serviço
docker-compose restart backend

# Rebuild do backend após mudanças no código
docker-compose up -d --build backend
```

### Validar Recursos AWS (dentro do container)

```powershell
# Listar buckets S3
docker exec localstack-main awslocal s3 ls

# Listar objetos no bucket
docker exec localstack-main awslocal s3 ls s3://shopping-images --recursive

# Listar tabelas DynamoDB
docker exec localstack-main awslocal dynamodb list-tables

# Escanear dados da tabela
docker exec localstack-main awslocal dynamodb scan --table-name ShoppingTasks

# Listar filas SQS
docker exec localstack-main awslocal sqs list-queues

# Listar tópicos SNS
docker exec localstack-main awslocal sns list-topics
```

## 🔍 Troubleshooting

### Containers não sobem
```powershell
# Verificar se Docker Desktop está rodando
docker ps

# Ver logs de erro
docker-compose logs

# Limpar e recriar
docker-compose down -v
docker-compose up -d
```

### LocalStack não fica healthy
```powershell
# Ver logs do LocalStack
docker logs localstack-main

# Testar health check manualmente
docker exec localstack-main curl -f http://localhost:4566/_localstack/health
```

### Backend não conecta ao LocalStack
```powershell
# Verificar se LocalStack está healthy
docker-compose ps

# Testar conectividade do backend para LocalStack
docker exec flutter-backend curl http://localstack:4566/_localstack/health

# Verificar logs do backend
docker logs flutter-backend
```

### Recursos AWS não foram criados
```powershell
# Verificar se init-resources executou com sucesso
docker logs localstack-init

# Recriar recursos manualmente (se necessário)
docker exec localstack-main awslocal s3 mb s3://shopping-images
docker exec localstack-main awslocal dynamodb create-table \
  --table-name ShoppingTasks \
  --attribute-definitions AttributeName=id,AttributeType=S AttributeName=createdAt,AttributeType=N \
  --key-schema AttributeName=id,KeyType=HASH AttributeName=createdAt,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST
```

### App Flutter não conecta ao backend
```powershell
# 1. Verificar se backend está respondendo
curl http://localhost:3000/health

# 2. Verificar configuração no app
# lib/services/cloud_service.dart deve ter:
# static const String baseUrl = 'http://10.0.2.2:3000'; (Android Emulator)
# static const String baseUrl = 'http://localhost:3000'; (iOS Simulator)

# 3. Testar do host
curl http://10.0.2.2:3000/health
```

### Imagens não carregam no app
```powershell
# Verificar se bucket existe
docker exec localstack-main awslocal s3 ls

# Verificar se PUBLIC_LOCALSTACK_URL está correto
docker exec flutter-backend printenv PUBLIC_LOCALSTACK_URL
# Deve retornar: http://10.0.2.2:4566

# Listar imagens no bucket
docker exec localstack-main awslocal s3 ls s3://shopping-images --recursive
```

### Portas em uso
```powershell
# Verificar o que está usando a porta 3000
Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue

# Verificar o que está usando a porta 4566
Get-NetTCPConnection -LocalPort 4566 -ErrorAction SilentlyContinue

# Parar outros containers se necessário
docker stop $(docker ps -q)
```

## 🛠️ Tecnologias Utilizadas

### Frontend (Flutter)
- **Flutter SDK**: Framework multiplataforma
- **http**: Cliente HTTP para API REST
- **sqflite**: Banco de dados SQLite local
- **image_picker**: Captura de fotos
- **geolocator**: Localização GPS
- **shared_preferences**: Armazenamento local de preferências

### Backend (Node.js)
- **Express**: Framework web
- **@aws-sdk/client-s3**: Cliente S3
- **@aws-sdk/client-dynamodb**: Cliente DynamoDB
- **@aws-sdk/client-sqs**: Cliente SQS
- **@aws-sdk/client-sns**: Cliente SNS
- **multer**: Upload de arquivos multipart
- **cors**: Cross-Origin Resource Sharing

### DevOps
- **Docker**: Containerização
- **Docker Compose**: Orquestração multi-container
- **LocalStack**: Emulador de serviços AWS
- **PowerShell**: Scripts de automação


## ⚡ Performance Tips

### Otimizações Recomendadas

1. **Docker Desktop**
   - Alocar ao menos 4GB RAM
   - Habilitar WSL 2 backend (Windows)
   - Usar volumes named ao invés de bind mounts para melhor performance

2. **LocalStack**
   - Desabilitar serviços não utilizados em `SERVICES`
   - Usar `DEBUG=0` em produção
   - Considerar LocalStack Pro para performance melhorada

3. **Flutter App**
   - Implementar cache de imagens
   - Usar pagination para listas grandes
   - Comprimir imagens antes do upload
   - Implementar retry logic com exponential backoff

---

**🌟 Desenvolvido para demonstração de integração Flutter com serviços AWS usando LocalStack** ☁️

**Stack**: Flutter + Node.js + LocalStack + Docker + AWS SDK
