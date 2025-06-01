from flask import Flask, request, jsonify
import sqlite3
import os
import logging

# 禁用 Flask 启动时的默认输出
log = logging.getLogger('werkzeug')
log.setLevel(logging.ERROR)

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

app = Flask(__name__)

@app.route('/api/query')
def query():
    sql = request.args.get('sql')
    if not sql:
        return jsonify({'error': 'Missing SQL query'}), 400
    
    try:
        with sqlite3.connect(DB_PATH) as conn:
            cursor = conn.execute(sql)
            if sql.strip().upper().startswith('SELECT'):
                rows = cursor.fetchall()
                columns = [desc[0] for desc in cursor.description]
                result = [dict(zip(columns, row)) for row in rows]
                return jsonify({
                    'result': result,
                    'metadata': {
                        'rows_affected': len(result),
                        'columns': columns
                    }
                })
            else:
                return jsonify({
                    'success': True,
                    'metadata': {
                        'rows_affected': cursor.rowcount
                    }
                })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/execute', methods=['POST'])
def execute():
    sql = request.json.get('sql')
    if not sql:
        return jsonify({'error': 'Missing SQL statement'}), 400
    
    try:
        with sqlite3.connect(DB_PATH) as conn:
            cursor = conn.cursor()
            cursor.execute(sql)
            conn.commit()
            return jsonify({
                'success': True,
                'metadata': {
                    'rows_affected': cursor.rowcount
                }
            })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# 添加健康检查端点，用于 MCP 验证服务器状态
@app.route('/api/health')
def health():
    try:
        with sqlite3.connect(DB_PATH) as conn:
            conn.execute('SELECT 1')
            return jsonify({'status': 'ok', 'database': 'connected'})
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

if __name__ == '__main__':
    # 禁用 Flask 启动时的 banner 和调试信息
    import click
    click.echo = lambda *args, **kwargs: None
    click.secho = lambda *args, **kwargs: None
    
    # 以静默模式启动，不输出启动信息
    app.run(host='0.0.0.0', port=6000, debug=False, use_reloader=False)
