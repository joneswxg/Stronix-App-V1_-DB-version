from typing import List, Optional, Dict, Any, Tuple
import sqlite3
from datetime import datetime
from ..database import get_db_connection
from ..models.PlanModels import (
    TrainingPlan, PlanAction, PlanSet, Action, 
    PlanError, PlanErrorCode, get_error_message
)

class PlanService:
    """计划服务类"""
    
    def __init__(self):
        pass
    
    def calculate_action_volume(self, sets: List[Dict[str, Any]], record_bilateral: bool = False) -> float:
        """
        计算动作的总容量
        容量 = 重量 × 次数 的总和
        """
        total_volume = 0.0
        
        for set_data in sets:
            if record_bilateral:
                # 双侧训练：(左重量 + 右重量) × 次数
                left_weight = float(set_data.get('left_weight', 0))
                right_weight = float(set_data.get('right_weight', 0))
                reps = int(set_data.get('reps', 0))
                total_volume += (left_weight + right_weight) * reps
            else:
                # 普通训练：重量 × 次数
                weight = float(set_data.get('weight', 0))
                reps = int(set_data.get('reps', 0))
                total_volume += weight * reps
        
        return total_volume
    
    def get_template_plans(self, language: str = 'zh_CN') -> List[Dict[str, Any]]:
        """获取模板计划列表"""
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # 查询模板计划（user_id为NULL的计划）
            cursor.execute("""
                SELECT id, name, description, difficulty, duration, created_at, updated_at
                FROM training_plans 
                WHERE is_template = 1 OR user_id IS NULL
                ORDER BY created_at DESC
            """)
            
            plans = []
            for row in cursor.fetchall():
                plan_dict = {
                    'id': row[0],
                    'name': row[1],
                    'description': row[2],
                    'difficulty': row[3],
                    'duration': row[4],
                    'created_at': row[5],
                    'updated_at': row[6],
                    'is_template': True
                }
                plans.append(plan_dict)
            
            conn.close()
            return plans
            
        except Exception as e:
            raise PlanError(
                get_error_message('SERVER_ERROR', language),
                PlanErrorCode.SERVER_ERROR,
                'SERVER_ERROR'
            )
    
    def get_user_plans(self, user_id: int, language: str = 'zh_CN') -> List[Dict[str, Any]]:
        """获取用户的个人计划列表"""
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # 查询用户的个人计划
            cursor.execute("""
                SELECT id, name, description, difficulty, duration, created_at, updated_at, template_id
                FROM training_plans 
                WHERE user_id = ? AND (is_template = 0 OR is_template IS NULL)
                ORDER BY created_at DESC
            """, (user_id,))
            
            plans = []
            for row in cursor.fetchall():
                plan_dict = {
                    'id': row[0],
                    'name': row[1],
                    'description': row[2],
                    'difficulty': row[3],
                    'duration': row[4],
                    'created_at': row[5],
                    'updated_at': row[6],
                    'template_id': row[7],
                    'is_template': False
                }
                plans.append(plan_dict)
            
            conn.close()
            return plans
            
        except Exception as e:
            raise PlanError(
                get_error_message('SERVER_ERROR', language),
                PlanErrorCode.SERVER_ERROR,
                'SERVER_ERROR'
            )
    
    def get_plan_detail(self, plan_id: int, user_id: Optional[int] = None, language: str = 'zh_CN') -> Dict[str, Any]:
        """获取计划详情"""
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # 查询计划基本信息
            cursor.execute("""
                SELECT id, name, description, difficulty, duration, user_id, is_template, template_id, created_at, updated_at
                FROM training_plans 
                WHERE id = ?
            """, (plan_id,))
            
            plan_row = cursor.fetchone()
            if not plan_row:
                raise PlanError(
                    get_error_message('PLAN_NOT_FOUND', language),
                    PlanErrorCode.NOT_FOUND,
                    'PLAN_NOT_FOUND'
                )
            
            # 检查权限（如果不是模板计划，需要验证用户权限）
            if plan_row[6] != 1 and plan_row[5] is not None and user_id and plan_row[5] != user_id:
                raise PlanError(
                    get_error_message('PERMISSION_DENIED', language),
                    PlanErrorCode.FORBIDDEN,
                    'PERMISSION_DENIED'
                )
            
            plan_dict = {
                'id': plan_row[0],
                'name': plan_row[1],
                'description': plan_row[2],
                'difficulty': plan_row[3],
                'duration': plan_row[4],
                'user_id': plan_row[5],
                'is_template': bool(plan_row[6]),
                'template_id': plan_row[7],
                'created_at': plan_row[8],
                'updated_at': plan_row[9],
                'actions': []
            }
            
            # 查询计划的动作
            cursor.execute("""
                SELECT 
                    pa.action_id, pa.`order`, pa.sets, pa.rest, pa.weight, pa.note, pa.record_bilateral,
                    a.name, a.name_en, a.gifUrl, a.description, a.bodypart_id, a.equipment_id, a.is_bilateral
                FROM plan_actions pa
                JOIN action a ON pa.action_id = a.id
                WHERE pa.plan_id = ?
                ORDER BY pa.`order`
            """, (plan_id,))
            
            actions = []
            for action_row in cursor.fetchall():
                action_dict = {
                    'action_id': action_row[0],
                    'order': action_row[1],
                    'sets_count': action_row[2],
                    'rest': action_row[3],
                    'weight': action_row[4],
                    'note': action_row[5],
                    'record_bilateral': bool(action_row[6]),
                    'action_info': {
                        'id': action_row[0],
                        'name': action_row[7],
                        'name_en': action_row[8],
                        'gifUrl': action_row[9],
                        'description': action_row[10],
                        'bodypart_id': action_row[11],
                        'equipment_id': action_row[12],
                        'is_bilateral': bool(action_row[13])
                    },
                    'sets': []
                }
                
                # 查询每个动作的组数据
                cursor.execute("""
                    SELECT id, set_number, weight, reps, left_weight, right_weight, created_at
                    FROM plan_sets
                    WHERE plan_id = ? AND action_id = ?
                    ORDER BY set_number
                """, (plan_id, action_row[0]))
                
                sets = []
                for set_row in cursor.fetchall():
                    set_dict = {
                        'id': set_row[0],
                        'set_number': set_row[1],
                        'weight': set_row[2],
                        'reps': set_row[3],
                        'left_weight': set_row[4],
                        'right_weight': set_row[5],
                        'created_at': set_row[6]
                    }
                    sets.append(set_dict)
                
                action_dict['sets'] = sets
                actions.append(action_dict)
            
            plan_dict['actions'] = actions
            conn.close()
            return plan_dict
            
        except PlanError:
            raise
        except Exception as e:
            raise PlanError(
                get_error_message('SERVER_ERROR', language),
                PlanErrorCode.SERVER_ERROR,
                'SERVER_ERROR'
            )
    
    def create_plan(self, plan_data: Dict[str, Any], user_id: int, language: str = 'zh_CN') -> int:
        """创建新的训练计划"""
        try:
            # 验证数据
            if not plan_data.get('name', '').strip():
                raise PlanError(
                    get_error_message('PLAN_NAME_EMPTY', language),
                    PlanErrorCode.INVALID_REQUEST,
                    'PLAN_NAME_EMPTY'
                )
            
            actions_data = plan_data.get('actions', [])
            if not actions_data:
                raise PlanError(
                    get_error_message('NO_ACTIONS', language),
                    PlanErrorCode.INVALID_REQUEST,
                    'NO_ACTIONS'
                )
            
            conn = get_db_connection()
            cursor = conn.cursor()
            
            try:
                # 开始事务
                cursor.execute("BEGIN TRANSACTION")
                
                # 1. 创建训练计划
                cursor.execute("""
                    INSERT INTO training_plans (name, description, difficulty, duration, user_id, is_template, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, 0, ?, ?)
                """, (
                    plan_data['name'],
                    plan_data.get('description', ''),
                    plan_data.get('difficulty', ''),
                    plan_data.get('duration', 0),
                    user_id,
                    datetime.now().isoformat(),
                    datetime.now().isoformat()
                ))
                
                plan_id = cursor.lastrowid
                
                # 2. 添加动作和组数据
                for order, action_data in enumerate(actions_data, 1):
                    action_id = action_data['action_id']
                    sets_data = action_data.get('sets', [])
                    record_bilateral = action_data.get('record_bilateral', False)
                    
                    # 计算总容量
                    total_volume = self.calculate_action_volume(sets_data, record_bilateral)
                    
                    # 插入plan_actions
                    cursor.execute("""
                        INSERT INTO plan_actions (plan_id, action_id, user_id, `order`, sets, rest, note, record_bilateral, weight)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, (
                        plan_id,
                        action_id,
                        user_id,
                        order,
                        len(sets_data),
                        action_data.get('rest', 60),
                        action_data.get('note', ''),
                        1 if record_bilateral else 0,
                        total_volume
                    ))
                    
                    # 插入plan_sets
                    for set_number, set_data in enumerate(sets_data, 1):
                        if record_bilateral:
                            # 双侧训练
                            cursor.execute("""
                                INSERT INTO plan_sets (plan_id, action_id, set_number, weight, reps, left_weight, right_weight, created_at)
                                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                            """, (
                                plan_id,
                                action_id,
                                set_number,
                                0,  # 双侧训练时weight字段设为0
                                set_data.get('reps', 12),
                                set_data.get('left_weight', 0),  # 确保不为NULL
                                set_data.get('right_weight', 0),  # 确保不为NULL
                                datetime.now().isoformat()
                            ))
                        else:
                            # 普通训练
                            cursor.execute("""
                                INSERT INTO plan_sets (plan_id, action_id, set_number, weight, reps, left_weight, right_weight, created_at)
                                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                            """, (
                                plan_id,
                                action_id,
                                set_number,
                                set_data.get('weight', 0),
                                set_data.get('reps', 12),
                                0,  # 普通训练时left_weight设为0
                                0,  # 普通训练时right_weight设为0
                                datetime.now().isoformat()
                            ))
                
                # 提交事务
                cursor.execute("COMMIT")
                conn.close()
                return plan_id
                
            except Exception as e:
                # 回滚事务
                cursor.execute("ROLLBACK")
                raise e
                
        except PlanError:
            raise
        except Exception as e:
            raise PlanError(
                get_error_message('SERVER_ERROR', language),
                PlanErrorCode.SERVER_ERROR,
                'SERVER_ERROR'
            )
    
    def copy_template_plan(self, template_id: int, user_id: int, language: str = 'zh_CN') -> int:
        """从模板复制计划"""
        try:
            # 获取模板计划详情
            template_plan = self.get_plan_detail(template_id, None, language)
            
            # 验证是否为模板计划
            if not template_plan.get('is_template', False):
                raise PlanError(
                    get_error_message('TEMPLATE_NOT_FOUND', language),
                    PlanErrorCode.NOT_FOUND,
                    'TEMPLATE_NOT_FOUND'
                )
            
            # 构造新计划数据
            new_plan_data = {
                'name': f"{template_plan['name']} - 副本",
                'description': template_plan.get('description', ''),
                'difficulty': template_plan.get('difficulty', ''),
                'duration': template_plan.get('duration', 0),
                'actions': []
            }
            
            # 复制动作数据
            for action in template_plan.get('actions', []):
                action_data = {
                    'action_id': action['action_id'],
                    'rest': action.get('rest', 60),
                    'note': action.get('note', ''),
                    'record_bilateral': action.get('record_bilateral', False),
                    'sets': []
                }
                
                # 复制组数据
                for set_data in action.get('sets', []):
                    new_set = {
                        'weight': set_data.get('weight', 0),
                        'reps': set_data.get('reps', 12),
                        'left_weight': set_data.get('left_weight'),
                        'right_weight': set_data.get('right_weight')
                    }
                    action_data['sets'].append(new_set)
                
                new_plan_data['actions'].append(action_data)
            
            # 创建新计划
            return self.create_plan(new_plan_data, user_id, language)
            
        except PlanError:
            raise
        except Exception as e:
            raise PlanError(
                get_error_message('SERVER_ERROR', language),
                PlanErrorCode.SERVER_ERROR,
                'SERVER_ERROR'
            )
    
    def update_plan(self, plan_id: int, plan_data: Dict[str, Any], user_id: int, language: str = 'zh_CN') -> bool:
        """更新训练计划"""
        try:
            # 验证计划存在和权限
            existing_plan = self.get_plan_detail(plan_id, user_id, language)
            
            # 验证数据
            if not plan_data.get('name', '').strip():
                raise PlanError(
                    get_error_message('PLAN_NAME_EMPTY', language),
                    PlanErrorCode.INVALID_REQUEST,
                    'PLAN_NAME_EMPTY'
                )
            
            actions_data = plan_data.get('actions', [])
            if not actions_data:
                raise PlanError(
                    get_error_message('NO_ACTIONS', language),
                    PlanErrorCode.INVALID_REQUEST,
                    'NO_ACTIONS'
                )
            
            conn = get_db_connection()
            cursor = conn.cursor()
            
            try:
                # 开始事务
                cursor.execute("BEGIN TRANSACTION")
                
                # 1. 更新计划基本信息
                cursor.execute("""
                    UPDATE training_plans 
                    SET name = ?, description = ?, difficulty = ?, duration = ?, updated_at = ?
                    WHERE id = ? AND user_id = ?
                """, (
                    plan_data['name'],
                    plan_data.get('description', ''),
                    plan_data.get('difficulty', ''),
                    plan_data.get('duration', 0),
                    datetime.now().isoformat(),
                    plan_id,
                    user_id
                ))
                
                # 2. 删除旧的动作和组数据
                cursor.execute("DELETE FROM plan_sets WHERE plan_id = ?", (plan_id,))
                cursor.execute("DELETE FROM plan_actions WHERE plan_id = ?", (plan_id,))
                
                # 3. 添加新的动作和组数据
                for order, action_data in enumerate(actions_data, 1):
                    action_id = action_data['action_id']
                    sets_data = action_data.get('sets', [])
                    record_bilateral = action_data.get('record_bilateral', False)
                    
                    # 计算总容量
                    total_volume = self.calculate_action_volume(sets_data, record_bilateral)
                    
                    # 插入plan_actions
                    cursor.execute("""
                        INSERT INTO plan_actions (plan_id, action_id, user_id, `order`, sets, rest, note, record_bilateral, weight)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, (
                        plan_id,
                        action_id,
                        user_id,
                        order,
                        len(sets_data),
                        action_data.get('rest', 60),
                        action_data.get('note', ''),
                        1 if record_bilateral else 0,
                        total_volume
                    ))
                    
                    # 插入plan_sets
                    for set_number, set_data in enumerate(sets_data, 1):
                        if record_bilateral:
                            # 双侧训练
                            cursor.execute("""
                                INSERT INTO plan_sets (plan_id, action_id, set_number, weight, reps, left_weight, right_weight, created_at)
                                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                            """, (
                                plan_id,
                                action_id,
                                set_number,
                                0,  # 双侧训练时weight字段设为0
                                set_data.get('reps', 12),
                                set_data.get('left_weight', 0),
                                set_data.get('right_weight', 0),
                                datetime.now().isoformat()
                            ))
                        else:
                            # 普通训练
                            cursor.execute("""
                                INSERT INTO plan_sets (plan_id, action_id, set_number, weight, reps, left_weight, right_weight, created_at)
                                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                            """, (
                                plan_id,
                                action_id,
                                set_number,
                                set_data.get('weight', 0),
                                set_data.get('reps', 12),
                                0,  # 普通训练时left_weight设为0
                                0,  # 普通训练时right_weight设为0
                                datetime.now().isoformat()
                            ))
                
                # 提交事务
                cursor.execute("COMMIT")
                conn.close()
                return True
                
            except Exception as e:
                # 回滚事务
                cursor.execute("ROLLBACK")
                raise e
                
        except PlanError:
            raise
        except Exception as e:
            raise PlanError(
                get_error_message('SERVER_ERROR', language),
                PlanErrorCode.SERVER_ERROR,
                'SERVER_ERROR'
            )
    
    def delete_plan(self, plan_id: int, user_id: int, language: str = 'zh_CN') -> bool:
        """删除训练计划"""
        try:
            # 验证计划存在和权限
            existing_plan = self.get_plan_detail(plan_id, user_id, language)
            
            # 检查计划是否正在使用中
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # 检查是否有进行中的训练会话
            cursor.execute("""
                SELECT COUNT(*) FROM training_sessions 
                WHERE plan_id = ? AND user_id = ? AND status = 'in_progress'
            """, (plan_id, user_id))
            
            if cursor.fetchone()[0] > 0:
                raise PlanError(
                    get_error_message('PLAN_IN_USE', language),
                    PlanErrorCode.CONFLICT,
                    'PLAN_IN_USE'
                )
            
            try:
                # 开始事务
                cursor.execute("BEGIN TRANSACTION")
                
                # 删除相关数据
                cursor.execute("DELETE FROM plan_sets WHERE plan_id = ?", (plan_id,))
                cursor.execute("DELETE FROM plan_actions WHERE plan_id = ?", (plan_id,))
                cursor.execute("DELETE FROM training_plans WHERE id = ? AND user_id = ?", (plan_id, user_id))
                
                # 提交事务
                cursor.execute("COMMIT")
                conn.close()
                return True
                
            except Exception as e:
                # 回滚事务
                cursor.execute("ROLLBACK")
                raise e
                
        except PlanError:
            raise
        except Exception as e:
            raise PlanError(
                get_error_message('SERVER_ERROR', language),
                PlanErrorCode.SERVER_ERROR,
                'SERVER_ERROR'
            ) 