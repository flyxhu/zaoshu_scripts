#!/bin/bash

# ====================== 参数校验 ======================
# 检查是否传入3个参数
if [ $# -ne 3 ]; then
    echo "用法: $0 <文件数量> <每行数量> <日期>"
    echo "示例: $0 3 50 2025-12-31"
    exit 1
fi

# 接收传入的参数
FILE_COUNT=$1    # 要生成的文件总数
LINE_COUNT=$2    # 每个文件的行数
DATE=$3          # 指定的日期

# 校验参数是否为正整数
if ! [[ $FILE_COUNT =~ ^[1-9][0-9]*$ ]]; then
    echo "错误：文件数量必须是正整数！"
    exit 1
fi

if ! [[ $LINE_COUNT =~ ^[1-9][0-9]*$ ]]; then
    echo "错误：行数必须是正整数！"
    exit 1
fi

# ====================== 核心生成逻辑 ======================
# 循环生成指定数量的文件
for (( file_num=1; file_num<=$FILE_COUNT; file_num++ )); do
    # 定义文件名（格式：data_文件序号.txt）
    filename="data_${file_num}.txt"
    
    # 初始化当前文件的行序号
    current_line_num=1
    
    # 清空/创建文件
    > "$filename"
    
    # 循环生成指定行数
    for (( i=1; i<=$LINE_COUNT; i++ )); do
        # 计算当前行属于第几组数据（每20行一组，组内数据相同）
        # 取模运算：1-20行=1组，21-40行=2组，以此类推
        group_line=$(( (i - 1) % 20 + 1 ))
        
        # 写入文件内容：序号 | 日期 | 组内行号(每20行重复)
        echo "行号: ${current_line_num} | 日期: ${DATE} | 数据段: 第${group_line}条固定数据" >> "$filename"
        
        # 行号自增（全局递增）
        current_line_num=$((current_line_num + 1))
    done

    echo "已生成文件: $filename (共$LINE_COUNT行)"
done

echo -e "\n✅ 所有文件生成完成！"