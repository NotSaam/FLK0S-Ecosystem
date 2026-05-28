# Networking — Caddy + Subdominios + Cookies cross-subdomain

> Para activar SSO de cookie compartida entre las apps. Sin Caddy, el ecosistema
> funciona en modo "dev por puerto" — el JWT del gateway viaja por header
> Authorization y todas las apps lo aceptan, pero la cookie de refresh no se
> comparte entre orígenes.

## Topología de subdominios

```
hub.flk0s.local              ↦ 127.0.0.1:3000  Centro de Operaciones
cdp.flk0s.local              ↦ 127.0.0.1:3100  FLK0S-CDP Web
api.cdp.flk0s.local          ↦ 127.0.0.1:8080  FLK0S-CDP API
rt.flk0s.local               ↦ 127.0.0.1:3200  FLK0S-RT Web
api.rt.flk0s.local           ↦ 127.0.0.1:8200  FLK0S-RT API
ai.flk0s.local               ↦ 127.0.0.1:3300  FLK0S-AI Web
api.ai.flk0s.local           ↦ 127.0.0.1:8300  FLK0S-AI API
reportes.flk0s.local         ↦ 127.0.0.1:3400  FLK0S-Reportes Web
api.reportes.flk0s.local     ↦ 127.0.0.1:8400  FLK0S-Reportes API
auth.flk0s.local             ↦ 127.0.0.1:8000  Auth Gateway
```

## ¿Por qué subdominios y no `localhost:PUERTO`?

Cookies con `Domain=.flk0s.local` son enviadas por el navegador a **cualquier** subdominio bajo `flk0s.local`. Pero las cookies NO se comparten entre orígenes que difieran solo en puerto (`localhost:3100` y `localhost:3200` son orígenes distintos a efectos de cookie). Sin subdominios, no hay SSO real de navegador.

## Setup

### 1. Instalar Caddy

```powershell
# Windows
winget install CaddyServer.Caddy
```

```bash
# macOS
brew install caddy

# Linux (Debian/Ubuntu)
# Ver https://caddyserver.com/docs/install
```

### 2. Editar archivo hosts (como administrador)

**Windows** → `C:\Windows\System32\drivers\etc\hosts`
**macOS/Linux** → `/etc/hosts`

```text
127.0.0.1 hub.flk0s.local
127.0.0.1 cdp.flk0s.local       api.cdp.flk0s.local
127.0.0.1 rt.flk0s.local        api.rt.flk0s.local
127.0.0.1 ai.flk0s.local        api.ai.flk0s.local
127.0.0.1 reportes.flk0s.local  api.reportes.flk0s.local
127.0.0.1 auth.flk0s.local
```

### 3. Confiar la CA local de Caddy (una vez por máquina)

```bash
caddy trust    # Windows: PowerShell admin · Linux/macOS: sudo
```

Esto instala el root certificate de Caddy en el sistema → ya no verás warnings de
"no es seguro" al abrir `https://cdp.flk0s.local`.

### 4. Arrancar Caddy

```bash
cd auth-gateway
caddy run --config Caddyfile
```

Caddy escucha en :80 y :443. Termina TLS local y proxy-pasa al puerto correspondiente.

### 5. Configurar el gateway para subdominio compartido

En `auth-gateway/.env`:

```dotenv
SECRET_KEY=<generado-con-secrets.token_urlsafe>
ENVIRONMENT=production               # activa Secure cookies + HSTS
COOKIE_DOMAIN=.flk0s.local
COOKIE_SECURE=true
COOKIE_SAMESITE=lax
ALLOWED_ORIGINS=https://hub.flk0s.local,https://cdp.flk0s.local,https://rt.flk0s.local,https://ai.flk0s.local,https://reportes.flk0s.local
```

Reinicia el gateway:

```bash
cd auth-gateway && docker compose up -d --force-recreate gateway
```

### 6. Abrir

- `https://hub.flk0s.local` → Centro de Operaciones (login una vez)
- Navega a `https://cdp.flk0s.local` → sesión activa (cookie viajó)
- Navega a `https://rt.flk0s.local` → sesión activa (sin volver a loguear)

## Fallback sin Caddy (modo dev por puerto)

Si no quieres instalar Caddy todavía:

- Cada app sigue accesible en `http://localhost:31xx`
- El AppSwitcher funciona (links absolutos entre orígenes)
- El SSO de cookie NO funciona — pero el SSO de JWT sí (vía header Authorization)
- El SDK `@flk0s/auth-sdk` cachea el access token en memoria + sessionStorage del propio origen
- Práctico para desarrollo individual; no realista para demos

## Producción

En cloud real, sustituir `flk0s.local` por tu dominio (`flk0s.tld`, `flk0s-demo.io`, etc.).
Caddy + Let's Encrypt resuelve TLS automáticamente sin cambios al `Caddyfile` (solo
cambia el dominio y `COOKIE_DOMAIN`). Sin Caddy, cualquier reverse proxy (Traefik, nginx,
Cloudflare) funciona igualmente — la condición esencial es:
- TLS terminado
- Mismo dominio base para todas las apps
- `Domain=.flk0s.tld` en la cookie del gateway

## Troubleshooting

| Síntoma | Causa | Solución |
|---|---|---|
| `ERR_CERT_AUTHORITY_INVALID` | No confiaste la CA de Caddy | `caddy trust` |
| Cookie no viaja entre apps | `COOKIE_DOMAIN` mal puesto | Debe empezar con `.` (`.flk0s.local`) |
| CORS preflight falla | Origin no en allowlist | Añadir a `ALLOWED_ORIGINS` del gateway |
| `host not found` | Falta entrada en hosts | Volver al paso 2 |
| Caddy no escucha 443 | Falta permiso admin | Arrancar como admin / `sudo` |
| Logout en CDP no cierra RT | Refresh denylist está en memoria — un crash del gateway lo olvida | Esperado · Fase 2 ya persiste en `refresh_sessions.revoked_at` |
| Login parece OK pero next request 401 | El token caché del frontend está viejo | Hard refresh (Ctrl+Shift+R) |

## Seguridad

- **HSTS** activado en producción (`ENVIRONMENT=production`).
- Cookie `flk0s_refresh`: `HttpOnly · Secure · SameSite=Lax · Domain=.flk0s.local`.
- Cabeceras compartidas por todos los vhosts: `X-Frame-Options DENY · X-Content-Type-Options nosniff · Referrer-Policy strict-origin-when-cross-origin · Permissions-Policy mínima`.
- Caddy **strip** del header `Server` para no anunciar versión.
- Access token JAMÁS en cookie, JAMÁS en localStorage. Solo memoria + sessionStorage del origin.
