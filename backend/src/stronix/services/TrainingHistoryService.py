import sqlite3
from typing import Dict, List, Optional, Any
from datetime import datetime
from ..database import get_db_connection
from ..models.TrainingHistoryModels import (
    TrainingHistoryError, TrainingHistoryErrorCode, get_error_message,
    SaveTrainingHistoryRequest, UpdatePlanFromTrainingRequest,
    TrainingHistoryResponse, TrainingHistoryDetailResponse
)

class TrainingHistoryService:
    """训练历史服务类"""
    
    def __init__(self):
        pass
    
    def save_training_history(self, history_data: Dict[str, Any], user_id: int, language: str = 'zh_CN') -> int:
        """保存训练历史"""
        try:
            # 验证请求数据
            request = SaveTrainingHistoryRequest.from_dict(history_data)
            
            # 验证必要字段
            if not request.plan_name or not request.training_date:
                raise TrainingHistoryError(
                    get_error_message('INVALID_TRAINING_DATA', language),
                    TrainingHistoryErrorCode.INVALID_REQUEST,
                    'INVALID_TRAINING_DATA'
                )
            
            conn = get_db_connection()
            cursor = conn.cursor()
            
            try:
                # 如果有plan_id，验证计划是否存在且属于用户
                if request.plan_id:
                    cursor.execute("""
                        SELECT id FROM training_plans 
                        WHERE id = ? AND user_id = ?
                    """, (request.plan_id, user_id))
                    
                    if not cursor.fetchone():
                        raise TrainingHistoryError(
                            get_error_message('PLAN_NOT_FOUND', language),
                            TrainingHistoryErrorCode.NOT_FOUND,
                            'PLAN_NOT_FOUND'
                        )
                
                # 插入训练历史主记录
                cursor.execute("""
                    INSERT INTO training_history (
                        user_id, plan_id, session_id, plan_name, plan_description,
                        training_date, volume, duration, note
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    user_id, request.plan_id, request.session_id, request.plan_name,
                    request.plan_description, request.training_date, request.volume,
                    request.duration, request.note
                ))
                
                history_id = cursor.lastrowid
                
                # 插入训练历史详情
                for detail in request.details:
                    cursor.execute("""
                        INSERT INTO training_history_details (
                            history_id, action_id, set_number, weight, weight_unit,
                            reps, difficulty, left_weight, right_weight, is_completed
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, (
                        history_id, detail.action_id, detail.set_number, detail.weight,
                        detail.weight_unit, detail.reps, detail.difficulty,
                        detail.left_weight, detail.right_weight, detail.is_completed
                    ))
                
                conn.commit()
                print(f"✅ 训练历史保存成功，ID: {history_id}")
                return history_id
                
            except sqlite3.Error as e:
                conn.rollback()
                print(f"❌ 数据库错误: {str(e)}")
                raise TrainingHistoryError(
                    get_error_message('SERVER_ERROR', language),
                    TrainingHistoryErrorCode.SERVER_ERROR,
                    'SERVER_ERROR'
                )
            finally:
                conn.close()
                
        except TrainingHistoryError:
            raise
        except Exception as e:
            print(f"❌ 保存训练历史时出错: {str(e)}")
            raise TrainingHistoryError(
                get_error_message('SERVER_ERROR', language),
                TrainingHistoryErrorCode.SERVER_ERROR,
                'SERVER_ERROR'
            )
    
    def update_plan_from_training(self, plan_id: int, plan_data: Dict[str, Any], user_id: int, language: str = 'zh_CN') -> None:
        """从训练更新计划"""
        try:
            # 验证请求数据
            request = UpdatePlanFromTrainingRequest.from_dict(plan_data)
            
            # 验证必要字段
            if not request.name:
                raise TrainingHistoryError(
                    get_error_message('INVALID_TRAINING_DATA', language),
                    TrainingHistoryErrorCode.INVALID_REQUEST,
                    'INVALID_TRAINING_DATA'
                )
            
            conn = get_db_connection()
            cursor = conn.cursor()
            
            try:
                # 验证计划是否存在且属于用户
                cursor.execute("""
                    SELECT id FROM training_plans 
                    WHERE id = ? AND user_id = ?
                """, (plan_id, user_id))
                
                if not cursor.fetchone():
                    raise TrainingHistoryError(
                        get_error_message('PLAN_NOT_FOUND', language),
                        TrainingHistoryErrorCode.NOT_FOUND,
                        'PLAN_NOT_FOUND'
                    )
                
                # 更新训练计划基本信息
                cursor.execute("""
                    UPDATE training_plans 
                    SET name = ?, description = ?, difficulty = ?, duration = ?, updated_at = CURRENT_TIMESTAMP
                    WHERE id = ? AND user_id = ?
                """, (request.name, request.description, request.difficulty, request.duration, plan_id, user_id))
                
                # 删除现有的计划动作和组数据
                cursor.execute("DELETE FROM plan_sets WHERE plan_id = ?", (plan_id,))
                cursor.execute("DELETE FROM plan_actions WHERE plan_id = ? AND user_id = ?", (plan_id, user_id))
                
                # 插入新的计划动作和组数据
                for action in request.actions:
                    # 插入计划动作
                    cursor.execute("""
                        INSERT INTO plan_actions (
                            plan_id, action_id, `order`, sets, rest, note, record_bilateral, user_id
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """, (
                        plan_id, action.action_id, action.order, len(action.sets),
                        action.rest, action.note, 1 if action.record_bilateral else 0, user_id
                    ))
                    
                    # 插入计划组数据
                    for set_data in action.sets:
                        # 对于双侧训练，weight字段设置为0；对于普通训练，使用实际重量
                        if action.record_bilateral:
                            weight_value = 0
                        else:
                            weight_value = set_data.weight if set_data.weight is not None else 0
                        
                        # 确保left_weight和right_weight不为NULL
                        left_weight_value = set_data.left_weight if set_data.left_weight is not None else 0
                        right_weight_value = set_data.right_weight if set_data.right_weight is not None else 0
                        
                        cursor.execute("""
                            INSERT INTO plan_sets (
                                plan_id, action_id, set_number, weight, reps, left_weight, right_weight
                            ) VALUES (?, ?, ?, ?, ?, ?, ?)
                        """, (
                            plan_id, action.action_id, set_data.order, weight_value,
                            set_data.reps, left_weight_value, right_weight_value
                        ))
                
                conn.commit()
                print(f"✅ 训练计划更新成功，计划ID: {plan_id}")
                
            except sqlite3.Error as e:
                conn.rollback()
                print(f"❌ 数据库错误: {str(e)}")
                raise TrainingHistoryError(
                    get_error_message('SERVER_ERROR', language),
                    TrainingHistoryErrorCode.SERVER_ERROR,
                    'SERVER_ERROR'
                )
            finally:
                conn.close()
                
        except TrainingHistoryError:
            raise
        except Exception as e:
            print(f"❌ 更新训练计划时出错: {str(e)}")
            raise TrainingHistoryError(
                get_error_message('SERVER_ERROR', language),
                TrainingHistoryErrorCode.SERVER_ERROR,
                'SERVER_ERROR'
            )
    
    def get_training_history(self, user_id: int, page: int = 1, limit: int = 20, plan_id: Optional[int] = None, start_date: Optional[str] = None, end_date: Optional[str] = None, language: str = 'zh_CN') -> Dict[str, Any]:
        """获取训练历史列表"""
        try:
            print(f"🔍 TrainingHistoryService.get_training_history 调用参数: user_id={user_id}, page={page}, limit={limit}, plan_id={plan_id}, start_date={start_date}, end_date={end_date}")
            
            conn = get_db_connection()
            cursor = conn.cursor()
            
            try:
                # 构建查询条件
                where_conditions = ["user_id = ?"]
                params = [user_id]
                
                if plan_id:
                    where_conditions.append("plan_id = ?")
                    params.append(plan_id)
                
                # 新增日期范围过滤条件
                if start_date and end_date:
                    where_conditions.append("DATE(training_date) BETWEEN DATE(?) AND DATE(?)")
                    params.append(start_date)
                    params.append(end_date)
                    print(f"📅 添加日期范围过滤条件: DATE(training_date) BETWEEN DATE({start_date}) AND DATE({end_date})")
                elif start_date:  # 如果只提供了开始日期，则视为单日查询
                    where_conditions.append("DATE(training_date) = DATE(?)")
                    params.append(start_date)
                    print(f"📅 添加单日过滤条件: DATE(training_date) = DATE({start_date})")
                
                where_clause = " AND ".join(where_conditions)
                print(f"🔍 SQL WHERE 子句: {where_clause}")
                print(f"🔍 SQL 参数: {params}")
                
                # 获取总数
                cursor.execute(f"""
                    SELECT COUNT(*) FROM training_history 
                    WHERE {where_clause}
                """, params)
                total = cursor.fetchone()[0]
                
                # 获取分页数据
                offset = (page - 1) * limit
                cursor.execute(f"""
                    SELECT id, plan_id, plan_name, training_date, volume, duration, note, created_at
                    FROM training_history 
                    WHERE {where_clause}
                    ORDER BY training_date DESC, created_at DESC
                    LIMIT ? OFFSET ?
                """, params + [limit, offset])
                
                histories = []
                for row in cursor.fetchall():
                    history = TrainingHistoryResponse(
                        id=row[0],
                        plan_id=row[1],
                        plan_name=row[2],
                        training_date=row[3],
                        volume=row[4],
                        duration=row[5],
                        note=row[6],
                        created_at=row[7]
                    )
                    histories.append(history.to_dict())
                
                return {
                    'histories': histories,
                    'pagination': {
                        'page': page,
                        'limit': limit,
                        'total': total,
                        'pages': (total + limit - 1) // limit
                    }
                }
                
            except sqlite3.Error as e:
                print(f"❌ 数据库错误: {str(e)}")
                raise TrainingHistoryError(
                    get_error_message('SERVER_ERROR', language),
                    TrainingHistoryErrorCode.SERVER_ERROR,
                    'SERVER_ERROR'
                )
            finally:
                conn.close()
                
        except TrainingHistoryError:
            raise
        except Exception as e:
            print(f"❌ 获取训练历史时出错: {str(e)}")
            raise TrainingHistoryError(
                get_error_message('SERVER_ERROR', language),
                TrainingHistoryErrorCode.SERVER_ERROR,
                'SERVER_ERROR'
            )
    
    def get_training_dates(self, user_id: int, start_date: str, end_date: str, language: str = 'zh_CN') -> Dict[str, Any]:
        """获取指定日期范围内有训练记录的日期列表"""
        try:
            print(f"🗓️ TrainingHistoryService.get_training_dates 调用参数: user_id={user_id}, start_date={start_date}, end_date={end_date}")
            
            conn = get_db_connection()
            cursor = conn.cursor()
            
            try:
                # 查询指定日期范围内的训练日期（去重）
                cursor.execute("""
                    SELECT DISTINCT DATE(training_date) as training_date
                    FROM training_history 
                    WHERE user_id = ? AND DATE(training_date) BETWEEN DATE(?) AND DATE(?)
                    ORDER BY training_date
                """, (user_id, start_date, end_date))
                
                training_dates = []
                for row in cursor.fetchall():
                    training_dates.append(row[0])
                
                print(f"✅ 查询到训练日期: {training_dates}")
                
                return {
                    'training_dates': training_dates,
                    'start_date': start_date,
                    'end_date': end_date,
                    'total_days': len(training_dates)
                }
                
            except sqlite3.Error as e:
                print(f"❌ 数据库错误: {str(e)}")
                raise TrainingHistoryError(
                    get_error_message('SERVER_ERROR', language),
                    TrainingHistoryErrorCode.SERVER_ERROR,
                    'SERVER_ERROR'
                )
            finally:
                conn.close()
                
        except TrainingHistoryError:
            raise
        except Exception as e:
            print(f"❌ 获取训练日期时出错: {str(e)}")
            raise TrainingHistoryError(
                get_error_message('SERVER_ERROR', language),
                TrainingHistoryErrorCode.SERVER_ERROR,
                'SERVER_ERROR'
            )
    
    def get_training_history_detail(self, history_id: int, user_id: int, language: str = 'zh_CN') -> Dict[str, Any]:
        """获取训练历史详情"""
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            try:
                # 获取训练历史基本信息
                cursor.execute("""
                    SELECT id, plan_id, plan_name, training_date, volume, duration, note, created_at
                    FROM training_history 
                    WHERE id = ? AND user_id = ?
                """, (history_id, user_id))
                
                history_row = cursor.fetchone()
                if not history_row:
                    raise TrainingHistoryError(
                        get_error_message('HISTORY_NOT_FOUND', language),
                        TrainingHistoryErrorCode.NOT_FOUND,
                        'HISTORY_NOT_FOUND'
                    )
                
                history = TrainingHistoryResponse(
                    id=history_row[0],
                    plan_id=history_row[1],
                    plan_name=history_row[2],
                    training_date=history_row[3],
                    volume=history_row[4],
                    duration=history_row[5],
                    note=history_row[6],
                    created_at=history_row[7]
                )
                
                # 获取训练历史详情
                cursor.execute("""
                    SELECT thd.action_id, thd.set_number, thd.weight, thd.weight_unit,
                           thd.reps, thd.difficulty, thd.left_weight, thd.right_weight,
                           thd.is_completed, a.name as action_name
                    FROM training_history_details thd
                    LEFT JOIN action a ON thd.action_id = a.id
                    WHERE thd.history_id = ?
                    ORDER BY thd.action_id, thd.set_number
                """, (history_id,))
                
                details = []
                for row in cursor.fetchall():
                    detail = {
                        'action_id': row[0],
                        'set_number': row[1],
                        'weight': row[2],
                        'weight_unit': row[3],
                        'reps': row[4],
                        'difficulty': row[5],
                        'left_weight': row[6],
                        'right_weight': row[7],
                        'is_completed': bool(row[8]),
                        'action_name': row[9]
                    }
                    details.append(detail)
                
                response = TrainingHistoryDetailResponse(
                    history=history,
                    details=details
                )
                
                return response.to_dict()
                
            except sqlite3.Error as e:
                print(f"❌ 数据库错误: {str(e)}")
                raise TrainingHistoryError(
                    get_error_message('SERVER_ERROR', language),
                    TrainingHistoryErrorCode.SERVER_ERROR,
                    'SERVER_ERROR'
                )
            finally:
                conn.close()
                
        except TrainingHistoryError:
            raise
        except Exception as e:
            print(f"❌ 获取训练历史详情时出错: {str(e)}")
            raise TrainingHistoryError(
                get_error_message('SERVER_ERROR', language),
                TrainingHistoryErrorCode.SERVER_ERROR,
                'SERVER_ERROR'
            ) 