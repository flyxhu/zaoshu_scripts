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
# 输出根目录和日志目录
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
OUTPUT_DIR="${SCRIPT_DIR}/../output"
LOG_DIR="${SCRIPT_DIR}/../logs"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$LOG_DIR"
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

# ================ 日志函数：记录运行日志到logs目录 ==================
operation_log="${LOG_DIR}/operation_$(date +%Y%m%d).log"
run_log="${LOG_DIR}/run_$(date +%Y%m%d).log"

# 写入运行日志函数
log_run() {
    local level="$1"
    shift
    local errMsg="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf "[%s] [%s] %s\n" "$timestamp" "$level" "$errMsg" >> "$run_log"
}   

# 写入生成文件清单日志函数
log_file_generation() {
    local filename="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local raw_clean=$(tr -d '\n\r' <<<"$filename")
    local clean_blankLine=$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<<"$raw_clean")
    if [ -z "$clean_blankLine" ]; then
        log_run "WARNING" "尝试记录空文件名或含空白字符到日志，已忽略！"
        return 0
    fi
    printf "%s|%s\n" "$timestamp" "$clean_blankLine" >> "$operation_log"
}

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
    log_run "DEBUG" "解析金额: 原始=${amount_str}, 整数=${int_part}, 小数=${dec_part}, 符号=${symbol}"
    # 拼接带正负的小数
    local num_val="$((10#$int_part)).$dec_part"
    if [ "$symbol" = "-" ]; then
        num_val="-$num_val"
    fi
    echo "$num_val"
    log_run "DEBUG" "解析金额结果: ${num_val}"
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
    echo "行号: 000000000001 | 日期: ${DATE_8} | 汇总: 总金额=${formatted_total} 本文件共${LINE_COUNT}行明细数据" >> "$temp_file"

    # 循环写入明细数据
    current_line_num=2
    for (( i=1; i<=$LINE_COUNT; i++ )); do
        idx=$(( (i - 1) % data_list_len ))
        line_data="${data_list[$idx]}"
        echo_line_num=$(printf "%012d" "$current_line_num")
        detail_line="行号: ${echo_line_num} | 数据: ${line_data}"
    
        echo -n "$detail_line" >> "$temp_file"
        if [ $i -lt $LINE_COUNT ]; then
            echo "" >> "$temp_file"
        fi
        current_line_num=$((current_line_num + 1))
    done

    # 转GBK，仅临时文件非空才转码，修复2>>无空格
    if [ -f "$temp_file" ] && [ -s "$temp_file" ]; then
        rm -f "$filename"
        iconv -f UTF-8 -t GBK//IGNORE -c "$temp_file" > "$filename" 2>> "$run_log"
    else
        log_run "ERROR" "临时文件$temp_file为空或不存在，跳过生成$filename"
        rm -f "$temp_file"
        continue # 直接跳过本次循环，不处理移动
    fi

    # 删除临时文件
    rm -f "$temp_file"
    # 移动文件，报错时忽略，打印日志
    if [ -f "$filename" ]; then
        if mv "$filename" "$OUTPUT_DIR/" 2>> "$run_log"; then
            echo "GBK编码文件 ${filename}已生成"
            log_run "INFO" "文件${filename}移动至output目录成功"
            log_file_generation "$filename"
        else
            echo "文件${filename}移动失败！"
            log_run "ERROR" "mv移动文件${filename}到${OUTPUT_DIR}/失败"
        fi
    else
        echo "GBK编码文件 ${filename}生成失败"
        log_run "ERROR" "转码后文件${filename}不存在"
    fi
done

echo -e "\n所有GBK编码文件生成完成！"