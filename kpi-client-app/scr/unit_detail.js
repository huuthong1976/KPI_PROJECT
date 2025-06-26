// unit_detail.js
const API_BASE_URL = 'http://127.0.0.1:5001';
let kpiDetailChart;
checkAuth()
document.addEventListener('DOMContentLoaded', async () => {
    await populateUnitSelector();
    // Tự động tải dữ liệu cho đơn vị đầu tiên trong danh sách
    loadUnitData();
    
    document.getElementById('unitSelector').addEventListener('change', loadUnitData);
});

async function populateUnitSelector() {
    try {
        const response = await fetch(`${API_BASE_URL}/api/units`);
        const units = await response.json();
        const selector = document.getElementById('unitSelector');
        selector.innerHTML = ''; // Clear old options
        units.forEach(unit => {
            const option = document.createElement('option');
            option.value = unit.id;
            option.textContent = unit.name;
            selector.appendChild(option);
        });
    } catch (error) {
        console.error('Không thể tải danh sách đơn vị:', error);
    }
}

async function loadUnitData() {
    const unitId = document.getElementById('unitSelector').value;
    const year = 2025; // Hardcoded for this example
    const month = 4;   // Hardcoded for this example
    
    if (!unitId) return;

    try {
        const response = await fetch(`${API_BASE_URL}/api/kpi_data/${unitId}/${year}/${month}`);
        const data = await response.json();
        
        document.getElementById('reportContent').classList.remove('d-none');
        updateKpiTable(data);
        updateKpiChart(data);
    } catch (error) {
        console.error(`Không thể tải dữ liệu cho đơn vị ${unitId}:`, error);
    }
}

function updateKpiTable(kpis) {
    const tableBody = document.getElementById('kpiDetailTable');
    tableBody.innerHTML = '';

    if (kpis.length === 0) {
        tableBody.innerHTML = '<tr><td colspan="5" class="text-center text-muted">Không có dữ liệu.</td></tr>';
        return;
    }

    kpis.forEach(kpi => {
        const rate = kpi.achievement_rate.toFixed(2);
        const color = rate >= 100 ? 'text-success' : (rate >= 80 ? 'text-warning' : 'text-danger');
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${kpi.perspective}</td>
            <td>${kpi.kpi_name}</td>
            <td>${kpi.monthly_target?.toLocaleString() || 'N/A'}</td>
            <td>${kpi.actual_value?.toLocaleString() || 'N/A'}</td>
            <td class="fw-bold ${color}">${rate}%</td>
        `;
        tableBody.appendChild(row);
    });
}

function updateKpiChart(kpis) {
    const ctx = document.getElementById('kpiDetailChart').getContext('2d');
    
    if (kpiDetailChart) {
        kpiDetailChart.destroy();
    }
    
    kpiDetailChart = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: kpis.map(kpi => kpi.kpi_name),
            datasets: [{
                label: 'Tỷ lệ Hoàn thành (%)',
                data: kpis.map(kpi => kpi.achievement_rate.toFixed(2)),
                backgroundColor: kpis.map(kpi => {
                    const rate = kpi.achievement_rate;
                    return rate >= 100 ? 'rgba(25, 135, 84, 0.7)' : (rate >= 80 ? 'rgba(255, 193, 7, 0.7)' : 'rgba(220, 53, 69, 0.7)');
                })
            }]
        },
        options: {
            responsive: true,
            plugins: {
                legend: { display: false }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    title: {
                        display: true,
                        text: 'Tỷ lệ Hoàn thành (%)'
                    }
                }
            }
        }
    });
}