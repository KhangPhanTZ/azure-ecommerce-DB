use quanlybanhangtructuyen;
-- =============================================
-- 3. STORED PROCEDURES
-- =============================================
-- Thủ tục đăng nhập
DELIMITER //

CREATE PROCEDURE sp_login(
    IN p_username_or_email VARCHAR(255),
    IN p_password VARCHAR(255),
    IN p_role VARCHAR(50),
    OUT p_user_id INT,
    OUT p_email VARCHAR(255),
    OUT p_fullname VARCHAR(255),
    OUT p_sex VARCHAR(10),
--     OUT p_role VARCHAR(50),
    OUT p_extra_info JSON
)
BEGIN
    DECLARE v_role VARCHAR(50);
    DECLARE v_user_id INT;
    DECLARE v_email VARCHAR(255);
    DECLARE v_fullname VARCHAR(255);
    DECLARE v_sex VARCHAR(10);

    -- Kiểm tra user với username hoặc email và password
    SELECT id, email, fullname, sex, role
    INTO v_user_id, v_email, v_fullname, v_sex, v_role
    FROM user
    WHERE (username = p_username_or_email OR email = p_username_or_email)
    AND password_hashed = p_password
    LIMIT 1;

    -- Nếu không tìm thấy user
    IF v_user_id IS NULL THEN
        SET p_user_id = NULL;
        SET p_extra_info = JSON_OBJECT('error', 'Invalid credentials');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid username/email or password';
    END IF;

    -- Kiểm tra vai trò
    SET p_role = LOWER(v_role);
    IF p_role != LOWER(p_role) THEN
        SET p_extra_info = JSON_OBJECT('warning', CONCAT('Role mismatch: requested ', p_role, ', actual ', v_role));
        SET p_role = v_role;
    END IF;

    -- Lấy thông tin bổ sung dựa trên vai trò
    SET p_user_id = v_user_id;
    SET p_email = v_email;
    SET p_fullname = v_fullname;
    SET p_sex = v_sex;

    IF p_role = 'customer' THEN
        SELECT JSON_OBJECT('dob', dob, 'address', address)
        INTO p_extra_info
        FROM customers
        WHERE id = v_user_id;
    ELSEIF p_role = 'employee' THEN
        SELECT JSON_OBJECT('department', department, 'internal_id', internal_id)
        INTO p_extra_info
        FROM employee
        WHERE id = v_user_id;
    ELSEIF p_role = 'admin' THEN
        SELECT JSON_OBJECT('admin_level', admin_level)
        INTO p_extra_info
        FROM admin
        WHERE id = v_user_id;
    ELSE
        SET p_extra_info = JSON_OBJECT('message', 'No additional info for this role');
    END IF;

END //

DELIMITER ;

-- Procedure thêm sản phẩm vào giỏ hàng
DELIMITER $$
CREATE PROCEDURE add_to_cart(
    IN p_customer_id INT,
    IN p_product_id INT,
    IN p_quantity INT
)
BEGIN
    DECLARE existing_quantity INT DEFAULT 0;
    
    -- Kiểm tra sản phẩm đã có trong giỏ hàng chưa
    SELECT COALESCE(quantity, 0) INTO existing_quantity
    FROM Shopping_cart
    WHERE customer_id = p_customer_id AND product_id = p_product_id;
    
    -- Nếu sản phẩm đã có trong giỏ hàng
    IF existing_quantity > 0 THEN
        -- Cập nhật số lượng
        UPDATE Shopping_cart
        SET quantity = existing_quantity + p_quantity
        WHERE customer_id = p_customer_id AND product_id = p_product_id;
    ELSE
        -- Thêm sản phẩm mới vào giỏ hàng
        INSERT INTO Shopping_cart (customer_id, product_id, quantity)
        VALUES (p_customer_id, p_product_id, p_quantity);
    END IF;
END$$
DELIMITER ;

-- Lấy giỏ hàng
DELIMITER $$

CREATE PROCEDURE get_cart(
    IN customer_id_param INT,
    OUT list_item JSON
)
BEGIN
    SELECT JSON_ARRAYAGG(
        JSON_OBJECT(
            'product_id', p.id,
            'name', p.name,
            'price', p.price,
            'quantity', c.quantity,
            'total', p.price * c.quantity
        )
    )
    INTO list_item
    FROM shopping_cart c
    JOIN products p ON c.product_id = p.id
    WHERE c.customer_id = customer_id_param;
END$$


DELIMITER ;
-- Lấy các sản phâm cho giỏ hàng tạm trên tầng cache
DELIMITER $$

CREATE PROCEDURE Make_product_for_temp_cart(
    IN product_id_param INT,
    IN quantity_param INT,
    OUT list_items JSON
)
BEGIN
    DECLARE available_inventory INT DEFAULT 0;

    -- Lấy tồn kho hiện tại
    SELECT ps.inventory
    INTO available_inventory
    FROM product_storage ps
    WHERE ps.product_id = product_id_param;

    -- Kiểm tra tồn kho
    IF available_inventory IS NULL THEN
        -- Nếu không tìm thấy sản phẩm
        SET list_items = JSON_OBJECT('error', 'Product not found');
    ELSEIF quantity_param > available_inventory THEN
        -- Nếu số lượng yêu cầu > tồn kho
        SET list_items = JSON_OBJECT('error', 'Not enough inventory');
    ELSE
        -- Nếu tồn kho đủ, trả về thông tin sản phẩm
        SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'product_id', p.id,
                'name', p.name,
                'price', p.price,
                'quantity', quantity_param,
                'total', p.price * quantity_param
            )
        )
        INTO list_items
        FROM products p
        JOIN product_storage ps ON p.id = ps.product_id
        WHERE p.id = product_id_param;
    END IF;
END$$

DELIMITER ;


-- Procedure thanh toán đơn hàng
DELIMITER $$
CREATE PROCEDURE complete_payment(
    IN p_order_id INT,
    OUT p_error_message VARCHAR(255)
)
BEGIN
    DECLARE v_bill_id INT;
    DECLARE v_bill_status VARCHAR(50);

    proc: BEGIN
        -- Kiểm tra đơn hàng tồn tại
        SELECT id, status INTO v_bill_id, v_bill_status
        FROM bill
        WHERE order_id = p_order_id;

        IF v_bill_id IS NULL THEN
            SET p_error_message = 'Không tìm thấy hóa đơn cho đơn hàng này';
            LEAVE proc;
        END IF;

        -- Kiểm tra trạng thái hóa đơn
        IF v_bill_status = 'paid' THEN
            SET p_error_message = 'Hóa đơn đã được thanh toán trước đó';
            LEAVE proc;
        END IF;

        IF v_bill_status = 'canceled' OR v_bill_status = 'refunded' THEN
            SET p_error_message = 'Không thể thanh toán hóa đơn đã bị hủy hoặc hoàn tiền';
            LEAVE proc;
        END IF;

        -- Cập nhật trạng thái thanh toán
        UPDATE bill
        SET status = 'paid', paid_date = NOW()
        WHERE order_id = p_order_id;

        -- Cập nhật trạng thái đơn hàng
        UPDATE orders
        SET status = 'received'
        WHERE id = p_order_id;

        SET p_error_message = NULL;
    END proc;
END;

DELIMITER ;
-- Thủ tục tạo tạo user
DELIMITER //

CREATE PROCEDURE CreateUser(
    IN p_username VARCHAR(30),
    IN p_password VARCHAR(60),
    IN p_role ENUM('Customer', 'Employee', 'Admin'),
    IN p_fullname VARCHAR(30),
    IN p_sex ENUM('Female', 'Male', 'Other'),
    IN p_email VARCHAR(30),
    -- Thông tin cho khách hàng
    IN p_address VARCHAR(255),
    IN p_dob DATE,
    -- Thông tin cho nhân viên
    IN p_department ENUM('sales', 'support', 'warehouse', 'IT', 'finance'),
    IN p_internal_id INT,
    IN p_hire_date DATETIME,
    -- Thông tin cho admin
    IN p_admin_level ENUM('super_admin', 'moderator', 'support'),
    IN p_granted_date DATETIME
)
BEGIN
    DECLARE new_user_id INT;
    DECLARE error_message VARCHAR(255);
    DECLARE username_exists INT DEFAULT 0;
    -- Kiểm tra thông tin chung bắt buộc
    IF p_username IS NULL OR p_username = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Username không được để trống';
    END IF;
    
    IF p_password IS NULL OR p_password = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Password không được để trống';
    END IF;
    
    IF p_fullname IS NULL OR p_fullname = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Họ tên không được để trống';
    END IF;
    
    IF p_email IS NULL OR p_email = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Email không được để trống';
    END IF;
    
    -- Kiểm tra xem username đã tồn tại chưa
    SELECT COUNT(*) INTO username_exists FROM `User` WHERE username = p_username;
    
    IF username_exists > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Username đã tồn tại trong hệ thống';
    END IF;
    
    -- Kiểm tra thông tin bắt buộc cho từng role
    CASE p_role
        WHEN 'Customer' THEN
            -- Kiểm tra thông tin bắt buộc cho khách hàng
            IF p_dob IS NULL THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ngày sinh là bắt buộc đối với khách hàng';
            END IF;
            
        WHEN 'Employee' THEN
            -- Kiểm tra thông tin bắt buộc cho nhân viên
            IF p_department IS NULL THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Phòng ban là bắt buộc đối với nhân viên';
            END IF;
            
            IF p_internal_id IS NULL THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Mã nội bộ là bắt buộc đối với nhân viên';
            END IF;
            
            IF p_hire_date IS NULL THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ngày tuyển dụng là bắt buộc đối với nhân viên';
            END IF;
            
        WHEN 'Admin' THEN
            -- Kiểm tra thông tin bắt buộc cho admin
            IF p_admin_level IS NULL THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cấp độ admin là bắt buộc';
            END IF;
            
            IF p_granted_date IS NULL THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ngày cấp quyền là bắt buộc đối với admin';
            END IF;
            
        ELSE
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Role không hợp lệ';
    END CASE;
    
    -- Bắt đầu transaction
    START TRANSACTION;
    
    BEGIN
        -- Sử dụng handler để bắt lỗi SQL
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            -- Rollback nếu có lỗi
            ROLLBACK;
            -- Chuyển tiếp lỗi
            RESIGNAL;
        END;
        
        -- Thêm thông tin vào bảng User
        INSERT INTO `User` (username, password_hashed, role, fullname, sex, email)
        VALUES (p_username, p_password, p_role, p_fullname, p_sex, p_email);
        
        -- Lấy ID của user vừa thêm
        SET new_user_id = LAST_INSERT_ID();
        
        -- Thêm thông tin vào bảng con tương ứng dựa vào role
        CASE p_role
            WHEN 'Customer' THEN
                INSERT INTO customers (id, address, Dob, loyalty_points)
                VALUES (new_user_id, p_address, p_dob, 0);
                
            WHEN 'Employee' THEN
                INSERT INTO employee (id, department, internal_id, hire_date)
                VALUES (new_user_id, p_department, p_internal_id, p_hire_date);
                
            WHEN 'Admin' THEN
                INSERT INTO admin (id, admin_level, granted_date)
                VALUES (new_user_id, p_admin_level, p_granted_date);
        END CASE;
    END;
    
    -- Hoàn thành transaction
    COMMIT;
    
    -- Trả về ID của user mới
    SELECT new_user_id AS 'New User ID', 
           CONCAT('Tạo người dùng ', p_role, ' thành công') AS 'Status Message';
END //

DELIMITER ;
-- Thủ tục mua nhiều sản phẩm
DELIMITER //

CREATE PROCEDURE CreateOrder(
    IN p_customer_id INT,
    IN p_employee_id INT,
    IN p_status ENUM('delivered', 'received', 'processing'),
    IN p_discount_order_id INT,
    IN p_products JSON
)
BEGIN
    DECLARE new_order_id INT;
    DECLARE product_count INT;
    DECLARE i INT DEFAULT 0;
    DECLARE product_id INT;
    DECLARE quantity INT;
    DECLARE discount_product_id INT;

    -- Bắt lỗi và rollback nếu có lỗi
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
      ROLLBACK;
      GET DIAGNOSTICS CONDITION 1
        @p1 = RETURNED_SQLSTATE, 
        @p2 = MESSAGE_TEXT;
    SELECT CONCAT('SQLSTATE: ', @p1, ' - Lỗi: ', @p2) AS detailed_error;
    END;

    START TRANSACTION;

    -- 1. Thêm đơn hàng
    INSERT INTO orders (`date`,customer_id, status)
    VALUES (Now(),p_customer_id, p_status);

    SET new_order_id = LAST_INSERT_ID();

    -- 2. Xử lý từng sản phẩm
    SET product_count = JSON_LENGTH(p_products);

    WHILE i < product_count DO
        SET product_id = JSON_UNQUOTE(JSON_EXTRACT(p_products, CONCAT('$[', i, '].product_id')));
        SET quantity = JSON_UNQUOTE(JSON_EXTRACT(p_products, CONCAT('$[', i, '].quantity')));

        INSERT INTO order_detail (order_id, product_id, quantity)
        VALUES (new_order_id, product_id, quantity);

        SET i = i + 1;
    END WHILE;

    COMMIT;

    -- Trả về id đơn hàng vừa tạo
    SELECT new_order_id AS order_id;
END //

DELIMITER ;
