#!/usr/bin/env python3
import sys
import os
sys.path.append('src')

from stronix.services.PlanService import PlanService
from stronix.database import get_db_connection

def test_plan_detail():
    """测试计划详情获取"""
    print("开始测试计划详情获取...")
    
    # 测试数据库连接
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # 查看计划3的详细信息
        plan_id = 3
        user_id = 7
        
        print(f"\n1. 查询计划基本信息 (plan_id={plan_id})...")
        cursor.execute("""
            SELECT id, name, description, difficulty, duration, user_id, is_template, template_id, created_at, updated_at
            FROM training_plans 
            WHERE id = ?
        """, (plan_id,))
        
        plan_row = cursor.fetchone()
        if plan_row:
            print(f"   计划找到: {plan_row[1]} (用户ID: {plan_row[5]})")
        else:
            print("   计划未找到!")
            return
        
        print(f"\n2. 查询计划动作...")
        cursor.execute("""
            SELECT 
                pa.action_id, pa.`order`, pa.sets, pa.rest, pa.weight, pa.note, pa.record_bilateral,
                a.name, a.name_en, a.gifUrl, a.description, a.bodypart_id, a.equipment_id, a.is_bilateral
            FROM plan_actions pa
            JOIN action a ON pa.action_id = a.id
            WHERE pa.plan_id = ?
            ORDER BY pa.`order`
        """, (plan_id,))
        
        actions = cursor.fetchall()
        print(f"   找到 {len(actions)} 个动作")
        for action in actions:
            print(f"   - 动作ID: {action[0]}, 名称: {action[7]}")
        
        if actions:
            action_id = actions[0][0]
            print(f"\n3. 查询动作组数据 (action_id={action_id})...")
            cursor.execute("""
                SELECT id, set_number, weight, reps, left_weight, right_weight, created_at
                FROM plan_sets
                WHERE plan_id = ? AND action_id = ?
                ORDER BY set_number
            """, (plan_id, action_id))
            
            sets = cursor.fetchall()
            print(f"   找到 {len(sets)} 组数据")
            for set_data in sets:
                print(f"   - 组{set_data[1]}: {set_data[2]}kg x {set_data[3]}次")
        
        conn.close()
        
        print(f"\n4. 测试PlanService...")
        service = PlanService()
        plan_detail = service.get_plan_detail(plan_id, user_id)
        print(f"   PlanService成功返回: {plan_detail['name']}")
        print(f"   动作数量: {len(plan_detail['actions'])}")
        
    except Exception as e:
        print(f"错误: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_plan_detail() 