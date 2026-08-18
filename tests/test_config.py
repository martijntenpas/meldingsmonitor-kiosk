"""Tests for station-screen kiosk tooling."""

from __future__ import annotations

import json
from pathlib import Path

EXAMPLE_CONFIG = Path(__file__).resolve().parent.parent / "config" / "config.example.json"


def test_example_config_has_required_keys() -> None:
    data = json.loads(EXAMPLE_CONFIG.read_text(encoding="utf-8"))

    assert data["homepage"].startswith("https://")
    assert data["setup_completed"] is False
    assert "check_url" in data
    assert "setup_ap_ip" in data


def test_homepage_validation_rules() -> None:
    homepage = "https://meldingsmonitor.nl/kazernescherm/testkey"

    assert homepage.startswith("https://")
    assert "kazernescherm" in homepage
