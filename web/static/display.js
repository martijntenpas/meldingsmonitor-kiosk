const setupUrl = document.getElementById('setup-url');
const setupQr = document.getElementById('setup-qr');
const stepWifi = document.getElementById('step-wifi');
const displayStatus = document.getElementById('display-status');
const displayHint = document.getElementById('display-hint');
const homepageSection = document.getElementById('homepage-section');
const homepageStatus = document.getElementById('homepage-status');

function setStatus(message) {
    if (displayStatus) {
        displayStatus.textContent = message;
    }
}

async function refreshDisplay() {
    const response = await fetch('/api/status', { headers: { Accept: 'application/json' } });
    const data = await response.json();

    setupUrl.textContent = data.setup_url || 'Onbekend';

    if (data.online) {
        setStatus(data.wifi_available
            ? 'Verbonden met internet via WiFi.'
            : 'Verbonden met internet via ethernet.');
    } else {
        setStatus('Geen internetverbinding. Controleer de kabel of WiFi-instellingen.');
    }

    if (data.setup_ap_active && data.setup_ssid) {
        stepWifi.textContent = `Verbind met WiFi-netwerk ${data.setup_ssid} als je nog geen internet hebt.`;
    } else if (data.online) {
        stepWifi.textContent = data.wifi_available
            ? 'Dit apparaat heeft internet. Scan de QR-code of open de setup-link.'
            : 'Dit apparaat heeft internet via ethernet. Open de setup-link op een andere computer in hetzelfde netwerk.';
    } else if (!data.wifi_available) {
        stepWifi.textContent = 'Geen internet. Controleer de ethernetkabel of open de setup-link via een andere computer in het netwerk.';
    }

    if (displayHint) {
        displayHint.textContent = data.online
            ? 'Werkt de QR-code niet? Typ de setup-link hierboven handmatig in je browser.'
            : 'Zonder internet: verbind eerst met WiFi of ethernet, daarna kun je de setup-link openen.';
    }

    setupQr.src = `/api/qr.svg?t=${Date.now()}`;

    if (!data.setup_needed && data.homepage_configured && data.homepage) {
        homepageSection.hidden = false;
        homepageStatus.textContent = `Kazernescherm is ingesteld. Bezig met laden: ${data.homepage}`;
        window.location.href = data.homepage;
    }
}

refreshDisplay().catch(() => {
    setupUrl.textContent = 'Instellingen laden mislukt';
    setStatus('Kan geen verbinding maken met de kiosk-server. Herstart de Pi of controleer mm-kiosk-web.service.');
});

setInterval(() => {
    refreshDisplay().catch(() => {});
}, 10000);
