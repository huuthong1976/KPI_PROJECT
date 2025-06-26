// app.js

// Hàm này sẽ được gọi khi trang web được tải xong
document.addEventListener('DOMContentLoaded', function() {
    // Gọi API để lấy dữ liệu
    fetch('http://127.0.0.1:5000/api/kpi_data/1/2025/4')
        .then(response => response.json())
        .then(data => {
            // Khi nhận được dữ liệu, gọi các hàm để hiển thị
            populateTable(data);
            createChart(data);
        })
        .catch(error => console.error('Lỗi khi gọi API:', error));
});

function populateTable(data) {
    const tableBody = document.querySelector("#kpiTable tbody");
    // Xóa dữ liệu cũ (nếu có)
    tableBody.innerHTML = '';

    // Lặp qua từng dòng dữ liệu và tạo hàng trong bảng
    data.forEach(kpi => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${kpi.perspective}</td>
            <td>${kpi.kpi_name}</td>
            <td>${kpi.monthly_target !== null ? kpi.monthly_target.toLocaleString() : 'N/A'}</td>
            <td>${kpi.actual_value !== null ? kpi.actual_value.toLocaleString() : 'N/A'}</td>
            <td>${kpi.unit_of_measure}</td>
        `;
        tableBody.appendChild(row);
    });
}

function createChart(data) {
    const ctx = document.getElementById('kpiChart').getContext('2d');
    
    // Chuẩn bị dữ liệu cho biểu đồ
    const labels = data.map(kpi => kpi.kpi_name);
    const targetData = data.map(kpi => kpi.monthly_target);
    const actualData = data.map(kpi => kpi.actual_value);

    new Chart(ctx, {
        type: 'bar', // Loại biểu đồ là biểu đồ cột
        data: {
            labels: labels,
            datasets: [
                {
                    label: 'Mục tiêu',
                    data: targetData,
                    backgroundColor: 'rgba(54, 162, 235, 0.6)',
                    borderColor: 'rgba(54, 162, 235, 1)',
                    borderWidth: 1
                },
                {
                    label: 'Thực tế',
                    data: actualData,
                    backgroundColor: 'rgba(75, 192, 192, 0.6)',
                    borderColor: 'rgba(75, 192, 192, 1)',
                    borderWidth: 1
                }
            ]
        },
        options: {
            scales: {
                y: {
                    beginAtZero: true
                }
            },
            plugins: {
                title: {
                    display: true,
                    text: 'Biểu đồ so sánh Mục tiêu và Thực tế'
                }
            }
        }
    });
}