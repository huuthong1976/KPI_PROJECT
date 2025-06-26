-- SQL Schema for KPI Management Application using MySQL

-- Xóa các bảng nếu chúng đã tồn tồn tại để tránh lỗi khi chạy lại file
DROP TABLE IF EXISTS `actuals`;
DROP TABLE IF EXISTS `targets`;
DROP TABLE IF EXISTS `kpis`;
DROP TABLE IF EXISTS `perspectives`;
DROP TABLE IF EXISTS `users`;
DROP TABLE IF EXISTS `units`;

-- Bảng 1: Quản lý các Đơn vị thành viên
CREATE TABLE `units` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(255) NOT NULL UNIQUE COMMENT 'Tên đơn vị thành viên',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) COMMENT='Lưu trữ danh sách các đơn vị thành viên';

-- Bảng 2: Quản lý người dùng và phân quyền
CREATE TABLE `users` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `username` VARCHAR(100) NOT NULL UNIQUE,
    `hashed_password` VARCHAR(255) NOT NULL COMMENT 'Mật khẩu đã được băm an toàn',
    `role` ENUM('admin', 'manager') NOT NULL DEFAULT 'manager' COMMENT 'Vai trò người dùng: admin hoặc manager',
    `unit_id` INT NULL COMMENT 'ID của đơn vị mà manager quản lý, NULL nếu là admin',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (`unit_id`) REFERENCES `units`(`id`) ON DELETE SET NULL
) COMMENT='Bảng người dùng, vai trò và thông tin đăng nhập';

-- Bảng 3: Quản lý các Khía cạnh của BSC
CREATE TABLE `perspectives` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(255) NOT NULL UNIQUE COMMENT 'Tên khía cạnh: Tài chính, Khách hàng...'
) COMMENT='Lưu trữ 4 khía cạnh của Balanced Scorecard';

-- Bảng 4: Quản lý các Định nghĩa KPI
CREATE TABLE `kpis` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(255) NOT NULL UNIQUE COMMENT 'Tên của chỉ số KPI',
    `unit_of_measure` VARCHAR(50) COMMENT 'Đơn vị tính: VNĐ, %, Điểm, ...',
    `description` TEXT NULL COMMENT 'Mô tả chi tiết hơn về KPI',
    `perspective_id` INT NOT NULL COMMENT 'Liên kết tới khía cạnh BSC',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (`perspective_id`) REFERENCES `perspectives`(`id`) ON DELETE RESTRICT
) COMMENT='Lưu trữ danh mục và định nghĩa của tất cả các KPIs';

-- Bảng 5: Quản lý các Mục tiêu KPI
CREATE TABLE `targets` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `kpi_id` INT NOT NULL,
    `unit_id` INT NOT NULL,
    `year` YEAR NOT NULL COMMENT 'Năm áp dụng mục tiêu',
    `monthly_target` DECIMAL(18, 2) NULL COMMENT 'Chỉ tiêu cho 1 tháng',
    `annual_target` DECIMAL(18, 2) NULL COMMENT 'Chỉ tiêu cho cả năm',
    `weight` VARCHAR(50) NULL COMMENT 'Trọng số của KPI',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_target_period` (`kpi_id`, `unit_id`, `year`),
    FOREIGN KEY (`kpi_id`) REFERENCES `kpis`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`unit_id`) REFERENCES `units`(`id`) ON DELETE CASCADE
) COMMENT='Lưu trữ các chỉ tiêu KPI được giao cho từng đơn vị theo năm';

-- Bảng 6: Lưu trữ các Kết quả thực tế hàng tháng
CREATE TABLE `actuals` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `kpi_id` INT NOT NULL,
    `unit_id` INT NOT NULL,
    `year` YEAR NOT NULL,
    `month` TINYINT NOT NULL COMMENT 'Tháng báo cáo (1-12)',
    `actual_value` DECIMAL(18, 2) NOT NULL COMMENT 'Giá trị thực tế đạt được',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_actual_period` (`kpi_id`, `unit_id`, `year`, `month`),
    FOREIGN KEY (`kpi_id`) REFERENCES `kpis`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`unit_id`) REFERENCES `units`(`id`) ON DELETE CASCADE
) COMMENT='Lưu trữ kết quả KPI thực tế hàng tháng của các đơn vị';

-- Thêm các chỉ mục để tăng tốc độ truy vấn
CREATE INDEX `idx_users_unit_id` ON `users`(`unit_id`);
CREATE INDEX `idx_kpis_perspective_id` ON `kpis`(`perspective_id`);
CREATE INDEX `idx_targets_unit_year` ON `targets`(`unit_id`, `year`);
CREATE INDEX `idx_actuals_unit_year_month` ON `actuals`(`unit_id`, `year`, `month`);

-- Thêm một vài dữ liệu mẫu
INSERT INTO `perspectives` (`name`) VALUES 
('Viễn cảnh tài chính'), 
('Viễn cảnh khách hàng'), 
('Viễn cảnh qui trình nội bộ'), 
('Viễn cảnh học tập và phát triển');

INSERT INTO `units` (`name`) VALUES ('Trường Trần Đại Nghĩa - TDN');

COMMIT;