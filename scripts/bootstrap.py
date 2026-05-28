#!/usr/bin/env python3
"""FLK0S · bootstrap — arranca el ecosistema completo de forma ordenada.

Orden:
  1. Stack de observabilidad (infra/observability)
  2. Auth gateway (espera healthy)
  3. Las 4 apps en paralelo (espera todas healthy)
  4. Seeds demo en cada app (si flag --seed)
  5. Smoke test SSO end-to-end
  6. Imprime resumen + URLs

Uso:
  python bootstrap.py                # arranca todo
  python bootstrap.py --no-seed      # no corre seeds demo
  python bootstrap.py --no-obs       # skip observability stack
  python bootstrap.py --teardown     # bajar todo
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass


ROOT = Path(__file__).resolve().parents[2]
ECOSYSTEM_DIR = ROOT / "FLK0S-Ecosystem"

# (label, compose_dir, health_url, optional)
STACKS = [
    ("Observability", ROOT / "infra" / "observability",   "http://localhost:3001/api/health",        True),
    ("Auth Gateway",  ROOT / "auth-gateway",              "http://localhost:8000/health",            False),
    ("FLK0S-CYB",     ROOT / "FLK0S-CYB",                 "http://localhost:8080/api/v1/health",     False),
    ("FLK0S-RT",      ROOT / "FLK0S-RT",                  "http://localhost:8200/health",            False),
    ("FLK0S-AI",      ROOT / "FLK0S-AI",                  "http://localhost:8300/health",            False),
    ("FLK0S-Reportes",ROOT / "FLK0S-Reportes",            "http://localhost:8400/health",            False),
]

SSO_TARGETS = [
    ("flk0s:cdp",      "http://localhost:8080/api/v1/alerts"),
    ("flk0s:rt",       "http://localhost:8200/api/v1/campaigns"),
    ("flk0s:airt",     "http://localhost:8300/api/v1/agents"),
    ("flk0s:reporter", "http://localhost:8400/api/v1/engagements/"),
]

GW = "http://localhost:8000"
DEMO_EMAIL = os.environ.get("FLK0S_DEMO_EMAIL", "demo@flk0s.local")
DEMO_PASSWORD = os.environ.get("FLK0S_DEMO_PASSWORD", "FLK0S-demo-2026")


class C:
    G = "\033[32m"; Y = "\033[33m"; R = "\033[31m"; B = "\033[1m"; DIM = "\033[2m"; END = "\033[0m"


def info(msg: str): print(f"{C.B}→{C.END} {msg}")
def ok(msg: str):   print(f"  {C.G}✓{C.END} {msg}")
def warn(msg: str): print(f"  {C.Y}!{C.END} {msg}")
def fail(msg: str): print(f"  {C.R}✗{C.END} {msg}")


def run(cmd: list[str], cwd: Path | None = None, capture: bool = False) -> tuple[int, str]:
    try:
        p = subprocess.run(cmd, cwd=cwd, capture_output=capture, text=True, check=False)
        return p.returncode, ((p.stdout or "") + (p.stderr or ""))
    except FileNotFoundError as e:
        return 127, str(e)


def wait_http(url: str, timeout: int = 120, every: float = 2.0) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=2) as r:
                if r.status == 200:
                    return True
        except Exception:
            pass
        time.sleep(every)
    return False


def http_post_json(url: str, payload: dict) -> tuple[int, dict]:
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 method="POST", headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=6) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, {"error": e.reason}
    except Exception as e:  # noqa: BLE001
        return 0, {"error": str(e)}


def http_get(url: str, token: str | None = None) -> int:
    req = urllib.request.Request(url)
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=5) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception:
        return 0


def compose_up(directory: Path) -> bool:
    if not (directory / "docker-compose.yml").exists() and not (directory / "compose.yml").exists():
        warn(f"{directory.name}: sin docker-compose.yml — skip")
        return True
    rc, _ = run(["docker", "compose", "up", "-d"], cwd=directory)
    return rc == 0


def compose_down(directory: Path) -> None:
    if not (directory / "docker-compose.yml").exists() and not (directory / "compose.yml").exists():
        return
    run(["docker", "compose", "down"], cwd=directory)


def start_stack(stack) -> tuple[str, bool, str]:
    label, dirpath, health, _opt = stack
    if not dirpath.exists():
        return label, False, "dir no encontrado"
    info(f"Levantando {label} ({dirpath.name})")
    if not compose_up(dirpath):
        return label, False, "compose up falló"
    ready = wait_http(health, timeout=180, every=3)
    return label, ready, health


def seed_demo(stack_label: str, dirpath: Path) -> str:
    """Corre el seed dentro del container del API, si existe el módulo."""
    candidates = {
        "FLK0S-CYB":      ("flk0s_cdp_api", "python", "-m", "seeds.demo_dataset"),
        "FLK0S-RT":       ("flk0s-rt-backend-1", "python", "-m", "seeds.demo_dataset"),
        "FLK0S-AI":       ("flk0s-ai-backend-1", "python", "-m", "seeds.demo_dataset"),
        "FLK0S-Reportes": ("flk0s-reportes-backend-1", "python", "-m", "seeds.demo_dataset"),
    }
    spec = candidates.get(stack_label)
    if not spec:
        return "no aplica"
    container, *cmd = spec
    rc, out = run(["docker", "exec", container, *cmd], capture=True)
    if rc == 0:
        return "OK"
    if "No module named 'seeds.demo_dataset'" in out:
        return "no implementado (skip)"
    return f"fallo rc={rc}"


def sso_smoke_test() -> dict:
    results = {}
    for aud, protected in SSO_TARGETS:
        code, body = http_post_json(f"{GW}/auth/login",
                                    {"email": DEMO_EMAIL, "password": DEMO_PASSWORD, "audience": aud})
        if code != 200:
            results[aud] = f"login {code}"
            continue
        token = body.get("access_token")
        if not token:
            results[aud] = "sin token"
            continue
        api_code = http_get(protected, token=token)
        results[aud] = "OK" if api_code == 200 else f"backend {api_code}"
    return results


def main() -> int:
    ap = argparse.ArgumentParser(description="FLK0S bootstrap")
    ap.add_argument("--no-seed", action="store_true")
    ap.add_argument("--no-obs",  action="store_true")
    ap.add_argument("--teardown", action="store_true")
    args = ap.parse_args()

    print(f"\n{C.B}FLK0S · Bootstrap{C.END}")
    print("=" * 60)

    if args.teardown:
        info("Bajando todo el ecosistema")
        for label, dirpath, _h, _o in reversed(STACKS):
            if dirpath.exists():
                ok(f"down {label}")
                compose_down(dirpath)
        return 0

    # 1) Observability
    if not args.no_obs:
        obs = STACKS[0]
        label, ready, _ = start_stack(obs)
        (ok if ready else warn)(f"{label}: {'healthy' if ready else 'no respondió (sigo)'}")

    # 2) Gateway primero (las apps lo dependen indirectamente vía SSO)
    label, ready, _ = start_stack(STACKS[1])
    if not ready:
        fail(f"{label} no llegó a healthy. Aborto.")
        return 1
    ok(f"{label}: healthy")

    # 3) Apps en paralelo
    info("Levantando las 4 apps en paralelo...")
    with ThreadPoolExecutor(max_workers=4) as ex:
        futures = [ex.submit(start_stack, s) for s in STACKS[2:]]
        for f in as_completed(futures):
            label, ready, _ = f.result()
            (ok if ready else fail)(f"{label}: {'healthy' if ready else 'no llegó a healthy'}")

    # 4) Seeds demo
    if not args.no_seed:
        info("Cargando seeds demo (idempotente)")
        for label, dirpath, _h, _o in STACKS[2:]:
            result = seed_demo(label, dirpath)
            (ok if result in ("OK", "no implementado (skip)", "no aplica") else warn)(f"seed {label}: {result}")

    # 5) SSO smoke test
    info("SSO smoke test (gateway → 4 audiences → backends protegidos)")
    sso = sso_smoke_test()
    all_ok = all(v == "OK" for v in sso.values())
    for aud, status in sso.items():
        (ok if status == "OK" else fail)(f"{aud}: {status}")

    # 6) Resumen
    print()
    print("=" * 60)
    verdict = f"{C.G}ECOSISTEMA OPERATIVO{C.END}" if all_ok else f"{C.Y}ECOSISTEMA PARCIAL{C.END}"
    print(f"RESULTADO: {verdict}")
    print()
    print("URLs (modo dev por puerto):")
    print(f"  Centro de Operaciones  http://localhost:3000")
    print(f"  FLK0S-CDP              http://localhost:3100")
    print(f"  FLK0S-RT               http://localhost:3200")
    print(f"  FLK0S-AI               http://localhost:3300")
    print(f"  FLK0S-Reportes         http://localhost:3400")
    print(f"  Gateway                http://localhost:8000")
    print(f"  Grafana                http://localhost:3001")
    print()
    print(f"Login demo: {DEMO_EMAIL} / {DEMO_PASSWORD}")
    print()
    return 0 if all_ok else 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\nabortado", file=sys.stderr)
        sys.exit(130)
