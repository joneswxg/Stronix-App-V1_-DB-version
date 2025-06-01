from flask import Blueprint
from src.stronix.services.database.db_service import query, execute, health

database_bp = Blueprint('database', __name__)

@database_bp.route('/query')
def query_route():
    return query()

@database_bp.route('/execute', methods=['POST'])
def execute_route():
    return execute()

@database_bp.route('/health')
def health_route():
    return health()
