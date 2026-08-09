#!/bin/bash

# ====================== 依赖检查（确保bc可用） ======================
# 新增bc计算器依赖校验，解决 bc: command not found
if [ -z "$(which bc)" ]; then
    echo "错误：系统缺少bc计算工具，请先安装！"
    echo "Ubuntu执行：sudo apt install bc -y"
    exit 1
fi

# ====================== 参数校验 ======================
if [ $# -ne 3 ]; then
    echo "用法: $0 <文件数量> <每行数量> <8位日期>"
    echo "示例: $0 3 50 20260429"
    exit 1
fi

FILE_COUNT=$1
LINE_COUNT=$2
DATE_8=$3  # 接收8位日期：20260429

# 截取月日（MMDD）用于文件名
MMDD=${DATE_8:4:4}                # 20260429 → 0429

# 校验参数合法性
if ! [[ $FILE_COUNT =~ ^[1-9][0-9]*$ ]]; then
    echo "错误：文件数量必须是正整数！"
    exit 1
fi

if ! [[ $LINE_COUNT =~ ^[1-9][0-9]*$ ]]; then
    echo "错误：行数必须是正整数！"
    exit 1
fi

if ! [[ $DATE_8 =~ ^[0-9]{8}$ ]]; then
    echo "错误：日期必须是8位数字（如20260429）！"
    exit 1
fi

# ====================== 自定义5条基础数据（15位整数+3位小数+末尾+） ======================
data_20=(
"张三 22 00000000000001109+ 中国 浙江 X"
"陈天 31 00000000000001700+ 中国 北京 E"
"李四 25 00000000000002220+ 中国 上海 A"
)

# ====================== 工具函数：提取金额数值 ======================
extract_amount() {
    local amount_str=$1
    local pure_num=${amount_str%+}
    # 前14位 = 整数部分，最后3位 = 小数部分
    local integer_part=${pure_num:0:14}
    local decimal_part=${pure_num: -3}
    echo "$((10#$integer_part)).$decimal_part"
}
# ====================== 工具函数：格式化金额 ======================
format_amount() {
    local total=$1
    local total_int=$(echo "$total * 1000" | bc -l | awk '{print int($1)}')
    printf "%017d+" "$total_int"
}

# ====================== 核心生成逻辑（强制GBK编码） ======================
for (( file_num=1; file_num<=$FILE_COUNT; file_num++ )); do
    # 定义文件名
    filename="F99999.00001.5000010000.003.${file_num}.${MMDD}.DAT"
    # 临时文件（先按UTF-8生成，再转换为GBK）
    temp_file="${filename}.tmp"
    > "$temp_file"

    # 第一步：计算总金额
    total_amount=0.000
    for (( i=1; i<=$LINE_COUNT; i++ )); do
        idx=$(( (i - 1) % 3 ))
        line_data="${data_20[$idx]}"
        amount_str=$(echo "$line_data" | awk '{print $3}')
        amount_num=$(extract_amount "$amount_str")
		# echo "第${i}行，单笔：${amount_num}，当前累计：${total_amount}"
        total_amount=$(echo "$total_amount + $amount_num" | bc -l)
    done
    formatted_total=$(format_amount "$total_amount")

    # 第二步：写入临时文件（UTF-8）
    echo "行号: 1 | 日期: ${DATE_8} | 汇总: 总金额=${formatted_total} | 本文件共${LINE_COUNT}行明细数据" >> "$temp_file"

    current_line_num=2
    for (( i=1; i<=$LINE_COUNT; i++ )); do
        idx=$(( (i - 1) % 3 ))
        line_data="${data_20[$idx]}"
        detail_line="行号: ${current_line_num} | 日期: ${DATE_8} | 数据: ${line_data}"
        
        echo -n "$detail_line" >> "$temp_file"
        if [ $i -lt $LINE_COUNT ]; then
            echo "" >> "$temp_file"
        fi
        
        current_line_num=$((current_line_num + 1))
    done

    # 第三步：转GBK，增加//IGNORE忽略无法转码字符，屏蔽错误输出
    if [ -f "$temp_file" ]; then
        rm -f "$filename"
        iconv -f UTF-8 -t GBK//IGNORE -c "$temp_file" > "$filename" 2>/dev/null
    fi
    
    # 删除临时文件
    rm -f "$temp_file"
    mv $filename ../output/
    echo "已生成GBK编码文件: $filename"
done

echo -e "\n✅ 所有GBK编码文件生成完成！"
