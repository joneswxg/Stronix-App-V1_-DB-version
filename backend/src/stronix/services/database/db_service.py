from flask import Flask, request, jsonify
import sqlite3
import os
import logging
from datetime import datetime

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

# 体测数据相关函数
def create_body_measurement(user_id, measurement_timestamp, weight_kg, height_cm, 
                          body_fat_percentage, skeletal_muscle_mass_kg, visceral_fat_level):
    """创建新的体测记录"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        sql = """
        INSERT INTO body_measurements 
        (user_id, measurement_timestamp, weight_kg, height_cm, body_fat_percentage, 
         skeletal_muscle_mass_kg, visceral_fat_level)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """
        
        cursor.execute(sql, (user_id, measurement_timestamp, weight_kg, height_cm,
                           body_fat_percentage, skeletal_muscle_mass_kg, visceral_fat_level))
        conn.commit()
        measurement_id = cursor.lastrowid
        conn.close()
        
        return measurement_id
    except Exception as e:
        print(f"创建体测记录错误: {e}")
        raise e

def get_user_body_measurements(user_id, limit=None, start_date=None, end_date=None):
    """获取用户的体测记录"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        sql = """
        SELECT id, user_id, measurement_timestamp, weight_kg, height_cm, 
               body_fat_percentage, skeletal_muscle_mass_kg, visceral_fat_level,
               created_at, updated_at
        FROM body_measurements 
        WHERE user_id = ?
        """
        params = [user_id]
        
        if start_date:
            sql += " AND measurement_timestamp >= ?"
            params.append(start_date)
        
        if end_date:
            sql += " AND measurement_timestamp <= ?"
            params.append(end_date)
            
        sql += " ORDER BY measurement_timestamp DESC"
        
        if limit:
            sql += " LIMIT ?"
            params.append(limit)
        
        cursor.execute(sql, params)
        rows = cursor.fetchall()
        conn.close()
        
        # 转换为字典列表
        measurements = []
        for row in rows:
            measurements.append({
                'id': row['id'],
                'user_id': row['user_id'],
                'measurement_timestamp': row['measurement_timestamp'],
                'weight_kg': row['weight_kg'],
                'height_cm': row['height_cm'],
                'body_fat_percentage': row['body_fat_percentage'],
                'skeletal_muscle_mass_kg': row['skeletal_muscle_mass_kg'],
                'visceral_fat_level': row['visceral_fat_level'],
                'created_at': row['created_at'],
                'updated_at': row['updated_at']
            })
        
        return measurements
    except Exception as e:
        print(f"获取体测记录错误: {e}")
        raise e

def get_body_measurement_by_id(measurement_id):
    """根据ID获取单条体测记录"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        sql = """
        SELECT id, user_id, measurement_timestamp, weight_kg, height_cm, 
               body_fat_percentage, skeletal_muscle_mass_kg, visceral_fat_level,
               created_at, updated_at
        FROM body_measurements 
        WHERE id = ?
        """
        
        cursor.execute(sql, (measurement_id,))
        row = cursor.fetchone()
        conn.close()
        
        if row:
            return {
                'id': row['id'],
                'user_id': row['user_id'],
                'measurement_timestamp': row['measurement_timestamp'],
                'weight_kg': row['weight_kg'],
                'height_cm': row['height_cm'],
                'body_fat_percentage': row['body_fat_percentage'],
                'skeletal_muscle_mass_kg': row['skeletal_muscle_mass_kg'],
                'visceral_fat_level': row['visceral_fat_level'],
                'created_at': row['created_at'],
                'updated_at': row['updated_at']
            }
        return None
    except Exception as e:
        print(f"获取体测记录错误: {e}")
        raise e

def update_body_measurement(measurement_id, weight_kg=None, height_cm=None, 
                          body_fat_percentage=None, skeletal_muscle_mass_kg=None, 
                          visceral_fat_level=None):
    """更新体测记录"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # 构建动态更新SQL
        update_fields = []
        params = []
        
        if weight_kg is not None:
            update_fields.append("weight_kg = ?")
            params.append(weight_kg)
        if height_cm is not None:
            update_fields.append("height_cm = ?")
            params.append(height_cm)
        if body_fat_percentage is not None:
            update_fields.append("body_fat_percentage = ?")
            params.append(body_fat_percentage)
        if skeletal_muscle_mass_kg is not None:
            update_fields.append("skeletal_muscle_mass_kg = ?")
            params.append(skeletal_muscle_mass_kg)
        if visceral_fat_level is not None:
            update_fields.append("visceral_fat_level = ?")
            params.append(visceral_fat_level)
        
        if not update_fields:
            return False
        
        update_fields.append("updated_at = CURRENT_TIMESTAMP")
        params.append(measurement_id)
        
        sql = f"UPDATE body_measurements SET {', '.join(update_fields)} WHERE id = ?"
        
        cursor.execute(sql, params)
        conn.commit()
        rows_affected = cursor.rowcount
        conn.close()
        
        return rows_affected > 0
    except Exception as e:
        print(f"更新体测记录错误: {e}")
        raise e

def delete_body_measurement(measurement_id):
    """删除体测记录"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("DELETE FROM body_measurements WHERE id = ?", (measurement_id,))
        conn.commit()
        rows_affected = cursor.rowcount
        conn.close()
        
        return rows_affected > 0
    except Exception as e:
        print(f"删除体测记录错误: {e}")
        raise e

def calculate_bmi(weight_kg, height_cm):
    """计算BMI"""
    height_m = height_cm / 100
    return weight_kg / (height_m * height_m)

def calculate_body_fat_kg(weight_kg, body_fat_percentage):
    """计算体脂肪重量"""
    return weight_kg * body_fat_percentage / 100

def calculate_bmr(weight_kg, height_cm, age, gender):
    """计算基础代谢率 (使用Mifflin-St Jeor公式)"""
    if gender.lower() == 'male':
        return 10 * weight_kg + 6.25 * height_cm - 5 * age + 5
    else:
        return 10 * weight_kg + 6.25 * height_cm - 5 * age - 161

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

# 体测数据API端点
@app.route('/api/body-measurements', methods=['POST'])
def create_measurement():
    """创建新的体测记录"""
    try:
        data = request.json
        measurement_id = create_body_measurement(
            user_id=data['user_id'],
            measurement_timestamp=data['measurement_timestamp'],
            weight_kg=data['weight_kg'],
            height_cm=data['height_cm'],
            body_fat_percentage=data['body_fat_percentage'],
            skeletal_muscle_mass_kg=data['skeletal_muscle_mass_kg'],
            visceral_fat_level=data['visceral_fat_level']
        )
        return jsonify({'success': True, 'measurement_id': measurement_id})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/body-measurements/<int:user_id>')
def get_measurements(user_id):
    """获取用户的体测记录"""
    try:
        limit = request.args.get('limit', type=int)
        start_date = request.args.get('start_date')
        end_date = request.args.get('end_date')
        
        measurements = get_user_body_measurements(user_id, limit, start_date, end_date)
        return jsonify({'measurements': measurements})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/body-measurements/detail/<int:measurement_id>')
def get_measurement_detail(measurement_id):
    """获取单条体测记录详情"""
    try:
        measurement = get_body_measurement_by_id(measurement_id)
        if measurement:
            return jsonify({'measurement': measurement})
        else:
            return jsonify({'error': 'Measurement not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/body-measurements/<int:measurement_id>', methods=['PUT'])
def update_measurement(measurement_id):
    """更新体测记录"""
    try:
        data = request.json
        success = update_body_measurement(
            measurement_id=measurement_id,
            weight_kg=data.get('weight_kg'),
            height_cm=data.get('height_cm'),
            body_fat_percentage=data.get('body_fat_percentage'),
            skeletal_muscle_mass_kg=data.get('skeletal_muscle_mass_kg'),
            visceral_fat_level=data.get('visceral_fat_level')
        )
        if success:
            return jsonify({'success': True})
        else:
            return jsonify({'error': 'Measurement not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/body-measurements/<int:measurement_id>', methods=['DELETE'])
def delete_measurement(measurement_id):
    """删除体测记录"""
    try:
        success = delete_body_measurement(measurement_id)
        if success:
            return jsonify({'success': True})
        else:
            return jsonify({'error': 'Measurement not found'}), 404
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
