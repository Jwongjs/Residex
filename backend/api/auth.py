"""Firebase ID token verification for the /api/rex router.

The single trust boundary: landlord identity comes from a verified token's
uid, never from a client-supplied parameter. Every 401/403 carries a
machine-readable `code` so the app can distinguish "refresh and retry"
(token_expired) from "sign out" (everything else).
"""
from fastapi import Depends, Header, HTTPException
from firebase_admin import auth as firebase_auth

from firebase_app import ensure_initialized


def _unauthorized(code: str, message: str) -> HTTPException:
    return HTTPException(status_code=401, detail={"code": code, "message": message})


async def verify_firebase_token(authorization: str | None = Header(None)) -> dict:
    """Verify the bearer token and return its decoded claims.

    Raises 401 with a machine-readable code for every failure mode.
    """
    ensure_initialized()

    if not authorization:
        raise _unauthorized("token_missing", "Authorization header is missing")

    parts = authorization.split(" ", 1)
    if len(parts) != 2 or parts[0] != "Bearer" or not parts[1].strip():
        raise _unauthorized("token_invalid", "Authorization header must be 'Bearer <token>'")

    token = parts[1].strip()
    try:
        # check_revoked=False by design (see plan Global Constraints).
        return firebase_auth.verify_id_token(token)
    except firebase_auth.ExpiredIdTokenError:
        raise _unauthorized("token_expired", "ID token has expired")
    except (firebase_auth.InvalidIdTokenError, ValueError):
        raise _unauthorized("token_invalid", "ID token is invalid")


async def current_landlord_id(claims: dict = Depends(verify_firebase_token)) -> str:
    """The authenticated landlord's uid, derived from the verified token."""
    uid = claims.get("uid")
    if not uid:
        raise _unauthorized("token_invalid", "Token has no uid")
    return uid
