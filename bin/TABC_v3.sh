#!/bin/bash

# ====================== 依赖检查（确保bc可用） ======================
# 新增bc计算器依赖校验，解决 bc: command not found
if [ -z "$(which bc)" ]; then
    echo "错误：系统缺少bc计算工具，请先安装！"
    echo "Ubuntu执行：sudo apt install bc -y"
    exit 1
fi

# ====================== 参数校验 ======================
if [ $# -lt 3 ] || [ $# -gt 4 ]; then
    echo "用法: $0 <文件数量> <单文件总行数> <8位日期> <单批次行数,可选，默认3>"
    echo "示例: $0 3 50 20260429 5"
    exit 1
fi

FILE_COUNT=$1
LINE_COUNT=$2
DATE_8=$3  # 接收8位日期：20260429
BATCH_ROM=${4:-3} # 单批次行数

# 截取月日（MMDD）用于文件名
MMDD=${DATE_8:4:4}                # 20260429 → 0429
mkdir -p ../output
mkdir -p ../logs

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

if ! [[ $BATCH_ROM =~ ^[1-9][0-9]*$ ]]; then
    echo "错误：单批次行数必须是正整数！"
    BATCH_ROM=3
fi

# ====================== 自定义单批次基础数据（15位整数+3位小数+末尾+） ======================
data_list=(
"张三2200000100000001109+中国浙江X"
"陈天3100030000000001700+中国北京E"
"李四2500000100000003210+中国上海A"
"陈洪4500000200000001200+美国纽约G"
"刘一3500000000000001200+美国纽约G"
"陈与5000000000000000000+中国张家界H"
"王凯1100000003000000200+美国纽约I"
)

data_list_len=${#data_list[@]}
echo "基础数据条数: $data_list_len | 单批次行数: $BATCH_ROM"

# ====================== 工具函数：提取金额数值 ======================
# 提取金额串，兼容末尾+ / -，变量名仅用下划线
extract_amount_from_line() {
    local full_line="$1"
    # 先截断第一个 + 或 - 之后的所有后缀地区文字
    # 分别取出+前面、-前面两部分，取最短的就是到符号为止
    local cut_plus="${full_line%%+*}"
    local cut_minus="${full_line%%-*}"
    if [ ${#cut_plus} -lt ${#cut_minus} ]; then
        # 存在 + 符号
        local prefix_all="${full_line:0:$(( ${#cut_plus} + 1 ))}"
    else
        # 存在 - 符号
        local prefix_all="${full_line:0:$(( ${#cut_minus} + 1 ))}"
    fi
    # 从符号前的完整前缀截取最后17位
    local amount_str="${prefix_all: -17}"
    echo "$amount_str"
}

# 解析金额为可计算浮点数（兼容+、-）
extract_amount() {
    local amount_str="$1"
    # 剥离末尾正负标记
    local pure_num="${amount_str%[+-]}"
    local symbol="${amount_str: -1}"

    # 拆分13位整数、3位小数
    local int_part="${pure_num:0:13}"
    local dec_part="${pure_num: -3}"

    # 拼接带正负的小数
    local num_val="$((10#$int_part)).$dec_part"
    if [ "$symbol" = "-" ]; then
        num_val="-$num_val"
    fi
    echo "$num_val"
}

# ====================== 工具函数：格式化金额 ======================
format_amount() {
    local total=$1
    local total_int=$(echo "$total * 1000" | bc -l | awk '{print int($1)}')
    printf "%017d+" "$total_int"
}

# ====================== 核心生成逻辑（强制GBK编码） ======================
for (( file_num=1; file_num<=$FILE_COUNT; file_num++ )); do
    # 定义文件名，随机生成4位序号
    raw_serial=$((RANDOM*RANDOM % 9000 + 1000))
    serial_no="00000000$raw_serial"
    serial_no=${serial_no: -4}
    filename="F9.00001.99${serial_no}.TABC.003.${MMDD}.DAT"
    # 临时文件（先按UTF-8生成，再转换为GBK）
    temp_file="${filename}.tmp"
    > "$temp_file"

    # 第一步：计算总金额
    total_amount=0.000
    for (( i=1; i<=$LINE_COUNT; i++ )); do
        idx=$(( (i - 1) % data_list_len ))
        line_data="${data_list[$idx]}"
        amount_str=$(extract_amount_from_line "$line_data")
        amount_num=$(extract_amount "$amount_str")
		# echo "第${i}行，单笔：${amount_num}，当前累计：${total_amount}"
        total_amount=$(echo "$total_amount + $amount_num" | bc -l)
    done
    formatted_total=$(format_amount "$total_amount")

    # 第二步：写入临时文件（UTF-8）
    echo "行号: 1 | 日期: ${DATE_8} | 汇总: 总金额=${formatted_total} 本文件共${LINE_COUNT}行明细数据" >> "$temp_file"

    # 循环写入明细数据
    current_line_num=2
    for (( i=1; i<=$LINE_COUNT; i++ )); do
        idx=$(( (i - 1) % data_list_len ))
        line_data="${data_list[$idx]}"
        detail_line="行号: ${current_line_num} | 数据: ${line_data}"
        
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
    # 标准输出、标准错误屏蔽
    if [ -f "$filename" ]; then
        mv -- "$filename" ../output/ >/dev/null 2>&1
    fi
    echo "已生成GBK编码文件: $filename"

    # 记录生成日志
    current_time=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${current_time}|${filename}" >> ../logs/file_generation.log
done

echo -e "\n所有GBK编码文件生成完成！"