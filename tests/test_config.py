"""Tests for kiosk configuration helpers."""

from __future__ import annotations

import json
from pathlib import Path

from kiosk_config import (
    build_setup_url,
    is_homepage_configured,
    is_setup_needed,
    load_default_config,
)

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
    assert is_homepage_configured(homepage) is True


def test_placeholder_homepage_is_not_configured() -> None:
    homepage = "https://meldingsmonitor.nl/kazernescherm/VUL_ACCESS_KEY_IN"

    assert is_homepage_configured(homepage) is False


def test_setup_needed_without_homepage() -> None:
    config = load_default_config(EXAMPLE_CONFIG)

    assert is_setup_needed(config, online=True) is True


def test_setup_not_needed_when_configured_and_online() -> None:
    config = load_default_config(EXAMPLE_CONFIG)
    config["homepage"] = "https://meldingsmonitor.nl/kazernescherm/abc123"
    config["setup_completed"] = True

    assert is_setup_needed(config, online=True) is False


def test_build_setup_url_uses_ap_ip_when_ap_active() -> None:
    url = build_setup_url(
        web_port=80,
        setup_ap_ip="192.168.4.1",
        ap_active=True,
        local_ip="192.168.1.50",
    )

    assert url == "http://192.168.4.1"
