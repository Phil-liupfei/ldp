# Local Data Platform (LDP) - Setup Guide

## Overview
## 概述
**LDP is a local development environment for data engineering**, designed to run entirely on your laptop using Minikube. This guide will help you set up a complete data engineering stack locally for development, testing, and learning.
**LDP 是一个面向数据工程的本地开发环境**，旨在通过 Minikube 完全在您的笔记本电脑上运行。本指南将帮助您在本地搭建一套完整的数据工程栈，用于开发、测试和学习。

### What You'll Get
### 你将获得
This Local Data Platform provides a complete data engineering stack running on Minikube, including:
- **Apache Airflow** - Workflow orchestration
- **Apache Spark** - Distributed data processing
- **MinIO** - S3-compatible object storage
- **PostgreSQL** - Metadata store
- **Jupyter** - Interactive development environment
- **Apache Iceberg** - Table format (configured via Spark)
该本地数据平台提供了一套完整的、运行在 Minikube 上的数据工程栈，包括：
- **Apache Airflow** —— 工作流编排
- **Apache Spark** —— 分布式数据处理
- **MinIO** —— 兼容 S3 的对象存储
- **PostgreSQL** —— 元数据存储
- **Jupyter** —— 交互式开发环境
- **Apache Iceberg** —— 表格式（通过 Spark 配置）

### Use Cases
### 使用场景

LDP is perfect for:
- **Learning**: Understanding how modern data platforms work without cloud costs
- **Development**: Building and testing data pipelines locally before cloud deployment
- **Experimentation**: Trying new data engineering patterns and tools
- **CI/CD**: Automated testing of data pipelines in GitHub Actions or similar
- **Prototyping**: Validating data architectures before production implementation
LDP 非常适用于：
- **学习**：在不产生云成本的情况下，理解现代数据平台的工作原理
- **开发**：在部署到云环境之前，在本地构建和测试数据管道
- **实验**：尝试新的数据工程模式与工具
- **CI/CD**：在 GitHub Actions 或类似平台上对数据管道进行自动化测试
- **原型验证**：在生产实施前验证数据架构

### Not For Production
### 不适用于生产环境

LDP runs on your laptop or in CI environments. For production data workloads, use cloud-managed services or dedicated Kubernetes clusters with proper scaling, security, and reliability features.
LDP 运行在您的笔记本电脑或 CI 环境中。对于生产环境的数据工作负载，请使用云托管服务或专用的 Kubernetes 集群，并确保具备适当的扩展能力、安全性和可靠性功能。

## Platform-Specific Guides
## 平台特定指南

**Choose your operating system for detailed installation instructions:**
**请根据您的操作系统选择对应的详细安装说明：**
- **[macOS Setup Guide](platform-guides/macos.md)** - Complete guide for Mac users (Intel and Apple Silicon)
- **[Windows Setup Guide](platform-guides/windows.md)** - Complete guide for Windows 10/11 users
- **[Linux Setup Guide](#prerequisites)** - See below for Linux instructions
- **[macOS 安装指南](platform-guides/macos.md)** —— 适用于 Mac 用户（Intel 和 Apple Silicon）的完整指南
- **[Windows 安装指南](platform-guides/windows.md)** —— 适用于 Windows 10/11 用户的完整指南
- **[Linux 安装指南](#prerequisites)** —— 请参阅下文中的 Linux 说明


## Linux Setup
## Linux 安装指南

### Prerequisites
### 前提条件

### Required Software
### 所需软件

```bash
# Install Minikube
brew install minikube  # macOS
# or
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Install kubectl
brew install kubectl  # macOS
# or
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Install Terraform
brew install terraform  # macOS
# or
https://developer.hashicorp.com/terraform/install

# Install Helm
brew install helm  # macOS
# or
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

## Setup Instructions
## 安装说明

### Step 1: Start Minikube
```bash
# Start Minikube with sufficient resources
minikube start \
  --cpus=4 \
  --memory=8192 \
  --disk-size=50g \
  --kubernetes-version=v1.34.0

# Enable required addons
minikube addons enable storage-provisioner
minikube addons enable default-storageclass
minikube addons enable metrics-server

# Verify cluster is running
kubectl cluster-info
```

### Step 2: Initialize Terraform
```bash
# Create project directory
mkdir ldp && cd ldp

# Save the Terraform configuration to main.tf
# (Copy the Terraform artifact content)

# Initialize Terraform
terraform init
```

### Step 3: Deploy the Platform
```bash
# Plan the deployment
terraform plan

# Apply the configuration
terraform apply

# This will take 10-15 minutes for all services to start
```

### Step 4: Verify Deployment
```bash
# Check all pods are running
kubectl get pods -n ldp

# Watch pods until all are ready
kubectl get pods -n ldp -w

# Get service URLs
minikube service list -n ldp
```

### Step 5: Access Services

Get the Minikube IP:
```bash
minikube ip
```

#### Service Access Points
- **Airflow UI**: `http://<minikube-ip>:30080`
  - Username: `admin`
  - Password: `admin`

- **MinIO Console**: `http://<minikube-ip>:30901`
  - Username: `admin`
  - Password: `minioadmin`

- **Spark Master UI**: `http://<minikube-ip>:30707`

- **Jupyter Notebook**: `http://<minikube-ip>:30888`
  - Token: Check logs with `kubectl logs -n ldp deployment/jupyter`

#### Port Forwarding Alternative
If NodePort access doesn't work:
```bash
# Airflow
kubectl port-forward -n ldp svc/airflow-webserver 8080:8080

# MinIO Console
kubectl port-forward -n ldp svc/minio-console 9001:9001

# Spark Master
kubectl port-forward -n ldp svc/spark-master-svc 8080:8080

# Jupyter
kubectl port-forward -n ldp svc/jupyter 8888:8888
```

## Iceberg Configuration

### Configure Spark with Iceberg
Create a Spark configuration file for Iceberg:

```python
# In Jupyter or your Spark application
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("IcebergApp") \
    .config("spark.jars.packages", "org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.10.0") \
    .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.iceberg.spark.SparkSessionCatalog") \
    .config("spark.sql.catalog.spark_catalog.type", "hive") \
    .config("spark.sql.catalog.local", "org.apache.iceberg.spark.SparkCatalog") \
    .config("spark.sql.catalog.local.type", "hadoop") \
    .config("spark.sql.catalog.local.warehouse", "s3a://warehouse/") \
    .config("spark.hadoop.fs.s3a.endpoint", "http://minio:9000") \
    .config("spark.hadoop.fs.s3a.access.key", "admin") \
    .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
    .getOrCreate()

# Create an Iceberg table
spark.sql("""
    CREATE TABLE local.db.sample (
        id bigint,
        data string,
        ts timestamp
    ) USING iceberg
""")
```

```python
from pyspark.sql import SparkSession

spark = (
    SparkSession.builder
    .appName("JupyterSpark")
    .config(
        "spark.jars.packages",
        "org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.10.0,"
        "org.apache.hadoop:hadoop-aws:3.3.4,"
        "com.amazonaws:aws-java-sdk-bundle:1.12.262"
    )
    .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")
    .config("spark.sql.catalog.local", "org.apache.iceberg.spark.SparkCatalog")
    .config("spark.sql.catalog.local.type", "hadoop")
    .config("spark.sql.catalog.local.warehouse", "s3a://warehouse/")
    # MinIO/S3A 配置
    .config("spark.hadoop.fs.s3a.endpoint", "http://minio:9000")
    .config("spark.hadoop.fs.s3a.access.key", "admin")
    .config("spark.hadoop.fs.s3a.secret.key", "minioadmin")
    .config("spark.hadoop.fs.s3a.path.style.access", "true")
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
    .config("spark.hadoop.fs.s3a.connection.ssl.enabled", "false")
    # ========== 关键修复参数 ==========
    .config("spark.hadoop.fs.s3a.fast.upload", "true")
    .config("spark.hadoop.mapreduce.fileoutputcommitter.algorithm.version", "2")
    .config("spark.hadoop.mapreduce.fileoutputcommitter.cleanup-failures.ignored", "true")
    .config("spark.sql.sources.commitProtocolClass", "org.apache.spark.sql.execution.datasources.SQLHadoopMapReduceCommitProtocol")
    # ==================================
    .config("spark.executor.memory", "1g")
    .config("spark.driver.memory", "1g")
    .config("spark.sql.adaptive.enabled", "true")
    .config("spark.sql.shuffle.partitions", "4")
    .getOrCreate()
)

print(f"Spark Version: {spark.version}")
print(f"Spark UI: {spark.sparkContext.uiWebUrl}")


# 测试 1：简单 DataFrame
df = spark.createDataFrame([(1, "Alice"), (2, "Bob")], ["id", "name"])
df.show()

# 测试 2：读写 MinIO
df.write.mode("overwrite").parquet("s3a://warehouse/test/jupyter_check.parquet")
spark.read.parquet("s3a://warehouse/test/jupyter_check.parquet").show()

# 测试 3：Iceberg 表操作
spark.sql("CREATE DATABASE IF NOT EXISTS local.demo")
spark.sql("""
    CREATE TABLE IF NOT EXISTS local.demo.jupyter_test (
        id BIGINT,
        name STRING
    ) USING iceberg
""")
df.writeTo("local.demo.jupyter_test").overwritePartitions()

spark.table("local.demo.jupyter_test").show()
```

## Example Airflow DAG with Spark

Create a sample DAG to test Spark integration:

```python
# Save to dags/spark_example.py
from airflow import DAG
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'ldp',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    'spark_iceberg_example',
    default_args=default_args,
    description='Example Spark job with Iceberg',
    schedule=timedelta(days=1),  # Use 'schedule' instead of deprecated 'schedule_interval'
    catchup=False,
) as dag:

    spark_job = SparkSubmitOperator(
        task_id='run_spark_job',
        application='/path/to/your/job.py',
        conn_id='spark_default',
        conf={
            'spark.jars.packages': 'org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.10.0',
            'spark.sql.catalog.local': 'org.apache.iceberg.spark.SparkCatalog'
        },
    )
```

## Useful Commands

### Scaling Services
```bash
# Scale Spark workers
kubectl scale deployment spark-worker -n ldp --replicas=3

# Check resource usage
kubectl top pods -n ldp
kubectl top nodes
```

### Logs and Debugging
```bash
# View Airflow logs
kubectl logs -n ldp -l component=webserver --tail=100

# View Spark master logs
kubectl logs -n ldp -l component=master --tail=100

# Describe a failing pod
kubectl describe pod <pod-name> -n ldp

# Execute into a pod
kubectl exec -it -n ldp <pod-name> -- /bin/bash
```

### Database Access
```bash
# Connect to PostgreSQL
kubectl exec -it -n ldp postgresql-0 -- psql -U ldp -d metastore

# Port forward for local access
kubectl port-forward -n ldp svc/postgresql 5432:5432
# Then: psql -h localhost -U ldp -d metastore
```

### MinIO CLI
```bash
# Install mc (MinIO Client)
brew install minio/stable/mc

# Configure
mc alias set ldp http://$(minikube ip):30900 admin minioadmin

# List buckets
mc ls ldp/

# Upload files
mc cp data.csv ldp/datalake/
```

## Cleanup

### Remove the Platform
```bash
# Destroy all resources
terraform destroy

# Or manually delete
kubectl delete namespace ldp

# Stop Minikube
minikube stop

# Delete Minikube cluster
minikube delete
```

## Troubleshooting

### Pods Not Starting
```bash
# Check events
kubectl get events -n ldp --sort-by='.lastTimestamp'

# Check resource constraints
kubectl describe nodes
```

### Out of Memory/CPU
```bash
# Increase Minikube resources
minikube delete
minikube start --cpus=6 --memory=12288
```

### Persistent Volume Issues
```bash
# Check PVCs
kubectl get pvc -n ldp

# Delete and recreate if needed
kubectl delete pvc <pvc-name> -n ldp
terraform apply
```

## Next Steps

1. **Configure Airflow Connections** for Spark and MinIO
2. **Create custom Spark images** with your dependencies
3. **Set up data ingestion pipelines** in Airflow
4. **Implement Iceberg table lifecycle** management
5. **Add monitoring** with Prometheus/Grafana (optional)
6. **Configure backup strategies** for metadata

## Additional Resources

- [Apache Airflow Documentation](https://airflow.apache.org/docs/)
- [Apache Spark Documentation](https://spark.apache.org/docs/latest/)
- [Apache Iceberg Documentation](https://iceberg.apache.org/docs/latest/)
- [MinIO Documentation](https://min.io/docs/minio/linux/index.html)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
