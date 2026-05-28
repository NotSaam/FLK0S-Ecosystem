# Arquitectura del ecosistema FLK0S

> Cómo encajan las piezas. Documento canónico — actualizarlo cuando la topología cambie.

## Topología

```mermaid
flowchart TB
    subgraph "Browser / Operador"
        U[Usuario en navegador]
    end

    subgraph "Edge (Caddy · TLS local)"
        E[hub.flk0s.local · cdp · rt · ai · reportes · auth · api.*]
    end

    subgraph "Identity"
        GW["Auth Gateway<br/>:8000<br/>FastAPI · async"]
        GWDB[("Postgres gateway-db<br/>organizations<br/>users<br/>auth_events<br/>refresh_sessions")]
    end

    subgraph "Apps · Frontend"
        HUB["Centro de Operaciones<br/>:3000"]
        CDP_F["CDP Web<br/>:3100"]
        RT_F["RT Frontend<br/>:3200"]
        AI_F["AI Frontend<br/>:3300"]
        REP_F["Reportes Frontend<br/>:3400"]
    end

    subgraph "Apps · Backend"
        CDP_A["CDP API :8080"]
        RT_A["RT API :8200"]
        AI_A["AI API :8300"]
        REP_A["Reportes API :8400"]
    end

    subgraph "Data · CDP"
        CDP_PG[("Postgres")]
        CDP_CH[("ClickHouse")]
        CDP_OS[("OpenSearch")]
        CDP_RD[("Redis")]
    end

    subgraph "Data · RT/Reportes/AI"
        RT_PG[("Postgres")]
        RT_MN[("MinIO")]
        AI_QD[("Qdrant")]
        REP_PG[("Postgres")]
        REP_MN[("MinIO")]
    end

    subgraph "Observability"
        OTEL["OTel Collector"]
        PROM["Prometheus"]
        LOKI["Loki"]
        TEMPO["Tempo"]
        GRAF["Grafana"]
    end

    U --> E
    E --> HUB & CDP_F & RT_F & AI_F & REP_F & GW
    HUB -. probe /api/health .-> CDP_F & RT_F & AI_F & REP_F
    CDP_F --> CDP_A
    RT_F --> RT_A
    AI_F --> AI_A
    REP_F --> REP_A
    GW --> GWDB

    CDP_F -. POST /auth/login + token exchange .-> GW
    RT_F -. POST /auth/login + token exchange .-> GW
    AI_F -. POST /auth/login + token exchange .-> GW
    REP_F -. POST /auth/login + token exchange .-> GW

    CDP_A --> CDP_PG & CDP_CH & CDP_OS & CDP_RD
    RT_A --> RT_PG & RT_MN
    AI_A --> AI_QD
    REP_A --> REP_PG & REP_MN

    CDP_A & RT_A & AI_A & REP_A & GW --> OTEL
    OTEL --> PROM & LOKI & TEMPO
    GRAF --> PROM & LOKI & TEMPO
```

## Capas

### 1. Edge (Caddy)

Termina TLS local con CA propia. Mapea subdominios a puertos de loopback. Cabeceras de seguridad compartidas (HSTS, X-Frame-Options, Permissions-Policy). Cookie del refresh viaja con `Domain=.flk0s.local` → SSO entre subdominios.

### 2. Identity (Auth Gateway)

FastAPI async. Emite JWTs HS256 firmados con `SECRET_KEY` compartida. Audiences canónicas: `flk0s:cdp`, `flk0s:rt`, `flk0s:airt`, `flk0s:reporter`, `flk0s:shell`.

- `/auth/login` — credenciales + audience → access token + cookie refresh.
- `/auth/token/exchange` — cookie refresh + nueva audience → access token para otra app.
- `/auth/logout` — revoca refresh (denylist + `revoked_at` en Postgres).
- `/auth/me` — introspección del token con cualquier audience.
- `/health` — incluye `store_backend` (memory/postgres).

Persistencia: `organizations` + `users(FK org)` + `auth_events` (audit inmutable) + `refresh_sessions` (jti + revocación + IP + UA).

### 3. Apps (Frontend + Backend × 4)

Cada app es **independiente** — su propio repo, propio docker-compose, propias migraciones. Aceptan dos formas de auth:

1. **Token nativo** (login propio de la app, compatibilidad legacy).
2. **Token del gateway** (HS256, mismo secret, `iss=flk0s-auth`, `aud=flk0s:<app>` → JIT provisioning local si no existe el user).

Esto permite migración progresiva sin romper nada: el day-1 de cada app puede seguir usando su login propio mientras el gateway escala.

### 4. Datos

Cada app tiene su propio stack de datos optimizado a su caso de uso:

- **CDP**: Postgres (transaccional) + ClickHouse (alert events high-volume) + OpenSearch (full-text + IOC search) + Redis (rate-limits + cache).
- **RT**: Postgres + MinIO (S3 para artefactos de campaña).
- **AI**: Qdrant (vector store RAG) + Redis (LLM call cache).
- **Reportes**: Postgres + MinIO (PDFs, evidence files).
- **Gateway**: Postgres dedicado (identity, no se mezcla con datos de apps).

### 5. Observabilidad

OTel Collector recibe traces/metrics/logs de las 4 APIs + gateway, los reparte a Prometheus / Loki / Tempo. Grafana es el panel único. Cada backend tiene `/metrics` con `prometheus-fastapi-instrumentator`.

## Principios arquitectónicos

1. **No fusionar repos.** Cada app evoluciona a su ritmo. El "ecosistema" se materializa en runtime (SSO + UX + observabilidad), no en monorepo.
2. **Separación dura entre identity y datos de app.** Gateway tiene su propia DB. Las apps confían en el JWT, no en su propio campo `users.role`.
3. **Compatibilidad aditiva.** Cada cambio mantiene viva la ruta anterior. JIT no rompe registros previos. Tokens nativos siguen aceptándose junto a tokens del gateway.
4. **Diseño compartido por tokens, no por componente.** Cada app importa el design-system (tipografía, severidades, motion) pero compone con su paleta local. Resultado: coherencia visual sin acoplamiento de código.
5. **Observabilidad por defecto.** No hay servicio sin instrumentación. La capacidad de debugging cross-app es lo que diferencia "ecosistema" de "carpeta con apps dentro".
