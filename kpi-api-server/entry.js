// entry.js
document.addEventListener('DOMContentLoaded', () => {
    const user = checkAuth(); // Kiểm tra đăng nhập trước
    populateUnitSelector(user);

    // Thêm sự kiện để tải lại danh sách KPI khi thay đổi lựa chọn
    document.getElementById('unitSelector').addEventListener('change', loadKpisForEntry);
    document.getElementById('monthSelector').addEventListener('change', loadKpisForEntry);
    document.getElementById('yearSelector').addEventListener('change', loadKpisForEntry);
    
    document.getElementById('entryForm').addEventListener('submit', saveActualData);
});

async function populateUnitSelector(user) {
    const selector = document.getElementById('unitSelector');
    if (user.role === 'admin') {
        // Admin thấy tất cả các đơn vị
        const response = await fetch(`${API_BASE_URL}/api/units`);
        const units = await response.json();
        units.forEach(unit => selector.add(new Option(unit.name, unit.id)));
    } else if (user.role === 'manager') {
        // Manager chỉ thấy đơn vị của mình
        const response = await fetch(`${API_BASE_URL}/api/units`);
        const units = await response.json();
        const userUnit = units.find(u => u.id === user.unit_id);
        if(userUnit) selector.add(new Option(userUnit.name, userUnit.id));
        selector.disabled = true; // Không cho thay đổi
    }
    loadKpisForEntry(); // Tải KPI cho lựa chọn mặc định
}

async function loadKpisForEntry() {
    const unitId = document.getElementById('unitSelector').value;
    const tableBody = document.getElementById('kpiEntryTable');
    if (!unitId) {
        tableBody.innerHTML = '<tr><td colspan="3">Vui lòng chọn một đơn vị.</td></tr>';
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE_URL}/api/kpis_by_unit/${unitId}`);
        const kpis = await response.json();
        
        tableBody.innerHTML = ''; // Xóa dữ liệu cũ
        kpis.forEach(kpi => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>${kpi.name}</td>
                <td>${kpi.unit_of_measure}</td>
                <td>
                    <input type="number" step="any" class="form-control" data-kpi-id="${kpi.id}" />
                </td>
            `;
            tableBody.appendChild(row);
        });
    } catch (error) {
        console.error('Lỗi khi tải danh sách KPI:', error);
    }
}

async function saveActualData(e) {
    e.preventDefault();
    const unitId = document.getElementById('unitSelector').value;
    const year = document.getElementById('yearSelector').value;
    const month = document.getElementById('monthSelector').value;
    
    const inputs = document.querySelectorAll('#kpiEntryTable input');
    const payload = [];
    
    inputs.forEach(input => {
        if (input.value !== '') {
            payload.push({
                kpi_id: parseInt(input.dataset.kpiId),
                unit_id: parseInt(unitId),
                year: parseInt(year),
                month: parseInt(month),
                actual_value: parseFloat(input.value)
            });
        }
    });

    if (payload.length === 0) {
        showAlert('Không có dữ liệu nào để lưu.', 'warning');
        return;
    }

    try {
        const response = await fetch(`${API_BASE_URL}/api/actuals`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        const result = await response.json();
        if (result.success) {
            showAlert('Lưu dữ liệu thành công!', 'success');
        } else {
            throw new Error(result.message);
        }
    } catch (error) {
        showAlert(`Lỗi khi lưu dữ liệu: ${error.message}`, 'danger');
    }
}

function showAlert(message, type) {
    const alertBox = document.getElementById('alertMessage');
    alertBox.className = `alert alert-${type}`;
    alertBox.textContent = message;
    alertBox.classList.remove('d-none');
    setTimeout(() => alertBox.classList.add('d-none'), 3000);
}