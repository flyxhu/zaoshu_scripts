# zaoshu_scripts 造数脚本仓库
## 仓库结构
zaoshu_scripts/
├── bin/                # 所有正式造数脚本统一存放
│   ├── TABC_v2.sh
│   ├── TABD_v1.sh
│   └── TSDX_v1.sh
├── archive/            # 旧版本脚本归档（TABC_v1、废弃脚本）
├── output/             # 生成出来的 *.DAT 文件统一输出在这里
├── tmp/                # 脚本运行临时中转文件
├── logs/               # 运行日志
└── README.md           # 说明文档

## 脚本对应产出文件
1. bin/TABC_v2.sh → 生成 F99999.*.TABC.*.DAT
2. bin/TABD_v1.sh → 生成 F99999.*.TABD.*.DAT
3. bin/TSDX_v1.sh → 生成 F99999.*.TSDX.*.DAT

## 调用格式
./脚本名.sh  文件数量  单文件明细行数  8位日期
示例：
./bin/TABC_v2.sh 1 20 20260808

## 版本记录
TABC_v2：修正金额14位整数+3位小数截取，增加全量明细自动汇总金额，UTF-8转GBK输出