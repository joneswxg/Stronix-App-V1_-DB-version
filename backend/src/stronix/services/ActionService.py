import sqlite3
from typing import List, Dict
import os

# 更新数据库路径到新位置
DB_PATH = "/Users/joneswang/Desktop/Project-Dev/Stronix-App-V1/Stronix-App/Resources/Database/database_stronix.db"

def get_all_target_muscles() -> List[Dict]:
    """获取所有目标肌肉信息"""
    print("DB_PATH:", DB_PATH)  # 保留这行用于调试
    print("DB exists:", os.path.exists(DB_PATH))  # 添加文件存在检查
    with sqlite3.connect(DB_PATH) as conn:
        cursor = conn.execute("SELECT id, name, display_name FROM target_muscle")
        columns = [desc[0] for desc in cursor.description]
        return [dict(zip(columns, row)) for row in cursor.fetchall()]

def get_all_equipment() -> List[Dict]:
    """获取所有训练设备信息"""
    with sqlite3.connect(DB_PATH) as conn:
        cursor = conn.execute("SELECT id, name, display_name FROM equipment")
        columns = [desc[0] for desc in cursor.description]
        return [dict(zip(columns, row)) for row in cursor.fetchall()]

def get_all_actions() -> List[Dict]:
    """获取所有训练动作信息"""
    with sqlite3.connect(DB_PATH) as conn:
        cursor = conn.execute("""
            SELECT 
                a.id,
                a.name,
                a.name_en,
                a.gifUrl as image_url,
                3 as default_sets,
                12 as default_reps,
                a.bodypart_id as body_part_id,
                a.equipment_id,
                GROUP_CONCAT(atml.target_muscle_id) as target_muscle_ids
            FROM action a
            LEFT JOIN action_target_muscle_link atml ON a.id = atml.action_id
            GROUP BY a.id
        """)
        columns = [desc[0] for desc in cursor.description]
        results = []
        for row in cursor.fetchall():
            data = dict(zip(columns, row))
            # 处理 target_muscle_ids 字段
            if data['target_muscle_ids']:
                data['target_muscle_ids'] = [int(x) for x in data['target_muscle_ids'].split(',')]
            else:
                data['target_muscle_ids'] = []
            # 处理 image_url 字段，只保留文件名
            if data['image_url']:
                data['image_url'] = os.path.basename(data['image_url'])
            results.append(data)
        return results

def get_actions_by_target_muscle(target_muscle_id: int) -> List[Dict]:
    """根据目标肌肉获取训练动作"""
    with sqlite3.connect(DB_PATH) as conn:
        cursor = conn.execute("""
            SELECT 
                a.id,
                a.name,
                a.name_en,
                a.gifUrl as image_url,
                3 as default_sets,
                12 as default_reps,
                a.bodypart_id as body_part_id,
                a.equipment_id,
                GROUP_CONCAT(atml.target_muscle_id) as target_muscle_ids
            FROM action a
            JOIN action_target_muscle_link atml ON a.id = atml.action_id
            WHERE atml.target_muscle_id = ?
            GROUP BY a.id
        """, (target_muscle_id,))
        columns = [desc[0] for desc in cursor.description]
        results = []
        for row in cursor.fetchall():
            data = dict(zip(columns, row))
            # 处理 target_muscle_ids 字段
            if data['target_muscle_ids']:
                data['target_muscle_ids'] = [int(x) for x in data['target_muscle_ids'].split(',')]
            else:
                data['target_muscle_ids'] = []
            # 处理 image_url 字段，只保留文件名
            if data['image_url']:
                data['image_url'] = os.path.basename(data['image_url'])
            results.append(data)
        return results

