# Publiceren als losse GitHub-repository

De kiosk-software staat canoniek in de private monorepo:

`meldingsmonitor/tools/station-screen-kiosk`

Voor installatie op sticks/Pi's zonder toegang tot de private repo publiceer je een **publieke mirror**, bijvoorbeeld:

`https://github.com/martijntenpas/meldingsmonitor-kiosk`

## Eerste keer: publieke repo aanmaken

Op je development-machine (PowerShell):

```powershell
cd C:\Users\mjjte\Documents\GitHub\meldingsmonitor
bash tools/station-screen-kiosk/scripts/publish-standalone-repo.sh
```

Of handmatig met GitHub CLI:

```powershell
$publish = "$env:TEMP\meldingsmonitor-kiosk"
Remove-Item -Recurse -Force $publish -ErrorAction SilentlyContinue
Copy-Item -Recurse tools/station-screen-kiosk $publish
cd $publish
git init
git add .
git commit -m "feat: initial public release of MeldingsMonitor kiosk tooling"
gh repo create martijntenpas/meldingsmonitor-kiosk --public --source=. --remote=origin --push
```

## Updates doorzetten naar de publieke repo

Na wijzigingen in de monorepo:

```powershell
bash tools/station-screen-kiosk/scripts/publish-standalone-repo.sh
```

Het script synchroniseert bestanden naar een lokale clone van `meldingsmonitor-kiosk` en pusht naar GitHub.

## Installatie op Intel stick / Raspberry Pi

```bash
git clone https://github.com/martijntenpas/meldingsmonitor-kiosk.git
cd meldingsmonitor-kiosk
sudo bash scripts/install.sh
sudo reboot
```

## Monorepo vs publieke repo

| | Private monorepo | Publieke repo |
| --- | --- | --- |
| Doel | Ontwikkeling met MeldingsMonitor | Installatie op hardware |
| Inhoud | Alleen `tools/station-screen-kiosk/` | Zelfde map, root van repo |
| Geheimen | Geen in deze tooling | Geen |
