# Script para facilitar comandos AWS no LocalStack
# Use: .\aws-local.ps1 s3 ls

param(
    [Parameter(Position=0, Mandatory=$true)]
    [string]$Service,
    
    [Parameter(Position=1, ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

# Configurar variáveis de ambiente
$env:AWS_ACCESS_KEY_ID = "test"
$env:AWS_SECRET_ACCESS_KEY = "test"
$env:AWS_DEFAULT_REGION = "us-east-1"
$env:HOME = $env:USERPROFILE

# Endpoint do LocalStack
$endpoint = "http://localhost:4566"

# Executar comando AWS CLI
$allArgs = @($Service) + $Arguments + @("--endpoint-url=$endpoint")
& aws @allArgs
