const wifiSelect = document.getElementById('wifi-ssid');
const wifiPassword = document.getElementById('wifi-password');
const wifiBtn = document.getElementById('wifi-btn');
const scanBtn = document.getElementById('scan-btn');
const homepageInput = document.getElementById('homepage');
const saveBtn = document.getElementById('save-btn');
const finishBtn = document.getElementById('finish-btn');
const resetBtn = document.getElementById('reset-btn');
const wifiFeedback = document.getElementById('wifi-feedback');
const configFeedback = document.getElementById('config-feedback');
const resetFeedback = document.getElementById('reset-feedback');
const statusOnline = document.getElementById('status-online');
const statusSetup = document.getElementById('status-setup');
const setupSsid = document.getElementById('setup-ssid');

function showFeedback(element, message, type = 'success') {
    element.hidden = false;
    element.textContent = message;
    element.className = `feedback ${type}`;
}

async function fetchJson(url, options = {}) {
    const response = await fetch(url, {
        headers: {
            'Content-Type': 'application/json',
            Accept: 'application/json',
        },
        ...options,
    });

    const data = await response.json().catch(() => ({}));

    if (!response.ok) {
        throw new Error(data.message || 'Er ging iets mis.');
    }

    return data;
}

async function loadStatus() {
    const data = await fetchJson('/api/status');
    statusOnline.textContent = data.online ? 'Verbonden' : 'Geen verbinding';
    statusSetup.textContent = data.setup_completed ? 'Afgerond' : 'Nog instellen';
    setupSsid.textContent = data.setup_ap_ip ? `MeldingsMonitor-Setup (via ${data.setup_ap_ip})` : 'MeldingsMonitor-Setup';

    if (data.homepage) {
        homepageInput.value = data.homepage;
    }
}

async function scanWifi() {
    wifiSelect.innerHTML = '<option value="">Scannen...</option>';
    const data = await fetchJson('/api/wifi/scan');
    wifiSelect.innerHTML = '<option value="">Kies een netwerk</option>';

    data.networks.forEach((network) => {
        const option = document.createElement('option');
        option.value = network.ssid;
        option.textContent = `${network.ssid} (${network.signal}%)${network.secured ? '' : ' · open'}`;
        wifiSelect.appendChild(option);
    });
}

async function connectWifi() {
    wifiBtn.disabled = true;
    wifiFeedback.hidden = true;

    try {
        const data = await fetchJson('/api/wifi/connect', {
            method: 'POST',
            body: JSON.stringify({
                ssid: wifiSelect.value,
                password: wifiPassword.value,
            }),
        });

        showFeedback(wifiFeedback, data.online ? 'WiFi gekoppeld en internet bereikbaar.' : 'WiFi gekoppeld, maar nog geen internet.', data.online ? 'success' : 'error');
        await loadStatus();
    } catch (error) {
        showFeedback(wifiFeedback, error.message, 'error');
    } finally {
        wifiBtn.disabled = false;
    }
}

async function saveConfig(complete = false) {
    const button = complete ? finishBtn : saveBtn;
    button.disabled = true;
    configFeedback.hidden = true;

    try {
        await fetchJson('/api/config', {
            method: 'POST',
            body: JSON.stringify({
                homepage: homepageInput.value.trim(),
                complete,
            }),
        });

        if (complete) {
            showFeedback(configFeedback, 'Opgeslagen. Apparaat herstart en opent het kazernescherm automatisch...', 'success');
            await fetchJson('/api/reboot', { method: 'POST' });
            return;
        }

        showFeedback(configFeedback, 'Kazernescherm-link opgeslagen.', 'success');
        await loadStatus();
    } catch (error) {
        showFeedback(configFeedback, error.message, 'error');
    } finally {
        button.disabled = false;
    }
}

async function factoryReset() {
    const confirmed = window.confirm(
        'Weet je het zeker? WiFi-profielen en kazernescherm-instellingen worden gewist. Het apparaat herstart daarna automatisch.',
    );

    if (!confirmed) {
        return;
    }

    resetBtn.disabled = true;
    resetFeedback.hidden = true;

    try {
        await fetchJson('/api/factory-reset', {
            method: 'POST',
            body: JSON.stringify({ confirm: true }),
        });

        showFeedback(resetFeedback, 'Factory reset gestart. Apparaat herstart...', 'success');
    } catch (error) {
        showFeedback(resetFeedback, error.message, 'error');
        resetBtn.disabled = false;
    }
}

wifiBtn.addEventListener('click', connectWifi);
scanBtn.addEventListener('click', scanWifi);
saveBtn.addEventListener('click', () => saveConfig(false));
finishBtn.addEventListener('click', () => saveConfig(true));
resetBtn.addEventListener('click', factoryReset);

loadStatus().then(scanWifi).catch((error) => {
    showFeedback(configFeedback, error.message, 'error');
});
