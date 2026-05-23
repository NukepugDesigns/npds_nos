// Detect if running in an external browser versus FiveM client
const isBrowser = (typeof GetParentResourceName !== 'function');
const resourceName = isBrowser ? 'npds_nos' : GetParentResourceName();
let isTunerOpen = false;
let activeModalType = null;
let activeModalData = null;
let selectedRefillSlot = 1;
let activeRefillIsElite = false;

// Multi-Language Localization System
let Locales = {};

function translateDOM() {
    document.querySelectorAll('[data-locale]').forEach(elem => {
        const key = elem.getAttribute('data-locale');
        if (Locales[key]) {
            elem.innerHTML = Locales[key];
        }
    });
}

function _L(key, fallback = "") {
    return Locales[key] || fallback || key;
}

// HUD drag coordinates tracking variables
let isDraggingHud = false;
let dragStartX = 0;
let dragStartY = 0;
let hudStartX = 0;
let hudStartY = 0;

document.addEventListener('DOMContentLoaded', () => {
    // Load local position coordinates instantly
    loadSavedPosition();

    if (isBrowser) {
        // Auto-show test controls and HUD container in normal browser testing
        document.getElementById('browser-test-panel').style.display = 'block';
        const hud = document.getElementById('nos-hud');
        hud.style.display = 'flex';
        setTimeout(() => {
            hud.classList.remove('hidden');
        }, 10);
        setupBrowserListeners();
    }

    // Set up dragging listeners
    const dragOverlay = document.getElementById('nos-hud-drag-overlay');
    const nosHud = document.getElementById('nos-hud');

    dragOverlay.addEventListener('mousedown', (e) => {
        isDraggingHud = true;
        dragStartX = e.clientX;
        dragStartY = e.clientY;
        
        const rect = nosHud.getBoundingClientRect();
        hudStartX = rect.left;
        hudStartY = rect.top;
        
        e.preventDefault();
    });

    // Set up purge color pill click listeners
    const pills = document.querySelectorAll('.color-pill');
    pills.forEach(pill => {
        pill.addEventListener('click', () => {
            pills.forEach(p => p.classList.remove('active'));
            pill.classList.add('active');
            updatePurgeTuningPreview();
        });
    });

    window.addEventListener('mousemove', (e) => {
        if (!isDraggingHud) return;
        
        const dx = e.clientX - dragStartX;
        const dy = e.clientY - dragStartY;
        
        let newX = hudStartX + dx;
        let newY = hudStartY + dy;
        
        // Bounds checking
        const maxW = window.innerWidth - nosHud.offsetWidth;
        const maxH = window.innerHeight - nosHud.offsetHeight;
        
        newX = Math.max(0, Math.min(newX, maxW));
        newY = Math.max(0, Math.min(newY, maxH));
        
        nosHud.style.bottom = 'auto';
        nosHud.style.right = 'auto';
        nosHud.style.left = `${newX}px`;
        nosHud.style.top = `${newY}px`;
    });

    window.addEventListener('mouseup', () => {
        isDraggingHud = false;
    });
});

// Main Message Event Handler
window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.type === "loadLocale") {
        Locales = data.locales || {};
        translateDOM();
    }
    else if (data.type === "show") {
        const hud = document.getElementById('nos-hud');
        hud.style.display = 'flex';
        setTimeout(() => {
            hud.classList.remove('hidden');
        }, 10);
    } 
    else if (data.type === "hide") {
        const hud = document.getElementById('nos-hud');
        hud.classList.add('hidden');
        setTimeout(() => {
            if (hud.classList.contains('hidden')) {
                hud.style.display = 'none';
            }
        }, 500);
    } 
    else if (data.type === "update") {
        updateHUD(data.bottle1, data.bottle2, data.temp || 0.0, data.system, data.active);
    }
    else if (data.type === "openRefillModal") {
        openRefillModal(data.bottle1, data.bottle2, data.system, data.isElite || false);
    }
    else if (data.type === "openInstallModal") {
        openInstallModal(data.system);
    }
    else if (data.type === "openUninstallModal") {
        openUninstallModal();
    }
    else if (data.type === "closeModal") {
        closeNosModal(false);
    }
    else if (data.type === "enterDragMode") {
        const hud = document.getElementById('nos-hud');
        // Ensure HUD is visible so it can be dragged
        hud.style.display = 'flex';
        hud.classList.remove('hidden');
        document.getElementById('nos-hud-drag-overlay').style.display = 'flex';
    }
    else if (data.type === "openPurgeTuner") {
        openPurgeTuner(data.config || { xOffset: 0.5, yOffset: 0.05, zOffset: 0.0, angle: 20.0, pitch: 40.0 });
    }
    else if (data.type === "resetPosition") {
        resetHudPositionToDefault();
    }
});

// Position Handling functions
function loadSavedPosition() {
    const nosHud = document.getElementById('nos-hud');
    const saved = localStorage.getItem('nos_hud_pos');
    if (saved) {
        try {
            const pos = JSON.parse(saved);
            nosHud.style.bottom = 'auto';
            nosHud.style.right = 'auto';
            nosHud.style.left = `${pos.left}px`;
            nosHud.style.top = `${pos.top}px`;
        } catch (e) {
            console.error("Failed to parse saved HUD position", e);
        }
    } else {
        resetHudPositionToDefault();
    }
}

function resetHudPositionToDefault() {
    localStorage.removeItem('nos_hud_pos');
    const nosHud = document.getElementById('nos-hud');
    nosHud.style.top = 'auto';
    nosHud.style.right = 'auto';
    nosHud.style.bottom = '35px';
    nosHud.style.left = '320px';
}

function saveHudPosition(event) {
    if (event) event.stopPropagation();

    const nosHud = document.getElementById('nos-hud');
    const rect = nosHud.getBoundingClientRect();
    
    // Save left & top offsets
    const pos = {
        left: rect.left,
        top: rect.top
    };
    
    localStorage.setItem('nos_hud_pos', JSON.stringify(pos));
    document.getElementById('nos-hud-drag-overlay').style.display = 'none';

    // Clear focus
    if (!isBrowser) {
        fetch(`https://${GetParentResourceName()}/closeModal`, {
            method: 'POST'
        });
    } else {
        console.log("Browser Simulated: Custom HUD coordinates saved successfully", pos);
    }
}

// Update HUD Render
function updateHUD(b1, b2, temp, system, active) {
    const fluidB1 = document.getElementById('fluid-b1');
    const fluidB2 = document.getElementById('fluid-b2');
    const fluidTemp = document.getElementById('fluid-temp');
    const valB1 = document.getElementById('val-b1');
    const valB2 = document.getElementById('val-b2');
    const valTemp = document.getElementById('val-temp');
    const containerB2 = document.getElementById('container-b2');
    const led = document.getElementById('boost-status');

    // 1. Set values
    fluidB1.style.height = `${b1}%`;
    valB1.innerText = `${Math.round(b1)}%`;

    fluidB2.style.height = `${b2}%`;
    valB2.innerText = `${Math.round(b2)}%`;

    // Overheat value scaling: 0-100% maps to 50°C - 150°C
    fluidTemp.style.height = `${temp}%`;
    const actualTemp = Math.round(50 + (temp * 1.0));
    valTemp.innerText = `${actualTemp}°C`;

    // 2. Add 'low' warning color under 20%
    if (b1 < 20) {
        fluidB1.classList.add('low');
    } else {
        fluidB1.classList.remove('low');
    }

    if (b2 < 20) {
        fluidB2.classList.add('low');
    } else {
        fluidB2.classList.remove('low');
    }

    // 3. Add 'overheat' flashing color over 80% (130°C+)
    if (temp >= 80) {
        fluidTemp.classList.add('overheat');
    } else {
        fluidTemp.classList.remove('overheat');
    }

    // 4. System Slot Rendering (Hide second cylinder if 1-bottle system)
    if (system === 'single_nossystem') {
        containerB2.style.display = 'none';
    } else {
        containerB2.style.display = 'flex';
    }

    // 5. Boost active LED pulsing
    if (active) {
        led.classList.add('active');
    } else {
        led.classList.remove('active');
    }
}

// Custom Modal Dynamic Builders
function openRefillModal(b1, b2, system, isElite) {
    activeModalType = "refill";
    selectedRefillSlot = 1;
    activeRefillIsElite = isElite;
    
    document.getElementById('modal-title-text').innerText = isElite ? _L('nui_refill_elite_title', "NOS Elite Refit Tool") : _L('nui_refill_title', "Nitrous Oxide Refit Tool");
    
    let html = `<p>${isElite ? _L('nui_refill_elite_body', 'Choose a cylinder slot to refill. The technician will securely weld and calibrate the pressurized <strong>Elite (High-Capacity)</strong> cylinder.') : _L('nui_refill_body', 'Choose a cylinder slot to refill. The technician will securely weld and calibrate the pressurized <strong>Standard</strong> cylinder.')}</p>`;
    
    html += `
        <div class="modal-status-card selected" id="card-slot1" onclick="selectRefillSlot(1)">
            <div>
                <div class="modal-status-label">${_L('nui_refill_slot1', 'Cylinder Slot 1 (B1)')}</div>
                <div style="font-size: 11px; color: #888;">${_L('nui_refill_slot1_desc', 'Primary NOS Bottle')}</div>
            </div>
            <div class="modal-status-val" id="modal-val-b1">${Math.round(b1)}%</div>
        </div>
    `;
    
    if (system === 'dual_nossystem') {
        html += `
            <div class="modal-status-card bottle2-card" id="card-slot2" onclick="selectRefillSlot(2)">
                <div>
                    <div class="modal-status-label">${_L('nui_refill_slot2', 'Cylinder Slot 2 (B2)')}</div>
                    <div style="font-size: 11px; color: #888;">${_L('nui_refill_slot2_desc', 'Secondary NOS Bottle')}</div>
                </div>
                <div class="modal-status-val" id="modal-val-b2">${Math.round(b2)}%</div>
            </div>
        `;
    }
    
    html += `<div class="modal-desc">${isElite ? _L('nui_refill_elite_req', 'Requires 1x Elite Nitrous Cylinder item in inventory.') : _L('nui_refill_req', 'Requires 1x Standard Nitrous Cylinder item in inventory.')}</div>`;
    
    document.getElementById('modal-body-content').innerHTML = html;
    
    // Set up actions
    document.getElementById('modal-actions-container').innerHTML = `
        <button class="modal-btn modal-btn-cancel" onclick="closeNosModal(true)">${_L('nui_cancel', 'Cancel')}</button>
        <button class="modal-btn modal-btn-confirm" onclick="confirmRefillAction()">${_L('nui_refit_btn', 'Refit Bottle')}</button>
    `;
    
    document.getElementById('nos-modal-container').style.display = 'flex';
}

function selectRefillSlot(slot) {
    selectedRefillSlot = slot;
    document.getElementById('card-slot1').classList.remove('selected');
    const card2 = document.getElementById('card-slot2');
    if (card2) card2.classList.remove('selected');
    
    if (slot === 1) {
        document.getElementById('card-slot1').classList.add('selected');
    } else {
        document.getElementById('card-slot2').classList.add('selected');
    }
}

function confirmRefillAction() {
    if (!isBrowser) {
        fetch(`https://${GetParentResourceName()}/confirmRefill`, {
            method: 'POST',
            body: JSON.stringify({ slot: selectedRefillSlot, isElite: activeRefillIsElite })
        });
    } else {
        console.log(`Browser Simulated: Refilling slot ${selectedRefillSlot} (Elite: ${activeRefillIsElite})`);
    }
    closeNosModal(false);
}

function openInstallModal(systemType) {
    activeModalType = "install";
    activeModalData = systemType;
    
    const isDouble = systemType === 'dual_nossystem';
    document.getElementById('modal-title-text').innerText = _L('nui_install_title', "NOS Mount Installation");
    
    let html = `
        <p>${isDouble ? _L('nui_install_body_double', 'You are about to install a premium <strong>Dual-Bottle Nitrous Oxide Mount Rack</strong>.') : _L('nui_install_body_single', 'You are about to install a premium <strong>Single-Bottle Nitrous Oxide Mount Rack</strong>.')}</p>
        <p>${_L('nui_install_body_weld', "This structural modification welds pressurized brackets into the vehicle's chassis, routing custom fuel-injection lines straight to the engine intake manifold.")}</p>
        <div class="modal-status-card">
            <div>
                <div class="modal-status-label">${_L('nui_install_upgrade_type', 'Upgrade Type')}</div>
                <div style="font-size: 11px; color: #888;">${_L('nui_install_upgrade_desc', 'Chassis Modification')}</div>
            </div>
            <div class="modal-status-val" style="color: #f39c12;">${isDouble ? _L('nui_install_upgrade_double', '2-Bottle Rack') : _L('nui_install_upgrade_single', '1-Bottle Rack')}</div>
        </div>
        <div class="modal-desc">${_L('nui_install_req', 'Requires certified welding torch and certified brackets kit.')}</div>
    `;
    
    document.getElementById('modal-body-content').innerHTML = html;
    
    document.getElementById('modal-actions-container').innerHTML = `
        <button class="modal-btn modal-btn-cancel" onclick="closeNosModal(true)">${_L('nui_cancel', 'Cancel')}</button>
        <button class="modal-btn modal-btn-confirm" onclick="confirmInstallAction()">${_L('nui_weld_btn', 'Weld Mounts')}</button>
    `;
    
    document.getElementById('nos-modal-container').style.display = 'flex';
}

function confirmInstallAction() {
    if (!isBrowser) {
        fetch(`https://${GetParentResourceName()}/confirmInstall`, {
            method: 'POST',
            body: JSON.stringify({ system: activeModalData })
        });
    } else {
        console.log(`Browser Simulated: Installing system ${activeModalData}`);
    }
    closeNosModal(false);
}

function openUninstallModal() {
    activeModalType = "uninstall";
    
    document.getElementById('modal-title-text').innerText = _L('nui_uninstall_title', "Uninstall NOS System");
    
    let html = `
        <p>${_L('nui_uninstall_body', 'Are you sure you want to completely <strong>dismantle and uninstall</strong> the nitrous mounting brackets and plumbing lines from this vehicle?')}</p>
        <p>${_L('nui_uninstall_body_recover', 'Doing so will recover the raw installation rack kit and return it to your inventory.')}</p>
        <div class="modal-desc" style="color: #ff4757;">${_L('nui_uninstall_warning', 'WARNING: Any remaining gas pressure inside the installed cylinders will be lost!')}</div>
    `;
    
    document.getElementById('modal-body-content').innerHTML = html;
    
    document.getElementById('modal-actions-container').innerHTML = `
        <button class="modal-btn modal-btn-cancel" onclick="closeNosModal(true)">${_L('nui_cancel', 'Cancel')}</button>
        <button class="modal-btn modal-btn-confirm" style="background: #ff4757; color: white;" onclick="confirmUninstallAction()">${_L('nui_dismantle_btn', 'Dismantle')}</button>
    `;
    
    document.getElementById('nos-modal-container').style.display = 'flex';
}

function confirmUninstallAction() {
    if (!isBrowser) {
        fetch(`https://${GetParentResourceName()}/confirmUninstall`, {
            method: 'POST'
        });
    } else {
        console.log("Browser Simulated: Uninstalling NOS System");
    }
    closeNosModal(false);
}

// Close Modal wrapper
function closeNosModal(shouldNotifyLua = true) {
    document.getElementById('nos-modal-container').style.display = 'none';
    if (shouldNotifyLua && !isBrowser) {
        fetch(`https://${GetParentResourceName()}/closeModal`, {
            method: 'POST'
        });
    }
}

// Browser Testing Simulation
function setupBrowserListeners() {
    const s1 = document.getElementById('test-b1');
    const s2 = document.getElementById('test-b2');
    const sTemp = document.getElementById('test-temp');
    const mode = document.getElementById('test-mode');
    const active = document.getElementById('test-active');

    const triggerUpdate = () => {
        const sys = (mode.value === "1") ? 'single_nossystem' : 'dual_nossystem';
        updateHUD(parseFloat(s1.value), parseFloat(s2.value), parseFloat(sTemp.value), sys, active.checked);
    };

    s1.addEventListener('input', triggerUpdate);
    s2.addEventListener('input', triggerUpdate);
    sTemp.addEventListener('input', triggerUpdate);
    mode.addEventListener('change', triggerUpdate);
    active.addEventListener('change', triggerUpdate);

    triggerUpdate();
}

function togglePreviewHud() {
    const hud = document.getElementById('nos-hud');
    if (hud.classList.contains('hidden')) {
        hud.style.display = 'flex';
        setTimeout(() => {
            hud.classList.remove('hidden');
        }, 10);
    } else {
        hud.classList.add('hidden');
        setTimeout(() => {
            if (hud.classList.contains('hidden')) {
                hud.style.display = 'none';
            }
        }, 500);
    }
}

// Browser preview modals trigger
function testRefillModal() {
    openRefillModal(35.0, 80.0, 'dual_nossystem', true);
}

function testInstallModal() {
    openInstallModal('dual_nossystem');
}

// Interactive Purge Alignment Tuner JS Logic
let originalPurgeConfig = null;

function openPurgeTuner(config) {
    originalPurgeConfig = { ...config };
    isTunerOpen = true;
    
    // Set slider values
    document.getElementById('slider-tuner-x').value = config.xOffset !== undefined ? config.xOffset : 0.50;
    document.getElementById('slider-tuner-y').value = config.yOffset !== undefined ? config.yOffset : 0.05;
    document.getElementById('slider-tuner-z').value = config.zOffset !== undefined ? config.zOffset : 0.00;
    document.getElementById('slider-tuner-angle').value = config.angle !== undefined ? config.angle : 20;
    document.getElementById('slider-tuner-pitch').value = config.pitch !== undefined ? config.pitch : 40;
    
    // Update display labels
    document.getElementById('val-tuner-x').innerText = (config.xOffset !== undefined ? config.xOffset : 0.50).toFixed(2) + 'm';
    document.getElementById('val-tuner-y').innerText = (config.yOffset !== undefined ? config.yOffset : 0.05).toFixed(2) + 'm';
    document.getElementById('val-tuner-z').innerText = (config.zOffset !== undefined ? config.zOffset : 0.00).toFixed(2) + 'm';
    document.getElementById('val-tuner-angle').innerText = (config.angle !== undefined ? config.angle : 20) + '°';
    document.getElementById('val-tuner-pitch').innerText = (config.pitch !== undefined ? config.pitch : 40) + '°';
    
    // Set active color pill selection
    const activeColor = config.color !== undefined ? config.color : 'white';
    document.querySelectorAll('.color-pill').forEach(pill => {
        if (pill.getAttribute('data-color') === activeColor) {
            pill.classList.add('active');
        } else {
            pill.classList.remove('active');
        }
    });

    // Show panel
    document.getElementById('nos-purge-tuner').style.display = 'flex';
    
    // Request client to start live preview loop
    if (!isBrowser) {
        fetch(`https://${resourceName}/startPurgePreview`, {
            method: 'POST',
            body: JSON.stringify(config)
        });
    } else {
        console.log("Browser Simulated: Purge alignment tuner opened with", config);
    }
}

function updatePurgeTuningPreview() {
    const x = parseFloat(document.getElementById('slider-tuner-x').value);
    const y = parseFloat(document.getElementById('slider-tuner-y').value);
    const z = parseFloat(document.getElementById('slider-tuner-z').value);
    const angle = parseInt(document.getElementById('slider-tuner-angle').value);
    const pitch = parseInt(document.getElementById('slider-tuner-pitch').value);
    
    // Get active color pill
    const activePill = document.querySelector('.color-pill.active');
    const color = activePill ? activePill.getAttribute('data-color') : 'white';

    document.getElementById('val-tuner-x').innerText = x.toFixed(2) + 'm';
    document.getElementById('val-tuner-y').innerText = y.toFixed(2) + 'm';
    document.getElementById('val-tuner-z').innerText = z.toFixed(2) + 'm';
    document.getElementById('val-tuner-angle').innerText = angle + '°';
    document.getElementById('val-tuner-pitch').innerText = pitch + '°';
    
    const config = { xOffset: x, yOffset: y, zOffset: z, angle: angle, pitch: pitch, color: color };
    
    if (!isBrowser) {
        fetch(`https://${resourceName}/updatePurgePreview`, {
            method: 'POST',
            body: JSON.stringify(config)
        });
    } else {
        console.log("Browser Simulated: Real-time purge preview updated", config);
    }
}

function savePurgeTuning() {
    const x = parseFloat(document.getElementById('slider-tuner-x').value);
    const y = parseFloat(document.getElementById('slider-tuner-y').value);
    const z = parseFloat(document.getElementById('slider-tuner-z').value);
    const angle = parseInt(document.getElementById('slider-tuner-angle').value);
    const pitch = parseInt(document.getElementById('slider-tuner-pitch').value);
    
    // Get active color pill
    const activePill = document.querySelector('.color-pill.active');
    const color = activePill ? activePill.getAttribute('data-color') : 'white';

    const config = { xOffset: x, yOffset: y, zOffset: z, angle: angle, pitch: pitch, color: color };
    document.getElementById('nos-purge-tuner').style.display = 'none';
    isTunerOpen = false;
    
    if (!isBrowser) {
        fetch(`https://${resourceName}/savePurgeTuning`, {
            method: 'POST',
            body: JSON.stringify(config)
        });
    } else {
        console.log("Browser Simulated: Custom purge coordinates saved", config);
    }
}

function cancelPurgeTuning() {
    document.getElementById('nos-purge-tuner').style.display = 'none';
    isTunerOpen = false;
    
    if (!isBrowser) {
        fetch(`https://${resourceName}/cancelPurgeTuning`, {
            method: 'POST',
            body: JSON.stringify(originalPurgeConfig)
        });
    } else {
        console.log("Browser Simulated: Custom purge alignment cancelled, original config restored", originalPurgeConfig);
    }
}

function toggleTunerCamera() {
    if (!isBrowser) {
        fetch(`https://${resourceName}/toggleTuningCamera`, {
            method: 'POST'
        });
    } else {
        console.log("Browser Simulated: Toggled tuning camera view");
    }
}

// ==========================================
// CAMERA CONTROLS (Drag to rotate & Wheel to zoom)
// ==========================================
let isDraggingCam = false;
let previousCamX = 0;
let previousCamY = 0;

window.addEventListener('mousedown', function(e) {
    const tuner = document.getElementById('nos-purge-tuner');
    if (isTunerOpen && tuner && !e.target.closest('#nos-purge-tuner')) {
        isDraggingCam = true;
        previousCamX = e.clientX;
        previousCamY = e.clientY;
    }
});

window.addEventListener('mouseup', function() {
    isDraggingCam = false;
});

window.addEventListener('mousemove', function(e) {
    if (isDraggingCam) {
        let deltaX = e.clientX - previousCamX;
        let deltaY = e.clientY - previousCamY;
        previousCamX = e.clientX;
        previousCamY = e.clientY;

        if (!isBrowser) {
            fetch(`https://${resourceName}/camMove`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ x: deltaX, y: deltaY })
            });
        } else {
            console.log("Browser Simulated: Camera moved", deltaX, deltaY);
        }
    }
});

window.addEventListener('wheel', function(e) {
    const tuner = document.getElementById('nos-purge-tuner');
    if (isTunerOpen && tuner && !e.target.closest('#nos-purge-tuner')) {
        if (!isBrowser) {
            fetch(`https://${resourceName}/camZoom`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ direction: Math.sign(e.deltaY) })
            });
        } else {
            console.log("Browser Simulated: Camera zoomed", Math.sign(e.deltaY));
        }
    }
});

