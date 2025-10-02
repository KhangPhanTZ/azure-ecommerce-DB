import os
import logging
import redis
import mysql.connector
from dotenv import load_dotenv
from mysql.connector.connection import MySQLConnection

# Tải biến môi trường
load_dotenv()

# Cấu hình logger
logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

# Hằng số
SESSION_TTL = 180  # 3 phút

# Lấy thông tin kết nối từ biến môi trường
redis_host = os.getenv("REDIS_HOST")
redis_port = os.getenv("REDIS_PORT", 6379)
redis_password = os.getenv("REDIS_PRIMARY_KEY")
mysql_host = os.getenv("MYSQL_HOST")
mysql_user = os.getenv("MYSQL_USER")
mysql_password = os.getenv("MYSQL_PASSWORD")
mysql_database = os.getenv("MYSQL_DATABASE")

# Kiểm tra biến môi trường bắt buộc
required_vars = {
    "REDIS_HOST": redis_host,
    "MYSQL_HOST": mysql_host,
    "MYSQL_USER": mysql_user,
    "MYSQL_PASSWORD": mysql_password,
    "MYSQL_DATABASE": mysql_database
}
for var_name, var_value in required_vars.items():
    if not var_value:
        logger.error(f"Thiếu biến môi trường: {var_name}")
        raise EnvironmentError(f"Thiếu biến môi trường: {var_name}")

# Khởi tạo biến kết nối
redis_client = None
mysql_conn = None
mysql_cursor = None

# Kết nối Redis
try:
    redis_client = redis.StrictRedis(
        host=redis_host,
        port=int(redis_port),
        password=redis_password,
        ssl=True,
        decode_responses=True
    )
    redis_client.ping()
    logger.info("✅ Kết nối Redis thành công")
except Exception as e:
    logger.error("❌ Lỗi kết nối Redis: %s", e)
    raise

# Kết nối MySQL
try:
    mysql_conn = mysql.connector.connect(
        host=mysql_host,
        user=mysql_user,
        password=mysql_password,
        database=mysql_database,
        ssl_ca="C:\Study\QLTT\Đồ án\redis_mysql\DigiCertGlobalRootG2.crt.pem", 
        ssl_disabled=False
    )
    """cnx = mysql.connector.connect(user="thoandanh2k55", password="{your_password}", host="doanqltt.mysql.database.azure.com", port=3306, database="{your_database}", ssl_ca="{ca-cert filename}", ssl_disabled=False)"""
    mysql_cursor = mysql_conn.cursor(dictionary=True)
    logger.info("✅ Kết nối MySQL thành công")
except Exception as e:
    logger.error("❌ Lỗi kết nối MySQL: %s", e)
    raise

# ✅ Hàm đóng kết nối
def close_connections():
    try:
        if mysql_cursor:
            mysql_cursor.close()
        if mysql_conn:
            mysql_conn.close()
        logger.info("🔒 Đã đóng kết nối MySQL.")
    except Exception as e:
        logger.warning("Lỗi khi đóng MySQL: %s", e)

    try:
        if redis_client:
            redis_client.close()
        logger.info("🔒 Đã đóng kết nối Redis.")
    except Exception as e:
        logger.warning("Lỗi khi đóng Redis: %s", e)
