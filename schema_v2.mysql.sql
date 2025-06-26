-- =================================================================
-- SQL Schema V2 for KPI Management Application with Individual KPIs
-- =================================================================

DROP TABLE IF EXISTS `pay_slips`;
DROP TABLE IF EXISTS `monthly_assessments`;
DROP TABLE IF EXISTS `individual_kpi_assignments`;
DROP TABLE IF EXISTS `actuals`;
DROP TABLE IF EXISTS `targets`;
DROP TABLE IF EXISTS `kpis`;
DROP TABLE IF EXISTS `perspectives`;
DROP TABLE IF EXISTS `users`;
DROP TABLE IF EXISTS `units`;

-- Bảng 1: Quản lý các Đơn vị thành viên (giữ nguyên)
CREATE TABLE `units` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(255) NOT NULL UNIQUE
) COMMENT='Lưu trữ danh sách các đơn vị thành viên';

-- Bảng 2: Quản lý người dùng (mở rộng với thông tin lương)
CREATE TABLE `users` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `username` VARCHAR(100) NOT NULL UNIQUE,
    `full_name` VARCHAR(255) NOT NULL,
    `hashed_password` VARCHAR(255) NOT NULL,
    `role` ENUM('admin', 'director', 'manager', 'employee') NOT NULL,
    `unit_id` INT NULL,
    `manager_id` INT NULL COMMENT 'ID của người quản lý trực tiếp',
    `base_salary_p1` DECIMAL(18, 2) DEFAULT 0 COMMENT 'Lương theo vị trí (P1)',
    `competency_salary_p2` DECIMAL(18, 2) DEFAULT 0 COMMENT 'Lương theo năng lực (P2)',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (`unit_id`) REFERENCES `units`(`id`) ON DELETE SET NULL,
    FOREIGN KEY (`manager_id`) REFERENCES `users`(`id`) ON DELETE SET NULL
) COMMENT='Bảng người dùng mở rộng với thông tin lương và cấp quản lý';

-- Bảng 3 & 4: Perspectives và KPIs (giữ nguyên)
CREATE TABLE `perspectives` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(255) NOT NULL UNIQUE
);
CREATE TABLE `kpis` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(255) NOT NULL UNIQUE,
    `unit_of_measure` VARCHAR(50),
    `description` TEXT NULL,
    `perspective_id` INT NOT NULL,
    FOREIGN KEY (`perspective_id`) REFERENCES `perspectives`(`id`) ON DELETE RESTRICT
) COMMENT='KPIs của đơn vị (company-level)';

-- Bảng 5: Mục tiêu của Đơn vị (giữ nguyên)
CREATE TABLE `targets` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `kpi_id` INT NOT NULL,
    `unit_id` INT NOT NULL,
    `year` YEAR NOT NULL,
    `monthly_target` DECIMAL(18, 2) NULL,
    FOREIGN KEY (`kpi_id`) REFERENCES `kpis`(`id`),
    FOREIGN KEY (`unit_id`) REFERENCES `units`(`id`)
);

-- Bảng 6: Kết quả thực tế của Đơn vị (giữ nguyên)
CREATE TABLE `actuals` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `kpi_id` INT NOT NULL,
    `unit_id` INT NOT NULL,
    `year` YEAR NOT NULL,
    `month` TINYINT NOT NULL,
    `actual_value` DECIMAL(18, 2) NOT NULL,
    FOREIGN KEY (`kpi_id`) REFERENCES `kpis`(`id`),
    FOREIGN KEY (`unit_id`) REFERENCES `units`(`id`)
);

-- =================================================================
-- CÁC BẢNG MỚI CHO KPI CÁ NHÂN VÀ LƯƠNG
-- =================================================================

-- Bảng 7: Bảng Giao KPI cho Cá nhân
CREATE TABLE `individual_kpi_assignments` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `user_id` INT NOT NULL,
    `kpi_description` TEXT NOT NULL COMMENT 'Mô tả công việc hoặc tên KPI cá nhân',
    `year` YEAR NOT NULL,
    `month` TINYINT NOT NULL,
    `target_description` TEXT COMMENT 'Mô tả mục tiêu cần đạt',
    `weight` DECIMAL(5, 2) NOT NULL COMMENT 'Tỷ trọng của KPI cá nhân (tổng = 100%)',
    FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) COMMENT='Lưu trữ các KPI được giao cho từng nhân viên theo tháng';

-- Bảng 8: Bảng Đánh giá Hàng tháng
CREATE TABLE `monthly_assessments` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `assignment_id` INT NOT NULL COMMENT 'Liên kết tới KPI cá nhân được giao',
    `employee_comment` TEXT NULL COMMENT 'Nhân viên tự ghi nhận kết quả',
    `employee_score` TINYINT NULL COMMENT 'Nhân viên tự đánh giá (thang điểm 10)',
    `manager_comment` TEXT NULL COMMENT 'Quản lý nhận xét',
    `manager_score` TINYINT NULL COMMENT 'Quản lý đánh giá (thang điểm 10)',
    `director_comment` TEXT NULL COMMENT 'TGĐ nhận xét (nếu có)',
    `director_score` TINYINT NULL COMMENT 'TGĐ đánh giá (thang điểm 10)',
    `final_score` DECIMAL(5, 2) NULL COMMENT 'Điểm số cuối cùng sau khi có tất cả đánh giá',
    `status` ENUM('pending', 'employee_assessed', 'manager_assessed', 'completed') DEFAULT 'pending',
    UNIQUE KEY `uk_assessment` (`assignment_id`),
    FOREIGN KEY (`assignment_id`) REFERENCES `individual_kpi_assignments`(`id`) ON DELETE CASCADE
) COMMENT='Lưu trữ quy trình đánh giá đa cấp cho mỗi KPI cá nhân';

-- Bảng 9: Bảng Lương Hàng tháng
CREATE TABLE `pay_slips` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `user_id` INT NOT NULL,
    `year` YEAR NOT NULL,
    `month` TINYINT NOT NULL,
    `unit_kpi_percentage` DECIMAL(5, 2) COMMENT 'Tỷ lệ hoàn thành KPI của đơn vị (%)',
    `individual_kpi_score` DECIMAL(5, 2) COMMENT 'Điểm KPI cá nhân cuối cùng',
    `base_salary_p1` DECIMAL(18, 2),
    `competency_salary_p2` DECIMAL(18, 2),
    `performance_salary_p3` DECIMAL(18, 2) COMMENT 'Lương hiệu suất P3 được tính toán',
    `other_allowances` DECIMAL(18, 2) DEFAULT 0,
    `deductions` DECIMAL(18, 2) DEFAULT 0,
    `final_salary` DECIMAL(18, 2) COMMENT 'Lương thực nhận',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_payslip_period` (`user_id`, `year`, `month`),
    FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) COMMENT='Lưu trữ bảng lương chi tiết sau khi tính toán';

COMMIT;