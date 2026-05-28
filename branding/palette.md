# Paleta FLK0S

> Identidad visual del ecosistema. Cada app es identificable por su accent.

## Accents por app

| App | Color | HSL | Hex | Uso |
|---|---|---|---|---|
| **CDP** | cyan eléctrico | `hsl(191, 100%, 50%)` | `#00d9ff` | defensa, alerta, scanning |
| **RT** | rojo táctico | `hsl(347, 100%, 60%)` | `#ff3366` | ofensiva, urgencia, lethal |
| **AI** | azul eléctrico | `hsl(218, 100%, 50%)` | `#0066ff` | cognición, profundidad |
| **Reportes** | púrpura | `hsl(258, 90%, 58%)` | `#7c3aed` | archivo, formal |
| **hub** | neutral grafito + accents superpuestos | n/a | `#0f172a` | agregador |

## Neutros del ecosistema (dark first)

| Token | HSL | Hex | Uso |
|---|---|---|---|
| `bg` | `220 26% 4%` | `#070a14` | fondo página |
| `bg-surface` | `220 22% 7%` | `#0e1320` | cards / panels |
| `bg-elevated` | `220 18% 11%` | `#171c2e` | panels destacados |
| `bg-border` | `220 14% 18%` | `#252c40` | bordes sutiles |
| `text` | `210 20% 96%` | `#eef1f6` | texto principal |
| `text-muted` | `215 14% 65%` | `#9aa3b2` | secundario |
| `text-dim` | `217 11% 42%` | `#5e6678` | terciario / hint |

## Severidades SOC homogéneas (compartidas por las 4 apps)

| Severidad | HSL | Hex |
|---|---|---|
| `critical` | `0 84% 60%` | `#ef4444` |
| `high` | `25 95% 53%` | `#f97316` |
| `medium` | `38 92% 50%` | `#f59e0b` |
| `low` | `142 71% 45%` | `#22c55e` |
| `info` | `217 91% 60%` | `#3b82f6` |

## Tipografía

- **Display**: `Inter`, weight 700 — títulos, hero numbers.
- **Sans**: `Inter`, weight 400-500 — texto general, chrome.
- **Mono**: `JetBrains Mono`, weight 400-500 — datos, IDs, código, métricas.

Tracking: `tight` en display (`-0.02em`), `normal` en sans, `wide` en chips mono (`0.05em-0.25em`).

## Iconos

- **lucide-react** (familia consistente, weight 1.5px stroke).
- Mismo set en las 4 apps + hub.
- Tamaños canónicos: 14px (chip), 16px (botón), 20px (sidebar), 24px (hero card).

## Motion

- Framer Motion con spring `damping: 24, stiffness: 200`.
- Reveal page: 550ms.
- Hover chip/button: 150-200ms.
- Layout shifts: 280ms con `ease-out`.
- `prefers-reduced-motion` respetado — reduce a 50ms / disable spring.

## Glow / depth

Glow se usa **solo para transmitir estado**, no como decoración:

- chip activo del EcosystemSwitcher → `boxShadow: 0 0 16px hsl(<accent> / 0.4)`
- severity badge critical → `boxShadow: 0 0 8px hsl(0 84% 60% / 0.5)`
- live health dot pulse → animación `breathe` con shadow expandido

No usar glow en cards estáticas ni en hover de elementos no-interactivos.
