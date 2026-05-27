#!/bin/bash
# =============================================================================
# 告警模拟脚本 — 触发 Prometheus 告警规则进行演示验证
#
# 模拟场景:
#   1. 容器 CPU 飙升 → ContainerHighCPU
#   2. 容器内存超标 → ContainerHighMemory
#   3. 服务下线     → TargetDown
#   4. 容器重启     → ContainerRestarted
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROMETHEUS_URL="http://localhost:9090"
GRAFANA_URL="http://localhost:3000"
NETWORK="monitor-system_monitor-net"

# ── Helpers ────────────────────────────────────────────────────

check_alerts() {
    echo -e "${YELLOW}[*] 当前触发中的告警:${NC}"
    curl -s "${PROMETHEUS_URL}/api/v1/alerts" \
        | python3 -c "
import sys, json
data = json.load(sys.stdin)
firing = [a for a in data['data']['alerts'] if a['state'] == 'firing']
if not firing:
    print('  (无告警 — 系统正常)')
else:
    for a in firing:
        labels = a['labels']
        print(f\"  [{labels.get('severity','?')}] {labels['alertname']}: {a['annotations'].get('summary','')}\")
" 2>/dev/null || echo "  (无法查询 Prometheus，请确认集群在运行)"
    echo
}

cleanup_stress() {
    echo -e "${YELLOW}[清理] 移除模拟容器...${NC}"
    docker rm -f stress-cpu stress-cpu2 stress-mem stress-mem2 2>/dev/null || true
    echo
}

# ── Main ───────────────────────────────────────────────────────

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Prometheus 告警模拟 — 安全监控演示                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# 0. Check prerequisites
if ! docker ps >/dev/null 2>&1; then
    echo -e "${RED}[ERROR] Docker 未运行${NC}"
    exit 1
fi

# 1. Clean any leftover stress containers
cleanup_stress

# 2. Baseline
echo "────────── 阶段 0: 基线状态 ──────────"
echo "  确保 no services alarm..."
sleep 2
check_alerts

# 3. CPU Stress
echo "────────── 阶段 1: 模拟 CPU 异常 ──────────"
echo "  启动 2 个 CPU 压力容器 (各占 1 核)..."
docker run -d --name stress-cpu --network "${NETWORK}" \
    alpine sh -c "while true; do true; done" >/dev/null
docker run -d --name stress-cpu2 --network "${NETWORK}" \
    alpine sh -c "while true; do true; done" >/dev/null
echo "  stress-cpu & stress-cpu2 已启动"
echo "  等待 ContainerHighCPU 告警触发 (约 2+ min, 需 rate 累积 + for 2m)..."
echo ""

# 4. Memory Stress
echo "────────── 阶段 2: 模拟内存异常 ──────────"
echo "  启动内存压力容器 (分配 800MB)..."
docker run -d --name stress-mem --network "${NETWORK}" \
    alpine sh -c "dd if=/dev/zero of=/dev/shm/big bs=1M count=800 2>/dev/null; sleep 600" >/dev/null
echo "  stress-mem 已启动 (800MB)"
echo "  等待 ContainerHighMemory 告警触发 (约 2+ min)..."
echo ""

echo "══════════════════════════════════════════════════════════════"
echo "  等待 3 分钟让告警规则评估..."
echo "  提示: 可在 Grafana (${GRAFANA_URL}) 仪表盘 '安全告警面板' 中实时观察"
echo "  或在 Prometheus (${PROMETHEUS_URL}/alerts) 查看告警状态"
echo "══════════════════════════════════════════════════════════════"
echo ""

for i in $(seq 180 -10 10); do
    printf "\r  剩余 %3d 秒..." "$i"
    sleep 10
done
echo ""
echo ""

check_alerts

# 5. Target Down
echo "────────── 阶段 3: 模拟服务下线 ──────────"
echo "  暂停 node-exporter (触发 TargetDown)..."
docker stop node-exporter 2>/dev/null
echo "  node-exporter 已暂停"
echo "  等待 TargetDown 告警触发 (for 1m)..."
echo ""

for i in $(seq 60 -10 10); do
    printf "\r  剩余 %3d 秒..." "$i"
    sleep 10
done
echo ""
echo ""

check_alerts

# 6. Restart node-exporter
echo "  恢复 node-exporter..."
docker start node-exporter 2>/dev/null
sleep 5
echo "  node-exporter 已恢复"
echo ""

check_alerts

# 7. Container Restart
echo "────────── 阶段 4: 模拟容器重启 ──────────"
echo "  重启 cadvisor (触发 ContainerRestarted)..."
docker restart cadvisor 2>/dev/null
sleep 8
echo "  cadvisor 已重启"
echo ""

check_alerts

# 8. Cleanup
echo "────────── 清理 ──────────"
cleanup_stress
echo ""

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  模拟完成。请在以下地址查看告警历史:                       ║"
echo "║    Prometheus Alerts: ${PROMETHEUS_URL}/alerts          ║"
echo "║    Grafana Dashboard: ${GRAFANA_URL}                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
