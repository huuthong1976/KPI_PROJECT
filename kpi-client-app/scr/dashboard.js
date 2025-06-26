// dashboard.js
const API_BASE_URL = 'http://127.0.0.1:5001';
let unitChart;
checkAuth()
document.addEventListener('DOMContentLoaded', () => {
    loadDashboardData();
    
    document.getElementById('yearFilter').addEventListener('change', loadDashboardData);
    document.getElementById('monthFilter').addEventListener('change', loadDashboardData);
});

async function loadDashboardData() {
    const year = document.getElementById('yearFilter').value;
    const month = document.getElementById('monthFilter').value;
    
    try {
        const response = await fetch(`${API_BASE_URL}/api/dashboard/${year}/${month}`);
        if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
        const data = await response.json();
        
        updatePerspectiveCards(data.perspective_summary);
        updateUnitChart(data.unit_summary);
    } catch (error) {
        console.error('Không thể tải dữ liệu dashboard:', error);
        document.getElementById('perspectiveSummary').innerHTML = `<p class="text-danger">Lỗi tải dữ liệu.</p>`;
    }
}

function updatePerspectiveCards(perspectives) {
    const container = document.getElementById('perspectiveSummary');
    container.innerHTML = ''; // Clear old data
    
    if (perspectives.length === 0) {
        container.innerHTML = `<p class="text-muted">Không có dữ liệu tổng hợp cho thời gian này.</p>`;
        return;
    }

    perspectives.forEach(p => {
        const rate = p.achievement_rate.toFixed(2);
        const color = rate >= 100 ? 'success' : (rate >= 80 ? 'warning' : 'danger');
        const cardHtml = `
            <div class="col-md-3">
                <div class="card text-center text-white bg-${color}">
                    <div class="card-header">${p.perspective_name}</div>
                    <div class="card-body">
                        <p class="achievement-rate">${rate}%</p>
                    </div>
                </div>
            </div>`;
        container.innerHTML += cardHtml;
    });
}

function updateUnitChart(units) {
    const ctx = document.getElementById('unitChart').getContext('2d');
    
    if (unitChart) {
        unitChart.destroy(); // Destroy old chart before creating a new one
    }
    
    unitChart = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: units.map(u => u.unit_name),
            datasets: [{
                label: 'Tỷ lệ Hoàn thành (%)',
                data: units.map(u => u.achievement_rate.toFixed(2)),
                backgroundColor: 'rgba(0, 123, 255, 0.7)',
                borderColor: 'rgba(0, 123, 255, 1)',
                borderWidth: 1
            }]
        },
        options: {
            indexAxis: 'y', // Make it a horizontal bar chart
            responsive: true,
            plugins: {
                legend: { display: false },
                tooltip: {
                    callbacks: {
                        label: function(context) {
                            return `${context.dataset.label}: ${context.raw}%`;
                        }
                    }
                }
            },
            scales: {
                x: {
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