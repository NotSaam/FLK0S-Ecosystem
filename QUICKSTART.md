# FLK0S — Quickstart (de cero a funcionando en ~10 min)

> Objetivo: clonar → un script → todo funciona. Probado en Windows 11 + Docker Desktop.

## Requisitos previos (una sola vez)
- **Windows 10/11**
- **Docker Desktop** instalado y **abierto** (el engine debe responder — el instalador lo valida).
- **PowerShell** (incluido en Windows).
- ~8 GB RAM libres para el stack.

## Instalación (1 comando)
```powershell
git clone <repo-url> FLK0S
cd FLK0S
.\install.ps1
```
`install.ps1` hace **todo automáticamente**:
1. Valida prerequisitos (Docker engine, Compose v2, Python opcional).
2. Genera los `.env` con secretos locales.
3. Levanta el ecosistema (gateway + 4 backends + 4 frontends + observabilidad).
4. Espera a que el gateway responda `/health`.
5. Siembra los datos demo (historia ACME SOC).
6. **Abre el navegador en el Hub.**

Al terminar verás:
```
 Entra por:  http://localhost:3000
 Demo:       demo@flk0s.local / FLK0S-demo-2026   (solo lectura)
 Trusted:    trusted@flk0s.local / FLK0S-trusted-2026   (operador)
```

## Uso diario
```powershell
.\start.ps1     # arranca todo
.\stop.ps1      # detiene todo
```

## Acceso
1. Abre **http://localhost:3000** (Centro de Operaciones).
2. Inicia sesión **una vez** con `demo@` o `trusted@`.
3. Navega a CDP / RT / AI / Reportes desde las tarjetas o `Ctrl+K` — **sin volver a autenticarte**.

> Nota: los frontends Next tardan ~20-40 s en compilar la primera vez. El Hub (estático) carga al
> instante y hace de cockpit mientras tanto.

## Modo enterprise (opcional — URLs bonitas + TLS)
```powershell
.\install.ps1 -Enterprise   # subdominios *.flk0s.local + Caddy (pide elevación UAC una vez)
```
Instala Caddy (winget), añade los hosts y configura TLS local. El **mecanismo SSO es el mismo**; esto
solo cambia `localhost:3000` por `https://hub.flk0s.local`.

## Diagnóstico
```powershell
python FLK0S-Ecosystem\scripts\doctor.py    # chequeo de salud del ecosistema
```

## Limitaciones conocidas (one-click honesto)
- Requiere **Docker Desktop abierto** antes de `install.ps1` (si el engine no responde, el script avisa y para).
- Tras cambios de código en un backend: `docker compose up -d --build <servicio>` (las imágenes son baked).
- Primera compilación de frontends: 20-40 s (normal en Next dev).

**Tiempo total desde cero:** ~10 min (mayoría = pull de imágenes Docker la primera vez).
