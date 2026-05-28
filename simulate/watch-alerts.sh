#!/bin/bash
# =============================================================================
# 实时告警监控面板 — 运行时持续刷新，Ctrl+C 退出
# =============================================================================

PROMETHEUS_URL="http://localhost:9090"
REFRESH=5

clear_tty() { clear; }

print_header() {
    echo "╔══════════════════════════════════════════════════════════════════════════╗"
    echo "║  Prometheus 实时告警监控面板   刷新间隔: ${REFRESH}s    $(date '+%H:%M:%S')  ║"
    echo "╠══════════════════════════════════════════════════════════════════════════╣"
}

print_footer() {
    echo "╚══════════════════════════════════════════════════════════════════════════╝"
    echo "  Ctrl+C 退出 | Grafana: http://localhost:3000 | Prometheus: http://localhost:9090/alerts"
}

# ── Main loop ─────────────────────────────────────────────────

trap 'echo ""; echo "监控面板已关闭。"; exit 0' INT

while true; do
    clear_tty
    print_header

    # Check Docker
    if ! docker ps >/dev/null 2>&1; then
        echo "  [ERROR] Docker 未运行"
        sleep "$REFRESH"
        continue
    fi

    # Container status
    echo "  ── 容器状态 ──"
    docker ps --format "  {{.Names:20s}} {{.Status}}" 2>/dev/null | grep -E "prometheus|grafana|alertmanager|node-exporter|cadvisor" || echo "  (无监控容器)"
    echo ""

    # Alert status from Prometheus
    echo "  ── 告警状态 ──"
    curl -s "${PROMETHEUS_URL}/api/v1/alerts" 2>/dev/null \
        | python3 -c "
import sys,json
data = json.load(sys.stdin)
alerts = data['data']['alerts']
firing = [a for a in alerts if a['state'] == 'firing']
pending = [a for a in alerts if a['state'] == 'pending']

if not firing and not pending:
    print('  系统正常，无告警 ✓')
else:
    if firing:
        for a in firing:
            labels = a['labels']
            sev = labels.get('severity','?')
            name = labels['alertname']
            summary = a['annotations'].get('summary','')
            print(f'  [FIRING]  [{sev:10s}] {name:25s} — {summary[:60]}')
    if pending:
        for a in pending:
            labels = a['labels']
            sev = labels.get('severity','?')
            name = labels['alertname']
            summary = a['annotations'].get('summary','')
            print(f'  [PENDING] [{sev:10s}] {name:25s} — {summary[:60]}')
" 2>/dev/null || echo "  (无法连接 Prometheus)"

    echo ""
    print_footer
    sleep "$REFRESH"
done
