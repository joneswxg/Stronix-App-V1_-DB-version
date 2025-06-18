import sqlite3
from datetime import datetime, timedelta
from typing import List, Optional, Tuple
import logging
from ..services.database.db_service import get_db_connection
from ..models.BodyMeasurementModels import (
    CreateBodyMeasurementRequest,
    UpdateBodyMeasurementRequest,
    BodyMeasurementRecord,
    BodyMeasurementQuery,
    BodyMeasurementStatistics
)

logger = logging.getLogger(__name__)


class BodyMeasurementService:
    """体测数据服务类"""

    @staticmethod
    def create_measurement(request: CreateBodyMeasurementRequest) -> int:
        """
        创建新的体测记录
        
        Args:
            request: 创建体测记录的请求数据
            
        Returns:
            int: 创建的记录ID
            
        Raises:
            Exception: 数据库操作异常
        """
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # 格式化时间戳
            timestamp_str = request.measurement_timestamp.strftime('%Y-%m-%d %H:%M:%S')
            
            sql = """
            INSERT INTO body_measurements 
            (user_id, measurement_timestamp, weight_kg, height_cm, body_fat_percentage, 
             skeletal_muscle_mass_kg, visceral_fat_level)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """
            
            cursor.execute(sql, (
                request.user_id,
                timestamp_str,
                request.weight_kg,
                request.height_cm,
                request.body_fat_percentage,
                request.skeletal_muscle_mass_kg,
                request.visceral_fat_level
            ))
            
            conn.commit()
            measurement_id = cursor.lastrowid
            conn.close()
            
            logger.info(f"创建体测记录成功，ID: {measurement_id}, 用户ID: {request.user_id}")
            return measurement_id
            
        except Exception as e:
            logger.error(f"创建体测记录失败: {e}")
            raise e

    @staticmethod
    def get_user_measurements(query: BodyMeasurementQuery) -> Tuple[List[BodyMeasurementRecord], int]:
        """
        获取用户的体测记录
        
        Args:
            query: 查询参数
            
        Returns:
            Tuple[List[BodyMeasurementRecord], int]: (记录列表, 总数)
        """
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # 构建查询SQL
            base_sql = """
            SELECT id, user_id, measurement_timestamp, weight_kg, height_cm, 
                   body_fat_percentage, skeletal_muscle_mass_kg, visceral_fat_level,
                   created_at, updated_at
            FROM body_measurements 
            WHERE user_id = ?
            """
            
            count_sql = "SELECT COUNT(*) FROM body_measurements WHERE user_id = ?"
            
            params = [query.user_id]
            
            # 添加日期范围过滤
            if query.start_date:
                base_sql += " AND measurement_timestamp >= ?"
                count_sql += " AND measurement_timestamp >= ?"
                start_date_str = query.start_date.strftime('%Y-%m-%d %H:%M:%S')
                params.append(start_date_str)
            
            if query.end_date:
                base_sql += " AND measurement_timestamp <= ?"
                count_sql += " AND measurement_timestamp <= ?"
                end_date_str = query.end_date.strftime('%Y-%m-%d %H:%M:%S')
                params.append(end_date_str)
            
            # 获取总数
            cursor.execute(count_sql, params)
            total_count = cursor.fetchone()[0]
            
            # 添加排序
            base_sql += f" ORDER BY {query.order_by} {query.order_direction}"
            
            # 添加分页
            if query.limit:
                base_sql += " LIMIT ?"
                params.append(query.limit)
                
                if query.offset:
                    base_sql += " OFFSET ?"
                    params.append(query.offset)
            
            # 执行查询
            cursor.execute(base_sql, params)
            rows = cursor.fetchall()
            conn.close()
            
            # 转换为模型对象
            measurements = []
            for row in rows:
                measurement = BodyMeasurementRecord(
                    id=row['id'],
                    user_id=row['user_id'],
                    measurement_timestamp=datetime.strptime(row['measurement_timestamp'], '%Y-%m-%d %H:%M:%S'),
                    weight_kg=row['weight_kg'],
                    height_cm=row['height_cm'],
                    body_fat_percentage=row['body_fat_percentage'],
                    skeletal_muscle_mass_kg=row['skeletal_muscle_mass_kg'],
                    visceral_fat_level=row['visceral_fat_level'],
                    created_at=datetime.strptime(row['created_at'], '%Y-%m-%d %H:%M:%S'),
                    updated_at=datetime.strptime(row['updated_at'], '%Y-%m-%d %H:%M:%S')
                )
                measurements.append(measurement)
            
            logger.info(f"获取用户 {query.user_id} 的体测记录成功，共 {len(measurements)} 条")
            return measurements, total_count
            
        except Exception as e:
            logger.error(f"获取体测记录失败: {e}")
            raise e

    @staticmethod
    def get_measurement_by_id(measurement_id: int) -> Optional[BodyMeasurementRecord]:
        """
        根据ID获取单条体测记录
        
        Args:
            measurement_id: 记录ID
            
        Returns:
            Optional[BodyMeasurementRecord]: 体测记录或None
        """
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
                measurement = BodyMeasurementRecord(
                    id=row['id'],
                    user_id=row['user_id'],
                    measurement_timestamp=datetime.strptime(row['measurement_timestamp'], '%Y-%m-%d %H:%M:%S'),
                    weight_kg=row['weight_kg'],
                    height_cm=row['height_cm'],
                    body_fat_percentage=row['body_fat_percentage'],
                    skeletal_muscle_mass_kg=row['skeletal_muscle_mass_kg'],
                    visceral_fat_level=row['visceral_fat_level'],
                    created_at=datetime.strptime(row['created_at'], '%Y-%m-%d %H:%M:%S'),
                    updated_at=datetime.strptime(row['updated_at'], '%Y-%m-%d %H:%M:%S')
                )
                logger.info(f"获取体测记录成功，ID: {measurement_id}")
                return measurement
            
            logger.warning(f"体测记录不存在，ID: {measurement_id}")
            return None
            
        except Exception as e:
            logger.error(f"获取体测记录失败: {e}")
            raise e

    @staticmethod
    def update_measurement(measurement_id: int, request: UpdateBodyMeasurementRequest) -> bool:
        """
        更新体测记录
        
        Args:
            measurement_id: 记录ID
            request: 更新请求数据
            
        Returns:
            bool: 是否更新成功
        """
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # 构建动态更新SQL
            update_fields = []
            params = []
            
            if request.weight_kg is not None:
                update_fields.append("weight_kg = ?")
                params.append(request.weight_kg)
            if request.height_cm is not None:
                update_fields.append("height_cm = ?")
                params.append(request.height_cm)
            if request.body_fat_percentage is not None:
                update_fields.append("body_fat_percentage = ?")
                params.append(request.body_fat_percentage)
            if request.skeletal_muscle_mass_kg is not None:
                update_fields.append("skeletal_muscle_mass_kg = ?")
                params.append(request.skeletal_muscle_mass_kg)
            if request.visceral_fat_level is not None:
                update_fields.append("visceral_fat_level = ?")
                params.append(request.visceral_fat_level)
            
            if not update_fields:
                logger.warning(f"没有需要更新的字段，ID: {measurement_id}")
                return False
            
            update_fields.append("updated_at = CURRENT_TIMESTAMP")
            params.append(measurement_id)
            
            sql = f"UPDATE body_measurements SET {', '.join(update_fields)} WHERE id = ?"
            
            cursor.execute(sql, params)
            conn.commit()
            rows_affected = cursor.rowcount
            conn.close()
            
            success = rows_affected > 0
            if success:
                logger.info(f"更新体测记录成功，ID: {measurement_id}")
            else:
                logger.warning(f"体测记录不存在或无需更新，ID: {measurement_id}")
            
            return success
            
        except Exception as e:
            logger.error(f"更新体测记录失败: {e}")
            raise e

    @staticmethod
    def delete_measurement(measurement_id: int) -> bool:
        """
        删除体测记录
        
        Args:
            measurement_id: 记录ID
            
        Returns:
            bool: 是否删除成功
        """
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute("DELETE FROM body_measurements WHERE id = ?", (measurement_id,))
            conn.commit()
            rows_affected = cursor.rowcount
            conn.close()
            
            success = rows_affected > 0
            if success:
                logger.info(f"删除体测记录成功，ID: {measurement_id}")
            else:
                logger.warning(f"体测记录不存在，ID: {measurement_id}")
            
            return success
            
        except Exception as e:
            logger.error(f"删除体测记录失败: {e}")
            raise e

    @staticmethod
    def get_user_statistics(user_id: int, days: int = 30) -> BodyMeasurementStatistics:
        """
        获取用户体测数据统计
        
        Args:
            user_id: 用户ID
            days: 统计天数
            
        Returns:
            BodyMeasurementStatistics: 统计数据
        """
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # 获取最新记录
            latest_sql = """
            SELECT id, user_id, measurement_timestamp, weight_kg, height_cm, 
                   body_fat_percentage, skeletal_muscle_mass_kg, visceral_fat_level,
                   created_at, updated_at
            FROM body_measurements 
            WHERE user_id = ?
            ORDER BY measurement_timestamp DESC
            LIMIT 1
            """
            
            cursor.execute(latest_sql, (user_id,))
            latest_row = cursor.fetchone()
            
            latest_measurement = None
            if latest_row:
                latest_measurement = BodyMeasurementRecord(
                    id=latest_row['id'],
                    user_id=latest_row['user_id'],
                    measurement_timestamp=datetime.strptime(latest_row['measurement_timestamp'], '%Y-%m-%d %H:%M:%S'),
                    weight_kg=latest_row['weight_kg'],
                    height_cm=latest_row['height_cm'],
                    body_fat_percentage=latest_row['body_fat_percentage'],
                    skeletal_muscle_mass_kg=latest_row['skeletal_muscle_mass_kg'],
                    visceral_fat_level=latest_row['visceral_fat_level'],
                    created_at=datetime.strptime(latest_row['created_at'], '%Y-%m-%d %H:%M:%S'),
                    updated_at=datetime.strptime(latest_row['updated_at'], '%Y-%m-%d %H:%M:%S')
                )
            
            # 获取统计数据
            start_date = datetime.now() - timedelta(days=days)
            start_date_str = start_date.strftime('%Y-%m-%d %H:%M:%S')
            
            stats_sql = """
            SELECT 
                COUNT(*) as measurement_count,
                MIN(measurement_timestamp) as earliest_date,
                MAX(measurement_timestamp) as latest_date
            FROM body_measurements 
            WHERE user_id = ? AND measurement_timestamp >= ?
            """
            
            cursor.execute(stats_sql, (user_id, start_date_str))
            stats_row = cursor.fetchone()
            
            measurement_count = stats_row['measurement_count'] if stats_row else 0
            date_range_days = 0
            
            if stats_row and stats_row['earliest_date'] and stats_row['latest_date']:
                earliest = datetime.strptime(stats_row['earliest_date'], '%Y-%m-%d %H:%M:%S')
                latest = datetime.strptime(stats_row['latest_date'], '%Y-%m-%d %H:%M:%S')
                date_range_days = (latest - earliest).days
            
            # 计算趋势（简单的首末差值）
            weight_trend = None
            body_fat_trend = None
            muscle_mass_trend = None
            
            if measurement_count >= 2:
                trend_sql = """
                SELECT weight_kg, body_fat_percentage, skeletal_muscle_mass_kg
                FROM body_measurements 
                WHERE user_id = ? AND measurement_timestamp >= ?
                ORDER BY measurement_timestamp ASC
                LIMIT 1
                """
                
                cursor.execute(trend_sql, (user_id, start_date_str))
                earliest_row = cursor.fetchone()
                
                if earliest_row and latest_measurement:
                    weight_trend = latest_measurement.weight_kg - earliest_row['weight_kg']
                    body_fat_trend = latest_measurement.body_fat_percentage - earliest_row['body_fat_percentage']
                    muscle_mass_trend = latest_measurement.skeletal_muscle_mass_kg - earliest_row['skeletal_muscle_mass_kg']
            
            conn.close()
            
            statistics = BodyMeasurementStatistics(
                latest_measurement=latest_measurement,
                weight_trend=weight_trend,
                body_fat_trend=body_fat_trend,
                muscle_mass_trend=muscle_mass_trend,
                measurement_count=measurement_count,
                date_range_days=date_range_days
            )
            
            logger.info(f"获取用户 {user_id} 的体测统计成功")
            return statistics
            
        except Exception as e:
            logger.error(f"获取体测统计失败: {e}")
            raise e 