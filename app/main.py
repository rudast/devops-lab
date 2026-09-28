"""Учебный бэкенд: Flask + PostgreSQL + Redis.

Вся конфигурация читается из переменных окружения (фактор III «Config»).
"""
import os
import socket

import psycopg
import redis
from flask import Flask, jsonify, request

HOSTNAME = socket.gethostname()


def create_app() -> Flask:
    app = Flask(__name__)
    app.config["DATABASE_URL"] = os.environ.get("DATABASE_URL", "")
    app.config["REDIS_URL"] = os.environ.get("REDIS_URL", "redis://localhost:6379/0")
    app.config["APP_VERSION"] = os.environ.get("APP_VERSION", "dev")

    def get_redis() -> redis.Redis:
        return redis.Redis.from_url(app.config["REDIS_URL"], socket_timeout=2)

    def get_db() -> psycopg.Connection:
        return psycopg.connect(app.config["DATABASE_URL"], connect_timeout=2)

    @app.get("/")
    def index():
        return jsonify(
            service="backend",
            version=app.config["APP_VERSION"],
            served_by=HOSTNAME,
        )

    @app.get("/health")
    def health():
        status = {"redis": "ok", "postgres": "ok"}
        try:
            get_redis().ping()
        except Exception as exc:  # noqa: BLE001
            status["redis"] = f"error: {exc.__class__.__name__}"
        try:
            with get_db() as conn:
                conn.execute("SELECT 1")
        except Exception as exc:  # noqa: BLE001
            status["postgres"] = f"error: {exc.__class__.__name__}"
        ok = all(v == "ok" for v in status.values())
        return jsonify(status=status, served_by=HOSTNAME), (200 if ok else 503)

    @app.get("/hits")
    def hits():
        count = get_redis().incr("hits")
        return jsonify(hits=count, served_by=HOSTNAME)

    @app.route("/notes", methods=["GET", "POST"])
    def notes():
        with get_db() as conn:
            conn.execute(
                "CREATE TABLE IF NOT EXISTS notes ("
                "id SERIAL PRIMARY KEY, text TEXT NOT NULL, author TEXT NOT NULL)"
            )
            if request.method == "POST":
                text = (request.get_json(silent=True) or {}).get("text", "").strip()
                if not text:
                    return jsonify(error="field 'text' is required"), 400
                conn.execute(
                    "INSERT INTO notes (text, author) VALUES (%s, %s)", (text, HOSTNAME)
                )
            rows = conn.execute(
                "SELECT id, text, author FROM notes ORDER BY id DESC LIMIT 20"
            ).fetchall()
        return jsonify(
            notes=[{"id": r[0], "text": r[1], "written_by": r[2]} for r in rows],
            served_by=HOSTNAME,
        )

    return app


app = create_app()
