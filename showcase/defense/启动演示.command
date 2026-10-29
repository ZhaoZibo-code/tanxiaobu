#!/bin/sh
# 双击本文件即可启动答辩演示（会打开终端并自动拉起浏览器）
cd "$(dirname "$0")" || exit 1
python3 serve.py
