import sqlite3
import os

# 获取项目根目录的绝对路径
PROJECT_ROOT = "/Users/joneswang/Desktop/Project-Dev/Stronix-App-V1"
DB_PATH = os.path.join(PROJECT_ROOT, "Stronix-App/Resources/Database/database_stronix.db")

def get_db_connection():
    """获取数据库连接"""
    try:
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row  # 使结果可以通过列名访问
        return conn
    except Exception as e:
        print(f"数据库连接错误: {e}")
        raise e

def test_connection():
    """测试数据库连接"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        result = cursor.fetchone()
        conn.close()
        return result is not None
    except Exception as e:
        print(f"数据库连接测试失败: {e}")
        return False 