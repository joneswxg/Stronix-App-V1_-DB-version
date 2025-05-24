from flask import Flask, request, jsonify
import sqlite3
import sys
import logging

# 禁用 Flask 启动时的默认输出
log = logging.getLogger('werkzeug')
log.setLevel(logging.ERROR)

app = Flask(__name__)
db_path = sys.argv[1] if len(sys.argv) > 1 else 'database.db'

@app.route('/api/query')
def query():
    sql = request.args.get('sql')
    if not sql:
        return jsonify({'error': 'Missing SQL query'}), 400
    
    try:
        with sqlite3.connect(db_path) as conn:
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
        with sqlite3.connect(db_path) as conn:
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
        with sqlite3.connect(db_path) as conn:
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
    app.run(host='0.0.0.0', port=5000, debug=False, use_reloader=False)
