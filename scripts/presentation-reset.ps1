# ════════════════════════════════════════════════════════════════════════════
# FLK0S · Presentation Mode reset (Windows PowerShell)
# Equivalente de presentation-reset.sh
# ════════════════════════════════════════════════════════════════════════════

[CmdletBinding()]
param(
    [switch]$Hard,
    [switch]$DryRun
)

$ErrorActionPreference = "Continue"

function Step($m) { Write-Host "`n→ $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "  ✓ $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  ! $m" -ForegroundColor Yellow }

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root      = Resolve-Path (Join-Path $ScriptDir "..\..")
$ResetToken = $env:FLK0S_DEMO_RESET_TOKEN
if (-not $ResetToken) { $ResetToken = "flk0s-presentation-reset" }

Write-Host "`nFLK0S · Presentation Mode Reset" -ForegroundColor White
Write-Host ("=" * 60)
if ($DryRun) { Write-Host "MODO DRY-RUN — ningún cambio se aplicará" -ForegroundColor Yellow }

function Run-Pg($container, $user, $db, $sql) {
    if ($DryRun) {
        Write-Host "  [dry] $container :: $($sql.Substring(0, [Math]::Min(80, $sql.Length)))"
        return
    }
    $null = docker exec -i $container psql -U $user -d $db -c $sql 2>$null
    if ($LASTEXITCODE -eq 0) {
        Ok "$container :: $($sql.Substring(0, [Math]::Min(60, $sql.Length)))"
    } else {
        Warn "$container :: SQL falló (¿tabla inexistente?)"
    }
}

# ── 1. Pausa de workers ──────────────────────────────────────────────────
Step "Pausando workers"
foreach ($c in @("flk0s-rt-backend-1","flk0s-ai-backend-1","flk0s-reportes-backend-1","flk0s_cdp_api")) {
    docker pause $c 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { Ok "$c paused" } else { Warn "$c ya parado o inexistente" }
}

# ── 2. Limpiar tablas demo-tagged ────────────────────────────────────────
Step "Limpiando registros tagged demo"

Run-Pg "flk0s_cdp_postgres" "flk0s" "flk0s_cdp" "DELETE FROM alerts WHERE created_by='demo-seed' OR tags @> ARRAY['demo']::text[];"
Run-Pg "flk0s_cdp_postgres" "flk0s" "flk0s_cdp" "DELETE FROM cases  WHERE created_by='demo-seed' OR tags @> ARRAY['demo']::text[];"
Run-Pg "flk0s_cdp_postgres" "flk0s" "flk0s_cdp" "DELETE FROM iocs   WHERE created_by='demo-seed';"
Run-Pg "flk0s-rt-db-1"      "flk0s_rt"   "flk0s_rt"        "DELETE FROM campaigns WHERE created_by='demo-seed';"
Run-Pg "flk0s-rt-db-1"      "flk0s_rt"   "flk0s_rt"        "DELETE FROM agents    WHERE created_by='demo-seed';"
Run-Pg "flk0s-reportes-db-1" "flk0s"     "flk0s_reporter"  "DELETE FROM engagements WHERE created_by='demo-seed';"
Run-Pg "flk0s-reportes-db-1" "flk0s"     "flk0s_reporter"  "DELETE FROM findings    WHERE created_by='demo-seed';"
Run-Pg "flk0s-ai-postgres-1" "flk0s_ai"  "flk0s_ai"        "DELETE FROM conversations WHERE created_by='demo-seed';"

# ── 3. Hard reset opcional ───────────────────────────────────────────────
if ($Hard) {
    Step "Limpiando refresh_sessions del gateway (--hard)"
    Run-Pg "auth-gateway-gateway-db-1" "flk0s_auth" "flk0s_auth" "UPDATE refresh_sessions SET revoked_at=NOW() WHERE revoked_at IS NULL;"
}

# ── 4. Despausar ─────────────────────────────────────────────────────────
Step "Despausando workers"
foreach ($c in @("flk0s-rt-backend-1","flk0s-ai-backend-1","flk0s-reportes-backend-1","flk0s_cdp_api")) {
    docker unpause $c 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { Ok "$c resumed" }
}

# ── 5. Re-seed + verify ───────────────────────────────────────────────────
Step "Re-seedeando + verificando"
if (-not $DryRun) {
    python "$ScriptDir\bootstrap.py" --no-obs 2>&1 | Select-String "seed|SSO" | ForEach-Object { $_.Line }
    python "$ScriptDir\doctor.py" --no-sso 2>&1 | Select-Object -Last 2
}

Write-Host "`n" -NoNewline
Write-Host ("=" * 60)
Write-Host "Demo limpio. Listo para presentar." -ForegroundColor Green
Write-Host "Login: demo@flk0s.local / FLK0S-demo-2026"
