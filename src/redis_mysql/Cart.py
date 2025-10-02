import json
from dotenv import load_dotenv
import logging
from datetime import datetime
from decimal import Decimal
from Remaining_login import login, get_user_from_token, logout
from connect_close_db import redis_client, mysql_conn, mysql_cursor, close_connections

# Thiết lập logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Hằng số
SESSION_TTL = 180  # 3 phút

def convert_decimal(obj):
    if isinstance(obj, list):
        return [convert_decimal(item) for item in obj]
    elif isinstance(obj, dict):
        return {k: convert_decimal(v) for k, v in obj.items()}
    elif isinstance(obj, Decimal):
        return float(obj)
    else:
        return obj

def get_cart(user_id):
    try:
        cache_key = f"cart:{user_id}"
        cached_cart = redis_client.get(cache_key)
        if cached_cart:
            logger.info(f"Lấy giỏ hàng từ cache cho user {user_id}")
            return json.loads(cached_cart)
        cart_items=[]
            # Thiết lập biến OUT
        mysql_cursor.execute("SET @output = NULL")

        # Gọi stored procedure
        mysql_cursor.execute(f"CALL get_cart(1, @output)")

        # Lấy giá trị của biến OUT
        mysql_cursor.execute("SELECT @output")
        result = mysql_cursor.fetchone() 
        cart_items=json.loads(result["@output"])
        if not cart_items:
            return create_cart(user_id)
        cart_data = {
            "user_id": user_id,
            "items": convert_decimal(cart_items),
            "last_updated": str(datetime.now())
        }

        redis_client.setex(cache_key, SESSION_TTL, json.dumps(cart_data))
        logger.info(f"Lấy giỏ hàng từ MySQL và cache cho user {user_id}")
        return cart_data
    except Exception as e:
        logger.error(f"Lỗi khi lấy giỏ hàng: {e}")
        return None

def create_cart(user_id):
    try:
        cache_key = f"cart:{user_id}"
        cart_data = {
            "user_id": user_id,
            "items": [],
            "last_updated": str(datetime.now())
        }
        redis_client.setex(cache_key, SESSION_TTL, json.dumps(cart_data))
        logger.info(f"Tạo giỏ hàng mới cho user {user_id}")
        return cart_data
    except Exception as e:
        logger.error(f"Lỗi khi tạo giỏ hàng: {e}")
        return None

def add_cart(user_id, product_id, quantity=1):
    try:
        cache_key = f"cart:{user_id}"

          # Thiết lập biến OUT
        mysql_cursor.execute("SET @output = NULL")
        
        # Gọi stored procedure
        mysql_cursor.execute(f"CALL Make_product_for_temp_cart({product_id}, {quantity}, @output)")
        
        # Lấy giá trị của biến OUT
        mysql_cursor.execute("SELECT @output")
        result = mysql_cursor.fetchone()
        parsed_result = json.loads(result["@output"]) if result else None

        # Kiểm tra kết quả từ stored procedure
        if not parsed_result:
            logger.error(f"Không có kết quả từ stored procedure cho sản phẩm {product_id}")
            return None
        # Kiểm tra nếu có lỗi từ stored procedure
        if 'error' in parsed_result:
            error_message = parsed_result['error']
            if error_message == 'Product not found':
                logger.error(f"Sản phẩm {product_id} không tìm thấy trong kho")
                return {'status': 'error', 'message': 'Sản phẩm không tồn tại'}
            elif error_message == 'Not enough inventory':
                logger.error(f"Số lượng yêu cầu ({quantity}) cho sản phẩm {product_id} vượt quá tồn kho")
                return {'status': 'error', 'message': 'Số lượng sản phẩm vượt quá tồn kho'}
            else:
                logger.error(f"Lỗi không xác định: {error_message}")
                return {'status': 'error', 'message': error_message}
        
        # Lấy thông tin sản phẩm (trong trường hợp thành công)
        if isinstance(parsed_result, list):
            # Nếu kết quả là một mảng JSON (trường hợp thành công)
            item_add_cart = parsed_result[0] if parsed_result else None
        else:
            # Nếu kết quả không phải mảng, có thể có lỗi trong cấu trúc trả về
            logger.error(f"Cấu trúc JSON không mong đợi: {parsed_result}")
            return {'status': 'error', 'message': 'Định dạng dữ liệu không hợp lệ'}
            
        if not item_add_cart or 'product_id' not in item_add_cart:
            logger.error(f"Lỗi thêm sản phẩm {product_id} vào giỏ hàng tạm cho user {user_id}")
            return {'status': 'error', 'message': 'Không thể thêm sản phẩm vào giỏ hàng'}

        # Load giỏ hàng từ Redis
        cached_cart = redis_client.get(cache_key)
        if cached_cart:
            cart_data = json.loads(cached_cart)
        else:
            cart_data = create_cart(user_id)

        # Cập nhật giỏ hàng
        updated = False
        for item in cart_data["items"]:
            if item["product_id"] == product_id:
                item["quantity"] += quantity
                item["total"] = float(item["price"]) * item["quantity"]
                updated = True
                break

        if not updated:
            cart_data["items"].append(item_add_cart)

        cart_data["last_updated"] = str(datetime.now())

        # Ghi lại vào Redis
        redis_client.setex(cache_key, SESSION_TTL, json.dumps(convert_decimal(cart_data)))
        logger.info(f"Đã thêm sản phẩm {product_id} vào giỏ hàng Redis của user {user_id}")
        return {'status': 'success', 'message': 'Đã thêm sản phẩm vào giỏ hàng'}

    except Exception as e:
        logger.error(f"Lỗi khi thêm sản phẩm vào Redis cart: {e}")
        return {'status': 'error', 'message': 'Lỗi khi thêm sản phẩm vào giỏ hàng'}

def delete_cart(user_id, product_id=None):
    try:
        cache_key = f"cart:{user_id}"
        if product_id:
            cached_cart = redis_client.get(cache_key)
            if not cached_cart:
                logger.warning(f"Không tìm thấy giỏ hàng cho user {user_id}")
                return False

            cart_data = json.loads(cached_cart)
            original_len = len(cart_data["items"])
            cart_data["items"] = [
                item for item in cart_data["items"]
                if int(item["product_id"]) != int(product_id)
            ]

            if len(cart_data["items"]) == original_len:
                logger.info(f"Sản phẩm {product_id} không tồn tại trong giỏ hàng")
                return False

            cart_data["last_updated"] = str(datetime.now())
            redis_client.setex(cache_key, SESSION_TTL, json.dumps(convert_decimal(cart_data)))
            logger.info(f"Đã xóa sản phẩm {product_id} khỏi giỏ hàng")
        else:
            redis_client.delete(cache_key)
            logger.info(f"Đã xóa toàn bộ giỏ hàng của user {user_id}")
        return True
    except Exception as e:
        logger.error(f"Lỗi khi xóa giỏ hàng: {e}")
        return False

def synchronize_mysql(user_id):
    try:
        cache_key = f"cart:{user_id}"
        cached_cart = redis_client.get(cache_key)
        if not cached_cart:
            return False

        cart_data = json.loads(cached_cart)

        # Lấy danh sách product_id đã có trong giỏ hàng MySQL
        mysql_cursor.execute(
            "SELECT product_id FROM shopping_cart WHERE customer_id = %s", (user_id,)
        )
        existing_rows = mysql_cursor.fetchall()
        existing_product_ids = {row['product_id'] for row in existing_rows}

        for item in cart_data["items"]:
            if item["product_id"] in existing_product_ids:
                # Cập nhật số lượng nếu sản phẩm đã tồn tại
                query = """
                    UPDATE shopping_cart
                    SET quantity = %s
                    WHERE customer_id = %s AND product_id = %s
                """
                mysql_cursor.execute(query, (
                    item["quantity"],
                    user_id,
                    item["product_id"]
                ))
            else:
                # Thêm mới nếu sản phẩm chưa có
                query = """
                    INSERT INTO shopping_cart (customer_id, product_id, quantity, created_at)
                    VALUES (%s, %s, %s, NOW())
                """
                mysql_cursor.execute(query, (
                    user_id,
                    item["product_id"],
                    item["quantity"]
                ))

        mysql_conn.commit()
        logger.info(f"Đồng bộ Redis -> MySQL cho user {user_id}")
        return True

    except Exception as e:
        logger.error(f"Lỗi khi đồng bộ dữ liệu: {e}")
        mysql_conn.rollback()
        return False
def load_cart_to_redis_after_login(user_id):
    try:
        cache_key = f"cart:{user_id}"
        cart_items=[]
            # Thiết lập biến OUT
        mysql_cursor.execute("SET @output = NULL")

        # Gọi stored procedure
        mysql_cursor.execute(f"CALL get_cart(1, @output)")

        # Lấy giá trị của biến OUT
        mysql_cursor.execute("SELECT @output")
        result = mysql_cursor.fetchone() 
        if result:  # Nếu có dữ liệu trong @output
            output_json = result["@output"]  # Chuỗi JSON
            cart_items = json.loads(output_json)# Parse thành list Python
        else:
            cart_items = []  # Không có giỏ hàng
        if not cart_items:
            logger.info(f"Giỏ hàng MySQL trống cho user {user_id}")
            return False

        cart_data = {
            "user_id": user_id,
            "items": convert_decimal(cart_items),
            "last_updated": str(datetime.now())
        }

        redis_client.setex(cache_key, SESSION_TTL, json.dumps(cart_data))
        logger.info(f"Load giỏ hàng từ MySQL -> Redis cho user {user_id}")
        return True
    except Exception as e:
        logger.error(f"Lỗi khi load giỏ hàng sau đăng nhập: {e}")
        return False

def make_order(user_id):
    product_ids = []  # Sử dụng danh sách đúng cách
    quantities = []   # Thêm danh sách cho số lượng
    
    # Lặp nhập thông tin sản phẩm
    while True:
        if input("Nhập q để thoát!! ").lower() == 'q':
            break
            
        try:
            # Nhập thông tin sản phẩm và số lượng
            product_id = int(input("Nhập id sản phẩm muốn mua: "))
            quantity = int(input("Nhập số lượng: "))
            
            # Kiểm tra giá trị hợp lệ
            if product_id <= 0 or quantity <= 0:
                print("ID sản phẩm và số lượng phải là số dương!")
                continue
                
            # Thêm vào giỏ hàng
            add_cart(user_id, product_id, quantity)
            
            # Lưu thông tin để xử lý sau
            product_ids.append(product_id)
            quantities.append(quantity)
            
        except ValueError:
            print("Lỗi: Vui lòng nhập số nguyên hợp lệ!")
    
    # Kiểm tra nếu không có sản phẩm nào được chọn
    if not product_ids:
        print("Không có sản phẩm nào được chọn. Hủy đặt hàng.")
        return
    
    print("Thực hiện mua hàng!!")
    
    # Lấy thông tin giỏ hàng
    cart = get_cart(user_id)
    
    # Chuẩn bị dữ liệu sản phẩm cho stored procedure
    product_data = []
    for product_id in product_ids:
        for item in cart["items"]:
            if item["product_id"] == product_id:
                product_data.append({
                    "product_id": item["product_id"],
                    "quantity": item["quantity"]
                })
                break
    
    # Chuyển product_data thành JSON
    import json
    product_data_json = json.dumps(product_data)
    
    try:
        # Gọi stored procedure và lấy kết quả trả về
        mysql_cursor.execute(
            "CALL CreateOrder(%s, NULL, 'processing', NULL, %s)",
            (user_id, product_data_json)
        )
        
        # Lấy kết quả từ stored procedure
        result = mysql_cursor.fetchone()
        
        # Kiểm tra kết quả
        if result and 'order_id' in result:
            order_id = result['order_id']
            print(f"Đặt hàng thành công! Mã đơn hàng của bạn là: {order_id}")
            
            # Xóa các sản phẩm đã mua khỏi giỏ hàng
            for product_id in product_ids:
                delete_cart(user_id, product_id)
                
            # Trả về order_id để có thể sử dụng ở nơi khác nếu cần
            return order_id
        else:
            print("Đặt hàng thành công nhưng không nhận được mã đơn hàng.")
            
            # Xóa các sản phẩm đã mua khỏi giỏ hàng
            for product_id in product_ids:
                delete_cart(user_id, product_id)
        
    except Exception as e:
        print(f"Lỗi khi đặt hàng: {e}")
        return None
# --------------------------
# Main test flow
# --------------------------
if __name__ == "__main__":
    email_test = "mullinsmichelle@example.org"
    pass_test = "d8faeff5e40bcce793759a7514a663ba4fb735866b6a9c370f0d589d47ebddf2"
    user_id = None

    try:
        token = login(email=email_test, password=pass_test, role="customer")
        user = get_user_from_token(token)
        user_id = user['user_id']
        print(f"User ID: {user_id}")

        if user_id:
            logger.info(f"Đăng nhập thành công: user_id = {user_id}")

            if load_cart_to_redis_after_login(user_id):
                logger.info("Giỏ hàng đã được load từ MySQL lên Redis")
                cart = get_cart(user_id)
                print("Giỏ hàng hiện tại:")
                print(json.dumps(cart, indent=2, ensure_ascii=False))
                make_order(user_id)
                print("Giỏ hàng hiện tại sau khi them:")
                print(json.dumps(cart, indent=2, ensure_ascii=False))
            else:
                logger.warning("Không có dữ liệu giỏ hàng trong MySQL hoặc lỗi khi load.")
        else:
            logger.warning("Đăng nhập thất bại.")
    except Exception as e:
        logger.error(f"Lỗi khi chạy chương trình chính: {e}")
    finally:
        if user_id:
            check=logout(token)
            if check:
                # synchronize_mysql(user_id)
                delete_cart(user_id)
                close_connections()
            else:
                print('logout that bai!')
