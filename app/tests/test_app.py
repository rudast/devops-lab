from main import create_app


def test_index_returns_hostname_and_version(monkeypatch):
    monkeypatch.setenv("APP_VERSION", "1.2.3")
    client = create_app().test_client()
    resp = client.get("/")
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["version"] == "1.2.3"
    assert body["served_by"]


def test_health_is_503_without_dependencies(monkeypatch):
    monkeypatch.setenv("REDIS_URL", "redis://127.0.0.1:1/0")
    monkeypatch.setenv("DATABASE_URL", "postgresql://x:y@127.0.0.1:1/z")
    client = create_app().test_client()
    resp = client.get("/health")
    assert resp.status_code == 503
