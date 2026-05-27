@echo off
chcp 65001 >nul

echo ================================================================
echo   基于 Docker 构建 Prometheus+Grafana 监控集群
echo   北京邮电大学 信息安全编程技术与实例开发 课程设计 — 选题4
echo ================================================================
echo.

REM ---- Check Docker ----
docker ps >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Docker Desktop 未启动，请先启动 Docker Desktop。
    pause
    exit /b 1
)

REM ---- Pull latest images (optional, comment out if already pulled) ----
echo [1/3] 拉取镜像...
docker pull prom/prometheus:v2.51.0
docker pull grafana/grafana:10.4.0
docker pull prom/node-exporter:v1.7.0
docker pull prom/alertmanager:v0.27.0
echo.

REM ---- Stop & remove existing containers ----
echo [2/3] 启动监控集群...
docker compose down 2>nul
docker compose up -d
echo.

REM ---- Wait for services ----
echo [3/3] 等待服务就绪...
timeout /t 8 /nobreak >nul

echo.
echo ================================================================
echo   集群启动完成！
echo.
echo   访问地址 (默认账号密码 admin/admin):
echo     Grafana:       http://localhost:3000
echo     Prometheus:    http://localhost:9090
echo     Alertmanager:  http://localhost:9093
echo     Node Exporter: http://localhost:9100/metrics
echo     cAdvisor:      http://localhost:8080/containers
echo.
echo   [安全监控告警已配置] 查看:
echo     Prometheus Alerts: http://localhost:9090/alerts
echo     Grafana Dashboard: http://localhost:3000  (仪表盘自动加载)
echo ================================================================

REM ---- Open Grafana ----
start http://localhost:3000

echo.
echo 按任意键停止集群并退出...
pause >nul
docker compose down
echo 集群已停止。
pause
