# Demo Mode

> El ecosistema nunca debe verse vacío. Una persona que evalúa FLK0S por 90 segundos
> tiene que ver datos realistas, severidades mezcladas y actividad cross-app.

## Filosofía

Demo Mode NO es "datos lorem ipsum". Es un dataset realista que cuenta una historia operacional creíble: una organización SOC ficticia (**ACME SOC**) está respondiendo a una intrusión activa, mientras el equipo Red Team tiene una campaña en marcha, el copiloto AI está investigando IOCs, y Reportes tiene engagements en distintas fases.

Cuando un evaluador hace login, ve **una empresa real haciendo cosas reales**.

## Dataset

### Organización

| Campo | Valor |
|---|---|
| Slug | `acme-soc` |
| Nombre | ACME SOC · Defense & Response |
| Tier | Enterprise |

### Usuarios

| Email | Password | Rol | Notas |
|---|---|---|---|
| `demo@flk0s.local` | `FLK0S-demo-2026` | admin | Acceso completo, visible en logs como "Operador Demo" |
| `analyst@acme-soc.flk0s.local` | `FLK0S-demo-2026` | analyst | SOC analyst, asignado a casos |
| `operator@acme-soc.flk0s.local` | `FLK0S-demo-2026` | operator | Triage + respuesta |
| `redteam@acme-soc.flk0s.local` | `FLK0S-demo-2026` | red_team_lead | Acceso RT |

### FLK0S-CDP (Cyber Defense Platform)

- **15+ alertas** con severities mezcladas (4 critical, 3 high, 5 medium, 3 low):
  - "Suspicious PowerShell encoded command on FIN-WS-08"
  - "Brute-force SSH from 185.220.x (Tor exit node)"
  - "Anomalous Kerberos TGS request — possible Kerberoasting"
  - "Outbound C2-like beacon to 92.118.x · 5min cadence"
  - "Detection rule fired: T1059.001 PowerShell execution"
  - ...
- **5+ casos abiertos**: 2 In Progress, 1 Containment, 1 Eradication, 1 Lessons Learned.
- **IOC pack** precargado: 30+ IOCs (IPs, hashes SHA256, domains, CVE) de ATT&CK groups conocidos (Lazarus, APT29, FIN7).
- **Detection rules**: 12+ reglas Sigma activas con telemetría.
- **SIEM targets** configurados: Splunk · Sentinel · Elastic (stubs).

### FLK0S-RT (Red Team)

- **3 campañas activas**:
  - "ACME Q2 Phishing Assessment" (en fase Lateral Movement)
  - "Internal Pentest · Tier-1 Apps" (en fase Initial Recon)
  - "Adversary Emulation · APT29 TTPs" (en fase Persistence)
- **8 agentes desplegados** con beacons recientes (algunos check-in vivo, otros stale).
- **2 lateral movement chains** documentadas con MITRE ATT&CK mapping.
- **Findings**: 15+ findings con severities y status (open/triaged/remediated).

### FLK0S-AI (Copilot)

- **5 conversaciones de ejemplo**:
  - "Investiga este IOC: 92.118.39.x"
  - "Resume el incidente CDP-2026-014"
  - "Genera regla Sigma para esta amenaza"
  - "¿Qué TTPs de Lazarus aplican aquí?"
  - "Triage de esta alerta: ¿FP o real?"
- **Knowledge base** indexada en Qdrant: 50+ documentos (playbooks, runbooks, MITRE ATT&CK frames).
- **3 agentes**: investigator · responder · hunter (stateless, claims-only auth).

### FLK0S-Reportes

- **2 engagements** en distintas fases:
  - "ACME Q2 External Assessment" (Draft → 60% completo)
  - "ACME Insider Threat Investigation" (Final Review)
- **8 findings** con severities, evidence (PDFs mock), screenshots, recommendations.
- **3 deliverables**: executive summary · technical report · remediation playbook.

### Centro de Operaciones (hub)

Como agrega de las 4 apps, no tiene seed propio — refleja en vivo lo que las 4 apps tienen:
- KPIs reales: alertas abiertas, campañas activas, agentes vivos, reportes en draft.
- Activity feed: últimas 20 acciones cross-app.
- Salud: probes a las 4 apps + observabilidad.
- Severities homogéneas: el dashboard mezcla rojos/naranjas/ámbar de las 4.

## Seeds idempotentes

Cada app tiene un script `seeds/demo_dataset.py` que se ejecuta con:

```bash
docker compose exec <app>-api python -m seeds.demo_dataset
```

El script:
1. crea la organización `acme-soc` si no existe (`get_or_create(slug=...)`)
2. crea los usuarios si no existen (idempotente por email)
3. crea las entidades base (alerts, campaigns, etc.) **sin duplicar** — usa una clave natural (título + org) para `ON CONFLICT DO NOTHING`
4. NO toca registros creados por usuarios reales fuera del demo set (los demos llevan `tags=["demo"]` o `created_by="demo-seed"`)

## Presentation Mode (reset)

Para demos en vivo donde queremos volver al estado limpio entre sesiones:

```bash
./scripts/presentation-reset.sh
```

Que internamente:
1. para los workers (CDP/RT) para evitar carreras
2. en cada app llama a `POST /admin/demo/reset` (gated por rol admin + `ENVIRONMENT=demo`)
3. el endpoint trunca tablas demo-tagged (`WHERE created_by='demo-seed'`)
4. re-ejecuta `seeds/demo_dataset.py`
5. reinicia los workers
6. el gateway NO se resetea — orgs y users sobreviven, el audit log se mantiene como histórico de la demo

Tiempo total: ~25 segundos.

## Garantías

- **Nunca pantallas vacías.** Cada vista clave tiene al menos 3 registros visibles.
- **Severities mezcladas.** Ninguna lista es todo "info" o todo "critical" — el ojo debe escanear y discriminar.
- **Datos creíbles.** IPs/hashes/dominios vienen de threat reports públicos. No "192.168.1.1" ni "test@test.com".
- **Coherencia cross-app.** Un IOC de CDP aparece referenciado en una conversación AI y en un finding de Reportes.
- **Tiempos realistas.** `created_at` distribuido en los últimos 14 días, no todos en el mismo segundo.
- **Idempotente.** Re-correr el seed nunca duplica registros.

## Lo que demo mode NO incluye

- Conexiones reales a APIs externas (VirusTotal, OTX, Shodan, AbuseIPDB) — si las keys están vacías, las cards muestran badges "no configurado" en vez de fallar.
- LLM keys — si no hay `ANTHROPIC_API_KEY/OPENAI_API_KEY/GROQ_API_KEY`, el copiloto AI muestra las conversaciones precargadas pero deshabilita nuevas queries con un toast informativo.
- SIEM targets reales — Splunk/Sentinel/Elastic son stubs documentados.
