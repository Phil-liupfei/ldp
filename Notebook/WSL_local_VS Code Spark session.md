WSL 本地 VS Code 体验确实好很多。最稳的方案是：**本地跑 Spark（local mode）+ Port-forward 连 K8s 里的 MinIO**。这样你不用处理 executor 回连 driver 的复杂网络问题，数据又能共享。

---

## 步骤 1：在 WSL 里建本地 Python 环境

在项目根目录执行：

```bash
cd /home/phil/ldp
python3 -m venv .venv
source .venv/bin/activate

# 安装依赖（版本和 K8s 里 Spark 3.5.8 对齐）
pip install pyspark==3.5.3 jupyter boto3 pandas
```

> ⚠️ 注意：你项目里的 `docker/jupyter/requirements.txt` 写了 `pyspark==4.0.1`，但 K8s 里实际跑的是 **Spark 3.5.8**，所以本地装 **3.5.x** 更稳。

---

## 步骤 2：Port-forward MinIO API 到本地

现有的 `scripts/port-forward.sh` 只转发了 MinIO **Console**（9001），没转 S3 **API**（9000）。

新开一个 WSL terminal，保持运行：

```bash
kubectl port-forward -n ldp svc/minio 9000:9000
```

> 这个窗口不能关，关了本地就访问不了 MinIO 了。

---

## 步骤 3：VS Code 配置

1. 按 `Ctrl+Shift+P` → `Python: Select Interpreter`
2. 选择 `./.venv/bin/python`
3. 新建 `.ipynb` 文件（或打开 `Notebook/` 里的），VS Code 会自动用这个环境的 kernel

---

## 步骤 4：本地用的 SparkSession 代码

和 K8s 里的唯一区别是：
- 加了 `.master("local[*]")`（本地模式）
- MinIO endpoint 改成 `http://localhost:9000`（走 port-forward）

```python
from pyspark.sql import SparkSession

spark = (
    SparkSession.builder
    .appName("LocalJupyterSpark")
    .master("local[*]")  # ✅ 本地模式，不连 K8s cluster
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
    # ✅ 通过 port-forward 访问 K8s 里的 MinIO
    .config("spark.hadoop.fs.s3a.endpoint", "http://localhost:9000")
    .config("spark.hadoop.fs.s3a.access.key", "admin")
    .config("spark.hadoop.fs.s3a.secret.key", "minioadmin")
    .config("spark.hadoop.fs.s3a.path.style.access", "true")
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
    .config("spark.hadoop.fs.s3a.connection.ssl.enabled", "false")
    .config("spark.hadoop.fs.s3a.fast.upload", "true")
    .config("spark.hadoop.mapreduce.fileoutputcommitter.algorithm.version", "2")
    .config("spark.sql.adaptive.enabled", "true")
    .config("spark.sql.shuffle.partitions", "4")
    .getOrCreate()
)

print(f"Spark Version: {spark.version}")
print(f"Spark UI: {spark.sparkContext.uiWebUrl}")
spark
```

---

## 验证测试

```python
# 读写 K8s MinIO 上的数据（两边共享）
df = spark.createDataFrame([(1, "Alice"), (2, "Bob")], ["id", "name"])

# 写 Parquet 到 MinIO
df.write.mode("overwrite").parquet("s3a://warehouse/local_test/data.parquet")

# 读回
spark.read.parquet("s3a://warehouse/local_test/data.parquet").show()

# Iceberg 表（和 K8s Jupyter 里共用同一个 catalog）
spark.sql("CREATE DATABASE IF NOT EXISTS local.demo")
spark.sql("""
    CREATE TABLE IF NOT EXISTS local.demo.local_test (
        id BIGINT,
        name STRING
    ) USING iceberg
""")
df.writeTo("local.demo.local_test").overwritePartitions()
spark.table("local.demo.local_test").show()
```

---

## 补充：不想一直开着 port-forward 窗口？

可以改 endpoint 直接用 **Minikube IP + NodePort**（如果 WSL 能连通）：

```python
.config("spark.hadoop.fs.s3a.endpoint", "http://192.168.49.2:30900")
```

但刚才测试你这边 `192.168.49.2:30900` 超时连不上，所以 **port-forward 是最稳的**。

---

需要我帮你把这套配置写成一个 `setup-local-jupyter.sh` 脚本放到 `scripts/` 里吗？以后新环境一键搞定。