# Quickstart — levantar FLK0S en local en <10 minutos

> Este documento describe el resultado final esperado. Los repos privados de cada
> app contienen su propio README operativo. Aquí está el flujo unificado.

## Prerequisitos

- **Docker Desktop** ≥ 24 (con Compose v2) — Windows/macOS/Linux.
- **Git** (para clonar los 5 repos).
- **Node** (opcional, solo si vas a desarrollar UI) ≥ 20.
- **Caddy** (opcional, solo modo SSO de navegador) — `winget install CaddyServer.Caddy` / `brew install caddy`.
- **Python 3.11+** (para `doctor.py` y `bootstrap.py`).

## Layout esperado

```
F:\FLK0S\                    (o ~/flk0s en *nix)
├── auth-gateway/            ← repo privado
├── FLK0S-CDP/               ← repo privado (cybersec defense platform)
├── FLK0S-RT/                ← repo privado (red team)
├── FLK0S-AI/                ← repo privado (ai copilot)
├── FLK0S-Reportes/          ← repo privado (engagement reports)
├── launchpad/               ← Centro de Operaciones (estático)
├── infra/observability/     ← stack OTel+Prom+Loki+Tempo+Grafana
└── FLK0S-Ecosystem/         ← este repo (showcase público)
```

## Setup (3 pasos)

### 1. Clonar y configurar

```bash
# Clonar todos los repos en la misma carpeta padre
git clone <auth-gateway>     auth-gateway
git clone <FLK0S-CDP>        FLK0S-CDP
git clone <FLK0S-RT>         FLK0S-RT
git clone <FLK0S-AI>         FLK0S-AI
git clone <FLK0S-Reportes>   FLK0S-Reportes

# Generar secrets + .env desde plantillas
./FLK0S-Ecosystem/scripts/setup.sh        # Linux/macOS
./FLK0S-Ecosystem/scripts/setup.ps1       # Windows PowerShell
```

El script `setup`:
- detecta Docker y la versión de Compose
- genera un `SECRET_KEY` compartido con `python -c 'import secrets; print(secrets.token_urlsafe(48))'`
- copia `.env.example` → `.env` en los 5 repos, inyecta el SECRET_KEY común
- pregunta interactivamente por API keys opcionales (LLM, threat-intel) — o deja vacías
- valida puertos libres (3000, 3100-3400, 8000, 8080, 8200-8400, observabilidad)

### 2. Arrancar

```bash
./FLK0S-Ecosystem/scripts/bootstrap.sh
```

`bootstrap`:
1. levanta el stack de observabilidad (`infra/observability`)
2. levanta el gateway (`auth-gateway`) → espera healthy
3. levanta las 4 apps en paralelo → espera todas healthy
4. ejecuta los seeds demo en cada app (idempotentes — re-ejecutable sin romper)
5. corre SSO smoke test (gateway → 4 backends → 200/200/200/200)
6. abre `http://localhost:3000` (Centro de Operaciones)

### 3. (Opcional) Modo subdominio

Si quieres SSO de cookie compartida entre apps:

```bash
# 1) Confiar CA local de Caddy (una vez por máquina)
caddy trust    # Windows admin / sudo en Linux

# 2) Añadir hosts
sudo $EDITOR /etc/hosts        # o C:\Windows\System32\drivers\etc\hosts
# Pegar las 7 entradas de docs/networking.md

# 3) Arrancar Caddy
cd auth-gateway && caddy run --config Caddyfile

# 4) En auth-gateway/.env activar cross-domain cookies:
#    COOKIE_DOMAIN=.flk0s.local
#    COOKIE_SECURE=true
#    ENVIRONMENT=production  (activa HSTS)
docker compose up -d --force-recreate gateway

# 5) Abrir https://hub.flk0s.local
```

Detalle → [`networking.md`](./networking.md)

## Verificación

```bash
./FLK0S-Ecosystem/scripts/doctor.py
```

Output esperado:

```
FLK0S · Doctor
══════════════════════════════════════════
Docker engine ······························· OK (28.0.4)
Docker Compose v2 ··························· OK (v2.32.4)
Puertos libres (3000,3100-3400,8000+APIs) ···· OK
Gateway /health ······························ OK (postgres backend)
CDP API /health ······························ OK
RT API /health ································ OK
AI API /health ································ OK
Reportes API /health ························· OK
SSO end-to-end (4 audiences) ················· OK
Grafana :3001 ································ OK
Prometheus :9090 ····························· OK
Caddy ········································ N/A (modo dev por puerto)
══════════════════════════════════════════
RESULTADO: ECOSISTEMA SALUDABLE
```

## Credenciales demo

```
Email:    demo@flk0s.local
Password: FLK0S-demo-2026
Rol:      admin
Org:      acme-soc
```

Hay también `analyst@acme-soc.flk0s.local` y `operator@acme-soc.flk0s.local` con `FLK0S-demo-2026` y roles correspondientes.

## URLs

| Modo dev (puertos) | Modo gateway (subdominios) | Descripción |
|---|---|---|
| `http://localhost:3000` | `https://hub.flk0s.local` | Centro de Operaciones |
| `http://localhost:3100` | `https://cdp.flk0s.local` | FLK0S-CDP |
| `http://localhost:3200` | `https://rt.flk0s.local` | FLK0S-RT |
| `http://localhost:3300` | `https://ai.flk0s.local` | FLK0S-AI |
| `http://localhost:3400` | `https://reportes.flk0s.local` | FLK0S-Reportes |
| `http://localhost:8000` | `https://auth.flk0s.local` | Auth Gateway |
| `http://localhost:3001` | `http://localhost:3001` | Grafana |

## Reset demo (presentation mode)

Si haces una demo y los datos quedan "sucios":

```bash
./FLK0S-Ecosystem/scripts/presentation-reset.sh
```

Trunca tablas no-críticas en las 4 apps y re-inyecta seeds. Mantiene credenciales y orgs.

## Troubleshooting rápido

| Síntoma | Causa más común | Fix |
|---|---|---|
| Puerto ocupado al arrancar | Otro stack corriendo | `docker ps` y para el que esté en ese puerto |
| Gateway 500 al login | SECRET_KEY no compartido entre repos | rerun `setup` que sincroniza |
| App pidiendo login en cada navegación | Modo dev por puerto, sin Caddy | Esperado — usa modo subdominio para SSO de cookie |
| `ERR_CERT_AUTHORITY_INVALID` | No corriste `caddy trust` | Hazlo (Windows admin / sudo) |
| Grafana sin datos | OTel collector parado o backends sin instrumentación | `doctor.py` lo flaggea |
