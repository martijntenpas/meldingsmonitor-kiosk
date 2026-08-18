"""Provisioning web server for MeldingsMonitor station-screen kiosks."""

from __future__ import annotations

import argparse
import io
import json
import os
import subprocess
import sys
from pathlib import Path

import qrcode
import qrcode.image.svg
from flask import Flask, Response, jsonify, request, send_from_directory

from kiosk_config import (
    build_setup_url,
    detect_local_ip,
    is_homepage_configured,
    is_setup_needed,
)

CONFIG_PATH = Path(os.environ.get("MM_KIOSK_CONFIG", "/etc/meldingsmonitor-kiosk/config.json"))
SCRIPTS_DIR = Path(os.environ.get("MM_KIOSK_SCRIPTS", Path(__file__).resolve().parent.parent / "scripts"))
STATE_DIR = Path(os.environ.get("MM_KIOSK_STATE_DIR", "/run/mm-kiosk"))
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


def ap_is_active() -> bool:
    pid_file = STATE_DIR / "hostapd.pid"
    if not pid_file.exists():
        return False

    try:
        pid = int(pid_file.read_text(encoding="utf-8").strip())
    except ValueError:
        return False

    try:
        os.kill(pid, 0)
    except OSError:
        return False

    return True


def read_setup_ssid() -> str:
    ssid_file = STATE_DIR / "setup-ssid"
    if ssid_file.exists():
        return ssid_file.read_text(encoding="utf-8").strip()

    return ""


def provisioning_context() -> dict:
    config = load_config()
    online = run_script("mm-kiosk-network-check.sh").returncode == 0
    web_port = int(config.get("web_port", 80))
    setup_ap_ip = str(config.get("setup_ap_ip", "192.168.4.1"))
    ap_active = ap_is_active()
    setup_url = build_setup_url(
        web_port=web_port,
        setup_ap_ip=setup_ap_ip,
        ap_active=ap_active,
        local_ip=detect_local_ip(),
    )

    return {
        "config": config,
        "online": online,
        "setup_url": setup_url,
        "setup_ap_active": ap_active,
        "setup_ssid": read_setup_ssid(),
        "homepage_configured": is_homepage_configured(config.get("homepage")),
        "setup_needed": is_setup_needed(config, online=online),
    }


def render_qr_svg(data: str) -> str:
    factory = qrcode.image.svg.SvgPathImage
    image = qrcode.make(data, image_factory=factory, box_size=8, border=2)
    stream = io.BytesIO()
    image.save(stream)
    return stream.getvalue().decode("utf-8")


@app.get("/")
def index():
    return send_from_directory(STATIC_DIR, "index.html")


@app.get("/display")
def display():
    return send_from_directory(STATIC_DIR, "display.html")


@app.get("/api/status")
def status():
    context = provisioning_context()
    config = context["config"]

    return jsonify(
        {
            "online": context["online"],
            "setup_completed": bool(config.get("setup_completed")),
            "homepage": config.get("homepage", ""),
            "homepage_configured": context["homepage_configured"],
            "setup_needed": context["setup_needed"],
            "check_url": config.get("check_url", ""),
            "setup_ap_ip": config.get("setup_ap_ip", "192.168.4.1"),
            "setup_url": context["setup_url"],
            "setup_ap_active": context["setup_ap_active"],
            "setup_ssid": context["setup_ssid"],
        }
    )


@app.get("/api/config")
def get_config():
    config = load_config()

    return jsonify(
        {
            "homepage": config.get("homepage", ""),
            "setup_completed": bool(config.get("setup_completed")),
            "homepage_configured": is_homepage_configured(config.get("homepage")),
        }
    )


@app.post("/api/config")
def update_config():
    payload = request.get_json(silent=True) or {}
    homepage = str(payload.get("homepage", "")).strip()

    if not homepage.startswith("https://"):
        return jsonify({"ok": False, "message": "Gebruik een HTTPS-URL voor het kazernescherm."}), 422

    if not is_homepage_configured(homepage):
        return jsonify({"ok": False, "message": "URL lijkt geen geldige MeldingsMonitor kazernescherm-link."}), 422

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


@app.post("/api/factory-reset")
def factory_reset():
    payload = request.get_json(silent=True) or {}

    if not bool(payload.get("confirm")):
        return jsonify({"ok": False, "message": "Bevestig de factory reset."}), 422

    result = run_script("mm-kiosk-factory-reset.sh")

    if result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip() or "Factory reset mislukt."
        return jsonify({"ok": False, "message": message}), 500

    subprocess.Popen(["systemctl", "reboot"])

    return jsonify({"ok": True})


@app.post("/api/reboot")
def reboot():
    subprocess.Popen(["systemctl", "reboot"])

    return jsonify({"ok": True})


@app.get("/api/qr.svg")
def qr_svg():
    context = provisioning_context()
    svg = render_qr_svg(context["setup_url"])
    return Response(svg, mimetype="image/svg+xml")


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
