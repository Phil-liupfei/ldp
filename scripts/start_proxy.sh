#!/bin/bash

# 定义颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' 

echo -e "${BLUE}🚀 正在全量重置隧道 (适配分离式 MinIO Service)...${NC}"

# 1. 彻底清理旧进程
pkill -f "kubectl port-forward" || true
sleep 1

# 2. Spark Master (RPC 7077 & UI 30707)
kubectl port-forward --address 0.0.0.0 svc/spark-master -n ldp 7077:7077 30707:8080 > /dev/null 2>&1 &

# 3. MinIO API (9000) - 对应你的 svc/minio
kubectl port-forward --address 0.0.0.0 svc/minio -n ldp 9000:9000 > /dev/null 2>&1 &

# 4. MinIO Console (9001) - 对应你的 svc/minio-console
kubectl port-forward --address 0.0.0.0 svc/minio-console -n ldp 9001:9001 > /dev/null 2>&1 &

# 5. 其他服务 (Airflow, Jupyter, Postgres)
kubectl port-forward --address 0.0.0.0 svc/airflow-api-server -n ldp 8080:8080 > /dev/null 2>&1 &
kubectl port-forward --address 0.0.0.0 svc/jupyter -n ldp 30888:8888 > /dev/null 2>&1 &
kubectl port-forward --address 0.0.0.0 svc/postgresql -n ldp 5432:5432 > /dev/null 2>&1 &

echo -e "${GREEN}------------------------------------------------${NC}"
echo -e "${GREEN}✅ 隧道已重新打通！${NC}"
echo -e "📦 ${BLUE}MinIO 数据 (9000):${NC} 已转发"
echo -e "🖥️ ${BLUE}MinIO 界面 (9001):${NC} 已转发"
echo -e "🐘 ${BLUE}其他服务:${NC} Spark(7077), Airflow(8080), PG(5432) 已就绪"
echo -e "${GREEN}------------------------------------------------${NC}"