# Monitor-System — 基于 Docker 的 Prometheus+Grafana 监控集群

北京邮电大学 信息安全编程技术与实例开发 课程设计 — 选题4

## 概述

基于 Docker Compose 一键部署 **Prometheus + Grafana** 全方位监控告警系统，覆盖主机、容器、网络三个维度的指标采集、可视化与安全告警。

## 架构

```
                        ┌─────────────────┐
                        │   Alertmanager   │
                        │   (告警路由)      │
                        │   :9093          │
                        └────────┬─────────┘
                                 ▲ 告警推送
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Node Exporter   │    │    cAdvisor      │    │     Grafana      │
│  (主机指标)       │    │   (容器指标)      │    │   (可视化看板)    │
│  :9100           │    │   :8080          │    │   :3000          │
└────────┬────────┘    └────────┬────────┘    └────────▲────────┘
         │                      │ Scrape               │ Query
         └──────────┬───────────┘                       │
                    ▼                                   │
         ┌─────────────────┐                            │
         │   Prometheus     │────────────────────────────┘
         │  (指标存储 + 告警) │
         │  :9090           │
         └─────────────────┘
```

## 服务清单

| 服务 | 镜像 | 端口 | 功能 |
|------|------|------|------|
| Prometheus | prom/prometheus:v2.51.0 | 9090 | 指标采集 + 时序存储 + 告警评估 |
| Grafana | grafana/grafana:10.4.0 | 3000 | 可视化看板，预置仪表盘 |
| Node Exporter | prom/node-exporter:v1.7.0 | 9100 | 主机级指标暴露 (CPU/内存/磁盘/网络) |
| cAdvisor | gcr.io/cadvisor/cadvisor:v0.47.2 | 8080 | 容器级指标暴露 (每个容器资源用量) |
| Alertmanager | prom/alertmanager:v0.27.0 | 9093 | 告警分组、抑制、路由 |

## 快速开始

### 前提

- Docker Desktop 已安装并运行
- 端口 3000 / 9090 / 9093 未被占用

### 启动

**Windows** — 双击 `build.bat`  
**Linux/Mac** — `bash build.sh`

或手动：

```bash
docker compose up -d
```

启动后自动打开 Grafana。停止集群：

```bash
docker compose down
```

### 告警模拟

启动集群后，运行模拟脚本触发告警进行演示验证：

**Windows** — 双击 `simulate/simulate-alerts.bat`  
**Linux/Mac** — `bash simulate/simulate-alerts.sh`

模拟场景：

| 阶段 | 操作 | 预期告警 | 等待 |
|------|------|----------|------|
| 1 | 启动 2 个 CPU 压力容器 | ContainerHighCPU | ~3 min |
| 2 | 启动内存压力容器 (800MB) | ContainerHighMemory | ~3 min |
| 3 | 暂停 node-exporter | TargetDown | ~1 min |
| 4 | 重启 cadvisor | ContainerRestarted | 即时 |

脚本自动触发、等待、检查、清理。运行期间可在 Grafana 仪表盘底部"安全告警面板"行实时观察告警变化。

### 实时监控面板

另开一个终端窗口，运行实时监控面板持续观察告警状态变化：

**Windows** — 双击 `simulate/watch-alerts.bat`  
**Linux/Mac** — `bash simulate/watch-alerts.sh`

每 5 秒自动刷新，显示容器运行状态 + 当前告警 (FIRING/PENDING)，Ctrl+C 退出。

### 访问地址

| 服务 | URL | 账号 |
|------|-----|------|
| Grafana | http://localhost:3000 | admin / admin |
| Prometheus | http://localhost:9090 | — |
| Alertmanager | http://localhost:9093 | — |
| Node Exporter Metrics | http://localhost:9100/metrics | — |
| cAdvisor | http://localhost:8080/containers | — |
| Prometheus Alerts | http://localhost:9090/alerts | — |

### 各服务使用指南

#### Grafana (可视化看板) — http://localhost:3000

1. 浏览器打开 `http://localhost:3000`，登录 `admin` / `admin`
2. 左侧菜单 → **Dashboards** → 点击 "**主机与容器安全监控**"
3. 仪表盘自动展示 CPU 仪表盘、内存曲线、网络流量、容器资源、告警面板
4. 顶部时间选择器可切换查看范围（最近 5 分钟 ~ 最近 30 天）
5. 仪表盘每 10 秒自动刷新

#### Prometheus (指标查询 + 告警) — http://localhost:9090

1. 打开 `http://localhost:9090`
2. **查指标**：搜索框输入指标名（如 `node_cpu_seconds_total`）→ 点击 Execute
3. **画图表**：输入查询表达式后切换到 Graph 标签页，例如：
   - `rate(node_network_receive_bytes_total[5m])` — 网络接收速率
   - `100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` — CPU 使用率
4. **看抓取目标**：Status → Targets，确认各采集目标状态为 UP
5. **看告警**：Alerts，查看 9 条规则中哪些已触发

#### cAdvisor (容器资源监控) — http://localhost:8080/containers

1. 打开 `http://localhost:8080/containers`
2. 首页列出所有运行中容器的实时 CPU / 内存 / 网络 / 文件系统用量
3. 点击某个容器名进入详情，可看到该容器的资源使用历史曲线
4. Subcontainers 展示容器内部进程级别的指标

#### Alertmanager (告警管理) — http://localhost:9093

1. 打开 `http://localhost:9093`
2. 查看当前触发的告警、已分组合并的告警
3. 告警由 Prometheus 自动评估并推送过来，通常无需手动操作

#### Node Exporter (主机原始指标) — http://localhost:9100/metrics

1. 打开 `http://localhost:9100/metrics`
2. 显示 Prometheus 抓取的原始主机指标（纯文本格式，供机器读取）
3. 这些数据的可视化通过 Prometheus → Grafana 图表完成，一般不直接访问此页面

> 日常使用只需关注 **Grafana (:3000)** 的仪表盘即可，其余服务为底层数据采集与存储。

## 告警规则 (9 条)

### 主机安全 (4)

| 告警 | 条件 | 级别 |
|------|------|------|
| CPU 高负载 | CPU > 80% 持续 5min | warning |
| 内存耗尽 | 内存使用率 > 85% 持续 5min | warning |
| 磁盘不足 | 磁盘可用 < 10% | critical |
| 磁盘 I/O 异常 | I/O > 100MB/s 持续 10min | warning |

### 网络安全 (2)

| 告警 | 条件 | 级别 |
|------|------|------|
| 入站流量激增 | 接收速率 > 100MB/s 持续 5min | warning |
| TCP 连接异常 | 当前连接数 > 1000 持续 5min | warning |

### 容器安全 (2)

| 告警 | 条件 | 级别 |
|------|------|------|
| 容器异常重启 | 10min 内检测到重启 | warning |
| 容器 CPU 滥用 | 容器 CPU 使用率异常偏高 | warning |

### 服务可用性 (1)

| 告警 | 条件 | 级别 |
|------|------|------|
| 目标下线 | 监控目标不可达 > 2min | critical |

## 项目结构

```
├── docker-compose.yml              # 服务编排
├── build.bat / build.sh            # 一键启动脚本
├── prometheus/
│   ├── prometheus.yml               # 采集配置
│   └── rules.yml                    # 告警规则 (10 条)
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/             # Prometheus 数据源自动配置
│   │   └── dashboards/              # 仪表盘自动加载配置
│   └── dashboards/
│       └── host-monitoring.json     # 预置仪表盘 JSON
├── alertmanager/
│   └── alertmanager.yml             # 告警路由配置
└── simulate/
    ├── simulate-alerts.bat           # 告警模拟脚本 (Windows)
    ├── simulate-alerts.sh            # 告警模拟脚本 (Linux/Mac)
    ├── watch-alerts.bat              # 实时监控面板 (Windows)
    └── watch-alerts.sh               # 实时监控面板 (Linux/Mac)
```

## 预置仪表盘

启动后 Grafana 自动加载"**主机与容器安全监控**"面板，包含：

- 系统概览：CPU / 内存 / 磁盘仪表盘 + 目标健康度
- CPU 详图：按核心 + 按模式 (system/iowait) 时间序列
- 内存分布：总量 / 空闲 / 缓存 / 实际使用
- 磁盘 & 网络：空间趋势 + 网络吞吐速率
- 容器监控：每个容器的 CPU 使用 + 内存占用
- 安全告警：当前触发告警表 + 严重级别分布 + 安全态势

## 平台兼容

| 功能 | Windows (Docker Desktop) | Linux |
|------|--------------------------|-------|
| Prometheus | ✓ | ✓ |
| Grafana | ✓ | ✓ |
| cAdvisor | ✓ | ✓ |
| Alertmanager | ✓ | ✓ |
| Node Exporter (完整主机指标) | ✗ (需 Linux) | ✓ |
| Node Exporter (自身进程指标) | ✓ | ✓ |
