#!/usr/bin/env python3
"""FLK0S · Doctor — chequeo de salud del ecosistema completo.

Verifica que:
  - Docker engine y Compose v2 están disponibles
  - Los puertos críticos no están ocupados por otros procesos
  - Gateway responde + reporta su backend de store
  - Los 4 backends de app responden /health
  - SSO end-to-end funciona (login → 4 audiences → 200)
  - Observabilidad (Prometheus + Grafana) responde
  - Caddy está corriendo (opcional) y los subdominios resuelven

Salida: exit 0 si todo verde, exit 1 si hay errores, exit 2 si hay warnings.

Uso:
  python doctor.py                   # modo estándar
  python doctor.py --verbose         # output detallado
  python doctor.py --json            # output JSON para CI
  python doctor.py --no-sso          # skip SSO smoke test
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import socket
import subprocess
import sys
import time
from dataclasses import dataclass, field
from typing import Callable, Optional

# Windows consoles default to cp1252 which cannot print unicode box-drawing.
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

try:
    import urllib.request
    import urllib.error
except ImportError:
    print("Python 3.11+ requerido", file=sys.stderr)
    sys.exit(1)


# ─── Constants ──────────────────────────────────────────────────────────────

GATEWAY_URL = os.environ.get("FLK0S_GATEWAY_URL", "http://localhost:8000")
DEMO_EMAIL = os.environ.get("FLK0S_DEMO_EMAIL", "demo@flk0s.local")
DEMO_PASSWORD = os.environ.get("FLK0S_DEMO_PASSWORD", "FLK0S-demo-2026")

APPS = [
    # (label, audience, frontend_port, backend_url_health, backend_url_protected)
    ("FLK0S-CDP",       "flk0s:cdp",      3100, "http://localhost:8080/api/v1/health", "http://localhost:8080/api/v1/alerts"),
    ("FLK0S-RT",        "flk0s:rt",       3200, "http://localhost:8200/health",        "http://localhost:8200/api/v1/campaigns"),
    ("FLK0S-AI",        "flk0s:airt",     3300, "http://localhost:8300/health",        "http://localhost:8300/api/v1/agents"),
    ("FLK0S-Reportes",  "flk0s:reporter", 3400, "http://localhost:8400/health",        "http://localhost:8400/api/v1/engagements/"),
]

PORTS_TO_CHECK = [3000, 3100, 3200, 3300, 3400, 8000, 8080, 8200, 8300, 8400]
OBS_ENDPOINTS = [
    ("Grafana",    "http://localhost:3001/api/health"),
    ("Prometheus", "http://localhost:9091/-/healthy"),
]

# Subdominios del ecosistema servidos por Caddy (networking enterprise). Opcional
# en dev: requieren entradas en hosts (ver install-hosts.ps1).
SUBDOMAINS = [
    "hub.flk0s.local",
    "cdp.flk0s.local",
    "rt.flk0s.local",
    "ai.flk0s.local",
    "reportes.flk0s.local",
]


# ─── Result types ───────────────────────────────────────────────────────────

OK = "OK"
WARN = "WARN"
FAIL = "FAIL"


@dataclass
class Check:
    name: str
    status: str = "PENDING"
    detail: str = ""
    elapsed_ms: int = 0

    def to_dict(self) -> dict:
        return {"name": self.name, "status": self.status, "detail": self.detail, "elapsed_ms": self.elapsed_ms}


@dataclass
class Report:
    checks: list[Check] = field(default_factory=list)

    def add(self, c: Check) -> Check:
        self.checks.append(c)
        return c

    def summary(self) -> tuple[int, int, int]:
        ok = sum(1 for c in self.checks if c.status == OK)
        warn = sum(1 for c in self.checks if c.status == WARN)
        fail = sum(1 for c in self.checks if c.status == FAIL)
        return ok, warn, fail


# ─── Helpers ────────────────────────────────────────────────────────────────

def _run(cmd: list[str], timeout: int = 10) -> tuple[int, str]:
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return p.returncode, (p.stdout + p.stderr).strip()
    except FileNotFoundError:
        return 127, "binario no encontrado"
    except subprocess.TimeoutExpired:
        return 124, "timeout"


def _http_get(url: str, timeout: float = 4.0, headers: Optional[dict] = None) -> tuple[int, str]:
    req = urllib.request.Request(url, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        return e.code, ""
    except Exception as e:  # noqa: BLE001
        return 0, str(e)


def _http_post_json(url: str, payload: dict, timeout: float = 6.0) -> tuple[int, dict]:
    data = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, method="POST",
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, {"error": e.reason}
    except Exception as e:  # noqa: BLE001
        return 0, {"error": str(e)}


def _port_in_use(port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(0.3)
        return s.connect_ex(("127.0.0.1", port)) == 0


def _time(fn: Callable[[], tuple[str, str]]) -> tuple[str, str, int]:
    t0 = time.perf_counter()
    status, detail = fn()
    return status, detail, int((time.perf_counter() - t0) * 1000)


# ─── Checks ─────────────────────────────────────────────────────────────────

def check_docker() -> tuple[str, str]:
    rc, out = _run(["docker", "version", "--format", "{{.Server.Version}}"])
    if rc != 0:
        return FAIL, "Docker engine no disponible · arranca Docker Desktop / dockerd"
    return OK, out.strip()


def check_compose() -> tuple[str, str]:
    rc, out = _run(["docker", "compose", "version", "--short"])
    if rc != 0:
        return FAIL, "Docker Compose v2 no disponible"
    return OK, out.strip()


def check_port_listening(port: int) -> tuple[str, str]:
    """Si la app está arriba, el puerto está LISTENING. Esperamos OCUPADO=OK."""
    if _port_in_use(port):
        return OK, f"listening en :{port}"
    return WARN, f"libre :{port} (¿app caída?)"


def check_gateway() -> tuple[str, str]:
    code, body = _http_get(f"{GATEWAY_URL}/health")
    if code != 200:
        return FAIL, f"gateway no responde ({code or 'sin conexión'})"
    try:
        j = json.loads(body)
        return OK, f"v{j.get('version')} · backend={j.get('store_backend')}"
    except Exception:
        return WARN, f"responde {code} pero JSON inválido"


def check_app_health(label: str, url: str) -> tuple[str, str]:
    code, _ = _http_get(url, timeout=3)
    if code == 200:
        return OK, "healthy"
    if code == 0:
        return FAIL, f"{label} sin conexión (¿levantado?)"
    return WARN, f"{label} respondió {code}"


def check_sso_audience(audience: str, protected_url: str) -> tuple[str, str]:
    code, j = _http_post_json(
        f"{GATEWAY_URL}/auth/login",
        {"email": DEMO_EMAIL, "password": DEMO_PASSWORD, "audience": audience},
    )
    if code != 200:
        return FAIL, f"login falló ({code}) · {j.get('error', j.get('detail', ''))}"
    token = j.get("access_token")
    if not token:
        return FAIL, "login OK pero sin access_token"
    code2, _ = _http_get(protected_url, headers={"Authorization": f"Bearer {token}"})
    if code2 != 200:
        return FAIL, f"backend respondió {code2} con token de aud={audience}"
    return OK, f"login + protected endpoint → 200"


def check_obs(name: str, url: str) -> tuple[str, str]:
    code, _ = _http_get(url, timeout=2)
    if code == 200:
        return OK, "responde"
    if code == 0:
        return WARN, "no levantado (opcional)"
    return WARN, f"respondió {code}"


def check_jwks() -> tuple[str, str]:
    """El gateway debe publicar claves públicas RS256 para validación de JWT."""
    code, body = _http_get(f"{GATEWAY_URL}/.well-known/jwks.json")
    if code != 200:
        return FAIL, f"JWKS no disponible ({code or 'sin conexión'})"
    try:
        keys = json.loads(body).get("keys", [])
    except Exception:
        return FAIL, "JWKS respondió pero JSON inválido"
    if not keys:
        return FAIL, "JWKS sin claves (los backends no podrán validar JWT)"
    kty = keys[0].get("kty", "?")
    return OK, f"{len(keys)} clave(s) · kty={kty}"


def check_oidc() -> tuple[str, str]:
    """OIDC discovery: issuer + jwks_uri coherentes para los backends."""
    code, body = _http_get(f"{GATEWAY_URL}/.well-known/openid-configuration")
    if code != 200:
        return WARN, f"discovery no disponible ({code or 'sin conexión'})"
    try:
        j = json.loads(body)
    except Exception:
        return WARN, "discovery con JSON inválido"
    if not j.get("jwks_uri") or not j.get("issuer"):
        return WARN, "discovery sin issuer/jwks_uri"
    return OK, f"issuer={j.get('issuer')}"


def check_subdomain(host: str) -> tuple[str, str]:
    """Resolución del subdominio Caddy. Opcional en dev (requiere entradas hosts)."""
    try:
        ip = socket.gethostbyname(host)
    except OSError:
        return WARN, f"{host} no resuelve (ver install-hosts.ps1)"
    if not ip.startswith("127.") and ip != "::1":
        return WARN, f"{host} → {ip} (¿esperado 127.0.0.1?)"
    # Resuelve a loopback → intenta el handshake HTTPS vía Caddy (puede no estar arriba)
    code, _ = _http_get(f"https://{host}", timeout=2)
    if code == 0:
        return WARN, f"{host} resuelve pero Caddy no responde"
    return OK, f"{host} → {ip} · Caddy {code}"


# ─── Runner ─────────────────────────────────────────────────────────────────

class Colors:
    G = "\033[32m"
    Y = "\033[33m"
    R = "\033[31m"
    DIM = "\033[2m"
    B = "\033[1m"
    END = "\033[0m"


def _color(status: str) -> str:
    return {OK: Colors.G, WARN: Colors.Y, FAIL: Colors.R}.get(status, "")


def _emit(report: Report, name: str, fn: Callable[[], tuple[str, str]], verbose: bool):
    c = Check(name=name)
    report.add(c)
    status, detail, elapsed = _time(fn)
    c.status, c.detail, c.elapsed_ms = status, detail, elapsed
    line = f"  {name:<48} {_color(status)}{status:<5}{Colors.END}"
    if detail and (status != OK or verbose):
        line += f" {Colors.DIM}· {detail}{Colors.END}"
    print(line)


def main() -> int:
    ap = argparse.ArgumentParser(description="FLK0S Doctor")
    ap.add_argument("--verbose", action="store_true")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--no-sso", action="store_true", help="skip SSO smoke test")
    args = ap.parse_args()

    report = Report()

    if not args.json:
        print(f"\n{Colors.B}FLK0S · Doctor{Colors.END}")
        print("═" * 60)
        print(f"{Colors.B}Toolchain{Colors.END}")

    _emit(report, "Docker engine",              check_docker,  args.verbose)
    _emit(report, "Docker Compose v2",          check_compose, args.verbose)

    if not args.json:
        print(f"{Colors.B}Puertos{Colors.END}")
    for port in PORTS_TO_CHECK:
        _emit(report, f"Puerto :{port}", lambda p=port: check_port_listening(p), args.verbose)

    if not args.json:
        print(f"{Colors.B}Servicios{Colors.END}")
    _emit(report, "Auth Gateway /health", check_gateway, args.verbose)
    for label, _aud, _fe, health, _prot in APPS:
        _emit(report, f"{label} /health",
              lambda l=label, h=health: check_app_health(l, h), args.verbose)

    if not args.json:
        print(f"{Colors.B}Identidad (RS256 · JWKS · OIDC){Colors.END}")
    _emit(report, "JWKS · /.well-known/jwks.json", check_jwks, args.verbose)
    _emit(report, "OIDC discovery", check_oidc, args.verbose)

    if not args.no_sso:
        if not args.json:
            print(f"{Colors.B}SSO end-to-end (gateway → backend protegido){Colors.END}")
        for label, aud, _fe, _h, prot in APPS:
            _emit(report, f"SSO · {aud}",
                  lambda a=aud, p=prot: check_sso_audience(a, p), args.verbose)

    if not args.json:
        print(f"{Colors.B}Networking (Caddy · subdominios){Colors.END}")
    for host in SUBDOMAINS:
        _emit(report, f"Subdominio {host}",
              lambda h=host: check_subdomain(h), args.verbose)

    if not args.json:
        print(f"{Colors.B}Observabilidad{Colors.END}")
    for name, url in OBS_ENDPOINTS:
        _emit(report, name, lambda n=name, u=url: check_obs(n, u), args.verbose)

    ok, warn, fail = report.summary()

    if args.json:
        print(json.dumps({
            "ok": ok, "warn": warn, "fail": fail,
            "checks": [c.to_dict() for c in report.checks],
        }, indent=2))
    else:
        print("═" * 60)
        verdict = (
            f"{Colors.G}ECOSISTEMA SALUDABLE{Colors.END}" if fail == 0 and warn == 0
            else f"{Colors.Y}OPERATIVO CON WARNINGS{Colors.END}" if fail == 0
            else f"{Colors.R}REQUIERE ATENCIÓN{Colors.END}"
        )
        print(f"RESULTADO: {verdict}  ·  OK={ok} · WARN={warn} · FAIL={fail}\n")

    if fail > 0:
        return 1
    if warn > 0:
        return 2
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\nabortado", file=sys.stderr)
        sys.exit(130)
