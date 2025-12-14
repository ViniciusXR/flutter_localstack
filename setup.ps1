# Script de Setup Automático - LocalStack + Backend
# Execute com: .\setup.ps1

Write-Host "🚀 Iniciando configuração do ambiente LocalStack..." -ForegroundColor Cyan
Write-Host ""

# Verificar Docker
Write-Host "1️⃣ Verificando Docker..." -ForegroundColor Yellow
try {
    docker --version | Out-Null
    Write-Host "✅ Docker encontrado" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker não encontrado. Instale o Docker Desktop primeiro." -ForegroundColor Red
    exit 1
}

# Verificar se Docker está rodando
$dockerRunning = docker ps 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Docker não está rodando. Inicie o Docker Desktop." -ForegroundColor Red
    exit 1
}
Write-Host "✅ Docker está rodando" -ForegroundColor Green
Write-Host ""

# Verificar Node.js
Write-Host "2️⃣ Verificando Node.js..." -ForegroundColor Yellow
try {
    node --version | Out-Null
    Write-Host "✅ Node.js encontrado" -ForegroundColor Green
} catch {
    Write-Host "❌ Node.js não encontrado. Instale o Node.js primeiro." -ForegroundColor Red
    exit 1
}
Write-Host ""

# Verificar AWS CLI
Write-Host "3️⃣ Verificando AWS CLI..." -ForegroundColor Yellow
try {
    aws --version | Out-Null
    Write-Host "✅ AWS CLI encontrado" -ForegroundColor Green
} catch {
    Write-Host "⚠️ AWS CLI não encontrado. Instale para validar recursos." -ForegroundColor Yellow
    Write-Host "   Comando: choco install awscli" -ForegroundColor Gray
}
Write-Host ""

# Verificar awslocal
Write-Host "4️⃣ Verificando awslocal..." -ForegroundColor Yellow
try {
    awslocal --version 2>&1 | Out-Null
    Write-Host "✅ awslocal encontrado" -ForegroundColor Green
} catch {
    Write-Host "⚠️ awslocal não encontrado. Instalando..." -ForegroundColor Yellow
    try {
        pip install awscli-local
        Write-Host "✅ awslocal instalado" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Não foi possível instalar awslocal. Instale manualmente: pip install awscli-local" -ForegroundColor Yellow
    }
}
Write-Host ""

# Parar containers existentes
Write-Host "5️⃣ Parando containers existentes..." -ForegroundColor Yellow
docker-compose down 2>&1 | Out-Null
Write-Host "✅ Containers parados" -ForegroundColor Green
Write-Host ""

# Subir LocalStack
Write-Host "6️⃣ Iniciando LocalStack..." -ForegroundColor Yellow
docker-compose up -d localstack

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ LocalStack iniciado" -ForegroundColor Green
} else {
    Write-Host "❌ Erro ao iniciar LocalStack" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Aguardar LocalStack ficar pronto
Write-Host "7️⃣ Aguardando LocalStack ficar pronto..." -ForegroundColor Yellow
$maxAttempts = 30
$attempt = 0
$ready = $false

while (-not $ready -and $attempt -lt $maxAttempts) {
    $attempt++
    Write-Host "   Tentativa $attempt/$maxAttempts..." -ForegroundColor Gray
    
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:4566/health" -TimeoutSec 2 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            $ready = $true
            Write-Host "✅ LocalStack pronto!" -ForegroundColor Green
        }
    } catch {
        Start-Sleep -Seconds 2
    }
}

if (-not $ready) {
    Write-Host "⚠️ LocalStack demorou para ficar pronto. Continuando..." -ForegroundColor Yellow
}
Write-Host ""

# Verificar recursos criados
Write-Host "8️⃣ Verificando recursos AWS criados..." -ForegroundColor Yellow
try {
    Write-Host "   Buckets S3:" -ForegroundColor Gray
    awslocal s3 ls
    
    Write-Host ""
    Write-Host "   Tabelas DynamoDB:" -ForegroundColor Gray
    awslocal dynamodb list-tables
    
    Write-Host ""
    Write-Host "   Filas SQS:" -ForegroundColor Gray
    awslocal sqs list-queues
    
    Write-Host "✅ Recursos verificados" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Não foi possível verificar recursos. Verifique manualmente." -ForegroundColor Yellow
}
Write-Host ""

# Instalar dependências do backend
Write-Host "9️⃣ Instalando dependências do backend..." -ForegroundColor Yellow
Push-Location backend
if (Test-Path "node_modules") {
    Write-Host "   node_modules já existe, pulando..." -ForegroundColor Gray
} else {
    npm install
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Dependências instaladas" -ForegroundColor Green
    } else {
        Write-Host "❌ Erro ao instalar dependências" -ForegroundColor Red
        Pop-Location
        exit 1
    }
}
Pop-Location
Write-Host ""

# Copiar .env.example para .env
Write-Host "🔟 Configurando variáveis de ambiente..." -ForegroundColor Yellow
if (-not (Test-Path "backend\.env")) {
    Copy-Item "backend\.env.example" "backend\.env"
    Write-Host "✅ Arquivo .env criado" -ForegroundColor Green
} else {
    Write-Host "   .env já existe" -ForegroundColor Gray
}
Write-Host ""

# Obter IP local
Write-Host "📡 Descobrindo IP local para configurar o app Flutter..." -ForegroundColor Yellow
$localIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notlike "*Loopback*" -and $_.InterfaceAlias -notlike "*VirtualBox*" -and $_.InterfaceAlias -notlike "*VMware*"} | Select-Object -First 1).IPAddress

if ($localIP) {
    Write-Host "   Seu IP local: $localIP" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   📝 Configure o cloud_service.dart:" -ForegroundColor Yellow
    Write-Host "   - Emulador Android: http://10.0.2.2:3000" -ForegroundColor Gray
    Write-Host "   - Simulador iOS: http://localhost:3000" -ForegroundColor Gray
    Write-Host "   - Dispositivo físico: http://${localIP}:3000" -ForegroundColor Gray
}
Write-Host ""

# Resumo
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✨ Setup concluído com sucesso!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "🎯 Próximos passos:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Iniciar o backend:" -ForegroundColor White
Write-Host "   cd backend" -ForegroundColor Gray
Write-Host "   npm start" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Configurar o app Flutter:" -ForegroundColor White
Write-Host "   Edite: lib\services\cloud_service.dart" -ForegroundColor Gray
Write-Host "   Ajuste o baseUrl conforme seu dispositivo" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Executar o app:" -ForegroundColor White
Write-Host "   flutter run" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Validar recursos:" -ForegroundColor White
Write-Host "   awslocal s3 ls s3://shopping-images --recursive" -ForegroundColor Gray
Write-Host "   awslocal dynamodb scan --table-name ShoppingTasks" -ForegroundColor Gray
Write-Host ""
Write-Host "📚 Documentação completa: LOCALSTACK_SETUP.md" -ForegroundColor Cyan
Write-Host "⚡ Comandos úteis: COMANDOS_WINDOWS.md" -ForegroundColor Cyan
Write-Host "🚀 Quick Start: README_QUICKSTART.md" -ForegroundColor Cyan
Write-Host ""
