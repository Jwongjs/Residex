# backend/scripts/mint_test_token.py
"""Print a real Firebase ID token for a test account, for manual API testing.

    python scripts/mint_test_token.py <email> <password>

Signs in via the Firebase Auth REST API (same flow the app uses) and prints
the ID token. Requires FIREBASE_WEB_API_KEY in the environment (the Web API
key from the Firebase console — NOT a service account). This mints a genuine
token so the auth path is exercised; there is deliberately no bypass flag.
"""
import os
import sys

import requests


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: python scripts/mint_test_token.py <email> <password>", file=sys.stderr)
        return 2

    api_key = os.getenv("FIREBASE_WEB_API_KEY")
    if not api_key:
        print("FIREBASE_WEB_API_KEY is not set", file=sys.stderr)
        return 2

    email, password = sys.argv[1], sys.argv[2]
    resp = requests.post(
        "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword",
        params={"key": api_key},
        json={"email": email, "password": password, "returnSecureToken": True},
        timeout=30,
    )
    if resp.status_code != 200:
        print(f"sign-in failed: {resp.status_code} {resp.text}", file=sys.stderr)
        return 1

    print(resp.json()["idToken"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
