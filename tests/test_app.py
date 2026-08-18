"""Tests for the provisioning Flask app."""

from __future__ import annotations

from unittest.mock import patch

import pytest

from app import app


@pytest.fixture
def client(tmp_path, monkeypatch):
    config_path = tmp_path / "config.json"
    config_path.write_text(
        '{"homepage": "", "setup_completed": false, "web_port": 80, "check_url": "https://example.test/up"}',
        encoding="utf-8",
    )
    scripts_dir = tmp_path / "scripts"
    scripts_dir.mkdir()

    monkeypatch.setenv("MM_KIOSK_CONFIG", str(config_path))
    monkeypatch.setenv("MM_KIOSK_SCRIPTS", str(scripts_dir))
    monkeypatch.setenv("MM_KIOSK_STATE_DIR", str(tmp_path / "state"))

    with patch("app.CONFIG_PATH", config_path), patch("app.SCRIPTS_DIR", scripts_dir):
        yield app.test_client()


def test_wifi_scan_skips_without_interface(client) -> None:
    with patch("app.wifi_available", return_value=False):
        response = client.get("/api/wifi/scan")

    assert response.status_code == 200
    assert response.json == {"networks": [], "wifi_available": False}


def test_status_includes_wifi_available(client) -> None:
    with patch("app.wifi_available", return_value=False), patch("app.run_script") as run_script:
        run_script.return_value.returncode = 0

        response = client.get("/api/status")

    assert response.status_code == 200
    assert response.json["wifi_available"] is False
