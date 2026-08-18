const setupUrl = document.getElementById('setup-url');
const setupQr = document.getElementById('setup-qr');
const stepWifi = document.getElementById('step-wifi');

async function refreshDisplay() {
    const response = await fetch('/api/status', { headers: { Accept: 'application/json' } });
    const data = await response.json();

    setupUrl.textContent = data.setup_url || 'Onbekend';

    if (data.setup_ap_active && data.setup_ssid) {
        stepWifi.textContent = `Verbind met WiFi-netwerk ${data.setup_ssid} als je nog geen internet hebt.`;
    } else if (data.online) {
        stepWifi.textContent = data.wifi_available
            ? 'Dit apparaat heeft internet. Scan de QR-code om verder te gaan.'
            : 'Dit apparaat heeft internet via ethernet. Open de setup-link op een andere computer in hetzelfde netwerk.';
    } else if (!data.wifi_available) {
        stepWifi.textContent = 'Geen internet. Controleer de ethernetkabel of open de setup-link via een andere computer in het netwerk.';
    }

    setupQr.src = `/api/qr.svg?t=${Date.now()}`;

    if (!data.setup_needed && data.homepage_configured) {
        window.location.href = '/';
    }
}

refreshDisplay().catch(() => {
    setupUrl.textContent = 'Instellingen laden mislukt';
});

setInterval(() => {
    refreshDisplay().catch(() => {});
}, 10000);
