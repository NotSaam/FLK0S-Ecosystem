# ════════════════════════════════════════════════════════════════════════════
# FLK0S · setup.ps1
# Genera SECRET_KEY compartida + .env desde plantillas + valida prereqs.
# Idempotente: re-correrlo NO sobrescribe .env existentes a menos que -Force.
#
# Uso:
#   pwsh -File setup.ps1                # estándar
#   pwsh -File setup.ps1 -Force         # regenera .env desde cero
#   pwsh -File setup.ps1 -SkipKeyPrompt # no preguntar por LLM/threat-intel keys
# ════════════════════════════════════════════════════════════════════════════

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$SkipKeyPrompt
)

$ErrorActionPreference = "Stop"

function Write-Step($msg)  { Write-Host "`n→ $msg" -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Warn($msg)  { Write-Host "  ! $msg" -ForegroundColor Yellow }
function Write-Fail($msg)  { Write-Host "  ✗ $msg" -ForegroundColor Red }

# Resolver raíz del workspace (asumimos que este script vive en FLK0S-Ecosystem/scripts/)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root      = Resolve-Path (Join-Path $ScriptDir "..\..")
Write-Host "`nFLK0S · Setup" -ForegroundColor White
Write-Host ("=" * 60)
Write-Host "Raíz del workspace: $Root"

# ── 1. Validar prereqs ────────────────────────────────────────────────────
Write-Step "Prerequisitos"

function Test-Cmd($cmd) {
    return [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
}

if (-not (Test-Cmd "docker")) { Write-Fail "Docker no encontrado · Instala Docker Desktop"; exit 1 }
Write-Ok "Docker disponible"

$composeOut = docker compose version --short 2>$null
if ($LASTEXITCODE -ne 0) { Write-Fail "Docker Compose v2 no disponible"; exit 1 }
Write-Ok "Docker Compose v$composeOut"

if (-not (Test-Cmd "python")) {
    Write-Warn "Python no encontrado · doctor.py y bootstrap.py no funcionarán"
} else {
    $pyver = (python --version) -replace 'Python ',''
    Write-Ok "Python $pyver"
}

# ── 2. Generar SECRET_KEY compartida ─────────────────────────────────────
Write-Step "SECRET_KEY compartida del ecosistema"

$SecretFile = Join-Path $Root ".shared_secret.tmp"
if ((Test-Path $SecretFile) -and -not $Force) {
    $Secret = (Get-Content $SecretFile -Raw).Trim()
    Write-Ok "Reutilizando SECRET_KEY existente ($SecretFile)"
} else {
    $Secret = python -c "import secrets; print(secrets.token_urlsafe(48))"
    Set-Content -Path $SecretFile -Value $Secret -Encoding utf8 -NoNewline
    Write-Ok "Generada nueva SECRET_KEY (48 bytes urlsafe)"
}

# Passwords adicionales que se reutilizan en varios .env
$PgGatewayPwd = python -c "import secrets; print(secrets.token_urlsafe(24))"
$PgAppPwd     = python -c "import secrets; print(secrets.token_urlsafe(24))"
$RedisPwd     = python -c "import secrets; print(secrets.token_urlsafe(16))"
$MinioUser    = "flk0s"
$MinioPwd     = python -c "import secrets; print(secrets.token_urlsafe(24))"

# ── 3. (Opcional) LLM + threat-intel keys ────────────────────────────────
$LlmKeys = @{}
if (-not $SkipKeyPrompt) {
    Write-Step "API keys opcionales (dejar vacío si no aplica)"
    foreach ($k in @("ANTHROPIC_API_KEY","OPENAI_API_KEY","GROQ_API_KEY","VIRUSTOTAL_API_KEY","ABUSEIPDB_API_KEY","OTX_API_KEY","SHODAN_API_KEY")) {
        $val = Read-Host "  $k"
        if ($val) { $LlmKeys[$k] = $val.Trim() }
    }
}

# ── 4. Crear .env desde .env.example en cada repo ─────────────────────────
Write-Step "Generando .env por repo"

$Repos = @(
    @{Name="auth-gateway";    Path=Join-Path $Root "auth-gateway";              Example=".env.example";          IsGateway=$true},
    @{Name="FLK0S-AI";        Path=Join-Path $Root "FLK0S-AI";                  Example=".env.example";          IsGateway=$false},
    @{Name="FLK0S-CYB";       Path=Join-Path $Root "FLK0S-CYB";                 Example=".env.example";          IsGateway=$false},
    @{Name="FLK0S-RT";        Path=Join-Path $Root "FLK0S-RT";                  Example=".env.example";          IsGateway=$false},
    @{Name="FLK0S-Reportes";  Path=Join-Path $Root "FLK0S-Reportes\backend";    Example=".env.example";          IsGateway=$false}
)

foreach ($repo in $Repos) {
    if (-not (Test-Path $repo.Path)) {
        Write-Warn "$($repo.Name) no encontrado — skip"
        continue
    }
    $envFile = Join-Path $repo.Path ".env"
    if ((Test-Path $envFile) -and -not $Force) {
        Write-Ok "$($repo.Name): .env ya existe (--Force para regenerar)"
        continue
    }
    $examplePath = Join-Path $repo.Path $repo.Example
    if (-not (Test-Path $examplePath)) {
        Write-Warn "$($repo.Name): .env.example no encontrado en $examplePath"
        continue
    }
    $content = Get-Content $examplePath -Raw
    $content = $content -replace '(?m)^SECRET_KEY=.*',      "SECRET_KEY=$Secret"
    $content = $content -replace '(?m)^POSTGRES_PASSWORD=.*',"POSTGRES_PASSWORD=$PgAppPwd"
    $content = $content -replace '(?m)^REDIS_PASSWORD=.*',  "REDIS_PASSWORD=$RedisPwd"
    $content = $content -replace '(?m)^MINIO_ACCESS_KEY=.*',"MINIO_ACCESS_KEY=$MinioUser"
    $content = $content -replace '(?m)^MINIO_SECRET_KEY=.*',"MINIO_SECRET_KEY=$MinioPwd"
    $content = $content -replace '(?m)^S3_ACCESS_KEY=.*',   "S3_ACCESS_KEY=$MinioUser"
    $content = $content -replace '(?m)^S3_SECRET_KEY=.*',   "S3_SECRET_KEY=$MinioPwd"

    foreach ($k in $LlmKeys.Keys) {
        if ($content -match "(?m)^$k=") {
            $content = $content -replace "(?m)^$k=.*", "$k=$($LlmKeys[$k])"
        }
    }

    Set-Content -Path $envFile -Value $content -Encoding utf8
    Write-Ok "$($repo.Name): .env generado"
}

# ── 5. Gateway extras: DATABASE_URL específico ───────────────────────────
$gwEnv = Join-Path $Root "auth-gateway\.env"
if (Test-Path $gwEnv) {
    $gwContent = Get-Content $gwEnv -Raw
    if ($gwContent -notmatch 'DATABASE_URL=') {
        Add-Content $gwEnv "`nPOSTGRES_USER=flk0s_auth"
        Add-Content $gwEnv "POSTGRES_PASSWORD=$PgGatewayPwd"
        Add-Content $gwEnv "POSTGRES_DB=flk0s_auth"
        Add-Content $gwEnv "DATABASE_URL=postgresql+asyncpg://flk0s_auth:$PgGatewayPwd@gateway-db:5432/flk0s_auth"
        Add-Content $gwEnv "SEED_DEMO_USER=true"
        Write-Ok "auth-gateway: DATABASE_URL inyectado"
    }
}

# ── 6. CYB workaround: docker include resuelve env de su propio dir ──────
$cybInner = Join-Path $Root "FLK0S-CYB\infra\docker"
if (Test-Path $cybInner) {
    $cybInnerEnv = Join-Path $cybInner ".env"
    if ((-not (Test-Path $cybInnerEnv)) -or $Force) {
        Set-Content -Path $cybInnerEnv -Value "SECRET_KEY=$Secret" -Encoding utf8
        Write-Ok "CYB: .env interno (workaround docker include) generado"
    }
}

Write-Host "`n" -NoNewline
Write-Host ("=" * 60)
Write-Host "Setup completo." -ForegroundColor Green
Write-Host "Siguiente paso:"
Write-Host "  python FLK0S-Ecosystem\scripts\bootstrap.py"
