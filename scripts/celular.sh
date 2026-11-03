#!/usr/bin/env bash
# Sobe o servidor do STUDY e o túnel do ngrok (Caminho A, uso pessoal).
# Uso: ./scripts/celular.sh [seu-dominio.ngrok-free.app] [porta]
# O domínio também pode vir de NGROK_DOMAIN (variável de ambiente ou .env).
set -euo pipefail
cd "$(dirname "$0")/.."

dotenv_get() {
  [ -f .env ] || return 0
  grep -E "^[[:space:]]*$1[[:space:]]*=" .env | tail -n 1 | sed -E "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//; s/^[\"']//; s/[\"'][[:space:]]*$//; s/[[:space:]]+$//"
}

DOMAIN="${1:-${NGROK_DOMAIN:-$(dotenv_get NGROK_DOMAIN)}}"
PORT="${2:-${PORT:-$(dotenv_get PORT)}}"
PORT="${PORT:-3000}"
if [ -z "$DOMAIN" ]; then
  echo "Informe o domínio: ./scripts/celular.sh seu-dominio.ngrok-free.app (ou NGROK_DOMAIN no .env)." >&2
  exit 1
fi
DOMAIN="${DOMAIN#http://}"; DOMAIN="${DOMAIN#https://}"; DOMAIN="${DOMAIN%%/*}"
command -v ngrok >/dev/null || { echo "ngrok não encontrado no PATH. Veja docs/ACESSO_CELULAR.md." >&2; exit 1; }
[ -d node_modules ] || npm ci --omit=dev

# Atrás do ngrok: limite de requisições por IP real e CORS só para o domínio público.
export TRUST_PROXY=1
if [ -z "${ALLOWED_ORIGINS:-}" ] && [ -z "$(dotenv_get ALLOWED_ORIGINS)" ]; then export ALLOWED_ORIGINS="https://$DOMAIN"; fi
export PORT

node server.js &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT INT TERM
sleep 2
kill -0 "$SERVER_PID" 2>/dev/null || { echo "O servidor não subiu (veja as mensagens acima)." >&2; exit 1; }
echo "STUDY no celular: https://$DOMAIN/"
ngrok http --url="$DOMAIN" "$PORT"
