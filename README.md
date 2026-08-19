# MeldingsMonitor kazernescherm-kiosk

Lichte Linux-kiosk voor **Raspberry Pi** en **Intel mini-PC/stick** met:

- automatische **setup-WiFi** als er geen internet is;
- **QR-code op het scherm** zolang het kazernescherm nog niet is gekoppeld;
- **webpagina** om WiFi en kazernescherm-URL in te stellen;
- **factory reset** via de webinterface;
- **Chromium kioskmodus** voor het MeldingsMonitor kazernescherm.

## Vereisten (apparaat)

Zorg vóór installatie dat het apparaat aan deze basis voldoet:

- **Besturingssysteem:** Debian 12+, Ubuntu 22.04+, of **Raspberry Pi OS Lite** (64-bit aanbevolen)
- **Netwerk:** WiFi of ethernet (internet tijdens installatie voor pakketten)
- **Geheugen:** minimaal 2 GB RAM
- **Toegang:** root/sudo op het apparaat

Je hoeft **geen** extra software handmatig te installeren — `scripts/install.sh` regelt dat.

## Wat `install.sh` automatisch installeert

Het installatiescript zet alles klaar wat de kiosk nodig heeft:

| Onderdeel | Pakket / actie |
| --- | --- |
| WiFi-beheer | `network-manager` (inclusief `nmcli`) |
| Browser | `chromium` / `chromium-browser` |
| Desktop voor kiosk | `xorg`, `openbox`, `lightdm`, `unclutter`, `x11-xserver-utils` |
| Setup-WiFi (access point) | `hostapd`, `dnsmasq` |
| Provisioning-webapp | `python3`, `python3-venv`, Flask (in venv) |
| Overig | `curl`, systemd-service, kiosk-gebruiker, autologin, energie-/scherminstellingen |

## Installatie

1. Flash **Raspberry Pi OS Lite (64-bit)** of Desktop — beide werken.
2. Log in via SSH als je gebruiker (bijv. `martijn`).
3. Clone en installeer:

```bash
git clone https://github.com/martijntenpas/meldingsmonitor-kiosk.git
cd meldingsmonitor-kiosk
sudo bash scripts/install.sh
sudo reboot
```

`install.sh` detecteert automatisch je gebruiker en zet een **opstartsequence** klaar die na login/boot Chromium in kioskmodus opent. Geen aparte `kiosk`-gebruiker nodig.

Tijdens installatie moet het apparaat **internet** hebben (via ethernet of WiFi) zodat `apt` de pakketten kan ophalen.

## Eerste configuratie

Zolang het kazernescherm nog niet is gekoppeld, toont het scherm een **QR-code** met de setup-link. Scan die met je telefoon om WiFi en de kazernescherm-URL in te stellen.

Na **Opslaan en starten** herstart het apparaat automatisch en opent het kazernescherm in fullscreen (geen handmatige actie nodig).

### Scenario A: geen internet (typisch bij nieuwe stick)

1. Het scherm toont een QR-code; het apparaat maakt ook WiFi-netwerk **`MeldingsMonitor-Setup-XXXX`**
2. Scan de QR-code, of verbind handmatig met het setup-netwerk
3. Open de setup-link (standaard **`http://192.168.4.1`**)
4. Scan WiFi → kies netwerk → voer wachtwoord in → **WiFi koppelen**
5. Plak de kazernescherm-link uit MeldingsMonitor
6. Klik **Opslaan en starten**

### Scenario B: ethernet of bekende WiFi

1. Open op het apparaat of via het netwerk: **`http://<ip-van-apparaat>`**
2. Stel URL in en klik **Opslaan en starten**

Apparaten **zonder WiFi** (alleen ethernet) slaan WiFi-instellingen automatisch over. De WiFi-sectie wordt dan verborgen.

## Updates op een geïnstalleerd apparaat

De systemd-service draait vanuit **`/opt/meldingsmonitor-kiosk`**.

```bash
cd /opt/meldingsmonitor-kiosk
git pull
sudo bash scripts/mm-kiosk-update.sh
```

`mm-kiosk-update.sh` kopieert de nieuwe bestanden, installeert de web-server service en herstart `mm-kiosk-web` + `mm-kiosk`.

### Noodoplossing zonder webinterface

Als de instellingenpagina niet bereikbaar is:

```bash
sudo bash /opt/meldingsmonitor-kiosk/scripts/mm-kiosk-set-homepage.sh \
  "https://meldingsmonitor.nl/kazernescherm/JOUW_KEY" complete
```

## Setup opnieuw openen

Via de webinterface onder **Geavanceerd → Factory reset**, of handmatig:

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
mm-kiosk-web.service          → instellingenpagina (poort 80)
gebruiker@autostart           → Chromium kiosk op HDMI na boot/login
  └── mm-kiosk-launch-browser.sh
```

## Energie en scherm (24/7)

De installer schakelt automatisch uit:

- schermbeveiliging / blanking (X11 + console)
- DPMS (monitor uitschakelen)
- slaapstand, suspend en hibernate (systemd)

Script: `scripts/mm-kiosk-power-settings.sh` (draait bij installatie en elke kiosk-start).

## Bekende beperkingen (v1)

- WiFi-scan stopt tijdelijk het setup-access-point (telefoon kan verbinding verliezen).
- WiFi-koppeling werkt via **NetworkManager** (`nmcli`); andere netwerkstacks worden niet ondersteund.
- De instellingenpagina op poort 80 is bereikbaar op het lokale netwerk (zonder wachtwoord).

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

## Voor onderhouders

Deze publieke repository is een mirror van `tools/station-screen-kiosk` in de private MeldingsMonitor-monorepo. Instructies voor synchroniseren staan in [PUBLISHING.md](PUBLISHING.md).
