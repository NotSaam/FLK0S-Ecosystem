<div align="center">

# FLK0S

### Tactical cybersecurity platform — engineered as one operating system, not five tools.

[![Status](https://img.shields.io/badge/status-active%20development-00d9ff?style=flat-square)]()
[![Apps](https://img.shields.io/badge/apps-4%20%2B%20hub-purple?style=flat-square)]()
[![SSO](https://img.shields.io/badge/SSO-cross--app-success?style=flat-square)]()
[![Stack](https://img.shields.io/badge/stack-Next.js%20%2B%20FastAPI%20%2B%20Postgres-blue?style=flat-square)]()
[![Observability](https://img.shields.io/badge/observability-OTel%20%2B%20Prometheus%20%2B%20Grafana-orange?style=flat-square)]()
[![License](https://img.shields.io/badge/license-Showcase-lightgrey?style=flat-square)](LICENSE)

</div>

---

## ¿Qué es FLK0S?

**FLK0S** es un ecosistema de ciberseguridad construido como una sola plataforma operativa. Cuatro aplicaciones especializadas, un Centro de Operaciones unificado, una identidad compartida, una superficie de observabilidad.

No es un dashboard. No es una colección de tools. Es un **operating system táctico** para equipos de defensa, ofensiva, análisis y reporting.

| Módulo | Propósito | Stack |
|---|---|---|
| **FLK0S-CDP** *(Cyber Defense Platform)* | SOC — alertas, casos, threat intel, response | Next.js · FastAPI · Postgres · ClickHouse · OpenSearch |
| **FLK0S-RT** *(Red Team)* | Operaciones ofensivas — campañas, agentes, lateral movement | Next.js · FastAPI · Postgres · MinIO |
| **FLK0S-AI** *(AI Copilot)* | LLM táctico — investigación IOC, hunting assistance | Next.js · FastAPI · Qdrant · LLM agnóstico |
| **FLK0S-Reportes** | Engagement reports, findings, evidence, deliverables | Next.js · FastAPI · Postgres · MinIO |
| **Centro de Operaciones** *(hub)* | Cockpit maestro: KPIs cross-ecosystem, salud, feed, command palette | Static · cross-app fetch |
| **Auth Gateway** | SSO compartido — JWT issuer, JIT provisioning, audit trail | FastAPI · Postgres · async |

---

## Por qué importa

Los equipos de seguridad operan con un Frankenstein de herramientas desconectadas. Cada una con su login, su modelo de datos, su look-and-feel, su silo de telemetría. FLK0S resuelve eso por construcción:

- **Una identidad** — login en cualquier app, sesión válida en todas (SSO real, no SAML pegado encima).
- **Un lenguaje visual** — severidades, accents, tipografía y motion compartidos por design tokens.
- **Un cockpit** — el hub agrega KPIs, salud y actividad de las 4 plataformas en tiempo real.
- **Un eje de observabilidad** — traces OTel, métricas Prometheus, logs Loki, dashboards Grafana, todo correlacionado.

---

## Arquitectura

```
                      ┌────────────────────────────────────────┐
                      │      Centro de Operaciones (hub)       │
                      │   KPIs · health · feed · Cmd+K         │
                      └────────────────────────────────────────┘
                                       │
              ┌────────────┬───────────┼───────────┬────────────┐
              ▼            ▼           ▼           ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
        │   CDP    │ │    RT    │ │    AI    │ │ Reportes │ │   Auth   │
        │  :3100   │ │   :3200  │ │   :3300  │ │   :3400  │ │   :8000  │
        └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘
             │            │            │            │            │
             ▼            ▼            ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
        │  API:8080│ │ API:8200 │ │ API:8300 │ │ API:8400 │ │ Gateway  │
        │  Postgres│ │ Postgres │ │ Qdrant   │ │ Postgres │ │ Postgres │
        │  ClickH. │ │ MinIO    │ │ Redis    │ │ MinIO    │ │  audit   │
        └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘
              │            │            │            │
              └────────────┴────────────┴────────────┘
                                       │
                            ┌──────────────────────┐
                            │  Observability Stack │
                            │  OTel · Prometheus   │
                            │   Loki · Tempo · Gr  │
                            └──────────────────────┘
```

Diagramas detallados → [`diagrams/`](./diagrams)

---

## Single Sign-On

Un único `POST /auth/login` en el gateway emite un token con `aud=flk0s:<app>`. La cookie `flk0s_refresh` (HttpOnly, `Domain=.flk0s.local`) viaja entre subdominios → cambias de `cdp.flk0s.local` a `rt.flk0s.local` y la sesión persiste.

```
Browser ──login(email,pwd,audience)──► Gateway ──(JWT aud=cdp + cookie refresh)──► CDP API (200)
                                          │
                                          └──(JWT aud=rt vía /exchange)──► RT API (200)
```

- **JIT provisioning**: si la app destino no conoce al usuario, lo aprovisiona desde los claims del JWT.
- **Audit trail**: `auth_events` registra login_success/failure, token_exchange, logout con IP+UA.
- **Multi-tenant**: organizations + RBAC (owner · admin · lead · analyst · operator · viewer · red_team_lead).
- **Roadmap**: RS256 + JWKS para rotación sin secreto compartido.

Detalle → [`docs/sso.md`](./docs/sso.md)

---

## Capturas

> Las capturas reflejan el estado actual del producto. Datos demo, branding consistente entre apps.

| | |
|:---:|:---:|
| ![Centro de Operaciones](./screenshots/hub-overview.png) | ![CDP — alertas](./screenshots/cdp-alerts.png) |
| **Centro de Operaciones** — KPIs cross-ecosystem y salud en vivo | **FLK0S-CDP** — pipeline de alertas SOC |
| ![RT — campañas](./screenshots/rt-campaigns.png) | ![AI — copilot](./screenshots/ai-copilot.png) |
| **FLK0S-RT** — control de campañas y agentes | **FLK0S-AI** — copiloto táctico LLM-agnóstico |
| ![Reportes — engagement](./screenshots/reportes-engagement.png) | ![SSO — switcher](./screenshots/login-switcher.png) |
| **FLK0S-Reportes** — engagements y findings | **Login estándar** — cross-app switcher con accent |

Galería completa → [`screenshots/`](./screenshots)

---

## Stack

| Capa | Tecnologías |
|---|---|
| **Frontend** | Next.js 14 · React 18 · TypeScript · Tailwind · Framer Motion · shadcn/ui · next-intl |
| **Backend** | FastAPI · Pydantic v2 · SQLAlchemy 2 async · asyncpg · Celery |
| **Almacenamiento** | Postgres 16 · Redis 7 · ClickHouse · OpenSearch · Qdrant · MinIO (S3) |
| **Auth** | JWT (HS256 → RS256+JWKS) · cookies HttpOnly · bcrypt · RBAC + scopes |
| **Observabilidad** | OpenTelemetry · Prometheus · Loki · Tempo · Grafana |
| **Infra dev** | Docker Compose · Caddy (TLS local, subdominios) · Playwright e2e |

---

## Demo Mode

El ecosistema arranca con datos demo realistas — nunca pantallas vacías. Una organización (`acme-soc`), tres usuarios (admin/analyst/operator), alertas con severidades mixtas, campañas Red Team en marcha, engagements con findings, IOC pack precargado, agentes IA con conversaciones.

```bash
# Quickstart
./scripts/setup.sh          # detecta docker, genera secrets, arranca stack
./scripts/bootstrap.sh      # corre seeds demo + verifica SSO end-to-end
open https://hub.flk0s.local
```

Login: `demo@flk0s.local` / `FLK0S-demo-2026`

Detalle → [`docs/demo-mode.md`](./docs/demo-mode.md)

---

## Principios de diseño

1. **Premium · operacional · táctico.** Estética SOC, no startup landing. Dark first. Severidades SOC homogéneas (rojo · naranja · ámbar · verde · azul).
2. **Una identidad por usuario, no una por app.** SSO real, JIT, audit por defecto.
3. **Token-agnostic UI components.** Diseño compartido entre 4 paletas distintas mediante inline `hsl()` accents + tokens neutros.
4. **Observabilidad como ciudadano de primera clase.** Cada backend traceado y scrapeado por defecto. No hay servicio sin `/metrics`.
5. **Cada acción audita.** Login, exchange, logout, reset demo — todo aparece en `auth_events` o en logs estructurados.
6. **Plug & play.** El owner instala docker, corre un script y tiene el ecosistema completo en local en <5 minutos.

---

## Roadmap

- ✅ **Fase 1 — SSO core**: shared secret + JWT por audience + JIT por app
- ✅ **Fase 2 — Identity DB**: Postgres dedicado al gateway con orgs/users/audit/refresh sessions
- 🚧 **Fase 3 — Cookie cross-subdomain + delegated login**: Caddy + `*.flk0s.local`, login de cada app delegado al gateway
- ⏳ **Fase 4 — RS256 + JWKS**: rotación de claves sin secreto compartido
- ⏳ **Hosted demo**: instancia pública con auto-reset por sesión
- ⏳ **CLI**: `flk0s` para gestionar tenants / orgs / usuarios desde shell

Detalle → [`docs/roadmap.md`](./docs/roadmap.md)

---

## Documentación

- [`docs/architecture.md`](./docs/architecture.md) — arquitectura del ecosistema
- [`docs/sso.md`](./docs/sso.md) — SSO, JIT, audit
- [`docs/observability.md`](./docs/observability.md) — OTel + métricas + dashboards
- [`docs/demo-mode.md`](./docs/demo-mode.md) — datos demo y presentation mode
- [`docs/networking.md`](./docs/networking.md) — Caddy + subdominios + cookies
- [`docs/quickstart.md`](./docs/quickstart.md) — instalación local end-to-end
- [`docs/design-principles.md`](./docs/design-principles.md) — filosofía de diseño y UX

---

## Estado

| Componente | Estado | Notas |
|---|---|---|
| Auth Gateway | ✅ Live | v0.2.0 · Postgres · audit |
| FLK0S-CDP | ✅ Live | SOC pipeline · multi-tenant |
| FLK0S-RT | ✅ Live | campañas + agentes |
| FLK0S-AI | ✅ Live | copiloto + RAG |
| FLK0S-Reportes | ✅ Live | engagements + findings |
| Centro de Operaciones | ✅ Live | hub cross-app |
| Observabilidad | ✅ Live | 4 backends instrumentados |
| Caddy subdomains | 🚧 Owner setup | manual paths documentados |
| Demo dataset | ✅ Seed idempotente | reset on-demand |

---

## Autor

Construido por **@saamuuh** como portfolio técnico — full-stack + security + UX + observabilidad. Disponible para entrevistas técnicas y discusión arquitectónica.

> *Si esto se parece a una plataforma SaaS real, es porque la intención fue construir una.*
