# Tao cac bang mo phong co so du lieu chinh
CREATE TABLE `products` (
    `id` INT NOT NULL AUTO_INCREMENT UNIQUE,
    `name` VARCHAR(255) NOT NULL,
    `description` TEXT(65535),
    `price` DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    `category_id` INT NOT NULL,
    `detail` JSON COMMENT 'Lưu thông số cụ thể của 1 sản phẩm. Ví dụ quần áo thì có size, máy tính thì có ram',
    PRIMARY KEY (`id`)
);

CREATE TABLE `categories` (
    `id` INT NOT NULL AUTO_INCREMENT UNIQUE,
    `name` VARCHAR(255) NOT NULL,
    PRIMARY KEY (`id`)
);

CREATE TABLE `orders` (
    `id` INT NOT NULL AUTO_INCREMENT UNIQUE,
    `date` DATETIME NOT NULL,
    `customer_id` INT NOT NULL,
    `status` ENUM('delivered', 'received', 'processing') NOT NULL,
    `total_amount` DECIMAL(15,2) NOT NULL CHECK (total_amount > 0),
    `employee_id` INT  NULL,
    `discount_order_id` INT,
    PRIMARY KEY (`id`)
);


CREATE TABLE `reviews` (
    `id` INT NOT NULL AUTO_INCREMENT UNIQUE,
    `customer_id` INT NOT NULL,
    `product_id` INT NOT NULL,
    `rating` SMALLINT CHECK (rating >= 1 AND rating <= 5),
    `content` TEXT,
    `date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE (`product_id`, `customer_id`)  -- Đảm bảo mỗi khách hàng chỉ review 1 sản phẩm 1 lần
);

CREATE TABLE `customers` (
    `id` INT NOT NULL UNIQUE,
    `address` VARCHAR(255),
    `Dob` DATE,
    `loyalty_points` BIGINT DEFAULT 0 CHECK (loyalty_points >= 0),
    PRIMARY KEY (`id`)
) COMMENT 'date of birth';

CREATE TABLE `order_detail` (
    `id` INT NOT NULL AUTO_INCREMENT UNIQUE,
    `order_id` INT NOT NULL,
    `product_id` INT  NULL,
    `quantity` INT NOT NULL CHECK (quantity > 0),
    `unit_price` DECIMAL(10,2) NULL,
    `discount_product_id` INT,
    `subtotal` DECIMAL(15,2),
    PRIMARY KEY (`id`)
);

CREATE TABLE `User` (
    `id` INT NOT NULL AUTO_INCREMENT UNIQUE,
    `username` VARCHAR(30) NOT NULL UNIQUE,
    `password_hashed` VARCHAR(60) NOT NULL,
    `role` ENUM('Customer', 'Employee', 'Admin') NOT NULL,
    `created_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `fullname` VARCHAR(30) NOT NULL,
    `sex` ENUM('Female', 'Male', 'Other') NOT NULL,
    `email` varchar(30) not null,
    PRIMARY KEY (`id`)
);

CREATE TABLE `admin` (
    `id` INT NOT NULL UNIQUE,
    `admin_level` ENUM('super_admin', 'moderator', 'support') NOT NULL,
    `granted_date` DATETIME NOT NULL,
    PRIMARY KEY (`id`)
);

CREATE TABLE `employee` (
    `id` INT NOT NULL UNIQUE,
    `department` ENUM('sales', 'support', 'warehouse', 'IT', 'finance') NOT NULL,
    `internal_id` INT NOT NULL,
    `hire_date` DATETIME NOT NULL,
    PRIMARY KEY (`id`)
);

CREATE TABLE `Wish_list` (
    `id` INT NOT NULL AUTO_INCREMENT UNIQUE,
    `customer_id` INT NOT NULL ,
    `product_id` INT NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE (`product_id`, `customer_id`)  -- Không cho phép thêm trùng sản phẩm vào wish list của 1 user
);

CREATE TABLE `Shopping_cart` (
    `id` INT NOT NULL AUTO_INCREMENT UNIQUE,
    `customer_id` INT NOT NULL,
    `product_id` INT NOT NULL,
    `quantity` INT DEFAULT 1 CHECK (quantity > 0),
    `date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
     UNIQUE (`product_id`, `customer_id`)  -- Một sản phẩm chỉ xuất hiện 1 lần trong giỏ hàng của 1 user
);

CREATE TABLE `Storage` (
    `id` INT NOT NULL AUTO_INCREMENT UNIQUE,
    `city` VARCHAR(255) NOT NULL,
    `capacity` BIGINT NOT NULL CHECK (capacity > 0),
    `manager_id` INT NOT NULL,
    `create_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
);



CREATE TABLE `product_storage` (
    `id` INT NOT NULL AUTO_INCREMENT UNIQUE,
    `product_id` INT NOT NULL,
    `storage_id` INT NOT NULL,
    `inventory` BIGINT NOT NULL CHECK (inventory >= 0),
    PRIMARY KEY (`id`)
);

CREATE TABLE `bill` (
    `id` INT NOT NULL AUTO_INCREMENT UNIQUE,
    `order_id` INT NOT NULL,
    `transaction_id` VARCHAR(255) NOT NULL UNIQUE,
    `create_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `due_date` DATETIME NOT NULL,
    `status` ENUM('pending', 'paid', 'canceled', 'refunded'),
    `payment_method` ENUM('credit_card', 'paypal', 'bank_transfer', 'cash_on_delivery') DEFAULT 'cash_on_delivery',
    `paid_date` TIMESTAMP,
    PRIMARY KEY (`id`)
);

CREATE TABLE `delivery` (
    `id` INT NOT NULL AUTO_INCREMENT UNIQUE,
    `shipping_address` VARCHAR(100) NOT NULL,
    `carrier` ENUM('GHTK', 'J&T Express', 'Ninja Van', 'VNPost', 'Shopee Express') DEFAULT 'GHTK',
    `estimated_date` DATE,
    `delivered_date` DATE,
    `order_id` INT NOT NULL,
    `price_delivery` DECIMAL(10,2) NOT NULL CHECK (price_delivery >= 0),
    `delivery_discount` INT NULL,
    PRIMARY KEY (`id`)
);

CREATE TABLE `discount` (
    `id` INT NOT NULL AUTO_INCREMENT UNIQUE,
    `discount_code` CHAR(10) UNIQUE,
    `min_value_apply` DECIMAL(10,2) CHECK (min_value_apply >= 0),
    `max_discount` DECIMAL(10,2) CHECK (max_discount >= 0),
    `type_discount` ENUM('Discount on order', 'Discount on delivery', 'Discount on categories'),
    `start_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `end_date` TIMESTAMP NOT NULL,
    `usagecount` BIGINT NOT NULL,
    `category_id` INT,
    `usagelimit` INT NOT NULL,
    `isActive` BOOLEAN NOT NULL,
    PRIMARY KEY (`id`)
);
use quanlybanhangtructuyen;
ALTER TABLE `products`
ADD FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE `reviews`
ADD FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON UPDATE CASCADE ON DELETE CASCADE,
ADD FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE `orders`
ADD FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT, -- Sửa: Không cho xóa khách hàng khi có đơn hàng
ADD FOREIGN KEY (`employee_id`) REFERENCES `employee` (`id`) ON UPDATE CASCADE ON DELETE SET NULL, -- Giữ đề xuất trước: Cho phép xóa nhân viên, đặt NULL
ADD FOREIGN KEY (`discount_order_id`) REFERENCES `discount` (`id`) ON UPDATE SET NULL ON DELETE SET NULL;

ALTER TABLE `order_detail`
ADD FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON UPDATE CASCADE ON DELETE CASCADE,
ADD FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON UPDATE SET NULL ON DELETE SET NULL,
ADD FOREIGN KEY (`discount_product_id`) REFERENCES `discount` (`id`) ON UPDATE SET NULL ON DELETE SET NULL;

ALTER TABLE `customers`
ADD FOREIGN KEY (`id`) REFERENCES `User` (`id`) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE `admin`
ADD FOREIGN KEY (`id`) REFERENCES `User` (`id`) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE `employee`
ADD FOREIGN KEY (`id`) REFERENCES `User` (`id`) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE `Wish_list`
ADD FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON UPDATE CASCADE ON DELETE CASCADE,
ADD FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE `Shopping_cart`
ADD FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON UPDATE CASCADE ON DELETE CASCADE,
ADD FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE `product_storage`
ADD FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON UPDATE CASCADE ON DELETE CASCADE,
ADD FOREIGN KEY (`storage_id`) REFERENCES `Storage` (`id`) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE `bill`
ADD FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE `delivery`
ADD FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON UPDATE CASCADE ON DELETE CASCADE,
ADD FOREIGN KEY (`delivery_discount`) REFERENCES `discount` (`id`) ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE `discount`
ADD FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE `Storage`
ADD FOREIGN KEY (`manager_id`) REFERENCES `employee` (`id`) ON UPDATE NO ACTION ON DELETE RESTRICT; 
INSERT INTO User (id, username, password_hashed, role, fullname, sex) VALUES

INSERT INTO categories (id, name) VALUES 
(1, 'Điện thoại'),
(2, 'Laptop'),
(3, 'Phụ kiện');

-- Thêm sản phẩm
INSERT INTO products (id, name, description, price, category_id, detail) VALUES
(1, 'iPhone 15 Pro', 'Điện thoại cao cấp', 999.99, 1, '{"color": "Black", "storage": "256GB"}'),
(2, 'MacBook Pro', 'Laptop đồ họa', 1999.99, 2, '{"ram": "16GB", "storage": "512GB"}'),
(3, 'AirPods Pro', 'Tai nghe không dây', 249.99, 3, '{"color": "White"}');
-- Thêm người dùng và khách hàng
INSERT INTO User (id, username, password_hashed, role, fullname, sex) VALUES
(1, 'user1', '$2a$10$somehashedpassword', 'Customer', 'Nguyễn Văn A', 'Male'),
(2, 'user2', '$2a$10$somehashedpassword', 'Customer', 'Trần Thị B', 'Female'),
(3, 'admin1', '$2a$10$somehashedpassword', 'Admin', 'Admin User', 'Male'),
(4, 'employee1', '$2a$10$somehashedpassword', 'Employee', 'Nhân viên C', 'Male');
INSERT INTO customers (id, address, Dob, loyalty_points) VALUES
(1, 'Hà Nội', '1990-01-15', 100),
(2, 'TP.HCM', '1995-05-20', 50);

-- Thêm nhân viên
INSERT INTO employee (id, department, internal_id, hire_date) VALUES
(4, 'sales', 1001, '2023-01-01 00:00:00');

-- Thêm kho hàng
INSERT INTO Storage (id, city, capacity, manager_id) VALUES
(1, 'Hà Nội', 10000, 4),
(2, 'TP.HCM', 15000, 4);

-- Thêm tồn kho
INSERT INTO product_storage (id, product_id, storage_id, inventory) VALUES
(1, 1, 1, 100),  -- iPhone tại kho Hà Nội
(2, 1, 2, 150),  -- iPhone tại kho TP.HCM
(3, 2, 1, 50),   -- MacBook tại kho Hà Nội
(4, 2, 2, 75),   -- MacBook tại kho TP.HCM
(5, 3, 1, 200),  -- AirPods tại kho Hà Nội
(6, 3, 2, 250);  -- AirPods tại kho TP.HCM

-- Thêm mã giảm giá
INSERT INTO discount (id, discount_code, min_value_apply, max_discount, type_discount, 
                     start_date, end_date, usagecount, usagelimit, isActive) VALUES
(1, 'ORDER10', 100.00, 50.00, 'Discount on order', 
   CURRENT_TIMESTAMP, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 30 DAY), 0, 100, TRUE),
(2, 'SHIP20', 0.00, 20.00, 'Discount on delivery', 
   CURRENT_TIMESTAMP, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 30 DAY), 0, 100, TRUE),
(3, 'PHONE15', 500.00, 150.00, 'Discount on categories', 
   CURRENT_TIMESTAMP, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 30 DAY), 0, 100, TRUE);

UPDATE discount SET category_id = 1 WHERE id = 3;


-- Thêm dữ liệu test trigger update trạng thái đơn hàng
-- Đầu tiên tạo một vài đơn hàng mẫu để test
INSERT INTO `orders` (`id`, `date`, `customer_id`, `status`, `total_amount`, `employee_id`, `discount_order_id`) VALUES
(1001, NOW(), 6, 'processing', 500000.00, null, NULL),
(1002, NOW(), 6, 'processing', 750000.00, null, NULL),
(1003, NOW(), 6, 'processing', 1200000.00, null, NULL),
(1004, NOW(), 6, 'processing', 300000.00, null, NULL);

-- Tạo dữ liệu bill với các trạng thái khác nhau
INSERT INTO `bill` (`id`, `order_id`, `transaction_id`, `create_date`, `due_date`, `status`, `payment_method`, `paid_date`) VALUES
(2001, 1001, 'TXN-2001-A', CURRENT_TIMESTAMP, DATE_ADD(CURRENT_DATE, INTERVAL 7 DAY), 'paid', 'credit_card', CURRENT_TIMESTAMP),
(2002, 1002, 'TXN-2002-B', CURRENT_TIMESTAMP, DATE_ADD(CURRENT_DATE, INTERVAL 7 DAY), 'pending', 'bank_transfer', NULL),
(2003, 1003, 'TXN-2003-C', CURRENT_TIMESTAMP, DATE_ADD(CURRENT_DATE, INTERVAL 7 DAY), 'paid', 'paypal', CURRENT_TIMESTAMP),
(2004, 1004, 'TXN-2004-D', CURRENT_TIMESTAMP, DATE_ADD(CURRENT_DATE, INTERVAL 7 DAY), 'canceled', 'cash_on_delivery', NULL);

-- Tạo dữ liệu delivery với các trạng thái khác nhau
INSERT INTO `delivery` (`id`, `shipping_address`, `carrier`, `estimated_date`, `delivered_date`, `order_id`, `price_delivery`, `delivery_discount`) VALUES
(3001, '123 Lê Lợi, Quận 1, TP.HCM', 'GHTK', DATE_ADD(CURRENT_DATE, INTERVAL 3 DAY), CURRENT_DATE, 1001, 25000.00, NULL),
(3002, '456 Nguyễn Huệ, Quận 3, TP.HCM', 'J&T Express', DATE_ADD(CURRENT_DATE, INTERVAL 2 DAY), NULL, 1002, 30000.00, NULL),
(3003, '789 Lê Duẩn, Quận 1, TP.HCM', 'VNPost', DATE_ADD(CURRENT_DATE, INTERVAL 5 DAY), CURRENT_DATE, 1003, 35000.00, NULL),
(3004, '101 Võ Văn Tần, Quận 3, TP.HCM', 'Ninja Van', DATE_ADD(CURRENT_DATE, INTERVAL 4 DAY), NULL, 1004, 28000.00, NULL);
