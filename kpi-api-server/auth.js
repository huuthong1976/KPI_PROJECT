// auth.js
const API_BASE_URL = 'http://127.0.0.1:5001';

// --- Phần xử lý trang đăng nhập ---
const loginForm = document.getElementById('loginForm');
if (loginForm) {
    loginForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const username = document.getElementById('username').value;
        const password = document.getElementById('password').value;
        const errorMessage = document.getElementById('errorMessage');

        try {
            const response = await fetch(`${API_BASE_URL}/api/login`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ username, password })
            });

            const data = await response.json();
            if (data.success) {
                // Lưu thông tin người dùng vào localStorage
                localStorage.setItem('kpi_token', data.token);
                localStorage.setItem('kpi_user', JSON.stringify(data.user));
                // Chuyển hướng đến trang dashboard
                window.location.href = '/dashboard.html';
            } else {
                errorMessage.textContent = data.message;
                errorMessage.classList.remove('d-none');
            }
        } catch (error) {
            errorMessage.textContent = 'Lỗi kết nối đến máy chủ.';
            errorMessage.classList.remove('d-none');
        }
    });
}

// --- Phần xử lý chung cho các trang được bảo vệ ---
function checkAuth() {
    const user = getUser();
    if (!user) {
        window.location.href = '/login.html';
    }
    return user;
}

function getUser() {
    const user = localStorage.getItem('kpi_user');
    return user ? JSON.parse(user) : null;
}

function logout() {
    localStorage.removeItem('kpi_token');
    localStorage.removeItem('kpi_user');
    window.location.href = '/login.html';
}