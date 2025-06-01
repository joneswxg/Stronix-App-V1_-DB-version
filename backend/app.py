from flask import Flask
from flask import Blueprint
from src.stronix.routes.ActionRoute import action_bp
from src.stronix.routes.database import database_bp
from src.stronix.routes.AuthRoute import auth_bp
import os

app = Flask(__name__)

# 注册蓝图
app.register_blueprint(action_bp)
app.register_blueprint(database_bp, url_prefix='/api')
app.register_blueprint(auth_bp, url_prefix='/api/auth')

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
