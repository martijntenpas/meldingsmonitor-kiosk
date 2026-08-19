# MeldingsMonitor kazernescherm-kiosk

Lichte Linux-kiosk voor **Raspberry Pi** en **Intel mini-PC/stick** met:

- automatische **setup-WiFi** als er geen internet is (na installatie);
- **QR-code op het scherm** zolang het kazernescherm nog niet is gekoppeld;
- **webpagina** om WiFi en kazernescherm-URL in te stellen;
- **factory reset** via de webinterface;
- **Chromium kioskmodus** voor het MeldingsMonitor kazernescherm.

Getest op **Raspberry Pi 4B** met Raspberry Pi OS Desktop en Lite (64-bit).

## Vereisten (apparaat)

- **Besturingssysteem:** Raspberry Pi OS (Desktop of Lite, 64-bit aanbevolen), Debian 12+ of Ubuntu 22.04+
- **Netwerk:** internet tijdens installatie (via **ethernet aanbevolen** of WiFi)
- **Geheugen:** minimaal 2 GB RAM
- **Toegang:** SSH of toetsenbord + HDMI tijdens eerste setup

Je hoeft **geen** extra software handmatig te installeren — `scripts/install.sh` regelt dat.

## Schone installatie — Raspberry Pi 4B

### 1. SD-kaart voorbereiden

1. Flash **Raspberry Pi OS (64-bit)** met [Raspberry Pi Imager](https://www.raspberrypi.com/software/).
2. Klik op **Instellingen** (tandwiel) en stel in:
   - hostnaam (bijv. `meldingsmonitor`)
   - gebruiker en wachtwoord
   - **SSH inschakelen**
   - land, tijdzone, toetsenbord
3. **Netwerk — kies één van deze opties:**

| Optie | Wanneer | Actie in Imager |
| --- | --- | --- |
| **Aanbevolen: ethernet** | Pi staat bij de kazerne met netwerkkabel | Geen WiFi nodig; sluit ethernetkabel aan vóór opstarten |
| **Alternatief: WiFi** | Geen ethernet beschikbaar | Vul WiFi-SSID en wachtwoord in onder *Draadloos LAN* |

> **Let op:** tijdens `install.sh` moet de Pi **internet** hebben om pakketten te downloaden. Zonder ethernet moet WiFi dus **vóór de installatie** werken (via Imager of handmatig na eerste boot).

4. Schrijf de image naar de SD-kaart en plaats die in de Pi.

### 2. Pi opstarten en verbinden

**Met ethernet (aanbevolen):**

1. Sluit HDMI en ethernetkabel aan.
2. Start de Pi op.
3. Zoek het IP-adres op (router, `ping meldingsmonitor.local` of `nmap`).
4. Log in via SSH:

```bash
ssh meldingsmonitor@<ip-adres-van-pi>
```

**Zonder ethernet (alleen WiFi):**

1. Controleer dat WiFi in Imager is ingesteld, **of** koppel na eerste boot handmatig via het desktop-netwerkmenu / `nmtui`.
2. Wacht tot de Pi online is (router of `ping meldingsmonitor.local`).
3. Log in via SSH (zelfde commando als hierboven).

### 3. Kiosk installeren

```bash
git clone https://github.com/martijntenpas/meldingsmonitor-kiosk.git
cd meldingsmonitor-kiosk
sudo bash scripts/install.sh
sudo reboot
```

`install.sh` detecteert automatisch je gebruiker, stelt het MeldingsMonitor-bureaubladachtergrond in en configureert Chromium-autostart. Geen aparte `kiosk`-gebruiker nodig.

### 4. Kazernescherm koppelen

Na reboot toont het HDMI-scherm een **setup-pagina met QR-code en tekstlink**.

1. Scan de QR-code of open op telefoon/laptop: **`http://<ip-adres-van-pi>`**
2. **WiFi (optioneel):** alleen nodig als je later op WiFi wilt draaien en nog geen verbinding hebt — zie [WiFi wijzigen](#wifi-wijzigen-via-de-webinterface)
3. Plak de kazernescherm-link uit MeldingsMonitor (`https://meldingsmonitor.nl/kazernescherm/...`)
4. Klik **Opslaan en starten**

Het scherm herstart en opent daarna automatisch het kazernescherm in fullscreen.

### Snelle referentie

```bash
# Kazernescherm instellen zonder webinterface (via SSH)
sudo bash /opt/meldingsmonitor-kiosk/scripts/mm-kiosk-set-homepage.sh \
  "https://meldingsmonitor.nl/kazernescherm/JOUW_KEY" complete
sudo reboot
```

---

## WiFi wijzigen via de webinterface

**Ja** — zolang de Pi WiFi-hardware heeft (`wlan0`), kun je WiFi altijd wijzigen via de instellingenpagina:

```
http://<ip-adres-van-pi>/
```

Dit werkt **ook na voltooide setup**, zolang `mm-kiosk-web` draait. Open de pagina vanaf je telefoon of laptop in hetzelfde netwerk (de kiosk zelf toont het kazernescherm fullscreen).

1. Open de instellingenpagina
2. Klik **Opnieuw scannen** bij WiFi
3. Kies netwerk, voer wachtwoord in
4. Klik **WiFi koppelen**

De WiFi-sectie wordt **automatisch verborgen** op apparaten zonder WiFi (bijv. alleen ethernet).

> **Tip:** tijdens een WiFi-scan kan het tijdelijke setup-access-point (`MeldingsMonitor-Setup-XXXX`) kort wegvallen als je via dat netwerk verbonden bent. Gebruik bij voorkeur ethernet of het reguliere WiFi-netwerk om instellingen te wijzigen.

---

## Eerste configuratie — scenario's

### Scenario A: ethernet (aanbevolen)

1. Installeer via SSH met ethernet aangesloten
2. Na reboot: open `http://<ip-adres-van-pi>` op je telefoon/laptop
3. Plak kazernescherm-link → **Opslaan en starten**

WiFi hoef je niet in te stellen.

### Scenario B: geen internet na installatie (setup-access-point)

1. Het scherm toont QR-code; het apparaat maakt WiFi-netwerk **`MeldingsMonitor-Setup-XXXX`**
2. Verbind je telefoon met dat netwerk
3. Open **`http://192.168.4.1`** (of scan de QR-code)
4. Scan WiFi → kies netwerk → **WiFi koppelen**
5. Plak kazernescherm-link → **Opslaan en starten**

### Scenario C: WiFi al werkend vóór installatie

1. WiFi ingesteld via Raspberry Pi Imager
2. Installeer via SSH
3. Na reboot: open `http://<ip-adres-van-pi>` → kazernescherm-link instellen

---

## Wat `install.sh` automatisch installeert

| Onderdeel | Pakket / actie |
| --- | --- |
| WiFi-beheer | `network-manager` (inclusief `nmcli`) |
| Browser | `chromium` / `chromium-browser` |
| Pi Desktop | bestaande desktop + autostart, `wtype`, `unclutter` |
| Pi Lite | `xorg`, `openbox`, `lightdm`, `unclutter`, `feh` |
| Setup-WiFi (access point) | `hostapd`, `dnsmasq` |
| Provisioning-webapp | `python3`, `python3-venv`, Flask (in venv) |
| Overig | `curl`, systemd-service, bureaubladachtergrond, energie-instellingen |

---

## Updates op een geïnstalleerd apparaat

De provisioning-server draait vanuit **`/opt/meldingsmonitor-kiosk`**.

```bash
cd ~/meldingsmonitor-kiosk
git pull
sudo bash scripts/mm-kiosk-apply-screen.sh
sudo reboot
```

Of alleen bestanden synchroniseren:

```bash
cd ~/meldingsmonitor-kiosk
git pull
sudo bash scripts/mm-kiosk-update.sh
```

---

## Diagnose

```bash
sudo bash /opt/meldingsmonitor-kiosk/scripts/mm-kiosk-diagnose.sh
sudo systemctl status mm-kiosk-web
tail -50 /var/log/mm-kiosk-browser.log
```

---

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

sudo systemctl restart mm-kiosk-web
sudo reboot
```

Factory reset wist ook opgeslagen WiFi-profielen (`mm-kiosk-*`).

---

## Configuratie

Bestand: `/etc/meldingsmonitor-kiosk/config.json`

| Sleutel | Beschrijving |
| --- | --- |
| `homepage` | Kazernescherm-URL |
| `setup_completed` | `true` na succesvolle setup |
| `check_url` | Internetcheck (standaard `https://meldingsmonitor.nl/up`) |
| `force_setup` | Setup-modus forceren |
| `setup_ap_ip` | Gateway in setup-modus (standaard `192.168.4.1`) |

---

## Architectuur

```
mm-kiosk-web.service              → instellingenpagina (poort 80)
gebruiker@autostart / labwc        → Chromium kiosk op HDMI na boot/login
  └── mm-kiosk-autostart.sh
        └── mm-kiosk-launch-browser.sh
```

---

## Energie en scherm (24/7)

De installer schakelt automatisch uit:

- schermbeveiliging / blanking (X11 + console)
- DPMS (monitor uitschakelen)
- slaapstand, suspend en hibernate (systemd)

Script: `scripts/mm-kiosk-power-settings.sh`

---

## Bekende beperkingen (v1)

- WiFi-scan stopt tijdelijk het setup-access-point (telefoon kan verbinding verliezen).
- WiFi-koppeling werkt via **NetworkManager** (`nmcli`); andere netwerkstacks worden niet ondersteund.
- De instellingenpagina op poort 80 is bereikbaar op het lokale netwerk (zonder wachtwoord).

---

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
