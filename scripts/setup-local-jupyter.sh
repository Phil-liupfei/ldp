#!/bin/bash
# Setup local Jupyter + PySpark environment in WSL
# Connects to K8s MinIO via port-forward, runs Spark in local mode

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 is not installed or not in PATH"
        exit 1
    fi
}

main() {
    log_step "Checking prerequisites..."
    check_command python3
    check_command kubectl

    if ! kubectl get ns ldp &>/dev/null; then
        log_error "Kubernetes namespace 'ldp' not found."
        log_error "Please deploy the platform first: make start"
        exit 1
    fi

    log_step "Checking MinIO service..."
    if ! kubectl get svc -n ldp minio &>/dev/null; then
        log_error "MinIO service not found in namespace 'ldp'"
        exit 1
    fi

    VENV_DIR="$PROJECT_ROOT/.venv"

    if [ ! -d "$VENV_DIR" ]; then
        log_info "Creating Python virtual environment at $VENV_DIR..."
        python3 -m venv "$VENV_DIR"
    else
        log_warn "Virtual environment already exists at $VENV_DIR"
    fi

    log_info "Activating virtual environment..."
    source "$VENV_DIR/bin/activate"

    log_step "Installing Python packages..."
    pip install --quiet --upgrade pip
    pip install --quiet pyspark==3.5.3 jupyter boto3 pandas ipykernel

    log_step "Registering Jupyter kernel..."
    KERNEL_NAME="ldp-local"
    KERNEL_DISPLAY="Python (LDP Local)"

    if jupyter kernelspec list 2>/dev/null | grep -q "$KERNEL_NAME"; then
        log_warn "Jupyter kernel '$KERNEL_NAME' already registered"
    else
        python -m ipykernel install --user --name="$KERNEL_NAME" --display-name "$KERNEL_DISPLAY"
        log_info "Jupyter kernel '$KERNEL_DISPLAY' registered"
    fi

    log_step "Generating local notebook template..."
    mkdir -p "$PROJECT_ROOT/Notebook/local"

    NOTEBOOK_PATH="$PROJECT_ROOT/Notebook/local/spark_local.ipynb"
    if [ -f "$NOTEBOOK_PATH" ]; then
        log_warn "Notebook already exists at Notebook/local/spark_local.ipynb"
        log_warn "Skipping generation to avoid overwriting your changes"
    else
        python3 << 'PYEOF'
import json
import os

notebook = {
    "cells": [
        {
            "cell_type": "markdown",
            "metadata": {},
            "source": [
                "# Local Spark + MinIO Notebook\n",
                "\n",
                "This notebook runs Spark in **local mode** on WSL and connects to MinIO in K8s via port-forward.\n",
                "\n",
                "> **Prerequisite**: Run `kubectl port-forward -n ldp svc/minio 9000:9000` in another terminal first."
            ]
        },
        {
            "cell_type": "code",
            "execution_count": None,
            "metadata": {},
            "outputs": [],
            "source": [
                "from pyspark.sql import SparkSession\n",
                "\n",
                "spark = (\n",
                "    SparkSession.builder\n",
                "    .appName(\"LocalJupyterSpark\")\n",
                "    .master(\"local[*]\")  # Local mode, does not connect to K8s Spark cluster\n",
                "    .config(\n",
                "        \"spark.jars.packages\",\n",
                "        \"org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.10.0,\"\n",
                "        \"org.apache.hadoop:hadoop-aws:3.3.4,\"\n",
                "        \"com.amazonaws:aws-java-sdk-bundle:1.12.262\"\n",
                "    )\n",
                "    .config(\"spark.sql.extensions\", \"org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions\")\n",
                "    .config(\"spark.sql.catalog.local\", \"org.apache.iceberg.spark.SparkCatalog\")\n",
                "    .config(\"spark.sql.catalog.local.type\", \"hadoop\")\n",
                "    .config(\"spark.sql.catalog.local.warehouse\", \"s3a://warehouse/\")\n",
                "    # MinIO via port-forward (localhost:9000)\n",
                "    .config(\"spark.hadoop.fs.s3a.endpoint\", \"http://localhost:9000\")\n",
                "    .config(\"spark.hadoop.fs.s3a.access.key\", \"admin\")\n",
                "    .config(\"spark.hadoop.fs.s3a.secret.key\", \"minioadmin\")\n",
                "    .config(\"spark.hadoop.fs.s3a.path.style.access\", \"true\")\n",
                "    .config(\"spark.hadoop.fs.s3a.impl\", \"org.apache.hadoop.fs.s3a.S3AFileSystem\")\n",
                "    .config(\"spark.hadoop.fs.s3a.connection.ssl.enabled\", \"false\")\n",
                "    .config(\"spark.hadoop.fs.s3a.fast.upload\", \"true\")\n",
                "    .config(\"spark.hadoop.mapreduce.fileoutputcommitter.algorithm.version\", \"2\")\n",
                "    .config(\"spark.sql.adaptive.enabled\", \"true\")\n",
                "    .config(\"spark.sql.shuffle.partitions\", \"4\")\n",
                "    .getOrCreate()\n",
                ")\n",
                "\n",
                "print(f\"Spark Version: {spark.version}\")\n",
                "print(f\"Spark UI: {spark.sparkContext.uiWebUrl}\")\n",
                "spark"
            ]
        },
        {
            "cell_type": "markdown",
            "metadata": {},
            "source": ["## Test 1: Basic DataFrame"]
        },
        {
            "cell_type": "code",
            "execution_count": None,
            "metadata": {},
            "outputs": [],
            "source": [
                "df = spark.createDataFrame([(1, \"Alice\"), (2, \"Bob\")], [\"id\", \"name\"])\n",
                "df.show()"
            ]
        },
        {
            "cell_type": "markdown",
            "metadata": {},
            "source": ["## Test 2: Read/Write MinIO (Parquet)"]
        },
        {
            "cell_type": "code",
            "execution_count": None,
            "metadata": {},
            "outputs": [],
            "source": [
                "df.write.mode(\"overwrite\").parquet(\"s3a://warehouse/local_test/jupyter_check.parquet\")\n",
                "result = spark.read.parquet(\"s3a://warehouse/local_test/jupyter_check.parquet\")\n",
                "result.show()"
            ]
        },
        {
            "cell_type": "markdown",
            "metadata": {},
            "source": ["## Test 3: Iceberg Table Operations"]
        },
        {
            "cell_type": "code",
            "execution_count": None,
            "metadata": {},
            "outputs": [],
            "source": [
                "spark.sql(\"CREATE DATABASE IF NOT EXISTS local.demo\")\n",
                "\n",
                "spark.sql(\"\"\"\n",
                "    CREATE TABLE IF NOT EXISTS local.demo.jupyter_test (\n",
                "        id BIGINT,\n",
                "        name STRING\n",
                "    ) USING iceberg\n",
                "\"\"\")\n",
                "\n",
                "df.writeTo(\"local.demo.jupyter_test\").overwritePartitions()\n",
                "spark.table(\"local.demo.jupyter_test\").show()"
            ]
        },
        {
            "cell_type": "markdown",
            "metadata": {},
            "source": [
                "## Cleanup\n",
                "\n",
                "Run this cell when you're done to stop the Spark session."
            ]
        },
        {
            "cell_type": "code",
            "execution_count": None,
            "metadata": {},
            "outputs": [],
            "source": [
                "spark.stop()"
            ]
        }
    ],
    "metadata": {
        "kernelspec": {
            "display_name": "Python (LDP Local)",
            "language": "python",
            "name": "ldp-local"
        },
        "language_info": {
            "name": "python",
            "version": "3.10.0"
        }
    },
    "nbformat": 4,
    "nbformat_minor": 4
}

os.makedirs("Notebook/local", exist_ok=True)
with open("Notebook/local/spark_local.ipynb", "w", encoding="utf-8") as f:
    json.dump(notebook, f, indent=2, ensure_ascii=False)
PYEOF
        log_info "Notebook template created at Notebook/local/spark_local.ipynb"
    fi

    echo ""
    log_info "Setup complete!"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo ""
    echo "1. Start MinIO port-forward in another terminal:"
    echo -e "   ${GREEN}kubectl port-forward -n ldp svc/minio 9000:9000${NC}"
    echo ""
    echo "2. In VS Code, open a .ipynb file and select the kernel:"
    echo -e "   ${GREEN}Python (LDP Local)${NC}"
    echo ""
    echo "3. Open the generated notebook:"
    echo -e "   ${GREEN}Notebook/local/spark_local.ipynb${NC}"
    echo ""
    echo "4. Run the cells to verify the connection."
    echo ""
    echo -e "${YELLOW}Note:${NC} This setup uses Spark local mode (runs on your machine)."
    echo -e "      Data is shared via MinIO, so notebooks in K8s Jupyter and local VS Code"
    echo -e "      see the same Iceberg tables and S3 files."
}

main "$@"
