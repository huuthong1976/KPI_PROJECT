# GỢI Ý CẤU TRÚC THƯ MỤC DỰ ÁN (sau khi bạn tách code ra):
# kpi_web_app_mysql/
# ├── app.py
# ├── models.py
# ├── db_operations.py
# ... (các file khác như trước)
# └── kpi_bsc_app_mysql_db (Tên database trong MySQL server của bạn)

# --- BẮT ĐẦU MÃ NGUỒN ---

import sqlite3 # Sẽ được thay thế bởi mysql.connector
import mysql.connector # THƯ VIỆN MỚI
from mysql.connector import errorcode # Để bắt lỗi MySQL cụ thể

import os
from dataclasses import dataclass, field
from typing import Optional, List, Dict, Any, Set
from datetime import datetime, date
import csv
from werkzeug.security import generate_password_hash, check_password_hash
from flask import (
    Flask, render_template, request, redirect, url_for, session, flash, abort, send_from_directory, g
)
from functools import wraps

# --- CẤU HÌNH ỨNG DỤNG ---
# DATABASE_NAME = 'kpi_bsc_app.db' # Không dùng nữa
UPLOAD_FOLDER = 'data_uploads'
ALLOWED_EXTENSIONS = {'csv'}

app = Flask(__name__)
app.config['SECRET_KEY'] = 'your_very_secret_key_for_sessions_v2_mysql' # THAY ĐỔI
# Cấu hình MySQL
app.config['MYSQL_HOST'] = os.environ.get('MYSQL_HOST', 'localhost')
app.config['MYSQL_USER'] = os.environ.get('MYSQL_USER', 'your_mysql_user') # THAY BẰNG USER MYSQL CỦA BẠN
app.config['MYSQL_PASSWORD'] = os.environ.get('MYSQL_PASSWORD', 'your_mysql_password') # THAY BẰNG PASSWORD MYSQL CỦA BẠN
app.config['MYSQL_DB'] = os.environ.get('MYSQL_DB', 'kpi_bsc_app_mysql_db') # TÊN DATABASE MYSQL CỦA BẠN
app.config['MYSQL_CURSORCLASS'] = 'DictCursor' # Để trả về kết quả dạng dictionary

if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

# --- PHẦN 1: DATABASE SETUP (Cập nhật cho MySQL) ---
def create_connection_app_mysql(): # Đổi tên hàm
    try:
        conn = mysql.connector.connect(
            host=app.config['MYSQL_HOST'],
            user=app.config['MYSQL_USER'],
            password=app.config['MYSQL_PASSWORD'],
            database=app.config['MYSQL_DB']
        )
        print(f"--- Đã kết nối tới MySQL DB: {app.config['MYSQL_DB']} ---")
        return conn
    except mysql.connector.Error as err:
        if err.errno == errorcode.ER_ACCESS_DENIED_ERROR:
            print("Lỗi: Sai tên người dùng hoặc mật khẩu MySQL.")
        elif err.errno == errorcode.ER_BAD_DB_ERROR:
            print(f"Lỗi: Database '{app.config['MYSQL_DB']}' không tồn tại.")
        else:
            print(f"Lỗi kết nối MySQL: {err}")
        return None

# enable_foreign_keys_app_v2 không cần thiết cho MySQL vì nó thường được bật mặc định
# hoặc được định nghĩa trong câu lệnh CREATE TABLE.
# MySQL sẽ tự động kiểm tra khóa ngoại nếu chúng được định nghĩa đúng.

def init_db_app_mysql(): # Đổi tên hàm
    conn = create_connection_app_mysql()
    if conn:
        cursor = conn.cursor()
        try:
            # Tạo các bảng với cú pháp MySQL
            # Bảng Organizations
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS Organizations (
                Organization_ID INT AUTO_INCREMENT PRIMARY KEY,
                Organization_Name VARCHAR(255) NOT NULL UNIQUE,
                Address TEXT,
                Contact_Person VARCHAR(255),
                Contact_Email VARCHAR(255) UNIQUE,
                Contact_Phone VARCHAR(20),
                Is_Active BOOLEAN DEFAULT TRUE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)

            # Bảng Employees
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS Employees (
                Employee_ID VARCHAR(20) PRIMARY KEY,
                FullName VARCHAR(255) NOT NULL,
                Position_ID INT,
                Organization_ID INT,
                Email VARCHAR(255) UNIQUE,
                PhoneNumber VARCHAR(20),
                StartDate DATE,
                Status VARCHAR(50) DEFAULT 'Active',
                FOREIGN KEY (Position_ID) REFERENCES Positions(Position_ID) ON DELETE SET NULL,
                FOREIGN KEY (Organization_ID) REFERENCES Organizations(Organization_ID) ON DELETE SET NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)
            
            # Bảng Positions
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS Positions (
                Position_ID INT AUTO_INCREMENT PRIMARY KEY,
                Position_Name VARCHAR(255) NOT NULL,
                Organization_ID INT NOT NULL,
                Description TEXT,
                FOREIGN KEY (Organization_ID) REFERENCES Organizations(Organization_ID) ON DELETE CASCADE,
                UNIQUE (Organization_ID, Position_Name)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)

            # Bảng Roles
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS Roles (
                Role_ID INT AUTO_INCREMENT PRIMARY KEY,
                Role_Name VARCHAR(100) NOT NULL UNIQUE,
                Description TEXT,
                Is_System_Role BOOLEAN DEFAULT FALSE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)

            # Bảng Permissions
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS Permissions (
                Permission_ID INT AUTO_INCREMENT PRIMARY KEY,
                Permission_Key VARCHAR(100) NOT NULL UNIQUE,
                Description TEXT
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)

            # Bảng Role_Permissions
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS Role_Permissions (
                Role_ID INT NOT NULL,
                Permission_ID INT NOT NULL,
                FOREIGN KEY (Role_ID) REFERENCES Roles(Role_ID) ON DELETE CASCADE,
                FOREIGN KEY (Permission_ID) REFERENCES Permissions(Permission_ID) ON DELETE CASCADE,
                PRIMARY KEY (Role_ID, Permission_ID)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)

            # Bảng Users
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS Users (
                User_ID INT AUTO_INCREMENT PRIMARY KEY,
                Username VARCHAR(100) NOT NULL UNIQUE,
                Password_Hash VARCHAR(255) NOT NULL,
                FullName VARCHAR(255),
                Email VARCHAR(255) NOT NULL UNIQUE,
                Organization_ID INT,
                Employee_ID VARCHAR(20) UNIQUE,
                Is_Active BOOLEAN DEFAULT TRUE,
                Last_Login DATETIME,
                FOREIGN KEY (Organization_ID) REFERENCES Organizations(Organization_ID) ON DELETE SET NULL,
                FOREIGN KEY (Employee_ID) REFERENCES Employees(Employee_ID) ON DELETE SET NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)

            # Bảng User_Roles
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS User_Roles (
                User_ID INT NOT NULL,
                Role_ID INT NOT NULL,
                FOREIGN KEY (User_ID) REFERENCES Users(User_ID) ON DELETE CASCADE,
                FOREIGN KEY (Role_ID) REFERENCES Roles(Role_ID) ON DELETE CASCADE,
                PRIMARY KEY (User_ID, Role_ID)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)

            # Bảng Audit_Logs
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS Audit_Logs (
                Log_ID INT AUTO_INCREMENT PRIMARY KEY,
                User_ID INT,
                Organization_ID INT,
                Timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                Action_Type VARCHAR(50) NOT NULL,
                Table_Name VARCHAR(100),
                Record_ID VARCHAR(255),
                Field_Name VARCHAR(100),
                Old_Value TEXT,
                New_Value TEXT,
                Description TEXT,
                IP_Address VARCHAR(50),
                FOREIGN KEY (User_ID) REFERENCES Users(User_ID) ON DELETE SET NULL,
                FOREIGN KEY (Organization_ID) REFERENCES Organizations(Organization_ID) ON DELETE SET NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)

            # Bảng Application_Settings
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS Application_Settings (
                Setting_ID INT AUTO_INCREMENT PRIMARY KEY,
                Organization_ID INT,
                Setting_Key VARCHAR(100) NOT NULL,
                Setting_Value TEXT,
                Data_Type VARCHAR(20), -- 'STRING', 'NUMBER', 'BOOLEAN', 'JSON'
                Description TEXT,
                Is_Editable_By_Org_Admin BOOLEAN DEFAULT FALSE,
                FOREIGN KEY (Organization_ID) REFERENCES Organizations(Organization_ID) ON DELETE CASCADE,
                UNIQUE (Organization_ID, Setting_Key) -- Nếu Organization_ID là NULL, MySQL không ép UNIQUE tốt, cần logic ứng dụng hoặc trigger
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)
            # Để xử lý UNIQUE cho global settings (Organization_ID IS NULL) trong MySQL,
            # một cách là tạo một giá trị Organization_ID đặc biệt (ví dụ 0 hoặc -1) cho global,
            # hoặc quản lý tính duy nhất ở tầng ứng dụng.
            # Hoặc tạo cột `Global_Setting_Key` UNIQUE riêng nếu tách bảng.

            # Bảng Evaluation_Periods
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS Evaluation_Periods (
                Period_ID INT AUTO_INCREMENT PRIMARY KEY,
                Organization_ID INT NOT NULL,
                Period_Name VARCHAR(100) NOT NULL,
                Period_Type VARCHAR(20) NOT NULL, -- 'MONTHLY', 'QUARTERLY', 'ANNUAL'
                Start_Date DATE NOT NULL,
                End_Date DATE NOT NULL,
                Is_Active_For_Input BOOLEAN DEFAULT TRUE,
                Is_Closed_For_Evaluation BOOLEAN DEFAULT FALSE,
                FOREIGN KEY (Organization_ID) REFERENCES Organizations(Organization_ID) ON DELETE CASCADE,
                UNIQUE (Organization_ID, Period_Name)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)

            # BSC_Perspectives
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS BSC_Perspectives (
                Perspective_ID INT AUTO_INCREMENT PRIMARY KEY,
                Perspective_Name VARCHAR(255) NOT NULL,
                Organization_ID INT NOT NULL,
                FOREIGN KEY (Organization_ID) REFERENCES Organizations(Organization_ID) ON DELETE CASCADE,
                UNIQUE (Organization_ID, Perspective_Name)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)
            # Strategic_Objectives
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS Strategic_Objectives (
                Objective_ID INT AUTO_INCREMENT PRIMARY KEY,
                Objective_Name TEXT NOT NULL,
                Perspective_ID INT NOT NULL,
                FOREIGN KEY (Perspective_ID) REFERENCES BSC_Perspectives(Perspective_ID) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)
            # School_KPI_Definitions
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS School_KPI_Definitions (
                School_KPI_Def_ID INT AUTO_INCREMENT PRIMARY KEY,
                KPI_Name TEXT NOT NULL,
                Description TEXT,
                Unit_Of_Measure VARCHAR(100),
                Strategic_Objective_ID INT NOT NULL,
                Default_Weight FLOAT,
                FOREIGN KEY (Strategic_Objective_ID) REFERENCES Strategic_Objectives(Objective_ID) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)
            # School_Monthly_KPI_Results
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS School_Monthly_KPI_Results (
                Result_ID INT AUTO_INCREMENT PRIMARY KEY,
                School_KPI_Def_ID INT NOT NULL,
                Period_ID INT NOT NULL,
                Weight FLOAT, Target_Value DECIMAL(18,2), Actual_Value DECIMAL(18,2),
                Completion_Rate FLOAT, Monthly_Score FLOAT, Notes TEXT,
                FOREIGN KEY (School_KPI_Def_ID) REFERENCES School_KPI_Definitions(School_KPI_Def_ID) ON DELETE CASCADE,
                FOREIGN KEY (Period_ID) REFERENCES Evaluation_Periods(Period_ID) ON DELETE CASCADE,
                UNIQUE (School_KPI_Def_ID, Period_ID)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)
            # Individual_Monthly_KPIs
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS Individual_Monthly_KPIs (
                Ind_KPI_ID INT AUTO_INCREMENT PRIMARY KEY,
                Employee_ID VARCHAR(20) NOT NULL,
                Period_ID INT NOT NULL,
                Task_Description TEXT, KPI_Indicator TEXT, Unit_Of_Measure VARCHAR(100), Weight FLOAT,
                Target_Value_Text VARCHAR(255), Target_Value_Numeric DECIMAL(18,2),
                Self_Assessed_Result_Text VARCHAR(255), Self_Assessed_Result_Numeric DECIMAL(18,2), Self_Assessed_Score FLOAT,
                Principal_Assessed_Result_Text VARCHAR(255), Principal_Assessed_Result_Numeric DECIMAL(18,2), Principal_Assessed_Score FLOAT,
                Chairman_Assessed_Result_Text VARCHAR(255), Chairman_Assessed_Result_Numeric DECIMAL(18,2), Chairman_Assessed_Score FLOAT,
                Final_Agreed_Score FLOAT, Notes TEXT,
                FOREIGN KEY (Employee_ID) REFERENCES Employees(Employee_ID) ON DELETE CASCADE,
                FOREIGN KEY (Period_ID) REFERENCES Evaluation_Periods(Period_ID) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)
            # Individual_Monthly_Overall_Scores
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS Individual_Monthly_Overall_Scores (
                Overall_Score_ID INT AUTO_INCREMENT PRIMARY KEY,
                Employee_ID VARCHAR(20) NOT NULL,
                Period_ID INT NOT NULL,
                Total_Individual_KPI_Score FLOAT,
                FOREIGN KEY (Employee_ID) REFERENCES Employees(Employee_ID) ON DELETE CASCADE,
                FOREIGN KEY (Period_ID) REFERENCES Evaluation_Periods(Period_ID) ON DELETE CASCADE,
                UNIQUE (Employee_ID, Period_ID)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)
            # Monthly_Salaries
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS Monthly_Salaries (
                Monthly_Salary_ID INT AUTO_INCREMENT PRIMARY KEY,
                Employee_ID VARCHAR(20) NOT NULL,
                Period_ID INT NOT NULL,
                P1_Actual DECIMAL(18,2), P2_Actual DECIMAL(18,2), Other_Fixed_Actual DECIMAL(18,2), Total_Fixed_Salary DECIMAL(18,2),
                Individual_KPI_Score_Used FLOAT, School_KPI_Score_Used FLOAT,
                P3_Individual_Bonus DECIMAL(18,2) DEFAULT 0, P3_School_Bonus DECIMAL(18,2) DEFAULT 0, Total_P3_Salary DECIMAL(18,2),
                Gross_Salary DECIMAL(18,2), Deductions DECIMAL(18,2) DEFAULT 0, Net_Salary DECIMAL(18,2), Notes TEXT,
                FOREIGN KEY (Employee_ID) REFERENCES Employees(Employee_ID) ON DELETE CASCADE,
                FOREIGN KEY (Period_ID) REFERENCES Evaluation_Periods(Period_ID) ON DELETE CASCADE,
                UNIQUE (Employee_ID, Period_ID)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)
            # Salary_Structure_3P
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS Salary_Structure_3P (
                Structure_3P_ID INT AUTO_INCREMENT PRIMARY KEY,
                Employee_ID VARCHAR(20) NOT NULL,
                Effective_Date DATE NOT NULL,
                P1_Position_Salary DECIMAL(18,2) DEFAULT 0,
                P2_Person_Salary DECIMAL(18,2) DEFAULT 0,
                Other_Fixed_Allowances DECIMAL(18,2) DEFAULT 0,
                Is_Active BOOLEAN DEFAULT TRUE,
                FOREIGN KEY (Employee_ID) REFERENCES Employees(Employee_ID) ON DELETE CASCADE,
                UNIQUE (Employee_ID, Effective_Date)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)
            # Debt_Details
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS Debt_Details (
                Debt_ID INT AUTO_INCREMENT PRIMARY KEY,
                Organization_ID INT NOT NULL,
                Reference_Code VARCHAR(100),
                Debtor_Name VARCHAR(255),
                Debt_Type VARCHAR(255),
                Amount DECIMAL(18,2) NOT NULL,
                Issue_Date DATE, Due_Date DATE, Status VARCHAR(100),
                Month_Reported INT, Year_Reported INT, Notes TEXT,
                FOREIGN KEY (Organization_ID) REFERENCES Organizations(Organization_ID) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)

            conn.commit()
            print("--- Các bảng MySQL đã được tạo/cập nhật hoặc đã tồn tại. ---")
        except mysql.connector.Error as err:
            print(f"Lỗi khi tạo bảng MySQL: {err}")
        finally:
            if cursor: cursor.close()
            conn.close()
    else:
        print("Không thể kết nối CSDL MySQL để khởi tạo.")


# --- PHẦN 2: MODELS (Giữ nguyên như phiên bản trước) ---
# (Các dataclass Role, Permission, User, AuditLog, ApplicationSetting, EvaluationPeriod,
#  Organization, Employee, Position, BSCPerspective, StrategicObjective, SchoolKPIDefinition,
#  SchoolMonthlyKPIResult, IndividualMonthlyKPI, IndividualMonthlyOverallScore, MonthlySalary, DebtDetail
#  giữ nguyên như trong kpi_bsc_web_app_v2_with_enhancements)
@dataclass
class Organization:
    Organization_ID: Optional[int] = None; Organization_Name: str = ""; Address: Optional[str] = None
    Contact_Person: Optional[str] = None; Contact_Email: Optional[str] = None
    Contact_Phone: Optional[str] = None; Is_Active: bool = True

@dataclass
class Role:
    Role_ID: Optional[int] = None; Role_Name: str = ""; Description: Optional[str] = None
    Is_System_Role: bool = False
    permissions: List['Permission'] = field(default_factory=list)

@dataclass
class Permission:
    Permission_ID: Optional[int] = None; Permission_Key: str = ""; Description: Optional[str] = None

@dataclass
class User:
    User_ID: Optional[int] = None; Username: str = ""; Password_Hash: str = ""
    FullName: Optional[str] = None; Email: str = "";
    Organization_ID: Optional[int] = None; Employee_ID: Optional[str] = None
    Is_Active: bool = True; Last_Login: Optional[str] = None
    organization_name: Optional[str] = None; employee_fullname: Optional[str] = None
    roles: List[Role] = field(default_factory=list)
    permissions: Set[str] = field(default_factory=set)

@dataclass
class AuditLog:
    Log_ID: Optional[int] = None; User_ID: Optional[int] = None; Organization_ID: Optional[int] = None
    Timestamp: str = ""; Action_Type: str = ""; Table_Name: Optional[str] = None
    Record_ID: Optional[str] = None; Field_Name: Optional[str] = None
    Old_Value: Optional[str] = None; New_Value: Optional[str] = None
    Description: Optional[str] = None; IP_Address: Optional[str] = None
    username: Optional[str] = None

@dataclass
class ApplicationSetting:
    Setting_ID: Optional[int] = None; Organization_ID: Optional[int] = None
    Setting_Key: str = ""; Setting_Value: Optional[str] = None; Data_Type: Optional[str] = None
    Description: Optional[str] = None; Is_Editable_By_Org_Admin: bool = False
    organization_name: Optional[str] = None

@dataclass
class EvaluationPeriod:
    Period_ID: Optional[int] = None; Organization_ID: int = 0
    Period_Name: str = ""; Period_Type: str = ""
    Start_Date: str = ""; End_Date: str = ""
    Is_Active_For_Input: bool = True; Is_Closed_For_Evaluation: bool = False
    organization_name: Optional[str] = None

@dataclass
class Position:
    Position_ID: Optional[int] = None; Position_Name: str = ""; Organization_ID: Optional[int] = None
    Description: Optional[str] = None; organization_name: Optional[str] = None

@dataclass
class Employee:
    Employee_ID: str = ""; FullName: str = ""; Position_ID: Optional[int] = None
    Organization_ID: Optional[int] = None; Email: Optional[str] = None
    PhoneNumber: Optional[str] = None; StartDate: Optional[str] = None; Status: str = 'Active'
    position_name: Optional[str] = None; organization_name: Optional[str] = None

@dataclass
class BSCPerspective:
    Perspective_ID: Optional[int] = None; Perspective_Name: str = ""
    Organization_ID: Optional[int] = None; organization_name: Optional[str] = None

@dataclass
class StrategicObjective:
    Objective_ID: Optional[int] = None; Objective_Name: str = ""
    Perspective_ID: Optional[int] = None; perspective_name: Optional[str] = None

@dataclass
class SchoolKPIDefinition:
    School_KPI_Def_ID: Optional[int] = None; KPI_Name: str = ""
    Unit_Of_Measure: Optional[str] = None; Description: Optional[str] = None
    Strategic_Objective_ID: Optional[int] = None; Default_Weight: Optional[float] = None
    strategic_objective_name: Optional[str] = None; perspective_name: Optional[str] = None

@dataclass
class SchoolMonthlyKPIResult:
    Result_ID: Optional[int] = None; School_KPI_Def_ID: Optional[int] = None
    Period_ID: Optional[int] = None
    Weight: Optional[float] = None; Target_Value: Optional[float] = None; Actual_Value: Optional[float] = None
    Completion_Rate: Optional[float] = None; Monthly_Score: Optional[float] = None
    Notes: Optional[str] = None; kpi_name: Optional[str] = None; period_name: Optional[str] = None

@dataclass
class IndividualMonthlyKPI:
    Ind_KPI_ID: Optional[int] = None; Employee_ID: str = ""; Period_ID: Optional[int] = None
    Task_Description: Optional[str] = None; KPI_Indicator: Optional[str] = None; Unit_Of_Measure: Optional[str] = None
    Weight: Optional[float] = None; Target_Value_Text: Optional[str] = None; Target_Value_Numeric: Optional[float] = None
    Self_Assessed_Result_Text: Optional[str] = None; Self_Assessed_Result_Numeric: Optional[float] = None; Self_Assessed_Score: Optional[float] = None
    Principal_Assessed_Score: Optional[float] = None; Chairman_Assessed_Score: Optional[float] = None # Thêm 2 trường này từ model gốc
    Principal_Assessed_Result_Text: Optional[str] = None; Principal_Assessed_Result_Numeric: Optional[float] = None; # Thêm từ DB
    Chairman_Assessed_Result_Text: Optional[str] = None; Chairman_Assessed_Result_Numeric: Optional[float] = None; # Thêm từ DB
    Final_Agreed_Score: Optional[float] = None; Notes: Optional[str] = None; period_name: Optional[str] = None


@dataclass
class IndividualMonthlyOverallScore:
    Overall_Score_ID: Optional[int] = None; Employee_ID: str = ""; Period_ID: Optional[int] = None
    Total_Individual_KPI_Score: Optional[float] = None; period_name: Optional[str] = None

@dataclass
class SalaryStructure3P:
    Structure_3P_ID: Optional[int] = None; Employee_ID: str = ""; Effective_Date: str = ""
    P1_Position_Salary: float = 0.0; P2_Person_Salary: float = 0.0
    Other_Fixed_Allowances: float = 0.0; Is_Active: bool = True

@dataclass
class MonthlySalary:
    Monthly_Salary_ID: Optional[int] = None; Employee_ID: str = ""; Period_ID: Optional[int] = None
    P1_Actual: Optional[float] = None; P2_Actual: Optional[float] = None; Other_Fixed_Actual: Optional[float] = None
    Total_Fixed_Salary: Optional[float] = None; Individual_KPI_Score_Used: Optional[float] = None
    School_KPI_Score_Used: Optional[float] = None; P3_Individual_Bonus: float = 0.0; P3_School_Bonus: float = 0.0
    Total_P3_Salary: Optional[float] = None; Gross_Salary: Optional[float] = None
    Deductions: float = 0.0; Net_Salary: Optional[float] = None; Notes: Optional[str] = None
    employee_fullname: Optional[str] = None; period_name: Optional[str] = None

@dataclass
class DebtDetail:
    Debt_ID: Optional[int] = None; Organization_ID: Optional[int] = None
    Reference_Code: Optional[str] = None; Debtor_Name: Optional[str] = None
    Debt_Type: Optional[str] = None; Amount: float = 0.0; Issue_Date: Optional[str] = None
    Due_Date: Optional[str] = None; Status: Optional[str] = None
    Month_Reported: Optional[int] = None; Year_Reported: Optional[int] = None # Có thể bỏ nếu dùng Period_ID cho Debt
    Notes: Optional[str] = None; organization_name: Optional[str] = None


# --- PHẦN 3: DB OPERATIONS (Cập nhật cho MySQL) ---
def get_db_connection_flask_mysql(): # Đổi tên hàm
    # Flask's g object is not available here if this is run outside app context
    # For simplicity, we'll create a new connection each time in these db_ops functions
    # In a real app, you'd manage connections more carefully, e.g., connection pooling
    # or ensuring g is available.
    # For this script, we assume direct calls.
    return create_connection_app_mysql() # Sử dụng hàm tạo kết nối MySQL mới

# --- Role Operations (Cập nhật placeholder '?' thành '%s') ---
def add_role_db(role: Role) -> Optional[int]:
    conn = get_db_connection_flask_mysql();
    if not conn: return None
    cursor = conn.cursor()
    try:
        cursor.execute("INSERT INTO Roles (Role_Name, Description, Is_System_Role) VALUES (%s, %s, %s)",
                       (role.Role_Name, role.Description, role.Is_System_Role))
        conn.commit(); return cursor.lastrowid
    except mysql.connector.Error as err:
        if err.errno == errorcode.ER_DUP_ENTRY: # Lỗi trùng lặp
             print(f"Lỗi: Tên vai trò '{role.Role_Name}' đã tồn tại.")
        else:
            print(f"Lỗi MySQL khi thêm vai trò: {err}")
        return None
    finally: conn.close()

def get_role_by_id_db(role_id: int) -> Optional[Role]:
    conn = get_db_connection_flask_mysql();
    if not conn: return None
    cursor = conn.cursor(dictionary=True) # Sử dụng dictionary cursor
    cursor.execute("SELECT * FROM Roles WHERE Role_ID = %s", (role_id,))
    row = cursor.fetchone()
    conn.close()
    return Role(**row) if row else None # **row vì cursor trả về dict

def get_all_roles_db() -> List[Role]:
    conn = get_db_connection_flask_mysql();
    if not conn: return []
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM Roles ORDER BY Role_Name")
    rows = cursor.fetchall()
    conn.close()
    return [Role(**row) for row in rows]

# --- Permission Operations (Cập nhật placeholder) ---
def add_permission_db(permission: Permission) -> Optional[int]:
    conn = get_db_connection_flask_mysql();
    if not conn: return None
    cursor = conn.cursor()
    try:
        cursor.execute("INSERT INTO Permissions (Permission_Key, Description) VALUES (%s, %s)",
                       (permission.Permission_Key, permission.Description))
        conn.commit(); return cursor.lastrowid
    except mysql.connector.Error as err:
        if err.errno == errorcode.ER_DUP_ENTRY:
            print(f"Lỗi: Khóa quyền '{permission.Permission_Key}' đã tồn tại.")
        else:
            print(f"Lỗi MySQL khi thêm quyền: {err}")
        return None
    finally: conn.close()

def get_all_permissions_db() -> List[Permission]:
    conn = get_db_connection_flask_mysql();
    if not conn: return []
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM Permissions ORDER BY Permission_Key")
    rows = cursor.fetchall()
    conn.close()
    return [Permission(**row) for row in rows]

# --- Role_Permission Operations (Cập nhật placeholder) ---
def assign_permission_to_role_db(role_id: int, permission_id: int) -> bool:
    conn = get_db_connection_flask_mysql();
    if not conn: return False
    cursor = conn.cursor()
    try:
        cursor.execute("INSERT INTO Role_Permissions (Role_ID, Permission_ID) VALUES (%s, %s)", (role_id, permission_id))
        conn.commit(); return True
    except mysql.connector.Error as err:
        if err.errno == errorcode.ER_DUP_ENTRY: print("Quyền này đã được gán cho vai trò.")
        else: print(f"Lỗi MySQL khi gán quyền: {err}")
        return False
    finally: conn.close()

# (Tương tự, cập nhật tất cả các hàm trong db_operations.py để dùng %s và dictionary=True cho cursor nếu cần)
# Ví dụ cho get_user_by_username_db:
def get_user_by_username_db(username: str) -> Optional[User]:
    conn = get_db_connection_flask_mysql()
    if not conn: return None
    cursor = conn.cursor(dictionary=True) # QUAN TRỌNG
    cursor.execute("""
        SELECT u.*, o.Organization_Name, e.FullName as employee_fullname
        FROM Users u
        LEFT JOIN Organizations o ON u.Organization_ID = o.Organization_ID
        LEFT JOIN Employees e ON u.Employee_ID = e.Employee_ID
        WHERE u.Username = %s AND u.Is_Active = TRUE
    """, (username,)) # Placeholder là %s
    row = cursor.fetchone()
    conn.close()
    return User(**row) if row else None # **row vì cursor trả về dict

# Cập nhật hàm add_user_db
def add_user_db(user: User) -> Optional[int]:
    conn = get_db_connection_flask_mysql()
    if not conn: return None
    cursor = conn.cursor()
    try:
        hashed_password = generate_password_hash(user.Password_Hash)
        cursor.execute("""
            INSERT INTO Users (Username, Password_Hash, FullName, Email, Organization_ID, Employee_ID, Is_Active)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (user.Username, hashed_password, user.FullName, user.Email,
              user.Organization_ID, user.Employee_ID, user.Is_Active))
        conn.commit()
        return cursor.lastrowid
    except mysql.connector.Error as err:
        if err.errno == errorcode.ER_DUP_ENTRY:
            print(f"Lỗi: Username '{user.Username}', Email '{user.Email}', hoặc Employee_ID '{user.Employee_ID}' đã tồn tại.")
        elif err.errno == errorcode.ER_NO_REFERENCED_ROW_2 : # Lỗi khóa ngoại
             print(f"Lỗi khóa ngoại khi thêm người dùng: Organization_ID hoặc Employee_ID không hợp lệ. Lỗi: {err}")
        else:
            print(f"Lỗi MySQL khi thêm người dùng: {err}")
        return None
    finally:
        conn.close()

# Cần cập nhật tất cả các hàm DB Operations khác tương tự:
# - Sử dụng get_db_connection_flask_mysql()
# - Thay đổi placeholder từ ? thành %s
# - Sử dụng cursor = conn.cursor(dictionary=True) khi fetch dữ liệu để trả về dict
# - Bắt lỗi mysql.connector.Error và các errorcode cụ thể nếu cần.
# - Đối với INSERT ... ON CONFLICT (SQLite) -> INSERT ... ON DUPLICATE KEY UPDATE (MySQL)
# Ví dụ cho add_or_update_individual_overall_score_ops:
def add_or_update_individual_overall_score_ops(score: IndividualMonthlyOverallScore):
    conn = get_db_connection_flask_mysql()
    if not conn: return
    cursor = conn.cursor()
    # MySQL dùng INSERT ... ON DUPLICATE KEY UPDATE
    sql = """
        INSERT INTO Individual_Monthly_Overall_Scores (Employee_ID, Period_ID, Total_Individual_KPI_Score)
        VALUES (%s, %s, %s)
        ON DUPLICATE KEY UPDATE Total_Individual_KPI_Score = VALUES(Total_Individual_KPI_Score)
    """
    params = (score.Employee_ID, score.Period_ID, score.Total_Individual_KPI_Score)
    try:
        cursor.execute(sql, params)
        conn.commit()
    except mysql.connector.Error as e:
        print(f"Lỗi MySQL khi lưu điểm KPI tổng hợp cá nhân: {e}")
    finally:
        conn.close()

# --- PHẦN 4: AUTH & ROLE MANAGEMENT (Giữ nguyên logic, chỉ thay đổi cách gọi DB ops nếu cần) ---
# (Hàm log_action, login_required_v2, load_logged_in_user_and_current_period, login_v2, logout_v2,
#  current_user_has_permission, utility_processor giữ nguyên logic,
#  chỉ cần đảm bảo các hàm DB mà chúng gọi đã được cập nhật cho MySQL)

# --- PHẦN 5: ROUTES & VIEWS (Giữ nguyên logic, chỉ thay đổi cách gọi DB ops nếu cần) ---
# (Các route @app.route(...) giữ nguyên logic,
#  chỉ cần đảm bảo các hàm DB mà chúng gọi đã được cập nhật cho MySQL)

# --- Context Processor (Giữ nguyên) ---
# @app.context_processor
# def inject_now_and_global_vars_v2(): ...

# --- CHẠY ỨNG DỤNG ---
if __name__ == '__main__':
    # 1. Khởi tạo CSDL và bảng (nếu chạy lần đầu với MySQL)
    # Bạn cần đảm bảo Database đã được tạo trong MySQL Server của bạn.
    # Hàm init_db_app_mysql() sẽ tạo các bảng.
    init_db_app_mysql()

    # 2. Tạo các quyền và vai trò cơ bản ban đầu (nếu cần)
    # (Hàm setup_initial_roles_permissions() và create_initial_system_admin()
    #  cần được gọi ở đây, và các hàm DB bên trong chúng cũng phải được cập nhật cho MySQL)
    # Ví dụ một phần của setup_initial_roles_permissions cho MySQL:
    def setup_initial_roles_permissions_mysql():
        conn = get_db_connection_flask_mysql()
        if not conn: print("Không thể kết nối MySQL để thiết lập roles/permissions."); return
        cursor = conn.cursor()
        
        permissions_to_create = [
            ('manage_users', 'Quản lý người dùng trong đơn vị'), ('view_users', 'Xem danh sách người dùng'),
            # ... (các permissions khác như trước) ...
            ('SUPER_ADMIN', 'Quyền quản trị cao nhất hệ thống')
        ]
        perm_map = {}
        for key, desc in permissions_to_create:
            try:
                cursor.execute("INSERT INTO Permissions (Permission_Key, Description) VALUES (%s,%s)", (key, desc))
                perm_map[key] = cursor.lastrowid
            except mysql.connector.Error as err:
                if err.errno == errorcode.ER_DUP_ENTRY: # Lấy ID nếu đã tồn tại
                    cursor.execute("SELECT Permission_ID FROM Permissions WHERE Permission_Key = %s", (key,))
                    row = cursor.fetchone()
                    if row: perm_map[key] = row[0] # cursor không dict
                else: print(f"Lỗi khi tạo permission {key}: {err}")
        # ... (Tiếp tục với Roles và Role_Permissions, User_Roles tương tự) ...
        conn.commit()
        print(">>> Đã thiết lập Roles và Permissions cơ bản cho MySQL (nếu chưa có). <<<")
        cursor.close()
        conn.close()

    # setup_initial_roles_permissions_mysql() # Chạy một lần

    def create_initial_system_admin_mysql():
        conn = get_db_connection_flask_mysql()
        if not conn: print("Không thể kết nối MySQL để tạo admin."); return
        cursor = conn.cursor()
        try:
            cursor.execute("SELECT User_ID FROM Users WHERE Username = 'sysadmin'")
            if not cursor.fetchone():
                admin_pass_hash = generate_password_hash("adminpass")
                cursor.execute("""
                    INSERT INTO Users (Username, Password_Hash, FullName, Email, Organization_ID, Is_Active)
                    VALUES (%s, %s, %s, %s, %s, %s)
                """, ('sysadmin', admin_pass_hash, 'System Super Admin', 'sysadmin@example.com', None, True))
                sysadmin_user_id = cursor.lastrowid
                
                cursor.execute("SELECT Role_ID FROM Roles WHERE Role_Name = 'System Admin'")
                sysadmin_role_row = cursor.fetchone() # cursor không dict
                if sysadmin_role_row and sysadmin_user_id:
                    sysadmin_role_id = sysadmin_role_row[0]
                    cursor.execute("INSERT INTO User_Roles (User_ID, Role_ID) VALUES (%s,%s)", (sysadmin_user_id, sysadmin_role_id))
                conn.commit()
                print(">>> Đã tạo người dùng 'sysadmin' (MySQL) với mật khẩu 'adminpass'. <<<")
        except mysql.connector.Error as e: print(f"Lỗi khi tạo sysadmin (MySQL): {e}")
        finally: cursor.close(); conn.close()

    # create_initial_system_admin_mysql() # Chạy một lần

    app.run(debug=True, port=5002) # Chạy trên port khác để tránh xung đột