# FLK0S — Roadmap 2026

> Hoja de ruta de producto. Base: RC v1.0 cerrada (SSO/RBAC/MFA verificados; Hub datos estáticos;
> ticketing fragmentado; planes definidos pero sin enforcement). 2026-06-01.

---

## v1.0 — Release Candidate ✅ (cerrada, 2026-06-01)
Base del ecosistema, lista para portfolio/demo:
- 4 apps + Hub + gateway con SSO único (login una vez → 4 apps), MFA TOTP, RBAC por tiers.
- Seguridad verificada E2E (RBAC, anti-bypass, headers, aislamiento de audiencia).
- Instalación casi-un-clic (Windows + Docker), observabilidad e2e, datos demo.
- Documentación completa de release y comercial.

---

## v1.1 — "Pilotable" (objetivo: Q3 2026)
**Tema: cerrar la brecha demo → uso real en empresa.** (Detalle en `PLAN-V1.1.md`.)
- **Datos vivos en el Hub** (agregación real cross-backend) — el mayor salto de credibilidad.
- **Ticketing unificado** en el Hub (cruza alertas CDP / hallazgos Reporter / tareas RT).
- **Onboarding sin fricción** (healthchecks, asistente de primer arranque, `install.sh` Linux/Mac).
- **MFA por UI** (enroll/challenge/recovery desde el navegador).
- **Monetización activa**: enforcement de quotas + página de planes/upgrade (Stripe).
- **Calidad**: CI por repo, componentes design-system compartidos (EmptyState/Skeleton/Toast),
  CSP/HSTS en dev, tests E2E de flujos críticos, rebuild para `--no-server-header`.
- **Criterio de cierre:** un cliente instala, ve datos reales, usa ticketing, activa MFA y opera con su plan.

---

## v1.2 — "Operable a diario" (objetivo: Q4 2026)
**Tema: profundidad operativa y confianza.**
- Notificaciones (alertas → email/Slack/webhook) y digest diario en el Hub.
- Dashboards Grafana curados embebidos por módulo + export.
- Roles/permisos más finos (custom roles por org, no solo viewer/operator/admin).
- Auditoría consultable desde la UI (hoy en DB) + export para compliance.
- Plantillas: informes Reporter, reglas de detección CDP, playbooks RT.
- Backups gestionados por tenant + restauración.
- Hardening de despliegue: secrets manager, rotación automática, rate-limit cross-app.

---

## v2.0 — "SaaS gestionado y extensible" (objetivo: 2027)
**Tema: plataforma comercial a escala.**
- **SaaS multi-tenant gestionado** (cloud) con alta disponibilidad y multi-región.
- **SSO externo** OIDC/SAML (Okta, Azure AD, Google Workspace) como feature Enterprise.
- **Marketplace** de detecciones, workflows IA y plantillas de informe (ecosistema de terceros).
- **Ticketing avanzado**: SLA, automatizaciones, integraciones (Jira/ServiceNow).
- **Billing cross-suite** (hoy solo en CDP) unificado en el gateway.
- **Renombrado interno completo** `cyberia`→`flk0s` + migración de DB (Fase C, deuda técnica).
- **API pública + SDK** para integraciones de cliente.
- **Auth Fase 4**: RS256 + JWKS (rotación sin secreto compartido).

---

## Principios de priorización
1. **Credibilidad antes que features**: datos vivos > nuevo módulo.
2. **Integración como diferenciador**: invertir en lo que une los módulos (ticketing, Hub), no en profundizar uno solo.
3. **Monetización temprana pero honesta**: activar planes en v1.1, IA por consumo medido.
4. **No reabrir lo cerrado**: seguridad e identidad (v1.0) son base estable; construir encima, no rehacer.

## Resumen
| Versión | Tema | Hito |
|---------|------|------|
| v1.0 ✅ | Base + seguridad | Portfolio / demo |
| v1.1 | Pilotable | Primer cliente real |
| v1.2 | Operable a diario | Retención / compliance |
| v2.0 | SaaS a escala | Comercialización plena |
