@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM =============================================================================
REM 实时告警监控面板 (Windows) — 运行时持续刷新，Ctrl+C 退出
REM =============================================================================

set PROMETHEUS_URL=http://localhost:9090
set REFRESH=5

:loop
cls
echo ╔══════════════════════════════════════════════════════════════════════════╗
echo ║  Prometheus 实时告警监控面板   刷新间隔: %REFRESH%s    %time:~0,8%  ║
echo ╠══════════════════════════════════════════════════════════════════════════╣

REM ---- Docker check ----
docker ps >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo   [ERROR] Docker 未运行
    goto :wait
)

REM ---- Container status ----
echo   ── 容器状态 ──
docker ps --format "table {{.Names}}\t{{.Status}}" 2>nul | findstr /C:"prometheus" /C:"grafana" /C:"alertmanager" /C:"node-exporter" /C:"cadvisor"
echo.

REM ---- Alert status ----
echo   ── 告警状态 ──
curl -s "%PROMETHEUS_URL%/api/v1/alerts" 2>nul | python3 -c "import sys,json; data=json.load(sys.stdin); alerts=data['data']['alerts']; firing=[a for a in alerts if a['state']=='firing']; pending=[a for a in alerts if a['state']=='pending']; [print('  [FIRING]  ['+a['labels'].get('severity','?')+'] '+a['labels']['alertname']+' — '+a['annotations'].get('summary','')[:60]) for a in firing]; [print('  [PENDING] ['+a['labels'].get('severity','?')+'] '+a['labels']['alertname']+' — '+a['annotations'].get('summary','')[:60]) for a in pending]; print('  系统正常，无告警') if not firing and not pending else None" 2>nul || echo   (无法连接 Prometheus)

echo.
echo ╚══════════════════════════════════════════════════════════════════════════╝
echo   Ctrl+C 退出 ^| Grafana: http://localhost:3000 ^| Prometheus: http://localhost:9090/alerts

:wait
timeout /t %REFRESH% /nobreak >nul
goto :loop
