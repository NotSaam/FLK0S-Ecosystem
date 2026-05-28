# SSO Fase 4 · RS256 + JWKS

> Rotación de claves sin redespliegue ni secret compartido.

## Resumen

El gateway puede emitir JWTs firmados con **RS256** (RSA private key) en vez de **HS256** (shared secret). La clave pública correspondiente se publica en `/.well-known/jwks.json` para que las apps cliente verifiquen sin compartir secretos.

| Aspecto | HS256 (Fase 1-3) | RS256 (Fase 4) |
|---|---|---|
| Algoritmo | HMAC SHA-256 | RSA 3072 + SHA-256 |
| Material | `SECRET_KEY` compartido | `private_key.pem` (gateway) + JWKS público (apps) |
| Rotación | Requiere redesplegar TODAS las apps | Sólo rotar la clave del gateway |
| Compromiso de una app | **Compromete TODO el ecosistema** | Sólo expone el access usage de esa app |
| Compatibilidad | Inmediata | Cada app debe soportar verificación JWKS |

## Estado de implementación

✅ **Gateway**: soporta ambos algoritmos vía `ALGORITHM=HS256|RS256`.
✅ **JWKS endpoint**: `GET /.well-known/jwks.json` devuelve la clave pública activa con `kid`.
✅ **Discovery doc**: `GET /.well-known/openid-configuration` para auto-config OIDC-compatible.
🚧 **Apps cliente**: aún verifican sólo con HS256 (shared secret). Falta soporte JWKS en las 4.

## Activar en el gateway

```bash
# En auth-gateway/.env (o .env.production):
ALGORITHM=RS256
ISSUER_URL=https://auth.flk0s.tld   # URL pública (para el discovery doc)
PRIVATE_KEY_PATH=/app/keys/jwt-private.pem
```

Al primer arranque el gateway:
1. Genera una clave RSA 3072 bits si no existe en `PRIVATE_KEY_PATH`.
2. Calcula `kid` = SHA-256 truncado de la clave pública DER (estable entre reinicios).
3. Empieza a firmar con RS256 y a publicar el JWKS.

## Migrar una app cliente

Cada backend (CDP/RT/AI/Reportes) debe:

### 1. Añadir dependencia

```toml
# pyproject.toml / requirements.txt
PyJWT[crypto]>=2.9.0
httpx>=0.27
```

### 2. Cachear JWKS con TTL

```python
# core/jwks.py
import time, httpx, jwt

_jwks_cache = {"fetched_at": 0, "keys": {}}
JWKS_URL = "http://auth-gateway:8000/.well-known/jwks.json"  # o el público
TTL = 3600  # 1h

def get_signing_key(kid: str) -> jwt.PyJWK:
    global _jwks_cache
    if time.time() - _jwks_cache["fetched_at"] > TTL or kid not in _jwks_cache["keys"]:
        jwks = httpx.get(JWKS_URL, timeout=5).json()
        _jwks_cache = {
            "fetched_at": time.time(),
            "keys": {k["kid"]: jwt.PyJWK(k) for k in jwks["keys"]},
        }
    return _jwks_cache["keys"][kid]
```

### 3. Verificar con RS256 (mantener HS256 como fallback)

```python
# core/security.py
def verify_gateway_token(token: str, audience: str) -> dict:
    header = jwt.get_unverified_header(token)
    if header.get("alg") == "RS256":
        key = get_signing_key(header["kid"]).key
        algorithms = ["RS256"]
    else:
        # Fallback HS256 — backwards compat
        key = settings.SECRET_KEY
        algorithms = ["HS256"]
    return jwt.decode(
        token, key, algorithms=algorithms,
        audience=audience, issuer="flk0s-auth",
        options={"require": ["exp", "sub", "aud", "iss"]},
    )
```

## Rotación de claves (futuro)

Cuando se implemente multi-key support:

1. Generar nueva keypair → guardarla en `PRIVATE_KEY_PATH` (+ keep old en `.previous.pem`).
2. JWKS expone AMBAS keys con sus respectivos `kid`.
3. Tokens nuevos se firman con la nueva key.
4. Apps verifican con cualquiera de las dos durante el período de rotación.
5. Tras `ACCESS_TOKEN_TTL_MIN * 2`, retirar la old key del JWKS.

Sin downtime. Sin redesplegar las apps.

## Verificación

```bash
# 1. Gateway healthy con algorithm correcto
curl http://localhost:8000/health
# → {"algorithm": "RS256", ...}

# 2. JWKS sirve la clave
curl http://localhost:8000/.well-known/jwks.json | jq
# → {"keys": [{"kty": "RSA", "use": "sig", "alg": "RS256", "kid": "...", "n": "...", "e": "AQAB"}]}

# 3. Login emite RS256 token
TOK=$(curl -s -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"demo@flk0s.local","password":"FLK0S-demo-2026","audience":"flk0s:cdp"}' \
  | jq -r .access_token)

# 4. Header confirma RS256 + kid
echo $TOK | cut -d. -f1 | base64 -d 2>/dev/null | jq
# → {"alg": "RS256", "kid": "...", "typ": "JWT"}

# 5. /auth/me lo verifica internamente
curl -H "Authorization: Bearer $TOK" http://localhost:8000/auth/me
```

## Roadmap incremental

| Hito | Estado |
|---|---|
| Gateway emite RS256 + publica JWKS | ✅ |
| Discovery doc OIDC | ✅ |
| Volume persistente para clave (no se pierde tras restart) | ✅ |
| Apps verifican RS256 vía JWKS (CDP) | ⏳ |
| Apps verifican RS256 vía JWKS (RT/AI/Reportes) | ⏳ |
| Multi-key (rotación zero-downtime) | ⏳ |
| Endpoint admin `/auth/keys/rotate` | ⏳ |
| Audit events `key_rotated` | ⏳ |
