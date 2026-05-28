# ════════════════════════════════════════════════════════════════════════════
# FLK0S · install-hosts.ps1
# Añade las entradas *.flk0s.local al hosts del sistema.
# REQUIERE PRIVILEGIOS DE ADMINISTRADOR.
#
# Auto-elevación: el script se re-lanza como admin si no lo es ya.
# Idempotente: si las entradas ya están, no las duplica.
# ════════════════════════════════════════════════════════════════════════════

[CmdletBinding()]
param([switch]$Remove)

$ErrorActionPreference = "Stop"

# ── Self-elevate ──────────────────────────────────────────────────────────
function Test-Admin {
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    return ([System.Security.Principal.WindowsPrincipal]::new($id)).IsInRole(
        [System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host "Re-lanzando como administrador..." -ForegroundColor Yellow
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName        = "powershell.exe"
    $psi.Arguments       = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" + $(if ($Remove) { " -Remove" })
    $psi.Verb            = "RunAs"
    $psi.UseShellExecute = $true
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    exit 0
}

# ── Configuración ─────────────────────────────────────────────────────────
$HostsFile = "C:\Windows\System32\drivers\etc\hosts"
$Marker    = "# FLK0S ecosystem (managed by install-hosts.ps1)"

$Entries = @(
    "127.0.0.1 hub.flk0s.local",
    "127.0.0.1 cdp.flk0s.local       api.cdp.flk0s.local",
    "127.0.0.1 rt.flk0s.local        api.rt.flk0s.local",
    "127.0.0.1 ai.flk0s.local        api.ai.flk0s.local",
    "127.0.0.1 reportes.flk0s.local  api.reportes.flk0s.local",
    "127.0.0.1 auth.flk0s.local"
)

# ── Apply ─────────────────────────────────────────────────────────────────
$content = Get-Content $HostsFile -Raw -ErrorAction SilentlyContinue
if ($null -eq $content) { $content = "" }

# Quita el bloque previo si existe (idempotente)
$pattern = "(?ms)" + [regex]::Escape($Marker) + ".*?# /FLK0S\r?\n?"
$content = [regex]::Replace($content, $pattern, "")
$content = $content.TrimEnd("`r","`n")

if (-not $Remove) {
    $block = "`r`n$Marker`r`n" + ($Entries -join "`r`n") + "`r`n# /FLK0S`r`n"
    $content += $block
    Set-Content -Path $HostsFile -Value $content -Encoding ASCII -Force
    Write-Host "`n✓ Hosts añadidos para FLK0S" -ForegroundColor Green
    Write-Host "Entradas:" -ForegroundColor Cyan
    $Entries | ForEach-Object { Write-Host "  $_" }
} else {
    Set-Content -Path $HostsFile -Value $content -Encoding ASCII -Force
    Write-Host "`n✓ Bloque FLK0S removido del hosts" -ForegroundColor Green
}

# Flush DNS cache para que los cambios entren ya
ipconfig /flushdns | Out-Null
Write-Host "`nDNS cache flushed."

Write-Host "`nPresiona Enter para cerrar..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
