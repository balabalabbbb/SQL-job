# -*- coding: utf-8 -*-
"""裁剪截图，只保留浏览器内容区域"""
from PIL import Image
import os

SHOTS = r"C:\Users\lenovo\Doubao\chats\2026-09-11\new-chat-1\SQL-job\stage2\result\screenshots"

# 裁剪区域：去掉顶部浏览器UI(约80px)和底部任务栏(约40px)
# 内容区域: left=0, top=82, right=1920, bottom=1040
CROP_BOX = (0, 82, 1920, 1040)

files = sorted([f for f in os.listdir(SHOTS) if f.endswith('.png')])

for fname in files:
    path = os.path.join(SHOTS, fname)
    img = Image.open(path)
    original_size = img.size
    
    # 裁剪
    cropped = img.crop(CROP_BOX)
    
    # 保存（覆盖原文件）
    cropped.save(path, 'PNG')
    
    print(f"{fname}: {original_size[0]}x{original_size[1]} -> {cropped.size[0]}x{cropped.size[1]}")
    img.close()
    cropped.close()

print("\n全部裁剪完成！")
