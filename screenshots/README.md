# Screenshots

> Capturas tomadas del producto real. Datos demo de `acme-soc`. Dark mode oficial.

## Recomendado (orden sugerido para portfolio / LinkedIn)

1. **`hub-overview.png`** — Centro de Operaciones, KPIs cross-app, salud en vivo, feed.
2. **`login-switcher.png`** — Login estándar con EcosystemSwitcher (los 4 accents visibles, el activo brillando).
3. **`cdp-alerts.png`** — FLK0S-CDP, pipeline de alertas SOC con severidades mezcladas.
4. **`cdp-case-detail.png`** — Detalle de un caso, timeline, evidence, IOCs vinculados.
5. **`rt-campaigns.png`** — Vista de campañas activas con MITRE ATT&CK mapping.
6. **`rt-agent-detail.png`** — Detalle de agente desplegado, últimos beacons, kill chain.
7. **`ai-copilot.png`** — Copilot AI investigando un IOC con RAG.
8. **`reportes-engagement.png`** — Engagement con findings, evidence, deliverables.
9. **`grafana-overview.png`** — Dashboard FLK0S Overview en Grafana.
10. **`grafana-auth-gateway.png`** — Dashboard Auth Gateway (login ratio, latency).

## Especificaciones técnicas

- Resolución: 1920×1200 (zoom 100% del navegador).
- Window chrome: oculto (capture solo viewport del navegador).
- Hora del sistema: ajustada para que `created_at` se vea reciente ("hace 2 minutos", no "hace 3 meses").
- Datos visibles: solo del seed demo (`tags=["demo"]`, `created_by="demo-seed"`).
- Cursor: oculto (sin highlights de elementos).
- Tabs: solo la app actual + máximo 1 adicional.

## Cómo regenerar

1. Asegurarse de que el demo dataset está limpio:
   ```bash
   ./scripts/presentation-reset.sh
   ```
2. Abrir cada pantalla en el navegador (recomendado: Chrome con extensión Awesome Screenshot para captures completos).
3. Hacer login con `demo@flk0s.local`.
4. Capturar y guardar con el nombre exacto del listado.
5. Optimizar:
   ```bash
   pngquant --quality=80-95 --ext .png --force screenshots/*.png
   ```

## Estado actual

Las capturas se generan al momento de cada release del showcase. Si este directorio
está vacío, ejecutar el flujo descrito arriba.
