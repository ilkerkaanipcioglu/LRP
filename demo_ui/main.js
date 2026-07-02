// LRP Interactive Presentation Logic

document.addEventListener('DOMContentLoaded', () => {
    initNavigation();
    initCompetitorTabs();
    initGraphSimulator();
    initEventSimulator();
    initLedgerSimulator();
    initAgentSimulator();
    initPluggableAppsSimulator();
});

// 1. Navigation Flow (Slide Transitions)
function initNavigation() {
    const navItems = document.querySelectorAll('.nav-steps .nav-item');
    const slides = document.querySelectorAll('.slide-content');
    const btnNext = document.getElementById('btn-next');
    const btnPrev = document.getElementById('btn-prev');
    const currentStepBubble = document.getElementById('current-step-bubble');
    let currentStep = 1;

    function goToStep(step) {
        if (step < 1 || step > 7) return;
        currentStep = step;

        // Update nav active states
        navItems.forEach(item => {
            if (parseInt(item.dataset.step) === currentStep) {
                item.classList.add('active');
            } else {
                item.classList.remove('active');
            }
        });

        // Update active slide
        slides.forEach((slide, index) => {
            if (index + 1 === currentStep) {
                slide.classList.add('active');
            } else {
                slide.classList.remove('active');
            }
        });

        // Update buttons
        btnPrev.disabled = currentStep === 1;
        if (currentStep === 7) {
            btnNext.innerHTML = 'Tamamla <i class="fa-solid fa-check"></i>';
        } else {
            btnNext.innerHTML = 'İleri <i class="fa-solid fa-arrow-right"></i>';
        }

        // Update header bubble
        currentStepBubble.textContent = currentStep;
    }

    navItems.forEach(item => {
        item.addEventListener('click', () => {
            goToStep(parseInt(item.dataset.step));
        });
    });

    btnNext.addEventListener('click', () => {
        if (currentStep === 7) {
            alert('LRP İnteraktif Tanıtım Demosunu tamamladınız! Sistemi incelemeye devam edebilirsiniz.');
        } else {
            goToStep(currentStep + 1);
        }
    });

    btnPrev.addEventListener('click', () => {
        goToStep(currentStep - 1);
    });
}

// 2. Competitor Tabs (Slide 2)
function initCompetitorTabs() {
    const tabButtons = document.querySelectorAll('.tabs-header .tab-btn');
    const tabPanes = document.querySelectorAll('.tabs-content .tab-pane');

    tabButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            tabButtons.forEach(b => b.classList.remove('active'));
            tabPanes.forEach(pane => pane.classList.remove('active'));

            btn.classList.add('active');
            const tabId = `tab-${btn.dataset.tab}`;
            document.getElementById(tabId).classList.add('active');
        });
    });
}

// 3. Graph Simulator (Slide 3)
function initGraphSimulator() {
    const graphCanvas = document.getElementById('graph-canvas');
    const btnAddEntity = document.getElementById('btn-add-entity');
    const inputName = document.getElementById('entity-name');
    const selectType = document.getElementById('entity-type');

    // Default graph nodes
    const nodes = [
        { id: '1', name: 'Hermes Agent', type: 'Party', x: 50, y: 50 },
        { id: '2', name: 'LRP Core', type: 'Resource', x: 280, y: 150 },
        { id: '3', name: 'Fatura #77', type: 'Document', x: 80, y: 160 },
        { id: '4', name: 'Müşteri A.Ş.', type: 'Party', x: 180, y: 40 }
    ];

    const relations = [
        { from: '1', to: '2', type: 'runs_on' },
        { from: '3', to: '4', type: 'billed_to' },
        { from: '1', to: '3', type: 'processed_by' }
    ];

    // Create SVG overlays for lines
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('class', 'graph-svg');
    graphCanvas.appendChild(svg);

    function renderGraph() {
        // Clear nodes (keep SVG)
        const oldNodes = graphCanvas.querySelectorAll('.graph-node');
        oldNodes.forEach(node => node.remove());
        svg.innerHTML = '';

        // Draw connections (relations)
        relations.forEach(rel => {
            const fromNode = nodes.find(n => n.id === rel.from);
            const toNode = nodes.find(n => n.id === rel.to);
            if (fromNode && toNode) {
                const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
                // Calculate center coordinates
                const x1 = fromNode.x + 45;
                const y1 = fromNode.y + 20;
                const x2 = toNode.x + 45;
                const y2 = toNode.y + 20;

                line.setAttribute('x1', x1);
                line.setAttribute('y1', y1);
                line.setAttribute('x2', x2);
                line.setAttribute('y2', y2);
                line.setAttribute('class', 'relation-path');
                
                // Add tooltip title for relation type
                const title = document.createElementNS('http://www.w3.org/2000/svg', 'title');
                title.textContent = rel.type;
                line.appendChild(title);

                svg.appendChild(line);
            }
        });

        // Draw nodes
        nodes.forEach(node => {
            const div = document.createElement('div');
            div.className = `graph-node ${node.type}`;
            div.style.left = `${node.x}px`;
            div.style.top = `${node.y}px`;

            div.innerHTML = `
                <div class="graph-node-title">${node.name}</div>
                <div class="graph-node-subtitle">${node.type}</div>
            `;

            // Make node draggable
            makeDraggable(div, node);

            graphCanvas.appendChild(div);
        });
    }

    function makeDraggable(element, nodeData) {
        let pos1 = 0, pos2 = 0, pos3 = 0, pos4 = 0;
        element.onmousedown = dragMouseDown;

        function dragMouseDown(e) {
            e = e || window.event;
            e.preventDefault();
            pos3 = e.clientX;
            pos4 = e.clientY;
            document.onmouseup = closeDragElement;
            document.onmousemove = elementDrag;
        }

        function elementDrag(e) {
            e = e || window.event;
            e.preventDefault();
            pos1 = pos3 - e.clientX;
            pos2 = pos4 - e.clientY;
            pos3 = e.clientX;
            pos4 = e.clientY;
            
            // Boundary constraints inside canvas
            let newX = element.offsetLeft - pos1;
            let newY = element.offsetTop - pos2;
            
            if (newX >= 0 && newX <= graphCanvas.clientWidth - 95) {
                element.style.left = newX + "px";
                nodeData.x = newX;
            }
            if (newY >= 0 && newY <= graphCanvas.clientHeight - 55) {
                element.style.top = newY + "px";
                nodeData.y = newY;
            }
            
            renderGraph();
        }

        function closeDragElement() {
            document.onmouseup = null;
            document.onmousemove = null;
        }
    }

    btnAddEntity.addEventListener('click', () => {
        const name = inputName.value.trim();
        const type = selectType.value;

        if (!name) {
            alert('Lütfen nesne adı girin.');
            return;
        }

        // Generate random node coordinates in the center area
        const x = Math.floor(Math.random() * (graphCanvas.clientWidth - 150)) + 30;
        const y = Math.floor(Math.random() * (graphCanvas.clientHeight - 100)) + 30;
        const newId = (nodes.length + 1).toString();

        nodes.push({ id: newId, name, type, x, y });

        // Connect new node to one of the existing nodes randomly to build graph
        if (nodes.length > 1) {
            const targetIndex = Math.floor(Math.random() * (nodes.length - 1));
            const target = nodes[targetIndex];
            relations.push({ from: newId, to: target.id, type: 'related_to' });
        }

        inputName.value = '';
        renderGraph();

        // Write log of insertion
        addLogLine('entity_created', `OBJECT(type: "${type}", name: "${name}") grafa yerleştirildi.`, 'success');
    });

    renderGraph();
}

// Helper to write to simulated logs (Slide 4)
function addLogLine(eventType, message, status = 'info') {
    const logOutput = document.getElementById('log-output');
    if (!logOutput) return;

    const now = new Date();
    const timeStr = now.toTimeString().split(' ')[0];
    
    const div = document.createElement('div');
    div.className = 'log-line';
    
    let statusClass = '';
    if (status === 'success') statusClass = 'log-success';
    if (status === 'error') statusClass = 'log-error';
    if (status === 'warn') statusClass = 'log-warn';

    div.innerHTML = `
        <span class="log-time">[${timeStr}]</span>
        <span class="log-tag">[LRP.Event]</span>
        <span class="log-event-name">${eventType}</span> -> 
        <span class="${statusClass}">${message}</span>
    `;

    logOutput.appendChild(div);
    logOutput.scrollTop = logOutput.scrollHeight;
}

// 4. Event Simulator (Slide 4)
function initEventSimulator() {
    const eventButtons = document.querySelectorAll('.btn-event-trigger');
    const maturityProgress = document.getElementById('maturity-progress');
    const maturityScoreVal = document.getElementById('maturity-score-val');
    let score = 72;

    eventButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            const eventType = btn.dataset.event;
            const payload = btn.dataset.payload;

            // Trigger log line
            addLogLine(eventType, `Payload: ${payload}`, 'info');

            // Increase maturity score slightly on events
            if (score < 100) {
                score = Math.min(100, score + 4);
                maturityProgress.style.width = `${score}%`;
                maturityScoreVal.textContent = `${score}%`;

                if (score >= 90) {
                    maturityScoreVal.className = 'score-badge';
                    maturityScoreVal.style.borderColor = 'var(--green)';
                    maturityScoreVal.style.color = 'var(--green)';
                }
            }
        });
    });

    // Populate initial logs
    addLogLine('system_init', 'LRP Application runtime started on BEAM successfully.', 'success');
    addLogLine('tenant_created', 'Tenant "Harezm Demo A.Ş." active.', 'success');
    addLogLine('actor_registered', 'Actor "Hermes Agent" (Agent) and "İlker" (Human) registered.', 'success');
}

// 5. Ledger Simulator (Slide 5)
function initLedgerSimulator() {
    const btnTogglePeriod = document.getElementById('btn-toggle-period');
    const periodLockIndicator = document.getElementById('period-lock-indicator');
    const btnPostLedger = document.getElementById('btn-post-ledger');
    const ledgerAmount = document.getElementById('ledger-amount');
    const ledgerEntries = document.getElementById('ledger-entries');
    const ledgerEmpty = document.getElementById('ledger-empty');
    let isPeriodOpen = true;

    btnTogglePeriod.addEventListener('click', () => {
        isPeriodOpen = !isPeriodOpen;

        if (isPeriodOpen) {
            periodLockIndicator.className = 'status-pill open';
            periodLockIndicator.innerHTML = '<i class="fa-solid fa-lock-open"></i> AÇIK';
            addLogLine('period_opened', 'FiscalPeriod Temmuz 2026 kilidi AÇILDI.', 'warn');
        } else {
            periodLockIndicator.className = 'status-pill closed';
            periodLockIndicator.innerHTML = '<i class="fa-solid fa-lock"></i> KİLİTLİ';
            addLogLine('period_locked', 'FiscalPeriod Temmuz 2026 kilidi KAPATILDI (DB kısıtı devrede).', 'error');
        }
    });

    btnPostLedger.addEventListener('click', () => {
        const amount = parseFloat(ledgerAmount.value);
        if (isNaN(amount) || amount <= 0) {
            alert('Lütfen geçerli bir tutar girin.');
            return;
        }

        if (!isPeriodOpen) {
            // Failure logging representing {:error, :fiscal_period_closed_or_missing}
            addLogLine('journal_posting_failed', 'DB level constraint failed: Fiscal Period is closed!', 'error');
            alert('Hata: {:error, :fiscal_period_closed_or_missing}\nTemmuz 2026 dönemi kilitli olduğundan yevmiye kaydı yapılamaz!');
            return;
        }

        // Successful posting
        ledgerEmpty.style.display = 'none';

        const journalId = Math.floor(Math.random() * 90000) + 10000;
        const div = document.createElement('div');
        div.className = 'journal-card';
        div.innerHTML = `
            <div class="journal-header">
                <span>Journal ID: JV-${journalId}</span>
                <span>Tarih: ${new Date().toISOString().split('T')[0]} (Temmuz 2026)</span>
            </div>
            <table class="journal-table">
                <thead>
                    <tr class="table-header-row">
                        <th>Hesap No</th>
                        <th>Hesap Adı</th>
                        <th class="text-right">Borç (Debit)</th>
                        <th class="text-right">Alacak (Credit)</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td>120.01.001</td>
                        <td>Alıcılar (Müşteri A.Ş.)</td>
                        <td class="text-right text-green">${amount.toFixed(2)}</td>
                        <td class="text-right">0.00</td>
                    </tr>
                    <tr>
                        <td>600.01.001</td>
                        <td>Yurtiçi Satışlar</td>
                        <td class="text-right">0.00</td>
                        <td class="text-right text-purple">${amount.toFixed(2)}</td>
                    </tr>
                </tbody>
            </table>
        `;

        ledgerEntries.insertBefore(div, ledgerEntries.firstChild);

        addLogLine('journal_posted', `Yevmiye kaydı JV-${journalId} başarıyla deftere işlendi. Tutar: ${amount} TRY`, 'success');
    });
}

// 6. Agent Simulator (Slide 6)
function initAgentSimulator() {
    const slider = document.getElementById('confidence-slider');
    const pctDisplay = document.getElementById('confidence-pct');
    const btnSimulate = document.getElementById('btn-simulate-decision');
    const explainOutput = document.getElementById('explainability-output');

    slider.addEventListener('input', () => {
        pctDisplay.textContent = `${slider.value}%`;
        if (parseInt(slider.value) < 80) {
            pctDisplay.style.color = 'var(--red)';
        } else {
            pctDisplay.style.color = 'var(--cyan)';
        }
    });

    btnSimulate.addEventListener('click', () => {
        const confidence = parseInt(slider.value) / 100;
        const now = new Date().toISOString();
        const reasoningTrace = `1. Analiz ediliyor: Gelen e-posta içeriği "Sipariş onayı bekliyoruz".
2. Fatura nesnesi OBJECT ID: a57c3d41-6f9a-4ad4-a21a-cf4c77fc7f9b bulundu.
3. İşlem Güven Oranı: ${confidence.toFixed(2)}.
${confidence < 0.8 ? '4. UYARI: Güven skoru limit altında (< 0.80)! İşlem otomatik eskalasyona yönlendirildi.\n5. Karar: PROCESS_TASK oluşturalım, insan (İlker) onaylasın.' : '4. Karar: Güven skoru limit üstü (>= 0.80).\n5. Karar: Faturayı otomatik onaylayalım, JOURNAL kaydı oluşturulabilir.'}`;

        explainOutput.innerHTML = `
            <div class="explain-header-row">
                <span>Model: Gemini 2.5 Flash</span>
                <span>Zaman: ${now}</span>
            </div>
            <div>
                <strong>Güven Katsayısı (confidence_score):</strong> 
                <span class="${confidence < 0.8 ? 'text-red' : 'text-green'}">${confidence.toFixed(2)}</span>
            </div>
            <div style="margin-top: 0.5rem;">
                <strong>Prompt Hash:</strong> <code>sha256:d8b2d4f82a1772c...</code>
            </div>
            <div style="margin-top: 0.5rem;">
                <strong>Düşünce Zinciri (reasoning_trace):</strong>
                <pre class="reasoning-text">${reasoningTrace}</pre>
            </div>
        `;

        if (confidence < 0.8) {
            addLogLine('agent_confidence_low', `Ajan confidence limit altında (${confidence.toFixed(2)}). ProcessTask: 'İnsan onayı bekliyor' oluşturuldu.`, 'warn');
        } else {
            addLogLine('agent_approved', `Ajan işlemi onayladı. Confidence: ${confidence.toFixed(2)}.`, 'success');
        }
    });
}

// 7. Pluggable Apps Simulator (Slide 7)
function initPluggableAppsSimulator() {
    const btnFix = document.getElementById('btn-fix-discrepancy');
    const discCountText = document.getElementById('disc-count');
    const stageBadge = document.getElementById('migration-stage-badge');
    
    const steps = {
        shadow: document.getElementById('mstep-shadow'),
        partial: document.getElementById('mstep-partial'),
        primary: document.getElementById('mstep-primary'),
        cutover: document.getElementById('mstep-cutover')
    };

    let discrepancies = 3;
    let currentStage = 'shadow';

    btnFix.addEventListener('click', () => {
        if (currentStage === 'cutover') {
            alert('Geçiş zaten başarıyla tamamlandı (Full Cutover)! Eski provider pasif/deprecated durumda.');
            return;
        }

        if (discrepancies > 0) {
            discrepancies--;
            discCountText.textContent = discrepancies;
            addLogLine('discrepancy_resolved', `MigrationTracker: Uyuşmazlık çözüldü. Kalan uyuşmazlık: ${discrepancies}`, 'success');

            if (discrepancies === 0) {
                // Move to next stage
                if (currentStage === 'shadow') {
                    currentStage = 'partial';
                    steps.shadow.className = 'm-step done';
                    steps.partial.className = 'm-step active';
                    stageBadge.textContent = 'KISMİ MOD (PARTIAL)';
                    stageBadge.className = 'status-pill partial';
                    discrepancies = 2;
                    discCountText.textContent = discrepancies;
                    addLogLine('migration_stage_up', 'MigrationTracker stage yükseltildi: shadow -> partial', 'warn');
                } else if (currentStage === 'partial') {
                    currentStage = 'primary';
                    steps.partial.className = 'm-step done';
                    steps.primary.className = 'm-step active';
                    stageBadge.textContent = 'ANA MOD (PRIMARY)';
                    stageBadge.className = 'status-pill primary';
                    discrepancies = 1;
                    discCountText.textContent = discrepancies;
                    addLogLine('migration_stage_up', 'MigrationTracker stage yükseltildi: partial -> primary (eski sisteme senkron paralel yazılıyor)', 'warn');
                } else if (currentStage === 'primary') {
                    currentStage = 'cutover';
                    steps.primary.className = 'm-step done';
                    steps.cutover.className = 'm-step done active';
                    stageBadge.textContent = 'TAM CUTOVER';
                    stageBadge.className = 'status-pill cutover';
                    discCountText.textContent = 0;
                    btnFix.disabled = true;
                    btnFix.textContent = 'Geçiş Tamamlandı';
                    addLogLine('migration_completed', 'MIGRATION COMPLETED! Eski provider deprecated işaretlendi.', 'success');
                    alert('Tebrikler! IT/İnsan onayı ile FULL CUTOVER geçişi başarıyla tamamlandı.');
                }
            }
        }
    });
}
