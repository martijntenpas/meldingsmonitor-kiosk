"""Provisioning web server for MeldingsMonitor station-screen kiosks."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

from flask import Flask, jsonify, request, send_from_directory

CONFIG_PATH = Path(os.environ.get("MM_KIOSK_CONFIG", "/etc/meldingsmonitor-kiosk/config.json"))
SCRIPTS_DIR = Path(os.environ.get("MM_KIOSK_SCRIPTS", Path(__file__).resolve().parent.parent / "scripts"))
STATIC_DIR = Path(__file__).resolve().parent / "static"

app = Flask(__name__, static_folder=str(STATIC_DIR), static_url_path="/static")


def load_config() -> dict:
    if not CONFIG_PATH.exists():
        example = SCRIPTS_DIR.parent / "config" / "config.example.json"
        CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
        CONFIG_PATH.write_text(example.read_text(encoding="utf-8"), encoding="utf-8")

    with CONFIG_PATH.open(encoding="utf-8") as handle:
        return json.load(handle)


def save_config(data: dict) -> None:
    CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with CONFIG_PATH.open("w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=4, ensure_ascii=False)
        handle.write("\n")


def run_script(name: str, *args: str) -> subprocess.CompletedProcess[str]:
    script = SCRIPTS_DIR / name
    if not script.exists():
        raise FileNotFoundError(f"Script ontbreekt: {script}")

    return subprocess.run(
        [str(script), *args],
        capture_output=True,
        text=True,
        check=False,
    )


@app.get("/")
def index():
    return send_from_directory(STATIC_DIR, "index.html")


@app.get("/api/status")
def status():
    config = load_config()
    online = run_script("mm-kiosk-network-check.sh").returncode == 0

    return jsonify(
        {
            "online": online,
            "setup_completed": bool(config.get("setup_completed")),
            "homepage": config.get("homepage", ""),
            "check_url": config.get("check_url", ""),
            "setup_ap_ip": config.get("setup_ap_ip", "192.168.4.1"),
        }
    )


@app.get("/api/config")
def get_config():
    config = load_config()

    return jsonify(
        {
            "homepage": config.get("homepage", ""),
            "setup_completed": bool(config.get("setup_completed")),
        }
    )


@app.post("/api/config")
def update_config():
    payload = request.get_json(silent=True) or {}
    homepage = str(payload.get("homepage", "")).strip()

    if not homepage.startswith("https://"):
        return jsonify({"ok": False, "message": "Gebruik een HTTPS-URL voor het kazernescherm."}), 422

    if "meldingsmonitor" not in homepage and "kazernescherm" not in homepage:
        return jsonify({"ok": False, "message": "URL lijkt geen MeldingsMonitor kazernescherm-link."}), 422

    config = load_config()
    config["homepage"] = homepage
    mark_complete = bool(payload.get("complete", False))

    if mark_complete:
        if not run_script("mm-kiosk-network-check.sh").returncode == 0:
            return jsonify({"ok": False, "message": "Geen internetverbinding. Koppel eerst WiFi."}), 422
        config["setup_completed"] = True
        config["force_setup"] = False

    save_config(config)

    return jsonify({"ok": True, "setup_completed": config.get("setup_completed", False)})


@app.get("/api/wifi/scan")
def wifi_scan():
    result = run_script("mm-kiosk-wifi-scan.sh")

    if result.returncode != 0:
        return jsonify({"networks": [], "message": result.stderr.strip()}), 200

    try:
        networks = json.loads(result.stdout or "[]")
    except json.JSONDecodeError:
        networks = []

    return jsonify({"networks": networks})


@app.post("/api/wifi/connect")
def wifi_connect():
    payload = request.get_json(silent=True) or {}
    ssid = str(payload.get("ssid", "")).strip()
    password = str(payload.get("password", ""))

    if not ssid:
        return jsonify({"ok": False, "message": "SSID is verplicht."}), 422

    args = [ssid, password] if password else [ssid]
    result = run_script("mm-kiosk-wifi-connect.sh", *args)

    if result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip() or "WiFi-koppeling mislukt."
        return jsonify({"ok": False, "message": message}), 422

    online = run_script("mm-kiosk-network-check.sh").returncode == 0

    return jsonify({"ok": True, "online": online})


@app.post("/api/reboot")
def reboot():
    subprocess.Popen(["systemctl", "reboot"])

    return jsonify({"ok": True})


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=80)
    args = parser.parse_args()

    if os.geteuid() != 0:
        print("Provisioning server moet als root draaien.", file=sys.stderr)
        return 1

    app.run(host=args.host, port=args.port, debug=False)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
