#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════════
# FLK0S · setup.sh — equivalente Bash de setup.ps1
# Genera SECRET_KEY compartida + .env desde plantillas + valida prereqs.
# Idempotente: re-correr NO sobrescribe .env existentes a menos que --force.
#
# Uso:
#   bash setup.sh                  # estándar
#   bash setup.sh --force          # regenera .env desde cero
#   bash setup.sh --skip-keys      # no preguntar por LLM/threat-intel keys
# ════════════════════════════════════════════════════════════════════════════

set -euo pipefail

FORCE=0
SKIP_KEYS=0
for arg in "$@"; do
  case "$arg" in
    --force)     FORCE=1 ;;
    --skip-keys) SKIP_KEYS=1 ;;
    -h|--help)
      sed -n '2,12p' "$0"; exit 0 ;;
  esac
done

c_cyan="\033[36m"; c_grn="\033[32m"; c_yel="\033[33m"; c_red="\033[31m"; c_end="\033[0m"
step() { echo -e "\n${c_cyan}→ $*${c_end}"; }
ok()   { echo -e "  ${c_grn}✓${c_end} $*"; }
warn() { echo -e "  ${c_yel}!${c_end} $*"; }
fail() { echo -e "  ${c_red}✗${c_end} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo
echo "FLK0S · Setup"
echo "============================================================"
echo "Raíz del workspace: $ROOT"

# ── 1. Prereqs ────────────────────────────────────────────────────────────
step "Prerequisitos"
command -v docker >/dev/null || { fail "Docker no encontrado"; exit 1; }
ok "Docker disponible"

if ! docker compose version --short >/dev/null 2>&1; then
  fail "Docker Compose v2 no disponible"; exit 1
fi
ok "Docker Compose v$(docker compose version --short)"

if command -v python3 >/dev/null; then
  PY=python3
elif command -v python >/dev/null; then
  PY=python
else
  fail "Python no encontrado"; exit 1
fi
ok "Python $($PY --version | awk '{print $2}')"

# ── 2. SECRET_KEY ─────────────────────────────────────────────────────────
step "SECRET_KEY compartida"
SECRET_FILE="$ROOT/.shared_secret.tmp"
if [[ -f "$SECRET_FILE" && $FORCE -eq 0 ]]; then
  SECRET=$(cat "$SECRET_FILE" | tr -d '[:space:]')
  ok "Reutilizando SECRET_KEY existente"
else
  SECRET=$($PY -c "import secrets; print(secrets.token_urlsafe(48))")
  printf "%s" "$SECRET" > "$SECRET_FILE"
  ok "Generada nueva SECRET_KEY"
fi

PG_GW_PWD=$($PY -c "import secrets; print(secrets.token_urlsafe(24))")
PG_APP_PWD=$($PY -c "import secrets; print(secrets.token_urlsafe(24))")
REDIS_PWD=$($PY -c "import secrets; print(secrets.token_urlsafe(16))")
MINIO_USER="flk0s"
MINIO_PWD=$($PY -c "import secrets; print(secrets.token_urlsafe(24))")

# ── 3. Keys opcionales ────────────────────────────────────────────────────
declare -A LLM_KEYS
if [[ $SKIP_KEYS -eq 0 ]]; then
  step "API keys opcionales (Enter = vacío)"
  for k in ANTHROPIC_API_KEY OPENAI_API_KEY GROQ_API_KEY VIRUSTOTAL_API_KEY ABUSEIPDB_API_KEY OTX_API_KEY SHODAN_API_KEY; do
    read -r -p "  $k: " v
    [[ -n "$v" ]] && LLM_KEYS[$k]="$v"
  done
fi

# ── 4. Generar .env por repo ──────────────────────────────────────────────
step "Generando .env por repo"

declare -a REPOS=(
  "auth-gateway:.env.example"
  "FLK0S-AI:.env.example"
  "FLK0S-CYB:.env.example"
  "FLK0S-RT:.env.example"
  "FLK0S-Reportes/backend:.env.example"
)

for entry in "${REPOS[@]}"; do
  IFS=":" read -r relpath example <<< "$entry"
  full="$ROOT/$relpath"
  if [[ ! -d "$full" ]]; then warn "$relpath no encontrado"; continue; fi
  env_file="$full/.env"
  if [[ -f "$env_file" && $FORCE -eq 0 ]]; then
    ok "$relpath: .env ya existe"
    continue
  fi
  if [[ ! -f "$full/$example" ]]; then warn "$relpath: $example no encontrado"; continue; fi
  cp "$full/$example" "$env_file"
  $PY -c "
import re, sys
secret = '''$SECRET'''
pg = '''$PG_APP_PWD'''
rd = '''$REDIS_PWD'''
mu = '''$MINIO_USER'''
mp = '''$MINIO_PWD'''
with open('$env_file', 'r', encoding='utf-8') as f: t = f.read()
def r(k, v): return re.sub(rf'^{re.escape(k)}=.*$', f'{k}={v}', t, flags=re.MULTILINE)
for k, v in [('SECRET_KEY',secret),('POSTGRES_PASSWORD',pg),('REDIS_PASSWORD',rd),('MINIO_ACCESS_KEY',mu),('MINIO_SECRET_KEY',mp),('S3_ACCESS_KEY',mu),('S3_SECRET_KEY',mp)]:
    t = r(k, v)
with open('$env_file', 'w', encoding='utf-8') as f: f.write(t)
"
  for k in "${!LLM_KEYS[@]}"; do
    $PY -c "
import re
k='$k'; v='''${LLM_KEYS[$k]}'''
with open('$env_file','r',encoding='utf-8') as f: t=f.read()
t=re.sub(rf'^{re.escape(k)}=.*$', f'{k}={v}', t, flags=re.MULTILINE)
with open('$env_file','w',encoding='utf-8') as f: f.write(t)
"
  done
  ok "$relpath: .env generado"
done

# ── 5. Gateway: DATABASE_URL extra ────────────────────────────────────────
gw_env="$ROOT/auth-gateway/.env"
if [[ -f "$gw_env" ]] && ! grep -q "^DATABASE_URL=" "$gw_env"; then
  {
    echo ""
    echo "POSTGRES_USER=flk0s_auth"
    echo "POSTGRES_PASSWORD=$PG_GW_PWD"
    echo "POSTGRES_DB=flk0s_auth"
    echo "DATABASE_URL=postgresql+asyncpg://flk0s_auth:$PG_GW_PWD@gateway-db:5432/flk0s_auth"
    echo "SEED_DEMO_USER=true"
  } >> "$gw_env"
  ok "auth-gateway: DATABASE_URL inyectado"
fi

# ── 6. CYB inner .env (docker include gotcha) ─────────────────────────────
cyb_inner="$ROOT/FLK0S-CYB/infra/docker"
if [[ -d "$cyb_inner" ]]; then
  cyb_env="$cyb_inner/.env"
  if [[ ! -f "$cyb_env" || $FORCE -eq 1 ]]; then
    echo "SECRET_KEY=$SECRET" > "$cyb_env"
    ok "CYB: .env interno (docker include workaround)"
  fi
fi

echo
echo "============================================================"
echo -e "${c_grn}Setup completo.${c_end}"
echo "Siguiente paso:"
echo "  $PY $ROOT/FLK0S-Ecosystem/scripts/bootstrap.py"
