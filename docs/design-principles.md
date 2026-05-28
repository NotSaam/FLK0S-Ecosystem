# Principios de diseño FLK0S

> Por qué FLK0S se ve como se ve, y por qué se siente operacional en vez de comercial.

## 1. Premium · operacional · táctico — no startup landing

FLK0S no necesita "convencer" a un usuario de que la plataforma sirve. Quien la abre ya está dentro y necesita trabajar. Por eso:

- **Dark first**, sin opción light. Equipos SOC trabajan turnos largos, monitores en penumbra.
- **Sin hero copy de marketing.** El root path operacional (`/`) hace redirect a `/dashboard` o `/login`, no a una landing. Quien quiere SaaS pitch va al README. Quien quiere usar la plataforma entra directo.
- **Sin pricing, sin "Get Started Free", sin testimonials.** Esos elementos rompen la sensación de plataforma interna.
- **Tipografía monoespaciada en datos**, sans-serif (Inter) en chrome. La diferencia visual entre "valor" (mono) y "estructura" (sans) tipifica el lenguaje de consolas operacionales.

## 2. Severidades SOC homogéneas

Cualquiera que abra CDP, RT y Reportes ve la misma escala:

| Severidad | Color | Hex base | Uso |
|---|---|---|---|
| Critical | rojo intenso | `#ef4444` | impacto inmediato, escalado |
| High | naranja | `#f97316` | requiere atención hoy |
| Medium | ámbar | `#f59e0b` | requiere atención semana |
| Low | verde | `#22c55e` | informativo, no acción |
| Info | azul | `#3b82f6` | metadata, sin severidad |

Esto NO está acoplado al accent de la app — el accent es identidad de plataforma. Las severidades son lenguaje operacional compartido.

## 3. Accent por app, no por componente

Cada app tiene un **accent único** que se siente al instante:

| App | Accent | HSL | Sensación |
|---|---|---|---|
| CDP | cyan eléctrico | `191° 100% 50%` | defensivo, alerta, scanning |
| RT | rojo táctico | `347° 100% 60%` | ofensivo, urgente, lethal |
| AI | azul eléctrico | `218° 100% 50%` | cognitivo, calmado, profundo |
| Reportes | púrpura | `258° 90% 58%` | documental, formal, archive |

El **EcosystemSwitcher** en los logins muestra los 4 accents — el operador ve de un vistazo dónde está y dónde puede ir. Click en otro accent = redirect al login de esa app.

## 4. Token-agnostic UI components

Los componentes compartidos (ej: `EcosystemSwitcher`) NO usan los tokens locales de cada paleta — usan colores **neutros + opacidades sobre white** + **inline `hsl(<accent>)` para acentos**.

```tsx
// ✅ Compila igual en las 4 apps (4 paletas distintas)
<div style={{ borderColor: `hsl(${accent})`, boxShadow: `0 0 16px hsl(${accent} / 0.3)` }}
     className="bg-white/5 hover:bg-white/10" />

// ❌ Acopla el componente al token local — rompe al copiarlo a otra app
<div className="border-cyber-500 bg-cyber-900/40" />
```

Esto permite que cambios de UI compartida se propaguen sin testing por app.

## 5. Motion premium pero contenido

- **Framer Motion** para todo lo no-trivial: enter/exit, layout shifts, modals.
- **Sin animaciones de >400ms** en chrome (sidebar, topbar, menus). Sí en transitions de página (550ms reveal).
- **Sin hover-glow excesivo.** Glow donde transmite estado (chip activo, severity badge), no como decoración.
- **Spring physics suaves** (`damping: 24, stiffness: 200`). Nada que rebote como app de redes sociales.
- **Reduced motion respetado** vía `prefers-reduced-motion`.

## 6. Spacing y rhythm

- **Sistema de 4px**: `1=4 · 2=8 · 3=12 · 4=16 · 6=24 · 8=32 · 12=48`. Nada arbitrario.
- **Card padding interno**: 20px (`p-5`) en cards densas, 32px (`p-8`) en cards hero.
- **Gap entre elementos relacionados**: 12px. Entre grupos: 24px. Entre secciones: 48px.
- **Border radius**: 6-8px en chips/buttons, 12-16px en cards, 20-24px en hero panels.

## 7. Componentes operacionales clave

| Componente | Propósito | Existe en |
|---|---|---|
| `AppSwitcher` | Saltar entre las 4 apps + hub | Chrome de las 4 |
| `CommandPalette` (Cmd+K) | Búsqueda global + acciones cross-app | Las 4 + hub |
| `EcosystemSwitcher` | Selector visual en logins | Logins CDP, RT, AI |
| `SeverityBadge` | Chip homogéneo crítico→info | Las 4 |
| `Panel` / `GlassPanel` | Contenedor estándar para datos | Las 4 |
| `KpiTile` | Métrica grande + delta | Hub + dashboards |
| `LiveHealthDot` | Estado de servicio en vivo | Hub |
| `ActivityFeed` | Stream cross-app de eventos | Hub |

## 8. Errores y empty states

- **Errores con tono operacional**, no marketing: "Token revocado · re-autentíca en el gateway" en vez de "Oops! Something went wrong".
- **Empty states siempre con call-to-action específico**: no "No data yet, get started" sino "No hay alertas hoy. Última alerta hace 8h. Configurar IOC sources →".
- **404 branded** en español, con accent de la app actual.

## 9. Internacionalización

- **100% español** en UI (CLAUDE.md mandate).
- **next-intl** en frontends, mismos keys por app (siempre que el dominio coincida).
- **Sin "es-ES" vs "es-MX"** — un solo locale `es` con vocabulario técnico SOC.
- **Inglés permitido en strings técnicos** que son universales (`null`, `forbidden`, `bearer`, `IOC`, `TTP`, `kill chain`, `phishing`...).

## 10. Accesibilidad mínima exigida

- **WCAG AA contrast** en textos sobre cards (verificado con axe).
- **Focus states visibles** en todos los interactivos (ring de 2px del accent).
- **Skip links** en chrome principal.
- **Aria-labels** en iconos solos (sin texto adyacente).
- **prefers-reduced-motion** respetado.
- **Sin trapping** de focus en modales (escape siempre cierra).

## 11. Densidad de información alta

Esto NO es un dashboard de meditación. Una vista bien diseñada de FLK0S puede mostrar:

- 12 KPIs cross-app en una pantalla 1440x900
- 30 alertas con severity, asignación, edad, fuente
- Activity feed de 20 eventos con timestamp relativo
- Salud de las 4 apps + observabilidad

Sin sentirse abrumadora — el truco es **jerarquía visual fuerte** (tamaño de fuente, opacidad, color) más que **whitespace abundante**.

## 12. Naming consistente

| Cosa | Cómo se llama (es) | NO se llama |
|---|---|---|
| Alerta SOC | "alerta" | "notificación" |
| Caso | "caso" / "incidente" | "ticket" (en CDP) |
| Engagement | "engagement" | "proyecto" |
| Campaign | "campaña" | "ejercicio" |
| Operador | "operador" | "usuario" (en chrome) |
| Severidad | "severidad" | "prioridad" |
| Centro de Operaciones | "Centro de Operaciones" / "hub" | "launchpad" (legacy) |

## 13. Lo que NO hace FLK0S visualmente

- No tiene **landings de marketing**.
- No tiene **iconos isométricos 3D**.
- No tiene **gradientes pasteles**.
- No tiene **ilustraciones humanas**.
- No tiene **typewriter effects** en hero.
- No tiene **carousels de logos de clientes**.
- No tiene **emojis** en UI (excepto donde el operador los introduce: nombres de findings, comentarios).
- No tiene **call-to-action de marketing** ("¡Pruébalo gratis!", "Hablemos") — solo CTAs operacionales ("Triage", "Asignar", "Cerrar caso").
