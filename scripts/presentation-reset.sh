#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════════
# FLK0S · Presentation Mode reset
#
# Restaura el demo dataset a estado limpio entre presentaciones.
# Idempotente. Mantiene:
#   - Organización acme-soc y sus 4 usuarios demo
#   - Audit log del gateway (auth_events) — sirve de histórico de la demo
#   - Volúmenes Docker (DBs siguen vivas; sólo se truncan tablas tagged)
#
# Borra y re-siembra:
#   - alertas CDP (created_by='demo-seed' o tags='demo')
#   - casos CDP demo
#   - campañas RT demo + agentes demo
#   - conversaciones AI demo
#   - engagements + findings demo en Reportes
#
# Uso:
#   bash presentation-reset.sh                 # estándar
#   bash presentation-reset.sh --hard          # también limpia refresh_sessions
#   bash presentation-reset.sh --dry-run       # imprime lo que haría sin tocar nada
# ════════════════════════════════════════════════════════════════════════════

set -euo pipefail

HARD=0
DRY=0
for a in "$@"; do
  case "$a" in
    --hard)    HARD=1 ;;
    --dry-run) DRY=1 ;;
  esac
done

c_cyan="\033[36m"; c_grn="\033[32m"; c_yel="\033[33m"; c_red="\033[31m"; c_end="\033[0m"
step() { echo -e "\n${c_cyan}→ $*${c_end}"; }
ok()   { echo -e "  ${c_grn}✓${c_end} $*"; }
warn() { echo -e "  ${c_yel}!${c_end} $*"; }
fail() { echo -e "  ${c_red}✗${c_end} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

run_pg() {
  local container="$1"
  local user="$2"
  local db="$3"
  local sql="$4"
  if [[ $DRY -eq 1 ]]; then
    echo "  [dry] $container :: $db :: $(echo "$sql" | head -c 80)"
    return 0
  fi
  docker exec -i "$container" psql -U "$user" -d "$db" -c "$sql" >/dev/null 2>&1 && ok "$container :: $(echo "$sql" | head -c 60)" || warn "$container :: SQL falló (¿tabla inexistente todavía?)"
}

call_admin_reset() {
  local label="$1"
  local url="$2"
  if [[ $DRY -eq 1 ]]; then
    echo "  [dry] POST $url"
    return 0
  fi
  # Estos endpoints aún no existen — placeholder para el futuro presentation API
  if curl -fsS -X POST "$url" -H "X-Demo-Reset-Token: $RESET_TOKEN" 2>/dev/null | head -c 0 ; then
    ok "$label: admin reset OK"
  else
    warn "$label: admin reset no disponible (endpoint no implementado todavía)"
  fi
}

echo
echo "FLK0S · Presentation Mode Reset"
echo "============================================================"
[[ $DRY -eq 1 ]] && echo "MODO DRY-RUN — ningún cambio se aplicará"

# ── Token compartido entre script y endpoints admin (cuando existan) ──────
RESET_TOKEN="${FLK0S_DEMO_RESET_TOKEN:-flk0s-presentation-reset}"

# ── 1. Hacer pausa a los workers para evitar carreras ─────────────────────
step "Pausando workers"
for c in flk0s-rt-backend-1 flk0s-ai-backend-1 flk0s-reportes-backend-1 flk0s_cdp_api; do
  if [[ $DRY -eq 1 ]]; then
    echo "  [dry] docker pause $c"
  else
    docker pause "$c" >/dev/null 2>&1 && ok "$c paused" || warn "$c ya parado o inexistente"
  fi
done

# ── 2. Truncar tablas demo-tagged en cada DB ──────────────────────────────
step "Limpiando registros tagged demo en las DBs"

# CDP (multi-tenant)
run_pg flk0s_cdp_postgres flk0s flk0s_cdp \
  "DELETE FROM alerts WHERE created_by='demo-seed' OR tags @> ARRAY['demo']::text[];"
run_pg flk0s_cdp_postgres flk0s flk0s_cdp \
  "DELETE FROM cases WHERE created_by='demo-seed' OR tags @> ARRAY['demo']::text[];"
run_pg flk0s_cdp_postgres flk0s flk0s_cdp \
  "DELETE FROM iocs WHERE created_by='demo-seed';"

# RT
run_pg flk0s-rt-db-1 flk0s_rt flk0s_rt \
  "DELETE FROM campaigns WHERE created_by='demo-seed';"
run_pg flk0s-rt-db-1 flk0s_rt flk0s_rt \
  "DELETE FROM agents WHERE created_by='demo-seed';"

# Reportes
run_pg flk0s-reportes-db-1 flk0s flk0s_reporter \
  "DELETE FROM engagements WHERE created_by='demo-seed';"
run_pg flk0s-reportes-db-1 flk0s flk0s_reporter \
  "DELETE FROM findings WHERE created_by='demo-seed';"

# AI (mayormente stateless; sólo conversaciones)
run_pg flk0s-ai-postgres-1 flk0s_ai flk0s_ai \
  "DELETE FROM conversations WHERE created_by='demo-seed';"

# ── 3. Refresh sessions del gateway (opcional, --hard) ────────────────────
if [[ $HARD -eq 1 ]]; then
  step "Limpiando refresh_sessions del gateway (--hard)"
  run_pg auth-gateway-gateway-db-1 flk0s_auth flk0s_auth \
    "UPDATE refresh_sessions SET revoked_at=NOW() WHERE revoked_at IS NULL;"
fi

# ── 4. Re-anudar workers ──────────────────────────────────────────────────
step "Despausando workers"
for c in flk0s-rt-backend-1 flk0s-ai-backend-1 flk0s-reportes-backend-1 flk0s_cdp_api; do
  if [[ $DRY -eq 1 ]]; then
    echo "  [dry] docker unpause $c"
  else
    docker unpause "$c" >/dev/null 2>&1 && ok "$c resumed" || true
  fi
done

# ── 5. Re-seedear (cuando los seeds demo estén implementados por app) ─────
step "Re-seedeando demo dataset"
if [[ $DRY -eq 1 ]]; then
  echo "  [dry] python $SCRIPT_DIR/bootstrap.py --no-obs --no-teardown   (--seed implícito)"
else
  if command -v python3 >/dev/null; then PY=python3; else PY=python; fi
  $PY "$SCRIPT_DIR/bootstrap.py" --no-obs 2>&1 | grep -E "(seed|SSO)" || true
fi

# ── 6. Verificación rápida ────────────────────────────────────────────────
step "Verificación"
if [[ $DRY -eq 0 ]]; then
  if command -v python3 >/dev/null; then PY=python3; else PY=python; fi
  $PY "$SCRIPT_DIR/doctor.py" --no-sso 2>&1 | tail -1
fi

echo
echo "============================================================"
echo -e "${c_grn}Demo limpio. Listo para presentar.${c_end}"
echo "Login: demo@flk0s.local / FLK0S-demo-2026"
