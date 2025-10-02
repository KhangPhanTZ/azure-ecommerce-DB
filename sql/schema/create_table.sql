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
    `total_amount` DECIMAL(15,2) default 0,
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
    'email' varchar(30) not null
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