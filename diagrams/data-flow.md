# Diagrama — Flujo de datos entre apps

```mermaid
flowchart LR
    classDef cdp fill:#082f49,stroke:#22d3ee,color:#cffafe
    classDef rt fill:#3f0a1e,stroke:#f43f5e,color:#fecdd3
    classDef ai fill:#0c1a4b,stroke:#3b82f6,color:#bfdbfe
    classDef rep fill:#1e1547,stroke:#a78bfa,color:#ddd6fe
    classDef hub fill:#0f172a,stroke:#94a3b8,color:#e2e8f0

    HUB["Centro de Operaciones"]:::hub

    subgraph CDP_BLOCK["FLK0S-CDP"]
        CDP_ALERT[/"alerta SOC"/]:::cdp
        CDP_CASE[/"caso / incidente"/]:::cdp
        CDP_IOC[/"IOC ingestado"/]:::cdp
    end

    subgraph RT_BLOCK["FLK0S-RT"]
        RT_CAMP[/"campaña"/]:::rt
        RT_BEACON[/"beacon agente"/]:::rt
        RT_FIND[/"finding RT"/]:::rt
    end

    subgraph AI_BLOCK["FLK0S-AI"]
        AI_CHAT[/"conversación copilot"/]:::ai
        AI_RAG[/"RAG sobre knowledge base"/]:::ai
    end

    subgraph REP_BLOCK["FLK0S-Reportes"]
        REP_ENG[/"engagement"/]:::rep
        REP_FIND[/"finding documentado"/]:::rep
        REP_DELIV[/"deliverable"/]:::rep
    end

    CDP_ALERT --> CDP_CASE
    CDP_IOC -. enriquece .-> CDP_ALERT
    CDP_CASE -. abre engagement .-> REP_ENG
    RT_FIND -. consolida en .-> REP_FIND
    AI_CHAT -. investiga .-> CDP_IOC
    AI_RAG -. resume .-> CDP_CASE
    AI_RAG -. asiste .-> RT_BEACON

    HUB --- CDP_ALERT
    HUB --- RT_CAMP
    HUB --- AI_CHAT
    HUB --- REP_ENG
```

## Lecturas

- Alertas CDP → casos → engagements en Reportes (kill chain documental).
- IOCs centralizados en CDP, enriquecidos por AI (lookup) y referenciados por RT (atribución) y Reportes (technical detail).
- Hub agrega los 4 ejes como KPIs y feed cross-app.
