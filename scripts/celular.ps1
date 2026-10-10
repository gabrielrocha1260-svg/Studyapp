# Sobe o servidor do STUDY e o túnel do ngrok (Caminho A, uso pessoal).
# Uso: .\scripts\celular.ps1 [-Domain seu-dominio.ngrok-free.app] [-Port 3000]
# O domínio também pode vir de NGROK_DOMAIN (variável de ambiente ou .env).
param(
  [string]$Domain = $env:NGROK_DOMAIN,
  [int]$Port = 0
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Get-DotEnv([string]$name) {
  if (-not (Test-Path ".env")) { return $null }
  $line = Get-Content ".env" | Where-Object { $_ -match "^\s*$name\s*=" } | Select-Object -Last 1
  if ($line) { return ($line -replace "^\s*$name\s*=\s*", "").Trim().Trim('"', "'") }
  return $null
}

if (-not $Domain) { $Domain = Get-DotEnv "NGROK_DOMAIN" }
if (-not $Port) { $p = Get-DotEnv "PORT"; $Port = if ($p) { [int]$p } else { 3000 } }
if (-not $Domain) { throw "Informe o domínio: -Domain seu-dominio.ngrok-free.app (ou NGROK_DOMAIN no .env)." }
$Domain = $Domain -replace "^https?://", "" -replace "/+$", ""
if (-not (Get-Command ngrok -ErrorAction SilentlyContinue)) { throw "ngrok não encontrado no PATH. Veja docs/ACESSO_CELULAR.md." }
if (-not (Test-Path "node_modules")) { npm ci --omit=dev }

# Atrás do ngrok: limite de requisições por IP real e CORS só para o domínio público.
$env:TRUST_PROXY = "1"
if (-not $env:ALLOWED_ORIGINS -and -not (Get-DotEnv "ALLOWED_ORIGINS")) { $env:ALLOWED_ORIGINS = "https://$Domain" }
$env:PORT = "$Port"

$server = Start-Process -FilePath "node" -ArgumentList "server.js" -NoNewWindow -PassThru
try {
  Start-Sleep -Seconds 2
  if ($server.HasExited) { throw "O servidor não subiu (veja as mensagens acima)." }
  Write-Host "STUDY no celular: https://$Domain/" -ForegroundColor Green
  ngrok http --url="$Domain" $Port
} finally {
  if (-not $server.HasExited) { Stop-Process -Id $server.Id -Force }
}
