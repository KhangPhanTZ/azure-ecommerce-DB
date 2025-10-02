-- =============================================
-- 2. TRIGGERS
-- =============================================

-- Trigger cập nhật price trong bảng order_detail
DELIMITER $$
CREATE TRIGGER update_order_detail_price
BEFORE INSERT ON order_detail
FOR EACH ROW
BEGIN 
    DECLARE price_product DECIMAL(10,2);
    
    -- Lấy giá sản phẩm từ bảng products
    SELECT price INTO price_product 
    FROM products 
    WHERE id = NEW.product_id;
    
    -- Cập nhật unit_price trong bản ghi mới
    SET NEW.unit_price = price_product;
END$$

DELIMITER ;
-- Trigger cập nhật subtotal trong bảng order_detail
DELIMITER $$
CREATE TRIGGER update_order_detail_subtotal 
BEFORE INSERT ON order_detail
FOR EACH ROW
BEGIN
    DECLARE discount_amount DECIMAL(10,2);
    
    -- Tính giảm giá cho sản phẩm (nếu có)
    SET discount_amount = calculate_product_discount(NEW.product_id, NEW.unit_price, NEW.discount_product_id, new.quantity);
    
    -- Tính subtotal = (đơn giá - giảm giá) * số lượng
    SET NEW.subtotal = NEW.unit_price* NEW.quantity - discount_amount ;
END$$
DELIMITER ;

-- Trigger cập nhật tổng tiền trong bảng orders khi thêm order_detail
DELIMITER $$
CREATE TRIGGER update_order_total_after_insert
AFTER INSERT ON order_detail
FOR EACH ROW
BEGIN
    DECLARE total DECIMAL(15,2);
    DECLARE discount_amount DECIMAL(15,2);
    DECLARE discount_id INT;
    
    -- Tính tổng tiền của đơn hàng
    SELECT COALESCE(SUM(subtotal), 0) INTO total
    FROM order_detail
    WHERE order_id = NEW.order_id;
    
    -- Lấy mã giảm giá của đơn hàng
    SELECT discount_order_id INTO discount_id
    FROM orders
    WHERE id = NEW.order_id;
    
    -- Tính giảm giá cho đơn hàng
    SET discount_amount = calculate_order_discount(total, discount_id);
    
    -- Cập nhật tổng tiền đơn hàng trừ đi giảm giá
    UPDATE orders
    SET total_amount = total - discount_amount
    WHERE id = NEW.order_id;
END$$
DELIMITER ;

-- Trigger cập nhật tổng tiền trong bảng orders khi cập nhật order_detail
DELIMITER $$
CREATE TRIGGER update_order_total_after_update
AFTER UPDATE ON order_detail
FOR EACH ROW
BEGIN
    DECLARE total DECIMAL(15,2);
    DECLARE discount_amount DECIMAL(15,2);
    DECLARE discount_id INT;
    
    -- Tính tổng tiền của đơn hàng
    SELECT COALESCE(SUM(subtotal), 0) INTO total
    FROM order_detail
    WHERE order_id = NEW.order_id;
    
    -- Lấy mã giảm giá của đơn hàng
    SELECT discount_order_id INTO discount_id
    FROM orders
    WHERE id = NEW.order_id;
    
    -- Tính giảm giá cho đơn hàng
    SET discount_amount = calculate_order_discount(total, discount_id);
    
    -- Cập nhật tổng tiền đơn hàng trừ đi giảm giá
    UPDATE orders
    SET total_amount = total - discount_amount
    WHERE id = NEW.order_id;
END$$
DELIMITER ;

-- Trigger cập nhật tổng tiền trong bảng orders khi xóa order_detail
DELIMITER $$
CREATE TRIGGER update_order_total_after_delete
AFTER DELETE ON order_detail
FOR EACH ROW
BEGIN
    DECLARE total DECIMAL(15,2);
    DECLARE discount_amount DECIMAL(15,2);
    DECLARE discount_id INT;
    
    -- Tính tổng tiền của đơn hàng
    SELECT COALESCE(SUM(subtotal), 0) INTO total
    FROM order_detail
    WHERE order_id = OLD.order_id;
    
    -- Lấy mã giảm giá của đơn hàng
    SELECT discount_order_id INTO discount_id
    FROM orders
    WHERE id = OLD.order_id;
    
    -- Tính giảm giá cho đơn hàng
    SET discount_amount = calculate_order_discount(total, discount_id);
    
    -- Cập nhật tổng tiền đơn hàng trừ đi giảm giá
    UPDATE orders
    SET total_amount = total - discount_amount
    WHERE id = OLD.order_id;
END$$
DELIMITER ;

-- Trigger cập nhật số lượng sử dụng mã giảm giá
DELIMITER $$
CREATE TRIGGER update_discount_usage
AFTER INSERT ON orders
FOR EACH ROW
BEGIN
    -- Cập nhật số lượng sử dụng khi mã giảm giá được áp dụng cho đơn hàng
    IF NEW.discount_order_id IS NOT NULL THEN
        UPDATE discount
        SET usagecount = usagecount + 1
        WHERE id = NEW.discount_order_id;
    END IF;
END$$
DELIMITER ;

-- Trigger cập nhật sử dụng mã giảm giá khi delivery được tạo
DELIMITER $$
CREATE TRIGGER update_delivery_discount_usage
AFTER INSERT ON delivery
FOR EACH ROW
BEGIN
    -- Cập nhật số lượng sử dụng khi mã giảm giá được áp dụng cho vận chuyển
    IF NEW.delivery_discount IS NOT NULL THEN
        UPDATE discount
        SET usagecount = usagecount + 1
        WHERE id = NEW.delivery_discount;
    END IF;
END$$
DELIMITER ;

-- Trigger cập nhật tồn kho sau khi tạo đơn hàng
DELIMITER $$
CREATE TRIGGER update_inventory_after_order
AFTER INSERT ON order_detail
FOR EACH ROW
BEGIN
    DECLARE storage_id_val INT;
    DECLARE remaining_quantity INT;
    DECLARE current_storage_inventory INT;
    
    -- Set biến để lưu số lượng cần trừ
    SET remaining_quantity = NEW.quantity;
    
    -- Duyệt qua các kho và trừ số lượng tồn kho
    -- (Bắt đầu từ kho có lượng tồn nhiều nhất)
    product_storage_loop: LOOP
        -- Lấy kho có số lượng tồn nhiều nhất cho sản phẩm
        SELECT id, inventory INTO storage_id_val, current_storage_inventory
        FROM product_storage
        WHERE product_id = NEW.product_id AND inventory > 0
        ORDER BY inventory DESC
        LIMIT 1;
        
        -- Nếu không còn kho nào hoặc đã trừ đủ số lượng, thoát loop
        IF storage_id_val IS NULL OR remaining_quantity <= 0 THEN
            LEAVE product_storage_loop;
        END IF;
        
        -- Nếu kho hiện tại có đủ số lượng
        IF current_storage_inventory >= remaining_quantity THEN
            -- Cập nhật số lượng tồn kho
            UPDATE product_storage
            SET inventory = inventory - remaining_quantity
            WHERE id = storage_id_val;
            
            -- Đã trừ xong, set remaining_quantity = 0
            SET remaining_quantity = 0;
        ELSE
            -- Cập nhật số lượng tồn kho về 0
            UPDATE product_storage
            SET inventory = 0
            WHERE id = storage_id_val;
            
            -- Cập nhật số lượng còn cần trừ
            SET remaining_quantity = remaining_quantity - current_storage_inventory;
        END IF;
        
        -- Reset biến để loop tiếp
        SET storage_id_val = NULL;
    END LOOP;
END$$
DELIMITER ;


DELIMITER //

CREATE TRIGGER before_review_insert
BEFORE INSERT ON `reviews`
FOR EACH ROW
BEGIN
    DECLARE has_purchased INT DEFAULT 0;
    
    -- Kiểm tra xem khách hàng đã mua sản phẩm này chưa
    -- Tìm trong bảng orders và order_detail
    SELECT COUNT(*) INTO has_purchased
    FROM `orders` o
    JOIN `order_detail` od ON o.id = od.order_id
    WHERE o.customer_id = NEW.customer_id 
    AND od.product_id = NEW.product_id
    AND o.status IN ('delivered', 'received'); -- Chỉ tính đơn hàng đã giao hoặc đã nhận
    
    -- Nếu khách hàng chưa mua sản phẩm này, không cho phép thêm review
    IF has_purchased = 0 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Không thể thêm review. Khách hàng chưa mua sản phẩm này.';
    END IF;
END //

DELIMITER ;

-- Trigger kiểm tra update trạng thái đơn hàng
DELIMITER //

CREATE TRIGGER before_order_status_update
BEFORE UPDATE ON `orders`
FOR EACH ROW
BEGIN
    -- KHAI BÁO BIẾN PHẢI Ở ĐÂU PHẦN BEGIN
    DECLARE bill_status VARCHAR(20);
    DECLARE delivery_status VARCHAR(20);
    DECLARE bill_exists INT DEFAULT 0;
    DECLARE delivery_exists INT DEFAULT 0;

    -- Chỉ kiểm tra khi trạng thái đơn hàng thay đổi thành 'delivered' hoặc 'received'
    IF (NEW.status = 'delivered' OR NEW.status = 'received') AND (OLD.status != NEW.status) THEN

        -- Kiểm tra hóa đơn
        SELECT COUNT(*) INTO bill_exists
        FROM `bill`
        WHERE order_id = NEW.id;

        IF bill_exists > 0 THEN
            SELECT status INTO bill_status
            FROM `bill`
            WHERE order_id = NEW.id
            LIMIT 1;
        END IF;

        -- Kiểm tra giao hàng
        SELECT COUNT(*) INTO delivery_exists
        FROM `delivery`
        WHERE order_id = NEW.id;

        IF delivery_exists > 0 THEN
            SELECT CASE 
                     WHEN delivered_date IS NOT NULL THEN 'delivered' 
                     ELSE 'pending' 
                   END INTO delivery_status
            FROM `delivery`
            WHERE order_id = NEW.id
            LIMIT 1;
        END IF;

        -- Kiểm tra điều kiện
        IF bill_exists = 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không thể cập nhật trạng thái đơn hàng vì không tìm thấy hóa đơn liên quan.';
        ELSEIF delivery_exists = 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không thể cập nhật trạng thái đơn hàng vì không tìm thấy thông tin giao hàng.';
        ELSEIF bill_status != 'paid' THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không thể cập nhật trạng thái đơn hàng vì hóa đơn chưa được thanh toán.';
        ELSEIF delivery_status != 'delivered' THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không thể cập nhật trạng thái đơn hàng vì đơn hàng chưa được giao.';
        END IF;
    END IF;
END //

DELIMITER ;
