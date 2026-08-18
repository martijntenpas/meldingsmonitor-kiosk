# MeldingsMonitor kazernescherm-kiosk

Lichte Linux-kiosk voor **Raspberry Pi** en **Intel mini-PC/stick** met:

- automatische **setup-WiFi** als er geen internet is;
- **webpagina** om WiFi en kazernescherm-URL in te stellen;
- **Chromium kioskmodus** voor het MeldingsMonitor kazernescherm.

## Vereisten

- Debian 12+, Ubuntu 22.04+, of **Raspberry Pi OS Lite** (64-bit aanbevolen)
- NetworkManager (`nmcli`)
- WiFi of ethernet
- Minimaal 2 GB RAM

## Installatie

1. Flash Raspberry Pi OS Lite of installeer Debian/Ubuntu op de Intel stick.
2. Clone de **publieke kiosk-repository** op het apparaat (of kopieer deze map via USB).

```bash
git clone https://github.com/martijntenpas/meldingsmonitor-kiosk.git
cd meldingsmonitor-kiosk
sudo bash scripts/install.sh
sudo reboot
```

> Deze software wordt vanuit de private MeldingsMonitor-monorepo gespiegeld naar een publieke repo.
> Zie [PUBLISHING.md](PUBLISHING.md) voor onderhouders.

## Eerste configuratie

### Scenario A: geen internet (typisch bij nieuwe stick)

1. Het apparaat maakt een WiFi-netwerk: **`MeldingsMonitor-Setup-XXXX`**
2. Verbind met je telefoon/laptop.
3. Open **`http://192.168.4.1`**
4. Scan WiFi → kies netwerk → voer wachtwoord in → **WiFi koppelen**
5. Plak de kazernescherm-link uit MeldingsMonitor
6. Klik **Opslaan en starten**

### Scenario B: ethernet of bekende WiFi

1. Open op het apparaat of via het netwerk: **`http://<ip-van-apparaat>`**
2. Stel URL in en klik **Opslaan en starten**

## Setup opnieuw openen

```bash
sudo python3 - <<'PY'
import json
from pathlib import Path

path = Path("/etc/meldingsmonitor-kiosk/config.json")
data = json.loads(path.read_text())
data["force_setup"] = True
data["setup_completed"] = False
path.write_text(json.dumps(data, indent=4) + "\n")
PY

sudo systemctl restart mm-kiosk
```

## Configuratie

Bestand: `/etc/meldingsmonitor-kiosk/config.json`

| Sleutel | Beschrijving |
| --- | --- |
| `homepage` | Kazernescherm-URL |
| `setup_completed` | `true` na succesvolle setup |
| `check_url` | Internetcheck (standaard `https://meldingsmonitor.nl/up`) |
| `force_setup` | Setup-modus forceren |
| `setup_ap_ip` | Gateway in setup-modus (standaard `192.168.4.1`) |

## Raspberry Pi vs Intel stick

| | Raspberry Pi | Intel stick |
| --- | --- | --- |
| OS | Raspberry Pi OS Lite 64-bit | Debian/Ubuntu minimal |
| Browser | `chromium-browser` | `chromium` |
| WiFi | `wlan0` | vaak `wlan0` / `wlp*` |
| Installatie | zelfde `install.sh` | zelfde `install.sh` |

## Architectuur

```
mm-kiosk.service
    └── mm-kiosk-boot.sh
            ├── geen internet / setup nodig → setup AP + webapp (poort 80)
            └── online + setup klaar      → Chromium kiosk
```

## Bekende beperkingen (v1)

- WiFi-scan stopt tijdelijk het setup-access-point (telefoon kan verbinding verliezen).
- Vereist **NetworkManager** voor WiFi-koppeling.
- X11 + Openbox + Lightdm autologin worden geïnstalleerd voor Chromium.
- Geen MeldingsMonitor-cloudkoppeling yet (fase 2).

## Ontwikkeling

Provisioning-webapp lokaal testen (Linux):

```bash
cd web
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
sudo MM_KIOSK_CONFIG=../config/config.example.json \
     MM_KIOSK_SCRIPTS=../scripts \
     python app.py --port 8080
```

## Tests

```bash
python3 -m pytest tests
```
