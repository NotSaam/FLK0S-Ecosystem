# FLK0S — Screenshot Guide

> Selección curada de capturas para presentación pública + comandos de regeneración.
> No modifica desarrollo: solo documenta qué usar y cómo regenerar.

## Selección recomendada (las mejores que ya existen)

| Uso | Archivo | Notas |
|-----|---------|-------|
| **Portada / social preview** | `FLK0S-Ecosystem/screenshots/hub-overview.png` | El cockpit — la imagen más vendedora |
| **Hub** | `FLK0S-Ecosystem/screenshots/hub-overview.png` | Centro de Operaciones completo |
| **AI** | `FLK0S-Ecosystem/screenshots/ai-copilot.png` | Copiloto de IA |
| **RT** | `FLK0S-Ecosystem/screenshots/rt-campaigns.png` · `rt-dashboard.png` | Campañas / panel red team |
| **CDP** | `FLK0S-Ecosystem/screenshots/cdp-dashboard.png` · `cdp-alerts.png` | Panel + alertas SOC |
| **Reporter** | `FLK0S-Ecosystem/screenshots/reportes-engagements.png` | Engagements |
| **Observabilidad** | `FLK0S-Ecosystem/screenshots/grafana-overview.png` | Grafana — señal de madurez |
| **Logins (opcional)** | `login-cdp.png` · `login-rt.png` · `login-ai.png` | Branding por app |

> Las 54 capturas en `.qa-shots/` son de QA (desktop/mobile/404, ruido). **No usarlas** para vitrina;
> son para verificación interna. La carpeta curada de vitrina es `FLK0S-Ecosystem/screenshots/`.

## Recomendaciones de calidad
- Usar siempre las versiones **desktop** y con **datos demo** (historia ACME) para que no salgan vacías.
- Evitar capturas con KPIs en 0 → sembrar datos antes (ver gap-analysis · datos demo).
- Para social preview de GitHub: 1280×640 px, usar `hub-overview` recortado.

## Regenerar capturas (scripts ya existentes — no tocar código)

```bash
# Stack arriba + sesión SSO inyectada (capturas autenticadas, "premium"):
node scripts/capture-screenshots-auth.mjs

# Set responsive (desktop + mobile) para QA:
node scripts/capture-responsive.mjs

# Set curado del showcase (el que alimenta el README):
node FLK0S-Ecosystem/scripts/capture-screenshots.mjs
```

Requisitos: stack levantado (`start.ps1`) + datos demo sembrados. Las capturas se guardan en las
carpetas que cada script define (`.qa-shots/` y `FLK0S-Ecosystem/screenshots/`).

## Antes de publicar (checklist)
- [ ] Regenerar el set curado con datos demo ricos.
- [ ] Verificar que ninguna captura muestra credenciales reales, IPs internas sensibles ni el C2 falso.
- [ ] Confirmar que las imágenes referenciadas en el README existen y cargan.
