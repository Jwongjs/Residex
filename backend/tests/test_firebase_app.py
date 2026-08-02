import firebase_admin
import firebase_app


def test_ensure_initialized_is_idempotent(monkeypatch):
    calls = []

    def fake_initialize_app(*args, **kwargs):
        calls.append(kwargs)
        return object()

    monkeypatch.setattr(firebase_admin, "_apps", {}, raising=False)
    monkeypatch.setattr(firebase_admin, "initialize_app", fake_initialize_app)

    firebase_app.ensure_initialized()
    # Simulate the app now being registered.
    monkeypatch.setattr(firebase_admin, "_apps", {"[DEFAULT]": object()}, raising=False)
    firebase_app.ensure_initialized()

    assert len(calls) == 1, "initialize_app must run only when no app exists"
    assert "storageBucket" in calls[0]["options"]
