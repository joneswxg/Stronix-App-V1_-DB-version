from flask import Flask
from flask import Blueprint
from src.stronix.routes.ActionRoute import action_bp
from src.stronix.routes.database import database_bp
from src.stronix.routes.AuthRoute import auth_bp
from src.stronix.routes.PlanRoutes import plan_bp
from src.stronix.routes.TrainingHistoryRoutes import training_history_bp
from src.stronix.routes.BodyMeasurementRoutes import body_measurement_bp
import os

app = Flask(__name__)

# 设置会话密钥（用于session）
app.secret_key = 'your-secret-key-here'  # 在生产环境中应该使用更安全的密钥

# 注册蓝图
app.register_blueprint(action_bp)
app.register_blueprint(database_bp, url_prefix='/api')
app.register_blueprint(auth_bp, url_prefix='/api/auth')
app.register_blueprint(plan_bp)  # 计划蓝图已经包含了 /api/plans 前缀
app.register_blueprint(training_history_bp)  # 训练历史蓝图已经包含了 /api/training 前缀
app.register_blueprint(body_measurement_bp)  # 体测蓝图已经包含了 /api/body-measurements 前缀

if __name__ == "__main__":
    # 禁用 Flask 的默认输出
    import logging
    log = logging.getLogger('werkzeug')
    log.setLevel(logging.ERROR)
    
    # 禁用 Flask 启动时的 banner 和调试信息
    import click
    click.echo = lambda *args, **kwargs: None
    click.secho = lambda *args, **kwargs: None
    
    print("Starting Flask server...")
    print(f"Debug mode: {app.debug}")
    print(f"Registered blueprints: {app.blueprints.keys()}")
    print("Server will be available at:")
    print("  - http://127.0.0.1:6000")
    print("  - http://localhost:6000")
    print("  - http://0.0.0.0:6000")
    print("Press CTRL+C to quit")
    print("-" * 50)
    
    app.run(host="0.0.0.0", port=6000, debug=False)
