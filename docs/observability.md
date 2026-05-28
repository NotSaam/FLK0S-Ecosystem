# Observabilidad

> Cada backend del ecosistema está instrumentado por defecto. La capacidad de
> hacer debugging cross-app es lo que diferencia un ecosistema de una carpeta
> con apps dentro.

## Stack

```
        ┌─────────────────────────────────────────────────┐
        │ Gateway · CDP API · RT API · AI API · Reportes  │
        └────────────────────┬────────────────────────────┘
                             │ OTLP (gRPC/HTTP)
                             ▼
                  ┌─────────────────────┐
                  │   OTel Collector    │
                  └──────┬──────┬───────┘
                         │      │
              ┌──────────┘      └──────────┐
              ▼                            ▼
        ┌──────────┐                  ┌──────────┐
        │ Tempo    │                  │ Prom     │
        │ (traces) │                  │ (metrics)│
        └──────────┘                  └──────────┘
              ▲                            ▲
              │      ┌──────────┐          │
              │      │  Loki    │          │
              │      │  (logs)  │          │
              │      └──────────┘          │
              │            ▲               │
              └────────────┴───────────────┘
                           │
                    ┌──────────────┐
                    │   Grafana    │
                    │   :3001      │
                    └──────────────┘
```

| Componente | Puerto | Rol |
|---|---|---|
| **OTel Collector** | 4317 (gRPC), 4318 (HTTP) | Recibe traces/metrics/logs, los enruta |
| **Tempo** | 3200 | Traces almacén |
| **Prometheus** | 9090 | Métricas scrape + storage |
| **Loki** | 3100 | Logs |
| **Grafana** | 3001 | Panel único |

> Nota: Tempo usa puerto interno 3200 que NO colisiona con FLK0S-RT :3200 porque
> está en network Docker interna; Grafana expone :3001 al host, no 3000 (3000 es del hub).

## Instrumentación

### FastAPI (los 4 backends + gateway)

```python
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from prometheus_fastapi_instrumentator import Instrumentator

# Auto-instrument: traces de cada request HTTP
FastAPIInstrumentor.instrument_app(app)

# Metrics: /metrics endpoint Prometheus
Instrumentator().instrument(app).expose(app, endpoint="/metrics")
```

Atributos OTel custom propagados:
- `tenant_id` (de los claims del JWT)
- `user_id`
- `audience`
- `flk0s.app` (`cdp`/`rt`/`airt`/`reporter`/`gateway`)

### Next.js (los 4 frontends + hub)

Browser-side OTel cuando se habilita la flag de demo (off por defecto). Las páginas server-rendered se tracean en el adaptador edge.

## Métricas clave que ya están

| Backend | Métrica | Significado |
|---|---|---|
| Todos | `http_requests_total{method,endpoint,status}` | RPS por endpoint |
| Todos | `http_request_duration_seconds_bucket` | Latencia p50/p95/p99 |
| Gateway | `auth_login_attempts_total{result}` | Login success vs failure |
| Gateway | `auth_active_refresh_sessions` | Sesiones vivas |
| CDP | `alerts_ingested_total{severity}` | Tasa de ingestión por severidad |
| CDP | `cases_open` | Casos abiertos por estado |
| RT | `campaigns_active` | Campañas vivas |
| RT | `agents_beacon_total{agent_id}` | Beacons por agente |
| AI | `llm_calls_total{provider,model}` | Llamadas LLM |
| AI | `rag_query_duration_seconds` | Latencia RAG |
| Reportes | `engagements_total{status}` | Engagements por status |

## Trazas

Cada request tiene trace-id end-to-end. Ejemplo de span tree para "login en CDP via gateway":

```
gateway · POST /auth/login                      [span 1, 42ms]
├── gateway · users.verify_credentials          [span 2, 18ms]  → asyncpg
├── gateway · users.update last_login_at        [span 3, 4ms]
├── gateway · jwt.encode access                 [span 4, <1ms]
├── gateway · jwt.encode refresh                [span 5, <1ms]
└── gateway · log_event login_success           [span 6, 3ms]   → asyncpg
```

Después la app envía `Bearer <access>` a su API y se traza el JIT provisioning:

```
cdp-api · GET /api/v1/alerts                    [span 7, 31ms]
├── cdp-api · verify_gateway_token              [span 8, 2ms]
├── cdp-api · _user_from_gateway_token (JIT)    [span 9, 12ms]  → INSERT user
└── cdp-api · query alerts WHERE org_id=...     [span 10, 14ms] → SELECT
```

Filtrable en Grafana / Tempo por `service.name`, `tenant_id`, `user_id`, `flk0s.app`.

## Logs estructurados

JSON via `structlog` en backends. Campos comunes: `ts`, `level`, `event`, `service`, `trace_id`, `span_id`, `tenant_id`, `user_id`. Loki los agrega correlacionando por `trace_id`.

```json
{"ts":"2026-05-28T08:10:39Z","level":"INFO","event":"login_success","service":"flk0s-gateway","trace_id":"abc...","user_id":"8jFTgD-ffJeB1sww","email":"demo@flk0s.local","audience":"flk0s:cdp","ip":"172.25.0.1"}
```

## Dashboards Grafana incluidos

1. **FLK0S Overview** — KPIs cross-app, RPS por servicio, error rates, top endpoints.
2. **Auth Gateway** — login success/failure ratio, latency p95, refresh sessions activas.
3. **CDP SOC** — alerts ingestion rate por severity, IOC lookups, case throughput.
4. **RT Operations** — campañas vivas, beacons por agente, latency C2.
5. **AI Copilot** — LLM calls por modelo/proveedor, RAG latency, token usage.
6. **Reportes** — engagements per status, findings inflow, deliverable cycle time.
7. **Infra Health** — Docker containers, Postgres connections, Redis ops, MinIO ops.

## Healthchecks

| Servicio | Endpoint | Verifica |
|---|---|---|
| Gateway | `/health` | DB connection + denylist size + store backend |
| CDP API | `/api/health` | DB + Redis + ClickHouse + OpenSearch |
| RT API | `/api/health` | DB + Redis + MinIO |
| AI API | `/api/health` | Qdrant + LLM probe |
| Reportes API | `/api/health` | DB + Redis + MinIO |
| Hub | `/api/health` | Probe a las 4 apps |

Cada `docker-compose.yml` tiene `healthcheck:` con `start_period` razonable. `bootstrap.sh` espera todos `healthy` antes de seedear.

## Lo que falta

- **OTel browser-side por defecto** — actualmente off para no enviar PII a Tempo en dev.
- **Alertas Prometheus configuradas** — dashboards sí, alertmanager no aún.
- **Trace propagation a las external APIs** (VirusTotal, etc.) — necesita W3C TraceContext en el cliente.
- **SLO dashboards** — definir SLOs por app y trackearlos.
