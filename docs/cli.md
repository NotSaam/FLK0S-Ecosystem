# `flk0s` CLI

> Herramienta de gestión del ecosistema desde terminal. Cubre lo más usado por
> el owner: status, seeds, SSO debug, usuarios, audit log, logs por servicio.

## Instalación

```bash
# Linux / macOS
chmod +x FLK0S-Ecosystem/scripts/flk0s
ln -s "$(pwd)/FLK0S-Ecosystem/scripts/flk0s" /usr/local/bin/flk0s

# Windows (PowerShell admin)
$env:Path += ";F:\FLK0S\FLK0S-Ecosystem\scripts"
# usa flk0s.cmd para invocar
```

O sin instalar:
```bash
python FLK0S-Ecosystem/scripts/flk0s <comando>
```

## Comandos

### Salud y arranque

```bash
flk0s status                  # doctor completo (23 checks)
flk0s status --verbose
flk0s bootstrap               # arranca el stack completo + seed + SSO smoke
flk0s bootstrap --no-seed --no-obs
```

### Demo data

```bash
flk0s seed                    # corre seeds de CYB + RT + Reportes
flk0s reset                   # presentation mode reset (limpia+seedea)
flk0s reset --hard            # también limpia refresh_sessions
flk0s reset --dry-run         # imprime acciones sin ejecutar
```

### SSO

```bash
flk0s sso login --aud=cdp                              # access_token plain
flk0s sso login --aud=cdp --json                       # respuesta completa
flk0s sso login --aud=rt --email=admin@acme.tld --password=...

flk0s sso whoami <token>                               # decodifica claims
flk0s sso jwks                                         # JWKS del gateway (RS256)
```

### Usuarios y organizations

```bash
flk0s user list
flk0s user create alice@acme.tld FLK0SpassDemo --name="Alice" --role=analyst --org=acme-soc

flk0s org list
```

### Audit log

```bash
flk0s events                    # últimos 20 auth_events
flk0s events --tail=100
```

### Logs

```bash
flk0s logs gateway --tail=100
flk0s logs cdp                  # docker compose logs de FLK0S-CYB
flk0s logs rt
flk0s logs ai
flk0s logs reportes
flk0s logs obs                  # observability stack
```

## Variables de entorno

| Variable | Default | Uso |
|---|---|---|
| `FLK0S_GATEWAY_URL` | `http://localhost:8000` | URL del gateway para los comandos `sso *` |
| `FLK0S_DEMO_EMAIL` | `demo@flk0s.local` | Email del usuario demo (login default) |
| `FLK0S_DEMO_PASSWORD` | `FLK0S-demo-2026` | Password demo |

## Ejemplos prácticos

### Demo express

```bash
flk0s bootstrap            # arranca todo
flk0s seed                 # carga dataset
open http://localhost:3000
# ...presentar...
flk0s reset                # vuelve al estado limpio entre sesiones
```

### Crear analyst para un cliente

```bash
flk0s org list             # confirma que la org existe
flk0s user create analyst@cliente.tld <password> --role=analyst --org=acme-soc
# El analista puede loguearse en cdp/rt/etc. (JIT lo provisionará en cada app
# al primer login con esa audience)
```

### Debugging SSO

```bash
# Verifica que el gateway emite tokens
TOK=$(flk0s sso login --aud=cdp)
flk0s sso whoami "$TOK"

# Mira los últimos eventos
flk0s events --tail=10

# Si algo falla, logs del gateway
flk0s logs gateway --tail=200
```

### Cambiar de HS256 a RS256

```bash
# 1. Edita auth-gateway/.env: ALGORITHM=RS256
# 2. Restart
cd auth-gateway && docker compose up -d --force-recreate gateway

# 3. Verifica
flk0s sso jwks               # debe devolver una key
flk0s sso login --aud=cdp    # token con alg=RS256 en el header
```

## Salida

- `0` → OK
- `1` → fallo recoverable (no se pudo conectar a Postgres, login falló, etc.)
- `2` → MFA challenge en SSO login (se necesita segundo paso)
- `130` → interrumpido (Ctrl+C)

## Roadmap CLI

- ✅ status, bootstrap, seed, reset, sso, user, org, events, logs
- ⏳ `flk0s mfa enroll --user=<email>` (auto-flow)
- ⏳ `flk0s rotate-key` (RS256 rotation triggered)
- ⏳ `flk0s import --tenant=<json>` (bulk provisioning)
- ⏳ `flk0s export --audit --since=<date>`
- ⏳ argcomplete para bash/zsh
