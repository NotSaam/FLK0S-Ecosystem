# FLK0S — Cybersecurity Operations Platform

> Entrada principal de portfolio.

## Qué es
FLK0S es una **plataforma unificada de operaciones de ciberseguridad**: un ecosistema de seis servicios
que reúne defensa (Blue Team), ataque controlado (Red Team), automatización con agentes de IA y reporting
profesional bajo un **único inicio de sesión** y un Centro de Operaciones común.

## El problema
Los equipos de seguridad operan con herramientas fragmentadas —SIEM, plataformas de pentesting, hojas de
cálculo para informes, scripts de automatización— cada una con su identidad, su estética y sus datos. Eso
genera fricción, errores, formación lenta y una experiencia que no parece producto. FLK0S resuelve la
**cohesión**: una sesión, una estética, un modelo de identidad, cuatro disciplinas conectadas.

## Arquitectura
- **6 servicios**: Hub (Centro de Operaciones), Auth Gateway (identidad/SSO), FLK0S-CDP (Blue), FLK0S-RT
  (Red), FLK0S-AI (agentes), FLK0S-Reportes (reporting).
- **SSO con token-exchange**: una cookie de sesión en el gateway → access token por aplicación (`audience`);
  cada backend valida firma + audiencia + emisor y aísla por organización.
- **Multi-tenant** desde el modelo de datos (organizaciones), con RBAC por tiers.
- **Monorepo**: frontends Next.js 14 (pnpm + Turborepo) + backends FastAPI por servicio + Docker Compose.
- **Observabilidad e2e**: OpenTelemetry + Prometheus + Grafana + Tempo.

## Tecnologías
`Next.js 14` · `TypeScript` · `FastAPI` · `Python` · `PostgreSQL` · `Redis` · `JWT/HS256` · `TOTP/MFA` ·
`Docker Compose` · `Caddy` · `OpenTelemetry` · `Grafana` · `pnpm` · `Turborepo`.

## Seguridad (lo más destacable técnicamente)
- **SSO único** verificado end-to-end (login una vez → 4 apps sin re-autenticar; logout global con revocación).
- **MFA TOTP** completo: enroll → challenge → verify → códigos de recuperación.
- **RBAC enforced** por tiers (viewer/operator/admin), con matrices 401/403/200 verificadas en runtime.
- **Cierre de un bypass real de privilegios**: el provisioning JIT reutilizaba el rol local sin re-sincronizar
  con el claim del gateway → un viewer podía heredar rol elevado. Detectado y corregido (re-sync del rol como
  fuente de verdad) en RT, Reporter y CDP; verificado anti-bypass.
- **Cabeceras de seguridad**, cookies HttpOnly, audit trail en PostgreSQL, 0 secretos en el repositorio.

## Escalabilidad
- Multi-tenant por organización; modelo de planes (Free/Starter/Pro/Enterprise) con quotas y enforcement.
- Diseñado para evolución a SaaS gestionado y a RS256+JWKS (rotación de claves sin secreto compartido).

## Qué desarrollé personalmente
El ecosistema completo end-to-end: arquitectura, el gateway de identidad (SSO/MFA/RBAC/audit), los cuatro
módulos (front + back), el Hub con datos vivos agregados vía SSO, el ticketing unificado cross-app, la capa
de observabilidad, el design-system compartido y la experiencia de instalación casi de un clic.

## Dificultades técnicas resueltas
- **Sesión única real cross-origin** en localhost (cookie same-site cross-puerto) y en enterprise (subdominios + Caddy).
- **Coherencia de identidad** entre servicios independientes vía token-exchange + JIT provisioning sin mezclar tenants.
- **Bypass de RBAC** por rol stale en el provisioning JIT (descrito arriba).
- **Agregación de datos vivos** en un Hub estático sin acoplar servicios (cliente agrega vía SSO; arquitectura extensible).
- **Cohesión visual** entre apps independientes mediante un preset de diseño compartido.

## Resultados
- Plataforma funcional con 6 servicios, verificada en runtime (seguridad, SSO, MFA, RBAC, ticketing, observabilidad).
- Instalación reproducible casi de un clic; documentación de producto y comercial completa.
- Base sólida y honestamente valorada: ~80% como software, con la "última milla" comercial/operativa
  identificada y planificada (ver `PRODUCT-VALUATION.md`).
