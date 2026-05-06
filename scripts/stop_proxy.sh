#!/bin/bash
echo "🛑 正在停止所有 LDP 转发隧道..."
pkill -f "kubectl port-forward"
if [ $? -eq 0 ]; then
    echo "✅ 所有转发已成功关闭。"
else
    echo "ℹ️ 没有发现正在运行的转发进程。"
fi
