use quanlybanhangtructuyen;
-- Tạo constraint unique cho các bảng không sử dụng composite key
ALTER TABLE reviews 
ADD CONSTRAINT constraint_name UNIQUE (customer_id, product_id);

ALTER TABLE order_detail 
ADD CONSTRAINT constraint_unique UNIQUE (order_id,product_id);

ALTER TABLE shopping_cart 
ADD CONSTRAINT constraint_unique UNIQUE (product_id, customer_id);

ALTER TABLE product_storage 
ADD CONSTRAINT constraint_name UNIQUE (product_id, storage_id);

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