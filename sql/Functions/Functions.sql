-- =============================================
-- 1. FUNCTIONS
-- =============================================
-- Function kiểm tra tồn kho sản phẩm
DELIMITER $$
CREATE FUNCTION check_product_inventory(product_id_param INT, quantity_param INT) 
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    DECLARE total_inventory INT DEFAULT 0;
    
    -- Tính tổng số lượng tồn kho của sản phẩm từ tất cả các kho
    SELECT COALESCE(SUM(inventory), 0) INTO total_inventory
    FROM product_storage
    WHERE product_id = product_id_param;
    
    -- Trả về TRUE nếu tồn kho đủ, FALSE nếu không đủ
    RETURN (total_inventory >= quantity_param);
END$$
DELIMITER ;


-- Function tính giá trị giảm giá cho một sản phẩm
DELIMITER $$
CREATE FUNCTION calculate_product_discount(product_id_param INT, price_param DECIMAL(10,2), discount_id_param INT,quantity_param int) 
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE discount_amount DECIMAL(10,2) DEFAULT 0;
    DECLARE product_category INT;
    DECLARE discount_type ENUM('Discount on order', 'Discount on delivery', 'Discount on categories');
    DECLARE discount_category INT;
    DECLARE max_discount_value DECIMAL(10,2);
    declare min_discount_value Decimal(10,2);
    -- Nếu không có mã giảm giá, trả về 0
    IF discount_id_param IS NULL THEN
        RETURN 0;
    END IF;
    
    -- Lấy thông tin sản phẩm và mã giảm giá
    SELECT category_id INTO product_category FROM products WHERE id = product_id_param;
    
    SELECT type_discount, category_id, max_discount, min_value_apply 
    INTO discount_type, discount_category, max_discount_value, min_discount_value
    FROM discount 
    WHERE id = discount_id_param AND isActive = TRUE 
      AND CURRENT_TIMESTAMP BETWEEN start_date AND end_date
      AND usagecount < usagelimit;
    
    -- Kiểm tra loại giảm giá và trả về max_discount
    IF discount_type = 'Discount on categories' AND discount_category = product_category and min_discount_value  <= quantity_param*price_param THEN
        SET discount_amount = max_discount_value;
    END IF;
    
    RETURN discount_amount;
END$$
DELIMITER ;


-- Function tính giá trị giảm giá cho đơn hàng - sử dụng max_discount
DELIMITER $$
CREATE FUNCTION calculate_order_discount(total_param DECIMAL(15,2), discount_id_param INT) 
RETURNS DECIMAL(15,2)
DETERMINISTIC
BEGIN
    DECLARE discount_amount DECIMAL(15,2) DEFAULT 0;
    DECLARE discount_type ENUM('Discount on order', 'Discount on delivery', 'Discount on categories');
    DECLARE min_value DECIMAL(10,2);
    DECLARE max_discount_value DECIMAL(10,2);
    
    -- Nếu không có mã giảm giá, trả về 0
    IF discount_id_param IS NULL THEN
        RETURN 0;
    END IF;
    
    -- Lấy thông tin mã giảm giá
    SELECT type_discount, min_value_apply, max_discount 
    INTO discount_type, min_value, max_discount_value
    FROM discount 
    WHERE id = discount_id_param AND isActive = TRUE 
      AND CURRENT_TIMESTAMP BETWEEN start_date AND end_date
      AND usagecount < usagelimit;
    
    -- Kiểm tra loại giảm giá và giá trị đơn hàng tối thiểu
    IF discount_type = 'Discount on order' AND total_param >= min_value THEN
        -- Trả về trực tiếp giá trị max_discount
        SET discount_amount = max_discount_value;
    END IF;
    
    RETURN discount_amount;
END$$
DELIMITER ;

-- Function tính giá trị giảm giá cho phí vận chuyển - sử dụng max_discount
DELIMITER $$
CREATE FUNCTION calculate_delivery_discount(price_delivery_param DECIMAL(10,2), discount_id_param INT) 
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE discount_amount DECIMAL(10,2) DEFAULT 0;
    DECLARE discount_type ENUM('Discount on order', 'Discount on delivery', 'Discount on categories');
    DECLARE max_discount_value DECIMAL(10,2);
    DECLARE min_discount_value DECIMAL(10,2);
    -- Nếu không có mã giảm giá, trả về 0
    IF discount_id_param IS NULL THEN
        RETURN 0;
    END IF;
    
    -- Lấy thông tin mã giảm giá
    SELECT type_discount, max_discount,min_value_apply  
    INTO discount_type, max_discount_value, min_discount_value
    FROM discount 
    WHERE id = discount_id_param AND isActive = TRUE 
      AND CURRENT_TIMESTAMP BETWEEN start_date AND end_date
      AND usagecount < usagelimit;
    
    -- Kiểm tra loại giảm giá
    IF discount_type = 'Discount on delivery' and min_discount_value <= price_delivery_param THEN
        -- Trả về trực tiếp giá trị max_discount
        SET discount_amount = max_discount_value;
    END IF;
    
    RETURN discount_amount;
END$$
DELIMITER ;
drop function if exists calculate_delivery_discount;

-- Function tính điểm tích lũy từ đơn hàng
DELIMITER $$
CREATE FUNCTION calculate_loyalty_points(total_amount_param DECIMAL(15,2)) 
RETURNS INT
DETERMINISTIC
BEGIN
    -- Tính điểm tích lũy (ví dụ: cứ 10.000 VND = 1 điểm)
    RETURN FLOOR(total_amount_param / 10000);
END$$
DELIMITER ;
