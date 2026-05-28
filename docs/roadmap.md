# Roadmap

> Estado público del ecosistema. Lo que ya existe, lo que viene y lo que está descartado.

## Hecho ✅

### Plataforma
- Centro de Operaciones (hub) — KPIs cross-ecosystem, salud en vivo, activity feed, command palette
- Las 4 apps en runtime: CDP · RT · AI · Reportes
- Coherencia visual: severidades SOC homogéneas, accents por app, motion compartido
- 100% UI en español, next-intl en frontends
- Responsive móvil en las 4 (drawer + sidebar off-canvas)
- 404 branded en cada app
- Token-agnostic shared components (EcosystemSwitcher, AppSwitcher, CommandPalette)

### Identidad / SSO
- ✅ **Fase 1**: SECRET_KEY compartida + apps aceptan JWT del gateway + JIT provisioning por app
- ✅ **Fase 2**: Postgres dedicado al gateway con orgs + users + audit + refresh_sessions + bootstrap idempotente
- Auth events con IP+UA (login_success/failure/exchange/logout)
- Refresh sessions persistidos con revocación por jti
- Login estándar (estilo AI) en CDP/RT/AI + EcosystemSwitcher con accent por app

### Observabilidad
- OTel collector recibiendo de los 5 backends
- Prometheus scrapeando `/metrics` de todos
- Tempo con trazas end-to-end
- Loki agregando logs estructurados
- 7 dashboards Grafana incluidos
- Healthchecks docker en cada servicio

### DevEx / Demo
- Demo dataset con org `acme-soc`, 4 usuarios, alertas/campañas/agentes/engagements realistas
- Datos cross-app coherentes (mismo IOC referenciado en CDP, AI y Reportes)
- Compose v2 en cada repo con healthchecks
- Caddyfile listo + DEV-NETWORKING documentado

### Seguridad
- HttpOnly refresh cookie con SameSite=Lax
- Cabeceras de seguridad (HSTS, X-Frame-Options, Permissions-Policy, Referrer-Policy)
- bcrypt para passwords
- Denylist por jti + persistencia en `refresh_sessions.revoked_at`
- Rate limiting en gateway login
- Validación pydantic v2 estricta
- `.dockerignore` en los 5 repos → imágenes sin .env real
- Auditoría de secretos formal (`SECRETS-AUDIT.txt`)

## En curso 🚧

### Fase 3 — Cookie cross-subdomain + login delegado
- Caddy + `*.flk0s.local` (`Caddyfile` listo, requiere setup manual del owner)
- Cookie `flk0s_refresh` con `Domain=.flk0s.local`
- Login de cada app delega al gateway (en vez de tener `/auth/login` propio)
- SDK frontend (`@flk0s/auth-sdk`) ya soporta refresh automático en 401

### Demo & Showcase
- Repo público `FLK0S-Ecosystem` con docs, diagramas, screenshots
- Scripts plug-and-play (setup, doctor, bootstrap)
- Presentation mode (reset demo idempotente)
- README premium

## Próximos pasos ⏳

### Fase 4 — RS256 + JWKS
- Gateway firma con clave privada RSA, expone `/.well-known/jwks.json`
- Apps verifican con clave pública (cacheada por TTL)
- Rotación de claves sin downtime ni redespliegue

### Federación de identidad
- OIDC: Google Workspace, Okta, Azure AD
- SAML 2.0 (enterprise IdPs)
- SCIM 2.0 para provisioning automático de tenants

### MFA
- TOTP (autenticador app)
- WebAuthn (passkeys, Yubikey)
- Recovery codes

### CLI
- `flk0s` CLI para gestión de tenants/orgs/usuarios desde shell
- `flk0s demo reset` para presentation mode desde terminal

### Hosted demo
- Instancia pública en `demo.flk0s.tld` con auto-reset por sesión
- Sandbox limitado: cada visitante crea su propio org efímero (TTL 30min)

### Plataforma
- Real-time vía WebSockets en hub (en vez de polling)
- Notificaciones push browser para alertas críticas
- Reglas de routing entre apps (ej: alerta → caso CDP → engagement Reportes auto)

### Observabilidad
- Alertmanager configurado con SLOs
- OTel browser-side por defecto
- SLO dashboards en Grafana

## Descartado o aparcado ❌

- **Monorepo** — los 5 repos quedan separados. La cohesión se materializa en runtime, no en filesystem
- **Light mode** — operadores SOC trabajan dark, no se mantiene un segundo theme
- **Pricing / billing UI** — FLK0S es plataforma operativa, no SaaS comercial directo (de momento)
- **Marketing landing en root** — `/` redirige a `/dashboard` o `/login`, no a hero comercial
- **Multi-language UI inicial** — 100% español por ahora; i18n keys están listos para añadir locales sin refactor

## Hitos por trimestre (aproximado)

| Trim | Foco |
|---|---|
| **Q2 2026** ⏳ | Fase 3 (cookies cross-subdomain), repo público + showcase, hosted demo MVP |
| **Q3 2026** | Fase 4 (RS256+JWKS), MFA TOTP, CLI básico |
| **Q4 2026** | OIDC federation, WebAuthn, SLO dashboards |
| **Q1 2027** | SCIM, real-time hub, alertmanager + alertas configuradas |
