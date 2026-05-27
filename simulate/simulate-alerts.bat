@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM =============================================================================
REM 告警模拟脚本 (Windows) — 触发 Prometheus 告警规则进行演示验证
REM =============================================================================

set PROMETHEUS_URL=http://localhost:9090
set GRAFANA_URL=http://localhost:3000
set NETWORK=monitor-system_monitor-net

echo ╔══════════════════════════════════════════════════════════════╗
echo ║  Prometheus 告警模拟 — 安全监控演示                        ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.

REM ---- Check Docker ----
docker ps >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Docker 未运行
    pause
    exit /b 1
)

REM ---- Cleanup leftover stress containers ----
echo [清理] 移除旧的模拟容器...
docker rm -f stress-cpu stress-cpu2 stress-mem 2>nul
echo.

REM ---- Phase 0: Baseline ----
echo ────────── 阶段 0: 基线状态 ──────────
echo   当前触发中的告警 (查看 http://localhost:9090/alerts ):
echo.

REM ---- Phase 1: CPU Stress ----
echo ────────── 阶段 1: 模拟 CPU 异常 ──────────
echo   启动 2 个 CPU 压力容器...
docker run -d --name stress-cpu --network %NETWORK% alpine sh -c "while true; do true; done" >nul
docker run -d --name stress-cpu2 --network %NETWORK% alpine sh -c "while true; do true; done" >nul
echo   stress-cpu ^& stress-cpu2 已启动 (各占约 1 核)
echo   等待 ContainerHighCPU 告警触发 (约 3 分钟)...
echo.

REM ---- Phase 2: Memory Stress ----
echo ────────── 阶段 2: 模拟内存异常 ──────────
echo   启动内存压力容器 (分配 800MB)...
docker run -d --name stress-mem --network %NETWORK% alpine sh -c "dd if=/dev/zero of=/dev/shm/big bs=1M count=800 2>/dev/null; sleep 600" >nul
echo   stress-mem 已启动 (800MB)
echo   等待 ContainerHighMemory 告警触发 (约 3 分钟)...
echo.

echo ══════════════════════════════════════════════════════════════
echo   等待 3 分钟让告警评估...
echo.
echo   在此期间可打开以下页面观察:
echo     Grafana 仪表盘: %GRAFANA_URL%
echo          → 底部 "安全告警面板" 行查看告警变化
echo     Prometheus Alerts: %PROMETHEUS_URL%/alerts
echo.
echo ══════════════════════════════════════════════════════════════
timeout /t 180 /nobreak
echo.
echo.

REM ---- Phase 3: Target Down ----
echo ────────── 阶段 3: 模拟服务下线 ──────────
echo   暂停 node-exporter (触发 TargetDown 告警)...
docker stop node-exporter >nul
echo   node-exporter 已暂停
echo   等待 TargetDown 告警触发 (约 1 分钟)...
timeout /t 65 /nobreak
echo.

echo   恢复 node-exporter...
docker start node-exporter >nul
echo   node-exporter 已恢复
timeout /t 5 /nobreak
echo.

REM ---- Phase 4: Container Restart ----
echo ────────── 阶段 4: 模拟容器重启 ──────────
echo   重启 cadvisor (触发 ContainerRestarted 告警)...
docker restart cadvisor >nul
timeout /t 10 /nobreak
echo   cadvisor 已重启
echo.

REM ---- Cleanup ----
echo ────────── 清理 ──────────
docker rm -f stress-cpu stress-cpu2 stress-mem 2>nul
echo.

echo ╔══════════════════════════════════════════════════════════════╗
echo ║  模拟完成。请在以下地址查看告警历史:                       ║
echo ║    Prometheus Alerts: %PROMETHEUS_URL%/alerts               ║
echo ║    Grafana Dashboard: %GRAFANA_URL%                         ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.

echo 按任意键退出...
pause >nul
