# Local Data Platform (LDP) 运维使用手册

> 本文档面向日常运维和使用 LDP 平台的同学，涵盖启动/停止、服务访问、故障排查、开发工作流等实操内容。

---

## 一、平台概览

LDP 是一套基于 Minikube 的本地数据工程平台，包含以下核心组件：

| 组件 | 作用 | 访问方式 |
|------|------|----------|
| **Apache Airflow** | 工作流编排与调度 | NodePort / Port-forward |
| **Apache Spark** | 分布式数据处理 | Spark Master UI |
| **MinIO** | S3 兼容对象存储 | Console + API |
| **PostgreSQL** | 元数据存储（Airflow / Hive Metastore）| 内部 Service |
| **Apache Iceberg** | 现代表格式（ACID、Time Travel）| 通过 Spark SQL 使用 |
| **Jupyter** | 交互式开发环境 | NodePort / Port-forward |
| **Prometheus** | 指标采集 | NodePort / Port-forward |
| **Grafana** | 可视化监控仪表盘 | NodePort / Port-forward |

---

## 二、环境前提

在操作平台前，请确保以下工具已安装：

```bash
minikube version    # v1.34.0+
kubectl version     # v1.30+
terraform version   # v1.7+
helm version        # v3.12+
```

> **网络提示**：在国内环境运行时，建议提前配置好代理，否则 Docker Hub / Helm Chart 仓库可能拉取超时。详见「七、常见问题 → 代理配置」。

---

## 三、日常操作流程

### 3.1 一键启动平台

首次使用（Minikube 未启动时）：

```bash
make setup   # 启动 Minikube 并开启必要插件
make start   # 部署所有平台服务
```

后续开机恢复（Minikube 已存在）：

```bash
make start   # 直接 Terraform 部署
```

### 3.2 查看平台健康状态

```bash
make health
# 等价于
./scripts/check-health.sh
```

输出包含：
- 所有 Pod 运行状态
- Service 列表
- PVC 绑定状态
- 节点/ Pod 资源占用（需 metrics-server）

### 3.3 一键停止平台（保留数据）

```bash
minikube stop
minikube stop
minikube start --registry-mirror=https://8v10vizu.mirror.aliyuncs.com
```

**效果**：关闭 Minikube 虚拟机，所有服务冻结。下次执行 `minikube start` 即可**原样恢复**，数据不丢失。

### 3.4 销毁平台资源（清空数据）

```bash
make stop
# 等价于
./scripts/stop.sh
```

**效果**：
- 删除 Terraform 管理的所有 K8s 资源（Pod、Service、Deployment、StatefulSet 等）
- **Minikube 虚拟机仍然运行**
- 数据卷（PVC）会被删除，数据清空

### 3.5 彻底清理（连 Minikube 一起删）

```bash
make cleanup
# 等价于
./scripts/cleanup.sh
```

**效果**：平台资源 + Minikube 集群全部删除，回到最原始状态。

---

## 四、服务访问指南

### 4.1 获取 Minikube IP

```bash
make minikube-ip
# 输出示例：192.168.49.2
```

### 4.2 通过 NodePort 访问（推荐）

假设 Minikube IP 为 `192.168.49.2`：

| 服务 | 地址 | 账号 | 密码 |
|------|------|------|------|
| Airflow UI | http://192.168.49.2:30080 | admin | admin |
| MinIO Console | http://192.168.49.2:30901 | admin | minioadmin |
| MinIO API | http://192.168.49.2:30900 | admin | minioadmin |
| Spark Master UI | http://192.168.49.2:30707 | - | - |
| Jupyter | http://192.168.49.2:30888 | Token 见下方 | - |
| Grafana | http://192.168.49.2:30300 | admin | admin |
| Prometheus | http://192.168.49.2:30909 | - | - |

> **Jupyter Token 获取**：
> ```bash
> kubectl logs -n ldp deployment/jupyter | grep token
> ```

### 4.3 通过 Port-forward 访问（NodePort 不通时使用）

```bash
# Airflow
make airflow-forward        # http://localhost:8080

# MinIO Console
make minio-forward          # http://localhost:9001

# Spark Master UI
make spark-forward          # http://localhost:8080

# Jupyter
make jupyter-forward        # http://localhost:8888

# PostgreSQL（本地连接数据库）
make postgres-forward       # localhost:5432

# Grafana
make grafana-forward        # http://localhost:3000

# Prometheus
make prometheus-forward     # http://localhost:9090
```

> Port-forward 是**前台进程**，按 `Ctrl+C` 停止转发。

---

## 五、常用运维命令速查

### 5.1 Make 快捷命令

```bash
make help              # 查看所有可用命令
make setup             # 初始化环境
make start             # 部署平台
make stop              # 销毁平台资源
make cleanup           # 彻底清理
make health            # 健康检查
make pods              # 查看所有 Pod
make services          # 查看所有 Service
make pvc               # 查看 PVC
make events            # 查看最近 K8s 事件
make logs              # 查看 Airflow 日志
make minikube-ip       # 查看 Minikube IP
make minikube-dashboard # 打开 K8s Dashboard
```

### 5.2 kubectl 常用操作

```bash
# 查看 Pod 状态
kubectl get pods -n ldp

# 查看 Pod 详情（排查故障）
kubectl describe pod <pod-name> -n ldp

# 查看 Pod 日志
kubectl logs <pod-name> -n ldp --tail=100
kubectl logs <pod-name> -n ldp -f        # 实时跟踪

# 查看所有服务
kubectl get svc -n ldp

# 查看存储卷
kubectl get pvc -n ldp

# 进入 Pod 容器
kubectl exec -it <pod-name> -n ldp -- /bin/bash

# 查看资源占用（需 metrics-server）
kubectl top nodes
kubectl top pods -n ldp
```

### 5.3 Terraform 操作

```bash
cd terraform

terraform plan              # 预览变更
terraform apply             # 应用变更
terraform apply -auto-approve   # 自动确认
terraform destroy -auto-approve # 销毁资源
terraform state list        # 查看 state 中的资源
terraform state rm <资源地址>   # 从 state 中移除资源（不删 K8s 对象）
terraform import <资源地址> <id> # 导入已有资源到 state
```

---

## 六、开发工作流

### 6.1 开发 Airflow DAG

DAG 文件放在 `airflow/dags/` 目录下：

```bash
vim airflow/dags/my_pipeline.py
```

修改后需要重启 Airflow 才能加载新 DAG：

```bash
# 方式一：重启整个平台
make stop && make start

# 方式二：仅重启 Airflow Webserver Pod
kubectl rollout restart deployment/airflow-webserver -n ldp
```

### 6.2 开发 Spark Job

Spark 作业放在 `spark/jobs/` 目录：

```bash
vim spark/jobs/process_data.py
```

提交作业到集群：

```bash
# 进入 Spark Master Pod
kubectl exec -it spark-master-0 -n ldp -- /bin/bash

# 提交作业
spark-submit /opt/spark/jobs/process_data.py
```

### 6.3 使用 Jupyter 开发

Jupyter 中已预装 PySpark，可以直接操作：

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("LDP") \
    .master("spark://spark-master:7077") \
    .getOrCreate()

# 读取 MinIO 中的数据
df = spark.read.csv("s3a://my-bucket/data.csv", header=True)
df.show()
```

### 6.4 加载示例代码

项目提供完整的示例代码（DAG、Spark Job、Iceberg 操作等）：

```bash
make load-examples
```

加载后执行 `make stop && make start` 生效。

---

## 七、常见问题与故障排查

### 7.1 Pod 状态为 `ImagePullBackOff`

**现象**：Pod 无法启动，`kubectl describe pod` 显示镜像拉取失败。

**原因**：Minikube 内的 Docker 无法连接到 Docker Hub（常见于国内网络）。

**解决**：

```bash
# 1. 配置 Minikube Docker 走代理（以 WSL + Windows 代理为例）
# 先获取 Windows 主机 IP
cat /etc/resolv.conf | grep nameserver   # 例如 172.22.16.1

# 2. 配置 Minikube 的 Docker
minikube ssh -- "sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment=\"HTTP_PROXY=http://<Windows_IP>:<代理端口>\"
Environment=\"HTTPS_PROXY=http://<Windows_IP>:<代理端口>\"
Environment=\"NO_PROXY=localhost,127.0.0.1,10.0.0.0/8\"
EOF"
minikube ssh -- "sudo systemctl daemon-reload && sudo systemctl restart docker"

# 3. 验证
minikube ssh -- docker pull postgres:16
```

### 7.2 Terraform 报错 "Unexpected Identity Change"

**现象**：

```
Error: Unexpected Identity Change
Current Identity: NullVal(...)
New Identity: ...StatefulSet...
```

**原因**：Terraform state 文件中记录的 K8s 资源 identity 损坏（通常因 apply 中断导致）。

**解决**：

```bash
cd terraform

# 1. 从 state 中移除损坏的资源（不删除 K8s 对象）
terraform state rm <资源地址>

# 示例：
terraform state rm module.postgresql.kubernetes_stateful_set_v1.postgresql
terraform state rm module.spark.kubernetes_stateful_set_v1.spark_master
terraform state rm module.spark.kubernetes_deployment_v1.spark_worker
terraform state rm kubernetes_deployment_v1.jupyter

# 2. 如果 K8s 中对象已存在，重新导入
terraform import module.postgresql.kubernetes_stateful_set_v1.postgresql ldp/postgresql
terraform import module.spark.kubernetes_stateful_set_v1.spark_master ldp/spark-master
terraform import module.spark.kubernetes_deployment_v1.spark_worker ldp/spark-worker
terraform import kubernetes_deployment_v1.jupyter ldp/jupyter

# 3. 重新 apply
terraform apply -auto-approve
```

### 7.3 Helm Chart 仓库无法访问

**现象**：

```
Error: Error locating chart
Unable to locate chart minio: looks like "https://charts.min.io/" is not a valid chart repository
```

**原因**：Helm / Terraform 走宿主机网络，未配置代理。

**解决**：

```bash
# 在当前终端设置代理（以 WSL 为例）
export HTTP_PROXY=http://<Windows_IP>:<代理端口>
export HTTPS_PROXY=http://<Windows_IP>:<代理端口>
export NO_PROXY=localhost,127.0.0.1,10.0.0.0/8,192.168.0.0/16,172.16.0.0/12

# 验证
helm repo add minio https://charts.min.io/ --force-update

# 重新部署
cd terraform && terraform apply -auto-approve
```

### 7.4 Pod 一直处于 `ContainerCreating`

**现象**：Pod 未就绪，状态停留在 `ContainerCreating` 或 `Init:0/1`。

**排查**：

```bash
# 查看事件
kubectl get events -n ldp --sort-by='.lastTimestamp' | tail -20

# 查看 Pod 详情
kubectl describe pod <pod-name> -n ldp
```

**常见原因**：
- 镜像太大，正在下载中（Jupyter 镜像约 4.8GB，需耐心等待 5-15 分钟）
- PVC 未绑定（检查 `kubectl get pvc -n ldp`）
- Init 容器正在执行初始化脚本

### 7.5 资源不足导致 Pod 无法调度

**现象**：Pod 状态为 `Pending`，`describe pod` 显示 `Insufficient memory` 或 `Insufficient cpu`。

**解决**：

```bash
# 删除旧集群并重新创建（数据会丢失）
minikube delete
minikube start --cpus=6 --memory=12288 --disk-size=60g --kubernetes-version=v1.34.0
```

---

## 八、数据持久化说明

| 组件 | 数据存储方式 | 删除平台后数据是否保留 |
|------|-------------|---------------------|
| PostgreSQL | PVC（8GB）| ❌ 随 `make stop` 删除 |
| MinIO | PVC（10GB）| ❌ 随 `make stop` 删除 |
| Airflow Logs | PVC | ❌ 随 `make stop` 删除 |
| Spark | 无持久化存储 | - |
| Jupyter | 无持久化存储 | - |

> **重要**：`make stop` 会销毁 PVC，数据会丢失。如需长期保留数据，请：
> 1. 使用 `minikube stop` 代替 `make stop`
> 2. 或在销毁前手动备份数据

### 备份 MinIO 数据到本地

```bash
# 安装 mc 客户端后
mc alias set ldp http://<minikube-ip>:30900 admin minioadmin
mc mirror ldp/my-bucket ./backup/
```

---

## 九、监控与告警

### 9.1 查看 Grafana 仪表盘

访问 http://`<minikube-ip>`:30300，账号 `admin` / `admin`。

平台预置了以下仪表盘：
- Airflow  overview
- MinIO 监控
- Spark 作业监控
- 平台整体概览

导入自定义仪表盘：

```bash
make import-dashboards
```

### 9.2 查看 Prometheus 指标

访问 http://`<minikube-ip>`:30909，可查询和调试指标。

### 9.3 查看各组件日志

```bash
make logs-airflow      # Airflow Webserver
make logs-scheduler    # Airflow Scheduler
make logs-spark        # Spark Master
make logs-minio        # MinIO
```

---

## 十、快速参考卡

### 账号密码速查

| 服务 | 用户名 | 密码 |
|------|--------|------|
| Airflow | admin | admin |
| MinIO | admin | minioadmin |
| PostgreSQL | ldp | ldppassword |
| Grafana | admin | admin |

### 核心端口速查

| 服务 | NodePort | Port-forward |
|------|----------|--------------|
| Airflow | 30080 | 8080 |
| MinIO Console | 30901 | 9001 |
| MinIO API | 30900 | - |
| Spark Master | 30707 | 8080 |
| Jupyter | 30888 | 8888 |
| Grafana | 30300 | 3000 |
| Prometheus | 30909 | 9090 |
| PostgreSQL | - | 5432 |

### 关键文件路径

```
ldp/
├── airflow/dags/          # DAG 文件
├── spark/jobs/            # Spark 作业
├── spark/lib/             # Spark 工具库
├── data/raw/              # 原始数据
├── data/processed/        # 处理后数据
├── terraform/             # 基础设施配置
├── scripts/               # 运维脚本
└── docs/                  # 项目文档
```

---

> 如有其他问题，请参考 `docs/troubleshooting.md` 或在仓库提交 Issue。
