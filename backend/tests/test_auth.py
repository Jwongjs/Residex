import unittest
from unittest.mock import patch

import firebase_admin
from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient

from api.auth import verify_firebase_token, current_landlord_id


def _make_probe_app() -> FastAPI:
    app = FastAPI()

    @app.get("/probe")
    async def probe(landlord_id: str = Depends(current_landlord_id)):
        return {"landlord_id": landlord_id}

    return app


class TestAuthDependency(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(_make_probe_app())

    def test_missing_header_is_401_token_missing(self):
        r = self.client.get("/probe")
        self.assertEqual(r.status_code, 401)
        self.assertEqual(r.json()["detail"]["code"], "token_missing")

    def test_malformed_header_is_401_token_invalid(self):
        r = self.client.get("/probe", headers={"Authorization": "NotBearer xyz"})
        self.assertEqual(r.status_code, 401)
        self.assertEqual(r.json()["detail"]["code"], "token_invalid")

    def test_expired_token_is_401_token_expired(self):
        with patch("api.auth.firebase_auth.verify_id_token",
                   side_effect=firebase_admin.auth.ExpiredIdTokenError("expired", cause=None)):
            r = self.client.get("/probe", headers={"Authorization": "Bearer tok"})
        self.assertEqual(r.status_code, 401)
        self.assertEqual(r.json()["detail"]["code"], "token_expired")

    def test_bad_signature_is_401_token_invalid(self):
        with patch("api.auth.firebase_auth.verify_id_token",
                   side_effect=firebase_admin.auth.InvalidIdTokenError("bad sig")):
            r = self.client.get("/probe", headers={"Authorization": "Bearer tok"})
        self.assertEqual(r.status_code, 401)
        self.assertEqual(r.json()["detail"]["code"], "token_invalid")

    def test_valid_token_returns_uid(self):
        with patch("api.auth.firebase_auth.verify_id_token",
                   return_value={"uid": "landlord_123"}):
            r = self.client.get("/probe", headers={"Authorization": "Bearer tok"})
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["landlord_id"], "landlord_123")


def test_no_landlord_id_in_any_request_input():
    """landlord_id must never be a client-supplied input (query/form/body).
    Response models may still expose it — this checks inputs only."""
    from main import app
    spec = app.openapi()
    schemas = spec.get("components", {}).get("schemas", {})

    offenders = []
    for path, methods in spec.get("paths", {}).items():
        for method, op in methods.items():
            for param in op.get("parameters", []):
                if param.get("name") == "landlord_id":
                    offenders.append(f"{method.upper()} {path} param")
            body = op.get("requestBody", {})
            for content in body.get("content", {}).values():
                schema = content.get("schema", {})
                ref = schema.get("$ref")
                if ref:
                    name = ref.split("/")[-1]
                    props = schemas.get(name, {}).get("properties", {})
                else:
                    props = schema.get("properties", {})
                if "landlord_id" in props:
                    offenders.append(f"{method.upper()} {path} body")

    assert not offenders, f"landlord_id is still a client input: {offenders}"


if __name__ == "__main__":
    unittest.main()
