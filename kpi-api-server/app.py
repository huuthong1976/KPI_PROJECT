# app.py
import sqlite3
from flask import Flask, jsonify, request
from flask_cors import CORS

app = Flask(__name__)
CORS(app) 

DB_NAME = 'kpi_app.db'

# --- Mô phỏng hệ thống người dùng và vai trò ---
# TRONG THỰC TẾ: Dữ liệu này phải được lưu trong CSDL và mật khẩu phải được băm an toàn.
SIMULATED_USERS = {
    "admin": {"password": "admin", "role": "admin"},
    "manager_tdn": {"password": "123", "role": "manager", "unit_id": 1} 
}

# --- Các hàm tiện ích ---
def query_db(query, args=(), one=False):
    try:
        con = sqlite3.connect(DB_NAME)
        con.row_factory = sqlite3.Row
        cur = con.cursor()
        cur.execute(query, args)
        rv = cur.fetchall()
        con.close()
        return (rv[0] if rv else None) if one else rv
    except sqlite3.Error as e:
        print(f"Lỗi CSDL: {e}")
        return None

def execute_db(query, args=()):
    try:
        con = sqlite3.connect(DB_NAME)
        cur = con.cursor()
        cur.execute(query, args)
        con.commit()
        con.close()
        return True
    except sqlite3.Error as e:
        print(f"Lỗi CSDL khi thực thi: {e}")
        return False

# --- API cho việc Đăng nhập (Authentication) ---
@app.route('/api/login', methods=['POST'])
def login():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')

    user = SIMULATED_USERS.get(username)
    if user and user['password'] == password:
        # TRONG THỰC TẾ: Tạo và trả về một JSON Web Token (JWT) an toàn.
        # Ở đây, chúng ta mô phỏng một token đơn giản.
        mock_token = f"token_for_{username}"
        return jsonify({
            "success": True, 
            "token": mock_token, 
            "user": {
                "username": username,
                "role": user['role'],
                "unit_id": user.get('unit_id')
            }
        })
    return jsonify({"success": False, "message": "Tên đăng nhập hoặc mật khẩu không đúng."}), 401

# --- API cho việc Nhập liệu (Data Entry) ---
@app.route('/api/actuals', methods=['POST'])
def upsert_actuals():
    # TRONG THỰC TẾ: Cần xác thực token từ header request.
    # if not is_token_valid(request.headers.get('Authorization')):
    #     return jsonify({"message": "Unauthorized"}), 401

    data = request.get_json() # Dữ liệu là một danh sách các bản ghi
    
    for record in data:
        # Dùng UPSERT (INSERT OR UPDATE) để nhập liệu
        query = """
            INSERT INTO actuals (kpi_id, unit_id, year, month, actual_value)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(kpi_id, unit_id, year, month) 
            DO UPDATE SET actual_value = excluded.actual_value;
        """
        execute_db(query, (
            record['kpi_id'],
            record['unit_id'],
            record['year'],
            record['month'],
            record['actual_value']
        ))
        
    return jsonify({"success": True, "message": "Dữ liệu đã được lưu thành công!"})


# --- Các API hiện có (giữ nguyên) ---
@app.route('/api/kpis_by_unit/<int:unit_id>', methods=['GET'])
def get_kpis_for_entry(unit_id):
    query = """
        SELECT k.id, k.name, k.unit_of_measure 
        FROM kpis k
        JOIN targets t ON k.id = t.kpi_id
        WHERE t.unit_id = ?
        GROUP BY k.id, k.name
        ORDER BY k.perspective_id, k.name;
    """
    kpis = query_db(query, (unit_id,))
    return jsonify([dict(row) for row in kpis] if kpis else [])

# (Các API get_dashboard_data, get_units, get_kpi_data từ phiên bản trước vẫn giữ nguyên ở đây...)
# ... (dán code các API còn lại vào đây) ...

# -----------------------------------------------
# Đoạn code dưới đây copy từ phiên bản trước
# -----------------------------------------------
@app.route('/')
def index():
    return "Chào mừng đến với API Quản lý KPI phiên bản cuối cùng!"
# 1. API cho màn hình Dashboard
@app.route('/api/dashboard/<int:year>/<int:month>', methods=['GET'])
def get_dashboard_data(year, month):
    perspectives_query = "..." # Giữ nguyên
    units_query = "..." # Giữ nguyên
    perspectives_data = query_db(perspectives_query, (year, month))
    units_data = query_db(units_query, (year, month))
    return jsonify({"perspective_summary": [dict(p) for p in perspectives_data], "unit_summary": [dict(u) for u in units_data]})

# 2. API để lấy danh sách đơn vị
@app.route('/api/units', methods=['GET'])
def get_units():
    units = query_db("SELECT * FROM units ORDER BY name")
    return jsonify([dict(row) for row in units] if units else [])

# 3. API để lấy dữ liệu chi tiết của 1 đơn vị
@app.route('/api/kpi_data/<int:unit_id>/<int:year>/<int:month>', methods=['GET'])
def get_kpi_data(unit_id, year, month):
    query = "..." # Giữ nguyên
    data = query_db(query, (unit_id, year, unit_id, year, month))
    return jsonify([dict(row) for row in data] if data else [])
# -----------------------------------------------
# --- API CRUD cho Quản lý Mục tiêu (Targets) ---

# GET: Lấy danh sách mục tiêu theo bộ lọc
@app.route('/api/targets', methods=['GET'])
def get_targets():
    unit_id = request.args.get('unit_id')
    year = request.args.get('year')
    if not unit_id or not year:
        return jsonify({"message": "Thiếu unit_id hoặc year"}), 400

    query = """
        SELECT t.id, t.kpi_id, k.name as kpi_name, t.monthly_target, t.annual_target, t.weight
        FROM targets t
        JOIN kpis k ON t.kpi_id = k.id
        WHERE t.unit_id = ? AND t.year = ?
        ORDER BY k.name;
    """
    targets = query_db(query, (unit_id, year))
    return jsonify([dict(row) for row in targets] if targets else [])

# POST: Tạo một mục tiêu mới
@app.route('/api/targets', methods=['POST'])
def create_target():
    data = request.get_json()
    query = """
        INSERT INTO targets (kpi_id, unit_id, year, monthly_target, annual_target, weight)
        VALUES (?, ?, ?, ?, ?, ?);
    """
    success = execute_db(query, (
        data['kpi_id'], data['unit_id'], data['year'], 
        data.get('monthly_target'), data.get('annual_target'), data.get('weight')
    ))
    return jsonify({"success": success})

# PUT: Cập nhật một mục tiêu đã có
@app.route('/api/targets/<int:target_id>', methods=['PUT'])
def update_target(target_id):
    data = request.get_json()
    query = """
        UPDATE targets SET 
            kpi_id = ?, monthly_target = ?, annual_target = ?, weight = ?
        WHERE id = ?;
    """
    success = execute_db(query, (
        data['kpi_id'], data.get('monthly_target'), data.get('annual_target'), 
        data.get('weight'), target_id
    ))
    return jsonify({"success": success})

# DELETE: Xóa một mục tiêu
@app.route('/api/targets/<int:target_id>', methods=['DELETE'])
def delete_target(target_id):
    query = "DELETE FROM targets WHERE id = ?;"
    success = execute_db(query, (target_id,))
    return jsonify({"success": success})

# Thêm API để lấy danh sách KPI (dùng cho form nhập liệu)
@app.route('/api/kpis', methods=['GET'])
def get_all_kpis():
    kpis = query_db("SELECT id, name FROM kpis ORDER BY name;")
    return jsonify([dict(row) for row in kpis] if kpis else [])
# app.py (thêm vào cuối file, trước if __name__ == '__main__':)

# --- API CRUD cho Quản lý Đơn vị (Units) ---

# POST: Tạo một đơn vị mới
@app.route('/api/units', methods=['POST'])
def create_unit():
    data = request.get_json()
    if not data or not data.get('name'):
        return jsonify({"success": False, "message": "Tên đơn vị là bắt buộc"}), 400
    
    query = "INSERT INTO units (name) VALUES (?);"
    success = execute_db(query, (data['name'],))
    return jsonify({"success": success})

# PUT: Cập nhật một đơn vị đã có
@app.route('/api/units/<int:unit_id>', methods=['PUT'])
def update_unit(unit_id):
    data = request.get_json()
    if not data or not data.get('name'):
        return jsonify({"success": False, "message": "Tên đơn vị là bắt buộc"}), 400

    query = "UPDATE units SET name = ? WHERE id = ?;"
    success = execute_db(query, (data['name'], unit_id))
    return jsonify({"success": success})

# DELETE: Xóa một đơn vị
@app.route('/api/units/<int:unit_id>', methods=['DELETE'])
def delete_unit(unit_id):
    # Quan trọng: Kiểm tra ràng buộc dữ liệu trước khi xóa
    # Không cho phép xóa nếu đơn vị này đã có mục tiêu hoặc kết quả thực tế
    targets_exist = query_db("SELECT 1 FROM targets WHERE unit_id = ? LIMIT 1", (unit_id,), one=True)
    if targets_exist:
        return jsonify({"success": False, "message": "Không thể xóa đơn vị đã có dữ liệu KPI."}), 409 # 409 Conflict
    
    query = "DELETE FROM units WHERE id = ?;"
    success = execute_db(query, (unit_id,))
    return jsonify({"success": success})

# Lưu ý: Endpoint GET /api/units đã tồn tại và có thể được tái sử dụng để đọc danh sách đơn vị.
# app.py (thêm vào)

# --- API CRUD cho việc Giao KPI Cá nhân (Assignments) ---

@app.route('/api/assignments', methods=['GET'])
def get_assignments():
    user_id = request.args.get('user_id')
    year = request.args.get('year')
    month = request.args.get('month')
    if not all([user_id, year, month]):
        return jsonify({"message": "Thiếu thông tin user_id, year, hoặc month"}), 400
    
    query = "SELECT * FROM individual_kpi_assignments WHERE user_id = ? AND year = ? AND month = ? ORDER BY id;"
    assignments = query_db(query, (user_id, year, month))
    return jsonify([dict(row) for row in assignments] if assignments else [])

@app.route('/api/assignments', methods=['POST'])
def create_assignment():
    data = request.get_json()
    query = """
        INSERT INTO individual_kpi_assignments 
        (user_id, year, month, kpi_description, target_description, weight)
        VALUES (?, ?, ?, ?, ?, ?);
    """
    success = execute_db(query, (
        data['user_id'], data['year'], data['month'],
        data['kpi_description'], data['target_description'], data['weight']
    ))
    # Đồng thời tạo một bản ghi đánh giá đang chờ xử lý
    if success:
        assignment_id = query_db("SELECT last_insert_rowid() as id", one=True)['id']
        execute_db("INSERT INTO monthly_assessments (assignment_id, status) VALUES (?, 'pending')", (assignment_id,))

    return jsonify({"success": success})

@app.route('/api/assignments/<int:assignment_id>', methods=['PUT'])
def update_assignment(assignment_id):
    data = request.get_json()
    query = """
        UPDATE individual_kpi_assignments SET
        kpi_description = ?, target_description = ?, weight = ?
        WHERE id = ?;
    """
    success = execute_db(query, (
        data['kpi_description'], data['target_description'], data['weight'], assignment_id
    ))
    return jsonify({"success": success})

@app.route('/api/assignments/<int:assignment_id>', methods=['DELETE'])
def delete_assignment(assignment_id):
    # Khi xóa assignment, cũng nên xóa bản ghi assessment liên quan
    execute_db("DELETE FROM monthly_assessments WHERE assignment_id = ?;", (assignment_id,))
    success = execute_db("DELETE FROM individual_kpi_assignments WHERE id = ?;", (assignment_id,))
    return jsonify({"success": success})

# --- API cho việc Nhân viên Tự đánh giá ---

# Lấy thông tin đánh giá (bao gồm cả KPI được giao)
@app.route('/api/my-assessments', methods=['GET'])
def get_my_assessments():
    user_id = request.args.get('user_id')
    year = request.args.get('year')
    month = request.args.get('month')
    query = """
        SELECT a.id, a.kpi_description, a.target_description, a.weight,
               m.id as assessment_id, m.employee_comment, m.employee_score, m.status
        FROM individual_kpi_assignments a
        JOIN monthly_assessments m ON a.id = m.assignment_id
        WHERE a.user_id = ? AND a.year = ? AND a.month = ?;
    """
    assessments = query_db(query, (user_id, year, month))
    return jsonify([dict(row) for row in assessments] if assessments else [])

# Endpoint để nhân viên nộp bản tự đánh giá
@app.route('/api/assessments/self', methods=['POST'])
def submit_self_assessment():
    # payload là một danh sách các đánh giá
    assessments_data = request.get_json()
    
    for item in assessments_data:
        query = """
            UPDATE monthly_assessments SET
            employee_comment = ?, employee_score = ?, status = 'employee_assessed'
            WHERE id = ? AND status = 'pending'; 
        """
        # Thêm điều kiện status = 'pending' để đảm bảo không ghi đè đánh giá đã hoàn thành
        execute_db(query, (item['employee_comment'], item['employee_score'], item['assessment_id']))
        
    return jsonify({"success": True, "message": "Nộp bản tự đánh giá thành công!"})

# app.py (thêm vào)

# --- API cho việc Quản lý Đánh giá (Manager Assessment) ---

# API để lấy danh sách nhân viên thuộc quyền quản lý của một manager
@app.route('/api/my-team', methods=['GET'])
def get_my_team():
    manager_id = request.args.get('manager_id')
    if not manager_id:
        return jsonify({"message": "Thiếu manager_id"}), 400
    
    # Lấy tất cả user có manager_id trỏ đến người quản lý hiện tại
    query = "SELECT id, full_name FROM users WHERE manager_id = ? ORDER BY full_name;"
    team_members = query_db(query, (manager_id,))
    return jsonify([dict(row) for row in team_members] if team_members else [])

# API để quản lý nộp bản đánh giá của mình cho nhân viên
@app.route('/api/assessments/manager', methods=['POST'])
def submit_manager_assessment():
    assessments_data = request.get_json() # payload là danh sách đánh giá
    
    for item in assessments_data:
        # Chỉ cập nhật những bản ghi đã được nhân viên đánh giá
        query = """
            UPDATE monthly_assessments SET
            manager_comment = ?, manager_score = ?, status = 'manager_assessed'
            WHERE id = ? AND status = 'employee_assessed'; 
        """
        execute_db(query, (
            item['manager_comment'], 
            item['manager_score'], 
            item['assessment_id']
        ))
        
    return jsonify({"success": True, "message": "Nộp đánh giá của quản lý thành công!"})
# app.py (thêm vào)

# --- API cho việc Đánh giá của Tổng Giám đốc ---

@app.route('/api/assessments/director', methods=['POST'])
def submit_director_assessment():
    assessments_data = request.get_json()
    
    for item in assessments_data:
        # Giả định điểm của TGĐ là điểm cuối cùng
        # Cập nhật cả director_score và final_score, đổi status thành 'completed'
        query = """
            UPDATE monthly_assessments SET
            director_score = ?, final_score = ?, status = 'completed'
            WHERE id = ? AND status = 'manager_assessed'; 
        """
        execute_db(query, (
            item['director_score'], 
            item['director_score'], # Gán điểm TGĐ làm điểm cuối cùng
            item['assessment_id']
        ))
        
    return jsonify({"success": True, "message": "Nộp đánh giá của TGĐ thành công!"})

# --- API cho Cỗ máy Tính lương và Phiếu lương ---

@app.route('/api/salary/calculate', methods=['POST'])
def calculate_salaries():
    data = request.get_json()
    year = data.get('year')
    month = data.get('month')
    # TRONG THỰC TẾ: Cần có cơ chế định nghĩa Quỹ lương P3 cho từng đơn vị/công ty.
    # Ở đây, chúng ta mô phỏng một quỹ lương P3 cố định cho đơn vị TDN (unit_id = 1)
    P3_FUND_FOR_UNIT_1 = 10000000 # Giả định quỹ lương P3 là 10 triệu

    # B1: Tính tỷ lệ hoàn thành KPI chung của đơn vị (unit_id = 1)
    unit_kpi_query = """
        SELECT AVG((a.actual_value / t.monthly_target) * 100) as achievement
        FROM actuals a
        JOIN targets t ON a.kpi_id = t.kpi_id AND a.unit_id = t.unit_id AND a.year = t.year
        WHERE a.unit_id = 1 AND a.year = ? AND a.month = ? AND t.monthly_target > 0;
    """
    unit_kpi_result = query_db(unit_kpi_query, (year, month), one=True)
    unit_achievement_rate = unit_kpi_result['achievement'] if unit_kpi_result and unit_kpi_result['achievement'] else 0

    # B2: Lấy tất cả nhân viên của đơn vị
    users = query_db("SELECT id, base_salary_p1, competency_salary_p2 FROM users WHERE unit_id = 1;")

    # B3: Tính tổng điểm hiệu suất cá nhân có trọng số của cả đơn vị
    total_performance_points = 0
    user_assessments = {}
    for user in users:
        assessments = query_db("""
            SELECT final_score, weight 
            FROM monthly_assessments m
            JOIN individual_kpi_assignments a ON m.assignment_id = a.id
            WHERE a.user_id = ? AND a.year = ? AND a.month = ? AND m.status = 'completed';
        """, (user['id'], year, month))
        
        # Tính điểm KPI cá nhân cuối cùng (trung bình có trọng số)
        user_final_score = sum([(a['final_score'] * (a['weight'] / 100.0)) for a in assessments]) if assessments else 0
        user_assessments[user['id']] = {'score': user_final_score, 'assessments': assessments}
        total_performance_points += user_final_score

    # B4: Tính lương P3 và tạo phiếu lương cho từng nhân viên
    for user in users:
        p1 = user['base_salary_p1']
        p2 = user['competency_salary_p2']
        user_score = user_assessments[user['id']]['score']
        
        # Công thức phân bổ lương P3
        # Lương P3 = (Quỹ lương P3 thực tế của đơn vị) * (Tỷ trọng điểm của cá nhân)
        p3_fund_actual = P3_FUND_FOR_UNIT_1 * (unit_achievement_rate / 100.0)
        user_point_share = (user_score / total_performance_points) if total_performance_points > 0 else 0
        p3 = p3_fund_actual * user_point_share
        
        final_salary = p1 + p2 + p3

        # Lưu vào bảng pay_slips (dùng UPSERT)
        payslip_query = """
            INSERT INTO pay_slips (user_id, year, month, unit_kpi_percentage, individual_kpi_score,
                                   base_salary_p1, competency_salary_p2, performance_salary_p3, final_salary)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(user_id, year, month)
            DO UPDATE SET unit_kpi_percentage=excluded.unit_kpi_percentage, individual_kpi_score=excluded.individual_kpi_score,
                          base_salary_p1=excluded.base_salary_p1, competency_salary_p2=excluded.competency_salary_p2,
                          performance_salary_p3=excluded.performance_salary_p3, final_salary=excluded.final_salary;
        """
        execute_db(payslip_query, (user['id'], year, month, unit_achievement_rate, user_score, p1, p2, p3, final_salary))

    return jsonify({"success": True, "message": f"Đã tính và lưu bảng lương cho {len(users)} nhân viên."})

# API để nhân viên xem phiếu lương
@app.route('/api/payslip', methods=['GET'])
def get_payslip():
    user_id = request.args.get('user_id')
    year = request.args.get('year')
    month = request.args.get('month')
    query = "SELECT u.full_name, p.* FROM pay_slips p JOIN users u ON p.user_id = u.id WHERE p.user_id = ? AND p.year = ? AND p.month = ?;"
    payslip = query_db(query, (user_id, year, month), one=True)
    return jsonify(dict(payslip) if payslip else None)
# app.py (thêm vào)

# --- API CRUD cho Quản lý Phụ cấp & Khấu trừ (Payroll Items) ---

# GET: Lấy danh sách các khoản thưởng/trừ đã nhập cho một nhân viên trong kỳ
@app.route('/api/payroll-items', methods=['GET'])
def get_payroll_items():
    user_id = request.args.get('user_id')
    year = request.args.get('year')
    month = request.args.get('month')
    if not all([user_id, year, month]):
        return jsonify({"message": "Thiếu thông tin user_id, year, hoặc month"}), 400
    
    # Chỉ lấy các khoản do người dùng nhập, không lấy các khoản hệ thống tự tính
    query = """
        SELECT id, item_description, item_type, amount 
        FROM payroll_items 
        WHERE user_id = ? AND year = ? AND month = ? 
        AND item_type IN ('allowance', 'deduction_other');
    """
    items = query_db(query, (user_id, year, month))
    return jsonify([dict(row) for row in items] if items else [])

# POST: Tạo một khoản mục mới
@app.route('/api/payroll-items', methods=['POST'])
def create_payroll_item():
    data = request.get_json()
    query = """
        INSERT INTO payroll_items 
        (user_id, year, month, item_description, item_type, amount)
        VALUES (?, ?, ?, ?, ?, ?);
    """
    success = execute_db(query, (
        data['user_id'], data['year'], data['month'],
        data['item_description'], data['item_type'], data['amount']
    ))
    return jsonify({"success": success})

# PUT: Cập nhật một khoản mục
@app.route('/api/payroll-items/<int:item_id>', methods=['PUT'])
def update_payroll_item(item_id):
    data = request.get_json()
    query = "UPDATE payroll_items SET item_description = ?, amount = ? WHERE id = ?;"
    success = execute_db(query, (data['item_description'], data['amount'], item_id))
    return jsonify({"success": success})

# DELETE: Xóa một khoản mục
@app.route('/api/payroll-items/<int:item_id>', methods=['DELETE'])
def delete_payroll_item(item_id):
    query = "DELETE FROM payroll_items WHERE id = ?;"
    success = execute_db(query, (item_id,))
    return jsonify({"success": success})

if __name__ == '__main__':
    app.run(debug=True, port=5001)