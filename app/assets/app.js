// Client-side interactions for docker-cicd-pipeline
document.addEventListener('DOMContentLoaded', () => {
    const healthOutput = document.getElementById('health-output');
    const pingButton = document.getElementById('btn-ping-health');
    const uptimeDisplay = document.getElementById('uptime-display');
    const versionBadge = document.getElementById('version-badge');
    const buildIdEl = document.getElementById('build-id');

    const startTime = Date.now();

    // Update uptime counter every second
    function updateUptime() {
        const elapsed = Math.floor((Date.now() - startTime) / 1000);
        const hours = String(Math.floor(elapsed / 3600)).padStart(2, '0');
        const minutes = String(Math.floor((elapsed % 3600) / 60)).padStart(2, '0');
        const seconds = String(elapsed % 60).padStart(2, '0');
        if (uptimeDisplay) {
            uptimeDisplay.textContent = `${hours}h ${minutes}m ${seconds}s`;
        }
    }
    setInterval(updateUptime, 1000);

    // Fetch and display health status from /healthz
    async function checkHealth() {
        if (!healthOutput) return;
        healthOutput.textContent = 'Pinging /healthz...';
        try {
            const start = performance.now();
            const response = await fetch('/healthz', { cache: 'no-store' });
            const duration = Math.round(performance.now() - start);
            const data = await response.json();

            const formatted = {
                http_status: response.status,
                status_text: response.statusText,
                latency_ms: duration,
                payload: data
            };

            healthOutput.textContent = JSON.stringify(formatted, null, 2);
        } catch (err) {
            healthOutput.textContent = `Error reaching /healthz endpoint:\n${err.message}`;
        }
    }

    // Attempt to load build metadata from /version.json
    async function loadVersionInfo() {
        try {
            const response = await fetch('/version.json', { cache: 'no-store' });
            if (response.ok) {
                const info = await response.json();
                if (info.version && versionBadge) {
                    versionBadge.textContent = `v${info.version}`;
                }
                if (info.commit && buildIdEl) {
                    buildIdEl.textContent = `${info.version || '1.0.0'}-${info.commit.substring(0, 7)}`;
                }
            }
        } catch (_) {
            // Default static values remain if version.json is not present
        }
    }

    if (pingButton) {
        pingButton.addEventListener('click', checkHealth);
    }

    // Initialize
    loadVersionInfo();
    checkHealth();
});
