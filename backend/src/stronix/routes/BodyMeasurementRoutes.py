from flask import Blueprint, request, jsonify
from datetime import datetime
import logging
from ..services.BodyMeasurementService import BodyMeasurementService
from ..models.BodyMeasurementModels import (
    CreateBodyMeasurementRequest,
    UpdateBodyMeasurementRequest,
    BodyMeasurementQuery,
    CreateBodyMeasurementResponse,
    UpdateBodyMeasurementResponse,
    DeleteBodyMeasurementResponse,
    BodyMeasurementListResponse,
    BodyMeasurementDetailResponse,
    ErrorResponse
)

logger = logging.getLogger(__name__)

# 创建蓝图
body_measurement_bp = Blueprint('body_measurement', __name__, url_prefix='/api/body-measurements')


@body_measurement_bp.route('', methods=['POST'])
def create_measurement():
    """创建新的体测记录"""
    try:
        data = request.get_json()
        
        # 验证必需字段
        required_fields = ['user_id', 'measurement_timestamp', 'weight_kg', 'height_cm', 
                          'body_fat_percentage', 'skeletal_muscle_mass_kg', 'visceral_fat_level']
        
        for field in required_fields:
            if field not in data:
                return jsonify(ErrorResponse(
                    error=f"缺少必需字段: {field}",
                    code="MISSING_FIELD"
                ).dict()), 400
        
        # 解析时间戳
        try:
            if isinstance(data['measurement_timestamp'], str):
                measurement_timestamp = datetime.strptime(data['measurement_timestamp'], '%Y-%m-%d %H:%M:%S')
            else:
                measurement_timestamp = data['measurement_timestamp']
        except ValueError as e:
            return jsonify(ErrorResponse(
                error="时间格式错误，应为 YYYY-MM-DD HH:MM:SS",
                detail=str(e),
                code="INVALID_TIMESTAMP"
            ).dict()), 400
        
        # 创建请求模型
        try:
            create_request = CreateBodyMeasurementRequest(
                user_id=data['user_id'],
                measurement_timestamp=measurement_timestamp,
                weight_kg=data['weight_kg'],
                height_cm=data['height_cm'],
                body_fat_percentage=data['body_fat_percentage'],
                skeletal_muscle_mass_kg=data['skeletal_muscle_mass_kg'],
                visceral_fat_level=data['visceral_fat_level']
            )
        except ValueError as e:
            return jsonify(ErrorResponse(
                error="数据验证失败",
                detail=str(e),
                code="VALIDATION_ERROR"
            ).dict()), 400
        
        # 创建记录
        measurement_id = BodyMeasurementService.create_measurement(create_request)
        
        response = CreateBodyMeasurementResponse(measurement_id=measurement_id)
        return jsonify(response.dict()), 200
        
    except Exception as e:
        logger.error(f"创建体测记录失败: {e}")
        return jsonify(ErrorResponse(
            error="创建体测记录失败",
            detail=str(e),
            code="CREATE_ERROR"
        ).dict()), 500


@body_measurement_bp.route('/<int:user_id>', methods=['GET'])
def get_user_measurements(user_id):
    """获取用户的体测记录"""
    try:
        # 获取查询参数
        limit = request.args.get('limit', type=int)
        offset = request.args.get('offset', type=int)
        start_date_str = request.args.get('start_date')
        end_date_str = request.args.get('end_date')
        order_by = request.args.get('order_by', 'measurement_timestamp')
        order_direction = request.args.get('order_direction', 'DESC')
        
        # 解析日期
        start_date = None
        end_date = None
        
        if start_date_str:
            try:
                start_date = datetime.strptime(start_date_str, '%Y-%m-%d %H:%M:%S')
            except ValueError:
                try:
                    start_date = datetime.strptime(start_date_str, '%Y-%m-%d')
                except ValueError:
                    return jsonify(ErrorResponse(
                        error="开始日期格式错误",
                        detail="应为 YYYY-MM-DD 或 YYYY-MM-DD HH:MM:SS",
                        code="INVALID_START_DATE"
                    ).dict()), 400
        
        if end_date_str:
            try:
                end_date = datetime.strptime(end_date_str, '%Y-%m-%d %H:%M:%S')
            except ValueError:
                try:
                    end_date = datetime.strptime(end_date_str, '%Y-%m-%d')
                    # 如果只提供日期，设置为当天的23:59:59
                    end_date = end_date.replace(hour=23, minute=59, second=59)
                except ValueError:
                    return jsonify(ErrorResponse(
                        error="结束日期格式错误",
                        detail="应为 YYYY-MM-DD 或 YYYY-MM-DD HH:MM:SS",
                        code="INVALID_END_DATE"
                    ).dict()), 400
        
        # 创建查询对象
        try:
            query = BodyMeasurementQuery(
                user_id=user_id,
                limit=limit,
                offset=offset,
                start_date=start_date,
                end_date=end_date,
                order_by=order_by,
                order_direction=order_direction
            )
        except ValueError as e:
            return jsonify(ErrorResponse(
                error="查询参数验证失败",
                detail=str(e),
                code="QUERY_VALIDATION_ERROR"
            ).dict()), 400
        
        # 获取数据
        measurements, total_count = BodyMeasurementService.get_user_measurements(query)
        
        # 转换为字典格式
        measurements_dict = []
        for measurement in measurements:
            measurement_dict = {
                'id': measurement.id,
                'user_id': measurement.user_id,
                'measurement_timestamp': measurement.measurement_timestamp.strftime('%Y-%m-%d %H:%M:%S'),
                'weight_kg': measurement.weight_kg,
                'height_cm': measurement.height_cm,
                'body_fat_percentage': measurement.body_fat_percentage,
                'skeletal_muscle_mass_kg': measurement.skeletal_muscle_mass_kg,
                'visceral_fat_level': measurement.visceral_fat_level,
                'created_at': measurement.created_at.strftime('%Y-%m-%d %H:%M:%S'),
                'updated_at': measurement.updated_at.strftime('%Y-%m-%d %H:%M:%S')
            }
            measurements_dict.append(measurement_dict)
        
        response = {
            'measurements': measurements_dict
        }
        
        return jsonify(response), 200
        
    except Exception as e:
        logger.error(f"获取体测记录失败: {e}")
        return jsonify(ErrorResponse(
            error="获取体测记录失败",
            detail=str(e),
            code="GET_ERROR"
        ).dict()), 500


@body_measurement_bp.route('/detail/<int:measurement_id>', methods=['GET'])
def get_measurement_detail(measurement_id):
    """获取单条体测记录详情"""
    try:
        measurement = BodyMeasurementService.get_measurement_by_id(measurement_id)
        
        if not measurement:
            return jsonify(ErrorResponse(
                error="体测记录不存在",
                code="NOT_FOUND"
            ).dict()), 404
        
        # 转换为字典格式
        measurement_dict = {
            'id': measurement.id,
            'user_id': measurement.user_id,
            'measurement_timestamp': measurement.measurement_timestamp.strftime('%Y-%m-%d %H:%M:%S'),
            'weight_kg': measurement.weight_kg,
            'height_cm': measurement.height_cm,
            'body_fat_percentage': measurement.body_fat_percentage,
            'skeletal_muscle_mass_kg': measurement.skeletal_muscle_mass_kg,
            'visceral_fat_level': measurement.visceral_fat_level,
            'created_at': measurement.created_at.strftime('%Y-%m-%d %H:%M:%S'),
            'updated_at': measurement.updated_at.strftime('%Y-%m-%d %H:%M:%S')
        }
        
        response = {'measurement': measurement_dict}
        return jsonify(response), 200
        
    except Exception as e:
        logger.error(f"获取体测记录详情失败: {e}")
        return jsonify(ErrorResponse(
            error="获取体测记录详情失败",
            detail=str(e),
            code="GET_DETAIL_ERROR"
        ).dict()), 500


@body_measurement_bp.route('/<int:measurement_id>', methods=['PUT'])
def update_measurement(measurement_id):
    """更新体测记录"""
    try:
        data = request.get_json()
        
        # 创建更新请求模型
        try:
            update_request = UpdateBodyMeasurementRequest(**data)
        except ValueError as e:
            return jsonify(ErrorResponse(
                error="数据验证失败",
                detail=str(e),
                code="VALIDATION_ERROR"
            ).dict()), 400
        
        # 更新记录
        success = BodyMeasurementService.update_measurement(measurement_id, update_request)
        
        if not success:
            return jsonify(ErrorResponse(
                error="体测记录不存在或无需更新",
                code="NOT_FOUND_OR_NO_CHANGE"
            ).dict()), 404
        
        response = UpdateBodyMeasurementResponse()
        return jsonify(response.dict()), 200
        
    except Exception as e:
        logger.error(f"更新体测记录失败: {e}")
        return jsonify(ErrorResponse(
            error="更新体测记录失败",
            detail=str(e),
            code="UPDATE_ERROR"
        ).dict()), 500


@body_measurement_bp.route('/<int:measurement_id>', methods=['DELETE'])
def delete_measurement(measurement_id):
    """删除体测记录"""
    try:
        success = BodyMeasurementService.delete_measurement(measurement_id)
        
        if not success:
            return jsonify(ErrorResponse(
                error="体测记录不存在",
                code="NOT_FOUND"
            ).dict()), 404
        
        response = DeleteBodyMeasurementResponse()
        return jsonify(response.dict()), 200
        
    except Exception as e:
        logger.error(f"删除体测记录失败: {e}")
        return jsonify(ErrorResponse(
            error="删除体测记录失败",
            detail=str(e),
            code="DELETE_ERROR"
        ).dict()), 500


@body_measurement_bp.route('/statistics/<int:user_id>', methods=['GET'])
def get_user_statistics(user_id):
    """获取用户体测数据统计"""
    try:
        days = request.args.get('days', default=30, type=int)
        
        if days <= 0 or days > 365:
            return jsonify(ErrorResponse(
                error="统计天数必须在1-365之间",
                code="INVALID_DAYS"
            ).dict()), 400
        
        statistics = BodyMeasurementService.get_user_statistics(user_id, days)
        
        # 转换为字典格式
        stats_dict = {
            'latest_measurement': None,
            'weight_trend': statistics.weight_trend,
            'body_fat_trend': statistics.body_fat_trend,
            'muscle_mass_trend': statistics.muscle_mass_trend,
            'measurement_count': statistics.measurement_count,
            'date_range_days': statistics.date_range_days
        }
        
        if statistics.latest_measurement:
            stats_dict['latest_measurement'] = {
                'id': statistics.latest_measurement.id,
                'user_id': statistics.latest_measurement.user_id,
                'measurement_timestamp': statistics.latest_measurement.measurement_timestamp.strftime('%Y-%m-%d %H:%M:%S'),
                'weight_kg': statistics.latest_measurement.weight_kg,
                'height_cm': statistics.latest_measurement.height_cm,
                'body_fat_percentage': statistics.latest_measurement.body_fat_percentage,
                'skeletal_muscle_mass_kg': statistics.latest_measurement.skeletal_muscle_mass_kg,
                'visceral_fat_level': statistics.latest_measurement.visceral_fat_level,
                'created_at': statistics.latest_measurement.created_at.strftime('%Y-%m-%d %H:%M:%S'),
                'updated_at': statistics.latest_measurement.updated_at.strftime('%Y-%m-%d %H:%M:%S')
            }
        
        return jsonify(stats_dict), 200
        
    except Exception as e:
        logger.error(f"获取体测统计失败: {e}")
        return jsonify(ErrorResponse(
            error="获取体测统计失败",
            detail=str(e),
            code="STATISTICS_ERROR"
        ).dict()), 500


# 错误处理
@body_measurement_bp.errorhandler(400)
def bad_request(error):
    return jsonify(ErrorResponse(
        error="请求参数错误",
        detail=str(error),
        code="BAD_REQUEST"
    ).dict()), 400


@body_measurement_bp.errorhandler(404)
def not_found(error):
    return jsonify(ErrorResponse(
        error="资源不存在",
        detail=str(error),
        code="NOT_FOUND"
    ).dict()), 404


@body_measurement_bp.errorhandler(500)
def internal_error(error):
    return jsonify(ErrorResponse(
        error="服务器内部错误",
        detail=str(error),
        code="INTERNAL_ERROR"
    ).dict()), 500 