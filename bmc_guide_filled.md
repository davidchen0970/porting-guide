# BMC 通用 Porting 技術參考手冊

## 0. 手冊使用說明

### 0.1 手冊目的

本手冊用於 BMC 新平台移植、Bring-up、量產前驗證與現場問題排查。目標是把硬體連線、Boot Flow、BSP、Device Tree、Sensor、Fan、Power、Host Interface、管理介面、安全、更新、除錯與測試矩陣放在同一份文件中，降低資訊分散造成的判讀成本。

### 0.2 適用範圍

適用於使用 Linux / Yocto / OpenBMC / AMI 類 BMC 韌體的平台，常見 SoC 包含 ASPEED AST24xx/25xx/26xx、Nuvoton NPCM7xx/8xx，以及其他可執行 Linux 的 BMC SoC。

### 0.3 符號與標記規則

- `[必填]`：平台 bring-up 前必須補齊。
- `[建議]`：量產或長測前建議補齊。
- `[待確認]`：目前資訊不足，需要 HW / BIOS / CPLD / ME / FW 共同確認。
- `[量測值]`：以示波器、LA、BMC log、host log 或 register dump 取得。
- `[版本]`：需保留 commit id、tag、image version、CPLD version、BIOS version。

### 0.4 參考標準與規格書清單

- Linux kernel Device Tree、GPIO、I2C、SPI、watchdog、MTD/UBI/UBIFS 文件。
- Yocto Project / OpenEmbedded / BitBake 文件。
- DMTF Redfish、MCTP、PLDM、SPDM 規格。
- IPMI v2.0 specification。
- SoC datasheet、board schematic、CPLD register map、power sequence document。

### 0.5 名詞定義

- BMC：Baseboard Management Controller，負責 out-of-band 管理。
- BSP：Board Support Package，板級支援層，包含 kernel、bootloader、DT、recipe 與平台設定。
- DT / DTS / DTB：Device Tree source / binary，用於描述非自動枚舉硬體。
- FRU：Field Replaceable Unit，現場可更換元件及其識別資料。
- SDR：Sensor Data Record，IPMI sensor 描述資料。
- SEL：System Event Log，事件紀錄。
- UBI / UBIFS：raw flash 上的 wear leveling / volume / file system 架構。
- Redfish：DMTF 定義的 RESTful 管理 API。
- MCTP / PLDM / SPDM：平台內部管理通訊、資料模型與安全協定。

### 0.6 修訂紀錄

| 日期       | 版本 | 作者    | 內容                   |
| ---------- | ---: | ------- | ---------------------- |
| 2026-07-06 |  0.1 | Copilot | 依目錄建立第一輪填寫版 |
| 2026-07-06 |  0.2 | Copilot | 撰寫 Yocto 章節 |
| 2026-07-06 |  0.3 | Copilot | 撰寫常用變數、目錄結構與 BitBake 建構流程 |
| 2026-07-06 |  0.4 | Copilot | 撰寫在 Docker 中建立 Yocto 專案並建置完整映像 |
| 2026-07-06 |  0.5 | Copilot | 撰寫單獨建置與除錯特定套件章節 |
| 2026-07-06 |  0.6 | Copilot | 撰寫使用 .bbappend 修改套件行為章節 |
| 2026-07-06 |  0.7 | Copilot | 撰寫使用 devtool 修改原始碼並產出補丁章節 |
| 2026-07-06 |  0.8 | Copilot | 撰寫自訂 .bb Recipe 章節 |
| 2026-07-06 |  0.9 | Copilot | 撰寫進階混合開發 devtool modify / update-recipe / finish 章節 |
| 2026-07-06 |  0.10 | Copilot | OpenBMC 新 Machine Layer 與 DTS Bring-up 系統化流程 |
| 2026-07-06 |  0.11 | Copilot | 撰寫 Porting ADC Sensor |
| 2026-07-06 |  0.12 | Copilot | 撰寫 Temperature Sensor |
| 2026-07-06 |  0.13 | Copilot | 撰寫 Voltage Sensor |
| 2026-07-06 |  0.14 | Copilot | 增加 OpenBMC 常用 Project, 放在 CH11, 原有的 CH11 向後挪一章 |
| 2026-07-07 |  0.15 | Copilot | 撰寫第一章 Boot Flow 與 SoC 初始化 |
| 2026-07-07 |  0.16 | Copilot | 撰寫 Current Sensor |
| 2026-07-07 |  0.17 | Copilot | 撰寫 Power Sensor |
| 2026-07-07 |  0.18 | Copilot | 撰寫 Fan Tach Sensor |
| 2026-07-07 |  0.19 | Copilot | 撰寫 Fan PWM / Fan Control |
| 2026-07-07 |  0.20 | Copilot | 撰寫 PSU Sensor |
| 2026-07-07 |  0.21 | Copilot | 撰寫 Fan Control 與 Thermal Policy |
| 2026-07-07 |  0.22 | Copilot | 撰寫 CPU Sensor / PECI / APML |
| 2026-07-07 |  0.23 | Copilot | 撰寫 Presence / Intrusion / GPIO State Sensor Sensor |
| 2026-07-07 |  0.24 | Copilot | 撰寫 Power Control Section |
| 2026-07-08 |  0.25 | Copilot | 撰寫各類 Sensor 共用除錯指令 |
| 2026-07-08 |  0.26 | Copilot | 撰寫 CH12 基本內容 |
| 2026-07-08 |  0.27 | Copilot | 補寫 BBMASK 變數、使用情境、範例與排查流程 |
| 2026-07-09 |  0.28 | Copilot | 補寫第 2 章 Flash Partition 與儲存架構、分區表、更新 rollback、log 收集與驗收 checklist |
| 2026-07-09 |  0.29 | Copilot | 撰寫第 3 章 Pinmux / GPIO 通用設計模式、DTS 範本、OpenBMC GPIO presence、log 收集與驗收 checklist |
| 2026-07-09 |  0.30 | Copilot | 撰寫第 4 章 Reset / Clock / Power Domain、DTS 範本、domain timing、reset reason、log 收集與驗收 checklist |
| 2026-07-10 |  0.31 | Copilot | 重寫第 2 章 Flash Partition 與儲存架構，補齊 MTD / UBI / MBR / GPT、檔案系統、映像格式、更新 rollback 與 log 收集 |
| 2026-07-10 |  0.32 | Copilot | 撰寫第 5 章周邊匯流排通用知識，補強 bus map、DTS/kernel/OpenBMC 對齊、I2C/SPI/UART/PECI/eSPI/NC-SI/MCTP/PLDM/SPDM、log 收集、回查結果與驗收 checklist |
| 2026-07-10 |  0.33 | Copilot | 撰寫第 6 章 CPLD / FPGA / Board Glue Logic，補強 register map、power sequence、reset mux、fault latch、WP / flash mux、update / recovery、OpenBMC 整合、log 收集、回查結果與驗收 checklist |
| 2026-07-10 |  0.34 | Copilot | 撰寫第 8 章 Device Tree 通用寫法與排查 |
| 2026-07-10 |  0.35 | Copilot | 撰寫第 10 章 I2C / PMBus 裝置驅動架構 |
| 2026-07-10 |  0.36 | Copilot | 撰寫第 15 章 Inventory / FRU / Asset 資料模型 |
| 2026-07-10 |  0.37 | Copilot | 撰寫第 16 章 Logging / Event / Telemetry |
| 2026-07-10 |  0.38 | Copilot | 撰寫第 20 章 MCTP / PLDM / SPDM |
| 2026-07-10 |  0.39 | Copilot | 撰寫第 9 章 Kernel Driver 與核心服務 |

### 0.7 資料來源可信度分級

- A：官方標準、Linux kernel 文件、Yocto 文件、SoC datasheet、board schematic。
- B：OpenBMC 官方 repository / design document。
- C：廠商應用手冊、白皮書、公開技術文章。
- D：論壇、部落格、推測性資料，只能作為排查線索。

---

## 第一部分：硬體底層抽象層

### 1. Boot Flow 與 SoC 初始化

本章整理 BMC 從上電到管理服務可用之間的主要流程，並建立 bring-up 與故障排查時的共同語言。對新平台而言，Boot Flow 不是單一軟體問題，而是由 power rail、reset、strap、clock、boot media、DDR、bootloader、kernel、rootfs 與 userspace services 串起來的跨部門路徑。任何一層狀態不一致，都可能表現為「無 UART」、「卡 U-Boot」、「kernel panic」、「service 起不來」或「Redfish / IPMI 無回應」。

本章對齊目錄中的 1.1～1.8：BMC SoC 典型開機流程、Boot Strap / Reset Strap、SPI-NOR / SPI-NAND / eMMC 差異、DDR 初始化、Watchdog、SoC 差異、Boot failure 分類，以及當前平台量測表。

#### 1.1 BMC SoC 典型開機流程

BMC SoC 的典型開機流程可分為下列階段：

```text
AC / Standby Power Apply
    ↓
BMC standby rail 穩定，例如 3V3_AUX / 1V8 / core rail
    ↓
BMC reset deassert
    ↓
SoC BootROM 啟動
    ↓
Latch boot strap / reset strap / security strap
    ↓
BootROM 初始化最小硬體，例如 clock、boot interface、SRAM
    ↓
從 boot media 載入第一階段 bootloader
    ↓
SPL / TPL / U-Boot early stage 初始化 DDR、pinmux、UART、clock
    ↓
U-Boot 載入 kernel、DTB、rootfs 或 FIT image
    ↓
Linux kernel 啟動，完成 driver probe 與 rootfs mount
    ↓
systemd 啟動 OpenBMC services
    ↓
D-Bus / Sensor / Network / Redfish / IPMI / WebUI 可用
```

每個階段的可觀察訊號不同：

| 階段 | 主要觀察點 | 常用工具 / 量測方式 | 典型問題 |
| --- | --- | --- | --- |
| Power apply | standby rail、power good、reset input | 示波器、DMM、CPLD register | rail 未穩、reset 未釋放 |
| BootROM | boot media CS/CLK、UART 是否有最早期 log | 示波器、LA、UART | strap 錯、boot device 不可讀 |
| SPL / U-Boot early | DDR init、clock、pinmux、console | UART log、JTAG、register dump | DDR training 失敗、UART pinmux 錯 |
| U-Boot normal | bootcmd、mtdparts、env、kernel load | UART、`printenv` | bootargs 錯、DTB 錯、image offset 錯 |
| Kernel | driver probe、rootfs mount、init | `dmesg`、UART | kernel panic、rootfs 無法掛載 |
| Userspace | systemd target、D-Bus services、network | `journalctl`、`systemctl`、`busctl` | service fail、設定檔錯、network 未起 |

Bring-up 時建議先建立「最小可開機路徑」：

```text
power / reset 正常
    → UART console 可用
    → BootROM 可讀 boot media
    → U-Boot 可執行
    → kernel 可啟動
    → rootfs 可掛載
    → systemd default target 可到達
    → SSH / Redfish / IPMI 依需求逐步驗證
```

#### 1.2 Boot Strap / Reset Strap 原理

Boot strap / reset strap 是 SoC 在 reset 釋放附近擷取的硬體腳位狀態，用來決定早期啟動行為。這些腳位通常在 BootROM 或 reset controller 早期階段被 latch，之後即使腳位電位改變，也不一定會影響本次 boot 結果。

常見 strap 類型包含：

| Strap 類型 | 可能決定的項目 | Bring-up 注意事項 |
| --- | --- | --- |
| Boot source | SPI-NOR、SPI-NAND、eMMC、UART recovery | 需確認硬體 pull-up / pull-down 與 SoC datasheet 一致 |
| Boot width / mode | SPI 單線 / 雙線 / 四線、NAND bus width | BootROM 支援的模式與 flash 實際接線需一致 |
| Secure boot | enable / disable、key source | 開發版與量產版設定需分開記錄 |
| Debug mode | JTAG、UART download、recovery mode | 量產安全政策需確認是否關閉 |
| Clock source | external crystal、reference clock selection | clock 未穩會造成早期無 log |
| Address map | memory remap、boot region | 需與 bootloader linker / image offset 對齊 |

排查 strap 問題時，建議不要只看 schematic 的設計值，也要量測 reset 釋放瞬間的實際電位。部分平台會由 CPLD、buffer、multi-function pin 或 update tool 影響 strap，因此量測點需選在 SoC pin 附近或可代表 SoC input 的節點。

建議記錄欄位：

| Strap Signal | SoC Pin | Design Value | Measured Value | Latch 時間點 | Pull Resistor | Owner | 備註 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Boot source strap | [待填] | [待填] | [待填] | reset deassert 附近 | [待填] | HW/BMC | [待填] |
| Secure boot strap | [待填] | [待填] | [待填] | reset deassert 附近 | [待填] | HW/Security | [待填] |
| Debug strap | [待填] | [待填] | [待填] | reset deassert 附近 | [待填] | HW/BMC | [待填] |

#### 1.3 SPI-NOR / SPI-NAND / eMMC 初始化流程差異

不同 boot media 的 early boot 風險不同。Porting 時需把 boot media 的硬體接線、SoC BootROM 支援模式、U-Boot 設定、kernel MTD / block 設定與 image layout 一起核對。

| Boot media | 早期流程特性 | 優點 | 常見風險 |
| --- | --- | --- | --- |
| SPI-NOR | BootROM 直接以 SPI command 讀取固定 offset 或 header | Bring-up 簡單、隨機讀取容易、U-Boot 支援成熟 | 容量較小、erase block 較大、寫入壽命需控管 |
| SPI-NAND | BootROM 需處理 NAND page、ECC、bad block policy | 容量較大、成本常較有利 | bad block、ECC、UBI layout、BootROM 支援限制 |
| eMMC | BootROM 透過 MMC controller 讀 boot partition 或 user area | 容量大、block device 管理方便 | boot partition 設定、EXT_CSD、power sequence、clock training |

SPI-NOR bring-up 檢查：

```text
[ ] CS / CLK / MOSI / MISO 接線與 pinmux 正確
[ ] Flash voltage 與 SoC IO voltage 一致
[ ] BootROM 支援該 flash read opcode / address byte 數
[ ] U-Boot defconfig 啟用對應 SPI controller / SPI NOR driver
[ ] mtdparts 與 image layout 一致
[ ] 實機可用 U-Boot `sf probe`、`sf read` 讀到合理資料
```

SPI-NAND bring-up 檢查：

```text
[ ] BootROM 支援該 SPI-NAND 型號或相容初始化流程
[ ] ECC / OOB / bad block policy 與 BootROM、U-Boot、kernel 一致
[ ] UBI VID header offset、PEB size、LEB size 與 image 建置設定一致
[ ] 初始燒錄工具會避開 bad block，且保留 bootloader 必要副本
[ ] kernel log 無大量 ECC error 或 UBI attach failure
```

eMMC bring-up 檢查：

```text
[ ] eMMC power rail、reset、clock 與 DAT/CMD pull-up 正確
[ ] Boot partition enable / boot bus width / boot ack 設定符合 SoC BootROM 需求
[ ] U-Boot 可辨識 mmc device 與 partition
[ ] kernel DTS 中 bus-width、max-frequency、non-removable 等屬性與電路一致
[ ] rootfs UUID / PARTUUID / bootargs 與實際 partition 對齊
```

#### 1.4 DDR 初始化

DDR 初始化通常是 Boot Flow 中最容易卡在「很早期、資訊很少」的階段。若 SoC 需要 SPL 或 vendor DDR training binary，DDR 失敗可能表現為無後續 UART log、重複 reset、watchdog reset，或卡在固定 early boot 訊息。

DDR bring-up 需確認下列資料：

| 項目 | 說明 | 檢查方式 |
| --- | --- | --- |
| DDR type | DDR3 / DDR4 / LPDDR4 / DDR5 等 | schematic、BOM、SoC datasheet |
| 顆粒型號 | vendor、density、organization、rank | BOM、memory datasheet |
| bus width | x8 / x16、channel、rank | schematic、layout review |
| clock / reset | DDR clock、CKE、reset、ODT | 示波器、register dump |
| power rail | VDD、VDDQ、VPP、reference voltage | DMM、示波器 |
| training parameter | drive strength、ODT、timing、frequency | vendor tool、SPL log、DDR config |
| layout constraint | length matching、impedance、via、topology | layout report |

DDR 失敗排查建議：

```text
1. 確認 DDR power rail 與 reset timing 符合記憶體 datasheet。
2. 確認 SoC strap 或 bootloader 設定選到正確 DDR type / frequency。
3. 降低 DDR frequency 測試，觀察是否從完全無 log 變成可進 U-Boot。
4. 確認 DDR training log 是否有 byte lane / DQS / Vref 失敗資訊。
5. 比對 reference board 的 DDR routing、ODT、termination 與 config。
6. 若有多顆 DDR，先以最小顆數或單 rank 設定做 bring-up。
```

常見 DDR 相關現象：

| 現象 | 可能方向 | 建議檢查 |
| --- | --- | --- |
| 完全無 UART，但 power / reset 正常 | 卡在 BootROM 或 SPL 前段 DDR init | early UART 是否啟用、JTAG PC、DDR rail |
| 只印出 SPL banner 後停住 | DDR training 失敗 | SPL log level、DDR config、頻率 |
| U-Boot 可進但 kernel 隨機 panic | DDR timing 邊界、容量描述錯 | memtester、降低頻率、檢查 memory node |
| 長測出現 random crash | DDR margin 不足或電源雜訊 | 壓力測試、溫度測試、示波器量測 |

#### 1.5 Watchdog 在開機各階段的角色

Watchdog 可用來避免 BMC 卡在某個階段無限等待，但在 bring-up 期間也可能讓問題變得不容易觀察。建議在開發版先明確記錄每個階段的 watchdog 狀態，再依產品需求逐步啟用。

常見 watchdog 層級：

| Watchdog 類型 | 啟用位置 | 作用 | Bring-up 注意事項 |
| --- | --- | --- | --- |
| SoC hardware watchdog | BootROM / SPL / U-Boot / kernel | 防止早期卡死 | 開發初期可拉長 timeout，避免 log 來不及收集 |
| U-Boot watchdog | U-Boot runtime | 防止停在 bootloader | 使用 U-Boot shell debug 時需注意是否會自動 reset |
| Linux watchdog | kernel driver / systemd | userspace hang recovery | 確認 watchdog device、systemd watchdog 設定 |
| External watchdog | CPLD / supervisor IC | 監控 BMC 或整板狀態 | 需知道 clear / feed 條件與 reset 範圍 |
| Host watchdog | BIOS / BMC / IPMI | 監控 host boot 或 OS | 不等同於 BMC 自身 watchdog |

建議記錄：

```text
[ ] Watchdog source：SoC / CPLD / external supervisor / host watchdog
[ ] Timeout 時間
[ ] 啟用階段：BootROM / SPL / U-Boot / Kernel / Userspace
[ ] Feed 條件與 feed 者
[ ] Timeout 後 reset 範圍：BMC-only / full board / host-only
[ ] reset reason register 是否能保存
[ ] 開發版是否有 disable 或 extend timeout 方式
```

#### 1.6 各 SoC 開機流程差異速查

不同 BMC SoC 的 BootROM、strap、boot media 支援、DDR 初始化工具與 secure boot policy 會有差異。下表用於建立專案筆記，不取代 SoC datasheet 或 vendor application note。

| SoC 家族 | 常見 boot media | 早期初始化重點 | Bring-up 注意事項 |
| --- | --- | --- | --- |
| ASPEED AST24xx / AST25xx | SPI-NOR 為主，依平台支援其他媒體 | Boot strap、SPI controller、DDR init、UART | 確認 strap、SPI flash layout、UART pinmux、watchdog |
| ASPEED AST2600 | SPI-NOR / SPI-NAND / eMMC 依設計而定 | 多 boot source、DDR training、secure boot 選項 | 需核對 BootROM 支援模式、image layout、SPL / U-Boot 設定 |
| Nuvoton NPCM7xx / NPCM8xx | SPI-NOR / SPI-NAND / eMMC 依平台而定 | Boot block、DDR init、pinmux、clock | 需確認 vendor BSP 的 bootloader flow 與 flash layout |
| 其他 Linux BMC SoC | 視 SoC 支援 | BootROM、SPL、DDR、storage driver | 以 datasheet、EVB、vendor BSP 為主要依據 |

專案建議維護下列 SoC boot 筆記：

```text
- SoC 型號與 revision
- BootROM 支援 boot source 清單
- 實際使用 boot source
- Strap pin 對照與量測值
- Bootloader 階段：SPL / TPL / U-Boot / vendor loader
- DDR config 來源與版本
- Secure boot 狀態
- Recovery boot 方式
- UART console 與 baud rate
- reset reason register 讀取方式
```

#### 1.7 Boot Failure 分類與排查入口

Boot failure 建議先依「停在哪一層」分類，再同步量測與 log。以下分類可作為初期會議同步與 log 收集的共通格式。

| 分類 | 觀察現象 | 可能方向 | 第一輪檢查 |
| --- | --- | --- | --- |
| 無上電 | standby rail 不穩、BMC 無反應 | power rail、CPLD enable、短路、負載過大 | DMM / 示波器、PGOOD、CPLD state |
| reset 未釋放 | reset pin 持續 asserted | power good 未滿足、CPLD hold reset、strap conflict | reset line、reset source、CPLD register |
| 無 UART | 無任何 log | clock、strap、BootROM、UART pinmux、boot media | UART TX、clock、SPI CS/CLK、strap |
| BootROM 讀取失敗 | SPI/eMMC 有動作但無有效後續 | image offset、flash opcode、boot header、媒體內容 | LA、燒錄檔、boot header、flash read |
| SPL / DDR 失敗 | 有 early log 後停住 | DDR config、rail、clock、layout | SPL log、DDR rail、降頻測試 |
| U-Boot 失敗 | 可進 U-Boot 或卡 bootcmd | env、bootargs、mtdparts、kernel / DTB offset | `printenv`、`bdinfo`、`sf read` / `mmc read` |
| Kernel panic | kernel 開始後 panic | DT memory、driver、rootfs、init | panic log、bootargs、DTB、rootfs |
| rootfs mount 失敗 | VFS unable to mount root | root=、partition、UBI、filesystem type | bootargs、`/proc/mtd`、UBI log |
| userspace fail | systemd emergency 或 service failed | service dependency、設定檔、read-write partition | `systemctl --failed`、`journalctl -xb` |
| 管理介面不可用 | OS 起來但 SSH/Redfish/IPMI 不通 | network、bmcweb、IPMI daemon、firewall | IP、route、service status、journal |

第一輪 log / 量測建議：

```text
[ ] UART 全程 log，從上電前開始收
[ ] 示波器量測 standby rail、reset、clock、boot media CS/CLK
[ ] reset reason register
[ ] Boot strap 實測值
[ ] U-Boot env / bootargs / mtdparts
[ ] kernel panic 或 dmesg
[ ] systemd failed units
[ ] image version、U-Boot version、kernel commit、DTS commit
```

#### 1.8 當前平台 Boot Strap 設定與實際量測值

本節作為專案填寫區，bring-up 前至少需完成 boot source、secure boot、UART、flash、DDR 與 reset timing 的資料整理。建議每次硬體 rework、CPLD 更新、bootloader 更新或安全設定變更後同步更新。

| 項目 | 設定 / 量測值 | 資料來源 | 責任窗口 | 狀態 |
| --- | --- | --- | --- | --- |
| SoC 型號 / revision | [待填] | BOM / register | HW / BMC | [待確認] |
| Boot source strap | [待填] | schematic / 量測 | HW / BMC | [待確認] |
| Secure boot strap | [待填] | schematic / 量測 | HW / Security / BMC | [待確認] |
| Recovery mode strap | [待填] | schematic / 量測 | HW / BMC | [待確認] |
| UART console pin / header | [待填] | schematic / layout | HW / BMC | [待確認] |
| UART baud rate | [待填] | bootloader config | BMC | [待確認] |
| Boot flash 型號 / 容量 | [待填] | BOM / flash ID | HW / BMC | [待確認] |
| Boot flash voltage | [待填] | schematic / 量測 | HW | [待確認] |
| DDR 型號 / 容量 | [待填] | BOM / memory config | HW / BMC | [待確認] |
| DDR 頻率 | [待填] | bootloader config | BMC / HW | [待確認] |
| Reset deassert 時間 | [待填] | 示波器 | HW | [待確認] |
| Clock source / frequency | [待填] | schematic / 量測 | HW | [待確認] |
| Watchdog timeout | [待填] | CPLD / SoC / systemd | BMC / HW | [待確認] |
| U-Boot version | [待填] | UART log / image manifest | BMC | [待確認] |
| Kernel version / commit | [待填] | `uname -a` / manifest | BMC | [待確認] |
| DTS / DTB 版本 | [待填] | build output / manifest | BMC | [待確認] |

Bring-up 驗收建議：

```text
[ ] AC on 後 BMC 可穩定進 U-Boot
[ ] BMC 可穩定進 Linux kernel
[ ] rootfs 可掛載且 systemd default target 可到達
[ ] `systemctl --failed` 無關鍵 service 失敗
[ ] SSH 或 serial login 可用
[ ] Redfish service 依平台需求可回應
[ ] reset reason 可正確描述上一輪 reset 來源
[ ] AC cycle / BMC reset / watchdog reset 行為已建立 baseline
```

#### 1.9 本章參考資料與交叉引用

- Flash layout 與 partition 細節請參考第 2 章。
- Pinmux、GPIO、reset、clock 與 power rail 細節請參考第 3、4 章。
- Boot media 牽涉 SPI、eMMC、I2C / SMBus 等介面時，請參考第 5 章。
- Yocto / U-Boot / kernel / DTS 建構與修改流程請參考第 7、8、9 章。
- 故障分析與 log 收集方法請參考第 25、26 章。


### 2. Flash Partition 與儲存架構

本章整理 BMC 韌體在 flash / eMMC / SD / SSD 類儲存媒體上的分層架構、分割區規劃、檔案系統選擇、映像格式、更新流程、rollback、資料保存與排查方法。這一章先把名詞分清楚，再談各種 layout，避免把「分割區」、「檔案系統」與「更新包格式」混在同一層討論。

BMC 平台常同時出現 SPI-NOR、SPI-NAND、eMMC、MTD partition、UBI volume、SquashFS、UBIFS、ext4、OverlayFS、`.static.mtd.tar`、`.ubi.mtd.tar`、`.wic`、`fitImage` 等名詞。這些不是同一類東西：有些描述儲存媒體，有些描述空間切割，有些描述可 mount 的檔案系統，有些只是 build / 燒錄 / 更新時使用的封裝格式。若不先建立分層模型，後面排查 rootfs mount failure、update failure、rollback failure、rwfs 滿載或 factory reset 時，很容易找錯層。

#### 2.1 三層模型：分割區、檔案系統、檔案格式

建議先用下列三層模型理解本章：

```text
儲存媒體 / Storage media
    ↓
分割區 / Volume：資料放在哪一段空間
    ↓
檔案系統：這段空間如何被 kernel mount 與讀寫
    ↓
檔案格式 / 映像格式：build、燒錄、更新、傳輸時如何封裝
```

| 層級 | 回答的問題 | 常見例子 | 常見檢查方式 |
| --- | --- | --- | --- |
| 儲存媒體 | 實體或邏輯儲存裝置是什麼？ | SPI-NOR、SPI-NAND、eMMC、SD、SATA SSD、NVMe | schematic、BOM、dmesg、`lsblk`、`cat /proc/mtd` |
| 分割區 / Volume | 資料放在儲存媒體哪一段？ | MTD partition、UBI volume、MBR partition、GPT partition | `/proc/mtd`、`cat /proc/partitions`、`lsblk`、`sfdisk -l`、`sgdisk -p`、`ubinfo -a` |
| 檔案系統 | 分割區 / volume 內如何被 mount 與讀寫？ | SquashFS、JFFS2、UBIFS、ext4、OverlayFS、tmpfs | `findmnt -R /`、`mount`、`cat /proc/mounts`、`dmesg` |
| 檔案格式 / 映像格式 | build output、燒錄檔、更新包長什麼樣子？ | `.squashfs`、`.ubifs`、`.ubi`、`.wic`、`.mtd.tar`、`fitImage`、`MANIFEST` | `file`、`tar tf`、`sha256sum`、`tar xfO image.tar MANIFEST` |

幾個容易混淆的例子：

- `rofs` 通常是 partition / volume name，不是檔案系統名稱。`rofs` 裡常放 SquashFS。
- `rwfs` 也是 partition / volume name，裡面可能是 JFFS2、UBIFS 或 ext4。
- UBI 是 raw flash 上的 volume / wear leveling / bad block 管理層；UBIFS 才是可 mount 的檔案系統。
- `.ubi` 是 UBI image，可能含多個 UBI volume；其中某個 volume 可能放 UBIFS，也可能放 SquashFS。
- `.mtd.tar` 是 OpenBMC 更新包格式，不是檔案系統。
- `.wic` 通常是 disk image，常用於 eMMC / SD 類 block device，裡面可包含 MBR / GPT 與多個 partition。
- OverlayFS 是 runtime merged view，由 lowerdir、upperdir、workdir 組成，不是單一 partition。

#### 2.2 Raw flash 與 block device 的分割方式

BMC 儲存媒體大致可分為 raw flash 類與 block device 類。兩者的分割區描述方式不同，不能直接套同一套名詞。

| 儲存類型 | Linux 視角 | 分割區 / volume 描述方式 | 常見 device | MBR / GPT 適用性 |
| --- | --- | --- | --- | --- |
| SPI-NOR | MTD raw flash | DTS fixed-partitions、U-Boot `mtdparts`、platform flash layout | `/dev/mtd0`、`/dev/mtd1` | 通常不使用 MBR / GPT |
| SPI-NAND / raw NAND | MTD raw flash | MTD partition + UBI volume table | `/dev/mtdX`、`/dev/ubi0_*` | 通常不使用 MBR / GPT |
| eMMC | block device | MBR 或 GPT partition table | `/dev/mmcblk0p1`、`/dev/mmcblk0p2` | 適用，BMC 新平台建議優先 GPT |
| SD / USB mass storage | block device | MBR 或 GPT partition table | `/dev/sdX1`、`/dev/mmcblkXp1` | 適用 |
| SATA / NVMe | block device | MBR 或 GPT partition table | `/dev/sdX1`、`/dev/nvme0n1p1` | 適用 |

##### 2.2.1 MTD partition

MTD partition 用於 raw flash。它描述 flash 上固定 offset 與 size 的區段，常由 Device Tree `fixed-partitions` 或 kernel cmdline `mtdparts` 建立。

```text
mtd0: u-boot
mtd1: u-boot-env
mtd2: kernel
mtd3: rofs
mtd4: rwfs
```

MTD partition 重點：

- offset / size 需對齊 erase block。
- partition name 需與 U-Boot、initramfs、update service 使用的名稱一致。
- raw NAND / SPI-NAND 需另外考慮 bad block、ECC、OOB 與燒錄工具。
- MTD partition 不等同於 filesystem；例如 `mtd3: rofs` 裡可能放 SquashFS raw image。

##### 2.2.2 UBI volume

UBI 通常建立在某個 MTD partition 上，例如 `mtd3: ubi`。UBI attach 後，裡面會有多個 UBI volume。

```text
mtd3: ubi

ubi0:kernel-a
ubi0:rofs-a
ubi0:kernel-b
ubi0:rofs-b
ubi0:rwfs
```

UBI volume 重點：

- UBI 管理 raw flash 的 wear leveling、bad block 與 volume table。
- UBI volume 可分 static / dynamic。readonly image 常用 static volume；可寫資料常用 dynamic volume。
- `rofs-a` 這類 UBI volume 裡可放 SquashFS，並透過 ubiblock 提供 block-like 介面給 kernel mount。
- `rwfs` 這類 UBI volume 則常放 UBIFS。
- UBI volume 不等同於 GPT partition，`ubinfo -a` 才是主要檢查入口。

##### 2.2.3 MBR / GPT partition table

MBR / GPT 用於 block device，例如 eMMC、SD、SATA SSD、NVMe。BMC 若使用 eMMC 作為 rootfs / data 儲存，應在本章明確記錄 partition table 類型。

| 項目 | MBR | GPT |
| --- | --- | --- |
| 適用情境 | legacy boot、舊工具鏈、簡單 partition layout | 新平台、A/B slot、多 partition、需要穩定識別 |
| Partition 數量 | 傳統限制較多 | 支援更多 partition |
| 識別方式 | device node、partition type | PARTUUID、partition name、GUID |
| 備援資訊 | 較少 | 有 primary / backup GPT header |
| BMC 建議 | 除非 bootloader / 工具鏈限制，否則不優先 | eMMC 新平台建議優先評估 |

GPT 對 BMC eMMC 平台通常比較友善，原因如下：

- 可使用 `PARTUUID`，bootargs 比 `/dev/mmcblk0p2` 穩定。
- 可使用 partition name，例如 `rootfs-a`、`rootfs-b`、`rw-data`。
- 適合 A/B slot 與多 partition 規劃。
- 有 primary / backup GPT header，便於偵測 partition table 損壞。
- Yocto `.wic` 常用於產生含 partition table 的 eMMC / SD image。

注意：MBR / GPT 只描述 block device 上的 partition table，不等同於檔案系統，也不等同於 update image format。

例如 eMMC 上可能是：

```text
GPT partition table
  ├─ rootfs-a partition：裡面放 SquashFS 或 ext4
  ├─ rootfs-b partition：裡面放 SquashFS 或 ext4
  └─ rw-data partition：裡面放 ext4

build output：obmc-phosphor-image-<machine>.wic
```

同樣地，SPI-NOR / SPI-NAND 這類 raw flash 通常不使用 MBR / GPT：

```text
SPI-NOR：DTS fixed-partitions / U-Boot mtdparts → MTD partitions
SPI-NAND：DTS fixed-partitions / U-Boot mtdparts → MTD partition → UBI volumes
```

#### 2.3 檔案系統選型

檔案系統決定 partition / volume 內的資料如何被 kernel mount 與讀寫。選型時需考量媒體類型、是否可寫、容量、power loss、wear、更新方式與資料保存政策。

| 檔案系統 / Layer | 適用媒體 | 常見用途 | 優點 | 注意事項 |
| --- | --- | --- | --- | --- |
| SquashFS | MTD / UBI static volume / block partition | readonly rootfs | 壓縮率高、內容固定、適合 image 更新 | 不可直接寫；需搭配 OverlayFS 或重新產生 image |
| JFFS2 | MTD raw flash | 小型 writable partition | 架構簡單、適合小 NOR | mount / scan 成本與容量相關；大型 NAND 不建議優先選 |
| UBI | MTD raw flash | volume / wear leveling / bad block 管理 | raw NAND / SPI-NAND 友善 | 不是 filesystem；需設定 PEB、LEB、VID header、volume |
| UBIFS | UBI dynamic volume | `/var`、persistent config、rwfs | 支援 journal / compression，適合 raw flash | 不適用 eMMC / block device |
| ubiblock + SquashFS | UBI static volume | raw flash 上的 readonly rootfs | 讓 SquashFS 放在 UBI volume 內 | rootfs volume、bootcmd、bootargs 需一致 |
| ext4 | block device | eMMC rootfs / data / log | 成熟、工具完整 | 需規劃 journal、fsck、power loss、wear |
| OverlayFS | lower + upper filesystem | readonly rootfs + writable upper | rootfs 可保持唯讀，變更落在 upper | upperdir / workdir 需在同一 filesystem，空間需監控 |
| tmpfs | RAM | `/run`、`/tmp`、暫存上傳 image | 不寫 flash | 受 RAM 限制，重開機即消失 |

OverlayFS 建議明確記錄 lower / upper / workdir：

```text
lowerdir: readonly rootfs，例如 SquashFS
upperdir: writable data，例如 UBIFS / JFFS2 / ext4
workdir : 與 upperdir 位於同一 filesystem 的工作目錄
merged  : userspace 看到的 root filesystem
```

排查 rootfs 可寫資料遺失時，不能只看 `rofs` 是否正常，還要查 OverlayFS 是否正確掛載、upper filesystem 是否可寫、space / inode 是否滿載。

```sh
findmnt -R /
cat /proc/mounts | grep -E 'overlay|squashfs|ubifs|jffs2|ext4'
dmesg | grep -Ei 'overlay|squashfs|ubi|ubifs|jffs2|ext4'
df -h
df -i
```

#### 2.4 檔案格式 / 映像格式

檔案格式 / 映像格式是 build、燒錄、更新、傳輸時的封裝方式，不一定等同 target 上最後 mount 的 filesystem。

| 格式 | 層級 | 常見用途 | 注意事項 |
| --- | --- | --- | --- |
| `.squashfs` | filesystem image | readonly rootfs | 可被放入 MTD partition、UBI volume 或 block partition |
| `.ext4` | filesystem image | eMMC rootfs / data | 通常寫入 block partition 或包入 `.wic` |
| `.ubifs` | filesystem image | UBIFS volume 內容 | 需搭配正確 `mkfs.ubifs` 參數 |
| `.ubi` | UBI image | 內含 UBI volume table 與 volumes | 不是 UBIFS；可能包含 SquashFS volume 與 UBIFS volume |
| `.wic` | disk image | eMMC / SD 類整碟映像 | 通常含 MBR / GPT 與多個 partition |
| `.mtd` / raw image | raw flash image | 工廠燒錄或整顆 flash image | raw NAND 場景需確認 bad block / ECC / OOB policy |
| `.static.mtd.tar` | update package | OpenBMC static MTD 更新包 | tar 內通常含 partition image 與 MANIFEST |
| `.ubi.mtd.tar` | update package | OpenBMC UBI layout 更新包 | tar 內檔案需對應 updater 期待的 partition / volume |
| `fitImage` | boot image container | kernel / DTB / initramfs bundle，可搭簽章 | bootcmd、load address、signature policy 需對齊 |
| `.dtb` | hardware description blob | Device Tree binary | kernel 實際載入哪一份 DTB 需確認 |
| `MANIFEST` | metadata | version、purpose、MachineName、簽章資訊 | update service 驗證依據之一 |

常見對照：

```text
範例 A：SPI-NOR static MTD
  儲存媒體：SPI-NOR
  分割區：mtd3 = rofs
  檔案系統：SquashFS
  映像檔：obmc-phosphor-image-<machine>.squashfs
  更新包：obmc-phosphor-image-<machine>.static.mtd.tar

範例 B：SPI-NAND UBI
  儲存媒體：SPI-NAND
  MTD 分割區：mtd3 = ubi
  UBI volume：ubi0:rofs-a、ubi0:rwfs
  檔案系統：rofs-a 內為 SquashFS，rwfs 內為 UBIFS
  映像檔：obmc-phosphor-image-<machine>.ubi
  更新包：obmc-phosphor-image-<machine>.ubi.mtd.tar

範例 C：eMMC GPT A/B
  儲存媒體：eMMC
  Partition table：GPT
  分割區：rootfs-a、rootfs-b、rw-data
  檔案系統：rootfs-a/b 可為 SquashFS 或 ext4，rw-data 可為 ext4
  映像檔：obmc-phosphor-image-<machine>.wic
```

#### 2.5 設計目標與分區原則

Flash / storage layout 的設計目標不是只讓 image 能開機，而是要同時滿足可更新、可回復、可保存、可追蹤與安全需求。

| 目標 | 說明 | 常見設計手段 |
| --- | --- | --- |
| 可開機 | BootROM、SPL、U-Boot、kernel、DTB、rootfs offset 正確 | 固定 offset、DTS fixed-partitions、U-Boot mtdparts / bootargs、GPT PARTUUID |
| 可更新 | 支援 Redfish / Web / scp / TFTP / local update | image manifest、software manager、A/B slot、activation state |
| 可回復 | 更新失敗可回到前一版或 golden image | boot attempt counter、boot priority、rollback policy、recovery partition |
| 可保存 | 網路設定、使用者、SSH key、FRU cache、event log 不因更新消失 | rwfs、persistent volume、白名單搬移、factory reset policy |
| 可控風險 | 降低任意寫入 rootfs、power loss、wear 對系統的影響 | readonly rootfs、OverlayFS、UBI、fsync policy、log rotation |
| 可追蹤 | 現場能判讀目前 running slot、image version、partition map | `/proc/mtd`、`lsblk`、`ubinfo`、`fw_printenv`、manifest、os-release、journal |
| 安全 | 支援 secure boot、image signature、anti-rollback、field mode | 簽章驗證、唯讀 golden image、rollback index、write protect |

分區規劃建議：

- BootROM 會讀取的區域需符合 SoC datasheet / BootROM 要求的 offset、header、alignment 與 media type。
- bootloader 與 bootloader env 分開管理；env 應有 CRC / redundant env 或可恢復預設值。
- kernel、DTB、rootfs 與 rw data 需明確切開，避免更新 rootfs 時碰到 persistent data。
- readonly rootfs 建議使用 SquashFS / EROFS / dm-verity 類設計，將內容變更收斂到正式 image build。
- writable data 需依資料重要性分層，不建議把大量 log、dump、temporary image 與永久設定放在同一小區域。
- raw NAND / SPI-NAND 需要將 bad block、ECC、OOB、VID header offset、PEB / LEB size 納入規劃。
- eMMC / SD / SSD 類 block device 需考量 MBR / GPT、fsck、journal、power loss、wear 與 discard / trim policy。
- BMC 新平台若使用 eMMC，建議優先評估 GPT，並使用 PARTUUID / UUID / label，避免 device enumeration 改變導致 rootfs 找錯。
- A/B slot 需要一套明確的「誰選 slot、誰標記成功、誰回退」機制，不能只把分區複製兩份。
- Golden image / recovery image 若作為最後救援入口，應有 write protect 或更新權限控管。
- 每次更動分區表、image type、U-Boot env、DTS fixed-partitions、`.wks` 或 update script，都要同步更新本章表格與測試紀錄。

#### 2.6 常見 BMC Flash / Storage Layout 模式

##### 2.6.1 SPI-NOR + static MTD

適用於 SPI-NOR 容量有限、平台更新流程相對單純的情境。

```text
0x00000000  u-boot          fixed, bootloader
0x00100000  u-boot-env      fixed, boot variables
0x00120000  kernel          Linux kernel / fitImage
0x00720000  rofs            SquashFS readonly rootfs
0x03920000  rwfs            JFFS2 / writable overlay
```

Bring-up 重點：

- DTS fixed-partitions、U-Boot mtdparts、kernel bootargs、image package 內的 partition name 必須一致。
- `/proc/mtd` 中 partition name 需與 init script / update script 使用的名稱一致，例如 `kernel`、`rofs`、`rwfs`。
- U-Boot env offset / size 不可與其他分區重疊；若有 redundant env，兩份 env 都要列入表格。
- `rwfs` 若使用 JFFS2，需確認 erase block size、cleanmarker、mount time 與容量是否符合需求。
- log 與 dump 優先放 tmpfs 或外部收集系統，避免小 NOR 上的 `rwfs` 被寫滿。

##### 2.6.2 SPI-NAND / raw NAND + UBI

適用於 raw flash 容量較大且需要 wear leveling 的平台。典型架構會將一段 MTD partition attach 成 UBI device，內含多個 UBI volume。

```text
MTD partitions:
  mtd0: u-boot
  mtd1: u-boot-env
  mtd2: fit / kernel fallback
  mtd3: ubi

UBI volumes on mtd3:
  kernel-a     static / dynamic volume, FIT or kernel
  rofs-a       static volume, SquashFS via ubiblock
  kernel-b     static / dynamic volume
  rofs-b       static volume, SquashFS via ubiblock
  rwfs         dynamic volume, UBIFS
```

Bring-up 重點：

- 確認 BootROM 與 U-Boot 是否能處理 SPI-NAND 的 ECC、OOB 與 bad block policy。
- 初次燒錄需使用適合 UBI 的工具與參數，例如 `ubiformat` / `ubinize` / platform flash writer。
- kernel bootargs 常見包含 `ubi.mtd=`、`root=`、`rootfstype=ubifs` 或 `root=/dev/ubiblockX_Y`。
- UBI attach log 對排查很重要，需留意 PEB size、LEB size、VID header offset、bad PEB、volume table。
- 不建議把 UBIFS 映像用一般 block 寫入方式直接 `dd` 到 raw NAND；需確認工具是否保留 UBI / ECC / bad block 語意。

##### 2.6.3 eMMC + MBR / GPT + ext4 / SquashFS

適用於需要大容量、較多 log / dump / factory data 的平台。eMMC 是 block device，底層已有 FTL，因此不使用 UBIFS。

```text
/dev/mmcblk0boot0      optional bootloader area
/dev/mmcblk0boot1      optional backup bootloader area
/dev/mmcblk0p1         boot / EFI / FIT / kernel
/dev/mmcblk0p2         rootfs-a
/dev/mmcblk0p3         rootfs-b
/dev/mmcblk0p4         rw-data
/dev/mmcblk0p5         logs / dumps / factory, optional
```

建議：

- 新平台優先評估 GPT；若使用 MBR，需留下 bootloader / tool 限制原因。
- bootargs 優先使用 PARTUUID / UUID / label，避免 `/dev/mmcblk0pX` 編號變動造成 rootfs 找錯。
- 若用 `.wic` 產生 eMMC image，需保存 `.wks`、partition label、partition type、alignment、filesystem type。
- ext4 需評估 journal mode、commit interval、fsck policy、systemd mount timeout 與突然斷電測試結果。
- 若使用 dm-verity / signed rootfs，rootfs partition 應保持唯讀，persistent data 放獨立 partition。
- eMMC health / lifetime estimate 若可讀，應納入量產診斷與現場 log。

##### 2.6.4 SPI-NOR + eMMC 混合架構

部分 SoC BootROM 只支援從 SPI-NOR 啟動，但平台需要較大 rootfs / data 空間，此時常見做法是 SPI-NOR 放 bootloader / recovery，eMMC 放 kernel / rootfs / data。

| 區域 | 媒體 | 用途 | 風險 |
| --- | --- | --- | --- |
| BootROM 讀取區 | SPI-NOR | SPL / U-Boot | SPI-NOR layout 與 recovery 需穩定 |
| Boot config | SPI-NOR / U-Boot env | root device、slot metadata | env 損壞可能造成找不到 eMMC |
| rootfs-a/b | eMMC GPT partition | A/B rootfs | bootargs / PARTUUID 需對齊 |
| rw-data | eMMC GPT partition | persistent data | factory reset 範圍需明確 |
| recovery | SPI-NOR 或 eMMC | rescue image | 需定義入口與退出條件 |

#### 2.7 A/B slot、Golden image 與 rollback

A/B slot 的核心是「新 image 先寫到非目前 running slot，下一次開機試跑新 slot，確認成功後才標記為穩定」。可套用於 MTD、UBI 或 eMMC，但所需 metadata 與 bootloader policy 需提早定義。

| 項目 | 建議定義 |
| --- | --- |
| Slot 名稱 | A/B、primary/backup、image0/image1，需全文件一致 |
| Slot 內容 | kernel、DTB、rootfs 是否都雙份；rwfs 是否共用 |
| Boot selection | U-Boot env、CPLD register、bootloader metadata、GPT partition attribute、software manager |
| Trial boot | 新 slot 啟動前是否設定 bootcount / upgrade_available |
| Success criteria | systemd target 到達、BMC service ready、network ready、版本暴露成功 |
| Mark-good 時機 | 首次成功 boot 後由 userspace 或 update manager 寫回 env / metadata |
| Rollback 條件 | kernel panic、rootfs mount 失敗、watchdog reset、mark-good timeout |
| Persistent data | 更新與 rollback 期間是否共用，schema migration 如何處理 |
| 安全政策 | anti-rollback index、簽章驗證、field mode、golden image 更新權限 |

常見風險：

- rootfs A/B 有做，但 kernel / DTB 仍只用單份，導致 rollback 不完整。
- U-Boot env 更新中斷後無法判斷 active slot；建議評估 redundant env 或 metadata journal。
- userspace 未完成 mark-good，但 watchdog timeout 太短，造成反覆回退。
- rwfs 共用後，新版 service 寫入的設定與舊版 service 不相容；需有 migration / downgrade policy。
- eMMC GPT A/B 若只靠 partition number，不使用 PARTUUID / label，後續調整 partition table 時容易造成 bootargs mismatch。

Golden / recovery image 建議：

- Golden image 預設唯讀，更新流程需有明確授權、簽章與維修程序。
- Golden image 功能可精簡，但至少應具備網路、更新服務、基本 shell / serial、版本資訊與硬體識別能力。
- 若 golden image 與 production image 共用 rwfs，需避免 rescue flow 寫壞 production 設定。
- 需定義啟動條件：strap、GPIO、CPLD register、bootcount failed、手動指令、watchdog rollback。
- 需定義退出條件：成功重新刷寫 production image 後是否自動切回 primary。

#### 2.8 分區表與平台必填資料

Bring-up 前至少填完下表，並在每次更動 image layout / U-Boot env / DTS / `.wks` / update service 後更新。

| 項目 | 目前平台值 | 資料來源 | 責任窗口 | 狀態 |
| --- | --- | --- | --- | --- |
| Boot media 類型 | [待填] | schematic / BOM / SoC strap | HW / BMC | [待確認] |
| Flash / eMMC 型號 | [待填] | BOM / jedec id / ext_csd | HW | [待確認] |
| 容量 | [待填] | datasheet / kernel log | HW / BMC | [待確認] |
| Raw flash erase block / page size | [待填] | datasheet / mtdinfo | BMC | [待確認] |
| Block device sector size | [待填] | lsblk / sysfs | BMC | [待確認] |
| ECC / OOB policy | [待填] | SoC BSP / NAND datasheet | BMC / HW | [待確認] |
| MBR / GPT | [待填] | `sfdisk -l` / `sgdisk -p` / `.wks` | BMC | [待確認] |
| U-Boot env offset / size | [待填] | U-Boot config / fw_env.config | BMC | [待確認] |
| Redundant env | [待填] | U-Boot config | BMC | [待確認] |
| Partition source | DTS / mtdparts / UBI volume / MBR / GPT [待填] | DTS / bootargs / build artifacts | BMC | [待確認] |
| Update image type | static.mtd.tar / ubi.mtd.tar / wic / custom [待填] | tmp/deploy/images | BMC | [待確認] |
| A/B slot | 有 / 無 [待填] | update design | BMC / PM | [待確認] |
| Golden / recovery image | 有 / 無 [待填] | schematic / image layout | BMC / HW | [待確認] |
| Persistent data policy | rwfs / overlay / whitelist [待填] | init script / service config | BMC | [待確認] |
| Factory reset scope | [待填] | product policy | BMC / PM / Security | [待確認] |
| Secure boot / signature | [待填] | security design | Security / BMC | [待確認] |
| Rollback policy | [待填] | update design | BMC / QA | [待確認] |

分區明細範本：

| 名稱 | Device / Volume | Offset / Start | Size | Partition table / Volume layer | FS | Mount point | 更新時是否覆寫 | 保存策略 | 備註 |
| --- | --- | ---: | ---: | --- | --- | --- | --- | --- | --- |
| u-boot | mtd0 | [待填] | [待填] | MTD | none | N/A | 預設否 | golden / factory tool | BootROM 讀取路徑 |
| u-boot-env | mtd1 | [待填] | [待填] | MTD | env | N/A | 依流程 | redundant env [待填] | fw_env.config 需對齊 |
| kernel-a | mtd2 / ubi volume / p1 | [待填] | [待填] | MTD / UBI / GPT | FIT / Image | N/A | 是 | A slot | [待填] |
| rofs-a | mtd3 / ubi volume / p2 | [待填] | [待填] | MTD / UBI / GPT | SquashFS / ext4 | / lower | 是 | A slot | [待填] |
| kernel-b | [待填] | [待填] | [待填] | [待填] | [待填] | N/A | 是 | B slot | [待填] |
| rofs-b | [待填] | [待填] | [待填] | [待填] | SquashFS / ext4 | / lower | 是 | B slot | [待填] |
| rwfs / rw-data | [待填] | [待填] | [待填] | MTD / UBI / GPT | JFFS2 / UBIFS / ext4 | /var、/etc overlay | 否 | 保存 | 需監控容量與 inode |
| logs / dumps | [待填] | [待填] | [待填] | block / UBI | ext4 / UBIFS | /var/log / dumps | 視政策 | 可清除 | 避免擠壓設定空間 |
| recovery | [待填] | [待填] | [待填] | [待填] | [待填] | rescue root | 預設否 | write protect | [待填] |

#### 2.9 Device Tree、U-Boot、Yocto 與 update service 對齊

Flash / storage layout 可能同時出現在 DTS、U-Boot env、Yocto image recipe、`.wks`、initramfs script、update service 與文件中。排查時需先確認「哪一份資料是目前 running image 實際使用的來源」。

| 來源 | 檔案 / 指令 | 作用 |
| --- | --- | --- |
| Device Tree fixed-partitions | `arch/.../dts/*.dts` | raw flash 上建立 `/proc/mtd` partition |
| U-Boot mtdparts | `printenv mtdparts` / `bootargs` | bootloader 與 kernel partition 傳遞 |
| U-Boot env config | `/etc/fw_env.config` | Linux userspace 讀寫 env offset |
| UBI config | ubinize cfg / image recipe | 建立 UBI volume table 與 volume 內容 |
| WIC layout | `.wks` / image recipe | 建立 eMMC / SD disk image、MBR / GPT、partition filesystem |
| Initramfs / preinit | obmc init scripts、preinit-mounts | 掛載 rofs / rwfs / overlay |
| Update service | phosphor-bmc-code-mgmt / platform updater | 擷取 tar、驗證 manifest、寫入分區 / volume |

DTS fixed-partitions 範例：

```dts
&fmc {
    status = "okay";

    flash@0 {
        status = "okay";
        m25p,fast-read;
        label = "bmc";

        partitions {
            compatible = "fixed-partitions";
            #address-cells = <1>;
            #size-cells = <1>;

            uboot@0 {
                label = "u-boot";
                reg = <0x00000000 0x00100000>;
                read-only;
            };

            uboot_env@100000 {
                label = "u-boot-env";
                reg = <0x00100000 0x00020000>;
            };

            kernel@120000 {
                label = "kernel";
                reg = <0x00120000 0x00600000>;
            };

            rofs@720000 {
                label = "rofs";
                reg = <0x00720000 0x03200000>;
            };

            rwfs@3920000 {
                label = "rwfs";
                reg = <0x03920000 0x006e0000>;
            };
        };
    };
};
```

fw_env.config 範例：

```text
# device       offset      env-size    sector-size
/dev/mtd1      0x0000      0x10000     0x10000
# redundant env 範例：
# /dev/mtd2    0x0000      0x10000     0x10000
```

eMMC / GPT bootargs 建議：

```text
root=PARTUUID=<rootfs-a-partuuid> rootfstype=squashfs ro
# 或
root=UUID=<rootfs-uuid> rootwait ro
```

檢查重點：

- raw flash：DTS partition label、U-Boot `mtdparts`、update package 內名稱需一致。
- UBI：`ubi.mtd=`、volume name、ubinize cfg、update service target 需一致。
- eMMC：`.wks`、GPT partition name、PARTUUID、bootargs、systemd mount unit 需一致。
- A/B：active slot metadata、bootargs、軟體 inventory、functional association 需能互相對照。

#### 2.10 Build 與 image 產出檢查

常用檢查：

```sh
# build 端：確認 image type 與輸出
bitbake -e obmc-phosphor-image | grep '^IMAGE_FSTYPES='
bitbake -e obmc-phosphor-image | grep -E '^(MACHINE|DISTRO|FLASH_SIZE|IMAGE_ROOTFS_SIZE)='
ls -lh tmp/deploy/images/${MACHINE}/

# 檢查 tar 內容與 manifest
tar tf tmp/deploy/images/${MACHINE}/*.mtd.tar | sort
tar xfO tmp/deploy/images/${MACHINE}/*.mtd.tar MANIFEST

# 檢查常見 image
ls -lh tmp/deploy/images/${MACHINE}/*{squashfs,ubi,wic,ext4,mtd.tar} 2>/dev/null

# 若是 wic image，可進一步檢查 partition table
wic ls tmp/deploy/images/${MACHINE}/*.wic 2>/dev/null || true
```

需保存：

| 資料 | 範例指令 | 用途 |
| --- | --- | --- |
| image manifest | `tar xfO image.tar MANIFEST` | 驗證 version、purpose、MachineName、KeyType |
| image type | `bitbake -e image | grep IMAGE_FSTYPES` | 確認 static / UBI / wic |
| partition config | DTS、ubinize cfg、`.wks` | 確認 layout source |
| U-Boot config | grep `CONFIG_ENV_`、`CONFIG_BOOTCOUNT` | 確認 env / bootcount / A/B policy |
| kernel config | grep MTD、UBI、UBIFS、OVERLAY_FS、EXT4、MMC | 確認 filesystem / media 支援 |
| deploy checksum | `sha256sum image` | 現場比對 |

#### 2.11 Target 端檢查指令與 log 收集

##### 2.11.1 Partition / volume / filesystem

```sh
# raw flash / MTD
cat /proc/mtd
mtdinfo -a 2>/dev/null

# UBI / UBIFS
ubinfo -a 2>/dev/null
cat /sys/class/ubi/ubi*/mtd_num 2>/dev/null
cat /sys/class/ubi/ubi*/volumes_count 2>/dev/null

# block device / MBR / GPT
cat /proc/partitions
lsblk -f 2>/dev/null
blkid 2>/dev/null
sfdisk -l 2>/dev/null
sgdisk -p /dev/mmcblk0 2>/dev/null || true

# mount 與空間
findmnt -R /
mount
cat /proc/mounts
df -h
df -i
```

##### 2.11.2 Kernel log pattern

```sh
dmesg | grep -Ei 'mtd|spi-nor|spi.*nand|nand|ubi|ubifs|jffs2|squashfs|overlay|mmc|gpt|mbr|partition|ext4|verity|vfs'
dmesg -T > /tmp/dmesg-storage.txt
journalctl -b > /tmp/journal-storage.txt
```

| Log pattern | 可能方向 | 後續檢查 |
| --- | --- | --- |
| `mtd: partition ... extends beyond the end` | DTS / mtdparts size 超出 flash | 核對 flash size、partition offset |
| `spi-nor ... unrecognized JEDEC id` | flash 型號或 SPI wiring / mode 問題 | JEDEC ID、DTS compatible、SPI clock |
| `UBI error: bad VID header offset` | ubinize / kernel UBI 參數不一致 | VID header、min_io_size、sub-page |
| `UBI: attaching mtdX` 後失敗 | bad block、ECC、volume table 問題 | mtdinfo、ubiformat、flash dump |
| `UBIFS error` | UBIFS metadata 或 mount 參數問題 | ubinfo、journal、power loss 歷史 |
| `SQUASHFS error` | rofs 損壞或讀取錯誤 | image checksum、flash readback |
| `overlayfs: upper fs does not support xattr` | upper filesystem 不符合 OverlayFS 需求 | rwfs filesystem、mount option |
| `VFS: Cannot open root device` | root= / rootfstype / initramfs 錯 | bootargs、initramfs、partition name |
| `GPT: Use GNU Parted to correct GPT errors` | GPT header / backup table 異常 | `sgdisk -v`、image / flash readback |
| `EXT4-fs warning/error` | eMMC / ext4 / power loss 問題 | fsck、eMMC health、journal policy |

##### 2.11.3 U-Boot env 與 slot 狀態

```sh
fw_printenv 2>/tmp/fw_printenv.err | sort
cat /tmp/fw_printenv.err
fw_printenv bootcount upgrade_available bootlimit 2>/dev/null
fw_printenv obmc_bootpart openbmconce bootargs mtdparts 2>/dev/null
```

若 `fw_printenv` 失敗，先檢查：

```sh
cat /etc/fw_env.config
cat /proc/mtd
hexdump -C /dev/mtdX | head
```

##### 2.11.4 OpenBMC software update 狀態

```sh
busctl tree xyz.openbmc_project.Software.BMC.Updater 2>/dev/null
busctl tree xyz.openbmc_project.Software.Version 2>/dev/null
busctl tree xyz.openbmc_project.Software.Activation 2>/dev/null
systemctl status phosphor-bmc-code-mgmt.service --no-pager 2>/dev/null
journalctl -u phosphor-bmc-code-mgmt.service -b --no-pager 2>/dev/null | tail -200
journalctl -b --no-pager | grep -Ei 'software|activation|updater|image|manifest|version|flash|mtd|ubi|wic|gpt|partition' | tail -300
```

#### 2.12 更新流程與 rollback 驗證

更新流程建議拆成「上傳、驗證、寫入、切換、重開機、mark-good、清理」幾段，各段都應有 log 與失敗回復策略。

| 階段 | 檢查項目 | 需要保存的 log / 狀態 |
| --- | --- | --- |
| 上傳 | image 是否完整、空間是否足夠 | `/tmp/images`、`df -h`、bmcweb log |
| 驗證 | manifest、MachineName、purpose、signature | MANIFEST、journal、activation object |
| 寫入 | 目標 slot、partition / volume、進度 | activation progress、dmesg、updater journal |
| 切換 | U-Boot env / boot metadata / GPT slot metadata | `fw_printenv` before/after、slot metadata |
| 重開機 | 是否從新 slot 開機 | UART log、bootargs、`/proc/cmdline` |
| mark-good | 成功條件是否達成 | systemd ready、software active / functional association |
| rollback | 失敗時是否回到前一 slot | bootcount、watchdog reset reason、previous slot boot log |
| 清理 | 非 running image 是否可刪除 | software inventory、flash free space |

最小驗證矩陣：

| 測試 | 預期結果 | 備註 |
| --- | --- | --- |
| 同版更新 | 可完成 activation，重開後版本一致 | 驗證基本流程 |
| 升版更新 | 新 slot 開機並標記 functional | 保存 before / after manifest |
| 降版更新 | 依 policy 允許或拒絕 | 若有 anti-rollback 需明確記錄 |
| 更新中斷電 | 不應造成雙 slot 都不可開機 | AC loss timing 需記錄 |
| 寫入中 BMC reset | 可回到舊版或繼續處理 | 觀察 update metadata |
| 新 image kernel panic | bootloader 回退到舊 slot | 需驗證 bootcount / watchdog |
| 新 image userspace fail | 未 mark-good 時回退或停留救援 | 需定義 timeout |
| rwfs 滿載 | update 應拒絕或清楚報錯 | `df -h` / journal |
| factory reset | 只清指定資料，不破壞 image | 驗證保留清單 |
| golden boot | 可進救援 image 並重新刷寫 | 測試手動 / 自動入口 |

#### 2.13 Persistent data、log 與 factory reset

| 資料類型 | 常見路徑 | 是否應保留於更新 | Factory reset 是否清除 | 備註 |
| --- | --- | --- | --- | --- |
| Network config | `/etc/systemd/network`、network manager state | 是 | 視產品需求 | 現場管理連線依賴此資料 |
| User / password | `/etc/passwd`、`/etc/shadow`、使用者資料庫 | 是 | 通常清除或回預設 | 需符合安全政策 |
| SSH host key | `/etc/ssh/ssh_host_*` | 是 | 視安全政策 | 清除後 client 會看到 host key 變更 |
| TLS certificate | `/etc/ssl`、`/var/lib` | 是 | 視產品需求 | 需避免私鑰外洩 |
| FRU cache | `/var/lib`、Entity Manager cache | 通常是 | 視來源 | 若可由 EEPROM 重建，可清除 |
| SEL / event log | `/var/log`、phosphor-logging | 視產品需求 | 通常可清除 | 需定義容量與輪替 |
| Crash dump | `/var/lib/systemd/coredump`、`/var/dump` | 視需求 | 可清除 | 避免佔滿 rwfs |
| Firmware staging | `/tmp/images`、`/var/tmp` | 否 | 可清除 | 優先放 tmpfs 或 staging partition |
| Factory data | `/var/lib/factory`、VPD backup | 是 | 通常不可清除 | 建議獨立分區或保護機制 |
| Calibration data | `/var/lib/platform/calibration` | 是 | 通常不可清除 | sensor / fan / power policy 可能使用 |

建議：

- 對每個保存資料建立 owner、路徑、格式版本、migration policy 與 reset policy。
- rwfs 空間需設定監控與 log rotation，避免 event log 或 dump 佔滿導致 service 寫入失敗。
- Factory reset 不應等同於 erase all flash；需明確列出可清與不可清資料。
- 若支援 downgrade，需定義新舊版本設定檔相容性；必要時保留版本戳記與 migration log。

#### 2.14 常見問題與排查入口

| 現象 | 可能方向 | 第一輪檢查 |
| --- | --- | --- |
| `/proc/mtd` 分區名稱不對 | DTS fixed-partitions 未更新，或 bootargs mtdparts 覆蓋 | dmesg、`/proc/cmdline`、DTB 反編譯 |
| `lsblk` 看不到預期 partition | `.wic` / GPT / MBR / eMMC probe 問題 | dmesg mmc、`sfdisk -l`、`sgdisk -p` |
| U-Boot 能讀 flash，但 kernel 找不到 rootfs | bootargs root= / ubi.mtd / rootfstype / PARTUUID 不對 | `printenv bootargs`、dmesg、`/proc/mtd`、`blkid` |
| 更新後仍開舊版 | slot metadata 未切換、mark-good / priority 未更新 | `fw_printenv`、software association、UART boot log |
| 更新後無法開機 | kernel / DTB / rofs slot 不一致 | dump active slot offset、比對 manifest |
| rwfs 掛載失敗 | JFFS2 / UBIFS / ext4 metadata 問題 | dmesg filesystem log、mtdinfo / fsck |
| OverlayFS 沒套上 | initramfs / preinit mount 順序錯、upper 不支援 xattr | `findmnt`、journal、dmesg overlayfs |
| `fw_printenv` 讀不到 | `fw_env.config` 錯或 env CRC 壞 | `/etc/fw_env.config`、U-Boot `printenv` |
| UBI attach 失敗 | ubinize 參數、VID header、bad block、ECC 不一致 | dmesg UBI、`ubinfo`、`mtdinfo` |
| SquashFS error | rofs 寫入不完整、flash read error、offset 錯 | sha256、mtd readback、dmesg |
| eMMC rootfs 偶發 read-only | ext4 journal / eMMC health / power loss | dmesg ext4/mmc、fsck、EXT_CSD |
| GPT warning / partition table mismatch | `.wic` 寫入不完整、backup header 未修正、容量不同 | `sgdisk -v`、`sfdisk -l`、reflash image |
| update tar 被拒絕 | MANIFEST MachineName / purpose / signature 不符 | updater journal、`tar xfO MANIFEST` |
| factory reset 後不可登入 | reset scope 清掉必要帳號或網路設定 | reset script、保留清單、journal |

#### 2.15 Bring-up 建議流程

1. 確認 media：SPI-NOR、SPI-NAND、eMMC、SD、SSD，並記錄型號、容量、電壓、strap。
2. 依 media 選分割方式：raw flash 使用 MTD / UBI；block device 使用 MBR / GPT。
3. 確認 filesystem：rofs / rwfs / data / log 各自使用 SquashFS、JFFS2、UBIFS、ext4 或 OverlayFS。
4. 確認映像格式：static mtd、UBI、wic、raw image、update tar、MANIFEST。
5. 對齊 partition source：DTS、U-Boot mtdparts、U-Boot env、`.wks`、ubinize cfg、Yocto image layout、update script。
6. 確認 kernel support：SPI-NOR / NAND / eMMC、MTD、UBI、UBIFS、SquashFS、OverlayFS、ext4、MMC、partition parser。
7. boot 一次乾淨 image，保存 UART、dmesg、`/proc/mtd`、`/proc/cmdline`、`findmnt`、`df`、`lsblk`、`ubinfo`。
8. 驗證 rwfs / overlay：建立檔案、重開機後確認保留，factory reset 後確認清除範圍。
9. 驗證更新：同版、升版、失敗回復、斷電、watchdog、rollback。
10. 驗證 golden / recovery：手動入口、自動入口、重新刷寫 production image。
11. 長測：AC cycle、BMC reboot、update loop、rwfs fill、log rotation、power loss。
12. 文件收斂：更新本章分區表、log、版本、owner 與已知限制。

#### 2.16 當前平台 Flash / Storage 實測表

| 項目 | 指令 / 來源 | 實測值 | 備註 |
| --- | --- | --- | --- |
| BMC image version | `cat /etc/os-release` | [待填] | VERSION_ID / BUILD_ID |
| Kernel version | `uname -a` | [待填] | 需對應 DTS commit |
| Bootargs | `cat /proc/cmdline` | [待填] | root= / ubi.mtd / mtdparts / PARTUUID |
| Raw flash partition | `cat /proc/mtd` | [待填] | raw flash 平台必填 |
| Block partition | `lsblk -f`; `sfdisk -l`; `sgdisk -p` | [待填] | eMMC / SD / SSD 平台必填 |
| Mount tree | `findmnt -R /` | [待填] | rofs / rwfs / overlay |
| Disk usage | `df -h`; `df -i` | [待填] | rwfs inode 也需看 |
| U-Boot env | `fw_printenv` | [待填] | 保存 before / after update |
| UBI info | `ubinfo -a` | [待填] | UBI 平台必填 |
| eMMC info | `mmc extcsd read` / sysfs | [待填] | eMMC 平台必填 |
| Update inventory | `busctl tree` / software objects | [待填] | active / functional association |
| Redfish UpdateService | curl UpdateService | [待填] | 若平台支援 Redfish |
| Golden image entry | strap / env / GPIO / CPLD | [待填] | 手動與自動入口 |
| Factory reset result | reset 後 diff | [待填] | 確認保留清單 |

建議保存 log 套件：

```sh
mkdir -p /tmp/storage-debug
cat /etc/os-release > /tmp/storage-debug/os-release.txt
uname -a > /tmp/storage-debug/uname.txt
cat /proc/cmdline > /tmp/storage-debug/proc-cmdline.txt
cat /proc/mtd > /tmp/storage-debug/proc-mtd.txt 2>&1
cat /proc/partitions > /tmp/storage-debug/proc-partitions.txt
findmnt -R / > /tmp/storage-debug/findmnt.txt
mount > /tmp/storage-debug/mount.txt
df -h > /tmp/storage-debug/df-h.txt
df -i > /tmp/storage-debug/df-i.txt
fw_printenv > /tmp/storage-debug/fw_printenv.txt 2>&1
mtdinfo -a > /tmp/storage-debug/mtdinfo.txt 2>&1
ubinfo -a > /tmp/storage-debug/ubinfo.txt 2>&1
blkid > /tmp/storage-debug/blkid.txt 2>&1
lsblk -f > /tmp/storage-debug/lsblk-f.txt 2>&1
sfdisk -l > /tmp/storage-debug/sfdisk-l.txt 2>&1
sgdisk -p /dev/mmcblk0 > /tmp/storage-debug/sgdisk-p-mmcblk0.txt 2>&1 || true
sgdisk -v /dev/mmcblk0 > /tmp/storage-debug/sgdisk-v-mmcblk0.txt 2>&1 || true
dmesg -T > /tmp/storage-debug/dmesg.txt
journalctl -b --no-pager > /tmp/storage-debug/journal.txt
tar czf /tmp/storage-debug-$(date +%Y%m%d-%H%M%S).tar.gz -C /tmp storage-debug
```

#### 2.17 驗收 Checklist

- [ ] Boot media 型號、容量、erase block / page size 或 block sector size 已記錄。
- [ ] 已明確區分儲存媒體、分割區 / volume、檔案系統、檔案格式 / 映像格式。
- [ ] Raw flash 平台已確認 MTD partition / UBI volume；block device 平台已確認 MBR / GPT。
- [ ] eMMC / SD / SSD 平台已記錄 partition label、PARTUUID / UUID、filesystem type 與 `.wks` 來源。
- [ ] BootROM、U-Boot、kernel、userspace 對同一份 layout 的理解一致。
- [ ] DTS fixed-partitions / U-Boot mtdparts / UBI config / WIC layout / update script 未互相矛盾。
- [ ] `/proc/mtd`、`ubinfo`、`lsblk`、`sfdisk` 或 `sgdisk` 輸出與設計表一致。
- [ ] rootfs 掛載型態符合設計：SquashFS / UBIFS / ext4 / OverlayFS。
- [ ] rwfs 可寫、重開機保留，且空間與 inode 有監控方式。
- [ ] `fw_printenv` / `fw_setenv` 可正常讀寫，且 env offset / size 正確。
- [ ] software update 可完成同版與升版測試。
- [ ] A/B slot 可切換、mark-good、rollback，並保存相關 log。
- [ ] 更新中斷電 / BMC reset / watchdog reset 不會讓系統進入不可回復狀態。
- [ ] Golden / recovery image 可啟動並可重新刷寫 production image。
- [ ] Factory reset 清除範圍與保留範圍已驗證。
- [ ] 安全設定包含 image signature、secure boot、anti-rollback、field mode 或其不啟用理由。
- [ ] 量產燒錄工具、維修流程與本章分區表一致。

#### 2.18 本章參考資料

- Linux kernel documentation - UBI File System: https://www.kernel.org/doc/html/latest/filesystems/ubifs.html
- Linux MTD project - UBIFS FAQ and HOWTO: http://linux-mtd.infradead.org/faq/ubifs.html
- Linux kernel documentation - Overlay Filesystem: https://www.kernel.org/doc/html/latest/filesystems/overlayfs.html
- OpenBMC docs - Flash Layout and Filesystem Documentation: https://github.com/openbmc/docs/blob/master/architecture/code-update/flash-layout.md
- OpenBMC docs - Code Update: https://github.com/openbmc/docs/blob/master/architecture/code-update/code-update.md
- U-Boot documentation - Environment variables and boot flow: https://docs.u-boot.org/
- Yocto Project Reference Manual - Images and filesystem types: https://docs.yoctoproject.org/ref-manual/

### 3. Pinmux / GPIO 通用設計模式

本章整理 BMC 平台中 Pinmux、GPIO、pinctrl、GPIO expander、CPLD GPIO-like bit、presence / fault / interrupt / reset / power signal 的共用設計與排查方法。Pinmux / GPIO 是 bring-up 中最容易造成跨部門理解落差的區塊之一：硬體 schematic 使用的是 net name，SoC datasheet 使用的是 ball / pad / alternate function，Linux 使用 pinctrl state、gpiochip / line offset、gpio-line-names，OpenBMC 則常再映射到 D-Bus object、inventory、Redfish、IPMI 或 power control policy。

本章目標是建立一份可追蹤的對照方式，讓每一條會影響 power、reset、boot strap、write protect、presence、fault、LED、button、interrupt、mux select 的訊號，都能回答下列問題：

- 這條訊號接到哪一個 SoC pin / ball？
- 它在 SoC 上是 GPIO 還是 alternate function？若是 alternate function，pinctrl 是否已選對？
- Linux 中的 gpiochip、line offset、line name 是什麼？
- active high / active low 是從硬體訊號角度、Linux logical value 角度，還是 OpenBMC inventory 狀態角度定義？
- reset 後預設值由誰決定：SoC reset default、strap、external pull resistor、CPLD、GPIO hog、driver probe、userspace daemon？
- 這條訊號的 owner 是 BMC、CPLD、BIOS、Host、PSU、front panel 還是共享？
- 若訊號狀態錯誤，會造成哪一類開機、更新、power sequence 或現場問題？

#### 3.1 名詞與資料流

| 名詞 | 說明 | Bring-up 關注點 |
| --- | --- | --- |
| Pin / Pad / Ball | SoC 封裝上的實體腳位 | schematic、layout、datasheet 名稱要對齊 |
| Pinmux | 同一實體 pin 在多個功能間切換，例如 GPIO / I2C / PWM / UART | DTS pinctrl state、strap、register default |
| Pinconf | pin 的電氣設定，例如 pull-up、pull-down、drive strength、open drain、topology | 是否能由 software 設定，是否與外部電路衝突 |
| GPIO controller | Linux 中提供 GPIO lines 的控制器，例如 SoC GPIO bank、I2C expander | gpiochip index 可能會變，建議依 line name 查找 |
| GPIO line offset | gpiochip 內部 line 編號 | 不等於 SoC ball name，也不一定等於舊 sysfs GPIO number |
| gpio-line-names | DTS 中給每條 GPIO line 的人類可讀名稱 | gpioinfo / gpiofind / OpenBMC config 常依賴此名稱 |
| GPIO consumer | 使用某條 GPIO 的 driver / service，例如 reset-gpios、enable-gpios、presence-gpios | consumer name 可在 gpioinfo 中看到，便於判斷是否已被占用 |
| GPIO hog | kernel early 階段固定要求某條 GPIO 為 input / output high / output low | 適合早期固定狀態，不適合後續需由 service 動態控制的訊號 |
| Active level | 有效電位，可能是 active-high 或 active-low | 必須分清楚 pin 電位與 logical state |
| Owner | 訊號狀態由誰決定 | 避免 BMC / CPLD / BIOS 同時控制同一條線 |

Linux pinctrl subsystem 涵蓋 pin enumeration、pin multiplexing，以及 pull-up / pull-down、open drain、drive strength 等 pin configuration；GPIO mapping 則建議在 Device Tree consumer node 使用 `<function>-gpios` 命名，例如 `reset-gpios`、`enable-gpios`、`led-gpios`。GPIO property 的 active-low / active-high 會影響 gpiod API 看到的 logical value，因此文件內需同時記錄 physical level 與 logical state。

典型資料流：

```text
Schematic net / CPLD bit / expander pin
    ↓
SoC ball / expander port / CPLD register bit
    ↓
Pinmux / pinconf / GPIO controller driver
    ↓
Linux gpiochip + line offset + gpio-line-name
    ↓
Kernel consumer driver 或 OpenBMC service
    ↓
D-Bus inventory / sensor / power state / event
    ↓
Redfish / IPMI / WebUI / SEL / policy
```

#### 3.2 訊號分類與風險等級

| 類型 | 範例 | 錯誤時常見現象 | 建議風險等級 |
| --- | --- | --- | --- |
| Boot strap / reset strap | boot source、secure boot、debug mode | 無 UART、BootROM 讀錯媒體、secure boot policy 不符 | Critical |
| Power enable | MAIN_PWR_EN、VR_EN、PSU_ON_N | Host 無法上電、反覆 power fault、rail 提早啟動 | Critical |
| Reset | BMC_RST_N、PLTRST_N、PERST_N、FPGA_RST_N | 裝置不 probe、Host boot hang、PCIe device 不見 | Critical |
| Power good / fault | PGOOD、VR_FAULT_N、THERMTRIP_N | power sequence timeout、誤觸發 fault、event log 錯誤 | High |
| Write protect | BIOS_WP_N、BMC_FLASH_WP_N、CPLD_WP | 更新失敗、保護失效、安全風險 | High |
| Presence | FAN_PRSNT_N、PSU_PRSNT_N、RISER_PRSNT_N | inventory 錯、fan / PSU / riser 不顯示 | High |
| Intrusion | CHASSIS_INTRUSION_N | SEL / Redfish event 錯、rearm policy 錯 | Medium |
| Interrupt | ALERT_N、IRQ_N、PMBUS_ALERT_N | driver 無事件、輪詢壓力增加、fault 延遲 | Medium～High |
| LED | UID_LED、FAULT_LED、STATUS_LED | 外部狀態顯示錯 | Medium |
| Button | PWRBTN_N、RSTBTN_N、IDBTN_N | 按鈕無效、誤觸發、長按策略錯 | High |
| Mux select | I2C_MUX_SEL、SPI_MUX_SEL | bus 掃不到 device、燒錄路徑錯 | High |
| Debug / manufacturing | JTAG_EN、UART_SEL、RECOVERY_N | 現場 debug 不可用或量產安全設定錯 | Medium～High |

建議所有 Critical / High 訊號都建立量測紀錄，至少包含：reset 後 default、BMC Linux 起來後狀態、Host off / on 狀態、AC cycle 後狀態、BMC reboot 後是否保持預期。

#### 3.3 GPIO 欄位範本

| 欄位 | 說明 |
| --- | --- |
| Signal | schematic net name，建議與硬體文件一致 |
| Functional name | 軟體語意，例如 host-reset、psu0-present、bios-wp |
| SoC pin / ball | SoC datasheet 腳位名稱 |
| Pin function | GPIO / I2C / PWM / UART / strap / alternate function |
| GPIO controller | SoC gpio、I2C expander、CPLD、MCU、PCH sideband |
| gpiochip / line | Linux 中的 gpiochip 與 line offset；若可能變動，需補 line name |
| gpio-line-name | DTS 或 driver 暴露的 line name |
| Active level | active-high / active-low；務必註明 physical 與 logical 角度 |
| Reset default | SoC reset 後方向、輸出值、Hi-Z、pull state |
| HW pull | pull-up / pull-down 電阻值與電源域 |
| Owner | BMC / CPLD / BIOS / Host / shared |
| Consumer | kernel driver、OpenBMC service、Entity Manager、power daemon |
| Purpose | 訊號用途 |
| Boot risk | 若狀態錯誤，對 boot / power / update 的影響 |
| Debounce | 是否需要 debounce、時間、由 kernel / daemon / CPLD 處理 |
| Event policy | 是否產生 SEL / Redfish event / phosphor-logging |
| Test method | gpioinfo、gpioget、scope、LA、CPLD register、service log |
| Status | [待確認] / [量測值] / 已驗證 |

平台表格範本：

| Signal | Functional name | SoC Pin | Pin function | GPIO line / name | Active | Default | HW pull | Owner | Consumer | Purpose | Boot risk | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PWRBTN_N | host-power-button | [待填] | GPIO | [待填] / pwrbtn-n | Low | input / High-Z [待填] | Pull-up [待填] | BMC/CPLD | x86-power-control | Host power button pulse | Critical | [待確認] |
| PLTRST_N | host-platform-reset | [待填] | GPIO input | [待填] / pltrst-n | Low | input | Pull-up [待填] | Host/PCH | x86-power-control / state monitor | Host reset state | High | [待確認] |
| BIOS_WP_N | bios-write-protect | [待填] | GPIO output | [待填] / bios-wp-n | Low | output high [待填] | Pull-up [待填] | BMC/Security | BIOS update service | SPI flash write protect | High | [待確認] |
| PSU0_PRSNT_N | psu0-present | [待填] | GPIO input | [待填] / psu0-present-n | Low | input | Pull-up [待填] | BMC/CPLD | Entity Manager / PSU service | PSU presence | High | [待確認] |
| FAN0_PRESENT_N | fan0-present | [待填] | GPIO input | [待填] / fan0-present-n | Low | input | Pull-up [待填] | BMC | fan presence service | Fan tray detection | High | [待確認] |
| CHASSIS_INTRUSION_N | chassis-intrusion | [待填] | GPIO input | [待填] / chassis-intrusion-n | Low | input | Pull-up [待填] | BMC/Security | intrusion sensor | Chassis open event | Medium | [待確認] |

#### 3.4 命名規則

命名規則是後續排查效率的關鍵。建議同一條訊號保留三種名稱，但不要混用：

| 名稱類型 | 來源 | 範例 | 用途 |
| --- | --- | --- | --- |
| Hardware net name | schematic | `PSU0_PRSNT_N` | 與 HW / CPLD / LA 量測對齊 |
| GPIO line name | DTS `gpio-line-names` | `psu0-present-n` | `gpioinfo`、`gpiofind`、service config |
| D-Bus / inventory name | OpenBMC config | `psu0`、`fan0`、`chassis_intrusion` | Redfish / IPMI / policy |

建議：

- Line name 使用小寫與 hyphen，例如 `psu0-present-n`、`bios-wp-n`、`pwrbtn-n`。
- 若硬體訊號本身帶 `_N` 或 `#`，line name 可保留 `-n`，但 active level 必須另外記錄，不要只靠名稱推論。
- 同一類訊號需序號一致，例如 `fan0-present-n` 對應 `fan0-tach`、`fan0-pwm`。
- 不建議使用 `gpio123`、`signal1`、`misc-gpio` 之類無語意名稱。
- shared line 或 wired-OR line 必須在備註標示所有 driver / sink / source。
- 若使用 expander，line name 仍應描述功能，不要只寫 `pca9555-p00`。

#### 3.5 Device Tree：pinctrl、gpio-line-names 與 consumer gpios

##### 3.5.1 pinctrl state 範本

以下範本用來表達 client device 需要的 pinmux state。實際 pins / function / groups / bias / drive-strength 屬性需依 SoC binding 調整。

```dts
&pinctrl {
    pinctrl_i2c5_default: i2c5-default {
        function = "I2C5";
        groups = "I2C5";
    };

    pinctrl_uart5_default: uart5-default {
        function = "UART5";
        groups = "UART5";
    };

    pinctrl_gpio_debug_default: gpio-debug-default {
        pins = "A1", "A2";
        bias-pull-up;
    };
};

&i2c5 {
    status = "okay";
    pinctrl-names = "default";
    pinctrl-0 = <&pinctrl_i2c5_default>;
};
```

檢查重點：

- pinctrl state 名稱應包含 peripheral 與狀態，例如 `i2c5-default`、`uart5-default`。
- 同一 pin 不應同時被設為 I2C / UART / PWM / GPIO 等互斥功能。
- 若 peripheral probe 失敗，除了 driver 與 clock，也要查 pinctrl 是否套用。
- 部分 SoC 有 strap / OTP / secure mode 影響 pin function，DTS 正確仍可能被硬體條件限制。

##### 3.5.2 gpio-line-names 範本

```dts
&gpio0 {
    gpio-line-names =
        /* A0-A7 */
        "pwrbtn-n", "pltrst-n", "host-pgood", "bios-wp-n",
        "psu0-present-n", "psu1-present-n", "fan0-present-n", "fan1-present-n",
        /* B0-B7 */
        "chassis-intrusion-n", "uid-button-n", "uid-led", "fault-led",
        "i2c-mux-sel0", "i2c-mux-sel1", "bmc-ready", "host-ready";
};
```

檢查重點：

- 每個 bank 的 line name 順序必須與 SoC GPIO driver 的 line offset 順序一致。
- 沒使用的 line 可留空字串，但未接腳位、保留腳位、strap 腳位建議加註，例如 `reserved-gpio-a3`、`strap-boot0`。
- 若 bootloader 與 kernel 使用不同 DTB，需確認 running kernel 看到的 line name 是最新版本。
- 若同名 line 出現在多個 gpiochip，`gpiofind` 可能找到第一個匹配；重要訊號建議確認 gpiochip 與 line offset。

##### 3.5.3 GPIO expander 範本

```dts
&i2c7 {
    status = "okay";

    gpio_expander0: gpio@20 {
        compatible = "nxp,pca9555";
        reg = <0x20>;
        gpio-controller;
        #gpio-cells = <2>;

        gpio-line-names =
            "psu0-present-n", "psu1-present-n", "riser0-present-n", "riser1-present-n",
            "fanboard0-present-n", "fanboard1-present-n", "cable0-present-n", "cable1-present-n",
            "fault-led", "uid-led", "reserved-exp0-10", "reserved-exp0-11",
            "wp-enable", "mux-sel0", "mux-sel1", "expander-int-n";
    };
};
```

Bring-up 重點：

- Expander 的 I2C bus / mux channel / address 需先驗證，再驗 GPIO line。
- 若 expander 有 INT pin，需確認 interrupt-parent、interrupts 與 active level。
- Expander 上的 output reset default 常由 expander datasheet 決定，未必等同 SoC GPIO default。
- Expander 供電若依賴 host rail，BMC standby 階段可能讀不到，service 需配合 PowerState / availability。

##### 3.5.4 GPIO hog 範本

GPIO hog 適合用於早期固定狀態，例如在 driver probe 前就需要維持 disable / reset / mux select。若 userspace 後續要改變狀態，需避免 hog 長期占用該 line。

```dts
&gpio0 {
    bios_wp_default: bios-wp-default-hog {
        gpio-hog;
        gpios = <10 GPIO_ACTIVE_HIGH>;
        output-high;
        line-name = "bios-wp-default";
    };

    mux_sel_default: mux-sel-default-hog {
        gpio-hog;
        gpios = <11 GPIO_ACTIVE_HIGH>;
        output-low;
        line-name = "mux-sel-default";
    };
};
```

使用前需確認：

- 這條 line 是否會被 kernel driver 或 OpenBMC service 重新要求。
- hog 的 output-high / output-low 是 physical level，不是一定等同功能上的 enable / disable。
- 若安全相關，例如 write protect，需確認 GPIO hog 是否足以涵蓋從 reset 到 userspace ready 的時間窗。

##### 3.5.5 Consumer GPIO 範本

```dts
some_device@40 {
    compatible = "vendor,some-device";
    reg = <0x40>;
    reset-gpios = <&gpio0 12 GPIO_ACTIVE_LOW>;
    enable-gpios = <&gpio0 13 GPIO_ACTIVE_HIGH>;
    interrupt-parent = <&gpio0>;
    interrupts = <14 IRQ_TYPE_LEVEL_LOW>;
};
```

建議：

- 新 binding 使用 `<function>-gpios`，例如 `reset-gpios`、`enable-gpios`、`presence-gpios`。
- 不同功能的 GPIO 不要包在同一個大陣列中，除非它們是同一功能的多條資料線。
- active level 使用 `GPIO_ACTIVE_LOW` / `GPIO_ACTIVE_HIGH` 巨集，避免裸數值造成閱讀困難。
- interrupt line 不等同 GPIO input，需要同時檢查 interrupt controller / trigger type / debounce。

#### 3.6 Active level、pull resistor 與安全預設值

Active level 需同時站在 hardware 與 software 角度描述。以下表格可避免「讀值 0 是 present 還是 absent」的溝通落差。

| 欄位 | 說明 | 範例 |
| --- | --- | --- |
| Physical level | 針腳實際電位 | 0V / 3.3V |
| Signal assert level | 硬體訊號有效電位 | `PSU_PRSNT_N` 為 Low 有效 |
| DTS flag | Device Tree GPIO flag | `GPIO_ACTIVE_LOW` |
| gpiod logical value | userspace 依 active flag 看到的邏輯值 | active low line assert 時 logical 1 |
| Inventory state | OpenBMC 對外狀態 | Present = true |
| Redfish/IPMI state | 外部介面狀態 | Present / Absent / Enabled / Warning |

建議每條關鍵 GPIO 都填：

| Signal | Physical assert | DTS flag | gpioget raw / logical 說明 | OpenBMC state | 備註 |
| --- | --- | --- | --- | --- | --- |
| PSU0_PRSNT_N | Low | GPIO_ACTIVE_LOW | pin low 表示 logical active | PSU0 Present=true | [待填] |
| BIOS_WP_N | Low | 視 driver binding | pin low 表示 write protect enabled | WriteProtected=true | 需確認外部 inverter |
| UID_LED | High | GPIO_ACTIVE_HIGH | pin high 表示 LED on | Identify=true | 若 LED driver 另有 polarity 需補充 |

Pull resistor 與 reset default 建議：

- 會影響 host power 的 line，reset default 必須落在安全狀態，例如 VR enable 預設 disable。
- open drain / wired-OR line 必須確認外部 pull-up 電源域與上電時序。
- 若 BMC GPIO reset 後為 input / Hi-Z，實際電位由外部 pull 決定；文件需記錄 pull resistor 值。
- 若 CPLD 在 BMC ready 前接管訊號，需記錄 CPLD default 與 BMC 交接條件。
- 若 GPIO 跨電源域，需確認 back-powering、level shifter、power-off leakage、hot-plug 狀況。

#### 3.7 Kernel config、驅動與 userspace 工具

常見 kernel config：

```text
CONFIG_GPIOLIB=y
CONFIG_GPIO_CDEV=y
CONFIG_PINCTRL=y
CONFIG_PINMUX=y
CONFIG_PINCONF=y
CONFIG_GPIO_SYSFS=n 或依舊工具需求保留
CONFIG_GPIO_PCA953X=y/m
CONFIG_GPIO_ASPEED=y
CONFIG_GPIO_GENERIC=y
CONFIG_DEBUG_FS=y
```

注意事項：

- 新平台建議使用 GPIO character device 與 libgpiod 工具，不建議新流程依賴舊 sysfs GPIO 介面。
- `gpiochipN` 編號可能因 driver probe 順序改變，腳本與 config 應優先使用 line name 或固定 chip label。
- 若 I2C expander driver 以 module 形式載入，使用該 expander 的 service 需有 systemd dependency 或 retry。
- pinctrl debugfs 依 kernel config 與 mount 狀態而定；若可用，對排查 pinmux 很有幫助。

#### 3.8 Target 端檢查指令與 log 收集

##### 3.8.1 GPIO chip 與 line name

```sh
# 列出 GPIO controller
gpiodetect

# 列出所有 GPIO line 狀態
gpioinfo

# 查特定 line name
gpiofind psu0-present-n
gpiofind pwrbtn-n

# 只看某個 gpiochip
gpioinfo gpiochip0
gpioinfo /dev/gpiochip0
```

應保存的資訊：

```sh
mkdir -p /tmp/gpio-debug
gpiodetect > /tmp/gpio-debug/gpiodetect.txt 2>&1
gpioinfo > /tmp/gpio-debug/gpioinfo.txt 2>&1
find /sys/kernel/debug/pinctrl -maxdepth 3 -type f -print > /tmp/gpio-debug/pinctrl-files.txt 2>&1
cat /sys/kernel/debug/gpio > /tmp/gpio-debug/debug-gpio.txt 2>&1
cat /proc/device-tree/model > /tmp/gpio-debug/model.txt 2>&1
cat /proc/cmdline > /tmp/gpio-debug/cmdline.txt 2>&1
dmesg -T > /tmp/gpio-debug/dmesg.txt
journalctl -b --no-pager > /tmp/gpio-debug/journal.txt
tar czf /tmp/gpio-debug-$(date +%Y%m%d-%H%M%S).tar.gz -C /tmp gpio-debug
```

##### 3.8.2 pinctrl debugfs

```sh
# 依平台 debugfs 路徑可能不同
mount | grep debugfs || mount -t debugfs debugfs /sys/kernel/debug
find /sys/kernel/debug/pinctrl -maxdepth 2 -type f -print

# 常見檔案
cat /sys/kernel/debug/pinctrl/*/pins 2>/dev/null
cat /sys/kernel/debug/pinctrl/*/pinmux-pins 2>/dev/null
cat /sys/kernel/debug/pinctrl/*/pinconf-pins 2>/dev/null
cat /sys/kernel/debug/pinctrl/*/gpio-ranges 2>/dev/null
```

排查重點：

- 目標 pin 是否已被 mux 到預期 function。
- 同一 pin 是否顯示被其他 consumer 占用。
- GPIO range 是否能把 gpio line 映射回 pinctrl pin。
- pinconf 是否有預期 pull-up / pull-down / drive strength。

##### 3.8.3 讀取與短期測試 GPIO

```sh
# 讀值：建議先用 gpiofind 找到 chip 與 line
gpiofind psu0-present-n
# 假設輸出 gpiochip2 3
gpioget gpiochip2 3

# 監看 edge event，適合 presence / intrusion / button
gpiomon --num-events=5 gpiochip2 3

# 短時間設定 output，請只在確認安全的測試 line 上使用
gpioset --mode=time --sec=2 gpiochip2 10=1
```

安全提醒：

- 不要在未確認前對 power enable、reset、write protect、strap、mux select line 執行 `gpioset`。
- 若 line 已被 kernel driver 或 daemon 占用，`gpioset` 可能失敗或造成狀態競爭；先看 `gpioinfo` consumer。
- 對 host power / reset 訊號做測試時，需同步 LA / scope、BMC journal、host log 與 CPLD register。

#### 3.9 OpenBMC 整合：Presence、Intrusion、LED、Power Control

##### 3.9.1 Entity Manager GPIODeviceDetect

Entity Manager 可用 GPIO presence daemon 將多條 presence pin 組合成硬體識別結果，並在 D-Bus 上暴露 `xyz.openbmc_project.Inventory.Source.DevicePresence`，後續其他 Entity Manager config 可用 Probe 匹配此 presence 狀態。

GPIODeviceDetect JSON 範本：

```json
{
  "Name": "My Chassis",
  "Probe": "xyz.openbmc_project.FruDevice({'BOARD_PRODUCT_NAME': 'MYBOARDPRODUCT*'})",
  "Type": "Board",
  "Exposes": [
    {
      "Name": "com.example.Hardware.fanboard0",
      "PresencePinNames": ["fanboard0-present-n"],
      "PresencePinValues": [0],
      "Type": "GPIODeviceDetect"
    },
    {
      "Name": "com.example.Hardware.riser0-type-a",
      "PresencePinNames": ["riser0-id0", "riser0-id1"],
      "PresencePinValues": [1, 0],
      "Type": "GPIODeviceDetect"
    }
  ]
}
```

後續板卡 config 可用 DevicePresence 作為 Probe：

```json
{
  "Name": "My Fan Board 0",
  "Probe": "xyz.openbmc_project.Inventory.Source.DevicePresence({'Name': 'com.example.Hardware.fanboard0'})",
  "Type": "Board",
  "Exposes": [
    {
      "Name": "fanboard_air_inlet",
      "Bus": 5,
      "Address": "0x28",
      "Type": "NCT7802"
    }
  ]
}
```

檢查：

```sh
systemctl status xyz.openbmc_project.EntityManager.service --no-pager
systemctl status xyz.openbmc_project.gpiopresence.service --no-pager 2>/dev/null
journalctl -u xyz.openbmc_project.EntityManager.service -b --no-pager | tail -200
journalctl -u xyz.openbmc_project.gpiopresence.service -b --no-pager | tail -200
busctl tree xyz.openbmc_project.EntityManager
busctl tree xyz.openbmc_project.Inventory.Manager 2>/dev/null
busctl tree xyz.openbmc_project.ObjectMapper | grep -i DevicePresence
```

##### 3.9.2 Presence、Functional、Available 的差異

| 狀態 | 意義 | 範例 |
| --- | --- | --- |
| Present | 物理上存在 | PSU 插入、fan tray 插入、riser 插入 |
| Functional | 存在且自我狀態正常 | PSU present 但 fault 為 false |
| Available | 值可取得或服務可使用 | device powered、bus 可讀、daemon ready |
| Fault | 裝置報錯或監控到 fault | PSU fault、fan tach fail、VR fault |

設計提醒：

- `Present=false` 不應同時報 sensor critical threshold，通常應將 sensor 設為 unavailable 或移除 inventory association。
- `Present=true` 但 `Functional=false` 適合表示 PSU 插著但 AC lost / fault，或 fan 插著但 tach 為 0。
- Hot-swap 類訊號需處理 debounce 與 event storm，避免插拔瞬間產生大量 SEL。
- 若 presence 來源有多種，例如 GPIO + EEPROM + PMBus ACK，需定義優先順序與衝突處理。

##### 3.9.3 Intrusion / Button / LED

| 功能 | 常見 OpenBMC 對應 | 注意事項 |
| --- | --- | --- |
| Chassis intrusion | intrusion sensor / inventory / logging | rearm mode、latch clear、SEL / Redfish event |
| UID button | button monitor / identify control | short press / long press policy、debounce |
| Power button | power control service | pulse width、owner、host state dependency |
| Reset button | reset control service / CPLD | debounce、host reset vs BMC reset |
| Fault LED | LED group / fault manager | LED polarity、blink pattern、CPLD takeover |
| UID LED | identify service / Redfish IndicatorLED | BMC / CPLD / front panel owner |

#### 3.10 與 CPLD / FPGA / Board Glue Logic 的邊界

很多平台會把 power sequence、reset mux、presence latch、fault latch、LED pattern、write protect、SKU ID 放在 CPLD。這些 bit 對 OpenBMC 來說可能長得像 GPIO，但排查方式不同。

建議區分：

| 類型 | Linux 視角 | 需要補的資訊 |
| --- | --- | --- |
| SoC GPIO | `/dev/gpiochip*` | pinmux、gpio-line-names、active level |
| I2C GPIO expander | `/dev/gpiochip*` + I2C device | bus / address / expander reset / INT |
| CPLD register bit | I2C / LPC / MMIO / sysfs / custom tool | register offset、bit、R/W、W1C、latch clear |
| MCU-reported GPIO | D-Bus / UART / I2C protocol | polling / event / timeout / firmware version |
| PCH sideband | eSPI / LPC / GPIO pass-through | BIOS / chipset owner、host state dependency |

CPLD bit 表格範本：

| Signal | CPLD offset | Bit | R/W | Active | Default | Clear rule | Mirrors GPIO? | Owner | 備註 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| VR_FAULT_N | [待填] | [待填] | RO/W1C | Low | [待填] | W1C | 否 | CPLD/HW | Fault latch |
| PSU0_PRSNT_N | [待填] | [待填] | RO | Low | [待填] | N/A | 是 | CPLD/BMC | 與 GPIO line 對照 |
| BIOS_WP_EN | [待填] | [待填] | RW | High | [待填] | RW | 否 | BMC/Security | 更新流程需控管 |

#### 3.11 Boot / Power / Reset 特別注意事項

##### 3.11.1 Boot strap 與 pinmux 共用 pin

部分 SoC pin 可能同時是 strap pin 與後續 GPIO / alternate function。此類 pin 要分成兩個時間點記錄：

| 時間點 | 需要確認 |
| --- | --- |
| Reset deassert 附近 | strap latch 值、外部 pull、CPLD / buffer 是否干擾 |
| Linux probe 後 | pinmux 是否改成預期功能、line 狀態是否安全 |

注意：

- 不要只看 Linux 中的 `gpioinfo` 判斷 strap 是否正確；strap 是 reset 釋放附近被 latch。
- 若 Linux 重新配置 pin 造成後續 reset / recovery path 改變，需在風險欄標示。
- Strap pin 上若有按鈕、LED 或 shared net，需檢查上電時的電位與 timing。

##### 3.11.2 Power enable / reset output

Power enable 與 reset output 必須建立「安全預設值」：

| 訊號 | Reset default 建議 | Driver / service ready 後 | 測試 |
| --- | --- | --- | --- |
| VR_EN | disable | power sequence 才 assert | AC on、BMC reboot、host off |
| PERST_N | assert reset | PCIe power good 後 release | host boot、BMC reboot |
| BIOS_WP_N | write protect enabled | authorized update 時短暫改變 | update success/fail、AC loss |
| PSU_ON_N | off / deassert | power on request 才改變 | power on/off/cycle |

##### 3.11.3 Interrupt / debounce

Interrupt 類 GPIO 需確認：

- Edge-trigger 還是 level-trigger。
- Active low / active high 是否與硬體一致。
- 是否需要 debounce；由硬體 RC、CPLD、kernel driver 或 daemon 處理。
- 是否為 latched interrupt，需要讀特定 register clear。
- 是否為 shared line；shared line 需每個 device 都讀 status 才能判斷來源。

#### 3.12 常見問題與排查入口

| 現象 | 可能方向 | 第一輪檢查 |
| --- | --- | --- |
| gpioinfo 看不到 line name | DTB 未更新、gpio-line-names 順序錯、GPIO controller 未 probe | `/proc/device-tree`、dmesg、gpioinfo |
| gpiochip 編號與文件不同 | probe 順序改變、expander 有時不出現 | 使用 gpiofind line name、確認 chip label |
| peripheral 不 probe | pinmux 未切到 alternate function、clock/reset 未就緒 | pinctrl debugfs、dmesg、DTS pinctrl-0 |
| gpioget 讀值與電表不同 | active logical value vs physical value 混淆、外部 inverter | scope、DTS flag、gpioinfo active-low |
| presence 反相 | PresencePinValues 錯、GPIO_ACTIVE_LOW 誤用 | gpioinfo、gpioget、Entity Manager JSON |
| gpioset 失敗 busy | line 已被 driver / daemon / hog 占用 | gpioinfo consumer、systemctl status |
| output 設了但硬體不變 | pinmux 還在 alternate function、level shifter 未上電、CPLD override | pinctrl、scope、CPLD register |
| BMC reboot 時 host 掉電 | power enable default 不安全、GPIO hog / driver handoff gap | AC / BMC reset 量測、scope、CPLD owner |
| BIOS / CPLD update 失敗 | write protect line polarity / owner 錯 | WP pin 量測、fw log、security policy |
| interrupt 沒觸發 | trigger type 錯、line 未 mux、IRQ parent 錯、status 未 clear | `/proc/interrupts`、dmesg、scope |
| LED 反相或不亮 | polarity、LED driver、CPLD pattern owner | gpioinfo consumer、LED sysfs、scope |
| button 誤觸發 | debounce 不足、active level 錯、floating input | scope、pull resistor、event log |
| Hot-swap 時 event storm | debounce / latch / service retry 不足 | journal、gpiomon、CPLD latch |

#### 3.13 Bring-up 建議流程

1. 建立 schematic net → SoC ball / expander port / CPLD bit 對照表。
2. 標示所有 Critical / High 風險訊號：power、reset、strap、write protect、presence、fault、mux。
3. 確認 pinmux：DTS pinctrl state、SoC alternate function、driver binding、DTB deploy。
4. 確認 gpio-line-names：使用 `gpioinfo` 與 schematic 表逐條比對。
5. 確認 active level：對每條 presence / fault / reset / enable 線進行 physical level 與 logical value 對照。
6. 確認 default：AC on、BMC reset、Linux boot 前後、service restart 前後都需量測關鍵線。
7. 確認 owner：BMC / CPLD / Host / BIOS / service 不可互相競爭。
8. 導入 OpenBMC config：Entity Manager、power control、fan presence、intrusion、LED group 等。
9. 驗證 D-Bus / Redfish / IPMI / SEL：確認外部狀態與硬體一致。
10. 做異常測試：AC cycle、BMC reboot、Host power cycle、hot-swap、fault injection、update WP、factory reset。

#### 3.14 當前平台 Pinmux / GPIO 實測表

| 類別 | Signal | Linux line | Physical inactive | Physical active | Logical active | Owner | 已驗證情境 | 備註 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Power | PWRBTN_N | [待填] | [待填] | [待填] | [待填] | BMC/CPLD | power on/off/cycle | [待填] |
| Reset | PLTRST_N | [待填] | [待填] | [待填] | [待填] | Host/PCH | host boot/BMC reboot | [待填] |
| WP | BIOS_WP_N | [待填] | [待填] | [待填] | [待填] | BMC/Security | BIOS update | [待填] |
| Presence | PSU0_PRSNT_N | [待填] | [待填] | [待填] | [待填] | BMC/CPLD | plug/unplug | [待填] |
| Presence | FAN0_PRESENT_N | [待填] | [待填] | [待填] | [待填] | BMC | plug/unplug | [待填] |
| Fault | VR_FAULT_N | [待填] | [待填] | [待填] | [待填] | CPLD/HW | fault injection | [待填] |
| Intrusion | CHASSIS_INTRUSION_N | [待填] | [待填] | [待填] | [待填] | BMC/Security | open/rearm | [待填] |
| LED | UID_LED | [待填] | [待填] | [待填] | [待填] | BMC/CPLD | Redfish identify | [待填] |
| Mux | I2C_MUX_SEL0 | [待填] | [待填] | [待填] | [待填] | BMC/CPLD | bus scan | [待填] |

#### 3.15 驗收 Checklist

- [ ] Schematic net、SoC pin、GPIO line、gpio-line-name、OpenBMC object 已建立對照表。
- [ ] Critical / High 訊號標示 owner、active level、reset default、pull resistor、boot risk。
- [ ] DTS pinctrl state 與實際 peripheral 功能一致，沒有互斥 pinmux 衝突。
- [ ] `gpioinfo` 顯示的 line name 與表格一致。
- [ ] 不依賴不穩定的 gpiochipN 編號；重要腳本 / config 可用 line name 或固定 chip label。
- [ ] active-low / active-high 已用實測電位驗證，並對應到 OpenBMC logical state。
- [ ] GPIO hog 僅用於固定安全狀態，且不與後續 service 控制衝突。
- [ ] power enable / reset / write protect 的 AC on、BMC reboot、Host power cycle 狀態已量測。
- [ ] GPIO expander 的 I2C bus / address / reset / INT / supply 已驗證。
- [ ] CPLD GPIO-like bit 已記錄 register offset、bit、R/W、default、clear rule。
- [ ] Presence / Functional / Available / Fault 狀態定義已對齊 inventory、sensor、Redfish、IPMI。
- [ ] Intrusion / button 類訊號已驗證 debounce、rearm、event log。
- [ ] LED 類訊號已驗證 polarity、blink pattern、CPLD/BMC owner。
- [ ] OpenBMC service、D-Bus object、Redfish / IPMI 顯示與硬體狀態一致。
- [ ] AC cycle、BMC reboot、service restart、hot-swap、fault injection 測試已保存 log。

#### 3.17 本章參考資料

- Linux kernel documentation - GPIO mappings: https://www.kernel.org/doc/html/latest/driver-api/gpio/board.html
- Linux kernel documentation - GPIO Device Tree bindings: https://www.kernel.org/doc/Documentation/devicetree/bindings/gpio/gpio.txt
- Linux kernel documentation - PINCTRL subsystem: https://www.kernel.org/doc/html/latest/driver-api/pin-control.html
- libgpiod documentation - gpioinfo: https://libgpiod.readthedocs.io/en/master/gpioinfo.html
- OpenBMC entity-manager: https://github.com/openbmc/entity-manager
- OpenBMC entity-manager gpio-presence README: https://github.com/openbmc/entity-manager/blob/master/src/gpio-presence/README.md

### 4. Reset / Clock / Power Domain

本章整理 BMC 平台中 reset、clock、power rail、regulator、power domain 與 ready signal 的共用設計模式與排查方法。這一章和第 1 章 Boot Flow、第 3 章 Pinmux / GPIO、第 5 章周邊匯流排、第 16 章 Power Control 關係很密切；差異在於本章聚焦「硬體 domain 是否已具備讓 device probe、bus transaction、host power transition 正常進行的前置條件」。

Reset / Clock / Power Domain 問題常呈現為：driver probe deferred、I2C / SPI / eMMC / MAC 無回應、PHY link 不起、host power sequence timeout、BMC reboot 影響 host、watchdog reset 後狀態不一致、周邊偶發消失。排查時不要只看單一訊號，需要同時把 rail、clock、reset、pinmux、driver binding、service policy、CPLD state、reset reason 串起來看。

#### 4.1 基本觀念

| 名詞 | 說明 | Bring-up 關注點 |
| --- | --- | --- |
| Reset source | 產生 reset 的來源，例如 POR IC、CPLD、SoC watchdog、BMC GPIO、host PCH | 需知道觸發條件與 reset 範圍 |
| Reset domain | 同一 reset source 或 reset controller 影響的一組電路 | 避免誤以為 BMC reset 不會影響 host sideband |
| Reset consumer | 被 reset 訊號控制的 device / block | 需知道 active level、minimum pulse width、release timing |
| Clock source | oscillator、crystal、PLL、clock generator、SoC internal clock | 需確認頻率、抖動、enable、source select |
| Clock consumer | 需要 clock 才能工作的 device / peripheral | driver probe 前 clock 是否已存在與已 enable |
| Power rail | 電源 rail，例如 3V3_AUX、1V8、VCCIO、PHY_AVDD | voltage、ramp、PGOOD、dependency |
| Regulator | Linux 中可描述與管理的供電來源，例如 fixed-regulator、PMIC regulator | constraints、enable GPIO、always-on、boot-on |
| Power domain | 一組共享供電 / clock / reset dependency 的硬體區塊 | domain on/off 順序與 runtime PM |
| Ready signal | 表示 domain 可用的訊號，例如 PGOOD、PLL_LOCK、LINK_UP、CHANNEL_READY | 需定義何時可由軟體開始存取 |

典型 dependency：

```text
Power rail stable
    ↓
Clock source stable / PLL lock
    ↓
Reset deassert
    ↓
Pinmux state applied
    ↓
Driver probe / bus scan
    ↓
Userspace service sees device / D-Bus object ready
```

若任一層缺資料，後面看到的現象可能只是連鎖結果。例如 I2C device ACK 不到，方向可能是 I2C pinmux 錯、pull-up rail 未上、expander reset 未釋放、clock gate 未開、bus owner 還在 CPLD / Host、或 power domain 尚未 ready。

#### 4.2 Reset 類型與影響範圍

| Reset 類型 | 常見來源 | 影響範圍 | 常見現象 | 必填資料 |
| --- | --- | --- | --- | --- |
| POR / Power-on reset | reset IC、CPLD、PMIC | 全板或 BMC domain | AC cycle 後所有狀態回預設 | rail threshold、delay、release 條件 |
| Cold reset | power rail drop 後重新啟動 | BMC / host / full board | register state 全部消失 | 哪些 rail 被關閉、reset reason |
| Warm reset | 不掉主要供電，只重置邏輯 | SoC / host / peripheral | 部分狀態保留，問題較難重現 | reset signal、clock 是否持續 |
| BMC-only reset | BMC reset pin、watchdog、software reboot | BMC SoC 與 BMC-managed peripherals | BMC 重啟，host 可能繼續跑 | host sideband 是否受影響 |
| Host reset | PCH / CPU / CPLD / BMC 控制 | host domain | Host 重開，BMC 不重開 | PLTRST / RSMRST / SLP 與 POST 狀態 |
| Peripheral reset | SoC reset controller、GPIO reset | MAC、USB、I2C device、PHY、FPGA | 單一 device probe 或 runtime 失敗 | active level、pulse width、release delay |
| Watchdog reset | SoC watchdog、external watchdog、CPLD | BMC-only 或 full board | reset reason 顯示 watchdog | timeout、feed source、reset target |
| Brownout reset | rail droop、power fault | 受影響電源 domain | 隨機 reboot、flash corruption、device missing | rail waveform、fault latch、PGOOD log |

Reset 排查基本要求：

- 同時保存 reset reason register、CPLD reset latch、power fault latch、UART log、scope / LA waveform。
- 明確標示 reset 範圍：BMC-only、host-only、full board、單一 peripheral。
- 對 BMC reboot / watchdog reset 特別確認 host power 是否受到 side effect。
- 若 reset line 是 open drain 或由多方 wired-OR，需列出所有可能拉低者。
- 若 reset line 由 CPLD pulse 產生，需記錄 pulse width、stretch、debounce 與 clear rule。

#### 4.3 Clock 類型與檢查重點

| Clock 類型 | 範例 | 檢查項目 | 常見風險 |
| --- | --- | --- | --- |
| Crystal / oscillator | 25MHz、24MHz、32.768kHz | 頻率、振幅、起振時間、load capacitor | BMC 無 early UART、RTC 不準、BootROM 失敗 |
| Reference clock | PCIe REFCLK、RGMII 125MHz、RMII 50MHz | source、enable、jitter、spread spectrum | link 不起、device training fail |
| SoC PLL | CPU / AHB / APB / peripheral PLL | lock 狀態、divider、parent clock | peripheral timeout、baud rate 錯 |
| Peripheral gate | I2C / SPI / UART / MAC clock gate | driver 是否 enable、runtime PM | driver probe deferred、bus 無 clock |
| External clock generator | clock buffer、clock generator IC | I2C config、OE pin、power rail | 多個 device 同時異常 |
| Host-provided clock | eSPI/LPC/PECI/PCIe sideband clock | host power state、PCH readiness | BMC service 在 host off 讀不到訊號 |

Clock bring-up 建議：

- 對 early boot 相關 clock，例如 main crystal、SPI clock、UART clock，優先以 scope 量測。
- 對 Linux driver 相關 clock，檢查 DTS `clocks` / `clock-names`、kernel config、`/sys/kernel/debug/clk/clk_summary`。
- 對 network / PCIe / eSPI 類高速 clock，確認 clock source、frequency、enable pin、reset timing 與 PHY / PCH dependency。
- 若 baud rate、PWM frequency、fan tach、I2C clock 異常，除了 driver 設定，也要檢查 parent clock 與 divider。

常用 clock debug：

```sh
mount | grep debugfs || mount -t debugfs debugfs /sys/kernel/debug
cat /sys/kernel/debug/clk/clk_summary 2>/dev/null | head -200
find /sys/kernel/debug/clk -maxdepth 2 -type f -print 2>/dev/null

dmesg | grep -Ei 'clk|clock|pll|osc|refclk|rate'
```

#### 4.4 Power rail、regulator 與 power domain

Linux regulator framework 用於描述電壓 / 電流 regulator 與其 consumer，常見能力包含 enable / disable、電壓設定、current limit 與 constraints。BMC 平台中不一定所有 rail 都由 Linux regulator 管理；有些 rail 只由 CPLD / PMIC / analog circuit 控制，但仍建議在本章記錄 dependency 與 ready 條件。

| 類型 | Linux 表達 | 適用情境 | 注意事項 |
| --- | --- | --- | --- |
| Fixed always-on rail | `regulator-fixed` + `regulator-always-on` | 3V3_AUX、1V8 standby | 仍需量測 ramp 與 ripple |
| GPIO controlled regulator | `regulator-fixed` + enable GPIO | PHY power、sensor power、slot power | active level 與 boot-on 預設需確認 |
| PMIC regulator | PMIC driver + regulator node | SoC core、DDR、peripheral rail | constraints 與 power sequence 必須對齊 datasheet |
| CPLD controlled rail | CPLD register / GPIO / D-Bus | host main rail、slot power | 記錄 register bit、PGOOD、fault latch |
| Host dependent rail | Host power state 控制 | eSPI、PECI、PCIe device | BMC service 需依 host state gating |
| External hot-swap / eFuse | HSC / eFuse driver 或 GPIO fault | riser、NVMe、PCIe slot | fault clear、retry、inrush policy |

Power domain 表格要同時填 rail、clock、reset、dependency、ready 條件。只填 rail 名稱不足以排查 probe 問題。

#### 4.5 DTS 範本：reset、clock、regulator、power domain

##### 4.5.1 Reset controller consumer

```dts
ethernet@1e660000 {
    compatible = "vendor,soc-mac";
    reg = <0x1e660000 0x1000>;
    resets = <&rst 12>;
    reset-names = "mac";
    clocks = <&syscon ASPEED_CLK_GATE_MAC1CLK>;
    clock-names = "macclk";
    status = "okay";
};
```

檢查重點：

- `resets` 與 `reset-names` 順序需與 driver 期待一致。
- shared reset 不適合任意放在多個 consumer node；需確認 reset 影響範圍。
- 若 reset 其實是外部 IC 腳位，通常用 `reset-gpios` 更直觀；若是 SoC internal reset controller，使用 `resets`。

##### 4.5.2 Clock consumer

```dts
uart5: serial@1e784000 {
    compatible = "ns16550a";
    reg = <0x1e784000 0x1000>;
    clocks = <&syscon ASPEED_CLK_APB>;
    clock-names = "uartclk";
    pinctrl-names = "default";
    pinctrl-0 = <&pinctrl_uart5_default>;
    status = "okay";
};
```

檢查重點：

- `clock-names` 必須與 driver 期待名稱一致。
- clock parent / divider 改變可能影響 UART baud、I2C bus speed、PWM frequency、MAC reference。
- debugfs `clk_summary` 可用來看 enable count、prepare count、rate、parent。

##### 4.5.3 Fixed regulator / GPIO enable rail

```dts
vdd_3v3_aux: regulator-vdd-3v3-aux {
    compatible = "regulator-fixed";
    regulator-name = "vdd_3v3_aux";
    regulator-min-microvolt = <3300000>;
    regulator-max-microvolt = <3300000>;
    regulator-always-on;
};

vdd_phy: regulator-vdd-phy {
    compatible = "regulator-fixed";
    regulator-name = "vdd_phy";
    regulator-min-microvolt = <3300000>;
    regulator-max-microvolt = <3300000>;
    gpio = <&gpio0 45 GPIO_ACTIVE_HIGH>;
    enable-active-high;
    startup-delay-us = <10000>;
};

ethernet-phy@0 {
    reg = <0>;
    vdd-supply = <&vdd_phy>;
    reset-gpios = <&gpio0 46 GPIO_ACTIVE_LOW>;
};
```

檢查重點：

- `startup-delay-us` 應來自 regulator / PHY datasheet 或量測結果。
- enable GPIO active level 需與硬體實測一致。
- 若 rail 在 bootloader 階段已開，Linux regulator state 需避免 probe 時誤關。

#### 4.6 Domain 對照表範本

| Domain | Rail | Clock | Reset | Dependency | Ready 條件 | Owner | Boot risk | 狀態 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BMC core | [待填] | main osc / PLL [待填] | BMC_RST_N / POR [待填] | standby rail / reset IC | UART early log / reset reason valid | HW/BMC | Critical | [待確認] |
| DDR | [待填] | DDR clock [待填] | DDR reset / CKE | BMC core rail / DDR rail | SPL DDR init pass / memtest | HW/BMC | Critical | [待確認] |
| Boot SPI | 3V3_AUX [待填] | SPI clock from SoC | POR / flash reset [待填] | boot strap / WP / HOLD | U-Boot `sf probe` pass | HW/BMC | Critical | [待確認] |
| MAC/RGMII | [待填] | 25MHz / 125MHz [待填] | PHY_RST_N | PHY power / strap / MDIO | link up / `ethtool` 正常 | HW/BMC | High | [待確認] |
| RMII/NC-SI | [待填] | 50MHz / RMII REFCLK [待填] | PHY / NIC reset | Host NIC / sideband | NC-SI package response | BMC/Host | High | [待確認] |
| eSPI/LPC | [待填] | host side clock [待填] | host reset / PLTRST_N | PCH power / RSMRST / straps | channel ready / host state valid | Host/BMC | High | [待確認] |
| I2C sensor rail | [待填] | I2C controller clock | expander/sensor reset | pull-up rail / mux / bus owner | i2cdetect / driver probe | BMC | Medium | [待確認] |
| Fan PWM/Tach | [待填] | PWM / tach clock | peripheral reset | fan power / tach pull-up | PWM output / RPM read | BMC/HW | High | [待確認] |
| PCIe slot mgmt | [待填] | REFCLK [待填] | PERST_N | slot power / CPLD / host state | device present / MCTP / SMBus | Host/BMC | High | [待確認] |
| CPLD | [待填] | CPLD clock [待填] | CPLD_RST_N | standby rail | register map readable | CPLD/HW/BMC | Critical | [待確認] |

#### 4.7 Timing 與量測欄位

對 power / reset / clock domain，單點狀態不夠，需記錄 timing。建議以 AC applied、BMC reset deassert、Host power button、main rail enable、PGOOD、reset release 為共同時間軸。

| 時間點 | 事件 | 量測訊號 | Target | 實測 | 判定 |
| --- | --- | --- | ---: | ---: | --- |
| T0 | AC applied | AC_OK / standby input | 0 ms | [待填] | [待確認] |
| T1 | Standby rail stable | 3V3_AUX / 1V8 / core | [待填] | [待填] | [待確認] |
| T2 | BMC reset release | BMC_RST_N | [待填] | [待填] | [待確認] |
| T3 | Main clock stable | OSC / PLL_LOCK | [待填] | [待填] | [待確認] |
| T4 | Boot media access | SPI_CS / SPI_CLK | [待填] | [待填] | [待確認] |
| T5 | U-Boot banner | UART TX | [待填] | [待填] | [待確認] |
| T6 | Linux starts | kernel log timestamp | [待填] | [待填] | [待確認] |
| T7 | Userspace ready | systemd default target | [待填] | [待填] | [待確認] |
| T8 | Host power request | PWRBTN_N / PWR_EN | [待填] | [待填] | [待確認] |
| T9 | Main rail PGOOD | PS_PWROK / VR_PGOOD | [待填] | [待填] | [待確認] |
| T10 | Host reset release | PLTRST_N / PERST_N | [待填] | [待填] | [待確認] |
| T11 | POST complete | POST_COMPLETE / port80 | [待填] | [待填] | [待確認] |

量測建議：

- Reset 與 PGOOD 請使用同一台 LA / scope 的共同 trigger，避免不同工具時間基準不一致。
- 對 clock 起振時間，需量測振幅穩定與 frequency lock，不只看有無波形。
- 對 GPIO / CPLD event，需同步保存 BMC journal 與 CPLD register dump。

#### 4.8 Reset reason 與 fault latch

Reset reason 是 boot failure 排查的入口，但需注意它可能被下次 reset 覆蓋，也可能只能描述 SoC 自身 reset，無法描述外部 full board reset 原因。

建議保存欄位：

| 資料 | 來源 | 說明 |
| --- | --- | --- |
| SoC reset reason | SoC register / kernel log / U-Boot log | POR、watchdog、software reset、external reset |
| Watchdog status | SoC / systemd / CPLD | timeout source、last feed time、reset target |
| CPLD fault latch | CPLD register | brownout、VR fault、PGOOD timeout、thermal trip |
| PMIC / VR fault | PMBus / PMIC register | UV/OV/OC/OT、status word、clear rule |
| Host reset cause | BIOS / CPLD / PCH sideband | warm reset、power button、OS reboot、watchdog |
| Event timeline | journal / SEL / Redfish EventLog | 軟體看見的 transition 與錯誤 |

常用指令範本：

```sh
mkdir -p /tmp/reset-debug
cat /etc/os-release > /tmp/reset-debug/os-release.txt
uname -a > /tmp/reset-debug/uname.txt
cat /proc/cmdline > /tmp/reset-debug/proc-cmdline.txt
dmesg -T > /tmp/reset-debug/dmesg.txt
journalctl -b --no-pager > /tmp/reset-debug/journal-current.txt
journalctl -b -1 --no-pager > /tmp/reset-debug/journal-previous.txt 2>&1
systemctl --failed > /tmp/reset-debug/systemctl-failed.txt 2>&1
busctl tree xyz.openbmc_project.State.Host > /tmp/reset-debug/dbus-host-state.txt 2>&1
busctl tree xyz.openbmc_project.State.Chassis > /tmp/reset-debug/dbus-chassis-state.txt 2>&1
fw_printenv > /tmp/reset-debug/fw_printenv.txt 2>&1
cat /sys/kernel/debug/clk/clk_summary > /tmp/reset-debug/clk_summary.txt 2>&1
find /sys/kernel/debug/pinctrl -maxdepth 3 -type f -print > /tmp/reset-debug/pinctrl-files.txt 2>&1
cat /sys/kernel/debug/gpio > /tmp/reset-debug/debug-gpio.txt 2>&1
find /sys/class/regulator -maxdepth 3 -type f -print -exec sh -c 'echo ==== $1; cat $1 2>/dev/null' _ {} \; > /tmp/reset-debug/regulator.txt 2>&1
tar czf /tmp/reset-debug-$(date +%Y%m%d-%H%M%S).tar.gz -C /tmp reset-debug
```

若平台有 `devmem`、CPLD tool、PMBus tool、vendor reset reason command，請另外保存：

```sh
# 依平台調整，以下僅為欄位提醒
# cpldtool dump > /tmp/reset-debug/cpld-dump.txt
# pmbus-status-dump > /tmp/reset-debug/pmbus-status.txt
# devmem <reset_reason_register> > /tmp/reset-debug/reset-reason.txt
```

#### 4.9 OpenBMC / Host power state 整合

x86 類平台常由 OpenBMC x86-power-control 或平台 power daemon 監控 GPIO / D-Bus 訊號，維護 Host state machine，並提供 hard power on/off/cycle、soft power on/off/cycle 等能力。這類 service 的設定與本章 domain 資料需一致，尤其是 PWRBTN、RESET、NMI、PS_PWROK、POST_COMPLETE、PLTRST、SLP_Sx、RSMRST。

| Signal | 典型角色 | 對 domain 的意義 |
| --- | --- | --- |
| PS_PWROK | PSU / main power ready | Host main rail 是否可視為有效 |
| SIO_POWER_GOOD / PCH_PWROK | Host power good | Host sideband 是否可讀 |
| RSMRST_N | Resume reset | PCH standby domain 是否 ready |
| PLTRST_N | Platform reset | Host peripheral 是否離開 reset |
| POST_COMPLETE | BIOS POST 狀態 | Host boot 是否到達指定階段 |
| PWRBTN_N | BMC 對 host power button pulse | Power transition requester |
| RESET_N / RSTBTN_N | BMC 對 host reset | Host reset transition |
| NMI_N | BMC 觸發 NMI | Debug / crash capture |

驗證重點：

- BMC reboot 後，power daemon 是否能重新發現 host current state，而不是假設 host off。
- AC restore policy 是否和 CPLD default / BIOS policy / BMC policy 一致。
- 若使用 PLTRST 判斷 warm reset，需確認 polarity、debounce 與 host reset timing。
- 所有 power button / reset pulse width 需符合 platform power sequence 文件。
- 多 host 平台需確認每個 host 的 GPIO / DBUS 設定沒有共用錯線。

#### 4.10 Device probe deferred 與 dependency 排查

Reset / Clock / Power Domain 問題常在 kernel 中呈現為 deferred probe。建議依序檢查 supply、clock、reset、GPIO、IRQ、bus parent。

常用指令：

```sh
dmesg | grep -Ei 'defer|probe|reset|clk|clock|regulator|supply|power domain|genpd|timeout'
cat /sys/kernel/debug/devices_deferred 2>/dev/null
cat /sys/kernel/debug/clk/clk_summary 2>/dev/null | grep -i '<device-or-clock>'
find /sys/class/regulator -maxdepth 2 -type l -o -type d 2>/dev/null
```

常見方向：

| dmesg / 現象 | 可能方向 | 第一輪檢查 |
| --- | --- | --- |
| `-EPROBE_DEFER` | regulator / clock / reset provider 尚未 ready | provider driver、DTS phandle、kernel config |
| `supply vdd not found` | `*-supply` 名稱錯或 regulator node 不存在 | DTS supply property、regulator-name |
| `failed to get reset` | `resets` / `reset-names` 錯 | reset binding、driver 期待名稱 |
| `failed to enable clock` | clock provider / gate / parent 問題 | clk_summary、clock-names、driver log |
| device timeout | reset 未 release、clock 無、rail 未穩 | scope、pinctrl、regulator state |
| I2C NACK | device rail off、reset asserted、pull-up rail off、bus mux 錯 | rail、reset、i2cdetect、mux channel |
| MAC no link | PHY rail/clock/reset/strap | MDIO、PHY reset waveform、REFCLK |

#### 4.11 常見問題與排查入口

| 現象 | 可能方向 | 第一輪檢查 |
| --- | --- | --- |
| BMC 完全無 UART | core rail、main oscillator、BMC reset、strap | scope rail/reset/osc、BootROM SPI access |
| BMC watchdog 後 host 掉電 | watchdog reset 範圍過大、CPLD default、power enable glitch | reset scope、CPLD latch、PWR_EN waveform |
| Peripheral probe 偶發失敗 | reset release 太早、clock unstable、rail ramp 慢 | LA/scope timing、driver retry、startup-delay |
| MAC link 不起 | PHY reset/clock/strap/MDIO/rail | REFCLK、PHY_RST_N、MDIO read、ethtool |
| eMMC 偶發找不到 | eMMC reset/clock/power sequence、bus width | dmesg mmc、scope CMD/CLK/RST、EXT_CSD |
| eSPI/LPC 不 ready | host standby domain、RSMRST、PLTRST、clock | host signal timeline、power daemon log |
| Fan PWM 無輸出 | PWM clock gate、pinmux、fan power、daemon override | clk_summary、pinctrl、sysfs、scope |
| I2C expander 消失 | expander rail/reset、bus mux、clock stretching、address conflict | i2cdetect、rail、reset、mux state |
| BMC reboot 後 power state 錯 | power daemon rediscovery 不完整、state file 舊資料 | D-Bus state、journal、power-config |
| factory reset 後 power policy 錯 | persistent policy 被清或未重建 | settings manager、power restore policy |
| AC restore 行為不一致 | CPLD default / BIOS / BMC policy 衝突 | AC cycle log、CPLD register、BMC setting |
| reset reason 不可信 | register 被清、只記錄 SoC reset、外部 latch 未讀 | early U-Boot log、CPLD latch、PMIC status |

#### 4.12 Bring-up 建議流程

1. 建立 rail / clock / reset / ready signal 依賴圖，先從 BMC core、DDR、boot flash、UART 開始。
2. 收集 reset source：POR IC、CPLD、watchdog、BMC GPIO、Host reset、peripheral reset。
3. 收集 clock source：crystal、oscillator、clock generator、PLL、host-provided clock。
4. 收集 power rail：standby、BMC core、IO、DDR、PHY、sensor、host sideband、slot power。
5. 對每個 domain 填寫 rail、clock、reset、dependency、ready 條件與 owner。
6. 以 scope / LA 量測 AC on、BMC reset、Linux boot、Host power on 的 timing。
7. 在 kernel 中驗證 regulator、clk、reset provider 與 consumer 是否 probe。
8. 在 userspace 中驗證 power daemon、state manager、sensor daemon 是否依 domain 狀態 gating。
9. 做異常測試：BMC reboot、watchdog reset、AC loss、host reset、peripheral reset、rail fault、clock disable 模擬。
10. 將 reset reason、fault latch、journal、dmesg 與 waveform 放在同一測試紀錄。

#### 4.13 當前平台 Reset / Clock / Power 實測表

| Domain | Rail 量測 | Clock 量測 | Reset 量測 | Ready signal | Kernel / service 狀態 | 結論 |
| --- | --- | --- | --- | --- | --- | --- |
| BMC core | [待填] | [待填] | [待填] | UART early log | [待填] | [待確認] |
| DDR | [待填] | [待填] | [待填] | SPL DDR init pass | [待填] | [待確認] |
| Boot flash | [待填] | SPI_CLK [待填] | [待填] | `sf probe` / kernel mtd | [待填] | [待確認] |
| MAC/RGMII | [待填] | 25/125MHz [待填] | PHY_RST_N [待填] | link up | [待填] | [待確認] |
| eSPI/LPC | [待填] | [待填] | PLTRST_N / RSMRST_N [待填] | channel ready | [待填] | [待確認] |
| I2C expander | [待填] | I2C bus clock [待填] | EXP_RST_N [待填] | device ACK | [待填] | [待確認] |
| Fan domain | fan rail [待填] | PWM/Tach clock [待填] | [待填] | RPM read | [待填] | [待確認] |
| CPLD | [待填] | [待填] | CPLD_RST_N [待填] | register readable | [待填] | [待確認] |
| Host main | [待填] | host clocks [待填] | PLTRST_N [待填] | POST complete | [待填] | [待確認] |

#### 4.14 驗收 Checklist

- [ ] 所有 reset source 與 reset domain 已列出，包含 BMC-only、host-only、full board、peripheral。
- [ ] reset reason register、CPLD fault latch、PMIC / VR fault status 的讀取方式已記錄。
- [ ] 主要 clock source、frequency、enable、parent、consumer 已列出。
- [ ] `clk_summary` 可讀，且 key peripheral clock rate / enable state 合理。
- [ ] power rail、regulator、PGOOD、fault line、dependency 與 ready 條件已列出。
- [ ] DTS 中 `resets` / `reset-names`、`clocks` / `clock-names`、`*-supply` 與 driver binding 一致。
- [ ] GPIO reset / enable line 的 active level、pulse width、startup delay 已量測。
- [ ] AC on、BMC reboot、watchdog reset、host power on/off/cycle 都有 timing log。
- [ ] BMC reboot 不會造成 host power 非預期切換，或已有明確產品政策。
- [ ] Host state rediscovery、AC restore policy、power daemon state transition 已驗證。
- [ ] Device probe deferred 已檢查，沒有未解釋的 supply / clock / reset dependency。
- [ ] Network、eSPI/LPC、I2C expander、fan、CPLD 等關鍵 domain 通過實機驗證。
- [ ] 異常測試包含 brownout、fault latch、reset stuck、clock missing、power rail delayed、watchdog reset。
- [ ] 測試紀錄包含 waveform、UART、dmesg、journal、D-Bus state、CPLD / PMIC dump、image version。

#### 4.15 回查結果

本章回查後補強項目：

- 原章節只有 reset 類型與簡短 clock / power 檢查表，已補上 reset source、reset domain、clock source、regulator、power rail、ready signal 的完整關係。
- 補上 reset、clock、power rail / regulator 的分類表與常見風險。
- 補上 DTS 範本：reset controller consumer、clock consumer、fixed regulator / GPIO enable rail。
- 補上 domain 對照表、timing 量測表、reset reason / fault latch 欄位。
- 補上 target 端 log 收集慣例，包含 dmesg、journal、D-Bus state、fw_printenv、clk_summary、pinctrl、gpio、regulator debug 資訊。
- 補上 OpenBMC / Host power state 關聯，特別是 x86-power-control 類平台的 PS_PWROK、RSMRST、PLTRST、POST_COMPLETE、PWRBTN、RESET、NMI。
- 補上 probe deferred 排查流程、常見問題表、bring-up 流程、當前平台實測表與驗收 checklist。

#### 4.16 本章參考資料

- Linux kernel documentation - Reset controller API: https://www.kernel.org/doc/html/latest/driver-api/reset.html
- Linux kernel documentation - Reset Device Tree bindings: https://www.kernel.org/doc/Documentation/devicetree/bindings/reset/
- Linux kernel documentation - Common Clock Framework: https://www.kernel.org/doc/html/latest/driver-api/clk.html
- Linux kernel documentation - Regulator framework overview: https://docs.kernel.org/power/regulator/overview.html
- Linux kernel documentation - Voltage and current regulator API: https://docs.kernel.org/driver-api/regulator.html
- OpenBMC x86-power-control README: https://github.com/openbmc/x86-power-control/blob/master/README.md

### 5. 周邊匯流排通用知識

本章整理 BMC 平台常見周邊匯流排的共用觀念、設計欄位、Device Tree、kernel、userspace、OpenBMC service 與外部管理介面的對齊方式。第 3 章聚焦 pinmux / GPIO，第 4 章聚焦 reset / clock / power domain；本章則聚焦「匯流排路徑是否清楚、controller 是否 probe、child device 是否正確 bind、raw interface 是否可讀寫、上層服務是否有一致的 inventory / sensor / state 對應」。

BMC 平台常見匯流排包含 I2C / SMBus / PMBus、SPI、UART、ADC / IIO、PWM / Tach、PECI / APML、eSPI / LPC、KCS / BT、Port80、NC-SI、RGMII / RMII、MDIO、PCIe 管理路徑、USB gadget、MCTP / PLDM / SPDM 等。這些介面看起來差異很大，但 bring-up 與排查可以共用同一套分層方法：先確認硬體前置條件，再確認 bus controller，接著確認 child device 或 endpoint，最後確認 OpenBMC service、D-Bus、Redfish / IPMI / EventLog。

本章特別強調三件事：

- 不要只用「掃得到 device」作為匯流排完成標準。許多管理匯流排還需要 page、phase、EID、route、package / channel、role、host power state、ownership 與 update / recovery policy。
- 不要只看 Linux bus number。I2C mux、MCTP netdev、USB gadget、NC-SI channel、SPI CS、PECI address 都可能在 runtime 形成新視角，文件要能從 schematic 追到 Linux runtime，再追到 D-Bus / Redfish / IPMI。
- 不要忽略 debug 指令的副作用。I2C quick command、PMBus CLEAR_FAULTS、SPI erase / write、EEPROM write、PLDM control command、retimer sideband 設定都可能改變平台狀態或清掉故障證據。

#### 5.1 共用分層模型

```text
硬體連線 / connector / device / endpoint
    ↓
power rail / reset / clock / pull-up / termination / level shift
    ↓
pinmux / pad configuration / strap / mux select
    ↓
Linux bus controller driver
    ↓
Linux child device / endpoint / protocol driver
    ↓
sysfs / dev node / netdev / hwmon / IIO / tty / socket
    ↓
OpenBMC daemon / Entity Manager / platform service
    ↓
D-Bus object / inventory / sensor / state / event
    ↓
Redfish / IPMI / WebUI / SEL / telemetry / policy
```

排查時建議先找出停在哪一層，不要從對外介面現象直接推論硬體異常。相同的「Redfish sensor 不見」可能來自 I2C NACK、mux channel 錯、driver 未 bind、hwmon label 錯、Entity Manager Probe 不符、PowerState gating、D-Bus association 錯或 bmcweb cache 未更新。

| 層級 | 典型檢查 | 常見問題 | 建議保存 |
| --- | --- | --- | --- |
| 硬體 | schematic、BOM、scope、LA、DMM | 接線錯、address strap 錯、pull-up 不足、termination 錯、connector pinout 錯 | schematic 頁碼、量測截圖、BOM 型號 |
| Power / reset / clock | rail、PGOOD、reset waveform、clock waveform、第 4 章 domain 表 | rail 未穩、reset 未釋放、clock gate 未開、host-off 時 device 無電 | waveform、CPLD / PMIC latch、reset reason |
| Pinmux / mux select | pinctrl debugfs、gpioinfo、CPLD mux bit、DTS | pinmux 到錯功能、GPIO hog 占用、mux select 預設值錯 | pinctrl dump、gpioinfo、CPLD dump |
| Bus controller | dmesg、sysfs、debugfs、kernel config | controller disabled、driver 未 probe、clock / reset provider 缺失 | dmesg、kernel config、DTS node |
| Child device / endpoint | I2C address、SPI CS、PECI address、MCTP EID、NC-SI package/channel | address / CS / mode / EID 錯、device 未上電、driver binding 錯 | sysfs path、driver link、raw read log |
| Raw interface | hwmon、IIO、tty、netdev、spidev、mctp socket | sysfs index mapping 錯、netdev rename、tty console 衝突 | sysfs tree、ip link、tty list |
| OpenBMC service | systemctl、journalctl、busctl、Entity Manager JSON | Probe 條件錯、PowerState gating、service dependency、D-Bus path 錯 | service status、journal、config commit |
| External interface | Redfish、IPMI SDR、SEL / EventLog | association 不完整、schema mapping 錯、inventory cache 舊 | Redfish dump、ipmitool output、event log |

#### 5.2 匯流排地圖必填資料

每個平台都建議維護一份 bus map。bus map 的價值不是列出所有 device，而是讓每個 device 都能從硬體來源追到 Linux runtime 與 OpenBMC 對外狀態。

| 欄位 | 說明 |
| --- | --- |
| Bus type | I2C、SPI、UART、PECI、eSPI、LPC、MDIO、NC-SI、USB、MCTP 等 |
| Physical controller | schematic / SoC 命名，例如 BMC_I2C5、SPI1、UART5、MAC0 |
| Linux bus / device | `i2c-5`、`spi1.0`、`ttyS4`、`eth0`、`mctp0`、`peci-0` |
| Topology | direct、mux channel、bridge、switch、slot、connector、package/channel |
| Device / endpoint | device 型號、FRU 名稱、CPU socket、PSU slot、NVMe slot、retimer |
| Address / CS / endpoint | I2C 7-bit address、SPI CS、PECI address、MDIO addr、MCTP EID、NC-SI package/channel |
| Driver / service | kernel driver、hwmon driver、dbus-sensors、mctpd、pldmd、network daemon |
| Power domain | AlwaysOn、Standby、HostOn、SlotPower、Presence-based、Hotplug |
| Reset / clock dependency | reset line、clock source、ready signal、host state dependency |
| Protocol | PMBus、SMBus、NVMe-MI、PLDM、SPDM、NC-SI、APML、KCS、BT |
| Sysfs / dev path | hwmon path、IIO path、`/dev/spidev*`、`/dev/tty*`、netdev、MCTP interface |
| D-Bus / OpenBMC path | sensor path、inventory path、state object、software object、event path |
| External mapping | Redfish URI、IPMI SDR、SEL、EventLog、OEM command |
| Debug risk | read-clear、write side effect、bus hang、host ownership、security boundary |
| Owner | HW、BMC FW、BIOS、CPLD、ME / PCH、Security、QA |
| Status | [待確認]、[量測值]、已驗證、限制事項 |

平台 bus map 範本：

| Bus | Controller | Linux node | Topology | Device | Address / CS / EID | Driver / Service | PowerState | 用途 | 狀態 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| I2C | BMC_I2C5 | `i2c-5` | direct | TMP75 inlet | `0x48` | lm75 / dbus-sensors | AlwaysOn | inlet temperature | [待確認] |
| I2C | BMC_I2C7 | `i2c-20` | mux@0x70 ch2 | PSU0 PMBus | `0x58` | pmbus / PSUSensor | AlwaysOn | PSU telemetry | [待確認] |
| I2C | BMC_I2C8 | `i2c-24` | mux ch1 | Riser FRU EEPROM | `0x50` | at24 / FruDevice | Presence-based | FRU / inventory | [待確認] |
| SPI | FMC | `spi0.0` | CS0 | BMC boot flash | CS0 | spi-nor / mtd | AlwaysOn | boot flash | [待確認] |
| SPI | SPI1 | `spi1.0` | CS0 | TPM / CPLD / MCU | CS0 | platform driver | Standby | security / board logic | [待確認] |
| UART | UART5 | `ttyS4` | header | BMC debug console | 115200 8N1 | serial-getty | AlwaysOn | bring-up console | [待確認] |
| UART | UART2 | `ttyS1` | muxed | Host SOL | 115200 8N1 | obmc-console | HostOn | host serial | [待確認] |
| PECI | PECI0 | `peci-0` | direct | CPU0 | `0x30` | peci-cputemp | HostOn | CPU / DIMM telemetry | [待確認] |
| MAC | MAC0 | `eth0` | RGMII | Dedicated PHY | MDIO addr [待填] | aspeed-mac / networkd | AlwaysOn | BMC LAN | [待確認] |
| NC-SI | MAC1 | `eth1` | NC-SI | Host NIC | pkg/ch [待填] | kernel ncsi / networkd | HostOn/Standby | shared NIC mgmt | [待確認] |
| MCTP | SMBus | `mctp0` | mux ch [待填] | NVMe / retimer | EID [待填] | mctpd / pldmd | HostOn | PLDM / NVMe-MI | [待確認] |
| USB | UDC0 | `usb_gadget/*` | device mode | Host USB | N/A | gadget configfs | HostOn | virtual media | [待確認] |

#### 5.3 DTS、kernel、Yocto 與 OpenBMC 設定對齊

同一個匯流排資訊可能出現在 DTS、kernel config、Yocto recipe、Entity Manager JSON、dbus-sensors config、systemd unit、network config、udev rule、Redfish / IPMI mapping 中。排查前需先確認目前 running image 載入的是哪一份 DTB 與哪一份 service config。

| 來源 | 常見檔案 / 指令 | 作用 | 需對齊內容 |
| --- | --- | --- | --- |
| Device Tree | `arch/.../dts/*.dts`、`/proc/device-tree` | 描述 controller、child device、mux、address、clock/reset/supply | controller status、reg、compatible、pinctrl、clocks、resets、supplies |
| Kernel config | `zcat /proc/config.gz`、build config | 啟用 bus / protocol driver | I2C、SPI、PECI、MCTP、NC-SI、IIO、hwmon、USB gadget |
| Yocto recipe / bbappend | layer recipe、package config | 將工具與 service 放入 image | i2c-tools、mtd-utils、ethtool、libmctp、pldmd、dbus-sensors |
| Entity Manager JSON | `/usr/share/entity-manager/configurations` | 建立 inventory 與 sensor config | Bus、Address、Name、Probe、PowerState、Exposes |
| D-Bus service | systemd unit、service config | 讀取 raw device 並暴露 D-Bus objects | dependency、restart policy、host state gating |
| Network config | systemd-networkd、netplan、platform script | netdev naming、DHCP/static、VLAN、NC-SI | interface name、MAC、link policy、failover |
| Update / security policy | update service、secure boot | 控制 SPI flash、EEPROM、CPLD / BIOS write path | write protect、signed image、授權流程 |

建議每個 bus controller 都保留 DTS 節點與 runtime 對照：

```sh
# 看 running DT model 與 compatible
tr '\0' '\n' < /proc/device-tree/model 2>/dev/null
tr '\0' '\n' < /proc/device-tree/compatible 2>/dev/null

# 查 I2C / SPI / serial / ethernet / peci 相關 node
find /proc/device-tree -type f | grep -Ei 'i2c|spi|serial|uart|ethernet|mdio|peci|usb|mctp' | head -200

# 查 kernel config
zcat /proc/config.gz 2>/dev/null | grep -E 'CONFIG_(I2C|SPI|SERIAL|PECI|MCTP|NCSI|IIO|HWMON|USB_GADGET|IPMI|ASPEED|NPCM)'
```

#### 5.4 I2C / SMBus / PMBus

I2C 是 BMC 最常見的管理匯流排。FRU EEPROM、temperature sensor、voltage / current monitor、VR、HSC、PSU、fan controller、GPIO expander、CPLD、retimer、clock generator、MUX、NVMe-MI bridge 都可能掛在 I2C / SMBus / PMBus 上。Linux 會把實體 controller 與 mux channel 抽象成 logical bus，因此文件中不能只寫 schematic 上的 `I2C5`，也要記錄 Linux 的 `i2c-X`。

##### 5.4.1 I2C topology 與 logical bus

```text
BMC I2C controller
  └─ I2C mux @0x70
      ├─ channel 0 → logical bus i2c-20 → PSU0 PMBus @0x58
      ├─ channel 1 → logical bus i2c-21 → PSU1 PMBus @0x58
      ├─ channel 2 → logical bus i2c-22 → fan board EEPROM @0x50
      └─ channel 3 → logical bus i2c-23 → retimer @0x18
```

重點：

- 實體 controller number 來自 schematic / SoC，例如 BMC_I2C5。
- Linux logical bus number 由 kernel runtime 建立，可能因 mux、driver probe 或 alias 而與實體 number 不同。
- Entity Manager JSON 的 `Bus` 通常使用 Linux logical bus number；若填成 schematic number，service 可能找錯 device。
- I2C mux 下游 bus number 若不固定，建議在 DTS 使用 aliases 或在文件中保存 `i2cdetect -l` 與 sysfs topology。

常用檢查：

```sh
i2cdetect -l
ls -l /sys/bus/i2c/devices/
for b in /sys/bus/i2c/devices/i2c-*; do
    echo "==== $b"
    readlink -f "$b"
done
find /sys/bus/i2c/devices -maxdepth 2 -type l | sort
find /sys/bus/i2c/devices -name channel-* -o -name mux_device 2>/dev/null | sort
```

##### 5.4.2 I2C / SMBus bring-up 欄位

| 欄位 | 說明 |
| --- | --- |
| Physical bus | schematic 上的 controller，例如 BMC_I2C5 |
| Logical bus | Linux `i2c-X` |
| Mux path | mux address、channel、下游 logical bus |
| Pull-up rail | pull-up 電壓、電阻值、是否 always-on |
| Bus speed | 100kHz、400kHz、1MHz；需確認 controller、board、device 都支援 |
| Address | 7-bit address；需避免 8-bit address 混用 |
| Address strap | A0/A1/A2、slot ID、board ID、PSU slot ID |
| Protocol | I2C、SMBus、PMBus、MCTP over SMBus、vendor mailbox |
| Driver | kernel driver、hwmon driver、userspace daemon |
| Side effect | read-clear、write-one-to-clear、page select、fault clear |
| PowerState | AlwaysOn、HostOn、SlotPower、Presence-based |
| Bus recovery | SCL toggle、controller reset、mux reset、device power cycle |

##### 5.4.3 DTS 範本：controller、mux、EEPROM、sensor

```dts
&i2c5 {
    status = "okay";
    clock-frequency = <400000>;
    pinctrl-names = "default";
    pinctrl-0 = <&pinctrl_i2c5_default>;

    mux@70 {
        compatible = "nxp,pca9548";
        reg = <0x70>;
        #address-cells = <1>;
        #size-cells = <0>;
        i2c-mux-idle-disconnect;

        i2c@0 {
            reg = <0>;
            psu0: power-supply@58 {
                compatible = "pmbus";
                reg = <0x58>;
            };
        };

        i2c@2 {
            reg = <2>;
            fanboard_eeprom: eeprom@50 {
                compatible = "atmel,24c64";
                reg = <0x50>;
                pagesize = <32>;
            };
        };
    };
};
```

檢查重點：

- `clock-frequency` 需符合最慢 device 能力與 signal integrity。
- mux channel 若有同 address device，需確認 idle disconnect / idle state，避免多通道同時連通。
- EEPROM pagesize、address-width、write protect 與 FRU 工具需一致。
- sensor 若由 dbus-sensors 或 Entity Manager 建立，不一定需要 DTS child node；但 bus / address / PowerState 仍需在文件對齊。

##### 5.4.4 使用 i2c-tools 的注意事項

`i2cdetect` 僅能作為輔助，不適合在不了解 device 行為時對整條 bus 做盲掃。某些 device 對 quick command、read byte 或特定 command 有副作用；PMBus / VR / PSU 類 device 也可能有 PAGE、PHASE、vendor mode 或 fault latch。

較安全的流程：

1. 先確認 bus map 與 mux channel。
2. 查 device datasheet，確認 address 與安全讀取 command。
3. 先用 `i2cdetect -l` 找 bus，不先掃全部 bus。
4. 只對預期 bus、預期 address 做讀取。
5. PMBus / VR / PSU 不任意使用 `i2cset`。
6. 若 device status 可能被讀取清除，先保存 PMBus / CPLD / service log。

```sh
# 列出 bus
i2cdetect -l

# 只掃指定 bus；若 device 有副作用，先不要使用
 i2cdetect -y 5

# 查 kernel 是否已有 driver bind
ls -l /sys/bus/i2c/devices/5-0048
readlink -f /sys/bus/i2c/devices/5-0048/driver 2>/dev/null

# hwmon mapping
find /sys/bus/i2c/devices/5-0048 -maxdepth 3 -type f | sort
find /sys/class/hwmon -maxdepth 3 -type f | grep -E 'name|temp|in|curr|power|fan' | sort
```

##### 5.4.5 PMBus 特別注意事項

PMBus 常用於 PSU、VR、HSC、eFuse、power monitor。PMBus bring-up 常見問題不是 bus 不通，而是 PAGE / PHASE / format / scale / fault state 對不上。

| 項目 | 說明 | 排查資料 |
| --- | --- | --- |
| PAGE | 多 rail / 多輸出 device 需先選 PAGE | device datasheet、driver channel label |
| PHASE | 多相 VR 可能需要 phase mapping | VR config、vendor tool、driver log |
| Linear / Direct format | raw value 轉換需依 PMBus format 與 driver | hwmon value、datasheet coefficient |
| STATUS_WORD | fault / warning 的入口 | dump before clear |
| CLEAR_FAULTS | 可能清除診斷資訊 | 僅在保存 status 後執行 |
| VOUT_MODE | 影響 VOUT 轉換 | driver log、datasheet |
| Manufacturer registers | vendor-specific 狀態或設定 | vendor app note、保密文件 |

建議 PMBus 先由 kernel hwmon / PMBus driver 暴露 sysfs，再由 userspace service 讀取。raw i2c command 適合 bring-up 與故障定位，不建議在量產流程中成為主要讀值路徑。

##### 5.4.6 I2C bus hang 與 recovery

I2C bus hang 常見於 SDA 被 device 拉低、SCL 被拉低、level shifter half-powered、mux channel 未釋放、device powered-off 但 sideband back-powering。排查時應同步看 scope 與 kernel log。

| 現象 | 可能方向 | 第一輪檢查 |
| --- | --- | --- |
| SCL high、SDA low | slave stuck、transaction 中斷 | SCL pulse recovery、device reset、power cycle |
| SCL low、SDA high/low | master 或 slave clock stretching 卡住 | controller reset、scope、driver timeout |
| mux 下游全 NACK | mux channel 未切、mux reset、pull-up rail off | mux sysfs、scope、CPLD mux bit |
| 只有 host on 才可讀 | device rail 依賴 host | PowerState gating、host power timeline |
| scan 後 device 狀態改變 | scan command 有副作用 | 停止盲掃，改用安全 command |

#### 5.5 SPI / SPI-NOR / SPI-NAND / spidev

SPI 常用於 boot flash、TPM、CPLD、FPGA、MCU、GPIO expander、debug bridge。BMC bring-up 中 SPI boot flash 是關鍵路徑，需同時確認 BootROM 支援、strap、pinmux、controller mode、clock、CS、flash opcode、address byte、dual / quad / octal mode、WP / HOLD、板上 mux 與 write protect policy。

##### 5.5.1 SPI 必填欄位

| 欄位 | 說明 |
| --- | --- |
| Controller | SoC SPI / FMC / QSPI controller |
| Chip select | CS0 / CS1 / GPIO CS，active level |
| Mode | CPOL / CPHA，mode 0～3 |
| Max frequency | controller、PCB、device 三者都要符合 |
| Data lanes | single、dual、quad、octal |
| Address byte | 3-byte / 4-byte address mode |
| Opcode | read / fast read / quad read / erase / program opcode |
| WP / HOLD / RESET | 腳位狀態、pull、是否由 BMC / CPLD 控制 |
| Boot role | 是否為 BootROM boot media 或 recovery media |
| Linux node | `/sys/bus/spi/devices/spiB.C`、MTD device、spidev node |
| Security | write protect、secure boot、signed image、field update 權限 |

##### 5.5.2 SPI flash bring-up

```sh
dmesg | grep -Ei 'spi|spi-nor|spi-nand|mtd|jedec|quad|qspi|fmc'
cat /proc/mtd
ls -l /sys/bus/spi/devices/
find /sys/bus/spi/devices -maxdepth 3 -type l -o -type f | sort | head -200
```

U-Boot 常用指令：

```text
sf probe
sf read <addr> <offset> <size>
sf erase <offset> <size>
sf write <addr> <offset> <size>
```

注意：`sf erase` 與 `sf write` 會修改 flash。使用前需確認 offset、partition、備份檔、recovery path 與 write protect 狀態。

##### 5.5.3 SPI mode / clock / signal integrity

| 現象 | 可能方向 | 第一輪檢查 |
| --- | --- | --- |
| JEDEC ID 全 0 或全 FF | CS、MISO、power、pinmux | scope CS/CLK/MOSI/MISO、DTS、U-Boot `sf probe` |
| JEDEC ID 偶發錯 | clock 過快、signal integrity、mode 錯 | 降低 SPI clock、scope、LA decode |
| erase / program fail | WP、block lock、voltage、4-byte mode | status register、WP pin、driver log |
| kernel 可讀但 BootROM 不開 | BootROM opcode / alignment / header 不符 | SoC boot spec、image offset、strap |
| quad read fail | QE bit、IO2/IO3、HOLD / WP multiplex | flash status、pinmux、DTS bus-width |

##### 5.5.4 spidev 使用限制

spidev 提供 userspace SPI 存取，適合 bring-up 或簡單 protocol 驗證；正式產品若 device 有 kernel driver，建議使用 kernel driver 或清楚的 userspace daemon。Device Tree 不建議以 `compatible = "spidev"` 代表真實硬體，應填入實際 device compatible，並在開發期間以明確方式 bind spidev。

```sh
ls -l /dev/spidev* 2>/dev/null
ls -l /sys/bus/spi/devices/spi* 2>/dev/null
readlink -f /sys/bus/spi/devices/spi1.0/driver 2>/dev/null
```

#### 5.6 UART / Serial / SOL

UART 是 bring-up 初期最重要的 debug 入口。至少需保留一組 BMC local console，並記錄 pin header、baud rate、電壓、flow control、mux、是否與 SOL / host console 共用。

| 欄位 | 說明 |
| --- | --- |
| UART controller | UART1 / UART5 / SoC serial instance |
| Linux tty | `ttyS0`、`ttyS4`、`ttyAMA0` |
| Baud / format | 115200 8N1、57600 8N1、921600 8N1 |
| Voltage | 1.8V / 3.3V，避免 USB-UART 電壓不符 |
| Pin header | board silkscreen / connector pinout / GND 位置 |
| Flow control | RTS / CTS 是否使用 |
| Console role | bootloader console、kernel console、login console、SOL、host console |
| Mux owner | BMC、CPLD、host、manual jumper |
| Log policy | AC-on 前開始收、保留完整 boot log、標記時間 |

```sh
cat /proc/cmdline | tr ' ' '\n' | grep console
cat /proc/tty/driver/serial 2>/dev/null
ls -l /dev/ttyS* /dev/ttyAMA* 2>/dev/null
systemctl status 'serial-getty@*.service' --no-pager 2>/dev/null
journalctl -b --no-pager | grep -Ei 'tty|serial|console|uart' | tail -200
```

Bring-up 建議：

- bootloader 與 kernel console 若共用同一 UART，baud rate 與 pinmux 需一致。
- 若 UART 經 CPLD / mux 切到 host console 或 BMC console，需記錄 mux select 預設值與控制方式。
- SOL / host serial 與 BMC local debug console 要分開命名，避免現場接錯線。
- 若 console log 中斷在特定階段，需同步檢查 reset / clock / pinmux，而不是只看 `serial-getty`。

#### 5.7 ADC / IIO、PWM、Tach

ADC / PWM / Tach 不一定被稱為 bus，但在 BMC sensor / fan control 中與匯流排相同：需要 controller、channel、scale、polarity、sampling、PowerState、userspace mapping 與對外 sensor 名稱。

##### 5.7.1 ADC / IIO

| 欄位 | 說明 |
| --- | --- |
| Controller | SoC ADC、external ADC、PMBus ADC |
| Channel | SoC channel、IIO channel、hwmon index |
| Voltage divider | Rtop / Rbottom、最大 pin voltage |
| Reference voltage | internal Vref / external Vref |
| Unit | raw code、mV、V；確認 daemon 期待單位 |
| Scaling formula | raw → voltage / current / power 的轉換式 |
| PowerState | AlwaysOn、HostOn、rail dependent |
| D-Bus path | `/xyz/openbmc_project/sensors/voltage/...` |

```sh
dmesg | grep -Ei 'adc|iio|hwmon'
find /sys/bus/iio/devices -maxdepth 3 -type f | sort
find /sys/class/hwmon -maxdepth 4 -type f | grep -E 'in[0-9]+_input|name|label' | sort
```

##### 5.7.2 PWM / Tach

| 欄位 | 說明 |
| --- | --- |
| PWM controller / channel | SoC PWM instance、fan controller channel |
| Tach channel | tach input channel 與 fan 物理位置 |
| PWM frequency | 依 fan spec，4-wire fan 常見 25kHz，但需以 datasheet 為準 |
| Duty range | raw 0-255、0-100%、或 period / duty_cycle |
| Polarity | normal / inversed，需以 scope 驗證 |
| Pulse per revolution | 2 PPR / 4 PPR 等，需依 fan datasheet |
| Fan power | fan rail、hot-swap、presence、fault |
| Policy owner | manual mode、fan daemon、PID service、thermal policy |

```sh
dmesg | grep -Ei 'pwm|tach|fan'
find /sys/class/hwmon -maxdepth 4 -type f | grep -E 'fan[0-9]+_input|pwm[0-9]|name|label' | sort
find /sys/class/pwm -maxdepth 5 -type f 2>/dev/null | sort
busctl tree xyz.openbmc_project.Sensor 2>/dev/null | grep -Ei 'fan|tach|pwm'
```

注意：fan daemon 若正在管理 PWM，手動寫 sysfs 可能會被 daemon 立即覆蓋。手動測試前應進入 maintenance / manual mode，或暫停對應 service，並留下測試紀錄。

#### 5.8 PECI / APML

PECI 是 Intel processor 與 BMC / management controller 之間的管理通訊介面，常用於 CPU / DIMM thermal、power 與平台 debug 資訊。PECI 使用 single-wire physical layer；CPU package address 需依平台設計與 CPU 文件確認，常見 socket address 如 `0x30`、`0x31` 但不可只靠慣例。

APML 是 AMD 平台常見管理介面集合，常見資料路徑包含 SB-TSI / SB-RMI，用於 CPU temperature、power 或 mailbox 類資訊。這兩類介面都依賴 host power state；Host off、CPU reset、socket absent 或 power transition 中時，service 應將 sensor 標示為 unavailable，而不是直接判為 sensor fault。

| 介面 | 常見用途 | 需確認 |
| --- | --- | --- |
| PECI | Intel CPU / DIMM telemetry、platform debug | PECI controller、CPU address、host power state、kernel driver、timeout |
| SB-TSI | AMD CPU temperature | I2C bus、address、driver、host power state、sensor scale |
| SB-RMI | AMD CPU management / mailbox | I2C bus、address、mailbox protocol、timeout、service dependency |

```sh
dmesg | grep -Ei 'peci|sbtsi|sbrmi|apml|cpu.*temp|dimm'
find /sys/bus/peci -maxdepth 4 -type f 2>/dev/null | sort
find /sys/class/hwmon -maxdepth 4 -type f | grep -Ei 'name|temp|power|label' | sort
busctl tree xyz.openbmc_project.Sensor 2>/dev/null | grep -Ei 'cpu|dimm|peci|apml'
busctl tree xyz.openbmc_project.State.Host 2>/dev/null
```

PECI / APML 驗證重點：

- Host off 時予以 unavailable，不產生大量 critical event。
- Host power on 後 polling start 時機需等待 CPU / PCH ready。
- 多 socket 平台需確認 socket address 與 physical socket 對應。
- CPU / DIMM sensor 命名需與 inventory association 對齊。
- timeout / retry 不可造成 sensor daemon 長時間阻塞。

#### 5.9 eSPI / LPC / KCS / BT / Port80

eSPI / LPC 是 BMC 與 host PCH / chipset 之間的管理通道，常承載 KCS / BT / IPMI、POST code、host status、virtual wire 或其他 sideband。此類介面高度依賴 host standby / reset / power state，需和第 4 章 eSPI/LPC domain、第 14 章 Power Control、第 18 章 KCS / BT / SSIF / eSPI 一起看。

| 項目 | 說明 |
| --- | --- |
| Host dependency | RSMRST、PLTRST、PCH power、eSPI clock |
| Mode | eSPI peripheral channel、VW channel、OOB channel、Flash channel；或 legacy LPC |
| BMC controller | SoC eSPI / LPC controller |
| Host interface | KCS、BT、Port80、mailbox、SERIRQ、virtual UART |
| Driver / service | kernel eSPI/LPC driver、phosphor-host-ipmid、postcode service |
| Security | host flash access、OOB command、privilege boundary、field mode |

```sh
dmesg | grep -Ei 'espi|lpc|kcs|bt|ipmi|port80|postcode|serirq|vw'
ls -l /dev/ipmi* /dev/kcs* 2>/dev/null
systemctl status phosphor-ipmi-host.service --no-pager 2>/dev/null
journalctl -u phosphor-ipmi-host.service -b --no-pager | tail -200
busctl tree xyz.openbmc_project.State.Host 2>/dev/null
busctl tree xyz.openbmc_project.State.Chassis 2>/dev/null
```

常見問題：

| 現象 | 可能方向 | 第一輪檢查 |
| --- | --- | --- |
| host IPMI 不通 | KCS / BT device 不見、daemon 未起、host side disabled | dmesg、`/dev/ipmi*`、ipmid journal、BIOS setting |
| Port80 無資料 | LPC/eSPI channel 未 ready、POST source 錯 | host state、postcode service、scope / LA |
| eSPI channel timeout | RSMRST / PLTRST / clock / virtual wire 狀態不符 | timing、CPLD register、kernel log |
| BMC reboot 後 host state 錯 | state rediscovery 不完整 | power daemon log、host GPIO、D-Bus state |

#### 5.10 Network sideband：RGMII、RMII、MDIO、NC-SI

BMC network 可能使用 dedicated PHY，也可能透過 NC-SI 與 host NIC 共用管理網路。Dedicated PHY 常見 RGMII / RMII / MDIO；NC-SI 則需注意 package / channel、host NIC power state、AEN、MAC address、link failover 與 filter policy。

##### 5.10.1 RGMII / RMII / MDIO

| 項目 | RGMII | RMII |
| --- | --- | --- |
| Clock | 常見 125MHz / 25MHz dependency | 常見 50MHz REFCLK |
| Signal | TX/RX data + control + clock | data line 較少，共用 REFCLK |
| 常見風險 | TX/RX delay、skew、PHY strap | REFCLK source、clock direction、strap |
| Debug | `ethtool`、MDIO、scope | `ethtool`、MDIO、scope |

```sh
dmesg | grep -Ei 'eth|mac|mdio|phy|rgmii|rmii|ncsi'
ip link
ip addr
ethtool eth0 2>/dev/null
ethtool -S eth0 2>/dev/null | head -100
find /sys/class/net -maxdepth 3 -type l -o -type f | sort | head -100
```

DTS / hardware 注意事項：

- `phy-mode` 需和硬體設計一致，例如 `rgmii-id`、`rgmii-rxid`、`rgmii-txid`、`rmii`。
- PHY reset 與 clock stable 的順序會影響 strap latch。
- MDIO address 由 PHY strap 決定，需與 DTS `reg` 一致。
- RGMII delay 是 PHY / MAC / board 三者分工，不能只改一端。

##### 5.10.2 NC-SI

NC-SI 常用於 BMC 與 host NIC 共享實體網路埠。需記錄 package ID、channel ID、hostless / hostful policy、link failover、MAC address、VLAN、filter、AEN 與 recovery 行為。

| 欄位 | 說明 |
| --- | --- |
| Package / Channel | NIC 內部 NC-SI package / channel mapping |
| Interface | BMC netdev，例如 `eth1` |
| Host dependency | NIC 是否在 standby 可用、host power transition 是否影響 |
| MAC policy | BMC MAC、host MAC、shared / dedicated、factory programmed |
| VLAN / filter | 是否由 NIC filter 或 BMC network stack 控制 |
| Recovery | link down、AEN、channel reset、package select |
| Service | kernel NC-SI、networkd、平台 NCSI daemon |

```sh
dmesg | grep -Ei 'ncsi|NCSI|AEN|package|channel|link'
ip link show
networkctl status 2>/dev/null
journalctl -b --no-pager | grep -Ei 'ncsi|network|eth|mac|link' | tail -300
```

驗證矩陣：

| 測試 | 預期 |
| --- | --- |
| BMC boot only、Host off | 依產品政策，NC-SI 可用或標示依賴 host |
| Host power on / off | BMC 管理網路不應無預期掉線，或 log 中需清楚記錄 transition |
| NIC reset / driver reload | BMC network 可 recovery |
| cable plug / unplug | link event、Redfish / network state 一致 |
| shared port failover | channel / package 選擇符合設計 |

#### 5.11 PCIe 管理路徑與 USB gadget

##### 5.11.1 PCIe 管理路徑

BMC 不一定直接是 PCIe root complex，但仍可能透過 sideband、MCTP over PCIe、SMBus、PERST、presence、hot-plug、retimer / switch management 參與 PCIe 裝置管理。此處重點是「BMC 管理路徑」而非 host PCIe enumeration 本身。

| 項目 | 需確認 |
| --- | --- |
| Slot power | slot power enable、PGOOD、fault、hot-swap controller |
| Reset | PERST_N、fundamental reset、hot reset、CPLD owner |
| Refclk | source、enable、spread spectrum、clock buffer |
| Presence | PRSNT pin、CPLD bit、GPIO、debounce |
| Management transport | SMBus、I2C、MCTP over PCIe、vendor sideband |
| Inventory | slot、FRU、PCIe device、retimer association |
| Security | device firmware update 授權、SPDM、debug lock |

##### 5.11.2 USB gadget

USB gadget 常用於 virtual media、USB network、USB serial、host-to-BMC debug 或 provisioning。需確認 BMC USB device controller、VBUS detect、ID pin、role switch、gadget configfs、systemd service 與 host OS driver。

```sh
dmesg | grep -Ei 'usb|gadget|udc|configfs|mass storage|rndis|ecm|hid'
ls -l /sys/class/udc 2>/dev/null
find /sys/kernel/config/usb_gadget -maxdepth 4 -type f 2>/dev/null | sort
systemctl --type=service | grep -Ei 'usb|gadget|virtual'
```

USB gadget 驗證重點：

- Host OS 可辨識 device class。
- BMC reboot / Host reboot 後 gadget role 能回復。
- Virtual media mount / unmount 不造成 BMC filesystem 殘留 busy state。
- USB network 與管理 LAN 的 route / firewall 不互相衝突。
- 量產模式與 field mode 對 gadget 功能的開關政策明確。

#### 5.12 MCTP / PLDM / SPDM

MCTP 是伺服器內部管理通訊常見基礎協定，可承載 PLDM、SPDM、NVMe-MI 與 OEM protocol。Linux kernel MCTP 以 netdevice 表示 MCTP interface，並提供 socket-based API；MCTP topology 需定義 network、interface、EID、route 與 message type。

##### 5.12.1 MCTP 分層

```text
Physical transport binding
    SMBus / I2C, PCIe, serial, vendor transport
        ↓
Linux MCTP netdev
    mctp0, mctp1 ...
        ↓
MCTP network / route / EID
        ↓
Upper protocol
    PLDM, SPDM, NVMe-MI, OEM
        ↓
OpenBMC service
    mctpd, pldmd, SPDM responder/requester, NVMe-MI daemon
```

| 項目 | 說明 |
| --- | --- |
| Transport binding | SMBus / I2C、PCIe、serial、vendor transport |
| Interface | Linux MCTP netdev，例如 `mctp0` |
| Network ID | 本地 MCTP network identifier |
| Local EID | BMC endpoint id |
| Remote EID | endpoint id，需避免同一 network 內衝突 |
| Route | EID → interface / network 的路由設定 |
| Upper protocol | PLDM、SPDM、NVMe-MI、OEM |
| Discovery | endpoint discovery、EID assignment、route setup |
| Service | mctpd、pldmd、SPDM service、NVMe-MI daemon |

```sh
dmesg | grep -Ei 'mctp|pldm|spdm|nvme-mi|eid'
ip link | grep -i mctp -A3 -B1
ip route show table all 2>/dev/null | grep -i mctp || true
busctl tree xyz.openbmc_project.PLDM 2>/dev/null
journalctl -b --no-pager | grep -Ei 'mctp|pldm|spdm|eid|nvme-mi' | tail -300
```

##### 5.12.2 PLDM / SPDM bring-up 注意事項

| 協定 | 常見用途 | Bring-up 重點 |
| --- | --- | --- |
| PLDM | FRU、sensor、firmware update、platform monitoring | endpoint discovery、terminus ID、PDR、sensor mapping、firmware package flow |
| SPDM | 裝置身份、憑證、measurement、secure session | certificate chain、algorithm、measurement hash、session policy |
| NVMe-MI | NVMe 管理、SMART、firmware slot | transport binding、controller ID、sideband availability、host state |

MCTP / PLDM / SPDM 常見現象：

| 現象 | 可能方向 | 第一輪檢查 |
| --- | --- | --- |
| MCTP netdev 不見 | kernel config、transport driver、DTS binding | dmesg、`ip link`、kernel config |
| EID 重複 | discovery policy、static config、multiple network 混淆 | mctpd log、route table、endpoint list |
| PLDM endpoint 有回應但 sensor 不出現 | PDR parsing、terminus mapping、inventory association | pldmd journal、PDR dump、D-Bus tree |
| SPDM handshake fail | algorithm mismatch、cert chain、time、policy | SPDM log、cert dump、endpoint capability |
| NVMe-MI timeout | slot power、MCTP route、controller reset、host state | slot power log、MCTP packet log、endpoint status |

#### 5.13 OpenBMC service 整合

OpenBMC 中同一個硬體裝置可能經過多個 service 才對外呈現。例如 PSU PMBus device 可能先由 kernel pmbus driver 產生 hwmon，再由 PSUSensor 建立 D-Bus sensor，再由 inventory association 與 Redfish PowerSubsystem 呈現。排查時需記錄每一層。

```text
I2C PMBus device
    ↓
kernel pmbus / hwmon
    ↓
dbus-sensors / PSUSensor
    ↓
D-Bus sensor path + inventory association
    ↓
Redfish PowerSubsystem / Chassis / EventLog
```

常用指令：

```sh
systemctl --failed
systemctl status xyz.openbmc_project.EntityManager.service --no-pager
journalctl -u xyz.openbmc_project.EntityManager.service -b --no-pager | tail -200
busctl tree xyz.openbmc_project.ObjectMapper | head -200
busctl tree xyz.openbmc_project.Sensor 2>/dev/null
busctl tree xyz.openbmc_project.Inventory.Manager 2>/dev/null
busctl tree xyz.openbmc_project.State.Host 2>/dev/null
```

服務整合檢查表：

| 項目 | 檢查重點 |
| --- | --- |
| Probe 條件 | FRU / GPIO presence / compatible / SKU 判斷是否正確 |
| PowerState gating | HostOff、Presence false、SlotPower off 時是否停止讀取或標 unavailable |
| Retry policy | device late ready、hot-swap、bus recovery 後是否重試 |
| Naming | sensor name、inventory name、Redfish name 是否一致 |
| Association | sensor → inventory、inventory → chassis / board / slot 是否完整 |
| Event policy | unavailable、warning、critical、functional false 的事件規則 |
| Service dependency | mux、GPIO expander、host state、network、mctpd / pldmd 是否先 ready |

#### 5.14 匯流排安全與副作用

周邊匯流排 debug 不只是「能不能讀到」，也要注意是否會造成副作用。建議在 bus map 中把高風險指令與安全讀取指令分開列出。

| 類型 | 風險 | 建議 |
| --- | --- | --- |
| I2C quick command | 可能觸發 device 行為 | 不熟 device 時避免對全 bus 掃描 |
| I2C write / EEPROM write | 改變 FRU / VPD / config | 預設 write protect，測試前備份 |
| PMBus CLEAR_FAULTS | 清除故障證據 | 先 dump status，再依流程 clear |
| PMBus PAGE / vendor mode | 影響後續讀值或控制 | 每次 raw 存取後恢復預期 page |
| SPI erase / write | 破壞 boot flash / CPLD / BIOS image | 先確認 offset、備份、recovery |
| GPIO reset / power enable | 造成 host 或 device reset | 先確認 owner、safe state、測試窗口 |
| Retimer / PCIe sideband | 影響 host link training | 配合 host power state 與測試計畫 |
| MCTP / PLDM control | 改變 endpoint 設定或 firmware 狀態 | 區分 read-only query 與 control command |
| USB gadget | 暴露 provisioning / storage / network path | field mode 與 factory mode 權限分開 |
| eSPI / LPC / KCS | host / BMC privilege boundary | 確認 BIOS、BMC security policy |

#### 5.15 Target 端共用 log 收集

本節提供匯流排共用 log 套件。實際平台可依 image 中可用工具調整；指令失敗時不代表測試失敗，但需保留 stderr 供分析。

```sh
mkdir -p /tmp/bus-debug
cat /etc/os-release > /tmp/bus-debug/os-release.txt
uname -a > /tmp/bus-debug/uname.txt
cat /proc/cmdline > /tmp/bus-debug/proc-cmdline.txt
zcat /proc/config.gz > /tmp/bus-debug/kernel-config.txt 2>&1 || true
dmesg -T > /tmp/bus-debug/dmesg.txt
journalctl -b --no-pager > /tmp/bus-debug/journal.txt
systemctl --failed > /tmp/bus-debug/systemctl-failed.txt 2>&1

# Device Tree / pinctrl / gpio / clock
tr '\0' '\n' < /proc/device-tree/model > /tmp/bus-debug/dt-model.txt 2>&1 || true
tr '\0' '\n' < /proc/device-tree/compatible > /tmp/bus-debug/dt-compatible.txt 2>&1 || true
find /proc/device-tree -maxdepth 6 -type f | grep -Ei 'i2c|spi|serial|uart|ethernet|mdio|peci|usb|mctp' > /tmp/bus-debug/dt-bus-files.txt 2>&1 || true
mount | grep debugfs || mount -t debugfs debugfs /sys/kernel/debug 2>/dev/null || true
cat /sys/kernel/debug/clk/clk_summary > /tmp/bus-debug/clk-summary.txt 2>&1 || true
cat /sys/kernel/debug/gpio > /tmp/bus-debug/debug-gpio.txt 2>&1 || true
find /sys/kernel/debug/pinctrl -maxdepth 3 -type f -print > /tmp/bus-debug/pinctrl-files.txt 2>&1 || true

# I2C / SMBus / PMBus
i2cdetect -l > /tmp/bus-debug/i2cdetect-l.txt 2>&1 || true
ls -l /sys/bus/i2c/devices > /tmp/bus-debug/sys-bus-i2c-devices.txt 2>&1 || true
find /sys/bus/i2c/devices -maxdepth 3 -type l -o -type f > /tmp/bus-debug/i2c-tree.txt 2>&1 || true

# SPI / MTD
ls -l /sys/bus/spi/devices > /tmp/bus-debug/sys-bus-spi-devices.txt 2>&1 || true
find /sys/bus/spi/devices -maxdepth 3 -type l -o -type f > /tmp/bus-debug/spi-tree.txt 2>&1 || true
cat /proc/mtd > /tmp/bus-debug/proc-mtd.txt 2>&1 || true

# UART
cat /proc/tty/driver/serial > /tmp/bus-debug/proc-tty-serial.txt 2>&1 || true
ls -l /dev/ttyS* /dev/ttyAMA* > /tmp/bus-debug/tty-devices.txt 2>&1 || true

# ADC / hwmon / PWM / fan
find /sys/class/hwmon -maxdepth 5 -type f > /tmp/bus-debug/hwmon-files.txt 2>&1 || true
find /sys/bus/iio/devices -maxdepth 4 -type f > /tmp/bus-debug/iio-files.txt 2>&1 || true
find /sys/class/pwm -maxdepth 5 -type f > /tmp/bus-debug/pwm-files.txt 2>&1 || true

# PECI / APML
find /sys/bus/peci -maxdepth 4 -type f > /tmp/bus-debug/peci-files.txt 2>&1 || true

# eSPI / LPC / IPMI host interface
ls -l /dev/ipmi* /dev/kcs* > /tmp/bus-debug/ipmi-devices.txt 2>&1 || true
journalctl -u phosphor-ipmi-host.service -b --no-pager > /tmp/bus-debug/phosphor-ipmi-host-journal.txt 2>&1 || true

# Network / NC-SI / MDIO
ip link > /tmp/bus-debug/ip-link.txt 2>&1 || true
ip addr > /tmp/bus-debug/ip-addr.txt 2>&1 || true
networkctl status > /tmp/bus-debug/networkctl-status.txt 2>&1 || true
for n in /sys/class/net/*; do
    iface=$(basename "$n")
    ethtool "$iface" > "/tmp/bus-debug/ethtool-${iface}.txt" 2>&1 || true
    ethtool -S "$iface" > "/tmp/bus-debug/ethtool-${iface}-stats.txt" 2>&1 || true
done

# MCTP / PLDM / SPDM
ip link | grep -i mctp -A3 -B1 > /tmp/bus-debug/mctp-link.txt 2>&1 || true
journalctl -b --no-pager | grep -Ei 'mctp|pldm|spdm|eid|nvme-mi' > /tmp/bus-debug/mctp-pldm-spdm-journal.txt 2>&1 || true
busctl tree xyz.openbmc_project.PLDM > /tmp/bus-debug/pldm-tree.txt 2>&1 || true

# D-Bus / inventory / sensor
busctl tree xyz.openbmc_project.Sensor > /tmp/bus-debug/sensor-tree.txt 2>&1 || true
busctl tree xyz.openbmc_project.Inventory.Manager > /tmp/bus-debug/inventory-tree.txt 2>&1 || true
busctl tree xyz.openbmc_project.State.Host > /tmp/bus-debug/host-state-tree.txt 2>&1 || true
busctl tree xyz.openbmc_project.State.Chassis > /tmp/bus-debug/chassis-state-tree.txt 2>&1 || true

tar czf /tmp/bus-debug-$(date +%Y%m%d-%H%M%S).tar.gz -C /tmp bus-debug
```

#### 5.16 常見問題與排查入口

| 現象 | 可能方向 | 第一輪檢查 |
| --- | --- | --- |
| I2C bus 不見 | controller disabled、pinmux、clock/reset、DTS status | dmesg、`i2cdetect -l`、pinctrl、clk_summary |
| I2C device NACK | address 錯、power off、reset asserted、mux channel 錯、pull-up rail off | scope、指定 bus 掃描、mux sysfs、PowerState |
| I2C bus hang | SDA/SCL 被拉低、device stuck、level shifter 問題 | scope、bus recovery、device reset |
| PMBus 讀值錯 | PAGE / PHASE / format / scale 錯 | hwmon label、datasheet、driver log |
| PMBus fault 消失 | status 被 clear | journal、clear history、測試流程 |
| SPI flash JEDEC ID 錯 | SPI mode、CS、clock、pinmux、WP/HOLD、電壓 | scope、dmesg、U-Boot `sf probe` |
| spidev 不出現 | compatible / driver binding 不符 | dmesg、`/sys/bus/spi/devices` |
| UART 無 log | pinmux、baud rate、電壓、console bootargs、mux | scope、`/proc/cmdline`、serial-getty |
| UART 有亂碼 | baud rate、clock parent、電壓不符 | U-Boot env、kernel cmdline、scope |
| ADC 讀值 0 或滿量程 | channel 錯、分壓錯、Vref、power state | IIO sysfs、DMM、DTS channel |
| PWM 無輸出 | pinmux、clock、polarity、service 覆蓋 | scope、pwm sysfs、fan daemon log |
| Tach RPM 為 0 | fan power、tach pull-up、PPR、channel mapping | scope、hwmon、fan presence |
| PECI / APML timeout | host off、CPU reset、address 錯、driver 未 probe | host state、dmesg、hwmon |
| eSPI / LPC 不 ready | RSMRST / PLTRST / clock / PCH sideband | power timeline、dmesg、host state |
| KCS / BT host IPMI 不通 | `/dev/ipmi*` 不見、daemon fail、BIOS disabled | dmesg、ipmid journal、BIOS setup |
| Dedicated LAN no link | PHY reset/clock/strap、RGMII delay、MDIO address | ethtool、MDIO、scope |
| NC-SI link 不起 | package / channel、NIC power、AEN、MAC policy | dmesg、`ip link`、network journal |
| USB gadget 不出現 | UDC not bound、role switch、VBUS detect、host driver | dmesg、configfs、host device manager |
| MCTP endpoint 不見 | EID / route / binding / service 未 ready | `ip link`、mctpd / pldmd journal |
| PLDM sensor 不出現 | PDR / terminus / association 問題 | pldmd journal、D-Bus tree、inventory |
| SPDM handshake fail | algorithm / certificate / policy mismatch | SPDM log、cert chain、endpoint capability |
| Redfish / IPMI 不顯示 | D-Bus object / inventory association / mapping | busctl、bmcweb、ipmid log |

#### 5.17 Bring-up 建議流程

1. 建立完整 bus map：controller、Linux node、mux、address / endpoint、driver、OpenBMC service。
2. 先確認 power / reset / clock / pinmux，引用第 3、4 章表格。
3. 確認 controller probe：dmesg、sysfs、debugfs、kernel config。
4. 確認 child device / endpoint：address、CS、package/channel、EID、binding、driver。
5. 確認 raw interface：hwmon、IIO、tty、spidev、MTD、netdev、MCTP interface。
6. 導入 OpenBMC config：Entity Manager、dbus-sensors、fan service、power service、network service、mctpd / pldmd。
7. 驗證 D-Bus object：ObjectMapper、sensor path、inventory path、state path、association。
8. 驗證外部介面：Redfish、IPMI、SEL / EventLog。
9. 做異常測試：NACK、bus hang、hot-swap、host power off/on、service restart、BMC reboot、AC cycle。
10. 保存 bus-debug log、scope / LA、版本、DTS commit、service config commit。
11. 回填 Chapter 5 bus map、當前平台實測表、限制事項與 owner。

#### 5.18 當前平台匯流排實測表

##### 5.18.1 Bus controller 實測表

| Bus type | Controller | Linux node | DTS status | Driver | Power domain | Pinmux state | 實測結果 | 狀態 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| I2C | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待確認] |
| SPI | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待確認] |
| UART | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待確認] |
| PECI/APML | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待確認] |
| eSPI/LPC | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待確認] |
| Ethernet/NC-SI | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待確認] |
| MCTP | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待確認] |
| USB gadget | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待確認] |

##### 5.18.2 I2C / SMBus / PMBus 實測表

| Physical bus | Logical bus | Mux path | Device | Address | Driver / service | PowerState | Safe read command | 實測結果 | 備註 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] |
| [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] |

##### 5.18.3 MCTP / PLDM / SPDM 實測表

| Transport | Interface | Network ID | Local EID | Remote EID | Endpoint | Upper protocol | Service | 實測結果 | 備註 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] |
| [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] |

#### 5.19 驗收 Checklist

- [ ] 每個 bus controller 已建立 schematic → DTS → Linux runtime → OpenBMC config 對照。
- [ ] I2C logical bus number、mux channel、device address、driver、PowerState 已填入 bus map。
- [ ] I2C / SMBus / PMBus 高風險讀寫 command 已標示副作用。
- [ ] PMBus PAGE / PHASE / data format / fault clear policy 已確認。
- [ ] SPI mode、clock、CS、data lane、flash opcode、address byte、WP / HOLD 已確認。
- [ ] SPI boot flash 的 BootROM、U-Boot、kernel MTD / UBI 路徑已與第 2 章對齊。
- [ ] UART console 至少保留一組，baud rate、pin header、電壓、mux owner 已記錄。
- [ ] SOL / host serial 與 BMC local console 命名清楚，現場接線不易混淆。
- [ ] ADC channel、scale、Vref、divider、D-Bus path 已對齊。
- [ ] PWM / Tach channel、polarity、frequency、PPR、fan presence 已驗證。
- [ ] PECI / APML address、host power state、driver / hwmon mapping 已驗證。
- [ ] eSPI / LPC / KCS / BT / Port80 與 host power / reset dependency 已記錄。
- [ ] RGMII / RMII / MDIO 的 clock、reset、PHY strap、delay mode 已驗證。
- [ ] NC-SI package / channel、MAC policy、host dependency、link recovery 已驗證。
- [ ] USB gadget 的 UDC、role、configfs、host driver 與安全模式已確認。
- [ ] MCTP transport、netdev、network、EID、route、service 狀態已確認。
- [ ] PLDM / SPDM / NVMe-MI endpoint discovery 與 service log 已保存。
- [ ] D-Bus / Redfish / IPMI / SEL 對外狀態與 raw bus / sysfs 資料一致。
- [ ] bus-debug log 收集腳本已可執行，且納入 bring-up / regression 流程。
- [ ] 高風險 debug 指令已建立使用限制與備份 / recovery 流程。

#### 5.20 本章參考資料

- Linux kernel documentation - I2C / SMBus subsystem: https://docs.kernel.org/i2c/index.html
- Linux kernel documentation - Linux I2C Sysfs: https://docs.kernel.org/i2c/i2c-sysfs.html
- Linux kernel documentation - Serial Peripheral Interface: https://docs.kernel.org/spi/index.html
- Linux kernel documentation - SPI userspace API: https://docs.kernel.org/spi/spidev.html
- Linux kernel documentation - Low Level Serial API: https://docs.kernel.org/driver-api/serial/driver.html
- Linux kernel documentation - PECI subsystem: https://docs.kernel.org/peci/index.html
- Linux kernel documentation - MCTP networking: https://docs.kernel.org/networking/mctp.html
- DMTF DSP0236 - Management Component Transport Protocol Base Specification: https://www.dmtf.org/dsp/DSP0236
- DMTF PMCI standards page, including NC-SI / MCTP family specifications: https://www.dmtf.org/standards/pmci
- OpenBMC libmctp: https://github.com/openbmc/libmctp
- OpenBMC docs - MCTP kernel design: https://github.com/openbmc/docs/blob/master/designs/mctp/mctp-kernel.md

### 6. CPLD / FPGA / Board Glue Logic

本章整理 BMC 平台中 CPLD、FPGA、board glue logic、platform controller、small MCU、hot-swap / fault latch、reset / power sequencing logic 與 GPIO-like register 的共用設計模式與排查方法。相較第 3 章的 Pinmux / GPIO、第 4 章的 Reset / Clock / Power Domain、第 5 章的周邊匯流排，本章聚焦「板級邏輯如何把多個訊號、時序、狀態、保護條件與 BMC / Host / BIOS / PSU / VR / slot 串接起來」。

CPLD / FPGA 在伺服器平台中常見職責包含 power sequence、reset mux、watchdog reset target、LED pattern、board ID / SKU ID、fault latch、presence detect、write protect、BIOS / BMC flash mux、host sideband、front panel button、slot power enable、hot-swap retry、debug strap、manufacturing mode、security strap、firmware update gate。若文件只記錄 register offset 與 bit name，通常不足以排查問題；需同時記錄訊號來源、active level、default、clear rule、owner、讀寫副作用、與 OpenBMC 對外狀態的關係。

本章的目標是讓每一個 CPLD / FPGA bit 都能回答下列問題：

- 這個 bit 代表 raw pin 電位、latched fault、debounced state、derived state，還是 BMC 寫入的 control request？
- 讀取該 bit 是否有副作用？寫入該 bit 是否會清除 latch、觸發 pulse、切 mux、關 power、放 reset？
- power-on default 由誰決定：CPLD image、外部 pull、reset pin、strap、NVM 設定，還是 BMC service？
- 這個 bit 的 owner 是 CPLD、BMC、BIOS、Host、Security、Manufacturing，還是多方共享？
- bit 狀態如何映射到 Linux sysfs / D-Bus / Redfish / IPMI / SEL？
- CPLD image 更新、BMC reboot、AC cycle、Host reset、watchdog reset 後，該狀態是否符合預期？

#### 6.1 角色與邊界

CPLD / FPGA / board glue logic 不是單純的「I/O expander」。在許多平台中，它負責在 BMC Linux 尚未啟動前維持安全狀態，並在 host power transition 中執行即時時序控制。因此排查時需把 CPLD 視為一個獨立 controller，而不是只看成幾個 GPIO。

| 類型 | 常見職責 | 與 BMC 的關係 | Bring-up 重點 |
| --- | --- | --- | --- |
| CPLD | power sequence、reset mux、fault latch、LED、board ID、WP | BMC 透過 I2C / LPC / MMIO / GPIO 讀寫 register | register map、default、clear rule、image version |
| FPGA | 高速板級邏輯、bridge、custom protocol、debug capture | BMC 可能負責 config、status、firmware update | configuration source、bitstream、done / init 狀態 |
| Board glue logic | level shift、simple latch、mux、wired-OR、RC delay | BMC 只能量測或間接控制 | schematic、時序、pull、owner |
| Platform MCU | power / thermal / security co-controller | BMC 透過 I2C / UART / mailbox 溝通 | protocol、firmware version、timeout、recovery |
| Hot-swap / eFuse / supervisor | slot power、fault protection、PGOOD | BMC 讀 status、下 reset / retry | fault status、retry policy、clear rule |

建議先界定邊界：

- CPLD 自主決定的狀態，例如 power sequence step、fault latch、debounce state。
- BMC request 類狀態，例如 power on request、LED mode、write protect enable。
- Host / BIOS / PCH 決定的狀態，例如 PLTRST、SLP_Sx、RSMRST、POST complete。
- 硬體 raw input，例如 presence pin、AC_OK、VR_PGOOD、PSU_PRESENT。
- CPLD derived output，例如 SYS_PWROK、PERST_N、PSU_ON_N、RESET_OUT_N。

#### 6.2 系統架構與資料流

典型 CPLD / BMC / Host 資料流如下：

```text
Raw hardware signal
    PSU / VR / slot / button / strap / presence / fault
        ↓
CPLD sampling / debounce / latch / state machine
        ↓
CPLD register map
    status / control / latch / version / scratch / security
        ↓
BMC access layer
    I2C / LPC / MMIO / GPIO / UART / mailbox / JTAG tool
        ↓
Linux driver / userspace tool / OpenBMC daemon
        ↓
D-Bus state / sensor / inventory / event
        ↓
Redfish / IPMI / WebUI / SEL / service policy
```

排查時需分清楚 raw signal、latched signal、derived state 與 outward state：

| 名稱 | 意義 | 典型例子 | 排查方式 |
| --- | --- | --- | --- |
| Raw input | CPLD 腳位目前電位 | `VR_FAULT_N`、`PSU0_PRESENT_N` | scope / LA、CPLD raw status bit |
| Debounced state | CPLD 過濾後狀態 | button pressed、presence stable | CPLD status、debounce 設定 |
| Latched fault | 曾經發生且等待清除 | VR fault latch、power sequence timeout | latch register、clear rule、fault timestamp |
| Control request | BMC / Host 寫入的要求 | power on request、LED mode、WP enable | register write log、owner policy |
| Derived output | CPLD state machine 產生的輸出 | `SYS_PWROK`、`PERST_N`、`PSU_ON_N` | waveform、state machine debug bit |
| External state | OpenBMC 對外呈現 | Redfish PowerState、SEL、Functional | D-Bus、bmcweb、ipmid |

#### 6.3 CPLD / FPGA 必填資料

平台 bring-up 前，至少需填完下表，並在每次更換 CPLD image、BMC image、BIOS、power sequence、schematic revision、board rework 後更新。

| 欄位 | 說明 |
| --- | --- |
| Device name | CPLD / FPGA / MCU 名稱，與 schematic 一致 |
| Vendor / part number | Lattice、Intel、AMD/Xilinx、Microchip 等，填實際料號 |
| Board location | Silkscreen、I2C bus、JTAG chain、connector |
| Firmware / image version | 版本 register、build id、git commit、date code |
| Access bus | I2C、LPC、eSPI sideband、MMIO、UART、JTAG、SPI |
| I2C address / BAR / port | 存取位址與 bus path |
| Register width | 8-bit、16-bit、32-bit，endianness |
| Address auto-increment | multi-byte 讀寫是否支援 auto-increment |
| Reset source | POR、BMC reset、Host reset、CPLD reset pin、watchdog |
| Power rail | standby rail、host rail、slot rail |
| Clock source | internal oscillator、external clock、host clock |
| Default policy | AC applied 後的安全預設狀態 |
| Update method | JTAG、I2C、SPI、BMC tool、factory tool |
| Fallback / recovery | golden image、dual image、JTAG recovery、manual strap |
| Security / WP | 更新授權、write protect、field mode、manufacturing mode |
| Owner | HW、CPLD、BMC、BIOS、Security、Manufacturing |

#### 6.4 Register map 設計與填寫規則

CPLD register map 不只列 offset，更應描述 bit 的生命週期與副作用。建議每個 register 分成 status、control、latch、clear、version、scratch、debug 類別，不要把不同語意混在同一個欄位。

##### 6.4.1 Register map 總表

| Offset | Register | Width | R/W | Default | Reset domain | Description | Owner | 備註 |
| ---: | --- | ---: | --- | --- | --- | --- | --- | --- |
| `0x00` | `CPLD_ID` | 8 | RO | [待填] | POR | device / board CPLD ID | CPLD | 需與 BOM 對齊 |
| `0x01` | `CPLD_VER_MAJOR` | 8 | RO | [待填] | POR | CPLD major version | CPLD | image 版本 |
| `0x02` | `CPLD_VER_MINOR` | 8 | RO | [待填] | POR | CPLD minor version | CPLD | image 版本 |
| `0x10` | `RAW_PRESENCE` | 8 | RO | pin state | live | raw presence inputs | HW/CPLD | 不含 debounce |
| `0x11` | `DEBOUNCE_PRESENCE` | 8 | RO | [待填] | live | debounced presence | CPLD | 給 BMC service 使用 |
| `0x20` | `FAULT_LATCH` | 8 | RO | `0x00` | sticky | latched fault | CPLD/HW | 搭配 clear register |
| `0x21` | `FAULT_CLEAR` | 8 | W1C | `0x00` | live | clear selected latch | BMC/CPLD | 清除前先保存 log |
| `0x30` | `POWER_CTRL` | 8 | RW | safe off | BMC reset / POR | power request bits | BMC/CPLD | policy owner 需明確 |
| `0x31` | `POWER_STATE` | 8 | RO | [待填] | live | state machine state | CPLD | power sequence debug |
| `0x40` | `RESET_CTRL` | 8 | RW/Pulse | safe reset | [待填] | reset pulse / mux | BMC/CPLD | 寫入可能觸發 pulse |
| `0x50` | `LED_CTRL` | 8 | RW | default pattern | [待填] | LED mode | BMC/CPLD | BMC / CPLD owner 切換 |
| `0x60` | `SECURITY_STATUS` | 8 | RO | [待填] | sticky/live | WP / field mode / strap | Security | 不可由一般 service 修改 |
| `0x70` | `SCRATCH` | 8 | RW | `0x00` | BMC reset? | debug scratch | BMC | bring-up 用 |

##### 6.4.2 Bit 欄位範本

| Register | Bit | Name | R/W | Active | Default | Meaning | Clear rule | Side effect | Owner | Test method |
| --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `FAULT_LATCH` | 0 | `VR_FAULT_LATCH` | RO | High=latched | 0 | VR fault 曾發生 | 寫 `FAULT_CLEAR[0]=1` | clear 後 fault 證據消失 | CPLD/HW | fault injection |
| `FAULT_LATCH` | 1 | `PSU_PGOOD_TIMEOUT` | RO | High=latched | 0 | PSU power good timeout | W1C | 需先保存 waveform | CPLD/HW | power cycle |
| `POWER_CTRL` | 0 | `HOST_PWR_ON_REQ` | RW | High=request | 0 | BMC 要求 host power on | BMC 寫 0 清除 | 觸發 power sequence | BMC/CPLD | host on/off |
| `RESET_CTRL` | 0 | `HOST_RESET_PULSE` | WO/Pulse | write 1 | 0 | 觸發 host reset pulse | auto clear | 會 reset host | BMC/CPLD | LA / host log |
| `SECURITY_STATUS` | 0 | `BIOS_WP_EN` | RO/RW | High=WP | safe on | BIOS flash write protect | 依 policy | 可能影響 BIOS update | Security/BMC | update flow |

##### 6.4.3 Register 語意規則

建議在 register map 中固定使用下列語意：

- `RO`：純讀取，不因 read 改變狀態。
- `RW`：讀寫暫存狀態，需說明 reset 後 default。
- `W1C`：write one clear，清除前需保存狀態。
- `W1S`：write one set，常用於 request 或 latch。
- `RC`：read clear，讀取會清除，需在表格中清楚標示。
- `Pulse`：寫入後 CPLD 產生固定寬度 pulse，需記錄 pulse width。
- `Sticky`：跨 warm reset 保留，直到 AC cycle 或 clear。
- `Live`：即時反映 pin 或 internal state。
- `Shadow`：BMC 寫入但 CPLD 延後套用，需有 apply / commit 位元。

#### 6.5 存取通道與驅動策略

CPLD / FPGA register 可透過多種通道暴露給 BMC。不同通道的 timeout、atomicity、endianness、multi-byte read 行為與安全邊界不同，需在文件中記錄。

| Access path | 常見形式 | 優點 | 注意事項 |
| --- | --- | --- | --- |
| I2C / SMBus | `i2c-X` + address | 簡單、常見、工具完整 | bus hang、byte/word order、read side effect |
| LPC / eSPI sideband | I/O port、mailbox、KCS-like | 與 host sideband 接近 | host state dependency、安全邊界 |
| MMIO | memory mapped register | 快速、可做 driver | address range、endianness、devmem 風險 |
| GPIO-like | gpiochip / line | 可整合 libgpiod | 不適合複雜 clear / latch 語意 |
| SPI | register protocol 或 flash image path | 可支援較大資料量 | CS、mode、flash / config 區分 |
| UART / mailbox | custom command | 彈性高 | protocol、timeout、版本相容性 |
| JTAG | factory / recovery | 最後救援路徑 | 現場可用性、安全限制 |

##### 6.5.1 I2C register access 注意事項

```sh
# 先確認 bus 與 address
 i2cdetect -l
 i2cdetect -y <bus>

# 讀單一 register，請先確認該 register 不是 read-clear
 i2cget -y <bus> <addr> <offset>

# 寫 register 前需確認副作用
 i2cset -y <bus> <addr> <offset> <value>
```

安全提醒：

- read-clear / W1C register 不可用一般輪詢工具反覆讀取。
- multi-byte version / counter 若不是 atomic read，需記錄讀取順序。
- 若同一 CPLD 同時由 kernel driver 與 userspace tool 存取，需有鎖定機制或管理流程。
- 若 CPLD register 使用 bank / page，raw tool 使用後需恢復預設 page。

##### 6.5.2 Linux driver 與 userspace tool

常見整合方式：

| 方式 | 適用情境 | 注意事項 |
| --- | --- | --- |
| userspace raw tool | bring-up、factory、debug | 需保護高風險寫入、記錄版本 |
| hwmon driver | 電壓、電流、溫度、fan 類狀態 | channel label 與 scale 需對齊 |
| gpio-regmap / GPIO driver | CPLD bit 暴露成 GPIO line | active level、latch / clear 不適合簡化為 GPIO |
| regmap-based custom driver | register map 較完整 | 可集中處理 endianness、locking、sysfs |
| OpenBMC daemon | 平台狀態、power control、LED、fault manager | service dependency、policy、event log |

#### 6.6 Power sequence 與 state machine

CPLD 常負責 host power sequence、slot power、PSU on/off、VR enable、PGOOD timeout、fault shutdown。文件中需要記錄 state machine，而不是只記錄 power enable bit。

##### 6.6.1 Power sequence 狀態範本

| State ID | State name | Entry condition | CPLD outputs | Wait signal | Timeout | Failure latch | Next state |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 0 | `S0_IDLE_OFF` | AC present, host off | PSU_ON_N deassert | power request | N/A | N/A | `S1_PSU_ON` |
| 1 | `S1_PSU_ON` | BMC host on request | PSU_ON_N assert | PSU_PGOOD | [待填] | PSU_PGOOD_TIMEOUT | `S2_VR_ENABLE` |
| 2 | `S2_VR_ENABLE` | PSU_PGOOD true | VR_EN assert | VR_PGOOD | [待填] | VR_PGOOD_TIMEOUT | `S3_SYS_PWROK` |
| 3 | `S3_SYS_PWROK` | all VR_PGOOD true | SYS_PWROK assert | PCH ready | [待填] | SYS_PWROK_TIMEOUT | `S4_RELEASE_RESET` |
| 4 | `S4_RELEASE_RESET` | PCH ready | release PLTRST / PERST | POST complete | [待填] | POST_TIMEOUT | `S5_HOST_ON` |
| 5 | `S5_HOST_ON` | Host running | monitor faults | power off request / fault | N/A | fault latch | `S6_SHUTDOWN` |
| 6 | `S6_SHUTDOWN` | request or fault | deassert enables by policy | rails off | [待填] | SHUTDOWN_TIMEOUT | `S0_IDLE_OFF` |

##### 6.6.2 Power sequence 需記錄的訊號

| 類型 | 範例 | 需記錄 |
| --- | --- | --- |
| Request | BMC power on、front panel button、AC restore | requester、debounce、priority |
| Enable | PSU_ON_N、VR_EN、slot power enable | active level、default、owner |
| Good | PSU_PGOOD、VR_PGOOD、PCH_PWROK | timeout、fault latch、是否 debounced |
| Reset | RSMRST_N、PLTRST_N、PERST_N | release 條件、pulse width |
| Fault | UV/OV/OC/OT、hot-swap fault | latch、clear rule、shutdown policy |
| Policy | AC restore、fault retry、watchdog reset target | BMC / CPLD / BIOS 協調 |

##### 6.6.3 Power sequence 排查

```sh
# CPLD register dump，依平台工具調整
# cpldtool dump > /tmp/cpld-dump.txt

# OpenBMC state
busctl tree xyz.openbmc_project.State.Host 2>/dev/null
busctl tree xyz.openbmc_project.State.Chassis 2>/dev/null
journalctl -b --no-pager | grep -Ei 'power|pgood|pwrok|vr|psu|cpld|fault|timeout' | tail -300
```

建議 scope / LA 同步量測：

- `AC_OK`
- standby rail
- `BMC_READY`
- `PSU_ON_N`
- `PSU_PGOOD`
- `VR_EN`
- `VR_PGOOD`
- `SYS_PWROK`
- `RSMRST_N`
- `PLTRST_N`
- `PERST_N`
- `POST_COMPLETE`

#### 6.7 Reset mux、reset pulse 與 watchdog target

CPLD 常負責 reset mux 與 reset target selection。BMC reboot、host reset、watchdog reset、external reset、button reset、CPLD reset 的影響範圍必須明確記錄。

| Reset source | 產生者 | Target | Pulse width | 是否影響 host | 是否影響 BMC | 備註 |
| --- | --- | --- | --- | --- | --- | --- |
| BMC watchdog | SoC / systemd | BMC reset or full board | [待填] | [待填] | 是 | 需確認 CPLD policy |
| Host reset button | front panel / CPLD | Host reset | [待填] | 是 | 否 | debounce |
| BMC request host reset | BMC → CPLD | Host reset | [待填] | 是 | 否 | power state gating |
| AC cycle | external power | Full board | N/A | 是 | 是 | fault latch reset policy |
| CPLD internal fault | CPLD state machine | rail shutdown / reset | [待填] | 是 | 視設計 | fault latch |

Reset mux 欄位範本：

| Signal | Source A | Source B | Mux select | Default | Owner | Safe state | 實測 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `HOST_RESET_N` | front panel button | BMC request | CPLD bit [待填] | front panel enabled | CPLD/BMC | deassert unless request | [待填] |
| `BMC_SPI_SEL` | BMC SPI controller | Host / factory path | strap / CPLD bit | BMC boot path | Security/HW | boot flash protected | [待填] |
| `UART_MUX_SEL` | BMC console | Host console | CPLD bit [待填] | BMC console | BMC/HW | debug available | [待填] |

#### 6.8 Fault latch、event 與 clear policy

Fault latch 是 CPLD 最常見但也最容易誤解的功能。Fault latch 表示「曾經發生」，不一定代表目前仍然存在；raw status 表示「現在狀態」。兩者必須分開寄存器與文件欄位。

| Fault type | Raw bit | Latch bit | Clear rule | Event policy | 備註 |
| --- | --- | --- | --- | --- | --- |
| VR fault | `VR_FAULT_RAW` | `VR_FAULT_LATCH` | W1C after dump | SEL / Redfish event | 需保存 PMBus status |
| PSU PGOOD timeout | `PSU_PGOOD_RAW` | `PSU_PGOOD_TIMEOUT` | W1C | power sequence failure | 需 waveform |
| Thermal trip | `THERMTRIP_RAW` | `THERMTRIP_LATCH` | AC cycle or W1C | critical event | 可能需硬體 latch |
| Chassis intrusion | `INTRUSION_RAW` | `INTRUSION_LATCH` | user rearm | security event | rearm policy 需明確 |
| Slot overcurrent | `SLOT_OC_RAW` | `SLOT_OC_LATCH` | clear after slot power off | slot fault | retry 次數需記錄 |

Clear policy 建議：

1. 先保存 CPLD dump、PMBus / PMIC status、BMC journal、SEL / EventLog。
2. 確認 raw fault 是否已解除。
3. 依 owner 與安全政策執行 clear。
4. clear 後立即再次 dump，確認 latch 是否清除且未重現。
5. 將 clear 時間與執行者寫入測試紀錄。

#### 6.9 Presence、Board ID、SKU ID 與 strap

CPLD 常彙整 presence、board ID、SKU ID、riser type、cable ID、factory mode、debug strap。這些 bit 可能由 raw pin、resistor strap、EEPROM、GPIO expander 或 CPLD NVM 設定而來，需要記錄來源。

| 類型 | 範例 | 來源 | OpenBMC 對應 | 注意事項 |
| --- | --- | --- | --- | --- |
| Presence | PSU、fan、riser、NVMe backplane | raw GPIO / CPLD debounce | inventory present | active level、debounce、hot-swap |
| Board ID | mainboard revision | strap resistor / CPLD register | Entity Manager Probe | boot 前需穩定 |
| SKU ID | feature set | resistor / EEPROM / CPLD NVM | config selection | 與 BOM / product name 對齊 |
| Cable ID | front panel / riser cable | GPIO ID pins | inventory / topology | 插拔時 event policy |
| Manufacturing mode | factory strap | jumper / CPLD bit | factory service enable | 量產後需關閉 |
| Security strap | secure boot / debug enable | strap / OTP / CPLD | security policy | 不可被一般流程改變 |

Presence 與 inventory 對齊：

```text
CPLD raw presence bit
    ↓
CPLD debounced presence status
    ↓
OpenBMC service / Entity Manager Probe
    ↓
Inventory Present=true/false
    ↓
Sensor availability / Redfish chassis / IPMI SDR
```

#### 6.10 LED、button、front panel 與 user visible state

CPLD 常負責 front panel LED pattern 與 button debounce。LED 類訊號需確認 owner：有些平台由 BMC 控制 LED group，有些由 CPLD 自主根據 fault state 控制，有些支援 BMC override。

| 功能 | CPLD 角色 | BMC 角色 | 需確認 |
| --- | --- | --- | --- |
| UID LED | blink / on / off pattern | Redfish IndicatorLED / identify service | polarity、blink frequency、override |
| Fault LED | 根據 fault latch 或 BMC request | fault manager / event policy | CPLD autonomous vs BMC controlled |
| Power LED | host power state pattern | state manager | host off / on / standby pattern |
| UID button | debounce、short/long press | identify toggle / event | debounce time、long press policy |
| Power button | debounce、pulse / pass-through | host power request | owner、pulse width、host state gating |
| Reset button | debounce、reset request | reset policy | host reset vs BMC reset |

LED pattern 表格範本：

| LED | Mode | Pattern | Source | Priority | Redfish / IPMI 對應 |
| --- | --- | --- | --- | --- | --- |
| UID | Off | off | BMC/CPLD | normal | IndicatorLED=Off |
| UID | Identify | blink [待填] Hz | BMC request | user request | IndicatorLED=Blinking |
| Fault | Critical | solid / blink [待填] | CPLD fault latch | fault high priority | Health=Critical |
| Power | Standby | slow blink / amber [待填] | CPLD state | platform policy | PowerState=Standby |

#### 6.11 Write protect、flash mux 與更新保護

CPLD 常控制 BIOS flash WP、BMC flash WP、CPLD image WP、flash mux、recovery strap。這類功能屬於安全與維修邊界，需比一般 GPIO 更嚴格記錄。

| 項目 | 需記錄 |
| --- | --- |
| BIOS flash WP | active level、default、授權流程、BIOS update service owner |
| BMC flash WP | boot flash保護、field update 是否可解除、recovery policy |
| CPLD image WP | factory / field mode、JTAG enable、update authorization |
| Flash mux | BMC / host / factory programmer 誰可存取，mux default |
| Recovery strap | 手動 / 自動進入條件、退出條件 |
| Anti-rollback | CPLD 是否參與 version / policy 判斷 |

BIOS update / CPLD update 前建議保存：

```sh
mkdir -p /tmp/cpld-security-debug
# cpldtool dump > /tmp/cpld-security-debug/cpld-dump-before.txt
# flashrom --wp-status > /tmp/cpld-security-debug/flash-wp-before.txt 2>&1
journalctl -b --no-pager > /tmp/cpld-security-debug/journal-before.txt
```

注意：write protect 相關訊號不建議由一般 debug script 自動解除；需經過授權流程與測試窗口。

#### 6.12 CPLD / FPGA firmware update 與 recovery

CPLD / FPGA image 更新風險通常高於一般 service 更新，因為失敗可能造成 power sequence、reset、flash mux、debug path 都不可用。需建立更新前檢查、更新中斷處理與 recovery path。

| 項目 | 建議定義 |
| --- | --- |
| Image format | jed / svf / bit / bin / vendor package / signed package |
| Version source | register、image manifest、build id、git commit |
| Update path | JTAG、I2C bridge、SPI config flash、BMC driver、factory fixture |
| Power requirement | host off、standby rail stable、slot power off、AC stable |
| Write protect | field mode / manufacturing mode / jumper / signature |
| Verification | readback checksum、version register、functional test |
| Rollback | dual image、golden image、JTAG recovery、manual reflash |
| Interruption test | AC loss、BMC reset、tool timeout、image mismatch |

更新流程建議：

1. 確認目前 image version、board revision、CPLD device ID。
2. 保存 CPLD register dump 與 BMC / host power state。
3. 確認 host power state 符合更新要求，例如 host off。
4. 驗證 package signature / checksum / board match。
5. 解除必要 write protect，並記錄授權來源。
6. 寫入 image。
7. verify / readback。
8. reset CPLD 或 AC cycle，依平台要求執行。
9. 讀回 version register，執行 power sequence / reset / LED / presence smoke test。
10. 收斂 log，回填本章版本表。

#### 6.13 Linux / OpenBMC 整合模式

CPLD / FPGA 可以透過 kernel driver、userspace daemon 或 OpenBMC service 整合。建議依功能拆分，不要讓單一 debug tool 長期負責所有平台狀態。

| 功能 | 建議整合方式 | 對外狀態 |
| --- | --- | --- |
| version / board ID | sysfs / D-Bus inventory property | Redfish / Inventory |
| presence | GPIO / CPLD service / Entity Manager | Inventory Present |
| fault latch | platform fault service | SEL / Redfish EventLog |
| power sequence state | power control service | Chassis / Host State |
| LED | phosphor-led-manager 或平台 LED service | Redfish IndicatorLED |
| write protect | security / update service | update precheck / audit log |
| CPLD update | software manager / vendor updater | Software inventory |

D-Bus 對齊建議：

```text
CPLD version register
    → Inventory property / Software version object
CPLD presence bit
    → Inventory Present property
CPLD fault latch
    → Logging entry / EventLog / Functional=false
CPLD power state
    → xyz.openbmc_project.State.Host / Chassis
CPLD LED control
    → LED group / IndicatorLED
```

常用檢查：

```sh
busctl tree xyz.openbmc_project.Inventory.Manager 2>/dev/null
busctl tree xyz.openbmc_project.State.Host 2>/dev/null
busctl tree xyz.openbmc_project.State.Chassis 2>/dev/null
busctl tree xyz.openbmc_project.Logging 2>/dev/null
systemctl --failed
journalctl -b --no-pager | grep -Ei 'cpld|fpga|power|fault|led|presence|wp|version' | tail -300
```

#### 6.14 DTS、driver 與平台工具欄位

若 CPLD 掛在 I2C，可用 DTS 描述 basic device node；若由 userspace tool 或 custom daemon 使用，也需文件化 bus、address、compatible 與 access method。

##### 6.14.1 I2C CPLD DTS 範本

```dts
&i2c8 {
    status = "okay";
    clock-frequency = <400000>;

    cpld@30 {
        compatible = "vendor,platform-cpld";
        reg = <0x30>;
        reset-gpios = <&gpio0 12 GPIO_ACTIVE_LOW>;
        interrupt-parent = <&gpio0>;
        interrupts = <13 IRQ_TYPE_LEVEL_LOW>;
    };
};
```

檢查重點：

- `reg` 是 7-bit address，不是 8-bit shifted address。
- interrupt pin 若接到 CPLD fault / event，需定義 trigger type 與 clear sequence。
- reset-gpios 若會重置 power sequence controller，使用前需確認 host 影響範圍。
- 若 CPLD register map 由 userspace 使用，仍需記錄工具版本與 register map 版本。

##### 6.14.2 FPGA Manager / configuration 狀態

若平台由 Linux FPGA manager 或 vendor tool 載入 FPGA bitstream，需記錄：

| 欄位 | 說明 |
| --- | --- |
| Config source | SPI config flash、BMC load、JTAG、host load |
| Done / init pins | `DONE`、`INIT_B`、`PROGRAM_B`、status register |
| Bitstream version | register、manifest、build id |
| Load timing | AC on、BMC boot、host power on 前 / 後 |
| Failure policy | bitstream fail 時是否禁止 host power on |
| Recovery | golden bitstream、JTAG、factory fixture |

#### 6.15 Target 端 log 收集

以下提供 CPLD / FPGA / board glue logic 共用 log 套件。平台工具名稱需依實際專案調整。

```sh
mkdir -p /tmp/cpld-debug
cat /etc/os-release > /tmp/cpld-debug/os-release.txt
uname -a > /tmp/cpld-debug/uname.txt
cat /proc/cmdline > /tmp/cpld-debug/proc-cmdline.txt
dmesg -T > /tmp/cpld-debug/dmesg.txt
journalctl -b --no-pager > /tmp/cpld-debug/journal.txt
journalctl -b -1 --no-pager > /tmp/cpld-debug/journal-previous.txt 2>&1 || true
systemctl --failed > /tmp/cpld-debug/systemctl-failed.txt 2>&1

# I2C / register access path
i2cdetect -l > /tmp/cpld-debug/i2cdetect-l.txt 2>&1 || true
ls -l /sys/bus/i2c/devices > /tmp/cpld-debug/sys-bus-i2c-devices.txt 2>&1 || true
find /sys/bus/i2c/devices -maxdepth 3 -type l -o -type f > /tmp/cpld-debug/i2c-tree.txt 2>&1 || true

# GPIO / pinctrl / clock
mount | grep debugfs || mount -t debugfs debugfs /sys/kernel/debug 2>/dev/null || true
cat /sys/kernel/debug/gpio > /tmp/cpld-debug/debug-gpio.txt 2>&1 || true
cat /sys/kernel/debug/clk/clk_summary > /tmp/cpld-debug/clk-summary.txt 2>&1 || true
find /sys/kernel/debug/pinctrl -maxdepth 3 -type f -print > /tmp/cpld-debug/pinctrl-files.txt 2>&1 || true

# OpenBMC state
busctl tree xyz.openbmc_project.State.Host > /tmp/cpld-debug/dbus-host-state.txt 2>&1 || true
busctl tree xyz.openbmc_project.State.Chassis > /tmp/cpld-debug/dbus-chassis-state.txt 2>&1 || true
busctl tree xyz.openbmc_project.Inventory.Manager > /tmp/cpld-debug/dbus-inventory.txt 2>&1 || true
busctl tree xyz.openbmc_project.Logging > /tmp/cpld-debug/dbus-logging.txt 2>&1 || true
busctl tree xyz.openbmc_project.Software.Version > /tmp/cpld-debug/dbus-software-version.txt 2>&1 || true

# 平台工具，請依專案替換
# cpldtool version > /tmp/cpld-debug/cpld-version.txt 2>&1 || true
# cpldtool dump > /tmp/cpld-debug/cpld-dump.txt 2>&1 || true
# cpldtool fault-status > /tmp/cpld-debug/cpld-fault-status.txt 2>&1 || true
# cpldtool power-state > /tmp/cpld-debug/cpld-power-state.txt 2>&1 || true
# fpgautil status > /tmp/cpld-debug/fpga-status.txt 2>&1 || true

tar czf /tmp/cpld-debug-$(date +%Y%m%d-%H%M%S).tar.gz -C /tmp cpld-debug
```

#### 6.16 常見問題與排查入口

| 現象 | 可能方向 | 第一輪檢查 |
| --- | --- | --- |
| CPLD I2C address 掃不到 | bus / mux / address / power / reset 問題 | `i2cdetect -l`、scope、rail、reset |
| CPLD version register 讀值錯 | bus width、endianness、bank/page、image mismatch | register map、tool version、LA decode |
| fault latch 一直回來 | raw fault 未解除、clear 順序錯、硬體真的異常 | raw status、PMBus status、scope |
| fault latch 清掉後無 log | clear 前未保存、read-clear register 被輪詢 | journal、工具流程、register 語意 |
| Host power on timeout | power sequence state machine 停在某 step | CPLD state、PGOOD waveform、fault latch |
| BMC reboot 導致 host 掉電 | CPLD / GPIO default 不安全、BMC_READY 影響 power | waveform、CPLD default、power daemon log |
| LED 狀態與 Redfish 不符 | LED owner 不一致、CPLD autonomous pattern、polarity 錯 | LED register、phosphor-led-manager、scope |
| Presence 反相 | active level 錯、raw/debounce 混淆、connector ID 錯 | raw bit、debounced bit、entity config |
| Board ID / SKU 錯 | strap resistor、CPLD decode、BOM 不符 | schematic、raw ID bit、inventory probe |
| BIOS update 失敗 | WP 未解除、flash mux 未切、host owner 衝突 | WP bit、flashrom log、CPLD mux state |
| CPLD update 後無法開機 | image 不符、power sequence regression、default 改變 | JTAG recovery、version、waveform |
| Reset pulse 太短 / 太長 | CPLD pulse width 設定或 clock 不符 | LA、register、CPLD image版本 |
| Watchdog reset target 錯 | CPLD reset routing / policy 錯 | reset reason、watchdog設定、scope |
| OpenBMC inventory 不更新 | service 未重讀 CPLD state、Probe 條件錯 | Entity Manager journal、D-Bus tree |

#### 6.17 Bring-up 建議流程

1. 建立 CPLD / FPGA inventory：料號、位置、版本 register、access bus、update path、owner。
2. 取得最新版 register map，標示每個 bit 的 R/W、default、active level、clear rule、side effect。
3. 確認 access path：I2C / LPC / MMIO / UART / JTAG，並保存 bus map。
4. 先讀 ID / version / scratch register，確認工具與 register map 對齊。
5. 驗證 raw input：presence、PGOOD、fault、button、strap，以 scope / LA 與 register 同步比對。
6. 驗證 control output：LED、mux select、safe GPIO、非破壞性 control bit。
7. 驗證 power sequence：host on/off/cycle、timeout、fault injection、AC restore。
8. 驗證 reset mux：BMC reset、host reset、watchdog reset、button reset、CPLD reset。
9. 驗證 fault latch / clear rule：先保存 log，再 clear，再確認 raw fault 狀態。
10. 驗證 write protect / flash mux：在授權流程中測試 BIOS / CPLD / BMC update 前置條件。
11. 導入 OpenBMC service：inventory、state、fault、LED、power、software version。
12. 驗證 Redfish / IPMI / SEL：對外狀態與 CPLD raw / latch / state 一致。
13. 做 regression：AC cycle、BMC reboot、host power loop、service restart、update interruption、factory reset。
14. 回填本章表格、版本、log、owner 與已知限制。

#### 6.18 當前平台 CPLD / FPGA 實測表

##### 6.18.1 Device 與存取資訊

| 項目 | 實測值 | 來源 | Owner | 狀態 |
| --- | --- | --- | --- | --- |
| CPLD / FPGA device name | [待填] | schematic / BOM | HW | [待確認] |
| Vendor / part number | [待填] | BOM | HW | [待確認] |
| Board location | [待填] | layout | HW | [待確認] |
| Image version | [待填] | version register | CPLD/BMC | [待確認] |
| Register map version | [待填] | design doc | CPLD | [待確認] |
| Access bus | [待填] | schematic / runtime | BMC | [待確認] |
| Address / port / BAR | [待填] | bus map | BMC | [待確認] |
| Update method | [待填] | factory / field process | Manufacturing/BMC | [待確認] |
| Recovery method | [待填] | platform plan | HW/BMC | [待確認] |
| Security mode | [待填] | security policy | Security | [待確認] |

##### 6.18.2 Register 實測表

| Register | Bit | Name | Default | Raw / latch / control | 實測值 | Clear rule | Owner | 備註 |
| --- | ---: | --- | --- | --- | --- | --- | --- | --- |
| [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] |
| [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] |

##### 6.18.3 Power / reset / fault 驗證表

| 測試 | CPLD state | 相關 register | Waveform / log | 預期 | 實測 | 結論 |
| --- | --- | --- | --- | --- | --- | --- |
| AC cycle | [待填] | [待填] | [待填] | safe default | [待填] | [待確認] |
| BMC reboot | [待填] | [待填] | [待填] | host 不受非預期影響 | [待填] | [待確認] |
| Host power on | [待填] | [待填] | [待填] | state machine 完成 | [待填] | [待確認] |
| Host power off | [待填] | [待填] | [待填] | rails 依序關閉 | [待填] | [待確認] |
| Watchdog reset | [待填] | [待填] | [待填] | reset target 正確 | [待填] | [待確認] |
| Fault injection | [待填] | [待填] | [待填] | latch / event 正確 | [待填] | [待確認] |
| CPLD update | [待填] | [待填] | [待填] | version 更新且功能正常 | [待填] | [待確認] |

#### 6.19 驗收 Checklist

- [ ] CPLD / FPGA 料號、位置、版本 register、register map version 已記錄。
- [ ] access bus、address、register width、endianness、bank/page、auto-increment 規則已確認。
- [ ] 每個 register bit 已標示 R/W、default、active level、raw / latch / control / derived 語意。
- [ ] W1C、read-clear、pulse、sticky、shadow 類 bit 已標示副作用與使用限制。
- [ ] Power sequence state machine 已列出 state、entry condition、output、wait signal、timeout、failure latch。
- [ ] Reset source、reset target、pulse width、watchdog reset 範圍已量測。
- [ ] Fault latch 與 raw status 分開記錄；clear 前保存 log 的流程已建立。
- [ ] Presence、Board ID、SKU ID、manufacturing mode、security strap 與 inventory / Probe 對齊。
- [ ] LED / button / front panel 的 owner、pattern、debounce、Redfish / IPMI 對應已驗證。
- [ ] BIOS / BMC / CPLD flash WP 與 flash mux default、安全流程、更新授權已確認。
- [ ] CPLD / FPGA update flow、verify、rollback / recovery path 已測試。
- [ ] BMC reboot、AC cycle、host reset、watchdog reset 不會造成非預期 power / reset 切換，或已有明確產品政策。
- [ ] OpenBMC D-Bus / Redfish / IPMI / SEL 對外狀態與 CPLD register / waveform 一致。
- [ ] cpld-debug log 收集腳本可執行，並納入 bring-up / regression 流程。
- [ ] 測試紀錄包含 CPLD version、BMC image version、BIOS version、CPLD dump、journal、waveform、owner、已知限制。

#### 6.20 本章參考資料

- Linux kernel documentation - GPIO Mappings: https://docs.kernel.org/driver-api/gpio/board.html
- Linux kernel documentation - Regmap API: https://docs.kernel.org/driver-api/regmap.html
- Linux kernel documentation - Linux I2C Sysfs: https://docs.kernel.org/i2c/i2c-sysfs.html
- Linux kernel documentation - FPGA Manager Framework: https://docs.kernel.org/driver-api/fpga/fpga-mgr.html
- OpenBMC entity-manager: https://github.com/openbmc/entity-manager
- OpenBMC phosphor-led-manager: https://github.com/openbmc/phosphor-led-manager
- OpenBMC phosphor-state-manager: https://github.com/openbmc/phosphor-state-manager
- OpenBMC phosphor-logging: https://github.com/openbmc/phosphor-logging

### 7. Build System 與 BSP 結構

Yocto / OpenEmbedded 核心觀念：recipe 描述套件如何取得、patch、編譯、安裝與打包；layer 保存不同來源與用途的 metadata；machine 定義硬體；distro 定義政策；image 定義最終 rootfs 組成。

建議目錄地圖：

| 區域          | 內容                  | 常改檔案                            |
| ------------- | --------------------- | ----------------------------------- |
| meta-platform | machine、DTS、recipes | conf/machine/*.conf、recipes-kernel |
| meta-common   | 共用功能              | packagegroup、systemd unit          |
| u-boot        | bootloader            | defconfig、board config、env        |
| linux         | kernel                | defconfig、fragments、dts           |
| openbmc apps  | user space services   | JSON config、service override       |


### 7.1 Yocto 簡介

Yocto Project 是一個開源協作專案，用來幫助開發者建立針對特定硬體架構（target boards）的**自訂 Linux 作業系統**。在 BMC porting 情境中，Yocto 的價值是把 kernel、bootloader、rootfs、package、SDK、license 資訊與平台差異，放進一套可重現的建構流程中管理。

它處理了嵌入式 Linux 開發常見的幾個問題：硬體架構碎片化、軟體元件相依複雜、建構流程難以重現。Yocto 提供一套標準化工具鏈，讓開發者可以：

- 從原始碼建構 Linux 映像
- 精確控制要放入哪些套件
- 管理套件之間的相依關係
- 支援跨平台編譯，例如 ARM、x86、MIPS、RISC-V 等
- 長期維護產品生命週期
- 輸出 rootfs、kernel、bootloader、package feed、SDK 與 license / SBOM 相關資料

Yocto 由多個核心元件所組成，為了方便理解，可以用**人體**來類比：

| 名稱 | 解釋 | 類比 |
|---|---|---|
| **Poky** | Yocto 的參考發行版，整合 BitBake、OpenEmbedded-Core 與參考 metadata。 | 完整的人體樣本 |
| **BitBake** | 負責解析 metadata 並執行建構流程的任務引擎。 | 大腦（發號施令） |
| **OpenEmbedded** | 提供建構系統的核心架構與 metadata，例如 recipes、classes、configuration。 | 身體的骨架與器官 |

補充說明：

- Poky 是 Yocto Project 提供的「**參考用完整組合**」，它是一個可以實際建出映像的參考組合，但**不是唯一選項**。可以拿 Poky 來改，也可以依專案需求自行組合 BitBake、OE-Core 與各 layers。
- 近年的 Yocto 文件中，Poky 的角色更偏向參考與測試目標；新的工作流程也可使用個別 clone 的 `bitbake`、`openembedded-core`、`meta-yocto`，或使用 `bitbake-setup` 建立建構環境。`poky` 作為 DISTRO 設定仍然存在。
- OpenBMC 是另一個完整的「人體」，它**使用** Yocto / OpenEmbedded / BitBake 工具來建構 BMC 映像，但不要把 OpenBMC 和 Poky 混在一起看。

#### 7.1.1 Yocto Build Flow（簡化流程）

![](https://docs.yoctoproject.org/2.1/yocto-project-qs/figures/yocto-environment.png)

常見的 Yocto 架構圖資訊量很大，初學時可先用「從左到右」的流程理解：

1. **準備階段（Prepare）**
   - BitBake 開始運作，讀取四類設定：
     - **User Configuration**：例如 `build/conf/local.conf`
     - **Metadata**：各 layer 的 recipes、classes、conf
     - **Machine Configuration**：硬體設定，例如 `qemux86-64`、`ast2600-evb`、專案 machine
     - **Policy Configuration**：發行版政策，例如 `poky`、OpenBMC distro 設定
   - 這些設定決定「要建構什麼」以及「如何建構」。

2. **擷取與打補丁（Fetch / Patch）**
   - BitBake 根據 `SRC_URI` 變數，從 Git、HTTP、local file 或 mirror 取得原始碼，對應 task 通常是 `do_fetch`。
   - 接著將 patches 套用到原始碼上，對應 task 通常是 `do_patch`。

3. **配置、編譯與安裝（Configure / Compile / Install）**
   - 執行建構前設定，對應 `do_configure`，例如 Autotools、CMake、Meson 的設定階段。
   - 開始編譯，對應 `do_compile`。
   - 將編譯好的檔案安裝到暫存目的地，對應 `do_install`。
   - 不同 recipe 之間可能存在 build-time dependency，因此 BitBake 會依任務依賴圖排程。

4. **部署到 Sysroot 與打包（Populate Sysroot / Package）**
   - 將可供其他 recipe 使用的 headers、libraries、pkg-config files 等部署到 sysroot，對應 `do_populate_sysroot`。
   - 將安裝結果拆成多個 package，對應 `do_package`。

5. **產生安裝套件（Write RPM / DEB / IPK）**
   - 將 package 轉成目標平台可使用的格式，例如 RPM、DEB、IPK。
   - BMC 專案常見產出位置包含 `tmp/deploy/rpm/`、`tmp/deploy/ipk/` 或依 distro 設定而定的 package deploy 目錄。

6. **QA 檢查（QA Check）**
   - Yocto 在建構過程中會執行多種 QA 檢查，例如 metadata、runtime dependency、license、installed-vs-shipped、rpath、host contamination 等。
   - QA issue 不一定每次都會讓 build fail，實際行為會受 `WARN_QA`、`ERROR_QA`、distro policy 影響。

7. **套件供給（Package Feeds）**
   - 建出的 package 可作為 package feed，放在 `tmp/deploy/` 底下。
   - 若產品支援線上套件更新，可進一步規劃 package feed server；若是 BMC 韌體，多數情境仍以 image update 為主。

8. **產生映像與 SDK（Image / SDK Generation）**
   - BitBake 最後會依 image recipe 產生 rootfs 與可燒錄映像，例如 ext4、wic、ubi、mtd tar、squashfs 等。
   - 也可以產生 SDK 或 eSDK，供應用程式開發者使用。

#### 7.1.2 Poky

Poky 是 Yocto 的**參考發行版**（reference distribution）。白話文來說，它是一組「可以拿來建出參考 Linux 系統」的建構工具與 metadata 組合。它提供：

- OpenEmbedded 建構系統相關元件，例如 BitBake 與 OpenEmbedded-Core
- 一組參考 metadata，幫助開發者建立自訂發行版
- 參考 machine、image、distro 設定，用於學習、測試與驗證建構環境

傳統 Poky repository 的根目錄常見結構如下：

```text
poky/
├── bitbake/                     # BitBake 主程式（Python）
├── build/                       # 編譯輸出目錄（執行 oe-init-build-env 後產生）
├── contrib/                     # 貢獻者工具
├── meta/                        # OpenEmbedded-Core 的 metadata（recipes、classes、機器配置）
├── meta-poky/                   # Poky 參考發行版的額外 metadata
├── meta-selftest/               # 自我測試用的 recipes 與 append 檔
├── meta-skeleton/               # BSP 和 Kernel 開發的 recipes 範本
├── meta-yocto-bsp/              # Yocto 計畫的參考 BSP metadata
├── oe-init-build-env            # 設定編譯環境的腳本
└── scripts/                     # 輔助工具腳本
```

`build/` 資料夾是在執行 `source oe-init-build-env` 後建立的，裡面包含 `conf/`、暫存資料、sstate-cache，以及最終輸出的映像檔。

需要注意的是，Poky repository 的使用方式會隨 Yocto 版本演進而調整。若專案採用新版本 Yocto，建議先查該版本的官方文件，確認目前建議的環境建立方式。

#### 7.1.3 OpenEmbedded

OpenEmbedded 是一套**建構框架**，可視為前面類比中的「身體骨架與器官」。它主要由下列部分組成：

- **OE-Core（OpenEmbedded-Core）**：核心 metadata，包含基礎 recipes、classes 與 configuration。
- **BitBake**：建構引擎，負責排程與執行任務。
- **meta-openembedded**：社群維護的額外 recipes 集合，常見的 `meta-oe`、`meta-python`、`meta-networking` 等都在這個體系內。

OE-Core 是許多 OpenEmbedded 衍生系統共用的「標準骨架」。Yocto Project 與 OpenBMC 都大量使用 OE-Core 的模型。

常見檔案類型：

- **Recipe（`.bb`）**：描述如何下載、設定、編譯、安裝、打包某個軟體套件。
- **Append（`.bbappend`）**：在不直接修改原 recipe 的前提下，追加 patch、設定或安裝內容。
- **Class（`.bbclass`）**：定義共用建構邏輯，例如 `cmake.bbclass`、`meson.bbclass`、`systemd.bbclass`。
- **Configuration（`.conf`）**：定義 machine、distro、layer、local build policy 等設定。

#### 7.1.4 BitBake

BitBake 是一個**任務執行引擎**（task execution engine），主要用來解析與執行 Yocto / OpenEmbedded 專案中的 recipes。它的概念與 GNU Make 有些相似，但更適合處理大量套件、交叉編譯、任務依賴、快取與平行排程。

BitBake 的運作流程大致如下：

1. **解析基礎設定**：讀取 `bblayers.conf`、各 layer 的 `layer.conf`、`bitbake.conf`、`local.conf` 等。
2. **建立 BBFILES 清單**：根據 `BBFILES` 變數，找到所有 `.bb` 與 `.bbappend` 檔案。
3. **解析 Recipes 與 Classes**：將 metadata 載入並展開變數、繼承 class、套用 override。
4. **產生任務依賴圖**：根據 `DEPENDS`、`RDEPENDS`、task dependency 與 class logic，建立任務順序。
5. **執行任務**：依依賴順序平行執行 `do_fetch`、`do_unpack`、`do_patch`、`do_configure`、`do_compile`、`do_install`、`do_package`、`do_rootfs` 等任務。
6. **使用 cache 與 sstate**：若任務輸入未改變，可重用 shared state，降低重建時間。

使用 BitBake 的好處：

- 可以組出完整嵌入式 Linux 發行版
- 透過依賴圖管理套件與任務順序
- 可平行處理多個 recipe 與 task，加快建置速度
- 可透過 sstate-cache 改善重複建構時間
- 可把 build-time dependency 與 runtime dependency 分開描述

常用指令：

```bash
# 建立 image
bitbake core-image-minimal

# OpenBMC 常見 image target
bitbake obmc-phosphor-image

# 只跑特定 recipe 的某個 task
bitbake -c compile <recipe>
bitbake -c clean <recipe>
bitbake -c cleansstate <recipe>

# 查 recipe 使用的變數展開結果
bitbake -e <recipe> | less

# 查 layers
bitbake-layers show-layers
bitbake-layers show-recipes
bitbake-layers show-appends

# 產生 dependency graph
bitbake -g <target>
```

#### 7.1.5 Layer Model

Layer Model 是 Yocto 用來管理套件與客製化內容的核心機制，設計目標是**同時支援協作與客製化**。

白話文來說，Layer Model 就是**把肉一層一層疊起來**的起司蛋糕概念：

- **Layer 就是一層起司**：每一層包含一組相關 recipes 與設定。BSP、GUI、中介軟體、應用服務、公司共用政策都可以分開放。
- **重複 recipe 會依規則處理**：如果同一個 recipe 名稱出現在多個 layer 中，BitBake 會依 layer priority、version、`PREFERRED_VERSION` 等規則選擇。
- **`.bbappend` 可追加既有 recipe**：不修改原 recipe，也能增加 patch、service、config 或安裝檔案。
- **最終結果是疊合後的系統**：所有 layer 疊加後，BitBake 依優先權、override 與設定產出完整系統。
- **Layer 可以重複使用**：同一個 BSP layer、feature layer 或公司共用 layer 可在多個專案使用。
- **分層是為了降耦合**：更換硬體時替換 BSP layer，新增功能時加入 feature layer，量產政策放在 distro / product layer。

常見 layer 分層方式：

**第一種：由大到小、由廣泛到精細**

- 底層：OE-Core / 基礎系統
- 中層：BSP（板級支援套件）、SoC vendor layer、中介軟體
- 上層：發行版政策、產品設定、應用程式、OEM 客製化

**第二種：企業內部常見分層**

- **Root Layer**：由硬體製造商、SoC vendor 或 upstream 專案提供的基礎 layer，例如 OpenBMC 常用 layer。
- **Model Layer**：針對特定平台、板子、SKU 所設計的 layer。
- **Recipe Layer**：針對特定工具、服務、OEM 套件或公司共用元件所提供的 layer。

OpenBMC 常見 layer 類型：

```text
openbmc/
├── meta/                         # OE-Core / Yocto 相關基礎 layer
├── meta-openembedded/            # 社群 recipes，例如 meta-oe、meta-python、meta-networking
├── meta-phosphor/                # OpenBMC 核心服務與共用設定
├── meta-aspeed/                  # ASPEED SoC BSP
├── meta-nuvoton/                 # Nuvoton SoC BSP
├── meta-ibm/、meta-facebook/等    # vendor / platform layer
└── build/                        # 建構輸出
```

實務建議：

- 不要直接改 upstream layer，優先用專案 layer + `.bbappend` 管理差異。
- 平台相關設定放 machine layer；產品政策放 distro 或 product layer；應用程式放 application layer。
- Layer priority 不宜濫用，否則後續很難追蹤 recipe 來源。
- 每個 layer 應清楚定義相依 layer，寫在 `conf/layer.conf` 的 `LAYERDEPENDS`。

#### 7.1.6 OpenBMC 和 Yocto 的關係

重要澄清：OpenBMC **不是** Yocto 的競爭者，而是 Yocto 的**使用者**。

**Yocto Project** 是一個框架，用來建立各式各樣的嵌入式 Linux 系統。它提供工具、metadata 與建構基礎設施。

**OpenBMC** 則是一個專門為伺服器 BMC（Baseboard Management Controller）設計的韌體堆疊。它包含硬體監控、感測器管理、遠端電源控制、IPMI / Redfish 支援、軟體更新、事件紀錄等功能。

OpenBMC 本身使用 Yocto 工具來建構。OpenBMC 借用 BitBake、layer model、OpenEmbedded-Core 與大量 metadata，再疊加 BMC 專屬服務與平台設定。因此：

- Yocto / OpenEmbedded / BitBake：提供建構框架。
- OpenBMC：提供 BMC runtime 架構與服務集合。
- OpenBMC image：是 Yocto build system 建出的 BMC 韌體映像。

OpenBMC 常見建構流程：

```bash
# 進入 OpenBMC source tree
cd openbmc

# 設定 machine；不同專案 machine 名稱不同
. setup <machine_name>

# 開始建構 BMC image
bitbake obmc-phosphor-image

# 產出通常位於
ls tmp/deploy/images/<machine_name>/
```

#### 7.1.7 BMC Porting 時 Yocto 需要優先確認的檔案

| 項目 | 常見位置 | 用途 | Porting 注意事項 |
|---|---|---|---|
| Machine conf | `conf/machine/<machine>.conf` | 定義 MACHINE、SoC、kernel、UBoot、image type | 需對齊實際 board、flash type、SoC BSP |
| Layer conf | `conf/layer.conf` | 定義 BBFILES、LAYERDEPENDS、layer priority | 確認相依 layer 與 priority 是否合理 |
| Kernel recipe / bbappend | `recipes-kernel/linux/` | 指定 kernel source、defconfig、DTS、patch | DTS、driver patch、config fragment 是 bring-up 重點 |
| U-Boot recipe / bbappend | `recipes-bsp/u-boot/` | 指定 bootloader source、defconfig、env、patch | flash layout、bootcmd、secure boot、recovery 需同步 |
| Image recipe | `recipes-phosphor/images/` 或 product layer | 定義 rootfs 內容 | 確認需要的 service、tool、debug package 是否進 image |
| Packagegroup | `recipes-*/packagegroups/` | 集中管理套件集合 | 適合控管 feature 開關與產品差異 |
| Systemd service | `recipes-*/<pkg>/files/*.service` | 定義 daemon 啟動方式 | 需檢查 dependency、restart policy、boot time impact |
| Entity Manager / Sensor config | `recipes-phosphor/configuration/` 或平台 layer | 定義 inventory、sensor、FRU、presence | 需對齊 schematic、I2C bus map、Redfish/IPMI mapping |

#### 7.1.8 Yocto / OpenBMC 常見排查入口

```bash
# 確認目前 machine / distro / image 相關變數
bitbake -e obmc-phosphor-image | grep -E "^(MACHINE|DISTRO|IMAGE_FSTYPES|PREFERRED_PROVIDER|BBLAYERS)="

# 查某個 recipe 實際來源
bitbake-layers show-recipes <recipe>
bitbake-layers show-appends | grep <recipe>

# 進入 recipe 開發流程
bitbake -c devshell <recipe>

# 清掉某個 recipe 的 sstate 後重建
bitbake -c cleansstate <recipe>
bitbake <recipe>

# 只重跑 image rootfs
bitbake -c rootfs obmc-phosphor-image

# 找 deploy image
ls tmp/deploy/images/${MACHINE}/

# 找 package 輸出
find tmp/deploy -maxdepth 3 -type f | grep -E "\.(rpm|ipk|deb)$" | head

# 找 recipe workdir
bitbake -e <recipe> | grep '^WORKDIR='
```

#### 7.1.9 小結

Yocto 可以理解成「可重現的嵌入式 Linux 建構框架」，BitBake 是任務引擎，OpenEmbedded 提供 metadata 骨架，Poky 是參考發行版，OpenBMC 則是在這套框架上建出的 BMC 韌體專案。對 BMC porting 來說，最重要的是把 machine、layer、kernel、U-Boot、image、sensor / inventory config、firmware update layout 這幾塊關係釐清，後續 debug 才能有效率地把問題定位到 BSP、kernel、Device Tree、user space service 或平台設定。


### 7.2 常用變數、目錄結構與 BitBake 建構流程

這章整理 Yocto 的「廚房」：目錄怎麼放、設定檔怎麼寫、常用變數代表什麼、BitBake 如何解析 metadata 並執行 tasks。熟悉這些內容後，排查 BMC image 建構失敗、recipe 沒有被套用、layer 優先權不如預期、sstate 沒有命中等問題會更有效率。

#### 7.2.1 目錄結構

執行 `source oe-init-build-env` 後，常見流程會建立或切換到 `build/` 目錄。`build/` 是整個建構過程的工作核心，包含設定檔、下載資料、快取、中間產物與最終輸出。

```text
build/
├── bitbake-cookerdaemon.log   # BitBake cooker daemon 的執行日誌
├── cache/                     # BitBake 解析快取，加速下次解析
├── conf/                      # 設定檔，例如 local.conf、bblayers.conf
├── downloads/                 # 下載的原始碼與 SCM mirror，通常由 DL_DIR 指定
├── sstate-cache/              # Shared State Cache，通常由 SSTATE_DIR 指定
└── tmp/                       # 建構中間產物與最終輸出，通常由 TMPDIR 指定
    ├── work/                  # 各 recipe 的工作目錄，含 source、build output、log
    ├── deploy/                # image、SDK、套件等輸出
    ├── sysroots-components/   # sysroot 元件資料
    ├── stamps/                # task stamp，用於判斷 task 是否需要重跑
    └── log/                   # build log 與部分統計資料
```

各目錄用途：

- `conf/`：最重要的設定檔所在地，包含 `local.conf` 與 `bblayers.conf`。
- `downloads/`：`do_fetch` 下載的 tarball、Git mirror 或其他 source cache 會放在這裡。此目錄可跨專案共用，降低重複下載成本。
- `sstate-cache/`：Shared State Cache，保存可重用的 task 輸出。若 task 的輸入與 signature 沒有變化，BitBake 可從 sstate 還原結果，減少重建時間。
- `tmp/`：建構過程的主要工作區。`tmp/work/` 是各 recipe 的獨立工作空間，`tmp/deploy/` 是 image、package、SDK 等輸出位置。
- `tmp/work/<machine或arch>/<recipe>/<version>/`：常見 recipe workdir，可找到 `temp/log.do_*`、`image/`、`package/`、`packages-split/`、source tree 等資料。
- `tmp/deploy/images/<machine>/`：BMC image、kernel、DTB、U-Boot、manifest、tarball 或 flash image 的常見輸出位置。

實務建議：

- `downloads/` 與 `sstate-cache/` 可透過共用目錄、符號連結或 NFS 提供給多個開發者或 CI 使用，節省網路頻寬與建構時間。
- CI 環境若共用 sstate，需同時控管 Yocto branch、layer revisions、host distro、compiler 版本與 `MACHINE` / `DISTRO`，避免 cache 命中行為難以追蹤。
- 若懷疑 sstate 造成舊檔被重用，先針對單一 recipe 使用 `bitbake -c cleansstate <recipe>`，不建議一開始就刪整個 `sstate-cache/`。

#### 7.2.2 設定檔說明

##### `local.conf`：個人建構設定

`local.conf` 是使用者自訂建構選項的主要設定檔，通常位於 `build/conf/local.conf`。它適合放開發者本機或 CI job 層級的設定，例如 target machine、下載目錄、sstate 目錄、package format、平行建構參數等。

| 項目 | 說明 | 變數 | 常見預設或範例 |
|---|---|---|---|
| 目標機器 | 要編譯給哪塊板子或 QEMU target | `MACHINE` | `qemux86-64`、`ast2600-evb`、`<project-machine>` |
| 下載目錄 | source archive / Git mirror 位置 | `DL_DIR` | `${TOPDIR}/downloads` |
| 快取目錄 | Shared State Cache 位置 | `SSTATE_DIR` | `${TOPDIR}/sstate-cache` |
| 輸出目錄 | 建構中間產物與 deploy 資料 | `TMPDIR` | `${TOPDIR}/tmp` |
| 發行版政策 | distro policy，例如 libc、init、feature set | `DISTRO` | `poky`、OpenBMC distro 設定 |
| 套件格式 | 產生 RPM、DEB 或 IPK | `PACKAGE_CLASSES` | `package_rpm`、`package_ipk` |
| SDK 架構 | SDK 執行端架構 | `SDKMACHINE` | `x86_64`、`i686` |
| 映像功能 | debug-tweaks、ssh-server 等 image feature | `EXTRA_IMAGE_FEATURES` | 依 distro / image 而定 |
| BitBake 任務數 | BitBake 同時排程多少 task | `BB_NUMBER_THREADS` | 可依 CPU 數與 RAM 調整 |
| 編譯核心數 | 傳給 make / ninja 等工具的平行度 | `PARALLEL_MAKE` | 例如 `-j 16` |

常見設定：

```bitbake
MACHINE = "<project-machine>"
DISTRO = "openbmc-phosphor"
PACKAGE_CLASSES = "package_ipk"

DL_DIR = "/data/yocto/downloads"
SSTATE_DIR = "/data/yocto/sstate-cache"
TMPDIR = "${TOPDIR}/tmp"

BB_NUMBER_THREADS = "16"
PARALLEL_MAKE = "-j 16"
```

建議：

- `BB_NUMBER_THREADS` 與 `PARALLEL_MAKE` 不一定越大越好。若主機 RAM 或 I/O 不足，過高平行度可能造成 swap、I/O wait 或 random build failure。
- BMC 專案常見瓶頸包含 C++ service 編譯、Rust package、node / web UI、kernel build 與 image rootfs；可透過 `buildstats` 或 CI log 觀察實際耗時。
- 若多人共用 `DL_DIR` / `SSTATE_DIR`，建議放在 `site.conf` 或 CI template，而不是每個人的 `local.conf` 各自維護。

##### `bblayers.conf`：決定載入哪些 layers

`bblayers.conf` 定義 BitBake 要載入哪些 layers，通常位於 `build/conf/bblayers.conf`。BitBake 解析 base configuration 時會讀取此檔，並依此找到每個 layer 的 `conf/layer.conf`。

```bitbake
POKY_BBLAYERS_CONF_VERSION = "2"

BBPATH = "${TOPDIR}"
BBFILES ?= ""

BBLAYERS ?= " \
  /home/yocto/poky/meta \
  /home/yocto/poky/meta-poky \
  /home/yocto/poky/meta-yocto-bsp \
  /home/yocto/openbmc/meta-phosphor \
  /home/yocto/openbmc/meta-aspeed \
  /home/yocto/project/meta-my-platform \
  "
```

重點變數：

- `BBLAYERS`：列出所有 layer 的路徑。BitBake 會讀取每個 layer 的 `conf/layer.conf`。
- `BBPATH`：BitBake 搜尋 `.conf`、`.bbclass` 等檔案的路徑基礎。
- `BBFILES`：定位 `.bb` 與 `.bbappend` 檔案的 pattern，通常由各 layer 的 `layer.conf` 追加。

注意事項：

- `BBLAYERS` 的順序會影響 layer 被加入 `BBPATH` 與 metadata 搜尋的先後，但 recipe 選擇與覆蓋不只看順序；更關鍵的是各 layer 在 `layer.conf` 中設定的 `BBFILE_PRIORITY_<collection>`、recipe version、`PREFERRED_PROVIDER`、`PREFERRED_VERSION` 與 override。
- 若同一 recipe 被多個 layer 提供，可用 `bitbake-layers show-overlayed` 與 `bitbake-layers show-recipes <name>` 確認實際採用來源。
- 若 `.bbappend` 沒有套上，常見原因是檔名版本不匹配、layer 沒有加入 `BBLAYERS`、`BBFILES` pattern 沒有包含該路徑，或 layer dependency 沒有滿足。

##### `layer.conf`：每個 layer 的自我介紹

每個 layer 根目錄下通常都有 `conf/layer.conf`，用來宣告該 layer 的 collection name、recipe 搜尋 pattern、priority 與相依 layer。

| 參數 | 說明 |
|---|---|
| `BBPATH` | 將該 layer 加入 BitBake 搜尋路徑 |
| `BBFILES` | 指定該 layer 內 `.bb` 與 `.bbappend` 的位置 |
| `BBFILE_COLLECTIONS` | 註冊 layer collection name |
| `BBFILE_PATTERN_<name>` | 比對路徑，判斷某個 recipe 屬於哪個 collection |
| `BBFILE_PRIORITY_<name>` | layer priority，數字越大優先權越高 |
| `LAYERDEPENDS_<name>` | 宣告此 layer 依賴哪些其他 layer |
| `LAYERSERIES_COMPAT_<name>` | 宣告此 layer 相容哪些 Yocto release series |

```bitbake
BBPATH .= ":${LAYERDIR}"
BBFILES += "${LAYERDIR}/recipes-*/*/*.bb \
            ${LAYERDIR}/recipes-*/*/*.bbappend"

BBFILE_COLLECTIONS += "myplatform"
BBFILE_PATTERN_myplatform = "^${LAYERDIR}/"
BBFILE_PRIORITY_myplatform = "10"

LAYERDEPENDS_myplatform = "core openembedded-layer meta-phosphor"
LAYERSERIES_COMPAT_myplatform = "scarthgap styhead walnascar"
```

BMC porting 建議：

- SoC vendor layer、OpenBMC core layer、company common layer、platform layer 最好有清楚的相依順序與責任邊界。
- 平台差異優先放在 `meta-<platform>`，不要直接改 `meta-phosphor`、`meta-aspeed`、`meta-nuvoton` 或 upstream layer。
- 新增 `.bbappend` 後，先用 `bitbake-layers show-appends | grep <recipe>` 確認有被 BitBake 看到。

#### 7.2.3 常用變數

##### 套件命名相關

| 變數 | 說明 | 範例 |
|---|---|---|
| `PN` | recipe / package name，通常由 recipe 檔名推導 | `busybox` |
| `PV` | package version | `1.36.1` |
| `PR` | package revision，常見預設為 `r0` | `r0` |
| `PE` | epoch，用於特殊版本排序 | `1` |
| `PF` | 完整 recipe working name，常見為 `${PN}-${PV}-${PR}` | `busybox-1.36.1-r0` |
| `BP` | base package name，常見為 `${BPN}-${PV}` | `busybox-1.36.1` |
| `BPN` | 不含特殊 prefix / suffix 的 base package name | `busybox` |

##### 目錄路徑相關

| 變數 | 說明 | 常見用途 |
|---|---|---|
| `TOPDIR` | build directory，例如 `build/` | 設定相對於 build root 的路徑 |
| `TMPDIR` | 建構中間產物 root | 預設常見為 `${TOPDIR}/tmp` |
| `WORKDIR` | 單一 recipe 的工作目錄 | 找 source、patch、log、image staging |
| `S` | 原始碼目錄 | `do_configure` / `do_compile` 常用工作目錄 |
| `B` | build directory | out-of-tree build 時與 `S` 分開 |
| `D` | 暫存安裝 root | `do_install` 安裝目的地 |
| `DL_DIR` | source download cache | 共用下載資料 |
| `SSTATE_DIR` | shared state cache | 共用 task 輸出快取 |
| `DEPLOY_DIR` | deploy 輸出 root | package/image/SDK 輸出根目錄 |
| `DEPLOY_DIR_IMAGE` | 目標 machine 的 image 輸出位置 | 找 BMC flash image、kernel、DTB |
| `sysconfdir` | 設定檔安裝路徑 | 常見為 `/etc` |
| `systemd_system_unitdir` | systemd system unit 目錄 | 安裝 `.service` |

##### 原始碼與相依相關

| 變數 | 說明 | 範例 |
|---|---|---|
| `SRC_URI` | 原始碼、patch、本地檔案來源 | `git://...`、`file://xxx.patch` |
| `SRCREV` | Git revision | commit hash、`${AUTOREV}` |
| `FILESEXTRAPATHS` | 擴充 `file://` 搜尋路徑 | bbappend 常用 |
| `DEPENDS` | build-time dependency | `openssl zlib` |
| `RDEPENDS:${PN}` | runtime dependency | `${PN}` 執行時需要的 package |
| `RRECOMMENDS:${PN}` | runtime recommended package | 可被移除的建議相依 |
| `PROVIDES` | recipe 提供的 virtual target | `virtual/kernel` |
| `RPROVIDES:${PN}` | runtime package 提供的名稱 | package alias |

##### Package 與 image 相關

| 變數 | 說明 | 常見用途 |
|---|---|---|
| `PACKAGES` | recipe 會切出的 package 清單 | `${PN}`、`${PN}-dev`、`${PN}-dbg` |
| `FILES:${PN}` | 指定哪些檔案進入 package | 補 installation path |
| `INSANE_SKIP:${PN}` | 跳過特定 QA check | 需謹慎使用並留下原因 |
| `IMAGE_INSTALL` | image 安裝 package 清單 | 加入工具或 service |
| `IMAGE_FEATURES` | image feature | ssh-server、package-management 等 |
| `EXTRA_IMAGE_FEATURES` | 額外 image feature | debug-tweaks 常見於開發版 |
| `IMAGE_FSTYPES` | image 輸出格式 | `tar.bz2 ext4 wic ubi mtd` |
| `BBMASK` | 讓 BitBake 忽略符合 pattern 的 `.bb` / `.bbappend` 檔案 | 排除衝突 recipe、暫停 vendor append、隔離不適用 layer metadata |


##### BBMASK：遮蔽不想讓 BitBake 解析的 recipe / append

`BBMASK` 是 BitBake / Yocto 的解析階段控制變數，用來讓 BitBake 忽略符合條件的 `.bb` 或 `.bbappend` 檔案。被 `BBMASK` 比對到的檔案不會被 parse，也不會成為 provider、dependency resolution 或 `bitbake-layers show-recipes` 的有效候選；效果接近「這些 metadata 對本次 build 不存在」。因此它適合用在「某些 recipe / append 目前不應參與解析」的場景，而不是用來取代 package 安裝、image 組成或 provider 選擇。

常見使用情境：

| 場景 | 建議用法 | 注意事項 |
|---|---|---|
| 暫時遮蔽 vendor layer 中會造成 parse error 的 recipe | 在 `local.conf` 或 distro / product conf 追加 `BBMASK` | 需留下原因與移除條件，避免長期隱藏問題 |
| 同一套 build tree 支援多個平台，但某些平台不使用特定 recipe | 使用 machine / distro override 控制 `BBMASK:append:<machine>` | 需確認其他 machine 不受影響 |
| 某個 `.bbappend` 已過期，對應新版 recipe 造成 patch 失敗 | 遮蔽該 `.bbappend`，或修正 append 檔名與 patch | 長期建議修 recipe / append，不建議只靠 mask |
| 多個 layer 提供相同功能，想排除其中一支 recipe | 以完整路徑 pattern 遮蔽不想要的 recipe | 若只是選 provider，優先評估 `PREFERRED_PROVIDER` |
| Bring-up 初期先剔除不穩定功能 | 暫時 mask sensor / fan / web / debug 相關 recipe 或 append | 需確認 image dependency 不會引用被遮蔽的 recipe |

`BBMASK` 的值是 Python regular expression fragment，且比對對象是 recipe / append 檔案的完整路徑。寫法上應盡量使用足夠明確的 layer 路徑與目錄尾端 `/`，避免把名稱相近但不相關的檔案一起遮蔽。

基本範例：

```bitbake
# 遮蔽整個目錄下的 recipe / append；目錄結尾保留 /
BBMASK += "/meta-vendor/recipes-obsolete/"

# 遮蔽特定 recipe
BBMASK += "/meta-vendor/recipes-support/foo/foo_.*\.bb"

# 遮蔽特定 .bbappend
BBMASK += "/meta-vendor/recipes-kernel/linux/linux-aspeed_.*\.bbappend"

# 遮蔽多個 pattern；每個 pattern 以空白分隔
BBMASK += "/meta-vendor/recipes-debug/ /meta-vendor/recipes-test/"
```

針對 machine 或 distro 的寫法：

```bitbake
BBMASK:append:my-bmc-machine = " /meta-vendor/recipes-platform/legacy-power/"
BBMASK:append:my-production-distro = " /meta-company/recipes-factory/"
```

驗證與排查指令：

```bash
bitbake-layers show-layers
bitbake-layers show-recipes foo
bitbake-layers show-appends | grep -A5 -B2 foo
bitbake -e | grep '^BBMASK='
bitbake -p
```

與其他機制的差異：

| 機制 | 作用層級 | 適合用途 | 不適合用途 |
|---|---|---|---|
| `BBMASK` | parse 階段，遮蔽 `.bb` / `.bbappend` 檔案 | 讓 BitBake 完全不看某些 metadata | 細緻控制 package 是否進 image |
| `PREFERRED_PROVIDER` / `PREFERRED_VERSION` | provider / version 選擇 | 多個 recipe 都可用時選其中一個 | vendor append 已造成 parse error 的情境 |
| `IMAGE_INSTALL:remove` | image rootfs 組成 | 從 image 移除 package | recipe 本身 parse 失敗 |
| `PACKAGE_EXCLUDE` | package install / rootfs 階段 | 避免特定 package 被安裝 | 遮蔽 `.bbappend` 或解決 provider 衝突 |
| `COMPATIBLE_MACHINE` | recipe 適用 machine | recipe 自身聲明支援範圍 | 從外部臨時排除既有 recipe |
| `SKIP_RECIPE` 或 `bb.parse.SkipRecipe` | recipe parse 邏輯 | recipe 內依條件主動跳過 | 從專案層遮蔽第三方 metadata 時通常不如 `BBMASK` 直接 |
| `BB_DANGLINGAPPENDS_WARNONLY` | dangling append 行為 | 讓舊 append 找不到 recipe 時由 fatal 變 warning | 不建議用來掩蓋產品 build 的 layer 不一致 |

常見問題與排查：

| 現象 | 可能方向 | 建議檢查 |
|---|---|---|
| 設了 `BBMASK` 但 recipe 還在 | pattern 沒匹配完整路徑、缺少 `/`、regex escape 不正確 | `bitbake -e | grep '^BBMASK='`、`bitbake-layers show-recipes` |
| 遮蔽後 build 出現 `Nothing PROVIDES` | 其他 recipe 仍 `DEPENDS` / `RDEPENDS` 該 recipe 或 virtual provider | `bitbake -g <target>`、檢查 `DEPENDS` / `RDEPENDS` / `PREFERRED_PROVIDER` |
| 只想遮蔽 `.bbappend` 卻 recipe 也消失 | pattern 太寬 | 明確寫到 `.*\.bbappend` |
| 某些 machine 正常，某些 machine 失敗 | override 沒掛對、`MACHINEOVERRIDES` 不符合預期 | `bitbake -e | grep '^OVERRIDES='`、檢查 machine conf |
| 遮蔽目錄後仍有 append 套用 | append 位於另一個 layer 或另一個路徑 | `bitbake-layers show-appends` 查完整來源 |

BMC / OpenBMC porting 建議：

- `BBMASK` 適合當作 bring-up 或 layer integration 的隔離工具，例如先遮蔽不適用平台的 vendor recipe、過期 append、暫不支援的 debug / factory tool。
- 若衝突來源是多個 provider，先評估 `PREFERRED_PROVIDER_virtual/<name>` 或 `PREFERRED_VERSION`；只有在不希望 BitBake 解析某些 `.bb` / `.bbappend` 時才使用 `BBMASK`。
- 若只是 package 不想進 image，應透過 image recipe、packagegroup、`IMAGE_INSTALL:remove` 或 feature flag 管理，不建議用 `BBMASK`。
- 每一條 `BBMASK` 都應附註 owner、原因、加入日期、預期移除條件。量產前建議審一次，確認沒有把安全更新、CVE 修補、必要 service 或平台 patch 保持在被遮蔽狀態。

建議檢查清單：

- [ ] `BBMASK` 放置位置明確：`local.conf`、distro conf、machine conf、layer conf 或 CI template。
- [ ] pattern 以完整 layer 路徑為主，避免只用過短名稱，例如 `foo`。
- [ ] 遮蔽目錄時保留 trailing slash，例如 `/recipes-obsolete/`。
- [ ] 若只要遮蔽 append，pattern 明確匹配 `.bbappend`。
- [ ] 執行 `bitbake -p` 確認 parse 通過。
- [ ] 執行 `bitbake-layers show-recipes` / `show-appends` 確認效果符合預期。
- [ ] 完整 image build 通過，且沒有新的 provider / dependency 問題。
- [ ] 文件或 commit message 留下原因、風險與移除條件。

##### 安裝路徑變數

| 變數 | 典型值 | 說明 |
|---|---|---|
| `prefix` | `/usr` | 安裝根目錄 |
| `exec_prefix` | `${prefix}` | 架構相關檔案的安裝根目錄 |
| `bindir` | `${exec_prefix}/bin` | 一般命令 |
| `sbindir` | `${exec_prefix}/sbin` | 系統管理命令 |
| `libdir` | `${exec_prefix}/lib` 或 `${exec_prefix}/lib64` | 函式庫檔案 |
| `includedir` | `${exec_prefix}/include` | 標頭檔 |
| `datadir` | `${prefix}/share` | 架構無關資料 |
| `sysconfdir` | `/etc` | 設定檔 |
| `localstatedir` | `/var` | log、spool、state data |

使用範例：

```bitbake
do_install() {
    install -d ${D}${bindir}
    install -m 0755 myapp ${D}${bindir}/

    install -d ${D}${sysconfdir}/myapp
    install -m 0644 myconfig.conf ${D}${sysconfdir}/myapp/
}
```

重點：`${D}` 是 `do_install` 的暫存根目錄，安裝檔案時應安裝到 `${D}${bindir}`、`${D}${sysconfdir}` 等路徑，而不是直接寫到 host 的 `/usr/bin` 或 `/etc`。

#### 7.2.4 BitBake 指令

BitBake 是 Yocto / OpenEmbedded 的建構引擎，負責解析 metadata、管理相依關係、安排 task、使用 sstate 並產生 package / image / SDK。

基本用法：

```bash
bitbake <recipe_or_image>
```

例如：

```bash
bitbake zstd-native
bitbake core-image-minimal
bitbake obmc-phosphor-image
```

常用選項：

| 選項 | 說明 | 範例 |
|---|---|---|
| `-c <task>` | 只執行指定 task | `bitbake -c compile zstd-native` |
| `-e` | 顯示變數展開後的環境 | `bitbake -e zstd-native | grep '^S='` |
| `-f` | 強制重跑指定 target 或 task | `bitbake -c compile -f zstd-native` |
| `-k` | 遇到部分錯誤時繼續跑可執行的 task | `bitbake -k obmc-phosphor-image` |
| `-g` | 產生 dependency graph 檔案 | `bitbake -g obmc-phosphor-image` |
| `-p` | 只解析 metadata，不執行建構 | `bitbake -p` |
| `-s` | 顯示 recipe 版本摘要 | `bitbake -s | grep busybox` |
| `-c listtasks` | 列出 recipe 可用 tasks | `bitbake -c listtasks busybox` |

清理任務：

| 指令 | 說明 | 使用時機 |
|---|---|---|
| `bitbake -c clean <recipe>` | 清除該 recipe 的多數 build 輸出，保留下載資料與 sstate | 一般重建 |
| `bitbake -c cleansstate <recipe>` | `clean` 加上刪除該 recipe 的 sstate | 懷疑 sstate 命中舊結果 |
| `bitbake -c cleanall <recipe>` | `cleansstate` 加上刪除 `DL_DIR` 內相關下載資料 | source 下載或 mirror 異常時才考慮 |

排查常用：

```bash
bitbake -e <recipe> | less
bitbake -e <recipe> | grep '^WORKDIR='
bitbake -e <recipe> | grep '^SRC_URI='
bitbake -c listtasks <recipe>
bitbake -c devshell <recipe>
bitbake -c compile -f <recipe>
bitbake-layers show-layers
bitbake-layers show-recipes <recipe>
bitbake-layers show-appends
bitbake-layers show-overlayed
```

#### 7.2.5 BitBake 執行流程

BitBake 的執行過程可分為兩大階段：**解析階段（Parsing Phase）**與**執行階段（Execution Phase）**。

##### 解析階段（Parsing Phase）

1. 讀取 `bblayers.conf`，確認要載入哪些 layers。
2. 讀取每個 layer 的 `conf/layer.conf`，建構 `BBPATH`、`BBFILES`、collection、priority 與 layer dependency。
3. 讀取 `bitbake.conf`、`local.conf`、distro conf、machine conf 與其他 include / require 檔。
4. 根據 `BBFILES` 找到所有 `.bb` 與 `.bbappend`。
5. 解析 recipes、classes、configuration、overrides 與 anonymous python。
6. 建立 providers、preferences、task dependency 與 runqueue。

常見解析階段問題：

| 現象 | 可能方向 | 檢查方式 |
|---|---|---|
| recipe 找不到 | layer 未加入、`BBFILES` pattern 不含該路徑 | `bitbake-layers show-recipes` |
| bbappend 沒套上 | 檔名版本不合、layer 未加入 | `bitbake-layers show-appends` |
| provider 衝突 | 多個 recipe 提供同一 virtual target | 查 `PREFERRED_PROVIDER_*` |
| layer dependency error | `LAYERDEPENDS` 未滿足 | `bitbake-layers show-layers` |
| Yocto series 不相容 | `LAYERSERIES_COMPAT` 不含目前 release | 檢查各 layer `conf/layer.conf` |

##### 執行階段（Execution Phase）

解析完成後，BitBake 依 runqueue 執行 task。task 是否需要重跑取決於 dependency、stamp、signature 與 sstate 狀態。

一般 recipe 的常見 task：

| 順序 | 任務名稱 | 說明 |
|---:|---|---|
| 1 | `do_fetch` | 根據 `SRC_URI` 取得原始碼、本地檔案與 patch |
| 2 | `do_unpack` | 解壓縮或展開 source 到 `WORKDIR` |
| 3 | `do_patch` | 套用 patches |
| 4 | `do_configure` | 執行建構前設定，例如 Autotools、CMake、Meson |
| 5 | `do_compile` | 編譯 source |
| 6 | `do_install` | 將編譯結果安裝到 `${D}` |
| 7 | `do_populate_sysroot` | 將 headers、libraries 等部署到 sysroot，供其他 recipe 使用 |
| 8 | `do_package` | 將 `${D}` 的內容拆成 packages |
| 9 | `do_package_qa` | 執行 package QA 檢查 |
| 10 | `do_package_write_rpm` / `do_package_write_ipk` / `do_package_write_deb` | 依 `PACKAGE_CLASSES` 產生套件 |
| 11 | `do_populate_lic` | 收集授權資訊 |
| 12 | `do_build` | 預設總任務，依賴完成正常建構所需 tasks |

Image recipe 額外 task：

| 任務名稱 | 說明 |
|---|---|
| `do_rootfs` | 建立 root filesystem，安裝 package、執行 postprocess |
| `do_image` | 將 rootfs 轉為 image 產物前的共用階段 |
| `do_image_<fstype>` | 產生指定格式，例如 `do_image_ext4`、`do_image_wic`、`do_image_ubi` |
| `do_image_complete` | image 完成階段，常見 manifest、symlink、deploy 收尾 |
| `do_populate_sdk` | 產生標準 SDK |
| `do_populate_sdk_ext` | 產生 extensible SDK |

擴充 task 的常見方式：

```bitbake
do_install:append() {
    install -d ${D}${sysconfdir}/myapp
    install -m 0644 ${WORKDIR}/myapp.conf ${D}${sysconfdir}/myapp/
}

python do_print_info() {
    bb.note("PN=%s" % d.getVar("PN"))
}
addtask print_info after do_configure before do_compile
```

#### 7.2.6 Metadata、Recipe 與 Layer

Metadata 是 Yocto 建構系統的核心資料，告訴 BitBake **要建構什麼**以及**如何建構**。主要分為：

- **Recipes（`.bb`）**：描述單一套件的建構方式。
- **Append files（`.bbappend`）**：在不直接修改原 recipe 的前提下，追加平台差異。
- **Classes（`.bbclass`）**：定義共用建構邏輯。
- **Configuration（`.conf`）**：定義 machine、distro、layer、local policy 等。

典型 recipe 目錄：

```text
meta-my-layer/
└── recipes-helloworld/
    └── hello-single/
        ├── files/
        │   ├── helloworld.c
        │   └── hello.service
        └── hello_1.0.bb
```

最小 recipe 範例：

```bitbake
SUMMARY = "Simple hello application"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://helloworld.c"
S = "${WORKDIR}"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} helloworld.c -o helloworld
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 helloworld ${D}${bindir}/
}
```

`.bbappend` 可在不改 upstream `.bb` 的狀態下，對 recipe 追加 patch、設定檔、systemd service、編譯參數或安裝內容。

```bitbake
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append = " \
    file://0001-platform-fix.patch \
    file://example.conf \
"

do_install:append() {
    install -d ${D}${sysconfdir}/example
    install -m 0644 ${WORKDIR}/example.conf ${D}${sysconfdir}/example/
}
```

Layer 是 recipe 之上的組織單元，一個 layer 可以包含 recipes、classes、configuration、machine settings、distro policy 與 image 定義。常見命名包含 `meta`、`meta-poky`、`meta-yocto-bsp`、`meta-phosphor`、`meta-aspeed`、`meta-nuvoton`、`meta-<company>`、`meta-<platform>`。

`bitbake-layers` 常用指令：

```bash
bitbake-layers create-layer ../meta-my-layer
bitbake-layers add-layer ../meta-my-layer
bitbake-layers remove-layer ../meta-my-layer
bitbake-layers show-layers
bitbake-layers show-recipes <recipe>
bitbake-layers show-appends
bitbake-layers show-overlayed
```

#### 7.2.7 BMC Porting 檢查重點

| 檢查項目 | 指令 / 檔案 | 預期結果 |
|---|---|---|
| machine 是否正確 | `grep ^MACHINE build/conf/local.conf` | 指向目前平台 machine |
| layer 是否載入 | `bitbake-layers show-layers` | 看到 SoC、OpenBMC、platform layers |
| recipe 是否選對 | `bitbake-layers show-recipes <recipe>` | 採用預期 layer 版本 |
| bbappend 是否套上 | `bitbake-layers show-appends | grep <recipe>` | platform bbappend 有列出 |
| image type 是否正確 | `bitbake -e obmc-phosphor-image | grep ^IMAGE_FSTYPES=` | 符合 flash layout，例如 `mtd`、`ubi` |
| kernel config 是否進去 | `bitbake -e virtual/kernel`、`tmp/work/.../defconfig` | config fragment 有套用 |
| DTS 是否進 image | `tmp/deploy/images/<machine>/*.dtb` | 產出正確 DTB |
| U-Boot env 是否正確 | U-Boot recipe / env / deploy output | bootcmd、mtdparts、slot 設定符合平台 |
| rootfs 是否含 service | `oe-pkgdata-util find-path`、image rootfs | package 有進 rootfs |
| sstate 是否異常 | `bitbake -c cleansstate <recipe>` 後重建 | 行為與預期一致 |

#### 7.2.8 本章參考資料

- Yocto Project Reference Manual - Variables: [https://docs.yoctoproject.org/ref-manual/variables.html](https://docs.yoctoproject.org/ref-manual/variables.html)
- Yocto Project Reference Manual - Tasks: [https://docs.yoctoproject.org/ref-manual/tasks.html](https://docs.yoctoproject.org/ref-manual/tasks.html)
- BitBake User Manual: [https://docs.yoctoproject.org/bitbake/](https://docs.yoctoproject.org/bitbake/)
- Yocto Project Development Tasks Manual - Understanding and Creating Layers: [https://docs.yoctoproject.org/dev/dev-manual/layers.html](https://docs.yoctoproject.org/dev/dev-manual/layers.html)
- OpenEmbedded Layer Index: [https://layers.openembedded.org](https://layers.openembedded.org)


### 7.3 在 Docker 中建立 Yocto 專案並建置完整映像

本章說明如何用 Docker 建立可重現的 Yocto build host，下載 Poky、初始化 build directory，並建置 `core-image-minimal`。此流程可用來驗證 Yocto 環境，也可作為 BMC / OpenBMC CI container 的基礎。

#### 7.3.1 為什麼要在 Docker 中建置 Yocto？

Yocto 對 build host 有明確需求：支援的 Linux distribution、必要套件，以及 Git、tar、Python、gcc、GNU make 等工具版本，都會隨 Yocto release 改變。若直接在本機安裝，可能遇到 host OS 太新或太舊、相依套件版本不合、同時維護多個 Yocto branch 時環境互相衝突等問題。

Docker 的價值是提供隔離且可重現的 build environment。可以在 container 內固定 Linux distribution 與套件清單，讓專案成員與 CI 使用相同建構基準。相較於 VM，Docker 通常更輕量，因為它使用 host Linux kernel，不需模擬完整硬體。

重要提醒：Yocto / BitBake 不建議以 `root` 身分執行。建構過程會建立大量檔案、執行 install step、產生 rootfs；若以 root 執行，容易造成檔案權限錯亂或誤寫 host 檔案。因此 Docker image 內應建立非 root 使用者，例如 `yocto`，並以該使用者執行 `bitbake`。

#### 7.3.2 建立 Docker Container

以下 Dockerfile 以 Fedora 38 為基礎。實際專案需依目前 Yocto release 的官方 system requirements 調整 base image 與套件清單。

```dockerfile
FROM fedora:38

# 建立非 root 使用者
RUN groupadd -g 1000 yocto && \
    useradd -m -u 1000 -g yocto yocto

# 安裝 Yocto 常用建構套件；實際清單需依 Yocto release 調整
RUN dnf update -y && dnf install -y \
    sudo \
    glibc-locale-source \
    glibc-langpack-en \
    librsvg2-tools \
    bc \
    @development-tools \
    gdisk \
    openssl-devel \
    bzip2 \
    ccache \
    chrpath \
    cpio \
    cpp \
    diffstat \
    diffutils \
    file \
    findutils \
    gawk \
    gcc \
    gcc-c++ \
    git \
    glibc-devel \
    gzip \
    hostname \
    libacl \
    make \
    ncurses-devel \
    patch \
    perl \
    perl-Data-Dumper \
    perl-File-Compare \
    perl-File-Copy \
    perl-FindBin \
    perl-Text-ParseWords \
    perl-Thread-Queue \
    perl-bignum \
    perl-locale \
    python3 \
    python3-GitPython \
    python3-jinja2 \
    python3-pexpect \
    python3-pip \
    rpcgen \
    socat \
    tar \
    texinfo \
    unzip \
    wget \
    which \
    xz \
    zstd \
    vim \
    lz4 \
    && dnf clean all

# 給予 yocto 使用者 sudo 權限；CI image 可依安全政策移除
RUN echo "yocto ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/yocto && \
    chmod 0440 /etc/sudoers.d/yocto

USER yocto
WORKDIR /home/yocto
CMD ["/bin/bash"]
```

常見套件用途：

| 套件 | 用途 |
|---|---|
| `git` | 從 Git repository 擷取原始碼，常用於 `do_fetch` |
| `wget` | 從 HTTP / HTTPS / FTP 下載 source archive |
| `make` / `gcc` / `gcc-c++` | 建構 host tools、native tools、target packages |
| `chrpath` | 調整 ELF RPATH，常見於 SDK / native tools |
| `cpio` | 建立 initramfs 或處理 cpio archive |
| `diffstat` | 顯示 patch 統計資訊 |
| `file` | 判斷檔案型態，常用於 QA 檢查 |
| `patch` | 套用 recipe patches，對應 `do_patch` |
| `perl` / `python3` | Yocto、BitBake、recipes 與輔助工具常用 runtime |
| `texinfo` | 建構 GNU info 文件 |
| `unzip` / `xz` / `zstd` / `lz4` | 處理不同壓縮格式 |
| `socat` | QEMU 網路轉發與測試情境常用工具 |
| `ccache` | 編譯快取，可縮短部分重建時間 |
| `ncurses-devel` | `menuconfig` / `nconfig` 類工具需要的 terminal UI library |

建立 Docker image：

```bash
mkdir -p ~/docker-yocto
cd ~/docker-yocto
vim Dockerfile

docker build -t yocto-fedora:38 .
```

啟動 container：

```bash
mkdir -p ~/yocto-work

docker run -itd \
    --name yocto_fedora38 \
    --memory=32g \
    --memory-swap=32g \
    -v ~/yocto-work:/work \
    yocto-fedora:38

docker exec -it yocto_fedora38 bash
```

參數說明：

- `-v ~/yocto-work:/work`：將 host 目錄掛載到 container 內，保存 source、downloads、sstate-cache 與最終 image。
- `--memory=32g --memory-swap=32g`：限制 container 記憶體與 swap。近期 Yocto quick build 文件建議準備較高 RAM；若只給 4 GB，簡單 image 可能可行，但大型 image 容易 OOM。
- `--name yocto_fedora38`：指定 container 名稱，方便後續 `docker exec`、`docker stop`、`docker start`。

若主機資源有限，優先降低 BitBake / make 平行度：

```bitbake
BB_NUMBER_THREADS = "4"
PARALLEL_MAKE = "-j 4"
```

Windows / WSL / Docker Desktop 注意事項：

- Yocto build directory 不建議放在 Windows NTFS 掛載路徑上，因為大小寫、symlink、inode、檔案權限與 I/O 行為可能造成額外問題。
- 若使用 WSL2，建議把 source、`build/`、`downloads/`、`sstate-cache/` 放在 WSL2 Linux filesystem 內，而不是 `/mnt/c/...`。
- 若需要從 Windows 取出產物，可只將 `tmp/deploy/images/<machine>/` 複製到 Windows 端。

#### 7.3.3 下載 Poky 並初始化

進入 container 後，下載 Poky 並切到目標分支。以下以 `walnascar` 為例；實際專案需依客戶、SoC vendor、OpenBMC branch 或 Yocto release policy 選擇 branch。

```bash
cd /work

git clone git://git.yoctoproject.org/poky.git
cd poky

git branch -a | grep walnascar
git checkout -t origin/walnascar -b my-walnascar

source oe-init-build-env
```

執行 `source oe-init-build-env` 後，通常會進入 `build/` 目錄，並產生：

```text
build/conf/local.conf
build/conf/bblayers.conf
```

第一次建置前建議調整 `conf/local.conf`：

```bitbake
# QEMU 目標；若是實體板，改為對應 MACHINE
MACHINE ?= "qemux86-64"

# 平行度需依 CPU / RAM / I/O 調整
BB_NUMBER_THREADS = "8"
PARALLEL_MAKE = "-j 8"

# 將 downloads 與 sstate-cache 放到 build 外層，方便多個 build 共用
DL_DIR = "/work/yocto-cache/downloads"
SSTATE_DIR = "/work/yocto-cache/sstate-cache"
```

建議目錄規劃：

```text
/work/
├── poky/
│   └── build/
└── yocto-cache/
    ├── downloads/
    └── sstate-cache/
```

#### 7.3.4 執行第一次 BitBake

建立最小 Linux image：

```bash
bitbake core-image-minimal
```

`core-image-minimal` 是驗證 build host、toolchain、metadata 與 QEMU target 的常見起點。第一次建構會花較久，因為需要下載 source、建構 native tools、cross toolchain、target packages 與 rootfs。第二次以後若 `downloads/` 與 `sstate-cache/` 命中，時間會縮短。

建構完成後，輸出通常位於：

```bash
ls tmp/deploy/images/qemux86-64/
```

常見產物：

```text
core-image-minimal-qemux86-64.ext4
core-image-minimal-qemux86-64.manifest
core-image-minimal-qemux86-64.testdata.json
bzImage
modules-qemux86-64.tgz
```

可用 QEMU 測試 image：

```bash
runqemu qemux86-64
```

若 container 內缺少 `/dev/kvm` 權限，QEMU 仍可能以軟體模擬方式啟動，但速度會慢很多。若要使用 KVM，可在 `docker run` 時加入：

```bash
docker run -itd \
    --name yocto_fedora38 \
    --device /dev/kvm \
    --group-add $(getent group kvm | cut -d: -f3) \
    -v ~/yocto-work:/work \
    yocto-fedora:38
```

#### 7.3.5 效能最佳化與最佳實務

保存建構產物：不要只把重要資料放在 container writable layer。container 移除後，內部資料也會消失。建議至少保存：

```text
/work/yocto-cache/downloads/
/work/yocto-cache/sstate-cache/
/work/poky/build/tmp/deploy/images/<machine>/
```

善用 sstate 快取：

```bitbake
SSTATE_DIR = "/work/yocto-cache/sstate-cache"
```

團隊共用 sstate 時，需注意：

- 共用目錄權限需允許 container 內的 UID/GID 讀寫。
- 不同 Yocto release、不同 host distro、不同 layer revision 混用時，sstate 命中率與可追蹤性會下降。
- CI 可使用唯讀 upstream sstate mirror 加上 job local writable sstate，降低互相污染。

記憶體與磁碟空間建議：

- `core-image-minimal`：建議準備 100 GB 等級磁碟空間較穩妥。
- OpenBMC image：依平台與 Web UI / debug package 狀態不同，建議保留更多空間給 `tmp/`、`downloads/`、`sstate-cache/`。
- 若記憶體有限，先降低 `BB_NUMBER_THREADS` 與 `PARALLEL_MAKE`。
- 可用 `docker stats` 觀察 container 記憶體與 CPU 使用。

```bash
docker stats yocto_fedora38
```

UID/GID 權限建議：若 host 掛載目錄屬於 UID 1000 / GID 1000，container 內也使用 UID 1000 / GID 1000 的 `yocto` 使用者，可避免許多 `Permission denied` 或 root-owned output。

若開發機 UID/GID 不一定是 1000，可把 Dockerfile 改成 build args：

```dockerfile
ARG USER_ID=1000
ARG GROUP_ID=1000
RUN groupadd -g ${GROUP_ID} yocto && \
    useradd -m -u ${USER_ID} -g yocto yocto
```

建置時指定：

```bash
docker build \
    --build-arg USER_ID=$(id -u) \
    --build-arg GROUP_ID=$(id -g) \
    -t yocto-fedora:38 .
```

#### 7.3.6 常見問題與排查

| 問題 | 可能原因 | 排查 / 處理方式 |
|---|---|---|
| `OE-core's config sanity checker detected a potential misconfiguration` | Host distro、必要工具或 shell 環境不符合 Yocto sanity check | 查看 `tmp/log/cooker/*`，確認 Yocto release 支援的 host distro 與套件版本 |
| `Permission denied` | bind mount 權限或 UID/GID 不一致 | 對齊 host 與 container 的 UID/GID，檢查 `/work` 權限 |
| `do_patch` 失敗 | patch 不適用、換行格式、檔案權限或 source revision 不對 | 看 `temp/log.do_patch`，進 `WORKDIR` 檢查 patch context |
| 建構中途被 kill | 記憶體不足或 Docker memory limit 太低 | 提高 `--memory`，或降低 `BB_NUMBER_THREADS` / `PARALLEL_MAKE` |
| `do_fetch` 失敗 | 網路、DNS、proxy、憑證、Git protocol 被擋 | 設定 `http_proxy` / `https_proxy`，或改用 mirror / premirror |
| 建構速度很慢 | 未命中 sstate、I/O 慢、平行度不合理 | 檢查 `SSTATE_DIR`、磁碟 I/O、`BB_NUMBER_THREADS`、`PARALLEL_MAKE` |
| Windows 掛載點建構失敗 | 檔案系統大小寫、symlink、權限或 I/O 行為不符合 Linux 預期 | 將 `TMPDIR`、source tree、sstate 放在 Linux filesystem |
| `make menuconfig` 失敗 | 缺少 ncurses 或 terminal 設定不足 | 安裝 `ncurses-devel`，確認 `TERM` 設定；必要時使用 `screen` / `tmux` |
| `runqemu` 很慢 | container 沒有 KVM 權限 | 加入 `--device /dev/kvm` 與 kvm group，或接受軟體模擬速度 |
| Docker 內 DNS 失敗 | Docker daemon DNS 設定或公司網路限制 | 檢查 `/etc/resolv.conf`，必要時於 Docker daemon 設定 DNS |

常用 log 位置：

```bash
# BitBake cooker log
ls -l bitbake-cookerdaemon.log

# 單一 recipe task log
find tmp/work -path '*temp/log.do_compile*' | head
find tmp/work -path '*temp/log.do_fetch*' | head
find tmp/work -path '*temp/log.do_patch*' | head

# 最近失敗訊息
find tmp/work -path '*temp/log.do_*' -mtime -1 | sort | tail
```

#### 7.3.7 BMC / OpenBMC 專案延伸

若目標不是 Poky 的 `core-image-minimal`，而是 OpenBMC image，流程通常會變成：

```bash
cd /work

git clone https://github.com/openbmc/openbmc.git
cd openbmc

# 依平台選擇 machine
. setup <machine>

bitbake obmc-phosphor-image
```

OpenBMC 專案建議額外確認：

| 項目 | 檢查方式 | 說明 |
|---|---|---|
| MACHINE | `. setup <machine>` 後檢查 `conf/local.conf` | 確認平台是否正確 |
| SoC layer | `bitbake-layers show-layers` | 需看到 `meta-aspeed`、`meta-nuvoton` 或對應 SoC layer |
| image output | `tmp/deploy/images/<machine>/` | 找 `.static.mtd.tar`、`.ubi.mtd.tar` 或平台定義 image |
| sensor config | platform layer / Entity Manager config | 對齊 I2C bus map 與 schematic |
| update format | image manifest / phosphor software manager | 對齊 update service 與 flash layout |

#### 7.3.8 本章參考資料

- Yocto Project Quick Build: [https://docs.yoctoproject.org/brief-yoctoprojectqs/index.html](https://docs.yoctoproject.org/brief-yoctoprojectqs/index.html)
- Yocto Project Reference Manual - System Requirements: [https://docs.yoctoproject.org/ref-manual/system-requirements.html](https://docs.yoctoproject.org/ref-manual/system-requirements.html)
- Docker Docs - Bind mounts: [https://docs.docker.com/engine/storage/bind-mounts/](https://docs.docker.com/engine/storage/bind-mounts/)
- Docker Docs - Resource constraints: [https://docs.docker.com/engine/containers/resource_constraints/](https://docs.docker.com/engine/containers/resource_constraints/)
- AMD / Xilinx Wiki - Building Yocto Images using a Docker Container: [https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/2823422188/Building+Yocto+Images+using+a+Docker+Container](https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/2823422188/Building+Yocto+Images+using+a+Docker+Container)

### 7.4 單獨建置與除錯特定套件

在日常開發中，很少需要每次都從頭建置整個 image。更常見的是只修改某個 application、library、kernel、kernel module、OpenBMC service 或 recipe，然後希望快速驗證修改是否正確。Yocto / BitBake 的建構單位是 **recipe**，因此可以只針對單一 recipe 執行 `fetch`、`patch`、`compile`、`install`、`package`、`deploy` 等 tasks；BitBake 會根據相依關係、stamp 與 sstate 判斷哪些任務需要重跑。

#### 7.4.1 為什麼要單獨建置一個套件？

| 場景                 | 說明                                                        | 常用指令                                                      |
| -------------------- | ----------------------------------------------------------- | ------------------------------------------------------------- |
| 開發新功能           | 修改某個 application、daemon、kernel module，先確認能否編譯 | `bitbake -c compile -f <recipe>`                            |
| 修 bug               | recipe 或 source 編譯失敗，修改後重新驗證                   | `bitbake <recipe>`                                          |
| 驗證 patch           | 測試 patch 是否可套用、是否造成編譯錯誤                     | `bitbake -c patch -f <recipe>`                              |
| 調整 feature         | 修改`PACKAGECONFIG`、編譯選項或 recipe 變數               | `bitbake -e <recipe>`、`bitbake -c configure -f <recipe>` |
| 取出產物             | 只需要某個 library、binary、kernel image 或 module          | `bitbake -c deploy <recipe>`                                |
| OpenBMC service 開發 | 修改 phosphor service 或平台 service 後快速重建             | `bitbake <service-recipe>`                                  |

關鍵觀念：

- `bitbake <recipe>` 會執行該 recipe 的預設 build task，並自動處理 build-time dependencies。
- `bitbake -c <task> <recipe>` 可指定只跑某個 task，例如 `compile`、`install`、`package`、`deploy`。
- `-f` 會讓指定 task 忽略既有 stamp，強制重跑。
- 若只是臨時改 `tmp/work` 內 source，速度很快，但 `clean` 後修改會消失；正式修改應回到 layer，用 `.bbappend`、patch 或 `devtool` 管理。

#### 7.4.2 單獨建置一個套件

假設要建置 `zstd-native`：

```bash
bitbake zstd-native
```

BitBake 會檢查 `zstd-native` 的相依項目，並依任務關係執行必要流程，例如：

```text
do_fetch → do_unpack → do_patch → do_configure → do_compile → do_install
         → do_populate_sysroot → do_package → do_package_qa → do_package_write_*
```

若之前已經建置過，相同 task 可能透過 stamp 或 sstate 判斷不需要重跑，因此第二次建置通常會快很多。

只執行特定 task：

```bash
# 只下載原始碼
bitbake -c fetch zstd-native

# 展開 source 並套用 patch，用於檢查 patch 是否衝突
bitbake -c patch zstd-native

# 只編譯
bitbake -c compile zstd-native

# 只執行安裝到 ${D}
bitbake -c install zstd-native

# 列出此 recipe 可用 tasks
bitbake -c listtasks zstd-native
```

強制重新執行某個 task：

```bash
# 強制重新編譯，忽略 compile task 的 stamp
bitbake -c compile -f zstd-native

# 如果 patch 或 configure 有改，從較早階段重跑
bitbake -c patch -f zstd-native
bitbake -c configure -f zstd-native
bitbake -c compile -f zstd-native
```

補充：`-C <task>` 也是常用方式，它會讓指定 task 的 stamp 失效，然後執行預設 build 流程。例如：

```bash
# 清掉 compile stamp 後，接著跑預設 build
bitbake -C compile zstd-native
```

#### 7.4.3 建置產物在哪裡？

單獨建置一個 recipe 後，常見產物位置如下：

| 路徑                                                          | 內容                                  | 用途                                             |
| ------------------------------------------------------------- | ------------------------------------- | ------------------------------------------------ |
| `tmp/work/<arch或machine>/<pn>/<pv>/`                       | 該 recipe 的工作目錄                  | 找 source、build output、task log                |
| `tmp/work/.../<pn>/<pv>/temp/`                              | task log 與 run script                | 排查`log.do_compile`、`run.do_compile`       |
| `tmp/work/.../<pn>/<pv>/image/`                             | `do_install` 安裝到 `${D}` 的結果 | 確認檔案是否安裝到正確路徑                       |
| `tmp/work/.../<pn>/<pv>/package/`                           | package 前的中間資料                  | 排查 package 切分問題                            |
| `tmp/work/.../<pn>/<pv>/packages-split/`                    | 拆分後的 package 內容                 | 確認`${PN}`、`${PN}-dev`、`${PN}-dbg` 內容 |
| `tmp/deploy/rpm/`、`tmp/deploy/ipk/`、`tmp/deploy/deb/` | 最終套件檔                            | 找`.rpm`、`.ipk`、`.deb`                   |
| `tmp/deploy/images/<machine>/`                              | kernel、DTB、U-Boot、image 等         | `virtual/kernel`、U-Boot、image recipe 常用    |
| `tmp/sysroots-components/`                                  | sysroot 元件                          | 確認 headers / libraries 是否進 sysroot          |

快速找 recipe 工作目錄：

```bash
bitbake -e zstd-native | grep '^WORKDIR='
bitbake -e zstd-native | grep '^S='
bitbake -e zstd-native | grep '^B='
```

開發時最常看的位置：

```bash
# 安裝結果
ls ${WORKDIR}/image/

# package 拆分結果
ls ${WORKDIR}/packages-split/

# task log
ls ${WORKDIR}/temp/log.do_*
```

#### 7.4.4 完整開發循環：Modify → Build → Test

以下以 `zstd-native` 為例，說明臨時修改 source 並驗證的流程。

Step 1：找到 source 目錄：

```bash
bitbake -e zstd-native | grep '^S='
```

可能輸出：

```text
S="/home/yocto/poky/build/tmp/work/x86_64-linux/zstd-native/1.5.7/git"
```

Step 2：進入 source 目錄並修改：

```bash
cd /home/yocto/poky/build/tmp/work/x86_64-linux/zstd-native/1.5.7/git
vim lib/zstd.h
```

注意：直接修改 `tmp/work/` 是臨時測試方式，適合快速確認方向。若後續執行 `clean`、重新 unpack，或 sstate 還原，修改可能消失。確認可行後，應把修改轉成 patch、`.bbappend`，或使用 `devtool modify / devtool finish` 納入正式 layer。

Step 3：重新編譯：

```bash
bitbake -c compile -f zstd-native
```

Step 4：重新安裝與打包：

```bash
bitbake -c install -f zstd-native
bitbake -c package -f zstd-native
```

Step 5：若要讓最終 image 納入變更，再重建 image：

```bash
bitbake core-image-minimal
```

OpenBMC service 常見流程：

```bash
# 找 recipe
bitbake-layers show-recipes | grep phosphor

# 單獨建置 service
bitbake <service-recipe>

# 若 image 要包含更新後 package
bitbake obmc-phosphor-image
```

#### 7.4.5 建置失敗時如何排查

BitBake 失敗時通常會印出失敗 task 與 log 位置，例如：

```text
ERROR: Logfile of failure stored in:
/tmp/work/x86_64-linux/zstd-native/1.5.7/temp/log.do_compile.12345
```

查看 log：

```bash
less /home/yocto/poky/build/tmp/work/x86_64-linux/zstd-native/1.5.7/temp/log.do_compile.12345

# 通常也會有無序號 symlink 或最新 log
less tmp/work/x86_64-linux/zstd-native/1.5.7/temp/log.do_compile
```

常見失敗情境：

| 失敗 task         | 可能原因                                                                                    | 排查入口                                                  |
| ----------------- | ------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| `do_fetch`      | 網路、proxy、DNS、Git branch / commit 不存在、憑證問題                                      | `log.do_fetch`、`SRC_URI`、`SRCREV`、mirror 設定    |
| `do_unpack`     | 壓縮檔格式錯、檔案損壞、fetch 結果不完整                                                    | `log.do_unpack`、`DL_DIR`                             |
| `do_patch`      | patch context 不符、source revision 不對、patch 順序錯                                      | `log.do_patch`、`patches/`、`quilt`                 |
| `do_configure`  | 缺少 build dependency、`PACKAGECONFIG` 不合理、toolchain file 問題                        | `log.do_configure`、`DEPENDS`、`EXTRA_OECONF`       |
| `do_compile`    | 語法錯誤、compiler flag 不相容、missing header / library                                    | `log.do_compile`、`S`、`B`、`CFLAGS`、`LDFLAGS` |
| `do_install`    | 未加`${D}`、安裝目錄不存在、權限或路徑錯 | `log.do_install`、`${D}`、`do_install()` |                                                           |
| `do_package`    | `FILES:${PN}` 未涵蓋、package split 錯誤                                                  | `packages-split/`、`FILES:*`                          |
| `do_package_qa` | rpath、installed-vs-shipped、already-stripped、ldflags 等 QA issue                          | `log.do_package_qa`、`INSANE_SKIP`                    |

從失敗點繼續：

```bash
# do_compile 失敗，修正 source 後重跑 compile
bitbake -c compile -f zstd-native

# do_configure 相關問題，通常從 configure 重跑
bitbake -c configure -f zstd-native
bitbake -c compile -f zstd-native

# do_patch 相關問題，從 patch 重跑
bitbake -c patch -f zstd-native
bitbake -c compile -f zstd-native
```

進入開發 shell：

```bash
# 進入 recipe 的建構環境，便於手動執行 make / ninja / cmake
bitbake -c devshell zstd-native

# 部分 recipe 可用 menuconfig，例如 kernel / busybox
bitbake -c menuconfig virtual/kernel
```

#### 7.4.6 clean / cleansstate / cleanall 何時使用？

| 指令                                | 清除範圍                                        | 適用情境                         | 注意事項                             |
| ----------------------------------- | ----------------------------------------------- | -------------------------------- | ------------------------------------ |
| `bitbake -c clean <recipe>`       | 清除多數 build output，保留`DL_DIR` 與 sstate | 一般重新建置                     | 相對安全，常用                       |
| `bitbake -c cleansstate <recipe>` | `clean` 加上移除該 recipe sstate              | 懷疑 sstate 還原舊結果           | 下次會慢，因為要重建                 |
| `bitbake -c cleanall <recipe>`    | `cleansstate` 加上刪除下載資料                | source / mirror 異常或要重新下載 | 謹慎使用，可能造成重新下載大量資料   |
| `bitbake -C <task> <recipe>`      | 指定 task stamp 失效後跑預設 build              | 想從某 task 後重跑完整流程       | 適合比`-f` 更貼近完整 build 的驗證 |

實務建議：

- 一般 code / recipe 修改：先用 `bitbake -c compile -f <recipe>` 或 `bitbake -C compile <recipe>`。
- 懷疑 workdir 舊檔干擾：用 `clean`。
- 懷疑 sstate 還原異常：用 `cleansstate`。
- 除非確認 source cache 有問題，否則少用 `cleanall`。

#### 7.4.7 實戰案例：修改 Linux Kernel

Kernel 是 BMC porting 最常單獨建置的目標之一。常見目標是修改 driver、DTS、defconfig 或 config fragment。

1. 建置 kernel：

```bash
bitbake virtual/kernel
```

2. 找 kernel source：

```bash
bitbake -e virtual/kernel | grep '^S='
bitbake -e virtual/kernel | grep '^B='
```

3. 修改 driver 或 DTS：

```bash
cd <kernel-source>
vim drivers/char/xxx.c
# 或修改 arch/arm/boot/dts/... / arch/arm64/boot/dts/...
```

4. 重新編譯 kernel：

```bash
bitbake -c compile -f virtual/kernel
```

5. 部署 kernel image / DTB / modules：

```bash
bitbake -c deploy virtual/kernel
```

6. 查看部署結果：

```bash
ls tmp/deploy/images/${MACHINE}/
```

7. 若是 QEMU target，可用：

```bash
runqemu qemux86-64
```

BMC kernel / DTS 額外提醒：

- 若變更 DTS，需確認實際 deploy 的 `.dtb` 是目標平台使用的那一份。
- 若變更 config fragment，需確認最終 `.config` 是否真的包含該選項。
- 若使用 OpenBMC，kernel image、DTB 與 rootfs 打包方式會受 machine 與 image type 影響，需同步檢查 `tmp/deploy/images/<machine>/` 的 `.mtd`、`.ubi`、fitImage 或其他平台產物。

#### 7.4.8 何時該改用 devtool？

直接修改 `tmp/work` 適合短時間測試，但不適合作為正式修改流程。以下情境建議使用 `devtool`：

| 情境                                      | 建議工具                            |
| ----------------------------------------- | ----------------------------------- |
| 要長時間修改某 recipe source              | `devtool modify <recipe>`         |
| 要新增一個 application / package          | `devtool add` 或手寫 recipe       |
| 要把本地修改整理成 patch 並放回 layer     | `devtool finish <recipe> <layer>` |
| 要部署單一 recipe 產物到 live target 測試 | `devtool deploy-target`           |
| 要移除 workspace 內的臨時 recipe 修改     | `devtool reset <recipe>`          |

典型 devtool 流程：

```bash
# 取出 recipe source 到 workspace
 devtool modify zstd-native

# 修改 source 後建置
 devtool build zstd-native

# 完成後把修改整理回指定 layer
 devtool finish zstd-native ../meta-my-layer

# 若只是取消 workspace 狀態
 devtool reset zstd-native
```

#### 7.4.9 本章參考資料

- BitBake User Manual - Execution: [https://docs.yoctoproject.org/bitbake/bitbake-user-manual/bitbake-user-manual-execution.html](https://docs.yoctoproject.org/bitbake/bitbake-user-manual/bitbake-user-manual-execution.html)
- BitBake User Manual: [https://docs.yoctoproject.org/bitbake/](https://docs.yoctoproject.org/bitbake/)
- Yocto Project Reference Manual - Tasks: [https://docs.yoctoproject.org/ref-manual/tasks.html](https://docs.yoctoproject.org/ref-manual/tasks.html)
- Yocto Project Development Tasks Manual - devtool: [https://docs.yoctoproject.org/dev/dev-manual/devtool.html](https://docs.yoctoproject.org/dev/dev-manual/devtool.html)

### 7.5 使用 .bbappend 修改套件行為

在 Yocto / OpenBMC 開發中，常見需求是調整既有套件的行為，但不直接修改原本的 `.bb`。原始 recipe 可能來自 OE-Core、meta-openembedded、meta-phosphor、SoC vendor layer 或 BSP layer；若直接改，後續更新時容易被覆蓋，也會讓平台差異不易追蹤。因此平台差異建議放在自己的 layer，透過 `.bbappend` 追加。

#### 7.5.1 什麼是 .bbappend？

`.bbappend` 是 BitBake append file。它必須對應到一個存在的 `.bb` recipe，且 root filename 要相同，差異只在副檔名。例如 `zstd_1.5.7.bb` 可對應 `zstd_1.5.7.bbappend`、`zstd_1.5.%.bbappend` 或 `zstd_%.bbappend`。

可以這樣理解：

- `.bb`：原始食譜。
- `.bbappend`：補充便條，只寫需要追加或調整的部分。
- BitBake：解析 recipe 時，把符合條件的 `.bbappend` 合併進 metadata。

常見用途：加 patch、加設定檔、加 systemd override、調整 `PACKAGECONFIG` / `EXTRA_OECMAKE` / `EXTRA_OEMESON`、追加 `DEPENDS` / `RDEPENDS:${PN}`、在 `do_install` 後追加安裝內容、針對 machine 或 class 做差異化設定。

#### 7.5.2 命名規範

| 檔名 | 套用範圍 | 適用情境 |
|------|----------|----------|
| `zstd_1.5.7.bbappend` | 只套用到 `zstd_1.5.7.bb` | patch 高度綁定特定版本 |
| `zstd_1.5.%.bbappend` | 套用到 `zstd_1.5.x` | 同一 minor series 行為接近 |
| `zstd_%.bbappend` | 套用到所有 `zstd` 版本 | 平台設定不依賴版本，最常見 |

注意：`%` 通常只放在 `.bbappend` 前面。若 recipe 升級，精準版本 append 可能失效；使用 `recipe_%.bbappend` 較能承受版本更新。若 append 找不到對應 recipe，BitBake 通常會在 parsing 階段報錯。

#### 7.5.3 目錄結構與 FILESEXTRAPATHS

建議把 `.bbappend` 放在自己的 layer，目錄分類盡量跟原 recipe 接近：

```text
meta-my-layer/
└── recipes-extended/
    └── zstd/
        ├── zstd_%.bbappend
        └── zstd/
            └── 0001-fix-compile-error.patch
```

`zstd_%.bbappend`：

```bitbake
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append = " file://0001-fix-compile-error.patch"
```

變數說明：

- `${THISDIR}`：目前 `.bbappend` 所在目錄。
- `${PN}`：目前 recipe / package name。
- `${BPN}`：base package name；遇到 `-native`、`nativesdk-`、multilib 變體時常比 `${PN}` 穩定。
- `FILESEXTRAPATHS`：擴充 `file://` 搜尋路徑。
- `SRC_URI`：列出 source、patch 或本地檔案。

常用寫法：

```bitbake
# 一般 recipe 常用
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# native / nativesdk 也會套用時，常改用 BPN
FILESEXTRAPATHS:prepend := "${THISDIR}/${BPN}:"

# 檔案統一放 files/ 時
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
```

BMC porting 建議：若 append 會作用到 `cmake-native`、`zstd-native` 或 `nativesdk-*`，優先評估 `${BPN}` 或 `files/`。因為 native variant 的 `${PN}` 可能是 `cmake-native`，但實際檔案目錄常是 `cmake/`。

#### 7.5.4 常用語法

```bitbake
# 追加變數；字串前面的空格要保留
SRC_URI:append = " file://0001-platform-fix.patch"
DEPENDS:append = " openssl"
RDEPENDS:${PN}:append = " bash"

# 插入變數；字串後面的空格要保留
CFLAGS:prepend = "-DDEBUG "

# 移除 list-like 變數中的項目
PACKAGECONFIG:remove = "x11"

# 完全覆寫，需謹慎
PACKAGECONFIG = "ssl zlib"
```

建議優先使用 `:append`、`:prepend`、`:remove`，非必要不要直接用 `=` 覆寫整個變數。override-style 的 `:append` / `:prepend` 不會自動補空格，所以 `SRC_URI:append = " file://my.patch"` 前面的空格是必要的。

追加 task 內容：

```bitbake
do_install:append() {
    install -d ${D}${sysconfdir}/myapp
    install -m 0644 ${WORKDIR}/myapp.conf ${D}${sysconfdir}/myapp/myapp.conf
}
```

`do_install` 內正式要進 package 的檔案應安裝到 `${D}` 底下，例如 `${D}${bindir}`、`${D}${sysconfdir}`、`${D}${datadir}`。`${B}` 是 build directory，不等於 package 安裝目的地。

針對 machine / class 做差異：

```bitbake
SRC_URI:append:my-bmc-machine = " file://0001-my-bmc-only.patch"
EXTRA_OECMAKE:append:class-native = " -DENABLE_TOOLS=ON"

do_install:append:class-target() {
    install -d ${D}${sysconfdir}/platform
}
```

#### 7.5.5 動手做：用 .bbappend 修改 cmake-native 行為

Step 1：建立或加入自己的 layer：

```bash
bitbake-layers create-layer ../meta-my-layer
bitbake-layers add-layer ../meta-my-layer
bitbake-layers show-layers
```

Step 2：確認 recipe：

```bash
bitbake-layers show-recipes cmake
bitbake -e cmake-native | grep -E '^(PN|BPN|PV|FILE)='
```

注意：雖然建置目標是 `cmake-native`，append 檔名通常仍是 `cmake_%.bbappend`。原因是 `cmake-native` 多半是由 `cmake` recipe 透過 class extension 產生，不是檔名叫 `cmake-native_*.bb` 的獨立 recipe。

Step 3：建立 append：

```bash
mkdir -p ../meta-my-layer/recipes-devtools/cmake
vim ../meta-my-layer/recipes-devtools/cmake/cmake_%.bbappend
```

先放最小內容確認 append 被解析：

```bitbake
python () {
    bb.note("meta-my-layer: cmake append parsed for PN=%s BPN=%s" % (d.getVar("PN"), d.getVar("BPN")))
}
```

確認 append 有套上：

```bash
bitbake -p
bitbake-layers show-appends | grep -A5 -B2 'cmake'
```

Step 4A：練習用，寫檔到 build directory：

```bitbake
do_install:append:class-native() {
    install -d ${B}/cmake2
    echo "Try to write line to the file." > ${B}/cmake2/appendFile.txt
}
```

```bash
bitbake -c install -f cmake-native
cat tmp/work/x86_64-linux/cmake-native/*/build/cmake2/appendFile.txt
```

這個做法適合確認 `do_install:append` 有執行，但不代表檔案會被打包或進 rootfs。

Step 4B：正式安裝用，寫到 `${D}`：

```bitbake
FILESEXTRAPATHS:prepend := "${THISDIR}/${BPN}:"

SRC_URI:append:class-native = " file://appendFile.txt"

do_install:append:class-native() {
    install -d ${D}${datadir}/cmake2
    install -m 0644 ${WORKDIR}/appendFile.txt ${D}${datadir}/cmake2/appendFile.txt
}

FILES:${PN}:append:class-native = " ${datadir}/cmake2/appendFile.txt"
```

```text
meta-my-layer/
└── recipes-devtools/
    └── cmake/
        ├── cmake_%.bbappend
        └── cmake/
            └── appendFile.txt
```

```bash
bitbake -c install -f cmake-native
find tmp/work -path '*cmake-native*image*appendFile.txt' -print

bitbake -c package -f cmake-native
find tmp/work -path '*cmake-native*packages-split*appendFile.txt' -print
```

補充：`cmake-native` 的產物主要給 build host sysroot 使用，不一定會進 target image。若目標是讓檔案進 BMC rootfs，應修改 target recipe、image recipe 或 packagegroup。

#### 7.5.6 完整範例：對 zstd 加 patch

```text
meta-my-layer/
└── recipes-extended/
    └── zstd/
        ├── zstd_%.bbappend
        └── zstd/
            └── 0001-fix-platform-build.patch
```

```bitbake
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append = " file://0001-fix-platform-build.patch"
```

驗證：

```bash
bitbake-layers show-appends | grep -A5 -B2 'zstd'
bitbake -c patch -f zstd
bitbake -c compile -f zstd
bitbake zstd
```

若 patch 失敗，先看：

```bash
bitbake -e zstd | grep '^WORKDIR='
find tmp/work -path '*zstd*temp/log.do_patch*' -print
```

常見方向包含 source revision 已變更、patch context 不符合、patch 順序不對、`FILESEXTRAPATHS` 路徑沒對上。

#### 7.5.7 多個 .bbappend 的順序與 layer priority

同一個 recipe 可以被多個 layer 的 `.bbappend` 修改。查看 layer priority：

```bash
bitbake-layers show-layers
```

查看 append：

```bash
bitbake-layers show-appends | grep -A20 -B2 '<recipe>'
```

查看變數最終值：

```bash
bitbake -e <recipe> | less
bitbake -e <recipe> | grep -n '^SRC_URI='
bitbake -e <recipe> | grep -n '^PACKAGECONFIG='
```

建議不要只靠 layer priority 猜結果；以 `bitbake-layers show-appends` 與 `bitbake -e` 展開值為準。若多個 layer 都在改同一變數，盡量用 `:append`、`:prepend`、`:remove` 表達意圖。

#### 7.5.8 常見錯誤與排查

| 現象 | 可能方向 | 檢查方式 |
|------|----------|----------|
| `.bbappend` 沒套上 | 檔名版本不合、layer 未加入、`BBFILES` pattern 不含路徑 | `bitbake-layers show-appends`、`show-layers`、`conf/layer.conf` |
| `No recipes available for ...bbappend` | append 找不到對應 recipe | 確認 recipe 是否存在、版本是否匹配、branch 是否一致 |
| `file://xxx.patch` 找不到 | `FILESEXTRAPATHS` 或目錄結構不對 | `bitbake -e <recipe> | grep '^FILESPATH='` |
| patch 無法套用 | source revision 不符、patch context 改變、patch 順序不對 | `log.do_patch`、`WORKDIR`、`quilt` |
| `do_install` 成功但 package 沒檔案 | 安裝到 `${B}` 而非 `${D}`，或 `FILES:${PN}` 未涵蓋 | `WORKDIR/image`、`packages-split`、`log.do_package_qa` |
| `installed-vs-shipped` QA issue | 檔案進 `${D}` 但沒被任何 package 收走 | 補 `FILES:${PN}:append` 或調整安裝路徑 |
| 修改後結果沒變 | task stamp / sstate 命中，或改到錯的 variant | `bitbake -c cleansstate <recipe>`、`bitbake -e` |
| 只想改 target 卻影響 native | 缺少 class override | 使用 `:class-target` 或 `:class-native` |
| 只想改某板子卻影響全部 machine | 缺少 machine override | 使用 `:append:<machine>` 或 machine-specific 檔案路徑 |

排查順序：

```bash
bitbake-layers show-layers
bitbake-layers show-recipes <recipe>
bitbake-layers show-appends | grep -A10 -B2 '<recipe>'
bitbake -e <recipe> | grep '^FILESPATH='
bitbake -e <recipe> | grep '^SRC_URI='
bitbake -e <recipe> | grep '^PACKAGECONFIG='
bitbake -c patch -f <recipe>
bitbake -c compile -f <recipe>
bitbake -c install -f <recipe>
```

#### 7.5.9 BMC / OpenBMC 常見場景

加入平台設定檔：

```bitbake
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"
SRC_URI:append = " file://platform.conf"

do_install:append() {
    install -d ${D}${sysconfdir}/platform
    install -m 0644 ${WORKDIR}/platform.conf ${D}${sysconfdir}/platform/platform.conf
}

FILES:${PN}:append = " ${sysconfdir}/platform/platform.conf"
```

加入 systemd override：

```bitbake
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"
SRC_URI:append = " file://10-platform.conf"

do_install:append() {
    install -d ${D}${systemd_system_unitdir}/my-service.service.d
    install -m 0644 ${WORKDIR}/10-platform.conf ${D}${systemd_system_unitdir}/my-service.service.d/10-platform.conf
}

FILES:${PN}:append = " ${systemd_system_unitdir}/my-service.service.d/10-platform.conf"
```

加入 kernel config fragment 或 DTS patch：

```bitbake
FILESEXTRAPATHS:prepend := "${THISDIR}/${BPN}:"
SRC_URI:append:my-bmc-machine = " file://my-bmc.cfg"
SRC_URI:append:my-bmc-machine = " file://0001-arm-dts-add-my-platform-sensors.patch"
```

驗證重點：patch 是否套用到正確 kernel source、deploy 的 DTB 是否為目標 machine 使用的 DTB、實機 `/sys/firmware/fdt` 反編譯後是否包含預期 node。

#### 7.5.10 本章重點

1. `.bbappend` 一律放在自己的 layer，不直接修改 upstream / vendor layer。
2. 檔名優先使用 `recipe_%.bbappend`，除非 patch 嚴格綁定特定版本。
3. 有 `file://` patch 或本地檔案時，補上 `FILESEXTRAPATHS`。
4. native / nativesdk 相關 append 優先評估 `${BPN}` 或 `files/` 目錄。
5. 追加 list-like 變數時注意空格，例如 `SRC_URI:append = " file://x.patch"`。
6. 優先使用 `:append`、`:prepend`、`:remove`，非必要不要直接 `=` 覆寫整個變數。
7. 要進 package 的檔案應安裝到 `${D}`，並確認 `FILES:${PN}` 涵蓋該路徑。
8. 用 `:class-target`、`:class-native`、machine override 控制影響範圍。
9. 新增 append 後先跑 `bitbake-layers show-appends`，再用 `bitbake -e` 檢查變數展開值。
10. 修改 recipe 行為後，至少驗證 patch、configure、compile、install、package；若會進 image，再重建 image 或 rootfs。

#### 7.5.11 本章參考資料

- Yocto Project Development Tasks Manual - Understanding and Creating Layers: https://docs.yoctoproject.org/dev-manual/layers.html
- Yocto Project Reference Manual - Append Files: https://docs.yoctoproject.org/ref-manual/terms.html#term-Append-Files
- BitBake User Manual - Syntax and Operators: https://docs.yoctoproject.org/bitbake/bitbake-user-manual/bitbake-user-manual-metadata.html
- Yocto Project Reference Manual - Variables: https://docs.yoctoproject.org/ref-manual/variables.html

### 7.6 使用 devtool 修改原始碼並產出補丁（Patch）

在上一章整理了 `.bbappend`。`.bbappend` 適合追加 patch、設定檔、systemd override、編譯參數或安裝步驟；但若你要反覆修改套件原始碼，例如修 bug、加功能、調整 C/C++/Python 程式邏輯，直接改 `tmp/work/` 會有維護風險。

`devtool` 是 Yocto / OpenEmbedded 提供的開發輔助工具，用來把「取出原始碼 → 修改 → 建置 → 測試 → 產出 patch → 收回 layer」整理成可追蹤流程。官方文件也將 `devtool` 定位為與 `bitbake` 搭配使用、協助 build、test、package software 的命令列工具。

#### 7.6.1 為什麼不要直接改 tmp/work/

| 問題 | 說明 | 建議處理 |
|------|------|----------|
| 修改會消失 | `bitbake -c clean <recipe>`、重新 unpack 或 sstate 還原時，`tmp/work/` 修改可能被清掉 | 用 `devtool modify` 把 source 移到 workspace |
| patch 整理麻煩 | 手動 `git diff`、複製 patch、修改 `SRC_URI` 容易漏步驟 | 用 `devtool finish` 或 `devtool update-recipe` |
| 修改紀錄不清楚 | 修改多個檔案後不易回溯 | 在 workspace source tree 用 Git commit 管理 |
| 不易分享 | 修改只在本機 workdir，很難給其他人重建 | 把 commit 轉成 patch，放回指定 layer |
| 可能改錯 variant | 例如想改 target，卻改到 `-native` | 用 `devtool status`、`bitbake -e` 檢查 |

#### 7.6.2 devtool 是什麼？

`devtool` 常用於 recipe 開發、source 修改、target 部署測試與 patch 收尾。它的指令風格類似 Git：主命令加 subcommand，例如 `modify`、`build`、`deploy-target`、`update-recipe`、`finish`、`reset`、`status`。

對既有 recipe 來說，`devtool` 主要做幾件事：

1. 建立或使用 `build/workspace/` 這個 workspace layer。
2. 把 recipe 的 source tree 放到 `workspace/sources/<recipe>/`，通常會是 Git repository。
3. 在 `workspace/appends/` 產生暫時用的 `.bbappend`。
4. 透過 `externalsrc` 與 `EXTERNALSRC` 讓 BitBake 改用 workspace 裡的 source tree。
5. 開發完成後，把 Git commit 轉成 patch，收回原 recipe 或指定 layer。

典型 workspace 結構：

```text
build/workspace/
├── appends/
│   └── <recipe>_*.bbappend
├── conf/
│   └── layer.conf
├── recipes/
├── sources/
│   └── <recipe>/
└── attic/
```

#### 7.6.3 devtool modify 的運作機制

執行：

```bash
devtool modify zstd-native
```

概念流程：

```text
devtool modify zstd-native
        │
        ├─ 讀取目前 build environment 與 recipe metadata
        ├─ 依 SRC_URI 取得並展開 source
        ├─ 將 source tree 放到 build/workspace/sources/zstd-native/
        ├─ 建立或使用 Git repository，讓修改可用 commit 管理
        ├─ 在 build/workspace/appends/ 建立暫時 .bbappend
        └─ 透過 externalsrc / EXTERNALSRC 讓 BitBake 改用 workspace source
```

暫時 `.bbappend` 的常見概念如下；實際內容會依 Yocto 版本、recipe、source layout 而有所不同：

```bitbake
inherit externalsrc

EXTERNALSRC:pn-zstd-native = "/home/yocto/poky/build/workspace/sources/zstd-native"
EXTERNALSRC_BUILD:pn-zstd-native = "/home/yocto/poky/build/workspace/sources/zstd-native"
```

`externalsrc` class 的用途，是讓 recipe 從外部 source tree 建置，而不是照一般流程從 `DL_DIR` 擷取、展開到 `WORKDIR` 後再建置。使用 devtool 時，外部 source tree 通常就是 `build/workspace/sources/<recipe>/`。

#### 7.6.4 實際流程：以 zstd-native 為例

`zstd-native` 是 build host 端工具；若目標是修改會進 BMC rootfs 的 target 套件，請確認 recipe 名稱不是 `-native` 版本。

Step 1：確認 recipe 與 layer 狀態：

```bash
bitbake-layers show-layers
bitbake-layers show-recipes zstd
bitbake -e zstd-native | grep -E '^(PN|BPN|PV|S|B|WORKDIR)='
```

第一次處理時，可先建置一次：

```bash
bitbake zstd-native
```

Step 2：取出 source：

```bash
devtool modify zstd-native
```

檢查 workspace：

```bash
ls build/workspace
find build/workspace -maxdepth 3 -type f | sort | head -50
devtool status
bitbake -e zstd-native | grep '^EXTERNALSRC'
bitbake -e zstd-native | grep '^EXTERNALSRC_BUILD'
```

Step 3：修改 source：

```bash
cd build/workspace/sources/zstd-native

git status
vim lib/zstd.h

git diff
```

Step 4：提交修改：

```bash
git add lib/zstd.h
git commit -s -m "zstd: fix platform build issue"
```

建議加 `-s` 產生 Signed-off-by。若要送 upstream，commit message 建議包含問題、原因、修改內容與測試方式。

Step 5：建置與測試：

```bash
devtool build zstd-native
# 或
bitbake zstd-native
```

檢查安裝結果：

```bash
bitbake -e zstd-native | grep '^WORKDIR='
find tmp/work -path '*zstd-native*image*' -type f | head
find tmp/work -path '*zstd-native*image*include*zstd.h' -print
```

如果測試失敗，回到 workspace source 修改，再 commit 或 amend，然後重新 build。這段循環不需要重新 fetch / unpack source。

#### 7.6.5 產出 patch：update-recipe 與 finish

完成修改後，常見有兩種收尾方式。

##### 方式 A：devtool update-recipe

```bash
devtool update-recipe zstd-native
```

`update-recipe` 會把 workspace source tree 的提交轉成 patch，並更新 recipe metadata。預設行為可能會修改原 recipe 所在 layer；若該 layer 是 upstream / vendor layer，需先確認是否符合團隊流程。

適用情境：

- recipe 是你自己維護的 layer 中的 recipe。
- 你正在準備把修正送回該 layer。
- 專案流程允許直接更新原 recipe 所在 layer。

收尾後檢查：

```bash
git status
find .. -name '000*.patch' | grep zstd
bitbake-layers show-appends | grep -A5 -B2 zstd || true
```

##### 方式 B：devtool finish

若不想修改原 recipe 所在 layer，希望把 patch 與 `.bbappend` 放到自己的 layer，建議用：

```bash
devtool finish zstd-native ../meta-my-layer
```

`finish` 會把 workspace 中對 recipe 的修改整理回指定 layer，通常會產生 patch 與對應 `.bbappend`，接著移除 workspace 中該 recipe 的 active 狀態。實際輸出路徑會依 recipe 原本分類、layer 結構、Yocto 版本與 devtool 判斷而有所不同；完成後請直接檢查結果。

```bash
find ../meta-my-layer -path '*zstd*' -type f | sort
git -C ../meta-my-layer status
```

收尾後驗證：

```bash
devtool status
bitbake-layers show-appends | grep -A10 -B2 zstd
bitbake -c cleansstate zstd-native
bitbake zstd-native
```

BMC platform patch 建議優先使用 `devtool finish <recipe> <platform-layer>`，讓差異留在自己的 layer，不直接寫回 OE-Core、meta-phosphor、SoC vendor layer。

#### 7.6.6 update-recipe、finish、手寫 .bbappend 的選擇

| 方式 | 產出位置 | 適合情境 | 注意事項 |
|------|----------|----------|----------|
| `devtool update-recipe <recipe>` | 通常更新 recipe 所在 layer | recipe 是自己維護，或要回寫原 layer | 可能修改 upstream / vendor layer，需先確認流程 |
| `devtool finish <recipe> <layer>` | 指定 layer | 平台客製化、BMC porting、產品差異 | 完成後要確認 `.bbappend` 與 patch 路徑 |
| 手寫 `.bbappend` + patch | 自己指定 | 已有現成 patch，或修改很小且不需 workspace 流程 | patch 內容與 `SRC_URI` 要自行維護 |
| 改 `SRC_URI` 指向 fork | 自己維護 recipe / bbappend | 長期維護大型 fork | 要管理 branch、SRCREV、授權與同步策略 |

#### 7.6.7 devtool 常用指令

| 指令 | 說明 |
|------|------|
| `devtool modify <recipe>` | 取出既有 recipe 的 source 到 workspace，準備修改 |
| `devtool build <recipe>` | 建置 workspace 中的 recipe |
| `devtool deploy-target <recipe> <target>` | 將 recipe 安裝結果部署到 live target，通常透過 SSH |
| `devtool undeploy-target <recipe> <target>` | 從 live target 移除先前部署的檔案 |
| `devtool update-recipe <recipe>` | 將 workspace 修改整理成 patch 並更新 recipe metadata |
| `devtool finish <recipe> <layer>` | 將 workspace 修改整理回指定 layer，並結束該 recipe 的 workspace 狀態 |
| `devtool reset <recipe>` | 從 workspace 移除該 recipe 的 active 狀態 |
| `devtool status` | 顯示目前 workspace 管理中的 recipes |
| `devtool edit-recipe <recipe>` | 開啟 workspace 中的 recipe / append 供檢查或修改 |
| `devtool build-image <image>` | 建置包含 workspace recipe package 的 image |

#### 7.6.8 deploy-target：部署到 live BMC 測試

若 target BMC 已開啟 SSH，且 image 內有必要 runtime dependency，可以用 `deploy-target` 快速把 recipe 的安裝結果推到目標機器：

```bash
devtool deploy-target <recipe> root@<bmc-ip>
```

常見測試流程：

```bash
devtool build <recipe>
devtool deploy-target <recipe> root@<bmc-ip>

ssh root@<bmc-ip> 'systemctl restart <service>.service'
ssh root@<bmc-ip> 'journalctl -u <service>.service -b --no-pager | tail -100'

devtool undeploy-target <recipe> root@<bmc-ip>
```

注意事項：

- `deploy-target` 適合開發測試，不等於正式 OTA / image update。
- 若 recipe 有 postinst、systemd preset、user/group、D-Bus policy 或多 package split，部署結果需額外確認。
- 若測的是 BMC service，建議保留 journal、service status、D-Bus object 狀態與 Redfish/IPMI 行為。

#### 7.6.9 常見問題與排查

| 問題 | 可能原因 | 檢查 / 處理方式 |
|------|----------|------------------|
| `devtool modify` 失敗 | `SRC_URI` 無法 fetch、相依 layer 未載入、recipe 解析失敗 | 先跑 `bitbake -c fetch <recipe>`、`bitbake-layers show-recipes <recipe>` |
| build 仍吃舊 source | workspace append 未生效，或 recipe variant 不對 | `devtool status`、`bitbake -e <recipe> | grep '^EXTERNALSRC'` |
| `update-recipe` 沒產出 patch | Git working tree 沒有 commit，或變更不是 source patch 類型 | `git status`、`git log --oneline`，先 commit 再收尾 |
| `finish` 找不到 layer | layer path 錯、未建立 layer、或不符合 layer 結構 | `bitbake-layers show-layers`、確認 `conf/layer.conf` |
| 收尾後 build 失敗 | patch context 不符、`.bbappend` 路徑不對、`FILESEXTRAPATHS` 不符合 | `bitbake-layers show-appends`、`log.do_patch`、`bitbake -e <recipe>` |
| `deploy-target` 後 service 起不來 | runtime dependency 未在 target image、中間狀態與完整 image 不一致 | 看 `journalctl`、`ldd`、D-Bus policy、systemd unit |
| `devtool reset` 後找不到修改 | 修改可能移到 `workspace/attic/` 或尚未 commit | 檢查 `build/workspace/attic/` 與 Git 狀態 |

常用排查指令：

```bash
devtool status
find build/workspace/appends -type f -maxdepth 2 -print

git -C build/workspace/sources/<recipe> status
git -C build/workspace/sources/<recipe> log --oneline --decorate -5

bitbake -e <recipe> | grep '^EXTERNALSRC'
bitbake -e <recipe> | grep '^S='
bitbake -e <recipe> | grep '^B='

bitbake-layers show-appends | grep -A10 -B2 '<recipe>'
```

#### 7.6.10 BMC / OpenBMC 實務建議

- 修改 OpenBMC service source 時，先確認 recipe 名稱與 service 名稱不一定相同。可用 `bitbake-layers show-recipes | grep <keyword>` 搜尋。
- 若只是改 JSON config、systemd override、D-Bus policy 或安裝路徑，優先評估 `.bbappend`，不一定需要 `devtool`。
- 若是改 C++ daemon、host interface、sensor service、fan control service、Redfish backend，建議用 `devtool modify` 管理 source 變更。
- 若修改會長期保留在專案，收尾時優先用 `devtool finish <recipe> <platform-layer>`，把 patch 留在平台 layer。
- 若準備送 upstream，commit message 建議包含 issue、root cause、修改內容、測試方式，並保留 Signed-off-by。
- 對 BMC target 做 `deploy-target` 測試後，仍需回到 image build 驗證，避免 live target 測試與正式 rootfs 組成不同。

#### 7.6.11 最佳實踐

1. 不要把 `tmp/work/` 內的手動修改當作正式成果。
2. 用 `devtool modify` 進入 source 開發流程，用 Git commit 管理每一組可解釋的修改。
3. 每次收尾前先確認 `git status` 是乾淨狀態，並檢查 commit message。
4. 平台差異優先用 `devtool finish <recipe> <platform-layer>` 收回自己的 layer。
5. 收尾後執行 `devtool status`，確認 workspace 不再覆蓋該 recipe。
6. 用 `bitbake-layers show-appends` 與 `bitbake -e` 確認正式 layer 中的 append / patch 已生效。
7. 至少從 `do_patch`、`do_compile`、完整 `bitbake <recipe>` 驗證一次；若會進 image，再重建 image。
8. 若是 live target 測試，`deploy-target` 只能視為開發驗證，不能取代正式 update / image boot test。

#### 7.6.12 回查結果

本章回查後已補強：

- 補上 `devtool modify`、workspace layer、`externalsrc`、`EXTERNALSRC` 的關係。
- 補上 `zstd-native` 與 target recipe 的差異提醒，避免把 host tool 變更誤認為會進 BMC rootfs。
- 補上 `update-recipe` 與 `finish` 的使用差異，並建議 BMC platform patch 優先收回自己的 layer。
- 補上 `deploy-target` 的用途與限制。
- 補上收尾後的驗證流程：`devtool status`、`show-appends`、`bitbake -e`、`cleansstate` 後重建。

#### 7.6.13 本章參考資料

- Yocto Project Development Tasks Manual - Using the devtool command-line tool: [https://docs.yoctoproject.org/dev/dev-manual/devtool.html](https://docs.yoctoproject.org/dev/dev-manual/devtool.html)
- Yocto Project Reference Manual - devtool Quick Reference: [https://docs.yoctoproject.org/ref-manual/devtool-reference.html](https://docs.yoctoproject.org/ref-manual/devtool-reference.html)
- Yocto Project Reference Manual - Classes / externalsrc: [https://docs.yoctoproject.org/ref-manual/classes.html](https://docs.yoctoproject.org/ref-manual/classes.html)

### 7.7 撰寫一個自訂的 .bb Recipe

前面章節已經說明兩種常見情境：用 `.bbappend` 修改既有 recipe 的 metadata，或用 `devtool` 對既有 recipe 的原始碼產出 patch。這一章處理另一種情境：**套件還不存在，需要自己新增一個 `.bb` recipe**。

在 BMC / OpenBMC porting 中，新增 recipe 常見於：

- 新增平台自有 daemon、CLI 工具或 factory tool。
- 加入公司內部 library、測試程式或 provisioning utility。
- 包裝客戶提供的 binary、script、configuration bundle。
- 加入 Yocto / OpenEmbedded 尚未收錄的開源專案。
- 建立 OpenBMC 平台 service、systemd unit、D-Bus config、Redfish backend 相關工具。

Recipe 的目標不是只讓程式「能編譯」，而是讓 BitBake 能以可重現方式完成：取得 source、套用 patch、設定、編譯、安裝、切 package、通過 QA、加入 image，並留下授權資訊。

#### 7.7.1 Recipe 是什麼？

Recipe 是 `.bb` 檔案，屬於 Yocto / OpenEmbedded metadata 的核心。每一個要被 OpenEmbedded build system 建置的軟體元件，都需要 recipe 描述如何取得、建置、安裝與打包。

最小概念包含三件事：

1. **去哪裡拿原始碼**：`SRC_URI`、`SRCREV`、checksum。
2. **怎麼建置它**：`inherit` 哪個 class、`do_configure`、`do_compile`。
3. **安裝到哪裡並怎麼打包**：`do_install`、`${D}`、`FILES:${PN}`、`PACKAGES`。

常見 recipe 欄位：

| 區塊 | 常見變數 / task | 說明 |
|------|-----------------|------|
| 基本資訊 | `SUMMARY`、`DESCRIPTION`、`HOMEPAGE`、`SECTION` | 給人與 package manager 看的套件資訊 |
| 授權 | `LICENSE`、`LIC_FILES_CHKSUM` | Yocto 會檢查授權檔案 checksum，避免授權內容變更未被注意 |
| 原始碼 | `SRC_URI`、`SRCREV`、`S`、`UNPACKDIR` | source、patch、本地檔案、Git revision、source directory |
| 相依 | `DEPENDS`、`RDEPENDS:${PN}`、`RRECOMMENDS:${PN}` | build-time 與 runtime dependency |
| 建置 | `inherit`、`EXTRA_OECMAKE`、`EXTRA_OEMESON`、`do_compile` | 決定使用 Makefile、Autotools、CMake、Meson、Python 等流程 |
| 安裝 | `do_install`、`${D}`、`${bindir}`、`${sysconfdir}` | 把檔案安裝到暫存 root，供後續 package 使用 |
| 打包 | `PACKAGES`、`FILES:${PN}`、`CONFFILES:${PN}` | 決定哪些檔案被放進哪些 package |
| 服務 | `inherit systemd`、`SYSTEMD_SERVICE:${PN}` | 安裝與啟用 systemd service |

#### 7.7.2 建立 recipe 的三種方式

| 方式 | 說明 | 適用情境 |
|------|------|----------|
| 手寫 `.bb` | 從空白 recipe 開始撰寫 | 熟悉 BitBake 語法，或內容很簡單 |
| `recipetool create` | 根據本地 source、tarball、Git URL 產生 recipe 骨架 | 快速起步，尤其適合不確定 build system 時 |
| `devtool add` | 產生 recipe，同時建立 workspace 方便後續修改 source | 新增套件後還要繼續改 source、補 patch、測試 |

實務建議：就算已經熟悉 Yocto，也可以先用 `recipetool create` 或 `devtool add` 產生骨架，再手動修整 recipe。官方文件也將 `devtool add`、`recipetool create`、參考相似 recipe 列為建立 base recipe 的常見入口。

#### 7.7.3 Recipe 放在哪裡？

Recipe 應放在自己維護的 layer，不要直接修改 OE-Core、meta-phosphor、SoC vendor layer 或客戶提供的 BSP layer。

建議目錄命名：

```text
meta-my-layer/
└── recipes-<category>/
    └── <recipe-name>/
        ├── files/
        │   ├── <local-source-or-config>
        │   └── <service-or-patch>
        └── <recipe-name>_<version>.bb
```

常見分類：

| 分類目錄 | 適合內容 |
|----------|----------|
| `recipes-apps/`、`recipes-extended/` | 一般應用程式、CLI 工具 |
| `recipes-devtools/` | 開發工具、build helper、factory tool |
| `recipes-kernel/` | kernel module、kernel fragment 相關 recipe |
| `recipes-bsp/` | bootloader、board-level BSP component |
| `recipes-phosphor/` | OpenBMC phosphor 相關 service / config |
| `recipes-support/` | library、helper、support package |
| `recipes-core/` | system core 元件；需謹慎使用 |

重點不是目錄名稱本身，而是 layer 的 `conf/layer.conf` 中 `BBFILES` pattern 要包含這些 `.bb` 檔案。新增 recipe 後可用：

```bash
bitbake-layers show-recipes hello
bitbake-layers show-layers
```

確認 BitBake 能看到你的 layer 與 recipe。

#### 7.7.4 手寫 Hello World recipe

##### Step 1：建立 layer

若還沒有自己的 layer：

```bash
bitbake-layers create-layer ../meta-my-layer
bitbake-layers add-layer ../meta-my-layer
bitbake-layers show-layers
```

##### Step 2：建立目錄與原始碼

```bash
mkdir -p ../meta-my-layer/recipes-helloworld/hello/files
```

建立 `helloworld.c`：

```c
#include <stdio.h>

int main(void)
{
    printf("Hello world!\n");
    return 0;
}
```

放到：

```text
../meta-my-layer/recipes-helloworld/hello/files/helloworld.c
```

##### Step 3：建立 recipe

建立：

```text
../meta-my-layer/recipes-helloworld/hello/hello_1.0.bb
```

內容：

```bitbake
SUMMARY = "Simple hello world application"
DESCRIPTION = "A minimal single-file C application used to demonstrate a custom Yocto recipe."
HOMEPAGE = "https://example.com/hello"
SECTION = "examples"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://helloworld.c"

# 新版 Yocto 常見寫法：明確指定 local file unpack 目的地與 source directory
S = "${WORKDIR}/sources"
UNPACKDIR = "${S}"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} helloworld.c -o helloworld
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 helloworld ${D}${bindir}/helloworld
}
```

補充：部分舊版 Yocto 範例會寫 `S = "${WORKDIR}"`，因為 `file://helloworld.c` 會被放在 `WORKDIR` 下。近年 Yocto 文件逐步將 unpack 目的地顯式化，看到 `S = "${WORKDIR}/sources"` 與 `UNPACKDIR = "${S}"` 屬於合理寫法。若專案 branch 較舊、不支援 `UNPACKDIR`，可改回 `S = "${WORKDIR}"`，並以實際 `bitbake -e hello | grep '^S='` 與 `WORKDIR` 結果為準。

##### Step 4：建置 recipe

```bash
bitbake hello
```

注意 target 名稱通常是 `PN`，也就是 recipe 檔名中第一個 `_` 前面的部分。`hello_1.0.bb` 對應：

```text
PN = "hello"
PV = "1.0"
PR = "r0"   # 未指定時常見預設
```

建置後檢查安裝暫存 root：

```bash
bitbake -e hello | grep '^WORKDIR='
find tmp/work -path '*hello*image*helloworld' -print
```

也可檢查 packages split：

```bash
bitbake -c package -f hello
find tmp/work -path '*hello*packages-split*helloworld' -print
```

#### 7.7.5 把 recipe 加入 image

單獨 `bitbake hello` 只代表 recipe 可以建置，並不代表它會進入 image。要放進 rootfs，常見做法有三種。

##### 方法 A：local.conf 開發測試

```bitbake
IMAGE_INSTALL:append = " hello"
```

這適合本機快速測試，不建議作為正式專案設定。

##### 方法 B：image recipe 或 image `.bbappend`

例如針對 `core-image-minimal`：

```text
meta-my-layer/
└── recipes-core/
    └── images/
        └── core-image-minimal.bbappend
```

內容：

```bitbake
IMAGE_INSTALL:append = " hello"
```

##### 方法 C：packagegroup 管理產品內容

BMC / OpenBMC 專案通常會把產品 feature 收斂到 packagegroup，方便不同 SKU / image 共用：

```text
meta-my-layer/
└── recipes-core/
    └── packagegroups/
        └── packagegroup-my-platform.bb
```

```bitbake
SUMMARY = "My platform package group"
LICENSE = "MIT"

inherit packagegroup

RDEPENDS:${PN} = "    hello "
```

再把 packagegroup 加入 image：

```bitbake
IMAGE_INSTALL:append = " packagegroup-my-platform"
```

#### 7.7.6 重要變數說明

| 變數 | 說明 | 常見注意事項 |
|------|------|--------------|
| `SUMMARY` | 簡短摘要 | 建議一行說清楚用途 |
| `DESCRIPTION` | 較完整描述 | 未設定時常由 `SUMMARY` 補上，但建議明確填寫 |
| `SECTION` | 套件分類 | 可協助套件管理與閱讀 metadata |
| `LICENSE` | 授權名稱 | 不清楚授權時先釐清，避免量產法務風險 |
| `LIC_FILES_CHKSUM` | 授權檔案 checksum | source 授權文字變更時會提醒維護者重新確認 |
| `SRC_URI` | source、patch、本地檔案來源 | `file://`、`git://`、`https://` 都常見 |
| `SRCREV` | Git commit revision | 不建議量產 recipe 使用 `${AUTOREV}` |
| `S` | source directory | `do_configure` / `do_compile` 通常在這裡跑 |
| `B` | build directory | out-of-tree build 時與 `S` 分開 |
| `D` | install destination root | `do_install` 必須安裝到 `${D}` 底下 |
| `DEPENDS` | build-time dependency | 例如需要 header / library 供編譯使用 |
| `RDEPENDS:${PN}` | runtime dependency | 目標機執行時需要的 package |
| `FILES:${PN}` | 指定 package 收哪些檔案 | 避免 installed-vs-shipped QA issue |
| `CONFFILES:${PN}` | 標示設定檔 | package upgrade 時會保護使用者修改 |

#### 7.7.7 `SRC_URI` 常見來源

##### 本地檔案

```bitbake
SRC_URI = "file://helloworld.c"
```

檔案通常放在 `files/` 或 `${PN}/` 子目錄。若放在自訂路徑，需搭配 `FILESEXTRAPATHS`。

##### Tarball

```bitbake
SRC_URI = "https://example.com/releases/myapp-${PV}.tar.gz"
SRC_URI[sha256sum] = "<sha256>"

S = "${WORKDIR}/myapp-${PV}"
```

遠端 tarball 建議固定 checksum，避免 upstream 檔案變更但 recipe 不易察覺。

##### Git repository

```bitbake
SRC_URI = "git://github.com/example/myapp.git;protocol=https;branch=main"
SRCREV = "0123456789abcdef0123456789abcdef01234567"

S = "${WORKDIR}/git"
```

量產或 CI 建議固定 `SRCREV`。`${AUTOREV}` 適合短期開發，不適合需要可重現的 release build。

##### 加 patch

```bitbake
SRC_URI = "    git://github.com/example/myapp.git;protocol=https;branch=main     file://0001-fix-build-on-arm.patch "
```

patch 會在 `do_patch` 階段套用。若 patch 順序有要求，依 `SRC_URI` 順序列出。

#### 7.7.8 不同建構系統的 recipe 寫法

##### 單一 C 檔案

```bitbake
do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} main.c -o myapp
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 myapp ${D}${bindir}/
}
```

##### Makefile 專案

一般不需要 `inherit make`；常見做法是直接使用 `oe_runmake`。`oe_runmake` 會帶入 Yocto 設定好的 make flags 與環境，較適合交叉編譯。

```bitbake
do_compile() {
    oe_runmake
}

do_install() {
    oe_runmake install DESTDIR=${D}
}
```

若 upstream Makefile 不支援 `DESTDIR`，可改為手動安裝：

```bitbake
do_install() {
    install -d ${D}${bindir}
    install -m 0755 myapp ${D}${bindir}/
}
```

##### Autotools

```bitbake
inherit autotools

EXTRA_OECONF = "--disable-tests"
```

通常不需要自行寫 `do_configure`、`do_compile`、`do_install`，除非 upstream build system 有特殊需求。

##### CMake

```bitbake
inherit cmake

EXTRA_OECMAKE = "-DBUILD_TESTING=OFF -DBUILD_EXAMPLES=OFF"
```

##### Meson

```bitbake
inherit meson

EXTRA_OEMESON = "-Dtests=false"
```

##### Python setuptools

```bitbake
inherit setuptools3

RDEPENDS:${PN} += "python3-core"
```

不同 Yocto branch 對 Python build backend 支援可能不同。若是 pyproject / PEP517 專案，需依 branch 中可用的 Python class 選擇，例如 `python_setuptools_build_meta`、`python_poetry_core` 等。

##### 只包 script

```bitbake
SUMMARY = "Simple BMC helper script"
LICENSE = "CLOSED"
SRC_URI = "file://bmc-helper.sh"

S = "${WORKDIR}/sources"
UNPACKDIR = "${S}"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 bmc-helper.sh ${D}${bindir}/bmc-helper
}
```

若公司內部封閉工具無法公開授權，可使用 `LICENSE = "CLOSED"`；但仍需符合公司與客戶的 legal / security policy。

#### 7.7.9 加入 systemd service

BMC service 常需要 recipe 同時安裝 binary、設定檔與 systemd unit。

目錄：

```text
meta-my-layer/
└── recipes-apps/
    └── mydaemon/
        ├── files/
        │   ├── mydaemon.c
        │   └── mydaemon.service
        └── mydaemon_1.0.bb
```

`mydaemon.service`：

```ini
[Unit]
Description=My BMC daemon
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/mydaemon
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
```

`mydaemon_1.0.bb`：

```bitbake
SUMMARY = "My BMC daemon"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "    file://mydaemon.c     file://mydaemon.service "

S = "${WORKDIR}/sources"
UNPACKDIR = "${S}"

inherit systemd

SYSTEMD_SERVICE:${PN} = "mydaemon.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} mydaemon.c -o mydaemon
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 mydaemon ${D}${bindir}/

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 mydaemon.service ${D}${systemd_system_unitdir}/
}

FILES:${PN} += "${systemd_system_unitdir}/mydaemon.service"
```

如果 service 還需要 D-Bus policy、tmpfiles、sysusers 或設定檔，請一併安裝，並確認 `FILES:${PN}` 涵蓋所有路徑。

#### 7.7.10 Package split：把檔案分成多個 package

單一 recipe 可以產生多個 package。常見情境：主程式、設定檔、開發檔、測試工具分開。

```bitbake
PACKAGES += "${PN}-tools"

FILES:${PN} = "    ${bindir}/mydaemon     ${systemd_system_unitdir}/mydaemon.service "

FILES:${PN}-tools = "    ${bindir}/mydaemon-cli "

RDEPENDS:${PN}-tools = "${PN}"
```

檢查 package split：

```bash
bitbake -c package -f mydaemon
find tmp/work -path '*mydaemon*packages-split*' -maxdepth 5 -type f | sort
```

若出現 `installed-vs-shipped` QA issue，通常代表檔案已安裝到 `${D}`，但沒有被任何 `FILES:*` 收進 package。

#### 7.7.11 recipetool create

`recipetool create` 可以根據 source 自動產生 base recipe。官方文件說明它會根據 source files 建立 recipe，並自動設定 pre-build information，例如 dependencies、license 與 checksums；使用時需要在 Build Directory 中並已 source build environment。

##### 本地 source

```bash
cd /path/to/myapp
recipetool create -o ../meta-my-layer/recipes-myapp/myapp/myapp_1.0.bb .
```

##### 遠端 tarball

```bash
recipetool create -o ../meta-my-layer/recipes-myapp/myapp/myapp_1.0.bb     https://github.com/example/myapp/archive/refs/tags/v1.0.tar.gz
```

##### 產生後建議檢查

```bash
sed -n '1,200p' ../meta-my-layer/recipes-myapp/myapp/myapp_1.0.bb
bitbake-layers show-recipes myapp
bitbake myapp
```

`recipetool` 的產出是骨架，不代表可以完全不看。仍需確認：

- `LICENSE` 與 `LIC_FILES_CHKSUM` 是否合理。
- `SRC_URI` 與 checksum 是否固定。
- `S` 是否指向正確 source directory。
- `DEPENDS` 是否足夠但不過度。
- 是否使用正確 class，例如 `cmake`、`meson`、`autotools`、`setuptools3`。
- `do_install` 是否真的把檔案裝到 `${D}`。
- 是否需要補 `FILES:${PN}`、`RDEPENDS:${PN}`、systemd 設定。

#### 7.7.12 devtool add：新增套件並進入開發模式

若新增 recipe 後還要繼續修改 source，`devtool add` 比 `recipetool create` 更適合。它會使用類似 `recipetool create` 的邏輯建立 recipe，同時建立 workspace，方便後續 patch 與測試。

常見形式：

```bash
# 從遠端 source 建立 recipe，source 放到 workspace
devtool add myapp https://github.com/example/myapp/archive/refs/tags/v1.0.tar.gz

# 指定本地 source tree
devtool add myapp /path/to/myapp
```

後續流程：

```bash
devtool build myapp
devtool finish myapp ../meta-my-layer
```

完成後仍需回到正式 layer 檢查 recipe 與 patch，並跑一次非 workspace 狀態的 `bitbake myapp`。

#### 7.7.13 常見問題與除錯

| 現象 | 可能方向 | 檢查方式 |
|------|----------|----------|
| BitBake 找不到 recipe | layer 未加入、`BBFILES` pattern 不含路徑、檔名不符合 `<name>_<version>.bb` | `bitbake-layers show-layers`、`bitbake-layers show-recipes <name>` |
| `file://` 檔案找不到 | 檔案不在 `files/`、`${PN}/`，或檔名大小寫不對 | `bitbake -e <recipe> | grep '^FILESPATH='` |
| 編譯時找不到 header / library | 缺少 build-time dependency | 補 `DEPENDS`，檢查 `log.do_compile` |
| 本機可編譯，Yocto 失敗 | Makefile 硬寫 `gcc`、忽略 `CC` / `CFLAGS` / `LDFLAGS` | patch Makefile 或傳入 `oe_runmake CC="${CC}"` |
| 安裝到 host `/usr/bin` | `do_install` 沒加 `${D}` | 所有安裝路徑都改成 `${D}${bindir}` 等 |
| `installed-vs-shipped` | 檔案在 `${D}` 但未被 package 收走 | 補 `FILES:${PN}` 或調整安裝路徑 |
| image 裡沒有程式 | 只建了 recipe，未加入 image | 檢查 `IMAGE_INSTALL`、packagegroup、`oe-pkgdata-util` |
| runtime 找不到 shared library | 缺少 runtime dependency 或 package split 不正確 | 補 `RDEPENDS:${PN}`，檢查 rootfs 與 `ldd` |
| systemd service 沒啟動 | 未 inherit systemd、`SYSTEMD_SERVICE` 不對、unit 未安裝 | 檢查 `${systemd_system_unitdir}`、`systemctl status` |

常用指令：

```bash
bitbake-layers show-recipes <recipe>
bitbake -e <recipe> | less
bitbake -e <recipe> | grep -E '^(PN|PV|S|B|D|WORKDIR|SRC_URI|DEPENDS)='
bitbake -c fetch <recipe>
bitbake -c unpack -f <recipe>
bitbake -c compile -f <recipe>
bitbake -c install -f <recipe>
bitbake -c package -f <recipe>
find tmp/work -path '*<recipe>*temp/log.do_*' | sort
find tmp/work -path '*<recipe>*image*' -type f | sort
find tmp/work -path '*<recipe>*packages-split*' -type f | sort
```

#### 7.7.14 BMC / OpenBMC recipe 檢查重點

| 類型 | 檢查重點 |
|------|----------|
| BMC daemon | systemd unit、restart policy、D-Bus name、journal log、runtime dependency |
| Sensor / fan service | Entity Manager config、D-Bus object path、threshold、failsafe 行為 |
| Factory tool | 是否只進 factory image、是否避免進正式 image、權限與安全風險 |
| Provisioning script | secret handling、重試機制、半寫入回復方式、log 是否洩漏敏感資訊 |
| Host interface tool | KCS/eSPI/LPC/PLDM/MCTP dependency、host state timing |
| Debug tool | 是否只在 debug image 或 development feature 啟用 |
| Binary-only package | 架構相容性、授權、strip 狀態、RPATH、shared library dependency |

#### 7.7.15 Recipe 提交前檢查清單

- [ ] recipe 放在自己的 layer，且 `bitbake-layers show-recipes <recipe>` 看得到。
- [ ] 檔名符合 `<PN>_<PV>.bb`，版本策略清楚。
- [ ] `SUMMARY`、`DESCRIPTION`、`HOMEPAGE`、`SECTION` 合理。
- [ ] `LICENSE` 正確，`LIC_FILES_CHKSUM` 已確認。
- [ ] `SRC_URI` 固定 source，遠端檔案有 checksum，Git source 固定 `SRCREV`。
- [ ] `S` / `UNPACKDIR` 符合目前 Yocto branch。
- [ ] 已選對 build class：`autotools`、`cmake`、`meson`、`setuptools3` 等。
- [ ] `DEPENDS` 與 `RDEPENDS:${PN}` 分別描述 build-time / runtime dependency。
- [ ] `do_install` 全部安裝到 `${D}` 底下。
- [ ] `FILES:${PN}` 涵蓋所有安裝檔案，沒有 `installed-vs-shipped` QA issue。
- [ ] 若有設定檔，評估是否加入 `CONFFILES:${PN}`。
- [ ] 若有 systemd service，確認 `inherit systemd`、`SYSTEMD_SERVICE:${PN}`、unit install path。
- [ ] `bitbake <recipe>` 可成功。
- [ ] `tmp/work/.../image/` 與 `packages-split/` 結果符合預期。
- [ ] 若要進 image，已透過 image append 或 packagegroup 加入，且完整 image build 通過。
- [ ] 若是 BMC service，已在 target 上驗證 service status、journal、D-Bus / Redfish / IPMI 行為。

#### 7.7.17 本章參考資料

- Yocto Project Development Tasks Manual - Writing a New Recipe: [https://docs.yoctoproject.org/dev/dev-manual/new-recipe.html](https://docs.yoctoproject.org/dev/dev-manual/new-recipe.html)
- Yocto Project Reference Manual - Variables Glossary: [https://docs.yoctoproject.org/ref-manual/variables.html](https://docs.yoctoproject.org/ref-manual/variables.html)
- Yocto Project Reference Manual - Tasks: [https://docs.yoctoproject.org/ref-manual/tasks.html](https://docs.yoctoproject.org/ref-manual/tasks.html)
- Yocto Project Reference Manual - devtool / recipetool Quick Reference: [https://docs.yoctoproject.org/ref-manual/devtool-reference.html](https://docs.yoctoproject.org/ref-manual/devtool-reference.html)


### 7.8 進階混合開發：devtool modify / update-recipe / finish

第 7.6 章已經整理 `devtool modify`、`devtool update-recipe`、`devtool finish` 的基本流程。本章更進一步釐清：**什麼時候該用 `update-recipe`，什麼時候該用 `finish`，以及在 BMC / OpenBMC 專案中如何避免 patch 放錯 layer、workspace 殘留、重複 patch 或 recipe metadata 沒被正式收回。**

先同步幾個核心觀念：

- `devtool modify <recipe>`：進入 workspace 開發模式，讓 BitBake 改用 `build/workspace/sources/<recipe>/` 的 source tree。
- `devtool update-recipe <recipe>`：把 workspace source tree 中的修改整理回 recipe metadata。預設通常會更新 recipe 所在的 layer；部分 Yocto branch 支援用選項指定 append 或 layer，實際以 `devtool update-recipe --help` 為準。
- `devtool finish <recipe> <layer>`：把 workspace 的成果收回指定 layer，並結束該 recipe 的 workspace 狀態。
- `devtool reset <recipe>`：移除 workspace 中該 recipe 的 active 狀態，讓 BitBake 不再使用 workspace source。

本章重點不是背指令，而是建立一個可回查、可交接、可進 CI 的開發策略。

#### 7.8.1 `update-recipe` 和 `finish` 的差異

很多人第一次使用 devtool 時，會把 `update-recipe` 與 `finish` 理解成「先 update，最後 finish」。這種流程不是完全不能做，但在專案維護上容易造成 patch 重複、原 layer 被改到、或 workspace 狀態與正式 layer 狀態混在一起。

較穩定的理解方式是：它們是兩種不同的收尾策略。

| 項目 | `devtool update-recipe` | `devtool finish` |
|------|--------------------------|------------------|
| 主要目的 | 將 workspace source 的修改套回 recipe metadata | 將 workspace 修改整理到指定 layer，並結束 workspace 狀態 |
| 常見產出位置 | 原 recipe 所在 layer；依版本與選項也可能產出 append | 你指定的 layer，例如 `../meta-my-layer` |
| 是否結束 workspace 狀態 | 通常不會，仍可繼續修改與建置 | 會結束該 recipe 的 workspace 狀態；可搭配選項保留 source tree |
| 適合情境 | recipe 就是你維護的 layer，或你準備把修正回寫原 layer | 平台差異、BMC product layer、客製 patch、避免碰 upstream / vendor layer |
| 風險 | 可能修改 OE-Core、meta-phosphor、SoC vendor layer 等不該直接改的地方 | 若指定錯 layer，patch 仍可能放錯位置；完成後需驗證 append 有被載入 |
| 檢查重點 | `git diff`、recipe 的 `SRC_URI`、patch 是否落在預期目錄 | `devtool status`、`show-appends`、`${FILESPATH}`、`log.do_patch` |

實務建議：

- 若修改是「要送回原本 recipe 所在 layer」的 bug fix，可考慮 `update-recipe`。
- 若修改是「平台客製化」或「產品差異」，優先用 `finish <recipe> <platform-layer>`。
- 不建議在同一輪修改中反覆混用 `update-recipe` 與 `finish`，除非你很清楚每一次產出的 patch 位置與 `SRC_URI` 狀態。

#### 7.8.2 使用前先確認目前狀態

進入 devtool 流程前，先固定幾個資訊，可以減少後續判讀成本。

```bash
# build environment 是否已初始化
bitbake-layers show-layers

# recipe 來源與 append 狀態
bitbake-layers show-recipes zstd
bitbake-layers show-appends | grep -A10 -B2 zstd || true

# recipe 重要變數
bitbake -e zstd-native | grep -E '^(PN|BPN|PV|S|B|WORKDIR|SRC_URI)='

# workspace 是否已有東西
devtool status || true
```

如果目標 patch 要進 `meta-my-layer`，也先確認 layer 已加入：

```bash
bitbake-layers show-layers | grep meta-my-layer
```

若 layer 還沒有建立：

```bash
bitbake-layers create-layer ../meta-my-layer
bitbake-layers add-layer ../meta-my-layer
```

#### 7.8.3 完整實戰：從 `modify` 到 `finish`

以下以 `zstd-native` 示範。提醒：`zstd-native` 是 build host 端工具，產物通常不會進 BMC rootfs。若你要改的是 target rootfs 內的套件，需要確認 recipe 名稱是否應該是 `zstd` 而不是 `zstd-native`。

##### Step 0：準備乾淨環境

```bash
# 確認沒有尚未提交的 metadata 修改
git status

# 先建置一次，排除 fetch / dependency 類問題
bitbake zstd-native
```

若你在多個 Git repository 組成的 Yocto source tree 中工作，也要分別檢查 platform layer、vendor layer、poky / openembedded-core 等 repository 的狀態。

##### Step 1：取出 source 到 workspace

```bash
devtool modify zstd-native
```

檢查：

```bash
devtool status
ls build/workspace/sources/zstd-native
find build/workspace/appends -type f -maxdepth 2 -print
bitbake -e zstd-native | grep '^EXTERNALSRC'
bitbake -e zstd-native | grep '^S='
```

這時 BitBake 會使用 workspace source tree，而不是原本 `tmp/work/.../git` 或 `tmp/work/.../<source>` 中的 source。

##### Step 2：先做未提交的快速測試

有時只是想確認方向，可先不 commit：

```bash
cd build/workspace/sources/zstd-native
vim lib/zstd.h

git diff
bitbake zstd-native
```

若測試方向不對，可直接還原：

```bash
git checkout -- lib/zstd.h
```

或如果已修改多個檔案，可先用：

```bash
git status
git diff --stat
```

整理後再決定是否保留。

##### Step 3：把有效修改提交成 commit

```bash
cd build/workspace/sources/zstd-native

git add lib/zstd.h
git commit -s -m "zstd: add platform debug marker"
```

建議原則：一個 commit 對應一個可說明的變更。若 patch 之後要送 upstream，commit message 應至少包含：問題描述、修改內容、測試方式。

##### Step 4：如果要回寫原 recipe，使用 `update-recipe`

如果這個 recipe 是自己維護的，或你準備把 patch 回送原 layer，可以使用：

```bash
devtool update-recipe zstd-native
```

接著檢查實際變更位置：

```bash
git status
find .. -name '000*.patch' | grep -E 'zstd|Zstd' || true
bitbake -e zstd-native | grep '^SRC_URI='
```

注意：`update-recipe` 通常不會結束 workspace 狀態。你仍然可以繼續修改 workspace source、commit，再次執行 `update-recipe`。

##### Step 5：如果要整理到平台 layer，使用 `finish`

若你的策略是把 patch 放到自己的 layer，例如 `meta-my-layer`，可直接用：

```bash
devtool finish zstd-native ../meta-my-layer
```

部分 Yocto branch 的 `finish` 支援保留 workspace source tree 的選項，例如 `--no-clean`。不同版本選項可能不同，請先確認：

```bash
devtool finish --help
```

若 branch 支援，且你想保留 workspace source 供對照：

```bash
devtool finish --no-clean zstd-native ../meta-my-layer
```

完成後檢查：

```bash
find ../meta-my-layer -path '*zstd*' -type f | sort
git -C ../meta-my-layer status
devtool status
bitbake-layers show-appends | grep -A10 -B2 zstd
```

`finish` 產生的目錄結構會依 Yocto 版本、recipe 名稱、`PN` / `BPN`、以及原 recipe 分類而不同。不要只依賴範例路徑；要以 `find`、`git status`、`bitbake-layers show-appends` 的結果為準。

##### Step 6：離開 workspace 後做乾淨驗證

完成後建議至少跑：

```bash
# 確認 workspace 不再覆蓋 zstd-native
devtool status
bitbake -e zstd-native | grep '^EXTERNALSRC' || true

# 確認 append 與 patch 生效
bitbake-layers show-appends | grep -A10 -B2 zstd
bitbake -e zstd-native | grep '^SRC_URI='

# 從 patch 階段與完整建置驗證
bitbake -c cleansstate zstd-native
bitbake -c patch zstd-native
bitbake zstd-native
```

若 patch 是為 target package 準備，還要重建 image 或至少重跑 rootfs：

```bash
bitbake obmc-phosphor-image
# 或依專案需要
bitbake -c rootfs obmc-phosphor-image
```

#### 7.8.4 中途卡關時的處理方式

##### 情境 A：改到一半想放棄

```bash
devtool reset zstd-native
```

執行後檢查：

```bash
devtool status
bitbake -e zstd-native | grep '^EXTERNALSRC' || true
```

`reset` 會移除 workspace 中該 recipe 的 active 狀態。若 devtool 判斷有需要保留的內容，可能會移到 `build/workspace/attic/`。

##### 情境 B：workspace 和原 recipe 不同步

例如原 recipe 升版、`SRCREV` 改變、或 upstream layer 更新後，workspace 仍指向舊 source。建議：

```bash
devtool status
devtool reset zstd-native
devtool modify zstd-native
```

重新取出後，再把仍需要的修改 cherry-pick 或重新套用。

##### 情境 C：修改的是 recipe metadata，不是 source

`devtool update-recipe` 與 `finish` 主要處理 source tree commit 產生的 patch。若你改的是 `DEPENDS`、`PACKAGECONFIG`、`SYSTEMD_SERVICE`、`FILES:${PN}` 等 metadata，請明確放在目標 layer 的 `.bbappend` 或 recipe 中。

可用：

```bash
devtool edit-recipe zstd-native
```

檢查 workspace append，但正式收尾時仍要確認 metadata 是否進入指定 layer。

##### 情境 D：已經 update-recipe，後來又想 finish

這是容易造成重複 patch 的情境。處理方式：

```bash
# 1. 先看目前哪些 layer 被改到
git status
find .. -name '000*.patch' | grep zstd || true

# 2. 決定保留哪一份 patch
# 3. 若要改走 finish，先還原不該改的原 layer，再執行 finish
```

建議每一輪開發開始前先決定收尾策略：

- 原 layer bug fix：走 `update-recipe`。
- 平台客製 patch：走 `finish <recipe> <platform-layer>`。

#### 7.8.5 工作流選擇表

| 目標 | 建議流程 | 原因 |
|------|----------|------|
| 修自己的 recipe，準備直接提交到同一 layer | `modify → commit → update-recipe → build` | metadata 與 patch 回到原 recipe 所在位置 |
| 修改 upstream / vendor recipe，但不能動原 layer | `modify → commit → finish <platform-layer> → clean build` | patch 與 `.bbappend` 留在自己的 layer |
| 只是短暫試驗 | `modify → edit → build → reset` | 不留下正式 patch |
| 要長期維護 fork | `modify` 可用於測試，但正式可能改 `SRC_URI` / `SRCREV` 指到 fork | 大量 patch 長期維護成本較高 |
| 只要加設定檔或 systemd override | 手寫 `.bbappend` | 不一定需要 devtool source workspace |
| 修改 kernel / DTS / driver | 可用 `devtool modify virtual/kernel` 或 kernel recipe；收尾到 platform layer | 需額外驗證 deploy 的 kernel / DTB / image |

#### 7.8.6 BMC / OpenBMC 專案中的建議流程

對 BMC 平台移植而言，通常不希望直接修改以下 layer：

- `poky/meta` / OE-Core
- `meta-openembedded`
- `meta-phosphor`
- SoC vendor layer，例如 `meta-aspeed`、`meta-nuvoton`
- 客戶或 ODM 提供、需保留同步能力的 BSP layer

因此大部分平台差異建議流程是：

```bash
bitbake-layers create-layer ../meta-my-platform
bitbake-layers add-layer ../meta-my-platform

bitbake <recipe>
devtool modify <recipe>
# edit source
git add <files>
git commit -s -m "<component>: describe platform fix"
devtool finish <recipe> ../meta-my-platform

bitbake-layers show-appends | grep -A10 -B2 '<recipe>'
bitbake -c cleansstate <recipe>
bitbake <recipe>
bitbake obmc-phosphor-image
```

如果修改的是 OpenBMC service，另外檢查：

```bash
# rootfs/package 是否有更新
oe-pkgdata-util list-pkg-files <package> | head

# 實機服務狀態
systemctl status <service>
journalctl -u <service> -b --no-pager | tail -100

# 若服務提供 D-Bus object
busctl tree <service-name>
```

#### 7.8.7 常見錯誤與排查

| 現象 | 可能方向 | 檢查方式 |
|------|----------|----------|
| `bitbake` 還在用 workspace source | `finish` 未成功、`devtool status` 仍有 recipe、`EXTERNALSRC` 還在 | `devtool status`、`bitbake -e <recipe> | grep '^EXTERNALSRC'` |
| patch 已產出但沒套用 | layer 未加入、`.bbappend` 檔名不符、`FILESEXTRAPATHS` 不對 | `bitbake-layers show-appends`、`bitbake -e <recipe> | grep '^FILESPATH='` |
| patch 重複 | 先 `update-recipe` 改到原 layer，又 `finish` 到平台 layer | `git status`、`find .. -name '000*.patch'`、檢查 `SRC_URI` |
| `finish` 放錯 layer | 指定 layer path 錯 | `git -C <layer> status`、檢查 `conf/layer.conf` |
| 修改 recipe metadata 沒被帶出 | 只改 workspace append，但未收回正式 layer | 手動檢查 workspace append 與 platform layer append |
| clean 後修改不見 | 只改 `tmp/work/`，未使用 devtool 或未產出 patch | 改用 `devtool modify`，或從 Git / attic 找回 |
| `--no-clean` 不支援 | Yocto branch 的 devtool finish 選項不同 | `devtool finish --help` |
| target image 沒變 | 只建 recipe，未重建 image/rootfs，或 package 沒被 image 安裝 | `IMAGE_INSTALL`、packagegroup、`oe-pkgdata-util` |

#### 7.8.8 `--no-clean` 與 attic 的使用提醒

部分 devtool 版本支援 `finish --no-clean`，可在收尾後保留 workspace source tree，方便後續對照。使用前請以：

```bash
devtool finish --help
```

確認目前 branch 是否支援該選項。

如果未使用 `--no-clean`，或執行 `reset` / `finish` 時 devtool 判斷需要保留舊內容，可能會把資料移到：

```text
build/workspace/attic/
```

建議收尾後執行：

```bash
devtool status
find build/workspace/attic -maxdepth 3 -type f 2>/dev/null | head
```

若要保留開發歷程，最可靠方式仍是確保 workspace source tree 的 Git commit 已經被轉成 patch，或已推到正式 Git repository。

#### 7.8.9 最終驗證清單

- [ ] `devtool status` 不再列出該 recipe；若仍列出，確認是否刻意保留 workspace。
- [ ] `bitbake -e <recipe> | grep '^EXTERNALSRC'` 不應再指向 workspace，除非仍在開發模式。
- [ ] `bitbake-layers show-appends` 看得到目標 layer 的 `.bbappend`。
- [ ] `bitbake -e <recipe> | grep '^SRC_URI='` 包含預期 patch。
- [ ] `bitbake -c patch -f <recipe>` 通過。
- [ ] `bitbake <recipe>` 通過。
- [ ] 若會進 image，完整 image 或 rootfs 重建通過。
- [ ] `git status` 顯示只有預期 layer 有變更。
- [ ] patch 檔案命名、commit message、Signed-off-by 符合團隊規範。
- [ ] BMC 實機測試已紀錄 service log、D-Bus / Redfish / IPMI 行為與版本資訊。

#### 7.8.10 本章重點

1. `update-recipe` 與 `finish` 不是固定先後順序，而是兩種不同收尾策略。
2. `update-recipe` 適合回寫目前 recipe 所在 layer；`finish` 適合把平台差異收回指定 layer。
3. BMC / OpenBMC 專案多數平台 patch 建議使用 `finish <recipe> <platform-layer>`，避免直接修改 upstream / vendor layer。
4. 收尾後一定要檢查 `devtool status`、`EXTERNALSRC`、`show-appends`、`SRC_URI`。
5. 若修改會進 image，單獨 `bitbake <recipe>` 不夠，仍需重建 image 或 rootfs。

#### 7.8.12 本章參考資料

- Yocto Project Development Tasks Manual - Using the devtool command-line tool: [https://docs.yoctoproject.org/dev/dev-manual/devtool.html](https://docs.yoctoproject.org/dev/dev-manual/devtool.html)
- Yocto Project Reference Manual - devtool Quick Reference: [https://docs.yoctoproject.org/ref-manual/devtool-reference.html](https://docs.yoctoproject.org/ref-manual/devtool-reference.html)
- Yocto Project Reference Manual - Classes / externalsrc: [https://docs.yoctoproject.org/ref-manual/classes.html](https://docs.yoctoproject.org/ref-manual/classes.html)

#### 7.9 OpenBMC 新 Machine Layer 與 DTS Bring-up 系統化流程

本節把 `davidboard` 的 debug 紀錄整理成可重用的 OpenBMC / Yocto 新平台移植流程。

1. 先讓 layer 成為合法 Yocto layer。
2. 再讓 OpenBMC setup 能用 template 建立 build directory。
3. 接著讓 BitBake 載入該 layer 並辨識 `MACHINE`。
4. 先沿用既有 EVB DTS，確認 image build flow 可通過。
5. 再導入 Linux kernel DTS。
6. 最後導入 U-Boot DTS 與 bootloader 相關設定。

此流程刻意將「能 build」與「硬體客製」分開，避免同時排查 layer、template、machine、kernel DTS、U-Boot DTS、flash layout 與 sensor/fan 設定。

##### 7.9.1 整體目錄規劃

案例假設：

```text
OpenBMC source tree : /yocto_qemu/aspeed_bmc/openbmc
Platform layer      : /yocto_qemu/aspeed_bmc/openbmc/meta-davidcorp/meta-davidboard
Machine             : davidboard
Kernel recipe       : linux-aspeed
U-Boot recipe       : u-boot-aspeed-sdk
Image target        : obmc-phosphor-image
```

建議目錄：

```text
meta-davidcorp/
└── meta-davidboard/
    ├── conf/
    │   ├── layer.conf
    │   ├── machine/
    │   │   └── davidboard.conf
    │   └── templates/
    │       └── default/
    │           ├── bblayers.conf.sample
    │           ├── local.conf.sample
    │           ├── conf-notes.txt
    │           └── conf-summary.txt        # 若目前 branch 使用此檔，需保留
    ├── recipes-kernel/
    │   └── linux/
    │       ├── linux-aspeed_%.bbappend
    │       └── linux-aspeed/
    │           └── aspeed-bmc-david-davidboard.dts
    └── recipes-bsp/
        └── u-boot/
            ├── u-boot-aspeed-sdk_%.bbappend
            └── u-boot-aspeed-sdk/
                └── ast2600-davidboard.dts
```

各區域的責任：

| 區域                             | 放置內容                                                   | 主要影響                                                                        |
| -------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------- |
| `conf/layer.conf`              | layer collection、recipe 搜尋路徑、Yocto series 相容宣告   | BitBake 是否承認此目錄是 layer                                                  |
| `conf/machine/davidboard.conf` | MACHINE、SoC include、kernel、DTB、U-Boot、image type      | BitBake 是否承認`davidboard`，以及 image 產物長相                             |
| `conf/templates/default/`      | `setup` 建 build directory 時使用的 sample conf          | `. setup davidboard` 是否能建立 `conf/local.conf` 與 `conf/bblayers.conf` |
| `recipes-kernel/linux/`        | kernel`.bbappend`、DTS、kernel patch、config fragment    | kernel source、DTB、driver config、deploy output                                |
| `recipes-bsp/u-boot/`          | U-Boot`.bbappend`、U-Boot DTS、defconfig、Makefile patch | SPL / U-Boot 建置、bootloader DTB、boot flow                                    |

##### 7.9.2 階段 1：建立合法 Yocto layer

目的：讓 BitBake 承認 `meta-davidboard` 是一個可載入的 layer。

需要放的檔案：

```text
meta-davidcorp/meta-davidboard/conf/layer.conf
```

建議內容：

```bitbake
BBPATH .= ":${LAYERDIR}"

BBFILES += "${LAYERDIR}/recipes-*/*/*.bb \
            ${LAYERDIR}/recipes-*/*/*.bbappend"

BBFILE_COLLECTIONS += "meta-davidboard"
BBFILE_PATTERN_meta-davidboard = "^${LAYERDIR}/"
BBFILE_PRIORITY_meta-davidboard = "10"

LAYERSERIES_COMPAT_meta-davidboard = "scarthgap styhead walnascar wrynose whinlatter"
```

會影響到什麼：

- `bitbake-layers show-layers` 是否列出此 layer。
- 此 layer 內的 `.bb` 與 `.bbappend` 是否會被掃描。
- `.bbappend` 是否有機會套到 `linux-aspeed`、`u-boot-aspeed-sdk` 等 recipe。
- `LAYERSERIES_COMPAT_*` 若不含目前 Yocto release，可能在 parsing 階段報 layer compatibility 相關錯誤。

檢查方式：

```bash
cd /yocto_qemu/aspeed_bmc/openbmc
find meta-davidcorp/meta-davidboard -name layer.conf -print
bitbake-layers show-layers | grep david
bitbake -p
```

常見錯誤與方向：

- `No recipes available for ...bbappend`：`.bbappend` 檔名沒有對應到任何 recipe，或 layer branch / recipe name 不一致。
- `.bbappend` 沒出現在 `show-appends`：`BBFILES` 沒涵蓋該路徑、layer 沒加入 `BBLAYERS`，或檔名不匹配。
- layer compatibility warning / error：確認目前 OpenBMC branch 使用的 Yocto series，並同步 `LAYERSERIES_COMPAT_meta-davidboard`。

##### 7.9.3 階段 2：建立 machine conf

目的：定義 `davidboard` 這台機器，讓 BitBake 知道要用哪個 SoC BSP、kernel、DTB、U-Boot 與 image policy。

需要放的檔案：

```text
meta-davidcorp/meta-davidboard/conf/machine/davidboard.conf
```

初期建議內容：

```bitbake
# override 標籤 (條件名稱), 這台機器有哪些 override 標籤要啟用
MACHINEOVERRIDES =. "davidboard:"

# 依目前 ASPEED BSP 實際 include 調整
require conf/machine/include/ast2600.inc

PREFERRED_PROVIDER_virtual/kernel = "linux-aspeed"
PREFERRED_VERSION_linux-aspeed = "6.18%"

# 第一階段先沿用 EVB DTB，降低 bring-up 變數
KERNEL_DEVICETREE = "aspeed-bmc-ast2600-evb.dtb"

# 切換到自訂 DTS 後再改成：
# KERNEL_DEVICETREE = "aspeed-bmc-david-davidboard.dtb"

# U-Boot 變數名稱需以實際 recipe 支援為準
UBOOT_DEVICETREE = "ast2600-davidboard"
```

會影響到什麼：

- `MACHINE = "davidboard"` 是否有效。
- `tmp/work/` 目錄中的 machine-specific workdir。
- kernel DTB 產出清單。
- image deploy 目錄，例如 `tmp/deploy/images/davidboard/`。
- U-Boot、kernel、rootfs、flash image 的 machine-specific override。

檢查方式：

```bash
find meta-davidcorp/meta-davidboard/conf/machine -name 'davidboard.conf' -print
bitbake -e obmc-phosphor-image | grep '^MACHINE='
bitbake -e virtual/kernel | grep '^KERNEL_DEVICETREE='
```

##### 7.9.4 階段 3：建立 setup template

目的：讓 `. setup davidboard` 能產生正確的 build directory 初始設定。

需要放的檔案：

```text
meta-davidcorp/meta-davidboard/conf/templates/default/local.conf.sample
meta-davidcorp/meta-davidboard/conf/templates/default/bblayers.conf.sample
meta-davidcorp/meta-davidboard/conf/templates/default/conf-notes.txt
meta-davidcorp/meta-davidboard/conf/templates/default/conf-summary.txt   # 若目前 branch 使用
```

`local.conf.sample` 至少要確認：

```bitbake
MACHINE ??= "davidboard"
```

`bblayers.conf.sample` 至少要確認含有 platform layer：

```bitbake
BBLAYERS ?= " \
  /yocto_qemu/aspeed_bmc/openbmc/meta \
  /yocto_qemu/aspeed_bmc/openbmc/meta-openembedded/meta-oe \
  /yocto_qemu/aspeed_bmc/openbmc/meta-openembedded/meta-networking \
  /yocto_qemu/aspeed_bmc/openbmc/meta-openembedded/meta-python \
  /yocto_qemu/aspeed_bmc/openbmc/meta-phosphor \
  /yocto_qemu/aspeed_bmc/openbmc/meta-aspeed-sdk \
  /yocto_qemu/aspeed_bmc/openbmc/meta-aspeed-sdk/meta-ast2600-sdk \
  /yocto_qemu/aspeed_bmc/openbmc/meta-davidcorp/meta-davidboard \
  "
```

會影響到什麼：

- `. setup davidboard` 是否能建立 `build/conf/local.conf`。
- `. setup davidboard` 是否能建立 `build/conf/bblayers.conf`。
- 新建 build directory 時是否自動加入 `meta-davidboard`。
- 後續 BitBake 是否看得到 `davidboard.conf` 與 `.bbappend`。

檢查方式：

```bash
unset TEMPLATECONF
rm -rf build conf/templateconf.cfg
. setup davidboard

grep '^MACHINE' build/conf/local.conf
grep david build/conf/bblayers.conf
```

##### 7.9.5 階段 4：確認 BBLAYERS 載入真正 layer root

目的：確認 build directory 內的 `conf/bblayers.conf` 已包含真正 layer root。

正確路徑應為：

```text
/yocto_qemu/aspeed_bmc/openbmc/meta-davidcorp/meta-davidboard
```

除非 `meta-davidcorp/conf/layer.conf` 才是真的 layer root，否則不要只加入：

```text
/yocto_qemu/aspeed_bmc/openbmc/meta-davidcorp
```

會影響到什麼：

- BitBake 是否能找到 `conf/machine/davidboard.conf`。
- `recipes-kernel/linux/linux-aspeed_%.bbappend` 是否套用。
- `recipes-bsp/u-boot/u-boot-aspeed-sdk_%.bbappend` 是否套用。

檢查方式：

```bash
find /yocto_qemu/aspeed_bmc/openbmc/meta-davidcorp -name layer.conf -print
grep -n david build/conf/bblayers.conf
bitbake-layers show-layers | grep david
bitbake-layers show-appends | grep -E 'linux-aspeed|u-boot-aspeed-sdk'
```

##### 7.9.6 階段 5：先沿用 EVB DTB，確認 image build flow

目的：先驗證 Yocto / OpenBMC build flow，不在同一時間導入自訂 DTS。

`davidboard.conf`：

```bitbake
KERNEL_DEVICETREE = "aspeed-bmc-ast2600-evb.dtb"
```

`linux-aspeed_%.bbappend` 初期不要引用不存在的 DTS：

```bitbake
# SRC_URI += "file://aspeed-bmc-david-davidboard.dts"
```

會影響到什麼：

- 可先確認 `obmc-phosphor-image` 能否完成。
- 可排除 layer / machine / image recipe 這一層問題。
- 後續切換自訂 DTS 時，若失敗就能集中看 DTS 與 kernel recipe。

檢查方式：

```bash
bitbake -c cleansstate linux-aspeed
bitbake obmc-phosphor-image
find build/tmp/deploy/images/davidboard -maxdepth 1 -type f | sort
```

##### 7.9.7 階段 6：導入 Linux kernel DTS

目的：把自訂硬體描述加入 kernel recipe，產出 `aspeed-bmc-david-davidboard.dtb`。

需要放的檔案：

```text
meta-davidcorp/meta-davidboard/recipes-kernel/linux/linux-aspeed_%.bbappend
meta-davidcorp/meta-davidboard/recipes-kernel/linux/linux-aspeed/aspeed-bmc-david-davidboard.dts
```

`linux-aspeed_%.bbappend`：

```bitbake
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append:davidboard = " file://aspeed-bmc-david-davidboard.dts"

# 若 vendor recipe 的 do_configure 從 ${B} 找 DTS，才補這段。
do_configure:prepend:davidboard() {
    if [ -f "${WORKDIR}/aspeed-bmc-david-davidboard.dts" ]; then
        cp "${WORKDIR}/aspeed-bmc-david-davidboard.dts" "${B}/"
    fi
}
```

`davidboard.conf` 切換 DTB：

```bitbake
KERNEL_DEVICETREE = "aspeed-bmc-david-davidboard.dtb"
```

會影響到什麼：

- `SRC_URI` 會要求 BitBake 在 `FILESPATH` 裡找到該 DTS。
- `linux-aspeed` 的 unpack / configure 階段會取得此 DTS。
- kernel build 會嘗試產出指定 DTB。
- 最終 image 會使用 `KERNEL_DEVICETREE` 指定的 DTB。

檢查方式：

```bash
bitbake-layers show-appends | grep -A5 -B2 linux-aspeed
bitbake -e linux-aspeed | grep '^FILESPATH='
bitbake -e linux-aspeed | grep '^SRC_URI='
bitbake -e linux-aspeed | grep '^KERNEL_DEVICETREE='

bitbake -c cleansstate linux-aspeed
bitbake -c configure linux-aspeed
find build/tmp/work -path '*linux-aspeed*' -name 'aspeed-bmc-david-davidboard.dts' -print
```

若 failed task 是 `do_configure` 且訊息類似：

```text
cp: cannot stat '.../linux-aspeed/6.18+git/aspeed-bmc-david-davidboard.dts': No such file or directory
```

排查順序：

1. 確認 DTS 檔案真實存在。
2. 確認 `FILESEXTRAPATHS` 對應到 `recipes-kernel/linux/linux-aspeed/`。
3. 確認 `.bbappend` 有被 `bitbake-layers show-appends` 列出。
4. 確認 `SRC_URI` 中有該 DTS。
5. 確認 vendor recipe 的 `do_configure` 從 `${WORKDIR}`、`${B}` 還是 `${S}` 找 DTS。
6. 若 recipe 期望 DTS 在 `${B}`，用 `do_configure:prepend:davidboard()` 從 `${WORKDIR}` 複製到 `${B}`。

##### 7.9.8 階段 7：導入 U-Boot DTS

目的：讓 U-Boot 使用符合平台早期初始化需求的 DTS。U-Boot DTS 與 Linux DTS 是不同來源，不要混用。

需要放的檔案：

```text
meta-davidcorp/meta-davidboard/recipes-bsp/u-boot/u-boot-aspeed-sdk_%.bbappend
meta-davidcorp/meta-davidboard/recipes-bsp/u-boot/u-boot-aspeed-sdk/ast2600-davidboard.dts
```

`u-boot-aspeed-sdk_%.bbappend`：

```bitbake
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append:davidboard = " file://ast2600-davidboard.dts"
UBOOT_DEVICETREE:davidboard = "ast2600-davidboard"

# 只有在 recipe / log 顯示需要時才補複製。
do_configure:prepend:davidboard() {
    if [ -f "${WORKDIR}/ast2600-davidboard.dts" ]; then
        cp "${WORKDIR}/ast2600-davidboard.dts" "${B}/" || true
    fi
}
```

若 U-Boot `arch/arm/dts/Makefile` 沒列入新 DTB，請提供 patch，例如：

```bitbake
SRC_URI:append:davidboard = " \
    file://ast2600-davidboard.dts \
    file://0001-arm-dts-aspeed-add-davidboard-dtb.patch \
"
```

會影響到什麼：

- SPL / U-Boot 的 device tree 選擇。
- 早期 pinmux、clock、DRAM、boot media、console、flash 等 bootloader 階段行為。
- U-Boot deploy 產物與後續 image 打包。

檢查方式：

```bash
bitbake-layers show-appends | grep -A5 -B2 u-boot-aspeed-sdk
bitbake -e u-boot-aspeed-sdk | grep -E '^(SRC_URI|FILESPATH|UBOOT_DEVICETREE|UBOOT_MACHINE)='
bitbake -c cleansstate u-boot-aspeed-sdk
bitbake u-boot-aspeed-sdk
find build/tmp/deploy/images/davidboard -iname '*u-boot*' -o -iname '*dtb*'
```

##### 7.9.9 變數與路徑判讀

| 變數           | 意義                       | 在本流程的用途                                     |
| -------------- | -------------------------- | -------------------------------------------------- |
| `${THISDIR}` | 目前`.bbappend` 所在目錄 | 組出 platform 檔案搜尋路徑                         |
| `${PN}`      | recipe name                | 對應`linux-aspeed`、`u-boot-aspeed-sdk` 子目錄 |
| `${BPN}`     | base recipe name           | 面對 native / nativesdk 變體時較穩定               |
| `${WORKDIR}` | recipe 工作目錄            | `SRC_URI` 的本地檔案通常先出現在這裡             |
| `${S}`       | source tree                | kernel / U-Boot source tree                        |
| `${B}`       | build directory            | vendor recipe 可能從這裡找 DTS                     |

排查指令：

```bash
bitbake -e linux-aspeed | grep -E '^(PN|BPN|WORKDIR|S|B|FILESPATH|SRC_URI)='
bitbake -e u-boot-aspeed-sdk | grep -E '^(PN|BPN|WORKDIR|S|B|FILESPATH|SRC_URI)='
```

##### 7.9.10 決策樹

```text
setup 找不到 machine
└─ 檢查 conf/machine/<machine>.conf 是否存在，檔名是否完全一致

setup 找到 machine，但 oe-setup-builddir 失敗
├─ 檢查 TEMPLATECONF 是否指到存在的 template 目錄
├─ 檢查 template sample 檔是否齊全
└─ 檢查 template 所在 layer 是否有 conf/layer.conf

BitBake 回報 MACHINE invalid
├─ 檢查 build/conf/bblayers.conf 是否加入真正 layer root
├─ 檢查 layer.conf 的 BBFILES / collection / LAYERSERIES_COMPAT
└─ 檢查 local.conf 或環境變數是否覆蓋 MACHINE

BitBake 回報 file://*.dts 找不到
├─ 檢查檔案是否存在
├─ 檢查 FILESEXTRAPATHS 是否對應實際目錄
├─ 檢查 .bbappend 是否被 show-appends 列出
└─ 檢查 machine override 是否拼對

configure 階段 cp 找不到 DTS
├─ 檢查 DTS 是否在 WORKDIR
├─ 檢查 recipe 自訂 task 從 B / S / WORKDIR 哪裡找
└─ 用 do_configure:prepend 或 patch 修正路徑假設

DTB 沒產出
├─ 檢查 KERNEL_DEVICETREE / UBOOT_DEVICETREE
├─ 檢查 kernel 或 U-Boot Makefile 是否列入新 DTS
└─ 檢查 deploy 目錄與 log.do_compile
```

##### 7.9.11 建議收斂順序

1. 建立 `conf/layer.conf`。
2. 建立 `conf/machine/davidboard.conf`。
3. 建立 `conf/templates/default/`。
4. 確認 `build/conf/bblayers.conf` 加入真正 layer root。
5. 先用 EVB DTB 建出 `obmc-phosphor-image`。
6. 加 Linux DTS，確認 `linux-aspeed` 產出 DTB。
7. 加 U-Boot DTS，確認 `u-boot-aspeed-sdk` 產物。
8. 再逐步導入 GPIO、I2C、CPLD、sensor、fan、power control、network。

### 8. Device Tree 通用寫法與排查

Device Tree（DT）是 Linux kernel 用來描述非自動枚舉硬體拓樸的資料結構。BMC 平台的 I2C 裝置、SPI flash、GPIO、pinctrl、PWM、tach、ADC、watchdog、reset controller、clock、regulator、MCTP endpoint、eSPI/LPC/KCS、NC-SI、USB gadget 等，多數都會在 DTS / DTSI / DTB 中留下硬體描述。DT 的重點不是把 board schematic 原封不動搬進 kernel，而是用對應 binding 描述「kernel driver 需要知道、且無法自行偵測」的資訊。

對 BMC porting 而言，Device Tree 是硬體設計、BSP、kernel driver、OpenBMC service 與現場排查之間的共同基準。若 DT 寫錯，常見現象不一定直接顯示為 DT error，而可能是 sensor 不出現、I2C bus 掃不到裝置、GPIO polarity 反相、fan PWM 無輸出、flash partition 錯位、kernel deferred probe、OpenBMC inventory 缺項、Redfish / IPMI 顯示不一致。因此本章把 DT 寫法、binding 檢查、BMC 常見節點範本、build / runtime 驗證、log 收集與驗收 checklist 放在同一個章節。

#### 8.1 Device Tree 在 BMC Porting 中的角色

DT 在 BMC bring-up 中主要回答下列問題：

- 這顆 board 使用哪一個 SoC、哪一份 SoC DTSI、哪一份 board DTS。
- 哪些 SoC controller 被啟用，例如 I2C、SPI、UART、MAC、PWM、tach、ADC、watchdog、eSPI、LPC、KCS。
- 每個 controller 的 pinmux、clock、reset、interrupt、DMA、bus speed、status 是否正確。
- 每個 bus 底下有哪些 child device，address / chip select / interrupt / reset / GPIO / supply 是否正確。
- flash partition、reserved-memory、chosen bootargs、aliases、gpio-line-names 是否與 U-Boot、Yocto image、OpenBMC service 對齊。
- 哪些設定屬於硬體描述，哪些應放在 Entity Manager JSON、systemd service、policy config 或 userspace 設定檔。

<table>
<tr><th>層級</th><th>Device Tree 負責內容</th><th>不建議放在 Device Tree 的內容</th><th>排查入口</th></tr>
<tr><td>SoC / Board</td><td>MMIO address、interrupt、clock、reset、pinctrl、controller status</td><td>會依產品政策變動的 runtime policy</td><td>dtc、dmesg、/proc/device-tree</td></tr>
<tr><td>Bus / Device</td><td>I2C address、SPI chip select、reg、compatible、GPIO、supply、interrupt</td><td>sensor threshold、fan curve、FRU inventory policy</td><td>dmesg、i2cdetect、ls -l /sys/bus</td></tr>
<tr><td>Storage</td><td>MTD fixed-partitions、flash compatible、SPI mode</td><td>更新策略、software inventory state</td><td>/proc/mtd、dmesg mtd/ubi</td></tr>
<tr><td>GPIO / Pinmux</td><td>gpio-line-names、pinctrl state、consumer GPIO polarity</td><td>按鈕長按策略、LED pattern policy</td><td>gpioinfo、pinctrl debugfs</td></tr>
<tr><td>OpenBMC userspace</td><td>提供 kernel device 與 line name 基礎</td><td>Entity Manager probe rule、sensor scale / threshold、thermal policy</td><td>busctl、journalctl、systemctl</td></tr>
<tr>
<td>  
2026-07-10
</td>
<td>  
0.34
</td>
<td>  
Copilot
</td>
<td>  
撰寫第 8 章 Device Tree 通用寫法與排查，補齊 binding、DTS/DTSI/DTB、pinctrl/GPIO、I2C/SPI/flash、console、network、sensor controller、reserved memory、dtbs_check、target log 收集、回查結果與驗收 checklist
</td>
</tr>
<tr>
<td>  
2026-07-10
</td>
<td>  
0.35
</td>
<td>  
Copilot
</td>
<td>  
撰寫第 10 章 I2C / PMBus 裝置驅動架構，補齊 I2C 拓樸、Device Tree、Linux i2c sysfs、hwmon、PMBus page/phase/format/status、Entity Manager / dbus-sensors、Redfish / IPMI 對映、fault snapshot、log 收集、回查結果與驗收 checklist
</td>
</tr>
<tr>
<td>  
2026-07-10
</td>
<td>  
0.36
</td>
<td>  
Copilot
</td>
<td>  
撰寫第 15 章 Inventory / FRU / Asset 資料模型，補齊資料權威端、OpenBMC inventory D-Bus object、FRU EEPROM / IPMI FRU 欄位、Entity Manager Probe、Presence / Functional、association、Redfish / IPMI 對映、製造 provisioning、資料保存、log 收集、回查結果與驗收 checklist
</td>
</tr>
<tr>
<td>  
2026-07-10
</td>
<td>  
0.37
</td>
<td>  
Copilot
</td>
<td>  
撰寫第 16 章 Logging / Event / Telemetry，補齊 phosphor-logging、systemd journal、D-Bus event log、SEL、Redfish EventLog / EventService、TelemetryService / MetricReport、remote syslog、安全 audit、core dump、容量策略、log 收集、回查結果與驗收 checklist；原 Presence / Intrusion / GPIO State Sensor 順延為第 17 章
</td>
</tr>
<tr>
<td>  
2026-07-10
</td>
<td>  
0.38
</td>
<td>  
Copilot
</td>
<td>  
撰寫第 20 章 MCTP / PLDM / SPDM，補齊 transport binding、EID / discovery / route、OpenBMC mctpd / pldmd、PLDM types / PDR / FRU / BIOS / firmware update、SPDM attestation / certificate / measurement / policy、log 收集、回查結果與驗收 checklist
</td>
</tr>
<tr>
<td>  
2026-07-10
</td>
<td>  
0.39
</td>
<td>  
Copilot
</td>
<td>  
撰寫第 9 章 Kernel Driver 與核心服務，補齊 Linux driver model、probe flow、bus match、deferred probe、kernel config、sysfs / debugfs / hwmon / IIO / GPIO / MTD / watchdog / netdev、OpenBMC service 銜接、dynamic debug / ftrace、panic / oops、log 收集、回查結果與驗收 checklist
</td>
</tr>
</table>

建議分工原則：

- 「硬體接線與 SoC controller 能力」放在 DTS / DTSI。
- 「裝置是否存在、在哪個 bus address、需要哪條 reset / interrupt / GPIO」通常放在 DTS；若裝置為可插拔且由 FRU / GPIO presence 決定，需搭配 Entity Manager 或對應 daemon。
- 「sensor threshold、fan policy、SKU 差異、使用者可調設定」通常放在 OpenBMC config 或 userspace policy，不建議塞進 DTS。
- 「CPLD register map」若無通用 kernel driver，可先在 CPLD 章節與平台 service 文件記錄；若有 MFD / regmap driver，再用 DT 描述 bus / address / interrupt / child function。

#### 8.2 DTS / DTSI / DTB / Overlay 與檔案位置

<table>
<tr><th>名詞</th><th>說明</th><th>BMC 常見用途</th><th>注意事項</th></tr>
<tr><td>DTS</td><td>Device Tree Source，通常描述單一 board</td><td>board-specific controller enable、I2C device、GPIO line name、flash partition</td><td>board DTS 應盡量覆寫 / 啟用 SoC DTSI 既有節點，避免重複定義 SoC 內部 block</td></tr>
<tr><td>DTSI</td><td>DTS include file，通常描述 SoC、package、共用板階變體</td><td>SoC base map、clock/reset/pinctrl controller、common board design</td><td>共用 DTSI 改動會影響多個平台，送審前需確認影響範圍</td></tr>
<tr><td>DTB</td><td>編譯後 binary blob，bootloader 傳給 kernel</td><td>實際開機使用的硬體描述</td><td>必須確認 running DTB 是本次 build 產物，不只看 source</td></tr>
<tr><td>DTBO / Overlay</td><td>覆加在 base DTB 上的片段</td><td>少數 SKU、runtime expansion</td><td>BMC 量產平台若使用 overlay，需明確記錄套用順序與 bootloader 設定</td></tr>
<tr><td>Binding</td><td>某類硬體節點的格式規範</td><td>確認 compatible、required properties、child node 格式</td><td>寫 DTS 前先查 binding，避免自創 property</td></tr>
</table>

OpenBMC / Yocto 平台常見來源位置：

```text
Linux kernel tree:
  arch/arm/boot/dts/aspeed/
  arch/arm/boot/dts/nuvoton/
  arch/arm64/boot/dts/
  Documentation/devicetree/bindings/

OpenBMC meta layer:
  meta-*/recipes-kernel/linux/linux-*.bbappend
  meta-*/recipes-kernel/linux/linux-*/<patch>.patch
  meta-*/conf/machine/<machine>.conf

Build output:
  tmp/work/<machine>-*/linux-*/<version>/git/arch/.../boot/dts/
  tmp/deploy/images/<machine>/*.dtb
  tmp/deploy/images/<machine>/fitImage 或 image package
```

Bring-up 時至少要確認三份內容是否一致：

1. `arch/.../boot/dts/<board>.dts`：source 是否為預期版本。
2. `tmp/deploy/images/<machine>/*.dtb`：build output 是否有更新。
3. `/sys/firmware/fdt` 或 `/proc/device-tree`：target 實際 running DTB 是否為新版本。

#### 8.3 Binding 優先原則與 DTS 寫作規則

寫 DTS 前先查 binding。DT binding 是 kernel driver 與硬體描述之間的契約，常見格式為 YAML schema，位置通常在 `Documentation/devicetree/bindings/`。若平台使用的 kernel 版本仍包含舊式 `.txt` binding，也需要以該 kernel tree 為準。

基本規則：

- `compatible` 必須能對上 driver 的 `of_match_table` 或 binding 允許的字串。
- `reg` 的 cell 數量由 parent bus 的 `#address-cells` 與 `#size-cells` 決定。
- node name 的 `@unit-address` 應與 `reg` 的第一個 address 對應；沒有 `reg` 時不應加 `@...`。
- `interrupts` / `interrupt-parent` / `interrupts-extended` 必須符合 interrupt controller binding。
- `clocks` / `clock-names`、`resets` / `reset-names`、`*-supply` 的名稱與順序需符合 driver 期待。
- GPIO consumer property 建議使用 `<function>-gpios`，例如 `reset-gpios`、`enable-gpios`、`presence-gpios`。
- GPIO polarity 要用 `GPIO_ACTIVE_LOW` / `GPIO_ACTIVE_HIGH`，並用實測電位驗證。
- I2C child node 的 `reg` 使用 7-bit address，不要把 8-bit address 或含 R/W bit 的值填入。
- `status = "okay";` 只能代表 kernel 可嘗試 probe，不代表硬體一定可用；仍需檢查 rail、reset、clock、pinmux。
- 不要把臨時 debug property 留在產品 DTS；若需要 debug knob，應放在 driver debugfs、module parameter 或平台設定中。

DTS coding style 建議：

- node name、property name 使用小寫、數字與 dash；label 使用小寫、數字與 underscore。
- unit address 使用小寫十六進位；除 bus 格式需要外，不加無意義前導零。
- 同一 bus 底下有 unit address 的 child node 依 address 排序。
- property 順序建議為：`compatible`、`reg`、`ranges`、common properties、vendor properties、`status`、child nodes。
- board DTS 中啟用 SoC controller 時，盡量使用 `&label { ... };` 覆寫現有節點。
- `status` 若預設即為 `"okay"`，可依專案風格省略；但 BMC porting 初期為了可讀性，常保留明確的 `status = "okay";`。

#### 8.4 `compatible`、`reg`、`ranges` 與 address cells

`compatible` 決定 driver matching 與 binding schema；`reg` 決定 device address；`#address-cells` / `#size-cells` 決定 child `reg` 的 cell 格式。這三者錯誤時，常見現象是 driver 不 probe、address 錯位、resource range 不正確，或 dtbs_check 出現 schema warning。

<table>
<tr><th>Parent bus</th><th>常見 cells</th><th>Child `reg` 意義</th><th>範例</th></tr>
<tr><td>MMIO bus / SoC bus</td><td>`#address-cells = &lt;1 or 2&gt;`；`#size-cells = &lt;1 or 2&gt;`</td><td>MMIO base + size</td><td>`reg = &lt;0x1e780000 0x1000&gt;;`</td></tr>
<tr><td>I2C bus</td><td>`#address-cells = &lt;1&gt;`；`#size-cells = &lt;0&gt;`</td><td>7-bit I2C address</td><td>`reg = &lt;0x48&gt;;`</td></tr>
<tr><td>SPI bus</td><td>`#address-cells = &lt;1&gt;`；`#size-cells = &lt;0&gt;`</td><td>chip select index</td><td>`reg = &lt;0&gt;;`</td></tr>
<tr><td>MDIO bus</td><td>`#address-cells = &lt;1&gt;`；`#size-cells = &lt;0&gt;`</td><td>PHY address</td><td>`reg = &lt;1&gt;;`</td></tr>
</table>

```dts
&i2c5 {
    status = "okay";

    temperature-sensor@48 {
        compatible = "ti,tmp75";
        reg = <0x48>;
    };
};

&fmc {
    status = "okay";

    flash@0 {
        compatible = "jedec,spi-nor";
        reg = <0>;
        spi-max-frequency = <50000000>;
    };
};
```

排查重點：

- I2C datasheet 若列出 `0x90 / 0x91` 這類 8-bit address，DTS 應填 `0x48`。
- SPI flash 的 `reg = <0>;` 通常代表 CS0，不是 flash offset。
- 若 child node 有 `@xx` 但沒有 `reg`，dtc 可能出現 unit address warning。
- 若 `reg` cell 數量錯，dtc / dtbs_check 可能報錯，driver 也可能拿到錯誤 resource。

#### 8.5 Node status、disabled 預設與 board DTS 覆寫策略

SoC DTSI 通常會把 controller node 先定義好，並將 board 未必使用的 controller 設為 disabled。Board DTS 再依 schematic 啟用需要的 controller。

```dts
/* SoC DTSI */
i2c5: i2c-bus@1e78a200 {
    compatible = "aspeed,ast2600-i2c-bus";
    reg = <0x1e78a200 0x80>;
    interrupts = <GIC_SPI 115 IRQ_TYPE_LEVEL_HIGH>;
    status = "disabled";
};

/* Board DTS */
&i2c5 {
    status = "okay";

    eeprom@50 {
        compatible = "atmel,24c64";
        reg = <0x50>;
        pagesize = <32>;
    };
};
```

建議策略：

- Board DTS 中只啟用實際接線且已驗證 power / reset / pinmux 的 controller。
- 未接的 controller 保持 disabled，避免 driver probe 造成 timeout 或誤佔 pinmux。
- 若 controller 暫時 disabled 是因為硬體 rework、driver 未 ready 或安全政策，請在註解與本章實測表補上原因。
- 多 SKU 共用 DTSI 時，可建立 common DTSI，再由各 SKU DTS 覆寫 `status`、child device、gpio-line-names。

#### 8.6 Pinctrl、GPIO line name 與 consumer GPIO

Pinctrl 代表 pin 的功能選擇與電氣設定；GPIO node 代表 Linux GPIO controller；consumer GPIO property 代表某個 driver 使用哪條 GPIO。這三者不要混在一起判讀。

```dts
&pinctrl {
    pinctrl_i2c7_default: i2c7-default {
        function = "I2C7";
        groups = "I2C7";
    };
};

&i2c7 {
    status = "okay";
    pinctrl-names = "default";
    pinctrl-0 = <&pinctrl_i2c7_default>;
};

&gpio0 {
    gpio-line-names =
        /* A0-A7 */
        "pwrbtn-n", "pltrst-n", "host-pgood", "bios-wp-n",
        "psu0-present-n", "psu1-present-n", "fan0-present-n", "fan1-present-n";
};
```

Consumer GPIO 範本：

```dts
device@40 {
    compatible = "vendor,device";
    reg = <0x40>;
    reset-gpios = <&gpio0 12 GPIO_ACTIVE_LOW>;
    interrupt-parent = <&gpio0>;
    interrupts = <13 IRQ_TYPE_LEVEL_LOW>;
};
```

檢查重點：

- `gpio-line-names` 順序必須與 gpio controller line offset 完全一致。
- line name 是排查與 OpenBMC config 對齊用，不會自動建立 driver consumer。
- `GPIO_ACTIVE_LOW` 會影響 gpiod logical value；請同時記錄 physical level 與 logical state。
- 若同一 pin 被 pinctrl 設成 I2C / UART / PWM，就不能同時當一般 GPIO 使用。
- GPIO expander 上的 line name 也需要填，避免 target 上只看到 `P00`、`P01` 這類無語意名稱。

#### 8.7 Interrupt、IRQ type 與 event line

Interrupt 類訊號在 BMC 平台常用於 PMBus ALERT、GPIO expander INT、thermal alert、fault latch、中斷式 button / intrusion。DT 需描述 interrupt parent 與 trigger type，driver 仍需要讀取裝置 status 才能知道事件來源。

```dts
&i2c7 {
    gpio_expander0: gpio@20 {
        compatible = "nxp,pca9555";
        reg = <0x20>;
        gpio-controller;
        #gpio-cells = <2>;
        interrupt-parent = <&gpio0>;
        interrupts = <42 IRQ_TYPE_LEVEL_LOW>;
        gpio-line-names =
            "psu0-present-n", "psu1-present-n", "riser0-present-n", "riser1-present-n",
            "fanboard0-present-n", "fanboard1-present-n", "reserved-exp0-6", "reserved-exp0-7",
            "fault-led", "uid-led", "reserved-exp0-10", "reserved-exp0-11",
            "wp-enable", "mux-sel0", "mux-sel1", "expander-int-n";
    };
};
```

排查重點：

- active low line 通常不等於 edge falling；需依硬體與 driver 確認 `IRQ_TYPE_LEVEL_LOW`、`IRQ_TYPE_EDGE_FALLING` 等設定。
- level interrupt 若 source status 未清，可能造成 IRQ storm。
- shared interrupt 需確認每個裝置都能讀 status 並清除自己的事件。
- GPIO expander INT pin 的 supply / reset 依賴也要記錄；expander 掉電時 interrupt line 可能浮動。

#### 8.8 Clock、reset、regulator 與 power dependency

Driver probe 成功常需要四個條件同時成立：clock 可用、reset 已釋放、rail 穩定、pinmux 已套用。DT 只能描述 dependency 與參數，無法取代實機 timing 量測。

```dts
vdd_3v3_aux: regulator-vdd-3v3-aux {
    compatible = "regulator-fixed";
    regulator-name = "vdd_3v3_aux";
    regulator-min-microvolt = <3300000>;
    regulator-max-microvolt = <3300000>;
    regulator-always-on;
};

ethernet@1e660000 {
    compatible = "vendor,soc-mac";
    reg = <0x1e660000 0x1000>;
    clocks = <&syscon 42>;
    clock-names = "macclk";
    resets = <&rst 12>;
    reset-names = "mac";
    phy-mode = "rgmii-id";
    phy-handle = <&ethphy0>;
    status = "okay";
};

ethernet-phy@0 {
    reg = <0>;
    vdd-supply = <&vdd_3v3_aux>;
    reset-gpios = <&gpio0 46 GPIO_ACTIVE_LOW>;
    reset-assert-us = <10000>;
    reset-deassert-us = <30000>;
};
```

檢查重點：

- `clock-names` / `reset-names` 必須符合 driver 期待；名稱錯時可能出現 `failed to get clock` 或 `failed to get reset`。
- `*-supply` 名稱必須符合 binding；不是所有 driver 都會主動要求 regulator。
- fixed regulator 若由 GPIO 控制，需確認 active level、startup delay、boot-on / always-on 設定。
- BMC reboot 不應讓 host critical rail 掉電，除非產品政策明確如此。

#### 8.9 I2C / SMBus / PMBus 節點

BMC 的 sensor、FRU EEPROM、GPIO expander、MUX、PMBus PSU / VR、CPLD 常在 I2C / SMBus 上。DTS 與 Entity Manager 的邊界需要事先定義：固定存在且 driver 需要 kernel 管理的 device 可放 DTS；依 FRU / SKU / presence 動態建立的 sensor，常由 Entity Manager config 描述。

```dts
&i2c5 {
    status = "okay";
    bus-frequency = <100000>;

    eeprom@50 {
        compatible = "atmel,24c64";
        reg = <0x50>;
        pagesize = <32>;
    };

    temperature-sensor@48 {
        compatible = "ti,tmp75";
        reg = <0x48>;
    };
};
```

I2C mux 範本：

```dts
&i2c6 {
    status = "okay";

    i2c-mux@70 {
        compatible = "nxp,pca9548";
        reg = <0x70>;
        #address-cells = <1>;
        #size-cells = <0>;

        i2c@0 {
            reg = <0>;
            #address-cells = <1>;
            #size-cells = <0>;

            eeprom@50 {
                compatible = "atmel,24c02";
                reg = <0x50>;
            };
        };
    };
};
```

<table>
<tr><th>現象</th><th>可能方向</th><th>第一輪檢查</th></tr>
<tr><td>I2C 裝置完全沒有 ACK</td><td>address 錯、mux channel 錯、rail/reset 未 ready、pinmux 錯</td><td>i2cdetect、scope SDA/SCL、pinctrl、power rail</td></tr>
<tr><td>driver 沒有 probe</td><td>compatible 不匹配、kernel config 未啟用、binding property 缺失</td><td>dmesg、modinfo、grep of_match_table</td></tr>
<tr><td>mux 後 bus number 跟文件不同</td><td>runtime bus number 依 probe 順序建立</td><td>`i2cdetect -l`、/sys/bus/i2c/devices</td></tr>
<tr><td>PMBus sensor 值不出現</td><td>kernel hwmon 與 dbus-sensors / Entity Manager 邊界未對齊</td><td>/sys/class/hwmon、Entity Manager journal、D-Bus sensor tree</td></tr>
</table>

#### 8.10 SPI、Flash 與 fixed-partitions

SPI flash 節點會影響 boot flash probe、/proc/mtd partition、software update target 與 recovery 流程。DTS fixed-partitions 必須與 U-Boot env、Yocto image layout、update service 完全對齊。

```dts
&fmc {
    status = "okay";

    flash@0 {
        compatible = "jedec,spi-nor";
        reg = <0>;
        spi-max-frequency = <50000000>;
        m25p,fast-read;
        label = "bmc";

        partitions {
            compatible = "fixed-partitions";
            #address-cells = <1>;
            #size-cells = <1>;

            u-boot@0 {
                label = "u-boot";
                reg = <0x00000000 0x00100000>;
                read-only;
            };

            u-boot-env@100000 {
                label = "u-boot-env";
                reg = <0x00100000 0x00020000>;
            };

            kernel@120000 {
                label = "kernel";
                reg = <0x00120000 0x00600000>;
            };

            rofs@720000 {
                label = "rofs";
                reg = <0x00720000 0x03200000>;
            };

            rwfs@3920000 {
                label = "rwfs";
                reg = <0x03920000 0x006e0000>;
            };
        };
    };
};
```

檢查重點：

- `label` 與 update service、/proc/mtd、U-Boot mtdparts 使用的名稱一致。
- `reg` offset / size 需對齊 erase block，且不可超出 flash 容量。
- 若 bootloader 使用不同 DTB 或內建 partition table，kernel 看到的 /proc/mtd 可能與 source DTS 不一致。
- SPI-NAND / raw NAND 若使用 UBI，需確認 ECC / bad block / ubinize 參數；DT 只處理 MTD partition，UBI volume table 另行管理。

#### 8.11 UART、console、chosen 與 aliases

早期 bring-up 需要穩定 UART console。DT 中的 `chosen` 與 `aliases` 會影響 console、stdout-path、I2C bus alias、MAC alias 等命名。

```dts
/ {
    aliases {
        serial4 = &uart5;
        i2c5 = &i2c5;
        ethernet0 = &mac0;
    };

    chosen {
        stdout-path = &uart5;
        bootargs = "console=ttyS4,115200n8 earlycon";
    };
};

&uart5 {
    status = "okay";
    pinctrl-names = "default";
    pinctrl-0 = <&pinctrl_uart5_default>;
};
```

注意事項：

- `stdout-path`、U-Boot `bootargs`、kernel config 的 console driver 需一致。
- 若 U-Boot 會動態修改 `/chosen/bootargs`，target 上需要讀 `/proc/cmdline` 而不是只看 DTS source。
- `aliases` 可影響 device numbering；若專案依賴固定 `i2c-N` 或 `ttySx`，需保存 running DT 與 dmesg。
- BMC 平台常有多個 UART：debug console、host SOL、MCU / CPLD UART，需避免 pinmux 與 alias 混淆。

#### 8.12 Ethernet、NC-SI、MDIO 與 PHY

BMC network DT 常牽涉 MAC controller、MDIO PHY、RGMII/RMII pinmux、NC-SI、PHY reset、clock source 與 NVMAC address 來源。網路不通時，不一定是 network service 問題，也可能是 DT 描述的 phy-mode、clock、reset 或 MDIO address 錯。

```dts
&mac0 {
    status = "okay";
    phy-mode = "rgmii-id";
    phy-handle = <&ethphy0>;
    pinctrl-names = "default";
    pinctrl-0 = <&pinctrl_rgmii1_default>;
};

&mdio0 {
    status = "okay";

    ethphy0: ethernet-phy@1 {
        reg = <1>;
        reset-gpios = <&gpio0 46 GPIO_ACTIVE_LOW>;
        reset-assert-us = <10000>;
        reset-deassert-us = <30000>;
    };
};
```

NC-SI 平台需額外確認：

- MAC node 是否設定為 NC-SI 模式所需 compatible / property。
- Sideband 連到哪一個 host NIC package / channel。
- Host NIC、PCH、main rail、RMII / RBT clock、reset timing 是否 ready。
- BMC network service 是否在 host off 狀態下仍重複報錯；若 NC-SI 依賴 host power，service 需有合理 retry / gating。

排查入口：

```bash
dmesg | grep -Ei 'eth|mac|mdio|phy|rgmii|rmii|ncsi|link'
ip link
ethtool eth0 2>/dev/null
cat /sys/class/net/eth0/carrier 2>/dev/null
find /sys/bus/mdio_bus/devices -maxdepth 2 -type f -print 2>/dev/null
```

#### 8.13 PWM / Tach / ADC / Watchdog / RTC 常見節點

BMC sensor 與 fan control 需要 PWM / tach / ADC 等 controller 先在 DT 中啟用，之後 kernel driver 才會提供 hwmon / sysfs / D-Bus service 的基礎。

```dts
&pwm_tacho {
    status = "okay";
    pinctrl-names = "default";
    pinctrl-0 = <&pinctrl_pwm0_default &pinctrl_tach0_default>;
};

&adc0 {
    status = "okay";
};

&wdt1 {
    status = "okay";
};

&i2c3 {
    status = "okay";

    rtc@51 {
        compatible = "nxp,pcf8563";
        reg = <0x51>;
    };
};
```

檢查重點：

- PWM 或 tach 無輸出 / 無讀值時，同時查 pinmux、clock、fan power、tach pull-up、driver consumer。
- ADC raw value 出現但 sensor 值不對，可能是分壓電阻、scale、offset、Entity Manager config 問題，不一定是 DT 問題。
- Watchdog 啟用前需確認 reset 範圍、timeout、systemd watchdog policy 與 bring-up 是否衝突。
- RTC 若在 host-off / standby 狀態無供電，I2C probe 可能失敗；需記錄 power domain。

#### 8.14 Reserved memory、memory node 與 bootargs

BMC 平台有時會保留記憶體給 framebuffer、video engine、host interface、crash dump、secure firmware 或 DMA buffer。Reserved memory 和 memory node 寫錯可能造成 kernel panic、driver DMA failure、video capture 異常或隨機 memory corruption。

```dts
/ {
    memory@80000000 {
        device_type = "memory";
        reg = <0x80000000 0x20000000>;
    };

    reserved-memory {
        #address-cells = <1>;
        #size-cells = <1>;
        ranges;

        video_engine_memory: framebuffer@9f000000 {
            reg = <0x9f000000 0x01000000>;
            no-map;
        };
    };
};
```

檢查重點：

- memory size 必須與 bootloader / DDR init 實際容量一致。
- reserved region 不可與 kernel、initramfs、CMA、其他 reserved-memory 重疊。
- 若 U-Boot 會修改 memory node 或 reserved-memory，需以 target running DT 為準。
- `no-map`、`reusable`、`shared-dma-pool` 等屬性需依 driver binding 使用。

#### 8.15 Build-time 驗證：dtc、dtbs、dtbs_check

建議將 DTS 修改分成三層檢查：語法、schema、實機。

```bash
# 在 kernel tree 內編譯所有或特定 DTB
make ARCH=arm dtbs
make ARCH=arm <vendor>/<board>.dtb

# 提高 dtc warning 等級
make ARCH=arm W=1 dtbs
make ARCH=arm W=2 dtbs

# 檢查 binding schema
make ARCH=arm dt_binding_check
make ARCH=arm dtbs_check

# 只檢查特定 binding 或特定 DTB，依 kernel 版本支援調整
make ARCH=arm CHECK_DTBS=y <vendor>/<board>.dtb
make ARCH=arm DT_SCHEMA_FILES=/gpio/ dtbs_check
```

Yocto / OpenBMC build 端常用檢查：

```bash
# 找到 kernel workdir
bitbake -e virtual/kernel | grep '^S='
bitbake -e virtual/kernel | grep '^B='

# 只編譯 kernel / device tree
bitbake virtual/kernel -c compile -f
bitbake virtual/kernel -c deploy

# 檢查 deploy DTB 是否更新
ls -lh tmp/deploy/images/${MACHINE}/*.dtb
strings tmp/deploy/images/${MACHINE}/*.dtb | head

# 若 kernel recipe 有獨立 dtbs task，依專案支援使用
bitbake virtual/kernel -c listtasks | grep -i dtb
```

建議保存：

- kernel commit、DTS patch commit、machine config commit。
- `make W=1 dtbs` / `dtbs_check` 的 log。
- `tmp/deploy/images/${MACHINE}` 中 DTB / fitImage / image package 的 timestamp 與 checksum。
- target running DTB 反編譯後的 `running.dts`。

#### 8.16 Target 端檢查與 running DTB 反編譯

Target 上排查時要先確認 kernel 實際收到的 DTB。Source 正確不代表 running DTB 正確，常見原因包含 bootloader 仍載入舊 DTB、FIT image 內 DTB 沒更新、A/B slot 用了另一份 image、U-Boot overlay 修改過 `/chosen` 或 memory node。

```bash
mkdir -p /tmp/dt-debug

# 讀 model / compatible / bootargs
tr '\0' '\n' < /proc/device-tree/model > /tmp/dt-debug/model.txt 2>&1
tr '\0' '\n' < /proc/device-tree/compatible > /tmp/dt-debug/compatible.txt 2>&1
cat /proc/cmdline > /tmp/dt-debug/proc-cmdline.txt

# 反編譯 running FDT
cp /sys/firmware/fdt /tmp/dt-debug/running.dtb 2>/dev/null
if command -v dtc >/dev/null 2>&1; then
    dtc -I dtb -O dts -o /tmp/dt-debug/running.dts /sys/firmware/fdt 2>/tmp/dt-debug/dtc-running.err
fi

# 檢查 device tree filesystem
find /proc/device-tree -maxdepth 3 -type f | sort > /tmp/dt-debug/proc-device-tree-files.txt

# kernel probe / deferred probe
cat /sys/kernel/debug/devices_deferred > /tmp/dt-debug/devices-deferred.txt 2>&1

dmesg -T > /tmp/dt-debug/dmesg.txt
journalctl -b --no-pager > /tmp/dt-debug/journal.txt
```

特定子系統檢查：

```bash
# I2C
ls -l /sys/bus/i2c/devices > /tmp/dt-debug/i2c-devices.txt 2>&1
i2cdetect -l > /tmp/dt-debug/i2c-bus-list.txt 2>&1

# GPIO / pinctrl
gpiodetect > /tmp/dt-debug/gpiodetect.txt 2>&1
gpioinfo > /tmp/dt-debug/gpioinfo.txt 2>&1
mount | grep debugfs || mount -t debugfs debugfs /sys/kernel/debug
cat /sys/kernel/debug/gpio > /tmp/dt-debug/debug-gpio.txt 2>&1
find /sys/kernel/debug/pinctrl -maxdepth 3 -type f -print > /tmp/dt-debug/pinctrl-files.txt 2>&1

# Clock / regulator / reset dependency
cat /sys/kernel/debug/clk/clk_summary > /tmp/dt-debug/clk-summary.txt 2>&1
find /sys/class/regulator -maxdepth 3 -type f -print -exec sh -c 'echo ==== $1; cat $1 2>/dev/null' _ {} \; > /tmp/dt-debug/regulator.txt 2>&1

# MTD / storage
cat /proc/mtd > /tmp/dt-debug/proc-mtd.txt 2>&1
cat /proc/partitions > /tmp/dt-debug/proc-partitions.txt 2>&1

tar czf /tmp/dt-debug-$(date +%Y%m%d-%H%M%S).tar.gz -C /tmp dt-debug
```

#### 8.17 常見問題與排查入口

<table>
<tr><th>現象</th><th>可能方向</th><th>第一輪檢查</th></tr>
<tr><td>修改 DTS 後 target 沒變</td><td>DTB 未 deploy、FIT image 未更新、bootloader 載入舊 slot</td><td>deploy timestamp、U-Boot boot log、/sys/firmware/fdt checksum</td></tr>
<tr><td>`compatible` 正確但 driver 未 probe</td><td>kernel config 未開、status disabled、binding 必填 property 缺、driver built as module 未載入</td><td>dmesg、zcat /proc/config.gz、lsmod、/proc/device-tree node</td></tr>
<tr><td>I2C device 不出現</td><td>7-bit address 錯、mux channel 錯、pinmux / pull-up / rail / reset 問題</td><td>i2cdetect、scope、pinctrl、DTS child node</td></tr>
<tr><td>GPIO line name 錯位</td><td>gpio-line-names 順序錯、bank offset 理解錯、running DTB 舊</td><td>gpioinfo、/proc/device-tree、DTS bank 對照</td></tr>
<tr><td>presence / fault 反相</td><td>GPIO_ACTIVE_LOW / userspace logical value / physical level 混淆</td><td>scope、gpioget、gpioinfo active-low、OpenBMC config</td></tr>
<tr><td>driver deferred probe</td><td>clock / regulator / reset provider 未 ready 或 phandle 錯</td><td>/sys/kernel/debug/devices_deferred、dmesg、clk_summary、regulator</td></tr>
<tr><td>flash partition 不符合預期</td><td>DTS fixed-partitions、U-Boot mtdparts、bootloader partition table 不一致</td><td>/proc/mtd、/proc/cmdline、running.dts、U-Boot env</td></tr>
<tr><td>UART console 不見</td><td>stdout-path、bootargs、pinmux、clock、baud rate 不一致</td><td>U-Boot env、/proc/cmdline、pinctrl、scope UART TX</td></tr>
<tr><td>MAC link 不起</td><td>phy-mode、MDIO address、PHY reset / clock / rail、NC-SI dependency</td><td>dmesg、MDIO sysfs、scope REFCLK、ethtool</td></tr>
<tr><td>dtbs_check 出現 unrelated warnings</td><td>kernel tree 既有平台 warning、schema 版本差異</td><td>先限縮到特定 DTB / binding，再比對本次 patch 新增 warning</td></tr>
<tr><td>OpenBMC inventory 缺裝置</td><td>kernel device 未 probe、Entity Manager Probe 不匹配、presence source 不一致</td><td>D-Bus tree、journal、/sys/bus devices、GPIO presence</td></tr>
</table>

#### 8.18 Bring-up 建議流程

- 先確認 SoC DTSI、board DTS、machine config、kernel recipe 使用的是同一個平台名稱。
- 從 boot-critical device 開始：UART、boot flash、DDR memory node、watchdog、reset reason、MAC / NC-SI。
- 逐條啟用 bus controller：I2C、SPI、PWM/tach、ADC、eSPI/LPC/KCS、USB gadget；每次啟用後保存 dmesg 與 `/sys/bus` 狀態。
- 建立 schematic net → DTS node → Linux device → OpenBMC object 對照表。
- 對每個 I2C / SPI child 填 `compatible`、`reg`、driver、kernel config、power dependency、owner。
- 對每條 GPIO 填 line name、offset、active level、physical level、logical state、consumer。
- 對 flash partition 核對 DTS、U-Boot mtdparts、Yocto image layout、update service。
- 每次 DTS patch 都跑 dtc / dtbs / dtbs_check，至少確認沒有本次新增的 warning。
- 每次更新 image 後從 target 反編譯 running DTB，確認實際內容已更新。
- 將 DT debug log、UART log、dmesg、journal、bus scan、gpioinfo、pinctrl、clk_summary 一起保存。

#### 8.19 當前平台 Device Tree 實測表

<table>
<tr><th>項目</th><th>指令 / 來源</th><th>實測值</th><th>備註</th></tr>
<tr><td>Board DTS 檔名</td><td>kernel tree / machine config</td><td>[待填]</td><td>需對應 MACHINE</td></tr>
<tr><td>SoC DTSI</td><td>#include / git grep</td><td>[待填]</td><td>SoC revision / package 差異</td></tr>
<tr><td>DTB build output</td><td>tmp/deploy/images/${MACHINE}</td><td>[待填]</td><td>記錄 checksum</td></tr>
<tr><td>Running model</td><td>cat /proc/device-tree/model</td><td>[待填]</td><td>target 實際值</td></tr>
<tr><td>Running compatible</td><td>tr '\0' '\n' &lt; /proc/device-tree/compatible</td><td>[待填]</td><td>需含 board 與 SoC compatible</td></tr>
<tr><td>Kernel bootargs</td><td>cat /proc/cmdline</td><td>[待填]</td><td>chosen / U-Boot 最終結果</td></tr>
<tr><td>I2C bus list</td><td>i2cdetect -l</td><td>[待填]</td><td>mux 後 bus number 需保存</td></tr>
<tr><td>GPIO line names</td><td>gpioinfo</td><td>[待填]</td><td>與 schematic 對照</td></tr>
<tr><td>Flash partitions</td><td>cat /proc/mtd</td><td>[待填]</td><td>需與第 2 章一致</td></tr>
<tr><td>Deferred probe</td><td>cat /sys/kernel/debug/devices_deferred</td><td>[待填]</td><td>需說明每一項原因</td></tr>
<tr><td>Pinctrl 狀態</td><td>/sys/kernel/debug/pinctrl</td><td>[待填]</td><td>關鍵 pinmux 必填</td></tr>
<tr><td>Clock summary</td><td>/sys/kernel/debug/clk/clk_summary</td><td>[待填]</td><td>關鍵 controller clock 必填</td></tr>
<tr><td>Regulator 狀態</td><td>/sys/class/regulator</td><td>[待填]</td><td>若 DTS 有 supply 必填</td></tr>
<tr><td>OpenBMC object 對照</td><td>busctl tree</td><td>[待填]</td><td>inventory / sensor / network</td></tr>
</table>

#### 8.20 回查結果

本章已回頭檢查前後文，並補齊下列銜接點：

- 第 2 章 Flash / Storage 已有 partition 與 update 流程，本章補上 DTS fixed-partitions 與 `/proc/mtd` 對齊方式。
- 第 3 章 Pinmux / GPIO 已有 GPIO line、active level、OpenBMC presence，本章補上 DT 中 pinctrl、gpio-line-names 與 consumer GPIO 寫法。
- 第 4 章 Reset / Clock / Power Domain 已有 dependency 與 timing，本章補上 `clocks`、`resets`、`*-supply` 與 deferred probe 的檢查入口。
- 第 5 章周邊匯流排已涵蓋 I2C / SPI / UART / NC-SI 等 bus，本章補上各 bus 在 DTS 中的常見節點與 runtime 驗證。
- 第 7 章 Build System 已涵蓋 Yocto / kernel build，本章補上 `virtual/kernel`、DTB deploy、`dtbs_check` 與 running DTB 反編譯流程。

#### 8.21 驗收 Checklist

-  Board DTS、SoC DTSI、MACHINE、kernel recipe、deploy DTB 已確認對應同一平台。
-  DTS 修改後已確認 DTB / FIT image / update package 重新產出。
-  Target running DTB 已反編譯並與 source patch 比對。
-  `compatible`、`reg`、`#address-cells`、`#size-cells` 已依 binding 檢查。
-  I2C device address 已確認為 7-bit address，mux channel 與 runtime bus number 已記錄。
-  SPI flash partition 與 U-Boot mtdparts、Yocto image layout、update service 一致。
-  GPIO line name、active level、physical level、logical state 已實測。
-  pinctrl state 已確認，沒有互斥功能共用同一 pin。
-  interrupt parent、IRQ type、clear rule、debounce / latch policy 已確認。
-  clocks / resets / supplies 與 driver binding 一致，沒有未解釋的 deferred probe。
-  UART console、chosen bootargs、aliases、stdout-path 與實際 console 對齊。
-  MAC / PHY / NC-SI mode、MDIO address、reset / clock / rail 已驗證。
-  PWM / tach / ADC / watchdog / RTC controller 已依平台需求啟用並驗證 sysfs / D-Bus。
-  reserved-memory 與 memory node 無重疊，容量與 DDR init / bootloader 一致。
-  dtc W=1 / W=2 與 dtbs_check 已保存 log，新增 warning 已處理或記錄原因。
-  DT debug log 套件、UART、dmesg、journal、gpioinfo、pinctrl、clk_summary 已保存。

#### 8.22 本章參考資料

- Linux kernel documentation - Linux and the Devicetree: [https://www.kernel.org/doc/html/latest/devicetree/usage-model.html](https://www.kernel.org/doc/html/latest/devicetree/usage-model.html)
- Linux kernel documentation - Open Firmware and Devicetree index: [https://docs.kernel.org/devicetree/index.html](https://docs.kernel.org/devicetree/index.html)
- Devicetree Specification: [https://www.devicetree.org/specifications/](https://www.devicetree.org/specifications/)
- Devicetree Specification basics: [https://devicetree-specification.readthedocs.io/en/stable/devicetree-basics.html](https://devicetree-specification.readthedocs.io/en/stable/devicetree-basics.html)
- Linux kernel documentation - DTS coding style: [https://docs.kernel.org/devicetree/bindings/dts-coding-style.html](https://docs.kernel.org/devicetree/bindings/dts-coding-style.html)
- Linux kernel documentation - Writing Devicetree Bindings in json-schema: [https://www.kernel.org/doc/html/latest/devicetree/bindings/writing-schema.html](https://www.kernel.org/doc/html/latest/devicetree/bindings/writing-schema.html)
- Devicetree schema tools: [https://github.com/devicetree-org/dt-schema](https://github.com/devicetree-org/dt-schema)


### 9. Kernel Driver 與核心服務

本章整理 BMC 平台移植時常遇到的 Linux kernel driver、driver model、probe flow、resource dependency、deferred probe、sysfs / debugfs / hwmon / input / net / mtd / watchdog interface、kernel config、module / built-in、OpenBMC service 銜接與排查方法。第 8 章已說明 Device Tree 如何描述硬體；本章接著說明 kernel 如何把 DT node 轉成 device，如何讓 driver match / probe，並在 probe 成功後提供 userspace 可讀寫的介面。

BMC 平台的 kernel driver 問題常呈現為：I2C device 沒有出現、hwmon 沒值、fan tach 沒讀值、PWM 無輸出、GPIO line busy、MTD partition 不對、watchdog reset、network link 不起、MCTP endpoint 不見、service 讀不到 D-Bus object。這些現象不一定都是 OpenBMC service 問題；很多時候真正的入口是 driver 是否 probe、resource 是否 ready、sysfs 是否建立、kernel config 是否啟用、device 是否被正確綁定。

#### 9.1 Linux Driver Model 基本觀念

Linux driver model 把 bus、device、driver 統一到共同模型。Bus 負責 match device 與 driver；driver 註冊 probe / remove / suspend / resume 等 callback；device 則由 Device Tree、ACPI、PCI enumeration、I2C core、SPI core、platform code 或 hotplug 流程建立。

典型關係：

```text
Device Tree / bus enumeration / hotplug
    ↓
struct device / bus-specific device
    ↓
bus match：compatible / id_table / modalias / ACPI / PCI ID
    ↓
driver probe
    ↓
取得 resource：regulator / clock / reset / GPIO / IRQ / pinctrl / memory / DMA
    ↓
初始化硬體
    ↓
註冊 subsystem interface：hwmon / iio / gpiochip / netdev / mtd / watchdog / input / rtc / misc
    ↓
userspace service / OpenBMC daemon 讀取 sysfs / D-Bus / netlink / character device
```

<table>
<tr><th>角色</th><th>說明</th><th>BMC 常見例子</th><th>檢查入口</th></tr>
<tr><td>Bus</td><td>device 與 driver 的 match domain</td><td>platform、i2c、spi、pci、mdio、usb、mctp</td><td>/sys/bus、dmesg</td></tr>
<tr><td>Device</td><td>kernel 看到的硬體實體或 logical device</td><td>i2c-5/5-0048、spi0.0、platform device、eth0</td><td>/sys/bus/*/devices</td></tr>
<tr><td>Driver</td><td>支援一類 device 的 kernel driver</td><td>tmp75、pmbus、aspeed-gpio、aspeed-pwm-tacho</td><td>/sys/bus/*/drivers、lsmod</td></tr>
<tr><td>Probe</td><td>driver 對 device 初始化</td><td>讀 DT、request IRQ、enable clock、register hwmon</td><td>dmesg、dynamic debug、trace</td></tr>
<tr><td>Subsystem</td><td>driver 對 userspace 暴露的標準介面</td><td>hwmon、iio、gpio、mtd、net、watchdog</td><td>/sys/class、debugfs</td></tr>
</table>

#### 9.2 Driver probe 典型流程

不同 bus 的 probe 細節不同，但 BMC driver 大多遵循下列順序：

```text
1. driver register
2. bus match device 與 driver
3. probe callback 被呼叫
4. 讀取 DT / firmware node / platform data
5. 取得 MMIO / I2C client / SPI device / PCI resource
6. 取得 clock / reset / regulator / GPIO / IRQ / pinctrl
7. 初始化硬體 register / mode / timing / calibration
8. 註冊 subsystem interface，例如 hwmon、gpiochip、iio、netdev、mtd
9. 建立 sysfs / debugfs / device attribute
10. userspace daemon 開始讀取或監控
```

Probe function 內常見 resource：

<table>
<tr><th>Resource</th><th>常見 API / 來源</th><th>probe 失敗常見現象</th><th>排查入口</th></tr>
<tr><td>MMIO reg</td><td>platform resource、ioremap</td><td>driver probe fail、register read timeout</td><td>/proc/iomem、dmesg</td></tr>
<tr><td>I2C client</td><td>DT child node、new_device</td><td>device 不存在或 driver 不綁定</td><td>/sys/bus/i2c/devices</td></tr>
<tr><td>SPI device</td><td>SPI child node、chip select</td><td>flash probe fail、JEDEC ID 錯</td><td>dmesg spi-nor、/proc/mtd</td></tr>
<tr><td>Clock</td><td>clocks / clock-names</td><td>-EPROBE_DEFER、baud / bus speed 異常</td><td>clk_summary、dmesg</td></tr>
<tr><td>Reset</td><td>resets / reset-names、reset-gpios</td><td>device timeout、link 不起</td><td>debugfs reset、scope</td></tr>
<tr><td>Regulator</td><td>vdd-supply、regulator-fixed</td><td>supply not found、device 無 ACK</td><td>/sys/class/regulator、dmesg</td></tr>
<tr><td>GPIO</td><td>reset-gpios、enable-gpios、interrupt-gpios</td><td>GPIO busy、polarity 反相</td><td>gpioinfo、debugfs gpio</td></tr>
<tr><td>IRQ</td><td>interrupts、interrupt-parent</td><td>事件不觸發、IRQ storm</td><td>/proc/interrupts、dmesg</td></tr>
<tr><td>Pinctrl</td><td>pinctrl-0、pinctrl-names</td><td>bus 無波形、GPIO 不動</td><td>pinctrl debugfs</td></tr>
</table>

#### 9.3 Bus match：platform、I2C、SPI、PCI、MDIO

不同 bus 的 match key 不同。排查 driver 不 probe 時，先確認 device 是否存在，再確認 match key 是否正確。

<table>
<tr><th>Bus</th><th>Device 來源</th><th>Driver match key</th><th>BMC 常見例子</th><th>檢查入口</th></tr>
<tr><td>platform</td><td>DT SoC node / platform device</td><td>of_match_table compatible</td><td>GPIO、PWM、ADC、watchdog、LPC/eSPI</td><td>/sys/bus/platform/devices</td></tr>
<tr><td>I2C</td><td>DT child node / new_device / detection daemon</td><td>i2c_device_id、of_match_table</td><td>temperature sensor、EEPROM、PMBus、CPLD</td><td>/sys/bus/i2c/devices</td></tr>
<tr><td>SPI</td><td>DT child node / spi controller</td><td>of_match_table / spi id</td><td>SPI-NOR、SPI-NAND、TPM、ADC</td><td>/sys/bus/spi/devices</td></tr>
<tr><td>PCI</td><td>PCI enumeration</td><td>vendor / device ID、class code</td><td>NIC、GPU、accelerator、PCIe switch</td><td>lspci、/sys/bus/pci/devices</td></tr>
<tr><td>MDIO</td><td>MDIO scan 或 DT PHY node</td><td>PHY ID / compatible</td><td>Ethernet PHY</td><td>/sys/bus/mdio_bus/devices</td></tr>
<tr><td>USB</td><td>USB enumeration</td><td>VID / PID / class</td><td>USB gadget / host debug devices</td><td>lsusb、/sys/bus/usb/devices</td></tr>
</table>

常見檢查：

```bash
# platform
ls -l /sys/bus/platform/devices
ls -l /sys/bus/platform/drivers

# I2C
ls -l /sys/bus/i2c/devices
i2cdetect -l

# SPI
ls -l /sys/bus/spi/devices

# PCI
lspci -nn 2>/dev/null
ls -l /sys/bus/pci/devices 2>/dev/null

# MDIO / net
find /sys/bus/mdio_bus/devices -maxdepth 2 -type f -print 2>/dev/null
ip link
```

#### 9.4 Deferred probe 與 dependency 排查

Deferred probe 是 embedded / BMC 平台常見現象：device 已建立、driver 也找到，但某個必要 resource 尚未 ready，例如 regulator provider、clock provider、GPIO controller、I2C mux、reset controller、interrupt controller。driver 應回傳 `-EPROBE_DEFER`，kernel driver core 之後會重試。

常見原因：

- `*-supply` 指向的 regulator node 尚未註冊。
- `clocks` / `resets` phandle 指向的 provider 沒有 probe。
- GPIO expander 在 I2C mux 後面，mux driver 尚未 ready。
- interrupt controller 或 parent domain 未建立。
- pinctrl provider 尚未 ready。
- device link / power domain dependency 未完成。

檢查指令：

```bash
mount | grep debugfs || mount -t debugfs debugfs /sys/kernel/debug
cat /sys/kernel/debug/devices_deferred 2>/dev/null

dmesg | grep -Ei 'defer|probe|supply|regulator|clock|clk|reset|gpio|pinctrl|irq|interrupt|power domain'

cat /sys/kernel/debug/clk/clk_summary 2>/dev/null | head -200
find /sys/class/regulator -maxdepth 2 -type l -o -type d 2>/dev/null
cat /sys/kernel/debug/gpio 2>/dev/null
```

判讀建議：

- `devices_deferred` 有內容時，不要只看最後一個錯誤；需順著 dependency 找 provider。
- 若某 device 永遠 deferred，通常是 DT phandle、kernel config、provider driver 或 probe order 有問題。
- 若 provider 是 module，但 rootfs 尚未載入 module，built-in consumer 可能卡在 deferred。
- 若 dependency 來自可插拔裝置，需定義 absent 時是否應 deferred、fail 或標 unavailable。

#### 9.5 Kernel config、built-in、module 與 image 整合

Driver source 存在不代表 image 有啟用。BMC porting 時需確認 kernel config、module package、device tree、userspace service 四者對齊。

常用檢查：

```bash
# Target 端 kernel config
zcat /proc/config.gz | grep -Ei 'HWMON|I2C|GPIO|PINCTRL|PWM|TACH|ADC|IIO|WATCHDOG|MTD|MCTP|PLDM' 2>/dev/null

# module
lsmod
modinfo <driver> 2>/dev/null
find /lib/modules/$(uname -r) -name '*<driver>*' 2>/dev/null

# build 端
bitbake -e virtual/kernel | grep '^S='
bitbake -e virtual/kernel | grep '^B='
```

設計建議：

- boot-critical driver 建議 built-in，例如 boot flash、rootfs storage、UART console、watchdog 或 early reset reason。
- 可選 sensor / debug driver 可用 module，但需確保 package 加入 image 且 service dependency 正確。
- 若 OpenBMC service 開機早期需要某 sysfs path，driver 若是 module 需確認載入時機。
- kernel config fragment、defconfig、Yocto recipe append 與實際 `/proc/config.gz` 需一致。

#### 9.6 sysfs / debugfs / hwmon / iio / input / net 常見介面

Driver probe 成功後，通常會註冊一種或多種 subsystem interface。OpenBMC service 多半讀取這些標準介面，再轉成 D-Bus object。

<table>
<tr><th>Subsystem</th><th>常見路徑</th><th>BMC 用途</th><th>常見 consumer</th></tr>
<tr><td>hwmon</td><td>/sys/class/hwmon/hwmonX</td><td>temperature、voltage、current、power、fan RPM</td><td>dbus-sensors、psusensor、fansensor</td></tr>
<tr><td>IIO</td><td>/sys/bus/iio/devices/iio:deviceX</td><td>ADC raw value、scale、channel</td><td>adcsensor、iio-hwmon</td></tr>
<tr><td>GPIO</td><td>/dev/gpiochipX、gpioinfo</td><td>presence、reset、power enable、fault</td><td>gpio-monitor、Entity Manager、platform daemon</td></tr>
<tr><td>MTD</td><td>/proc/mtd、/dev/mtdX</td><td>flash partition、update、rwfs</td><td>update service、storage scripts</td></tr>
<tr><td>netdev</td><td>/sys/class/net、ip link</td><td>BMC network、NC-SI、RGMII</td><td>networkd、bmcweb、SSH</td></tr>
<tr><td>watchdog</td><td>/dev/watchdog、/sys/class/watchdog</td><td>BMC recovery</td><td>systemd、watchdog daemon</td></tr>
<tr><td>input</td><td>/dev/input/eventX</td><td>buttons、GPIO keys</td><td>button handler、power control</td></tr>
<tr><td>rtc</td><td>/sys/class/rtc/rtcX</td><td>timekeeping</td><td>systemd-timesyncd、time service</td></tr>
<tr><td>debugfs</td><td>/sys/kernel/debug</td><td>pinctrl、clk、gpio、tracing</td><td>debug only</td></tr>
</table>

檢查指令：

```bash
find /sys/class/hwmon -maxdepth 2 -type f -print | sort
find /sys/bus/iio/devices -maxdepth 2 -type f -print 2>/dev/null | sort
gpiodetect 2>/dev/null
gpioinfo 2>/dev/null
cat /proc/mtd 2>/dev/null
ip link
find /sys/class/watchdog -maxdepth 2 -type f -print 2>/dev/null
```

#### 9.7 OpenBMC service 與 kernel interface 銜接

OpenBMC service 多數不是直接接硬體，而是讀 kernel 暴露的 interface。排查時需先確認 kernel 層，再確認 userspace。

```text
Kernel driver / subsystem
    ↓
sysfs / device node / netlink / D-Bus provider
    ↓
OpenBMC daemon
    ↓
D-Bus object / property / signal
    ↓
Redfish / IPMI / policy / event
```

常見對照：

<table>
<tr><th>Kernel interface</th><th>OpenBMC service</th><th>D-Bus 目標</th><th>常見問題</th></tr>
<tr><td>hwmon</td><td>dbus-sensors、psusensor、hwmontempsensor</td><td>/xyz/openbmc_project/sensors/...</td><td>hwmon label / scale / config 不匹配</td></tr>
<tr><td>IIO / iio-hwmon</td><td>adcsensor</td><td>voltage sensor</td><td>ADC channel / scale 不對</td></tr>
<tr><td>GPIO</td><td>gpio presence、power control、intrusion</td><td>inventory / state / event</td><td>line name / polarity / busy</td></tr>
<tr><td>MTD / UBI</td><td>phosphor-bmc-code-mgmt、update scripts</td><td>software inventory</td><td>partition name 不一致</td></tr>
<tr><td>watchdog</td><td>systemd watchdog、platform watchdog</td><td>state / event</td><td>reset 範圍與 timeout 不明</td></tr>
<tr><td>netdev</td><td>systemd-networkd、phosphor-network</td><td>network config / Redfish EthernetInterface</td><td>link / MAC / DHCP / NC-SI</td></tr>
</table>

#### 9.8 Driver 開發與修改流程

BMC 專案常需要修改 kernel driver 或新增 platform quirk。建議流程：

1. 先確認是否已有 upstream driver / binding。
2. 在第 8 章補齊 DTS node 與 binding 檢查。
3. 在 kernel tree 以最小 patch 修改 driver。
4. 使用 Yocto `devtool modify virtual/kernel` 或 kernel recipe patch 管理。
5. 只修改必要差異，避免把 board policy 寫死在通用 driver。
6. 建立 target 驗證指令、dmesg pattern、sysfs output 與 D-Bus 對照。
7. 若修改會影響共用 driver，需回查其他 machine / board。

Patch 檢查重點：

- 錯誤路徑是否釋放 resource。
- 是否使用 managed resource，例如 devm_* API，降低 remove / error path 風險。
- probe fail 是永久錯誤還是 `-EPROBE_DEFER`。
- 是否支援 module unload / reprobe，至少不造成 kernel oops。
- sysfs 屬性單位是否符合 kernel subsystem 慣例。
- 是否把 board-specific policy 留在 DTS / userspace，而不是硬寫在 driver。
- log level 是否合理，量產版不應大量 spam。

#### 9.9 Dynamic debug、tracepoint 與 ftrace

當 dmesg 資訊不夠時，可用 dynamic debug 或 ftrace 追 probe / driver 行為。使用前需確認 kernel config 是否啟用。

```bash
# dynamic debug
mount | grep debugfs || mount -t debugfs debugfs /sys/kernel/debug
cat /sys/kernel/debug/dynamic_debug/control 2>/dev/null | grep <driver>

echo 'file drivers/hwmon/<driver>.c +p' > /sys/kernel/debug/dynamic_debug/control
# 或依 function
echo 'func <function_name> +p' > /sys/kernel/debug/dynamic_debug/control

# function trace，請謹慎使用，避免大量輸出
cd /sys/kernel/debug/tracing
echo 0 > tracing_on
echo function > current_tracer
echo '<function_name>' > set_ftrace_filter
echo 1 > tracing_on
sleep 3
echo 0 > tracing_on
cat trace > /tmp/ftrace-driver.txt
```

注意事項：

- tracing 可能影響 timing，排查 race / timeout 時需註明是否啟用。
- dynamic debug 設定通常重開機後消失，debug package 需保存設定與 log。
- 不要在量產環境長時間開啟大量 trace。

#### 9.10 Kernel panic、oops、lockdep 與 crash 排查

Kernel issue 可能是 driver probe、interrupt handler、workqueue、runtime PM、sysfs store callback 或 remove path 造成。需要保存完整 panic / oops 前後文。

建議保存：

```bash
dmesg -T > /tmp/dmesg.txt
journalctl -k -b --no-pager > /tmp/journal-kernel-current.txt
journalctl -k -b -1 --no-pager > /tmp/journal-kernel-previous.txt 2>&1
cat /proc/modules > /tmp/proc-modules.txt
cat /proc/interrupts > /tmp/proc-interrupts.txt
cat /proc/iomem > /tmp/proc-iomem.txt
cat /proc/slabinfo > /tmp/proc-slabinfo.txt 2>/dev/null
```

排查方向：

- Null pointer dereference：probe error path / optional resource 未檢查。
- Use-after-free：remove / hotplug / module unload / workqueue 競爭。
- IRQ storm：interrupt trigger type、status clear、shared IRQ。
- Sleeping in atomic：IRQ handler 或 spinlock 內呼叫 sleep API。
- Lockdep warning：driver lock order 或 subsystem callback 互相等待。
- Kernel panic after rootfs mount：driver 註冊 userspace 可見介面後被 service 觸發。

#### 9.11 Target 端 kernel driver debug log 收集

```bash
mkdir -p /tmp/kernel-driver-debug
cat /etc/os-release > /tmp/kernel-driver-debug/os-release.txt
uname -a > /tmp/kernel-driver-debug/uname.txt
cat /proc/cmdline > /tmp/kernel-driver-debug/proc-cmdline.txt
zcat /proc/config.gz > /tmp/kernel-driver-debug/proc-config.txt 2>&1

dmesg -T > /tmp/kernel-driver-debug/dmesg.txt
journalctl -k -b --no-pager > /tmp/kernel-driver-debug/journal-kernel-current.txt
journalctl -k -b -1 --no-pager > /tmp/kernel-driver-debug/journal-kernel-previous.txt 2>&1
journalctl -b --no-pager > /tmp/kernel-driver-debug/journal-current.txt
systemctl --failed > /tmp/kernel-driver-debug/systemctl-failed.txt 2>&1

# bus / devices
find /sys/bus/platform/devices -maxdepth 1 -print > /tmp/kernel-driver-debug/platform-devices.txt 2>&1
find /sys/bus/i2c/devices -maxdepth 2 -print > /tmp/kernel-driver-debug/i2c-devices.txt 2>&1
find /sys/bus/spi/devices -maxdepth 2 -print > /tmp/kernel-driver-debug/spi-devices.txt 2>&1
find /sys/class/hwmon -maxdepth 3 -type f -print > /tmp/kernel-driver-debug/hwmon-files.txt 2>&1
find /sys/bus/iio/devices -maxdepth 3 -type f -print > /tmp/kernel-driver-debug/iio-files.txt 2>&1

# debugfs
mount | grep debugfs || mount -t debugfs debugfs /sys/kernel/debug
cat /sys/kernel/debug/devices_deferred > /tmp/kernel-driver-debug/devices-deferred.txt 2>&1
cat /sys/kernel/debug/gpio > /tmp/kernel-driver-debug/debug-gpio.txt 2>&1
cat /sys/kernel/debug/clk/clk_summary > /tmp/kernel-driver-debug/clk-summary.txt 2>&1
find /sys/kernel/debug/pinctrl -maxdepth 3 -type f -print > /tmp/kernel-driver-debug/pinctrl-files.txt 2>&1

# system state
cat /proc/interrupts > /tmp/kernel-driver-debug/proc-interrupts.txt
cat /proc/iomem > /tmp/kernel-driver-debug/proc-iomem.txt
cat /proc/modules > /tmp/kernel-driver-debug/proc-modules.txt
lsmod > /tmp/kernel-driver-debug/lsmod.txt 2>&1

tar czf /tmp/kernel-driver-debug-$(date +%Y%m%d-%H%M%S).tar.gz -C /tmp kernel-driver-debug
```

#### 9.12 常見問題與排查入口

<table>
<tr><th>現象</th><th>可能方向</th><th>第一輪檢查</th></tr>
<tr><td>driver 完全沒有 probe log</td><td>device 未建立、compatible 不匹配、kernel config 未開、module 未載入</td><td>DTS、/sys/bus、dmesg、/proc/config.gz</td></tr>
<tr><td>probe 回傳 -EPROBE_DEFER</td><td>clock / regulator / reset / GPIO / pinctrl provider 未 ready</td><td>devices_deferred、dmesg、clk / regulator / gpio</td></tr>
<tr><td>I2C driver 沒綁定</td><td>address 錯、DT node 缺、id_table 不匹配、device 已被其他 driver 綁定</td><td>/sys/bus/i2c/devices、driver symlink、i2cdetect</td></tr>
<tr><td>hwmonX 每次不同</td><td>hwmon index 動態分配</td><td>用 name / label / device path，不要寫死 hwmonX</td></tr>
<tr><td>sysfs 有值但 D-Bus 沒值</td><td>OpenBMC config / service / label / power state gating 問題</td><td>journal、busctl、Entity Manager config</td></tr>
<tr><td>GPIO busy</td><td>GPIO hog、driver consumer、另一個 daemon 已 request</td><td>gpioinfo consumer、debugfs gpio</td></tr>
<tr><td>IRQ storm</td><td>trigger type 錯、status 未 clear、level interrupt 仍 asserted</td><td>/proc/interrupts、scope、driver log</td></tr>
<tr><td>network link 不起</td><td>PHY driver、MDIO、reset、clock、phy-mode</td><td>dmesg、ethtool、MDIO sysfs、scope</td></tr>
<tr><td>watchdog 非預期 reset</td><td>timeout 太短、feed service fail、reset target 不明</td><td>journal previous boot、reset reason、watchdog sysfs</td></tr>
<tr><td>kernel oops</td><td>driver bug、error path、race、IRQ / workqueue 問題</td><td>完整 oops log、symbol、kernel commit</td></tr>
</table>

#### 9.13 Bring-up 建議流程

- 確認 kernel config 與 driver 是否 built-in / module。
- 確認 Device Tree node、compatible、reg、interrupt、clock、reset、GPIO、supply 與 binding 一致。
- 開機後先看 dmesg，再看 `/sys/bus/*/devices` 是否出現 device。
- 確認 driver symlink 是否建立，並保存 probe log。
- 檢查 `devices_deferred`，逐項解 dependency。
- 確認 subsystem interface 是否出現：hwmon、iio、gpiochip、mtd、watchdog、netdev。
- 再檢查 OpenBMC service 是否讀到對應 sysfs / device node。
- 建立 kernel interface → D-Bus object → Redfish / IPMI 的對照表。
- 做 service restart、BMC reboot、AC cycle、host power transition、hot-plug、fault injection。
- 保存 kernel-driver-debug log、DTS / kernel commit、image version 與實測結果。

#### 9.14 當前平台 Kernel Driver 實測表

<table>
<tr><th>項目</th><th>指令 / 來源</th><th>實測值</th><th>備註</th></tr>
<tr><td>Kernel version</td><td>uname -a</td><td>[待填]</td><td>需對應 kernel commit</td></tr>
<tr><td>Kernel config</td><td>zcat /proc/config.gz</td><td>[待填]</td><td>關鍵 driver config</td></tr>
<tr><td>Boot driver log</td><td>dmesg -T</td><td>[待填]</td><td>保存完整 log</td></tr>
<tr><td>Deferred probe</td><td>/sys/kernel/debug/devices_deferred</td><td>[待填]</td><td>需逐項說明原因</td></tr>
<tr><td>Platform devices</td><td>/sys/bus/platform/devices</td><td>[待填]</td><td>SoC controller</td></tr>
<tr><td>I2C devices</td><td>/sys/bus/i2c/devices</td><td>[待填]</td><td>sensor / FRU / PMBus</td></tr>
<tr><td>SPI devices</td><td>/sys/bus/spi/devices</td><td>[待填]</td><td>flash / TPM</td></tr>
<tr><td>hwmon mapping</td><td>/sys/class/hwmon</td><td>[待填]</td><td>不要只記 hwmonX</td></tr>
<tr><td>IIO mapping</td><td>/sys/bus/iio/devices</td><td>[待填]</td><td>ADC channel</td></tr>
<tr><td>GPIO chips</td><td>gpioinfo</td><td>[待填]</td><td>line name / consumer</td></tr>
<tr><td>Clock summary</td><td>clk_summary</td><td>[待填]</td><td>key controller clock</td></tr>
<tr><td>Regulator state</td><td>/sys/class/regulator</td><td>[待填]</td><td>supply dependency</td></tr>
<tr><td>Watchdog</td><td>/sys/class/watchdog</td><td>[待填]</td><td>timeout / nowayout</td></tr>
<tr><td>Network driver</td><td>ip link / ethtool</td><td>[待填]</td><td>MAC / PHY / NC-SI</td></tr>
<tr><td>OpenBMC consumer</td><td>busctl / journal</td><td>[待填]</td><td>D-Bus object 對照</td></tr>
</table>

#### 9.15 驗收 Checklist

-  Kernel config、driver built-in / module、Yocto recipe 與 image package 已確認。
-  DTS node 與 driver binding、compatible、resource、interrupt、clock、reset、GPIO、supply 一致。
-  Target 上 device 已出現在正確 bus，例如 platform、i2c、spi、pci、mdio。
-  Driver symlink 已建立，probe log 清楚，沒有未解釋的 probe fail。
-  `/sys/kernel/debug/devices_deferred` 為空，或每一項都有合理原因與追蹤 owner。
-  hwmon / IIO / GPIO / MTD / watchdog / netdev 等 subsystem interface 已出現且數值合理。
-  OpenBMC service 能讀取 kernel interface 並建立 D-Bus object。
-  GPIO consumer、IRQ、pinctrl、clock、regulator 狀態與設計表一致。
-  Service restart、BMC reboot、AC cycle、host power transition 後 driver 狀態穩定。
-  Fault injection / hot-plug / timeout 測試已保存 kernel log 與 D-Bus / Redfish 對照。
-  dynamic debug / ftrace 使用方式已驗證，且不會長時間留在量產設定。
-  kernel oops / panic / watchdog reset 能收集到 previous boot journal、reset reason 與版本資訊。
-  kernel-driver-debug log 套件、DTS / kernel commit、image version 已保存。

#### 9.17 本章參考資料

- Linux kernel documentation - Driver Model: [https://docs.kernel.org/driver-api/driver-model/index.html](https://docs.kernel.org/driver-api/driver-model/index.html)
- Linux kernel documentation - Device Drivers: [https://www.kernel.org/doc/html/latest/driver-api/driver-model/driver.html](https://www.kernel.org/doc/html/latest/driver-api/driver-model/driver.html)
- Linux kernel documentation - Device drivers infrastructure: [https://www.kernel.org/doc/html/v4.14/driver-api/infrastructure.html](https://www.kernel.org/doc/html/v4.14/driver-api/infrastructure.html)
- Linux kernel driver core `drivers/base/dd.c`: [https://github.com/torvalds/linux/blob/master/drivers/base/dd.c](https://github.com/torvalds/linux/blob/master/drivers/base/dd.c)
- Linux kernel documentation - Dynamic debug: [https://docs.kernel.org/admin-guide/dynamic-debug-howto.html](https://docs.kernel.org/admin-guide/dynamic-debug-howto.html)
- Linux kernel documentation - ftrace: [https://docs.kernel.org/trace/ftrace.html](https://docs.kernel.org/trace/ftrace.html)


### 10. I2C / PMBus 裝置驅動架構

本章整理 BMC 平台中 I2C / SMBus / PMBus 裝置的硬體拓樸、Device Tree、Linux driver、hwmon/sysfs、OpenBMC `dbus-sensors`、Entity Manager、Redfish / IPMI 對映、fault handling 與 debug 方法。I2C 在 BMC 中不是單一 bus，而是常由 SoC I2C controller、I2C mux、GPIO expander、CPLD bridge、hot-swap 板卡、FRU EEPROM、PSU / VR / HSC PMBus 裝置串成多層拓樸。PMBus 則是在 SMBus / I2C 之上的電源管理命令集，用於讀取 voltage、current、power、temperature、fan、status word、fault bit、manufacturer data 等資訊。

Linux I2C 裝置不像 PCI / USB 一樣可由硬體自行枚舉，kernel 需要透過 Device Tree、ACPI、board data 或 userspace new_device 等方式明確建立裝置；BMC embedded 平台通常以 Device Tree 與 OpenBMC Entity Manager / dbus-sensors 共同描述固定與動態裝置。PMBus driver 也不會安全地自動探測所有裝置，因為沒有共同且一定安全的識別 register，通常需要明確指定 driver 與 address。這些限制會直接影響 bring-up 策略、bus scan 方法、hot-plug 設計與現場排查。

#### 10.1 I2C / SMBus / PMBus 分層模型

建議先把 I2C 類裝置分成五層理解：

```text
硬體拓樸
  SoC I2C controller / mux / expander / target device / pull-up rail
    ↓
Kernel 裝置模型
  i2c_adapter / i2c_client / driver / hwmon / gpiochip / eeprom / regmap
    ↓
sysfs / hwmon / debugfs
  /sys/bus/i2c/devices、/sys/class/hwmon、/sys/kernel/debug
    ↓
OpenBMC userspace
  Entity Manager、dbus-sensors、psusensor、hwmontempsensor、fru-device
    ↓
對外介面與 policy
  D-Bus、Redfish、IPMI SDR、SEL / EventLog、Fan / Power policy
```

| 層級 | 主要資料 | 常見問題 | 第一輪檢查 |
|------|----------|----------|------------|
| 硬體拓樸 | bus、mux channel、address、pull-up、rail、reset、INT | 無 ACK、clock stretch、bus stuck、address conflict | schematic、scope、LA、`i2cdetect` |
| Kernel | Device Tree node、`i2c_client`、driver binding、kernel config | driver 不 probe、錯 driver、deferred probe | `dmesg`、`/sys/bus/i2c/devices`、`lsmod` |
| `hwmon` / `sysfs` | `in*_input`、`curr*_input`、`power*_input`、`temp*_input`、`fault` / `status` | 數值比例錯、channel 缺失、label 錯 | `/sys/class/hwmon`、`sensors`、driver docs |
| OpenBMC | Entity Manager config、D-Bus sensor object、`availability`、`functional` | D-Bus object 缺失、service fail、threshold 錯 | `busctl`、`journalctl`、`systemctl` |
| 對外介面 | Redfish Sensor / Power / Thermal、IPMI SDR、event log | Web / Redfish 不顯示、IPMI sensor type 錯、事件反覆 | `curl`、`ipmitool`、`journal`、SEL |

#### 10.2 BMC 常見 I2C / PMBus 裝置類型

| 類型 | 常見裝置 | Kernel 子系統 | OpenBMC 對應 | 注意事項 |
|------|----------|---------------|---------------|----------|
| FRU EEPROM | 24C02 / 24C64 / M24256 | `at24` / `nvmem` | `fru-device`、Entity Manager Probe | address width、page size、write protect、FRU format |
| Temperature sensor | LM75、TMP75、EMC141x、TMP451 | `hwmon` | `hwmontempsensor` | local / remote channel、offset、fault handling |
| Voltage / Current / Power monitor | INA2xx、INA233、ADM1275、LM25066 | `hwmon` / `pmbus` | `psusensor`、`dbus-sensors` | shunt resistor、calibration、linear/direct format |
| PMBus PSU | CRPS、DPS、PFE、vendor PSU | `pmbus` / vendor driver | `psusensor`、power inventory | page、`MFR_*`、presence、AC lost、fault clear |
| PMBus VR / regulator | IR / MPS / TI multiphase VR | `pmbus` / vendor driver | voltage / current / power / temp sensors | page / phase、`VOUT` mode、`STATUS_WORD`、rail naming |
| GPIO expander | PCA9555、PCA9539、TCA64xx | `gpiochip` / `irqchip` | presence、LED、power state | reset default、INT、line name、polarity |
| I2C mux | PCA954x、GPIO mux、CPLD mux | `i2c-mux` | bus topology 基礎 | logical bus number、idle disconnect、mux select owner |
| CPLD / FPGA | board glue、fault latch、power sequence | `i2c` client / `regmap` / custom | platform daemon、power control | register map、W1C、latch clear、firmware version |
| Fan / thermal controller | EMC2305、MAX31790、NCT7802 | `hwmon` / `PWM` | `fansensor`、thermal policy | PWM polarity、tach divisor、fan presence gating |

#### 10.3 拓樸設計：bus、mux、channel、address

I2C 拓樸文件至少要記錄 physical bus、mux path、logical bus、device address、device type、driver、power domain 與 owner。尤其有 I2C mux 時，Linux 看到的是 logical bus number；這個 number 可能受到 probe 順序影響，因此測試表不能只寫 `i2c-12`，還要寫 physical path。

拓樸範本：

| Physical path | Linux bus | Mux path | Address | Device | Driver | Power domain | Owner | 狀態 |
|---------------|-----------|----------|---------|--------|--------|--------------|-------|------|
| BMC I2C5 | **[待填]** | none | `0x50` | baseboard FRU EEPROM | `at24` / `fru-device` | `3V3_AUX` | BMC | **[待確認]** |
| BMC I2C6 → PCA9548 ch0 | **[待填]** | `0x70/ch0` | `0x58` | PSU0 PMBus | `pmbus` / vendor | PSU standby | BMC / PSU | **[待確認]** |
| BMC I2C6 → PCA9548 ch1 | **[待填]** | `0x70/ch1` | `0x58` | PSU1 PMBus | `pmbus` / vendor | PSU standby | BMC / PSU | **[待確認]** |
| BMC I2C7 | **[待填]** | none | `0x20` | GPIO expander | `pca953x` | `3V3_AUX` | BMC | **[待確認]** |

Bring-up 注意事項：

- 同一 bus segment 上不可有 address conflict；mux 不同 channel 上可以重複 address，但文件需清楚標示 path。
- I2C pull-up 電源域要跟裝置 power state 對齊；host-dependent rail off 時，BMC 可能讀不到該 segment。
- I2C mux 若設定 idle disconnect，service 讀值時需允許 mux channel 切換時間。
- 若同一 bus 由 BMC、Host、CPLD 多方存取，需明確 bus owner、arbitration 與 host power state dependency。
- Hot-plug 裝置需有 presence source、debounce、scan/retry 策略與不存在時的 sensor availability policy。

#### 10.4 Device Tree：I2C controller、child device、mux

固定存在且 kernel driver 需要管理的 I2C device，建議在 DTS 中描述。動態板卡、SKU-dependent device 或 FRU 探測後才知道的 sensor，則可由 Entity Manager configuration 描述，再由 dbus-sensors 建立 D-Bus sensor。

I2C controller 與 child node 範本：

```dts
&i2c5 {
    status = "okay";
    bus-frequency = <100000>;

    eeprom@50 {
        compatible = "atmel,24c64";
        reg = <0x50>;
        pagesize = <32>;
    };

    temperature-sensor@48 {
        compatible = "ti,tmp75";
        reg = <0x48>;
    };
};
```

I2C mux 範本：

```dts
&i2c6 {
    status = "okay";
    bus-frequency = <100000>;

    i2c-mux@70 {
        compatible = "nxp,pca9548";
        reg = <0x70>;
        #address-cells = <1>;
        #size-cells = <0>;
        i2c-mux-idle-disconnect;

        i2c@0 {
            reg = <0>;
            #address-cells = <1>;
            #size-cells = <0>;

            psu0@58 {
                compatible = "pmbus";
                reg = <0x58>;
            };
        };

        i2c@1 {
            reg = <1>;
            #address-cells = <1>;
            #size-cells = <0>;

            psu1@58 {
                compatible = "pmbus";
                reg = <0x58>;
            };
        };
    };
};
```

DTS 檢查重點：

- I2C device `reg` 是 7-bit address，例如 datasheet 顯示 0x90/0x91 時，DTS 通常填 0x48。
- `bus-frequency` 需符合 bus segment 上最慢裝置與 signal integrity 量測結果。
- Mux channel child node 需有 `#address-cells = <1>; #size-cells = <0>;`，並用 `reg = <channel>` 表示 channel。
- 若裝置有 ALERT / INT / reset / enable pin，需在 DTS 或平台設定中補齊 active level 與 dependency。
- PMBus generic `compatible = "pmbus";` 可用於部分通用裝置，但 vendor-specific driver 常能提供較完整的 page、phase、format、fault support。

#### 10.5 Linux I2C 裝置模型與 sysfs 對照

Linux I2C 主要由 `i2c_adapter`、`i2c_client` 與 `i2c_driver` 組成。BMC target 上常用 `/sys/bus/i2c/devices` 觀察 bus 與 device：

```text
/sys/bus/i2c/devices/
  i2c-0        logical I2C bus
  i2c-1        logical I2C bus
  1-0048       bus 1, address 0x48 device
  6-0070       bus 6, address 0x70 mux
  i2c-20       mux channel logical bus
  20-0058      mux 後 PSU0 at 0x58
```

常用指令：

```bash
# 列出 logical I2C bus 與 adapter name
i2cdetect -l

# 查看 I2C sysfs 拓樸
ls -l /sys/bus/i2c/devices
find /sys/bus/i2c/devices -maxdepth 2 -type l -o -type d | sort

# 指定 bus 掃描，請先確認該 bus 可以安全掃描
i2cdetect -y <bus>

# 查看某 device 綁定的 driver
readlink /sys/bus/i2c/devices/<bus>-00<addr>/driver 2>/dev/null
cat /sys/bus/i2c/devices/<bus>-00<addr>/name 2>/dev/null
```

`i2cdetect` 使用提醒：

- 不建議在未確認前對 PMBus、EEPROM、CPLD、host-owned bus 執行 aggressive scan。
- 量產 log 收集可優先用 `i2cdetect -l`、sysfs topology、已知 safe register read，避免任意 probing。
- `UU` 表示該 address 已被 kernel driver 佔用，不代表錯誤；代表該 address 已有 i2c_client / driver。
- Bus number 是 logical number；請搭配 mux path 與 adapter name 判讀。

#### 10.6 Driver binding、new_device 與動態建立裝置

Bring-up 初期常需要先確認某顆 I2C device 是否能被 driver 綁定。若該 device 尚未寫進 DTS，可用 `new_device` 暫時建立 i2c_client；正式版本仍建議回到 DTS 或 Entity Manager / platform service 描述。

```bash
# 範例：在 i2c-5 的 0x48 建立 tmp75 device
echo tmp75 0x48 > /sys/bus/i2c/devices/i2c-5/new_device

# 移除該 device
echo 0x48 > /sys/bus/i2c/devices/i2c-5/delete_device
```

使用限制：

- `new_device` 是 bring-up / debug 工具，不應取代正式平台描述。
- driver 名稱需對應 kernel driver 的 i2c_device_id；不是 DTS compatible 字串一定可直接使用。
- 若 device 需要 GPIO、interrupt、supply、calibration data，單純 `new_device` 可能不足。
- 不可在已由 DTS 或 service 建立的 address 重複建立 device。

#### 10.7 hwmon sysfs 與 OpenBMC Sensor 資料流

許多 I2C / PMBus driver 會把讀值匯出到 `/sys/class/hwmon/hwmonX/`。OpenBMC `dbus-sensors` 會讀取 hwmon、D-Bus 或 direct driver access，並建立 `xyz.openbmc_project.Sensor` 相關 D-Bus object。

典型資料流：

```text
I2C / PMBus hardware
    ↓
Linux i2c driver / pmbus driver
    ↓
/sys/class/hwmon/hwmonX/*_input / *_label / *_alarm / *_fault
    ↓
Entity Manager configuration
    ↓
dbus-sensors daemon：hwmontempsensor / psusensor / fansensor 等
    ↓
/xyz/openbmc_project/sensors/<type>/<name>
    ↓
Redfish / IPMI SDR / Fan policy / Event log
```

常見 hwmon 屬性：

| 屬性 | 含義 | 單位慣例 | 常見來源 |
|------|------|----------|----------|
| `temp*_input` | 溫度 | milli-degree Celsius | LM75、PMBus `TEMP` |
| `in*_input` | 電壓 | millivolt | INA、PMBus `VIN` / `VOUT` |
| `curr*_input` | 電流 | milliampere | INA、PMBus `IIN` / `IOUT` |
| `power*_input` | 功率 | microwatt | PMBus `PIN` / `POUT` |
| `fan*_input` | 轉速 | RPM | fan controller、PMBus fan |
| `*_label` | channel 名稱 | 字串 | driver 或 config |
| `*_alarm` / `*_fault` | 告警 / fault | `0` / `1` | driver status mapping |

檢查指令：

```bash
find /sys/class/hwmon -maxdepth 2 -type f -print | sort
for h in /sys/class/hwmon/hwmon*; do
    echo "==== $h"
    cat "$h/name" 2>/dev/null
    grep -H . "$h"/*_input "$h"/*_label "$h"/*_alarm "$h"/*_fault 2>/dev/null
done
```

#### 10.8 PMBus 基本資料：page、phase、format、status

PMBus 裝置常見於 PSU、VR、HSC、power module。Porting 時需分清楚 command、page、phase、data format 與 status register。

| 項目 | 說明 | Bring-up 注意事項 |
|------|------|------------------|
| `PAGE` | 多 output rail / channel 的選擇 | PSU / VR 不同 rail 可能在不同 page；D-Bus sensor name 需對應 rail |
| `PHASE` | 多相 VR 的 phase 選擇 | 總電流與 phase 電流需分清楚，避免重複計算 |
| `LINEAR11` / `LINEAR16` | PMBus 常見數值格式 | 需確認 driver 是否正確解析 exponent / mantissa |
| `DIRECT` | 由 m/b/R 係數轉換 raw 值 | 需使用 vendor datasheet 係數 |
| `VOUT_MODE` | VOUT 讀值格式與 exponent | 不同 page 可能不同，需保存讀值 |
| `STATUS_WORD` | 總狀態 word | 只是入口，還要讀 `STATUS_VOUT` / `STATUS_IOUT` / `STATUS_INPUT` / `STATUS_TEMPERATURE` 等細項 |
| `CLEAR_FAULTS` | 清除 latched fault | 不可在未保存 fault snapshot 前清掉現場證據 |
| `MFR_* command` | 廠商自定義資訊 | 常用於 serial、model、revision、vendor fault extension |

PMBus bring-up 建議順序：

1. 確認 presence 與 power domain：PSU / VR 是否真的上電且允許 BMC sideband 讀取。
2. 確認 I2C address 與 mux path：同一 PSU slot 常可能相同 address 但不同 mux channel。
3. 用安全讀取命令確認通訊，例如 driver 已支援的 sysfs / hwmon 讀值，而非隨意掃描所有 command。
4. 確認 page 數、rail 名稱、VOUT mode、讀值 format、status command 支援度。
5. 建立 hwmon channel → OpenBMC sensor name → Redfish / IPMI 對照。
6. 做 fault injection 或模擬 AC lost / PSU pull-out，確認 availability、functional、event policy。

#### 10.9 PMBus driver 選型：generic、vendor-specific、custom

| driver 型態 | 適用情境 | 優點 | 風險 |
|-------------|----------|------|------|
| generic `pmbus` | 裝置符合標準 command，且只需基本 telemetry | 導入快、維護成本低 | page / format / status 支援可能不足 |
| kernel 既有 vendor driver | kernel 已支援該晶片或相容系列 | 較完整支援 device-specific 行為 | 需確認 kernel 版本與 `compatible` / id table |
| 新 vendor driver | 需要特殊 page、direct format、`MFR` command、fault mapping | 可把轉換與 quirk 放在 kernel 層 | 需提交與長期維護 driver |
| userspace direct I2C | 暫時 debug 或 vendor tool | 可快速驗證 register | 不宜長期與 kernel driver 同時存取同一 address |

判斷要不要寫新 driver：

- generic pmbus 無法正確解析 VOUT / current / power。
- 需要使用 vendor-specific MFR command 才能取得 fault 或 serial / model。
- 裝置對 unsupported command 反應不安全，generic auto-detect 造成 bus error 或 fault bit。
- 需要 page / phase / rail label 固定映射，避免 userspace 用錯 channel。
- 需要在 probe 時寫入 device-specific 初始化設定。

#### 10.10 Entity Manager 與 dbus-sensors 整合

OpenBMC 常用 Entity Manager 描述硬體 Entity 與其 Exposes 設定，再由 dbus-sensors 類 daemon 消費這些 D-Bus configuration，建立 sensor object。這樣可讓 sensor 設定依 FRU、presence、SKU、Probe result 動態調整。

簡化 JSON 範本：

```json
{
  "Name": "Example PSU0",
  "Probe": "TRUE",
  "Type": "Board",
  "Exposes": [
    {
      "Name": "psu0_input_voltage",
      "Type": "PSUSensor",
      "Bus": 20,
      "Address": "0x58",
      "Labels": ["v_in"],
      "PowerState": "Always",
      "Thresholds": [
        {
          "Direction": "less than",
          "Name": "lower critical",
          "Severity": 1,
          "Value": 10000
        }
      ]
    }
  ]
}
```

整合注意事項：

- `Bus` 若是 mux 後 logical bus，需確認每次 boot 是否穩定；若會變動，需用更穩定的 probe / template 方法。
- `Address` 要使用 7-bit address 字串或 schema 要求格式。
- `PowerState` 需與硬體 domain 對齊，避免 host off 或 PSU absent 時持續報錯。
- `Labels` / channel name 需和 hwmon label 或 psusensor 期待一致。
- Threshold 不要只從 reference board 複製，需依平台電源規格與 sensor 精度調整。
- Sensor `Available` 與 `Functional` 應反映裝置 presence、read failure、fault 狀態，而不是只顯示最後一次讀值。

#### 10.11 Redfish / IPMI / SEL 對映

I2C / PMBus sensor 最終常會暴露到 Redfish、IPMI SDR、WebUI 與 SEL / EventLog。對映錯誤時，硬體與 kernel 都可能正常，但使用者看到的欄位不對。

| 來源 | 中介資料 | 對外呈現 | 檢查重點 |
|------|----------|----------|----------|
| `hwmon` temp | D-Bus temperature sensor | Redfish Thermal / Sensor、IPMI temperature SDR | 單位、threshold、association |
| PMBus `VIN` / `VOUT` | D-Bus voltage sensor | Redfish Power / Sensor、IPMI voltage SDR | rail name、scale、warning / critical |
| PMBus `IIN` / `IOUT` | D-Bus current sensor | Redfish Power、IPMI current SDR | input vs output、page 對應 |
| PMBus `PIN` / `POUT` | D-Bus power sensor | Redfish PowerControl / PowerSupply | PSU input/output power 差異 |
| Fault bit | logging / operational status | SEL / EventLog / Redfish Health | latched fault clear policy |
| Presence | inventory present property | Redfish Position / Status | hot-plug debounce、availability gating |

排查指令：

```bash
# D-Bus sensors
busctl tree xyz.openbmc_project.HwmonTempSensor 2>/dev/null
busctl tree xyz.openbmc_project.PSUSensor 2>/dev/null
busctl tree xyz.openbmc_project.ObjectMapper | grep -i sensors

# Redfish sensor / thermal / power，依平台調整 URI
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>/Sensors
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>/Power
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>/Thermal

# IPMI sensor
ipmitool sensor list
ipmitool sdr elist
ipmitool sel list
```

#### 10.12 Fault、timeout、bus stuck 與 retry policy

I2C / PMBus 失敗不應一律當作 sensor critical threshold。需要區分裝置不存在、bus timeout、PMBus fault、讀值超界、host power off、PSU absent 與 driver bug。

| 狀態 | 建議語意 | D-Bus / event 建議 | 備註 |
|------|----------|--------------------|------|
| 裝置未插入 | `Present=false` | Sensor unavailable 或移除 association | 不應報 threshold critical |
| 裝置插入但讀不到 | `Available=false` 或 `Functional=false` | 可記錄通訊 fault | 需 retry 與 debounce |
| PMBus `STATUS` fault | `Functional=false` 或 event | 保存 `STATUS_*` snapshot | 清 fault 前先保存資訊 |
| 讀值超界 | Threshold asserted | Warning / Critical event | 需使用實際 sensor value |
| Host power off | PowerState gating | 依設計不讀或標 unavailable | 避免反覆報錯 |
| Bus stuck low | bus fault | 記錄 bus recovery / reset | 需看 SDA/SCL waveform |

Bus stuck 排查：

```bash
# kernel log
dmesg | grep -Ei 'i2c|smbus|pmbus|timeout|arbitration|stuck|recovery|nack'

# 查看 adapter 與 device
ls -l /sys/bus/i2c/devices
cat /sys/bus/i2c/devices/i2c-<bus>/name 2>/dev/null

# service log
journalctl -b --no-pager | grep -Ei 'i2c|pmbus|sensor|psu|timeout|unavailable|functional'
```

硬體方向：

- SDA / SCL 是否被某顆 device 拉低。
- Pull-up 電阻與電源域是否正確。
- Mux reset / enable 是否正確。
- Hot-plug 過程是否造成 transient short 或 bus capacitance 過高。
- Clock stretching 是否超出 controller / driver timeout。
- 多 master / Host sideband 是否同時存取同一 bus。

#### 10.13 PMBus fault snapshot 與 clear fault 流程

PMBus fault 常有 latched 行為。若立即 `CLEAR_FAULTS`，現場資訊可能消失。建議建立「先保存、再判讀、最後依政策清除」的流程。

建議保存項目：


| 資料 | 來源 | 用途 |
|------|------|------|
| `STATUS_WORD` | PMBus standard | 總 fault 入口 |
| `STATUS_VOUT` / `STATUS_IOUT` / `STATUS_INPUT` / `STATUS_TEMPERATURE` | PMBus standard | 判斷 fault 類型 |
| `READ_VIN` / `READ_VOUT` / `READ_IIN` / `READ_IOUT` / `READ_PIN` / `READ_POUT` | PMBus telemetry | 事件當下讀值 |
| `MFR_STATUS` / `MFR_FAULT_LOG` | vendor command | 廠商擴充 fault |
| PSU presence / AC good / power good | GPIO / CPLD / PMBus | 區分拔除、AC lost、內部 fault |

清除策略建議：

- 若 fault 影響安全或保固證據，預設不要自動清除，需維修流程決定。
- 若是已知 transient 且會造成後續讀值 blocked，可在保存 snapshot 後清除。
- 清除後需重新讀 status，確認 fault 是否仍存在。
- 若 clear fault 需要 PSU / VR 特定 sequence，需依 vendor datasheet 實施。

#### 10.14 Target 端 log 收集套件

```bash
mkdir -p /tmp/i2c-pmbus-debug
cat /etc/os-release > /tmp/i2c-pmbus-debug/os-release.txt
uname -a > /tmp/i2c-pmbus-debug/uname.txt
cat /proc/cmdline > /tmp/i2c-pmbus-debug/proc-cmdline.txt

dmesg -T > /tmp/i2c-pmbus-debug/dmesg.txt
journalctl -b --no-pager > /tmp/i2c-pmbus-debug/journal.txt
systemctl --failed > /tmp/i2c-pmbus-debug/systemctl-failed.txt 2>&1

# I2C topology
i2cdetect -l > /tmp/i2c-pmbus-debug/i2cdetect-l.txt 2>&1
ls -l /sys/bus/i2c/devices > /tmp/i2c-pmbus-debug/sys-bus-i2c-devices.txt 2>&1
find /sys/bus/i2c/devices -maxdepth 3 -type f -print > /tmp/i2c-pmbus-debug/i2c-files.txt 2>&1

# hwmon
find /sys/class/hwmon -maxdepth 3 -type f -print > /tmp/i2c-pmbus-debug/hwmon-files.txt 2>&1
for h in /sys/class/hwmon/hwmon*; do
    b=$(basename "$h")
    mkdir -p "/tmp/i2c-pmbus-debug/$b"
    cp -a "$h"/* "/tmp/i2c-pmbus-debug/$b/" 2>/dev/null || true
done

# GPIO / presence / mux line
command -v gpiodetect >/dev/null 2>&1 && gpiodetect > /tmp/i2c-pmbus-debug/gpiodetect.txt 2>&1
command -v gpioinfo >/dev/null 2>&1 && gpioinfo > /tmp/i2c-pmbus-debug/gpioinfo.txt 2>&1

# D-Bus / OpenBMC services
busctl tree xyz.openbmc_project.ObjectMapper > /tmp/i2c-pmbus-debug/dbus-objectmapper.txt 2>&1
busctl tree xyz.openbmc_project.EntityManager > /tmp/i2c-pmbus-debug/dbus-entity-manager.txt 2>&1
busctl tree xyz.openbmc_project.PSUSensor > /tmp/i2c-pmbus-debug/dbus-psusensor.txt 2>&1
busctl tree xyz.openbmc_project.HwmonTempSensor > /tmp/i2c-pmbus-debug/dbus-hwmontempsensor.txt 2>&1
journalctl -u xyz.openbmc_project.EntityManager.service -b --no-pager > /tmp/i2c-pmbus-debug/entity-manager-journal.txt 2>&1
journalctl -u xyz.openbmc_project.PSUSensor.service -b --no-pager > /tmp/i2c-pmbus-debug/psusensor-journal.txt 2>&1
journalctl -u xyz.openbmc_project.HwmonTempSensor.service -b --no-pager > /tmp/i2c-pmbus-debug/hwmontempsensor-journal.txt 2>&1

tar czf /tmp/i2c-pmbus-debug-$(date +%Y%m%d-%H%M%S).tar.gz -C /tmp i2c-pmbus-debug
```

#### 10.15 常見問題與排查入口

| 現象 | 可能方向 | 第一輪檢查 |
|------|----------|------------|
| `i2cdetect -l` 看不到 bus | controller disabled、pinctrl / clock / reset 未 ready、kernel config 缺 | DTS、`dmesg`、`clk_summary`、`devices_deferred` |
| bus 存在但 device 無 ACK | address / mux / power / reset / pull-up 問題 | schematic、scope、`i2cdetect`、mux sysfs |
| `UU` 顯示在 address 上 | driver 已綁定該 address | `/sys/bus/i2c/devices/*/driver`、`hwmon` |
| driver 未綁定 | DTS `compatible` / id table 不符、module 未載入 | `dmesg`、`modprobe`、kernel config |
| `hwmon` 有值但 D-Bus sensor 沒有 | Entity Manager config 不匹配、daemon 未啟動、label 不符 | `journal`、`busctl`、config JSON |
| D-Bus 有 sensor 但 Redfish 不顯示 | association / inventory / chassis path 不完整 | ObjectMapper、bmcweb journal、Redfish URI |
| PMBus voltage 數值比例錯 | linear/direct format、`VOUT_MODE`、scale factor 錯 | driver docs、raw register、datasheet |
| PSU 拔除後持續報 critical | presence gating 缺失，讀 failure 被當 threshold | presence GPIO、PowerState、sensor availability |
| bus 偶發 timeout | clock stretching、bus capacitance、hot-plug、multi-master 衝突 | `dmesg`、LA waveform、bus speed 降低測試 |
| fault 清掉後無法分析 | 未保存 `STATUS` / `MFR` fault snapshot | 調整 fault handling 流程 |
| 同一 PSU slot 名稱錯亂 | mux channel / logical bus number / Entity Manager template 錯 | i2c topology、Probe source、`busctl` config object |
| 更新後 sensor 順序改變 | hwmon index 動態變化、依 `hwmonX` 寫死 | 用 name / label / device path 匹配 |

#### 10.16 Bring-up 建議流程

- 收集 schematic：BMC I2C controller、mux、channel、address、pull-up、power domain、reset、INT、presence。
- 建立 I2C topology 表，不只寫 Linux bus number，也寫 physical path 與 mux path。
- 用 scope / LA 確認 SDA/SCL pull-up、bus frequency、ACK、clock stretching 與 hot-plug waveform。
- 在 DTS 啟用固定存在的 I2C controller / device / mux，完成 dtbs_check 與 running DTB 驗證。
- 先確認 `/sys/bus/i2c/devices`、`i2cdetect -l`、driver binding，再看 hwmon。
- 對 PMBus 裝置確認 driver 選型、page、phase、format、status、clear fault policy。
- 核對 hwmon channel 與實際 rail / PSU / fan 名稱，避免 label 或 page 對錯。
- 補 Entity Manager / dbus-sensors config，確認 D-Bus sensor object、threshold、availability、functional。
- 驗證 Redfish / IPMI / SEL 顯示與硬體狀態一致。
- 做異常測試：PSU pull-out、AC lost、VR fault、bus stuck、mux reset、sensor read timeout、BMC reboot、host power transition。
- 保存 i2c-pmbus-debug log、scope / LA waveform、PMBus fault snapshot 與版本資訊。

#### 10.17 當前平台 I2C / PMBus 實測表

| 項目 | 指令 / 來源 | 實測值 | 備註 |
|------|-------------|--------|------|
| I2C controller 清單 | `i2cdetect -l` / DTS | [待填] | physical bus 與 logical bus 對照 |
| I2C mux 清單 | DTS / `/sys/bus/i2c/devices` | [待填] | address、channel、idle policy |
| FRU EEPROM | `fru-device` / i2c sysfs | [待填] | address、page size、FRU parse |
| Temperature sensors | `/sys/class/hwmon` / D-Bus | [待填] | local / remote channel |
| PSU PMBus | `hwmon` / `psusensor` | [待填] | page、VIN/VOUT/IIN/IOUT/PIN/POUT |
| VR PMBus | `hwmon` / raw register | [待填] | page、phase、`VOUT_MODE` |
| GPIO expander | `gpioinfo` / DTS | [待填] | line name、INT、reset default |
| CPLD I2C register | platform tool | [待填] | version、fault latch、clear rule |
| hwmon channel mapping | `/sys/class/hwmon` | [待填] | sensor name 與 rail 對照 |
| D-Bus sensor tree | `busctl tree` | [待填] | Value / threshold / availability |
| Redfish mapping | `curl` Redfish URI | [待填] | Power / Thermal / Sensor |
| IPMI SDR mapping | `ipmitool sdr elist` | [待填] | sensor type / number |
| Fault handling | fault injection | [待填] | STATUS snapshot 與 clear flow |
| Bus recovery | timeout / stuck test | [待填] | recovery 成功條件 |

#### 10.18 回查結果

本章已回查前後文並補齊下列銜接點：

- 第 5 章已建立周邊匯流排通用知識，本章補上 I2C / SMBus / PMBus 深入拓樸、driver、hwmon、OpenBMC 連動與 fault handling。
- 第 8 章已說明 Device Tree，本章補上 I2C controller、mux、child device、PMBus 節點在實機 porting 中的檢查重點。
- 第 11 章 OpenBMC 常用 Project 與服務速查將說明 Entity Manager、dbus-sensors、ObjectMapper，本章先補 I2C / PMBus sensor 的資料流與排查指令。
- 第 12 章 Sensor 抽象層與後續 Voltage / Current / Power / PSU Sensor 章節會使用本章的 bus、driver、hwmon、D-Bus 對照方式。
- 第 16 章 Power Control 與 PSU / VR fault 需引用本章的 PMBus STATUS snapshot、clear fault policy 與 power domain gating。

#### 10.19 驗收 Checklist

-  I2C physical topology、mux path、logical bus、address、power domain、owner 已建立表格。
-  所有固定 I2C device 已在 DTS 或平台設定中描述，且不與動態 discovery 衝突。
-  I2C address 已確認為 7-bit address，未把 8-bit address 填入 DTS / config。
-  `i2cdetect -l`、`/sys/bus/i2c/devices` 與設計拓樸一致。
-  I2C mux channel 與 logical bus number 已記錄，重開機後行為已確認。
-  Bus speed、pull-up、waveform、clock stretching、hot-plug 行為已量測。
-  PMBus driver 選型已確認：generic、vendor-specific 或 custom driver。
-  PMBus page、phase、VOUT_MODE、linear/direct format、status command 已驗證。
-  hwmon channel 與實際 rail / PSU / fan / thermal 裝置對照正確。
-  Entity Manager / dbus-sensors config 已建立，D-Bus sensor object 正常出現。
-  Sensor `Available`、`Functional`、threshold 與 presence / power state gating 一致。
-  Redfish、IPMI SDR、SEL / EventLog 顯示與 D-Bus / hardware 狀態一致。
-  PMBus fault snapshot 會在 clear fault 前保存。
-  PSU pull-out、AC lost、VR fault、bus timeout、mux reset、BMC reboot 已完成測試。
-  i2c-pmbus-debug log、dmesg、journal、hwmon dump、busctl tree、waveform 已保存。

#### 10.20 本章參考資料

- Linux kernel documentation - How to instantiate I2C devices: [https://docs.kernel.org/i2c/instantiating-devices.html](https://docs.kernel.org/i2c/instantiating-devices.html)
- Linux kernel I2C sysfs documentation: [https://github.com/torvalds/linux/blob/master/Documentation/i2c/i2c-sysfs.rst](https://github.com/torvalds/linux/blob/master/Documentation/i2c/i2c-sysfs.rst)
- Linux kernel Hardware Monitoring documentation: [https://www.kernel.org/doc/html/latest/hwmon/index.html](https://www.kernel.org/doc/html/latest/hwmon/index.html)
- Linux kernel PMBus driver documentation: [https://docs.kernel.org/hwmon/pmbus.html](https://docs.kernel.org/hwmon/pmbus.html)
- Linux kernel PMBus core documentation: [https://mjmwired.net/kernel/Documentation/hwmon/pmbus-core.rst](https://mjmwired.net/kernel/Documentation/hwmon/pmbus-core.rst)
- OpenBMC dbus-sensors README: [https://github.com/openbmc/dbus-sensors/blob/master/README.md](https://github.com/openbmc/dbus-sensors/blob/master/README.md)
- OpenBMC entity-manager README: [https://github.com/openbmc/entity-manager/blob/master/README.md](https://github.com/openbmc/entity-manager/blob/master/README.md)


### 11. OpenBMC 常用 Project 與服務速查

#### 11.1 本章目的

OpenBMC 採用 D‑Bus centric 與 service‑oriented 架構，許多功能會拆成多個 daemon，並透過 D‑Bus object、interface、method、property 與 signal 串接。Sensor、Fan、Power、Inventory、Logging、Redfish、IPMI、MCTP / PLDM 等章節會反覆遇到同一批 OpenBMC project，因此本章先建立共通對照，後續章節只需引用本章，不需要重複說明每個 project 的職責。

本章重點不是取代各 project 的官方文件，而是讓 BMC porting / bring‑up / debug 時可以快速回答下列問題：

- 這個 project / daemon 主要負責哪一層？  
- 它通常讀取哪些設定或 kernel interface？  
- 它會在 D‑Bus 上提供哪些資料？  
- 發生問題時應先看哪個 log、哪個 service、哪個 recipe？  
- 在 Yocto / OpenBMC layer 中，常見修改點在哪裡？

#### 11.2 OpenBMC 常見資料流

多數 OpenBMC 功能可用下列資料流理解：

```
硬體 / Host / 外部裝置
    ↓
Kernel driver / sysfs / hwmon / I2C / GPIO / MCTP / PLDM
    ↓
OpenBMC userspace daemon
    ↓
D‑Bus object / interface / property / signal
    ↓
ObjectMapper / association / inventory / state / logging
    ↓
Redfish / IPMI / WebUI / event / policy
```

對 BMC porting 來說，建議一律先判斷問題落在哪一層：

- **Kernel 層**：DTS、driver、sysfs、hwmon、I2C transaction、GPIO line  
- **Userspace 層**：daemon 是否啟動、設定是否解析、D‑Bus object 是否建立  
- **整合層**：ObjectMapper、association、inventory、state、logging  
- **對外介面層**：Redfish、IPMI、WebUI、Event、SEL

#### 11.3 D‑Bus 與 ObjectMapper 相關 project

| Project / 元件 | 主要用途 | 常見修改 / 檢查點 | 常見排查入口 |
| --- | --- | --- | --- |
| `phosphor-dbus-interfaces` | OpenBMC 標準 D‑Bus interface 的 YAML 定義來源，常用來查 interface、property、method、enum 與 event registry。 | 通常不在平台 layer 直接修改；平台差異應優先放在 service、JSON config 或 OEM interface。 | `grep -R xyz.openbmc_project.Sensor phosphor-dbus-interfaces/yaml` |
| `sdbusplus` | C++ D‑Bus binding 與 async D‑Bus 開發常用 library。 | 修改 service source 時常會遇到產生出的 server / client binding。 | build error、interface mismatch、method signature mismatch |
| `phosphor-objmgr` / `xyz.openbmc_project.ObjectMapper` | 協助尋找 D‑Bus object owner、列出 subtree、建立 association 查詢。 | 通常不改 source；主要用於 runtime 查詢與 debug。 | `busctl call xyz.openbmc_project.ObjectMapper ... GetObject`、`GetSubTree` |
| `dbus-broker` / system bus | OpenBMC system D‑Bus message bus。 | 通常不改；需確認 service name、policy、activation 與 bus 連線狀態。 | `busctl list`、`busctl tree`、`journalctl -b` |

ObjectMapper 是排查 D‑Bus 問題的第一入口。當只知道 object path，不知道由哪個 service 提供時，可先查 owner：

```bash
busctl call xyz.openbmc_project.ObjectMapper \
  /xyz/openbmc_project/object_mapper \
  xyz.openbmc_project.ObjectMapper GetObject \
  sas \
  /xyz/openbmc_project/sensors/voltage/P12V \
  0
```

若要列出某一類 sensor：

```bash
busctl call xyz.openbmc_project.ObjectMapper \
  /xyz/openbmc_project/object_mapper \
  xyz.openbmc_project.ObjectMapper GetSubTree \
  sias \
  /xyz/openbmc_project/sensors \
  0 \
  1 \
  xyz.openbmc_project.Sensor.Value
```

#### 11.4 系統基礎服務與配置管理

| Project / 元件 | 主要用途 | 常見修改 / 檢查點 | 常見排查入口 |
| --- | --- | --- | --- |
| `phosphor-settings-manager` | 管理平台各項設定值（如 auto‑reboot、boot mode、NTP 設定等），每個設定為獨立 D‑Bus object。 | `/usr/share/phosphor-settings-manager/defaults.yaml`、platform layer 的 override YAML。 | `busctl tree xyz.openbmc_project.Settings`、`journalctl -u phosphor-settings-manager.service -b` |
| `phosphor-networkd` | 管理 BMC 網路介面（IP、DHCP、DNS、NTP 等），提供網路 D‑Bus object。 | 網路 interface 設定、DHCP enable/disable、DNS 設定。 | `busctl tree xyz.openbmc_project.Network`、`journalctl -u phosphor-networkd.service -b` |
| `phosphor-time-manager` | 管理 BMC 與 Host 系統時間，實作 `xyz.openbmc_project.Time.EpochTime` 介面。 | 時間來源（NTP / Manual）、time owner（BMC / Host）。 | `busctl introspect xyz.openbmc_project.Time.Manager /xyz/openbmc_project/time/bmc` |

**常用指令**：

```bash
# 查網路設定
busctl introspect xyz.openbmc_project.Network /xyz/openbmc_project/network/eth0
# 查時間
busctl get-property xyz.openbmc_project.Time.Manager /xyz/openbmc_project/time/bmc xyz.openbmc_project.Time.EpochTime Elapsed
# 查所有設定
busctl tree xyz.openbmc_project.Settings
```

#### 11.5 Sensor / Inventory / Entity Manager 相關 project

| Project / 元件 | 主要用途 | 常見修改 / 檢查點 | 常見排查入口 |
| --- | --- | --- | --- |
| `entity-manager` | 以 JSON 描述平台實體元件、FRU、sensor、connector、association 與 Probe 條件。 | `/usr/share/entity-manager/configurations/*.json`、platform layer 的 configuration recipe、schema。 | `journalctl -u xyz.openbmc_project.EntityManager.service -b`、`busctl tree xyz.openbmc_project.EntityManager` |
| `fru-device` | 掃描 I2C FRU EEPROM，建立 FRU / inventory 輔助資料。 | I2C bus blacklist、FRU EEPROM address、FRU 格式、Probe rule。 | `journalctl -u xyz.openbmc_project.FruDevice.service -b`、`busctl tree xyz.openbmc_project.FruDevice` |
| `dbus-sensors` | 一組 sensor daemons，從 hwmon、D‑Bus 或 direct driver access 讀值，並發佈 sensor D‑Bus object。 | Sensor JSON、service enable、daemon source、threshold、PowerState、ScaleFactor。 | `systemctl list-units '*sensor*'`、`busctl tree /xyz/openbmc_project/sensors` |
| `phosphor-hwmon` | 傳統 hwmon sensor 讀取方案，部分平台仍使用。 | hwmon config、label、scale、threshold、service instance。 | `/sys/class/hwmon/hwmonX/*`、`journalctl -u '*hwmon*' -b` |
| `phosphor-inventory-manager` | 管理 inventory object 與 FRU / chassis / board / assembly 類資料。 | inventory path、association、FRU property、Redfish inventory mapping。 | `busctl tree xyz.openbmc_project.Inventory.Manager`、`busctl tree /xyz/openbmc_project/inventory` |

Sensor 類問題排查流程：

```text
1. kernel 是否有 sysfs / hwmon / IIO / device node
2. Entity Manager JSON 是否被載入
3. sensor daemon 是否啟動且無解析錯誤
4. D‑Bus sensor object 是否存在
5. threshold / association / inventory 是否正確
6. Redfish / IPMI 是否有對應 mapping
```

常用指令：

```bash
systemctl list-units '*sensor*' --no-pager
systemctl list-units '*Entity*' --no-pager
journalctl -u xyz.openbmc_project.EntityManager.service -b --no-pager | tail -100
busctl tree /xyz/openbmc_project/sensors
busctl introspect <service> <object-path>
```

#### 11.6 Power / Fan / Thermal 相關 project

| Project / 元件 | 主要用途 | 常見修改 / 檢查點 | 常見排查入口 |
| --- | --- | --- | --- |
| `phosphor-fan-presence` | 風扇 presence 偵測。 | GPIO / tach / inventory presence、fan tray 對應。 | `journalctl -u '*fan*presence*' -b` |
| `phosphor-fan-control` / fan control service | 風扇 PWM、zone、target speed、thermal policy。 | zone config、PID / table、sensor input、PWM polarity。 | `busctl tree /xyz/openbmc_project/control/fanpwm`、fan service journal |
| `phosphor-pid-control` | PID 型 thermal / fan control，部分平台使用。 | PID config、sensor association、setpoint、failsafe。 | config file、service log、D‑Bus control object |
| Power control service | Host power on/off、chassis power、GPIO / CPLD / PMIC / sequencer 互動。 | power GPIO、CPLD register、state transition、systemd target。 | `busctl tree /xyz/openbmc_project/state`、`journalctl -b | grep -Ei 'power|chassis|host'` |
| `x86-power-control` 或平台 power daemon | x86 平台常見 power control 實作之一。 | PGOOD、power button、reset、NMI、host state。 | service journal、GPIO state、CPLD register |

Fan tach 與 fan control 建議分開看：Fan Tach Sensor 只確認轉速讀值是否正確，Fan Control 則確認 PWM、policy、zone 與 failsafe 是否符合規格。

#### 11.7 GPIO 監控

| Project / 元件 | 主要用途 | 常見修改 / 檢查點 | 常見排查入口 |
| --- | --- | --- | --- |
| `phosphor-gpio-monitor` | 監控 GPIO assertion 並觸發對應動作（如 checkstop、power‑good 處理）。 | GPIO 監控設定檔、systemd service instance。 | `journalctl -u phosphor-gpio-monitor*.service -b`、查看 GPIO 狀態 |

> **使用場景**：硬體訊號異常（checkstop、power fault）未被正確偵測或處理時。

#### 11.8 Redfish / Web / IPMI 相關 project（含 IPMI 擴充元件）

| Project / 元件 | 主要用途 | 常見修改 / 檢查點 | 常見排查入口 |
| --- | --- | --- | --- |
| `bmcweb` | OpenBMC web server，提供 Redfish、OpenBMC REST、WebSocket、KVM / console 等對外介面。 | Redfish route、schema mapping、privilege、web feature option、OEM extension。 | `journalctl -u bmcweb.service -b`、`curl -k https://<bmc>/redfish/v1/...` |
| `phosphor-webui` / WebUI package | Web UI 前端。新版平台可能改用其他前端實作。 | UI 顯示、API 路徑、build/package 是否進 image。 | browser devtools、bmcweb log、network trace |
| `phosphor-host-ipmid` | Host 端 IPMI command handling，常見於 KCS / BT / host interface。 | OEM command、sensor command、SEL / SDR hook、host interface。 | `journalctl -u phosphor-ipmi-host.service -b` |
| `phosphor-net-ipmid` | Network IPMI / RMCP+ 類服務，依平台 image 設定而定。 | network IPMI enable、user privilege、cipher suite、LAN channel。 | `systemctl status phosphor-ipmi-net@*.service`、`ipmitool -I lanplus ...` |
| IPMI SDR / SEL 相關元件 | 把 D‑Bus sensor、event、log 對應到 IPMI SDR / SEL。 | SDR 設計、sensor number、entity ID、threshold event、SEL policy。 | `ipmitool sensor`、`ipmitool sdr elist`、`ipmitool sel list` |
| `phosphor-ipmi-blobs` | 提供 OEM IPMI BLOB 傳輸協定框架，支援 generic blob 讀寫。 | blob handler 實作、OEM command 註冊。 | `journalctl -u phosphor-ipmi*.service -b` |
| `phosphor-ipmi-fru` / `ipmi-fru-parser` | IPMI FRU 格式支援，將 inventory 對應至 IPMI FRU。 | FRU mapping YAML、inventory 對應表。 | `ipmitool fru print`、`busctl tree xyz.openbmc_project.Inventory` |
| `phosphor-ipmi-ethstats` | 提供 BMC 乙太網路裝置統計資料的 OEM IPMI handler。 | 網路介面統計、OEM command。 | `ipmitool <oem command>` |

Redfish 顯示問題建議先分層：

```text
D‑Bus object 不存在：回到 daemon / Entity Manager / kernel
D‑Bus object 存在但 Redfish 沒有：查 bmcweb route、association、inventory path
Redfish 有資料但數值不對：比對 D‑Bus property 與 Redfish schema mapping
權限或登入問題：查 bmcweb、user manager、session / privilege 設定
```

#### 11.9 Logging / Event / State 相關 project

| Project / 元件 | 主要用途 | 常見修改 / 檢查點 | 常見排查入口 |
| --- | --- | --- | --- |
| `phosphor-logging` | OpenBMC event / error log 相關服務，負責產生與維護事件紀錄。 | event metadata、error YAML、event registry、SEL / Redfish event 對應。 | `journalctl -u phosphor-log-manager.service -b`、`busctl tree /xyz/openbmc_project/logging` |
| `phosphor-state-manager` | BMC、Chassis、Host state 管理，例如 power state、host transition、BMC state。 | power on/off state machine、host state、chassis state、systemd target 依賴。 | `busctl tree /xyz/openbmc_project/state`、`journalctl -u '*state*' -b` |
| `phosphor-user-manager` | 帳號、權限、群組、password policy。 | 使用者建立、role mapping、Redfish privilege。 | `busctl tree /xyz/openbmc_project/user`、bmcweb auth log |
| `phosphor-certificate-manager` | TLS / certificate lifecycle 管理。 | HTTPS certificate、CSR、憑證更換與持久化。 | bmcweb TLS error、certificate D‑Bus object |
| `phosphor-led-manager` | LED group 與 LED state 管理。 | fault LED、identify LED、enclosure LED group、GPIO / LED mapping。 | `busctl tree /xyz/openbmc_project/led`、`journalctl -u '*led*' -b` |

Threshold event、Power fault、PSU fault、Fan fault 這類問題通常會跨越 sensor daemon、logging、state、LED 與 Redfish。排查時建議保留同一時間點的 D‑Bus property、journal、Redfish response 與實體 LED 狀態。

#### 11.10 Host 日誌、POST Code 與 Debug Dump

| Project / 元件 | 主要用途 | 常見修改 / 檢查點 | 常見排查入口 |
| --- | --- | --- | --- |
| `phosphor-hostlogger` | 收集與儲存 Host console 輸出（boot log、kernel message），透過 `obmc-console` UNIX socket 讀取。 | console instance（ttyS0 / ttyVUART0）、log 儲存位置、logrotate。 | `journalctl -u phosphor-hostlogger@*.service -b`、`/var/log/hostlogger/` |
| `phosphor-host-postd` | 接收 POST code 並發出 D‑Bus signal。 | POST code 來源（LPC / eSPI）、D‑Bus path。 | `busctl monitor xyz.openbmc_project.State.Boot.Raw` |
| `phosphor-post-code-manager` | 將 POST code 持久化儲存並經由 Redfish 暴露。 | POST code 儲存路徑、Redfish mapping。 | `busctl tree /xyz/openbmc_project/state/boot/raw` |
| `phosphor-debug-collector` | 收集各種 log 與系統參數（如 `dreport` 腳本），用於問題排查。 | dump 類型（BMC dump / Host dump）、儲存路徑。 | `busctl tree xyz.openbmc_project.Dump`、`dreport` 指令 |

> **使用場景**：Host 開機失敗、POST code 卡住、需要收集 FFDC 資料時。

**常用指令**：

```bash
# 監看 POST code
busctl monitor xyz.openbmc_project.State.Boot.Raw
# 列出 dump
busctl tree xyz.openbmc_project.Dump
# 查看 host console log
journalctl -u phosphor-hostlogger@*.service -b -f
```

#### 11.11 軟體版本管理與韌體更新

| Project / 元件 | 主要用途 | 常見修改 / 檢查點 | 常見排查入口 |
| --- | --- | --- | --- |
| `phosphor-bmc-code-mgmt` | 管理 BMC 自身韌體版本、active / inactive 影像、更新與 rollback。 | 影像存放路徑、version ID、active 旗標、更新流程。 | `busctl tree xyz.openbmc_project.Software`、`journalctl -u phosphor-bmc-code-mgmt.service -b` |
| `phosphor-software-manager` | 提供系統軟體管理 daemon 集合，適用於各種 OpenBMC 平台。 | 軟體版本列舉、啟用/停用、更新策略。 | `busctl tree /xyz/openbmc_project/software` |

> **使用場景**：BMC 升級失敗、版本顯示錯誤、rollback 失效時優先檢查此區。

**常用指令**：

```bash
busctl tree xyz.openbmc_project.Software
busctl introspect xyz.openbmc_project.Software /xyz/openbmc_project/software/<version_id>
```

#### 11.12 MCTP / PLDM / Host Interface 相關 project

| Project / 元件 | 主要用途 | 常見修改 / 檢查點 | 常見排查入口 |
| --- | --- | --- | --- |
| `mctpd` | MCTP endpoint、routing、binding 與 bus owner 管理。 | I2C / SMBus / PCIe binding、EID、endpoint discovery。 | `busctl tree xyz.openbmc_project.MCTP`、`journalctl -u mctpd.service -b` |
| `pldmd` | PLDM stack，常用於 platform monitoring、FRU、firmware update、host / device telemetry。 | PLDM type、terminus、sensor PDR、FRU record、FW update flow。 | `journalctl -u pldmd.service -b`、PLDM D‑Bus object |
| `phosphor-ipmi-*` | IPMI host / net / OEM command。 | KCS / BT / SSIF、OEM command、SEL / SDR。 | `ipmitool`、host interface journal |
| KCS / BT / SSIF kernel driver | Host 與 BMC IPMI 通道。 | DTS、driver probe、IRQ、device node。 | `/dev/ipmi*`、dmesg、host side test |
| eSPI / LPC bridge 相關 driver | x86 host sideband interface。 | eSPI channel、LPC decode、host reset timing。 | dmesg、register dump、host log |

MCTP / PLDM 問題常同時牽涉 kernel binding、daemon discovery、endpoint 狀態與上層資料模型。建議先確認 endpoint 是否存在，再確認該 endpoint 是否有對應的 PLDM terminus / PDR / FRU record。

#### 11.13 常用 recipe / service / runtime 路徑對照

| 類型 | 常見位置 / 指令 | 用途 |
| --- | --- | --- |
| systemd unit | `/lib/systemd/system/`、`/usr/lib/systemd/system/` | 確認 daemon 啟動方式、相依 target、restart policy |
| Entity Manager JSON | `/usr/share/entity-manager/configurations/` | 平台 sensor、FRU、inventory、connector 設定 |
| D‑Bus service 清單 | `busctl list` | 查目前已註冊 service |
| D‑Bus object tree | `busctl tree <service>` 或 `busctl tree /xyz/openbmc_project` | 查 object path 是否存在 |
| D‑Bus interface | `busctl introspect <service> <path>` | 查 method、property、signal |
| journal | `journalctl -u <service> -b` | 查 daemon runtime log |
| kernel log | `dmesg`、`journalctl -k -b` | 查 driver probe、I2C error、hwmon、GPIO、MCTP binding |
| Yocto recipe 來源 | `bitbake-layers show-recipes <recipe>` | 確認 recipe 由哪個 layer 提供 |
| Yocto append | `bitbake-layers show-appends | grep <recipe>` | 確認平台 `.bbappend` 是否套用 |
| recipe 變數 | `bitbake -e <recipe>` | 查 `SRC_URI`、`PACKAGECONFIG`、`SYSTEMD_SERVICE`、`FILES` |

#### 11.14 依問題類型選擇排查入口

| 問題類型 | 優先檢查 project / layer | 建議第一步 |
| --- | --- | --- |
| Sensor 不出現 | `entity-manager`、`dbus-sensors`、`phosphor-hwmon` | 查 JSON 是否載入、daemon 是否啟動、hwmon/sysfs 是否存在 |
| Redfish 沒資料 | `bmcweb`、ObjectMapper、inventory association | 先確認 D‑Bus object 是否存在，再查 Redfish route / association |
| IPMI sensor 不對 | `phosphor-host-ipmid`、SDR mapping、sensor daemon | 比對 `ipmitool sdr`、D‑Bus sensor path、sensor number |
| Power on/off 失敗 | `phosphor-state-manager`、power daemon、GPIO / CPLD | 查 host/chassis state、power signal、CPLD fault latch |
| Fan 轉速不對 | `dbus-sensors` / tach daemon、fan control daemon、hwmon | 先確認 tach input，再確認 PWM / policy |
| FRU / Inventory 不對 | `fru-device`、`entity-manager`、`phosphor-inventory-manager` | 查 FRU EEPROM、Probe rule、inventory path |
| Event / SEL 沒產生 | `phosphor-logging`、sensor threshold、IPMI SEL bridge | 查 threshold alarm flag、logging D‑Bus object、journal |
| MCTP / PLDM device 不出現 | `mctpd`、`pldmd`、kernel binding | 先確認 endpoint / EID，再查 PLDM terminus / PDR |
| Web 登入或權限問題 | `bmcweb`、`phosphor-user-manager` | 查 session、user role、privilege mapping |
| 網路不通 | `phosphor-networkd`、kernel driver | 查 network D‑Bus object、IP 設定、DHCP、DNS |
| 時間不準 | `phosphor-time-manager`、`phosphor-settings-manager` | 查 NTP 設定、time owner、手動設定 |
| BMC 升級失敗 | `phosphor-bmc-code-mgmt`、`phosphor-software-manager` | 查 active/inactive 版本、更新 journal |
| Host console 看不到 | `phosphor-hostlogger`、`obmc-console` | 查 service 是否啟動、console 設定 |
| POST code 卡住 | `phosphor-host-postd`、`phosphor-post-code-manager` | 監看 D‑Bus signal、比對 POST code 表 |
| GPIO 事件未觸發 | `phosphor-gpio-monitor` | 查 GPIO state、service journal、設定檔 |
| IPMI OEM 功能異常 | `phosphor-ipmi-blobs`、`phosphor-ipmi-fru`、`phosphor-ipmi-ethstats` | 查對應 service journal、OEM command 測試 |

#### 11.16 本章參考資料

- OpenBMC dbus-sensors README：https://github.com/openbmc/dbus-sensors  
- OpenBMC entity-manager README：https://github.com/openbmc/entity-manager  
- OpenBMC phosphor-dbus-interfaces：https://github.com/openbmc/phosphor-dbus-interfaces  
- OpenBMC phosphor-objmgr：https://github.com/openbmc/phosphor-objmgr  
- OpenBMC ObjectMapper architecture：https://github.com/openbmc/docs/blob/master/architecture/object-mapper.md  
- OpenBMC bmcweb：https://github.com/openbmc/bmcweb  
- OpenBMC phosphor-settings-manager：https://github.com/openbmc/phosphor-settings-manager  
- OpenBMC phosphor-networkd：https://github.com/openbmc/phosphor-networkd  
- OpenBMC phosphor-time-manager：https://github.com/openbmc/phosphor-time-manager  
- OpenBMC phosphor-bmc-code-mgmt：https://github.com/openbmc/phosphor-bmc-code-mgmt  
- OpenBMC phosphor-software-manager：https://github.com/openbmc/phosphor-software-manager  
- OpenBMC phosphor-hostlogger：https://github.com/openbmc/phosphor-hostlogger  
- OpenBMC phosphor-host-postd：https://github.com/openbmc/phosphor-host-postd  
- OpenBMC phosphor-post-code-manager：https://github.com/openbmc/phosphor-post-code-manager  
- OpenBMC phosphor-debug-collector：https://github.com/openbmc/phosphor-debug-collector  
- OpenBMC phosphor-ipmi-blobs：https://github.com/openbmc/phosphor-ipmi-blobs  
- OpenBMC phosphor-gpio-monitor：https://github.com/openbmc/phosphor-gpio-monitor  
- OpenBMC 官方文件索引：https://github.com/openbmc/docs
### 12. Sensor 抽象層

Sensor 資料流：driver/hwmon → userspace sensor daemon → D-Bus object → Redfish/IPMI/SEL/Event。Sensor 狀態需區分：正常、不可用、讀值超界、device 不存在、bus error、timeout。

Sensor 欄位範本：

| Name   | Type             | Source    | Scale  | Unit    | Warning | Critical | D-Bus path | Redfish | IPMI SDR |
| ------ | ---------------- | --------- | ------ | ------- | ------: | -------: | ---------- | ------- | -------- |
| [待填] | temp/voltage/fan | hwmon/i2c | [待填] | C/V/RPM |  [待填] |   [待填] | [待填]     | [待填]  | [待填]   |


#### 12.1 Sensor 目的與共通架構
#### 12.2 Sensor 種類總覽
#### 12.3 ADC Sensor

本節整理 OpenBMC 中 ADC voltage sensor 的 porting 流程。ADC 適合用來量測板上類比電壓，常見包含 P12V、P5V、P3V3、P1V8、CPU Vcore、standby rail、thermistor voltage、hardware strap voltage、battery sense 等。

在 OpenBMC 的 `dbus-sensors` 架構中，ADC sensor 通常由 `adcsensor` daemon 讀取 Linux kernel 透過 IIO / hwmon 匯出的 sysfs 節點，再依 Entity Manager 提供的設定建立 D-Bus sensor 物件。AST2600 類平台需先在 device tree 啟用 ADC controller，再用 `iio-hwmon` 將 IIO channel 轉成 hwmon voltage input。

##### 12.3.1 基本資料流

```text
硬體待測電壓 Rail
    ↓
分壓電阻或濾波電路
    ↓
BMC SoC ADC pin / ADC channel
    ↓
Linux IIO ADC driver
    ↓
iio-hwmon bridge
    ↓
/sys/class/hwmon/hwmonX/inY_input
    ↓
OpenBMC adcsensor daemon
    ↓
Entity Manager configuration：Name / Type / Index / ScaleFactor / Thresholds
    ↓
D-Bus：/xyz/openbmc_project/sensors/voltage/<Name>
    ↓
Redfish / WebUI / IPMI SDR / logging / threshold event
```

關鍵觀念：
- Kernel 端負責讓 ADC channel 出現在 IIO，並由 `iio-hwmon` 轉為 `/sys/class/hwmon/hwmonX/inY_input`。
- Userspace 端的 `adcsensor` 會尋找 `name` 為 `iio_hwmon` 的 hwmon 裝置，並讀取 `in*_input`。
- Entity Manager 只描述「哪個 index 對應哪個 sensor 名稱、倍率、閾值與電源狀態」，不負責設定 ADC pinmux 或啟用 kernel driver。
- Redfish / IPMI 是否看得到 sensor，通常取決於 D-Bus path、sensor type、association 與上層 mapping 是否符合平台政策。

##### 12.3.2 Bring-up 前必填資料

| 欄位 | 說明 | 範例 / 注意事項 |
| --- | --- | --- |
| Rail name | 待測電壓名稱 | `P12V`、`P3V3_AUX`、`CPU_VCORE` |
| ADC controller | 使用哪個 ADC engine | `adc0` / `adc1` |
| ADC channel | SoC 端 channel number | `adc0 channel 0`、`adc1 channel 3` |
| Schematic net | ADC pin 前後 net 名稱 | 需可回查硬體圖 |
| Rtop / Rbottom | 分壓電阻 | 例如 `100 kΩ / 20 kΩ` |
| ADC pin 最大電壓 | 分壓後進 ADC 的最高電壓 | 不可超過 Vref / SoC 規格限制 |
| ADC reference | 內部或外部參考電壓 | AST2600 common binding 允許內部 `1.2 V` 或 `2.5 V`，也可用 `vref-supply` 描述外部參考 |
| ADC 解析度 | SoC / driver 實際解析度 | Upstream AST2600 binding 描述為 10-bit；若 vendor BSP 有差異，以該 kernel driver 與 datasheet 為準 |
| sysfs index | `/sys/class/hwmon/.../inY_input` 的 `Y` | 需實機確認，避免 DTS channel 順序與 sensor 設定不一致 |
| ScaleFactor | 分壓還原倍率 | `(Rtop + Rbottom) / Rbottom` |
| Thresholds | Warning / Critical 上下限 | 通常依 rail nominal ± tolerance 設定 |
| PowerState | sensor 啟用條件 | `Always` / `On` 等，依專案 schema 支援值確認 |
| Redfish / IPMI policy | 是否需要對外呈現 | 對應 Chassis / Inventory / SDR policy |

##### 12.3.3 ScaleFactor 與單位換算

若 `/sys/class/hwmon/hwmonX/inY_input` 回傳的是 ADC pin 上的電壓，hwmon voltage input 慣例單位為 millivolt。此時 Entity Manager 中的 `ScaleFactor` 應設定為外部分壓還原倍率：

```text
ScaleFactor = (Rtop + Rbottom) / Rbottom
RailVoltage(V) = (inY_input(mV) / 1000) × ScaleFactor
```

範例：

```text
待測 rail: P12V
Rtop = 100 kΩ
Rbottom = 20 kΩ
ScaleFactor = (100 + 20) / 20 = 6.0
in0_input = 2000 mV
P12V = 2000 / 1000 × 6.0 = 12.0 V
```

若看到 sysfs 讀值像 `0~1023` 或 `0~4095` 這類 raw code，而不是 mV，需要先確認目前節點是否真的是 hwmon voltage input，或是否讀錯到 IIO raw 節點。若專案 kernel / vendor BSP 的橋接行為與 upstream 不同，才需要把 Vref 與解析度納入換算：

```text
ADC_pin_mV = raw_code × Vref_mV / (2^N - 1)
RailVoltage(V) = (ADC_pin_mV / 1000) × ((Rtop + Rbottom) / Rbottom)
```

排查時建議同步讀取：

```bash
# hwmon voltage input，通常為 millivolt
cat /sys/class/hwmon/hwmonX/inY_input

# IIO raw / scale，依 driver expose 狀態可能不同
ls /sys/bus/iio/devices/iio:device*/in_voltage*_raw 2>/dev/null
ls /sys/bus/iio/devices/iio:device*/in_voltage*_scale 2>/dev/null
```

##### 12.3.4 Device Tree 設定

AST2600 upstream binding 中，ADC controller 常見必要屬性包含 `compatible`、`reg`、`clocks`、`resets` 與 `#io-channel-cells = <1>`。平台 dts 通常只需覆寫 `status`、參考電壓與必要 pinmux，再建立 `iio-hwmon` consumer。

```dts
/* SoC dtsi 通常已有 adc0 / adc1 節點，平台 dts 覆寫即可 */
&adc0 {
    status = "okay";
    aspeed,int-vref-microvolt = <2500000>;
};

&adc1 {
    status = "okay";
    aspeed,int-vref-microvolt = <2500000>;
};

/* 將指定 IIO channels 匯出為 hwmon voltage input */
iio-hwmon {
    compatible = "iio-hwmon";
    io-channels = <&adc0 0>, <&adc0 1>, <&adc0 2>, <&adc1 0>;
};
```

若平台使用外部 reference regulator，可改用 `vref-supply`，並在 regulator 節點描述實際電壓。若 BSP 支援額外 vendor property，例如 averaging、clock frequency、battery sensing 或 trim data，需以該 kernel tree 的 binding 文件與 `dtbs_check` 結果為準；不要只靠舊專案 DTS 複製。

建議驗證：

```bash
# build host：檢查 binding
bitbake -c devshell virtual/kernel
make dtbs_check DT_SCHEMA_FILES=Documentation/devicetree/bindings/iio/adc/aspeed,ast2600-adc.yaml
make dtbs_check DT_SCHEMA_FILES=Documentation/devicetree/bindings/hwmon/iio-hwmon.yaml

# target：確認 DTB 實際載入內容
dtc -I fs -O dts /sys/firmware/devicetree/base 2>/dev/null | less
```

##### 12.3.5 Kernel Config 與 image 納入檢查

ADC sensor 需要 ADC driver、IIO core 與 iio-hwmon。不同 kernel 版本名稱可能略有差異，常見方向如下：

```text
CONFIG_IIO=y
CONFIG_ASPEED_ADC=y 或對應 platform ADC driver
CONFIG_SENSORS_IIO_HWMON=y 或 m
CONFIG_HWMON=y
```

檢查方式：

```bash
# build output 中確認最後 .config
bitbake -e virtual/kernel | grep '^B='
 grep -E 'CONFIG_(IIO|ASPEED_ADC|SENSORS_IIO_HWMON|HWMON)' \
    tmp/work/*/linux-*/**/build/.config 2>/dev/null

# target 上確認 driver / module / sysfs
zcat /proc/config.gz | grep -E 'CONFIG_(IIO|ASPEED_ADC|SENSORS_IIO_HWMON|HWMON)' 2>/dev/null
ls /sys/bus/iio/devices/
ls /sys/class/hwmon/
```

##### 12.3.6 sysfs 節點確認

開機後先找出 `iio_hwmon`：

```bash
for h in /sys/class/hwmon/hwmon*; do
    [ -f "$h/name" ] || continue
    if grep -qx "iio_hwmon" "$h/name"; then
        echo "$h"
        ls "$h"/in*_input
    fi
done
```

讀取所有 voltage input：

```bash
HWMON=/sys/class/hwmon/hwmon2
for f in "$HWMON"/in*_input; do
    printf '%s = ' "$(basename "$f")"
    cat "$f"
done
```

以三用電表比對：

```text
1. 量測 ADC pin 端電壓，而不是 rail 原始電壓。
2. 比對 inY_input 是否接近 ADC pin mV。
3. 再用 ScaleFactor 換算回 rail voltage。
4. 若 pin 電壓吻合但 D-Bus rail voltage 不吻合，優先檢查 ScaleFactor / Index。
5. 若 pin 電壓與 sysfs 不吻合，優先檢查 Vref、driver、DTS、IIO scale、SoC ADC calibration。
```

一般 bring-up 可接受誤差需依電阻精度、ADC 精度、Vref 精度與 board noise 決定；若未另訂規格，可先用 `±1%~±3%` 作為初步判斷，再由 HW / validation 定義量產門檻。

##### 12.3.7 Entity Manager JSON 設定

Entity Manager configuration 通常為 board / chassis / device 物件，sensor 放在 `Exposes` 陣列中。以下以 baseboard 上的 P12V 為例：

```json
{
    "Name": "Baseboard",
    "Type": "Board",
    "Probe": "TRUE",
    "Exposes": [
        {
            "Name": "P12V",
            "Type": "ADC",
            "Index": 0,
            "ScaleFactor": 6.0,
            "PollRate": 0.5,
            "PowerState": "Always",
            "MinValue": 0.0,
            "MaxValue": 15.0,
            "Thresholds": [
                {
                    "Name": "upper critical",
                    "Direction": "greater than",
                    "Severity": 1,
                    "Value": 13.2
                },
                {
                    "Name": "lower critical",
                    "Direction": "less than",
                    "Severity": 1,
                    "Value": 10.8
                },
                {
                    "Name": "upper non critical",
                    "Direction": "greater than",
                    "Severity": 0,
                    "Value": 12.6
                },
                {
                    "Name": "lower non critical",
                    "Direction": "less than",
                    "Severity": 0,
                    "Value": 11.4
                }
            ]
        }
    ]
}
```

設定重點：
- `Type = "ADC"`：讓 `adcsensor` daemon 把此筆設定視為 ADC sensor。
- `Index`：需對應實機可讀到的 `inY_input`，請以 target sysfs 與 daemon log 交叉確認。
- `ScaleFactor`：通常只放分壓倍率；不要重複把 mV → V 或 Vref 轉換放進去，除非專案 driver 確認回傳 raw code。
- `PollRate`：OpenBMC upstream `adcsensor` 使用秒為單位且預設約 `0.5` 秒；部分 vendor fork 可能改成 `PollInterval` 或毫秒，需查 schema / source。
- `PowerState`：用於控制 sensor 在 standby / host on 時是否建立或更新。待機 rail 用 `Always` 類設定，host rail 可依平台政策設為只在 host on 時讀取。
- `Probe`：若 sensor 只存在於特定 SKU，需加入 FRU、board ID、CPLD register 或其他 inventory 條件，避免不存在的 sensor 長期呈現 unavailable。

建議在 source tree 內驗證 schema：

```bash
# 找 ADC schema 或 legacy schema 中的 ADC 定義
find meta-* openbmc -path '*entity-manager*schema*' -type f 2>/dev/null | sort
 grep -R '"ADC"' -n meta-* openbmc 2>/dev/null | head -50

# 找平台設定是否進 image
find tmp/work -path '*entity-manager*' -type f | grep -E '\.json$' | head
find tmp/deploy/images/${MACHINE}/ -type f | grep -E 'manifest|rootfs|tar'
```

##### 12.3.8 啟動服務與 D-Bus 驗證

```bash
# 重新讀取 Entity Manager 設定
systemctl restart xyz.openbmc_project.EntityManager.service

# 重啟 ADC sensor daemon
systemctl restart xyz.openbmc_project.ADCSensor.service

# 查看 log
journalctl -u xyz.openbmc_project.EntityManager.service -b --no-pager
journalctl -u xyz.openbmc_project.ADCSensor.service -b --no-pager

# 找 ADC sensor 物件
busctl tree xyz.openbmc_project.ADCSensor

# 讀值，Value 通常為 Volts / double
busctl get-property \
  xyz.openbmc_project.ADCSensor \
  /xyz/openbmc_project/sensors/voltage/P12V \
  xyz.openbmc_project.Sensor.Value \
  Value

# 確認 threshold interface
busctl introspect \
  xyz.openbmc_project.ADCSensor \
  /xyz/openbmc_project/sensors/voltage/P12V
```

預期在 D-Bus 上可看到：

```text
xyz.openbmc_project.Sensor.Value
xyz.openbmc_project.Sensor.Threshold.Warning
xyz.openbmc_project.Sensor.Threshold.Critical
xyz.openbmc_project.State.Decorator.Availability
xyz.openbmc_project.State.Decorator.OperationalStatus
```

##### 12.3.9 Redfish / IPMI 驗證

Redfish：

```bash
# 依平台 Chassis 名稱調整
$ curl -k -u root:0penBmc https://${BMC}/redfish/v1/Chassis/
$ curl -k -u root:0penBmc https://${BMC}/redfish/v1/Chassis/<chassis>/Sensors
$ curl -k -u root:0penBmc https://${BMC}/redfish/v1/Chassis/<chassis>/Sensors/P12V
```

IPMI：

```bash
$ ipmitool -I lanplus -H ${BMC} -U root -P 0penBmc sensor list | grep -i P12V
$ ipmitool -I lanplus -H ${BMC} -U root -P 0penBmc sdr elist | grep -i P12V
```

若 D-Bus 有 sensor 但 Redfish / IPMI 看不到，排查方向通常不是 ADC driver，而是：
- sensor path 或 type 不符合上層預期。
- inventory association 未建立。
- Redfish chassis mapping 未包含該 sensor。
- IPMI SDR policy 未產生該 sensor。
- service 啟動順序或 cache 未更新。

##### 12.3.10 閾值與事件驗證

Threshold 建議先用 nominal voltage 與 tolerance 計算。例如 12 V rail：

```text
Warning：±5%  → 11.4 V / 12.6 V
Critical：±10% → 10.8 V / 13.2 V
```

驗證內容：

```bash
# 讀取 threshold property
busctl introspect xyz.openbmc_project.ADCSensor \
  /xyz/openbmc_project/sensors/voltage/P12V | grep -E 'Threshold|Alarm|Value'

# 查看事件 log / journal
journalctl -b | grep -Ei 'P12V|threshold|critical|warning'
```

測試方式可依硬體條件選擇：
- 使用可程式電源供應器調整 rail，需先確認安全範圍。
- 使用 ADC input fixture 模擬分壓後電壓。
- 若 driver / validation framework 支援，可用測試 hook 注入讀值。

驗收點：
- 超過 warning threshold 時，Warning alarm property 變化。
- 超過 critical threshold 時，Critical alarm property 變化。
- 回到 hysteresis / deassert 條件後 alarm 清除。
- EventLog / SEL / journal 有對應紀錄。
- Redfish sensor 狀態與讀值同步更新。

##### 12.3.11 常見問題與排查

| 問題現象 | 可能方向 | 建議檢查 |
| --- | --- | --- |
| `/sys/class/hwmon` 找不到 `iio_hwmon` | `iio-hwmon` DTS node 未加入、kernel config 未啟用、driver probe fail | `dmesg | grep -Ei 'adc|iio|hwmon'`、確認 `CONFIG_SENSORS_IIO_HWMON` |
| `iio_hwmon` 存在但沒有 `in*_input` | `io-channels` 指到錯誤 provider / channel、ADC controller 未啟用 | 檢查 DTS phandle、`#io-channel-cells`、`status = "okay"` |
| `inY_input` 永遠為 0 | ADC pin 無電壓、pinmux / board route 錯、待測 rail 未上電 | 用電表量 ADC pin，確認 host power state |
| D-Bus sensor 沒出現 | Entity Manager JSON 未載入、`Probe` 不符合、`Type` / `Index` 錯誤 | `journalctl -u EntityManager`、`journalctl -u ADCSensor`、`busctl tree` |
| D-Bus value 差一個倍率 | `ScaleFactor` 未填或填錯、把 mV/V 轉換重複計入 | 用 `inY_input / 1000 × ScaleFactor` 手算比對 |
| 某些 rail 在待機顯示 unavailable | `PowerState` 設成 host-on-only、rail 本身未上電 | 確認 power policy 與待機 rail 定義 |
| 讀值跳動大 | ADC input noise、分壓阻值過高、濾波不足、取樣率太快 | 用示波器看 ADC pin；評估 RC filter、driver averaging、PollRate |
| Redfish N/A | D-Bus 有 sensor 但 association / chassis mapping 不完整 | 查 bmcweb log、Redfish sensors endpoint、inventory association |
| threshold 不觸發 | threshold 名稱 /方向 /Severity 錯、讀值未真正跨越門檻 | busctl introspect threshold properties，人工調整輸入驗證 |
| 更新 DTB 後行為沒變 | 燒錄到錯誤 image slot、U-Boot 載入舊 DTB | 檢查 `/proc/device-tree`、U-Boot env、`tmp/deploy/images` |

##### 12.3.12 Porting 驗收 Checklist

硬體與 schematic：
- [ ] ADC channel number 與 SoC pin 對照完成。
- [ ] Rail name、net name、Rtop、Rbottom、ADC pin net 已記錄。
- [ ] ADC pin 最大電壓低於 SoC / Vref 允許範圍。
- [ ] ScaleFactor 已依 schematic 計算並由 HW review。
- [ ] 使用三用電表量測 ADC pin 與 rail，確認分壓比例合理。

Device Tree / Kernel：
- [ ] `adc0` / `adc1` 或對應 ADC controller `status = "okay"`。
- [ ] `aspeed,int-vref-microvolt` 或 `vref-supply` 與硬體一致。
- [ ] `iio-hwmon` node 已列出需要的 `io-channels`。
- [ ] kernel config 包含 IIO、ADC driver、hwmon、iio-hwmon。
- [ ] target 上可看到 `/sys/class/hwmon/hwmonX/name = iio_hwmon`。
- [ ] target 上可讀到 `/sys/class/hwmon/hwmonX/inY_input`。

Entity Manager / Userspace：
- [ ] JSON 放在正確 layer / recipe，且進入 rootfs。
- [ ] `Exposes` 裡有 `Type = "ADC"`、`Name`、`Index`、`ScaleFactor`。
- [ ] `PollRate` / `PowerState` 符合平台需求。
- [ ] SKU 差異已用 `Probe` 或平台設定區分。
- [ ] warning / critical thresholds 已依 rail tolerance 設定。

D-Bus / Redfish / IPMI：
- [ ] `xyz.openbmc_project.ADCSensor.service` 啟動無錯誤。
- [ ] D-Bus path 出現 `/xyz/openbmc_project/sensors/voltage/<Name>`。
- [ ] `Value` 單位為 Volts，且與電表換算結果一致。
- [ ] Warning / Critical threshold interfaces 存在。
- [ ] Redfish sensor endpoint 可看到該 sensor。
- [ ] 若平台需要 IPMI，SDR 與 `ipmitool sensor list` 可看到該 sensor。
- [ ] threshold assert / deassert、EventLog / SEL / journal 已驗證。

##### 12.3.13 ADC Sensor 資料表範本

| Rail | ADC controller / channel | sysfs | Rtop | Rbottom | ScaleFactor | Nominal | Warning low/high | Critical low/high | PowerState | D-Bus path |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| P12V | adc0 ch0 | in0_input | 100 kΩ | 20 kΩ | 6.0 | 12.0 V | 11.4 / 12.6 V | 10.8 / 13.2 V | Always | `/xyz/openbmc_project/sensors/voltage/P12V` |
| P3V3_AUX | adc0 ch1 | in1_input | [待填] | [待填] | [待填] | 3.3 V | [待填] | [待填] | Always | [待填] |
| CPU_VCORE | adc1 ch0 | in3_input | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | On | [待填] |

##### 12.3.14 本節參考資料

- OpenBMC `dbus-sensors` README：說明 sensor daemon 由 Entity Manager 動態設定，ADC sensor 使用 Linux IIO，AST2600 平台需在 device tree 啟用 `adc0` / `adc1` 並用 `iio-hwmon` 匯出。
- OpenBMC `ADCSensorMain.cpp`：`adcsensor` 尋找 `name` 為 `iio_hwmon` 的 hwmon 裝置，讀取 `in*_input`，預設 poll rate 約 `0.5` 秒。
- Linux kernel `iio-hwmon.yaml`：`iio-hwmon` binding 的必要屬性為 `compatible = "iio-hwmon"` 與 `io-channels`。
- Linux kernel `aspeed,ast2600-adc.yaml`：AST2600 ADC binding 描述兩個 ADC engine、各 8 個 voltage channels、`#io-channel-cells = <1>`、內部 reference `1200000` / `2500000` microvolt，以及可用 `vref-supply` 對應外部 reference。


#### 12.4 Temperature Sensor

##### 12.4.1 適用情境

Temperature Sensor 常見於監控系統中各關鍵部位的熱分佈。BMC 端通常不只關心單點溫度，也會將多個溫度來源交給 Redfish、IPMI SDR、事件紀錄與 fan control policy 使用。

常見監控點如下：

```text
Ambient temperature：進風口 / 出風口
Board temperature：PCB 中央或局部 hotspot
CPU temperature：核心 / 外殼 / PECI 回報值
DIMM temperature：記憶體模組
PSU temperature：電源供應器內部
NVMe temperature：固態硬碟 controller / composite temperature
GPU temperature：圖形處理器 / HBM / board sensor
VR temperature：電壓調節模組
BMC temperature：BMC SoC 自身或鄰近 board sensor
```

在 OpenBMC 中，溫度感測器通常會被發布成 D-Bus 物件，常見路徑如下：

```text
/xyz/openbmc_project/sensors/temperature/<sensor_name>
```

典型 D-Bus 介面包含：

```text
xyz.openbmc_project.Sensor.Value
xyz.openbmc_project.Sensor.Threshold.Warning
xyz.openbmc_project.Sensor.Threshold.Critical
xyz.openbmc_project.State.Decorator.Availability
xyz.openbmc_project.State.Decorator.OperationalStatus
xyz.openbmc_project.Association.Definitions
```

這些物件後續可被 Redfish、IPMI、Phosphor PID Control、logging service 或其他平台 daemon 消費。

##### 12.4.2 資料路徑（Data Flow）

本節以最常見的 I2C 溫度感測晶片（例如 TMP75 / LM75 類）為例說明資料流：

```text
I2C Temperature Chip (TMP75 at Bus 3, Addr 0x48)
    ↓
Linux I2C Driver (i2c-core) + Chip-specific hwmon Driver (lm75.c / tmp75 compatible)
    ↓
hwmon sysfs 介面 (/sys/class/hwmon/hwmonX/temp1_input)
    ↓
HwmonTempSensor daemon 定期讀取 sysfs
    ↓
Entity Manager 提供 JSON 設定 (Name, Type, Bus, Address, Thresholds)
    ↓
D-Bus 發佈至 /xyz/openbmc_project/sensors/temperature/<Name>
    ↓
Redfish Thermal / Sensors、IPMI SDR、Fan PID policy 查詢或消費
```

其他溫度來源的前段資料路徑可能不同，例如 PECI CPU 溫度、PMBus PSU 溫度、NVMe over MCTP、GPU vendor tool 或 ADC Thermistor。但在 OpenBMC 上，常見整合方向仍是收束到標準 D-Bus sensor 介面，讓上層服務用一致模型讀取。

##### 12.4.3 常見來源分類

<table>
<tr>
<th>來源類型</th>
<th>驅動 / 協定</th>
<th>OpenBMC 對應 Daemon</th>
<th>備註</th>
</tr>
<tr>
<td>I2C 獨立晶片，例如 TMP75 / LM75 / MAX31725</td>
<td>Linux hwmon driver</td>
<td>HwmonTempSensor</td>
<td>最常見；需 DTS 或 board info 建立 I2C device</td>
</tr>
<tr>
<td>CPU 內部溫度</td>
<td>PECI driver / peci-temp</td>
<td>IntelCPUSensor 或平台特定 daemon</td>
<td>主要見於 x86 平台；需 host CPU / PCH / PECI 通道可用</td>
</tr>
<tr>
<td>PMBus 電源裝置</td>
<td>pmbus driver</td>
<td>PSUSensor 或 HwmonTempSensor</td>
<td>讀取 PSU 回報的內部 temperature rail</td>
</tr>
<tr>
<td>NVMe 固態硬碟</td>
<td>NVMe-MI / MCTP / vendor command</td>
<td>NVMeSensor 或平台自有服務</td>
<td>視平台拓撲決定是否透過 MCTP over I2C / PCIe sideband</td>
</tr>
<tr>
<td>GPU</td>
<td>vendor-specific ioctl / SMBus / MCTP</td>
<td>GPUUtilSensor / ExternalSensor / vendor daemon</td>
<td>通常需額外 userspace 工具或 vendor library</td>
</tr>
<tr>
<td>外部類比 Thermistor</td>
<td>ADC 讀取後換算</td>
<td>ADCSensor 搭配 ScaleFactor / Offset / polynomial</td>
<td>請參閱 11.1 ADC Sensor</td>
</tr>
<tr>
<td>BMC SoC 內部溫度</td>
<td>SoC thermal / hwmon driver</td>
<td>HwmonTempSensor 或 SoC-specific daemon</td>
<td>需確認 kernel driver 是否輸出 temp*_input</td>
</tr>
</table>

##### 12.4.4 Porting 前需確認的硬體資訊與校準參數

從 schematic、board placement、datasheet 與 thermal policy 取得下列資訊：

```text
- Sensor chip 完整型號，例如 TMP75B、LM75A、MAX31725、PCT2075
- 所在 I2C bus number，例如 I2C3
- 若經過 I2C mux，需確認 mux device、channel 與 enable 條件
- 7-bit I2C device address，例如 0x48、0x4A
- 供電 rail 與 power state，例如 BMC standby rail 或 host main rail
- ALERT / interrupt pin 是否接到 BMC GPIO
- 解析度、轉換時間、sample time 或 conversion rate
- 感測點物理位置，例如 front inlet、rear outlet、VR hotspot、PCIe zone
- 有無硬體 offset 或需線性補償，例如貼合、風道位置、膠材造成固定偏差
- Warning / Critical threshold，由 thermal policy 決定
- Redfish / IPMI 顯示名稱與 inventory association
```

範例參數：

```text
Sensor Name: Ambient_Temp
Chip: TMP75B
I2C Bus: 3
Address: 0x48
Resolution: 12-bit (0.0625°C per LSB)
Expected Offset: +0.5°C
Critical High: 85°C
Warning High: 75°C
Warning Low: 0°C
Power Rail: BMC_STBY_3V3
Physical Location: Front inlet, near fan wall
```

建議在 bring-up 記錄中保留硬體量測條件，例如室溫、風扇狀態、系統功耗與開蓋 / 關蓋狀態，避免後續校準時無法對齊測試條件。

##### 12.4.5 I2C Bus 偵測與地址確認

開機後使用 `i2cdetect` 掃描指定 bus：

```bash
i2cdetect -y 3
```

預期輸出範例，0x48 出現 `48`：

```text
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
00:          -- -- -- -- -- -- -- -- -- -- -- -- -- 
10: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
20: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
30: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
40: -- -- -- -- -- -- -- -- 48 -- -- -- -- -- -- -- 
```

若經過 I2C mux，先確認 mux channel 是否切到正確路徑：

```bash
# 範例：列出 I2C adapter 與 mux channel
ls -l /sys/bus/i2c/devices/

i2cdetect -l
```

若掃不到地址，可改用 read-only 方式讀取溫度暫存器或製造商 ID 暫存器。實際 register 需依 datasheet 確認：

```bash
# TMP75 / LM75 類常見 temperature register 在 0x00；實際格式需看 datasheet
i2cget -y 3 0x48 0x00 w
```

注意事項：

- `i2cdetect` 只是輔助確認工具，不建議在不熟悉裝置行為時對整條 bus 反覆掃描。
- 部分裝置對 SMBus quick command 或特定讀寫型態敏感，可能造成狀態變化。
- 若 bus 上有 mux、CPLD bridge、hot-swap buffer 或電源 domain gating，需先確認相關 enable 條件。

##### 12.4.6 Device Tree 加入 sensor node

LM75 / TMP75 類溫度晶片通常在 I2C bus node 下建立 child node。核心必要屬性是 `compatible` 與 `reg`；若平台有 regulator 或 interrupt，也應一併描述。

```dts
&i2c3 {
    status = "okay";
    clock-frequency = <100000>;

    temperature-sensor@48 {
        compatible = "ti,tmp75b";
        reg = <0x48>;
        label = "ambient_front";
        vs-supply = <&p3v3_stby>;
        #thermal-sensor-cells = <0>;   /* 若需與 Linux thermal zone 連結 */
    };
};
```

相容性注意事項：

- Linux `lm75` family binding 支援多個 compatible，例如 `national,lm75`、`st,stlm75`、`maxim,max31725`、`ti,tmp75`、`ti,tmp75b`、`ti,tmp75c` 等。
- 若特定 compatible 在目前 kernel branch 尚未支援，可先查看 `Documentation/devicetree/bindings/hwmon/lm75.yaml` 與 `drivers/hwmon/lm75.c`。
- 不建議任意使用相近 compatible；必須確認解析度、暫存器格式、sample time、threshold register 與 interrupt 行為相容。

若溫度晶片掛在 I2C mux 後方，DTS 結構會多一層 mux channel。實際 bus number 可能由 kernel 動態分配，因此 Entity Manager 中的 bus number 需以目標機實際 `i2cdetect -l` 與 `/sys/bus/i2c/devices/` 結果確認。

##### 12.4.7 Kernel config 與 driver 確認

Kernel 需啟用 I2C、hwmon 與對應感測器 driver。LM75 / TMP75 類通常對應 `CONFIG_SENSORS_LM75`。

```bash
# 在 build tree 檢查最終 kernel config
bitbake -e virtual/kernel | grep '^B='

grep -E 'CONFIG_HWMON|CONFIG_I2C|CONFIG_SENSORS_LM75' \
  tmp/work/*/linux-*/ */build/.config 2>/dev/null
```

實機上可檢查 driver 是否 probe 成功：

```bash
dmesg | grep -Ei 'lm75|tmp75|hwmon|i2c'

# 若 driver 是 module
lsmod | grep -E 'lm75|hwmon'

# 查看 I2C device 與 driver bind 狀態
find /sys/bus/i2c/devices -maxdepth 2 -type l -name driver -print -exec readlink -f {} \;
```

若 driver 未 probe，可從下列方向同步資訊：

- DTS 是否進到實際 boot 的 DTB。
- `compatible` 是否被目前 kernel driver 支援。
- bus / mux path 是否正確。
- power rail 是否已開。
- I2C address 是否與硬體 strap 一致。

##### 12.4.8 確認 hwmon sysfs 節點與數值單位

開機後尋找對應 hwmon：

```bash
# 找出所有 hwmon 並顯示 name
for i in /sys/class/hwmon/hwmon*; do
    echo "$i: $(cat $i/name 2>/dev/null)"
done

# 假設找到 hwmon4，檢查溫度節點
ls /sys/class/hwmon/hwmon4/temp*_input

# 讀取溫度，Linux hwmon temperature 通常以 millidegree Celsius 呈現
cat /sys/class/hwmon/hwmon4/temp1_input
```

單位判讀：

```text
temp1_input: 30000 → 30.000°C
temp1_crit: 85000 → 85.000°C
temp1_max: 75000 → 75.000°C
```

常見 sysfs 欄位：

<table>
<tr>
<th>欄位</th>
<th>常見意義</th>
<th>單位</th>
</tr>
<tr>
<td>temp1_input</td>
<td>目前溫度讀值</td>
<td>millidegree Celsius</td>
</tr>
<tr>
<td>temp1_max</td>
<td>上限 threshold，若 driver 支援</td>
<td>millidegree Celsius</td>
</tr>
<tr>
<td>temp1_crit</td>
<td>critical threshold，若 driver 支援</td>
<td>millidegree Celsius</td>
</tr>
<tr>
<td>temp1_alarm</td>
<td>硬體 alarm 狀態，若 driver 支援</td>
<td>0 / 1</td>
</tr>
<tr>
<td>name</td>
<td>hwmon 裝置名稱</td>
<td>字串</td>
</tr>
</table>

注意：Linux hwmon 文件中提到，driver 只是呈現硬體值與 alarm 狀態；不同 board 的標籤與補償通常仍需由 userspace 或設定檔處理。

##### 12.4.9 Entity Manager 配置

Entity Manager 的設定通常位於下列路徑之一，實際位置需依平台 layer 與 recipe 設計確認：

```text
/usr/share/entity-manager/configurations/
meta-<platform>/recipes-phosphor/configuration/<project>/
meta-<platform>/recipes-phosphor/configuration/entity-manager/
```

OpenBMC `dbus-sensors` 通常透過 Entity Manager 取得 sensor device 設定；sensor 物件以 configuration 中的 `Exposes` records 描述，且 `Name` 與 `Type` 是基本必要欄位。

常見 JSON 結構如下。不同 OpenBMC branch 的 schema 可能略有差異，請以目前 image 內 `/usr/share/entity-manager/schemas/` 與 `sensor-info.json` 為準。

```json
{
    "Name": "Baseboard Sensors",
    "Probe": "xyz.openbmc_project.FruDevice({'BOARD_PRODUCT_NAME': 'MyPlatform'})",
    "Type": "Board",
    "Exposes": [
        {
            "Name": "Ambient_Temp",
            "Type": "TMP75",
            "Bus": 3,
            "Address": "0x48",
            "PollRate": 0.5,
            "ScaleFactor": 1.0,
            "Offset": 0.5,
            "MaxValue": 100.0,
            "MinValue": -10.0,
            "PowerState": "AlwaysOn",
            "Thresholds": [
                {
                    "Name": "upper critical",
                    "Direction": "greater than",
                    "Severity": 1,
                    "Value": 85.0
                },
                {
                    "Name": "upper non critical",
                    "Direction": "greater than",
                    "Severity": 0,
                    "Value": 75.0
                },
                {
                    "Name": "lower non critical",
                    "Direction": "less than",
                    "Severity": 0,
                    "Value": 0.0
                }
            ]
        }
    ]
}
```

重點欄位說明：

<table>
<tr>
<th>欄位</th>
<th>說明</th>
<th>檢查方式</th>
</tr>
<tr>
<td>Name</td>
<td>D-Bus sensor 名稱的一部分；通常會出現在 /xyz/openbmc_project/sensors/temperature/&lt;Name&gt;</td>
<td>busctl tree / Redfish sensor list</td>
</tr>
<tr>
<td>Type</td>
<td>需符合 dbus-sensors 與 Entity Manager schema 支援的 sensor type</td>
<td>查 sensor-info.json、schema、daemon log</td>
</tr>
<tr>
<td>Bus / Address</td>
<td>對應 I2C bus 與 7-bit address</td>
<td>i2cdetect -l、/sys/bus/i2c/devices</td>
</tr>
<tr>
<td>PollRate / PollInterval</td>
<td>輪詢頻率或間隔；名稱依 branch 而可能不同</td>
<td>查 schema 與 daemon source</td>
</tr>
<tr>
<td>ScaleFactor / Offset</td>
<td>線性倍率與固定補償；適合處理安裝位置或類比路徑的固定偏差</td>
<td>與標準溫度計比對</td>
</tr>
<tr>
<td>PowerState</td>
<td>AlwaysOn 或 On；用來控制 host power state 下是否讀取</td>
<td>待機 / 上電狀態測試</td>
</tr>
<tr>
<td>Thresholds</td>
<td>Warning / Critical high / low threshold</td>
<td>D-Bus introspect 與 threshold 觸發測試</td>
</tr>
</table>

若平台使用舊版設定格式，可能不使用 `Exposes` wrapper，或欄位名稱不同。移植時請以 target image 內實際 schema 為準，不要只複製其他平台 JSON。

##### 12.4.10 啟動服務與 D-Bus 驗證

重啟 Entity Manager 與 HwmonTempSensor：

```bash
systemctl restart xyz.openbmc_project.EntityManager.service
systemctl restart xyz.openbmc_project.HwmonTempSensor.service
```

監看日誌：

```bash
journalctl -u xyz.openbmc_project.EntityManager.service -b --no-pager | tail -100
journalctl -u xyz.openbmc_project.HwmonTempSensor.service -b --no-pager | tail -100

# 或持續追蹤
journalctl -u xyz.openbmc_project.HwmonTempSensor.service -f
```

確認 D-Bus 物件樹：

```bash
busctl tree xyz.openbmc_project.HwmonTempSensor
```

讀取溫度輸出。D-Bus `Value` 的單位通常為 °C，型態為 double：

```bash
busctl get-property \
  xyz.openbmc_project.HwmonTempSensor \
  /xyz/openbmc_project/sensors/temperature/Ambient_Temp \
  xyz.openbmc_project.Sensor.Value \
  Value
```

確認 threshold 介面是否存在：

```bash
busctl introspect xyz.openbmc_project.HwmonTempSensor \
  /xyz/openbmc_project/sensors/temperature/Ambient_Temp
```

預期可看到下列介面與屬性：

```text
xyz.openbmc_project.Sensor.Value
  Value
  Unit

xyz.openbmc_project.Sensor.Threshold.Warning
  WarningHigh
  WarningLow
  WarningAlarmHigh
  WarningAlarmLow

xyz.openbmc_project.Sensor.Threshold.Critical
  CriticalHigh
  CriticalLow
  CriticalAlarmHigh
  CriticalAlarmLow
```

若 D-Bus sensor 未出現，先同步三個層級的資訊：

```bash
# 1. kernel / hwmon 是否有輸出
find /sys/class/hwmon -name 'temp*_input' -print

# 2. Entity Manager 是否載入設定
busctl tree xyz.openbmc_project.EntityManager
journalctl -u xyz.openbmc_project.EntityManager.service -b --no-pager | grep -i Ambient

# 3. HwmonTempSensor 是否建立物件
journalctl -u xyz.openbmc_project.HwmonTempSensor.service -b --no-pager | grep -Ei 'Ambient|TMP75|0x48|error|fail'
```

##### 12.4.11 Redfish / IPMI 整合驗證

Redfish 常見查詢入口會依 OpenBMC 版本與平台設定而不同。常見路徑包含：

```text
/redfish/v1/Chassis/<ChassisId>/Thermal
/redfish/v1/Chassis/<ChassisId>/Sensors
/redfish/v1/TelemetryService/MetricReports
```

查詢範例：

```bash
curl -k -u root:<password> \
  https://<bmc-ip>/redfish/v1/Chassis/chassis/Sensors

curl -k -u root:<password> \
  https://<bmc-ip>/redfish/v1/Chassis/chassis/Thermal
```

需確認項目：

- Redfish sensor 名稱是否符合平台命名規格。
- Reading / ReadingUnits 是否合理，溫度單位通常為 Celsius。
- Thresholds 是否對應 Entity Manager 設定。
- Status.State / Status.Health 是否會隨 availability / threshold 狀態變化。
- 若需 IPMI SDR，確認 SDR 中 sensor type、entity id、sensor number 與 threshold mapping 是否符合需求。

##### 12.4.12 校準與 Thermal Policy 對齊

溫度 sensor bring-up 不應只停在 `cat temp1_input` 有值，還需與 thermal policy 對齊。建議建立下列測試資料：

<table>
<tr>
<th>測試條件</th>
<th>觀察項目</th>
<th>驗收方向</th>
</tr>
<tr>
<td>室溫 idle</td>
<td>sensor 讀值、標準溫度計、風扇轉速</td>
<td>ambient sensor 通常應與環境溫度接近</td>
</tr>
<tr>
<td>host full load</td>
<td>CPU / DIMM / VR / outlet 溫度曲線</td>
<td>曲線需符合 airflow 與功耗預期</td>
</tr>
<tr>
<td>fan speed step</td>
<td>溫度下降時間常數</td>
<td>fan policy 應可讓溫度回到目標區間</td>
</tr>
<tr>
<td>局部加熱</td>
<td>D-Bus Value、WarningAlarmHigh、CriticalAlarmHigh</td>
<td>threshold 旗標與事件紀錄需同步更新</td>
</tr>
<tr>
<td>S5 / standby</td>
<td>PowerState 行為與 I2C error log</td>
<td>不應在未供電裝置上持續讀取造成錯誤</td>
</tr>
</table>

校準建議：

- 先確認 raw sysfs 值是否合理，再調整 Entity Manager 的 `Offset` / `ScaleFactor`。
- 若偏差與溫度相關，單純固定 offset 可能不足，需重新檢查硬體安裝、感測點位置或換算公式。
- 若 thermal policy 使用 PID control，需要同步確認 sensor 名稱是否被 policy 指到正確物件。
- threshold 建議由熱設計與可靠度規格定義，不要只依 bring-up 當下測得溫度推估。

##### 12.4.13 進階除錯與常見陷阱

<table>
<tr>
<th>問題現象</th>
<th>可能方向</th>
<th>排查 / 處理方式</th>
</tr>
<tr>
<td>i2cdetect 掃不到地址</td>
<td>I2C mux 未切到正確 channel；晶片未供電；地址 strap 與預期不同；bus number 認知不一致</td>
<td>檢查 DTS mux node、/sys/bus/i2c/devices、VCC / GND、嘗試相鄰 address，例如 0x49 / 0x4A</td>
</tr>
<tr>
<td>hwmon 有節點但讀值固定或異常</td>
<td>driver 與硬體型號不完全相容；暫存器格式不同；讀取到 cached value</td>
<td>確認 compatible、看 datasheet、觀察 dmesg；注意 LM75 driver 可能有 cache 週期</td>
</tr>
<tr>
<td>讀值為極端負值，例如 -128°C 附近</td>
<td>通訊失敗、NACK、暫存器讀取格式不正確、driver 回傳錯誤值</td>
<td>確認 I2C waveform、pull-up、clock-frequency；必要時降速到 100 kHz 或 40 kHz 測試</td>
</tr>
<tr>
<td>讀值與標準溫度計偏差大於 2°C</td>
<td>硬體熱耦合不良；sensor 放置位置與量測點不同；解析度或 sample time 設定不同</td>
<td>比對多個溫度點；先確認 raw 值，再評估 JSON Offset 或 ScaleFactor</td>
</tr>
<tr>
<td>D-Bus sensor 未出現</td>
<td>Entity Manager JSON 未載入；Probe 條件不成立；Type 不符合 schema；Bus / Address 對不上 hwmon device</td>
<td>查 Entity Manager log、HwmonTempSensor log、sensor-info.json、schema 與 busctl tree</td>
</tr>
<tr>
<td>Redfish 出現但數值不更新</td>
<td>daemon 輪詢未更新；Redfish cache；sensor availability false</td>
<td>調整 PollRate 測試；busctl monitor 觀察 PropertiesChanged；查 bmcweb log</td>
</tr>
<tr>
<td>系統 log 出現頻繁 I2C 錯誤</td>
<td>輪詢過快；bus 上裝置過多；clock 太高；host / BMC 共用 bus 存在 arbitration 問題</td>
<td>調低 PollRate 或調高 PollInterval；降低 clock-frequency；檢查 bus loading</td>
</tr>
<tr>
<td>PECI CPU 溫度無法讀取</td>
<td>peci driver 未載入；PECI channel 初始化失敗；host CPU 不回應</td>
<td>檢查 DTS peci node、dmesg、host power state 與平台 PECI routing</td>
</tr>
<tr>
<td>threshold 不觸發事件</td>
<td>Thresholds 未進 D-Bus；logging / event policy 未連接；測試溫度未跨越門檻與 hysteresis 條件</td>
<td>busctl introspect 查看 Warning/Critical 介面；busctl monitor；查 phosphor-logging journal</td>
</tr>
</table>

##### 12.4.14 Temperature Sensor 資料表範本

<table>
<tr>
<th>欄位</th>
<th>填寫值</th>
<th>備註</th>
</tr>
<tr>
<td>Sensor Name</td>
<td>[待填]</td>
<td>例如 Ambient_Temp、CPU0_Temp、DIMM_A0_Temp</td>
</tr>
<tr>
<td>Physical Location</td>
<td>[待填]</td>
<td>進風口、出風口、VR、PCIe zone 等</td>
</tr>
<tr>
<td>Source Type</td>
<td>[待填]</td>
<td>I2C hwmon、PECI、PMBus、NVMe、GPU、ADC Thermistor</td>
</tr>
<tr>
<td>Chip / Device</td>
<td>[待填]</td>
<td>TMP75B、LM75A、MAX31725、CPU PECI 等</td>
</tr>
<tr>
<td>I2C Bus / Mux Channel</td>
<td>[待填]</td>
<td>若非 I2C，填入協定或來源</td>
</tr>
<tr>
<td>7-bit Address</td>
<td>[待填]</td>
<td>例如 0x48</td>
</tr>
<tr>
<td>DTS Node</td>
<td>[待填]</td>
<td>檔名與 node path</td>
</tr>
<tr>
<td>Kernel Driver</td>
<td>[待填]</td>
<td>例如 lm75、pmbus、peci-temp</td>
</tr>
<tr>
<td>hwmon Path</td>
<td>[待填]</td>
<td>/sys/class/hwmon/hwmonX/temp1_input</td>
</tr>
<tr>
<td>Entity Manager Type</td>
<td>[待填]</td>
<td>需符合 schema</td>
</tr>
<tr>
<td>D-Bus Path</td>
<td>[待填]</td>
<td>/xyz/openbmc_project/sensors/temperature/...</td>
</tr>
<tr>
<td>Redfish Path</td>
<td>[待填]</td>
<td>/redfish/v1/Chassis/.../Sensors/...</td>
</tr>
<tr>
<td>ScaleFactor / Offset</td>
<td>[待填]</td>
<td>預設 1.0 / 0.0；需有測試依據</td>
</tr>
<tr>
<td>Warning High / Low</td>
<td>[待填]</td>
<td>°C</td>
</tr>
<tr>
<td>Critical High / Low</td>
<td>[待填]</td>
<td>°C</td>
</tr>
<tr>
<td>PowerState</td>
<td>[待填]</td>
<td>AlwaysOn / On</td>
</tr>
<tr>
<td>Fan Policy Consumer</td>
<td>[待填]</td>
<td>PID zone 或 thermal policy 名稱</td>
</tr>
<tr>
<td>Validation Owner</td>
<td>[待填]</td>
<td>BMC / Thermal / HW / System</td>
</tr>
</table>

##### 12.4.15 Temperature Sensor 完整 Checklist（Porting 驗收）

```text
硬體設計階段：
[ ] Sensor chip 型號與 datasheet 確認
[ ] I2C bus number、mux channel 與 device address 確認
[ ] 地址 strap、ALERT pin、供電 rail 與 power state 確認
[ ] 溫度感測點物理位置定義（進風 / 出風 / 元件表面 / hotspot）
[ ] 預期溫度範圍與 thermal policy thresholds 定義
[ ] 若需校準，已定義標準溫度計、測試治具與環境條件

Device Tree / Kernel：
[ ] 對應 I2C bus node status = "okay"
[ ] 若經過 I2C mux，mux node 與 channel 設定正確
[ ] Sensor child node 加入，compatible / reg 正確
[ ] regulator / interrupt / label 視平台需求加入
[ ] Kernel driver 已啟用，例如 CONFIG_SENSORS_LM75
[ ] 開機後 dmesg 無 probe 失敗錯誤
[ ] /sys/class/hwmon/hwmonX/temp1_input 存在且讀值合理
[ ] 以標準溫度計比對讀值，誤差在規格書或 thermal 團隊定義範圍內

Entity Manager / Userspace：
[ ] JSON 設定檔加入正確路徑或已編進 image
[ ] Probe 條件符合目前 board FRU / inventory 資料
[ ] Type 名稱與 sensor-info.json / schema 定義一致
[ ] Bus / Address 數值與實機一致
[ ] ScaleFactor 與 Offset 已視需要調整，且有測試紀錄
[ ] PollRate / PollInterval 符合散熱回應時間與 bus loading 需求
[ ] PowerState 設定符合系統使用情境
[ ] Thresholds（Critical / Warning High / Low）設定完成

D-Bus / 系統整合：
[ ] xyz.openbmc_project.HwmonTempSensor.service 啟動無錯誤
[ ] busctl tree 出現 /xyz/openbmc_project/sensors/temperature/<Name>
[ ] busctl get-property 可讀取 Value，單位為 °C
[ ] WarningHigh / CriticalHigh 等屬性寫入 D-Bus 且數值正確
[ ] busctl monitor 可看到 PropertiesChanged 訊號
[ ] Redfish Thermal 或 Sensors 可查到該溫度 sensor
[ ] IPMI SDR 若有需求，sensor type / entity / threshold mapping 正確
[ ] 加熱 / 冷卻測試時，D-Bus 與 Redfish 數值同步變化
[ ] 觸發過溫時，CriticalAlarmHigh 或 WarningAlarmHigh 旗標正確變化
[ ] threshold 觸發時，phosphor-logging / SEL / Journal entry 符合需求
[ ] 風扇轉速依據溫度變化有正確加速 / 減速
[ ] S5 / standby / host power cycle 下，不產生不必要 I2C error log
```

##### 12.4.16 本節參考資料

- OpenBMC dbus-sensors README: https://github.com/openbmc/dbus-sensors
- OpenBMC dbus-sensors HwmonTempSensor source: https://github.com/openbmc/dbus-sensors/tree/master/src/hwmon-temp
- Linux hwmon sysfs interface: https://docs.kernel.org/hwmon/sysfs-interface.html
- Linux LM75 Device Tree binding: https://github.com/torvalds/linux/blob/master/Documentation/devicetree/bindings/hwmon/lm75.yaml
- Linux LM75 hwmon driver documentation: https://www.kernel.org/doc/html/latest/hwmon/lm75.html

#### 12.5 Voltage Sensor

本節整理 OpenBMC 中 Voltage Sensor 的適用情境、資料路徑與 PMBus / hwmon 類電壓感測器 porting 流程。ADC 類比電壓的細節已在 `11.1 ADC Sensor` 說明；本節重點放在 VR controller、PSU、PMBus device 與獨立 hwmon 晶片等數位讀取來源。

##### 12.5.1 適用情境

Voltage Sensor 用於監控系統中各級電源軌的電壓準位，目的在於確認供電穩定度、比對硬體規格，以及讓電源異常能被 D-Bus、Redfish、IPMI SDR、SEL / Journal 或平台 policy 消費。常見監控對象包含：

```text
P12V：主電源輸入
P5V：週邊介面
P3V3：I/O 與晶片組
P1V8：低壓介面
CPU_VCCIN：CPU 核心輸入電壓
CPU_VDDCR：CPU 計算核心電壓
DIMM rail：記憶體供電
VR output voltage：電壓調節模組輸出
PSU input voltage：電源供應器輸入端
PSU output voltage：電源供應器輸出端
```

在 OpenBMC 中，Voltage Sensor 通常以 D-Bus sensor object 呈現，典型路徑如下：

```text
/xyz/openbmc_project/sensors/voltage/<sensor_name>
```

`dbus-sensors` 的設計是由不同 sensor daemon 從 `hwmon`、D-Bus 或直接 driver 讀值，並建立 `xyz.openbmc_project.Sensor.*` 介面；上層常見消費者包含 Redfish、IPMI SDR、logging 與控制策略。

##### 12.5.2 資料路徑

Voltage Sensor 依硬體來源可分為兩條主要資料路徑。

路徑 A：ADC 類比電壓，細節請回查 `11.1 ADC Sensor`。

```text
類比電壓
    ↓
分壓電阻 / 濾波電路
    ↓
AST2600 ADC
    ↓
iio-hwmon
    ↓
sysfs：/sys/class/hwmon/hwmonX/inY_input
    ↓
adcsensor daemon
    ↓
D-Bus：/xyz/openbmc_project/sensors/voltage/<Name>
```

路徑 B：PMBus / VR 控制器 / PSU / 獨立 hwmon 晶片。

```text
VR Controller / PSU / PMBus device
    ↓
I2C / SMBus 匯流排
    ↓
Linux kernel I2C driver
    ↓
PMBus kernel driver 或晶片專用 hwmon driver
    ↓
hwmon sysfs：/sys/class/hwmon/hwmonX/in*_input
    ↓
OpenBMC sensor daemon
    ↓
D-Bus：/xyz/openbmc_project/sensors/voltage/<Name>
    ↓
Redfish / WebUI / IPMI / logging / policy
```

實務上，服務名稱會依平台採用的 sensor stack 而不同。常見可能是 `psusensor`、`phosphor-hwmon`、平台自有 hwmon voltage daemon，或專案命名的 `HwmonVoltageSensor` 類服務。Porting 時應以 image 內實際 systemd units、Entity Manager schema 與 `sensor-info.json` 為準。

##### 12.5.3 常見來源分類與特性

| 來源類型 | 讀取介面 | OpenBMC 對應服務 | 關鍵注意事項 |
| :--- | :--- | :--- | :--- |
| ADC 分壓電阻 | IIO / hwmon | `adcsensor` | 需計算 `ScaleFactor`；細節回查 ADC Sensor 章節 |
| PMBus VR，例如 CPU / DIMM VR | PMBus driver | `psusensor` / hwmon voltage daemon / 平台服務 | 需確認 I2C bus、address、PMBus Page 與 rail 對應 |
| PMBus PSU | PMBus driver | `psusensor` 或 PSU sensor service | 通常同時有 input voltage、output voltage、power、current、fan 等資料 |
| 獨立 hwmon 晶片，例如 LTC2990 / INA 類 device | I2C hwmon driver | hwmon 類 sensor service | 需在 Device Tree 或 board info 中啟用，並確認 label 對應 |
| 主機板內建 VR / CPU telemetry | 專用 driver 或 PECI / SMBus 類路徑 | 專用 daemon | 依 CPU / vendor driver 與平台策略確認 |

Linux hwmon sysfs 對 voltage 使用 `in<number>_input` 命名；多數文件慣例中 voltage 編號常從 `in0` 開始，而 `*_input` 為單一固定小數格式數值。實際 rail 標籤仍需靠 `in*_label`、schematic、driver 文件或實機量測比對確認。

##### 12.5.4 Porting 步驟：PMBus / hwmon Voltage Sensor

###### Step 1：確認硬體資訊與 PMBus Page

從 schematic、BOM、VR datasheet、PSU MFR 文件與 I2C bus map 取得下列資料：

```text
- VR / PSU / hwmon 晶片型號，例如 MP2971、ISL68137、TPS53679、LTC2990
- 所在 I2C bus number
- 7-bit I2C device address，例如 0x40、0x4C、0x4E
- VR 支援的輸出電壓軌數量，也就是 Page 數量
- 每個 Page 對應的 rail 名稱，例如 Page 0 = Vcore，Page 1 = VCCGT
- 電壓讀取命令，PMBus 常見 READ_VOUT = 0x8B
- 是否存在外部回授分壓或 sense network
- nominal voltage、warning threshold、critical threshold
```

範例參數：

```text
Sensor Name: CPU0_VCCIN
Chip: MP2971
I2C Bus: 8
Address: 0x40
Page: 0
Expected Voltage: 1.80 V
Warning High: 1.89 V
Critical High: 1.98 V
Warning Low: 1.71 V
Critical Low: 1.62 V
PowerState: On
```

###### Step 2：I2C 位址與基本通訊驗證

先確認 I2C bus 上能看到目標位址：

```bash
i2cdetect -y 8
```

預期在 `0x40` 位置看到裝置回應。若該 device 對 SMBus quick command 敏感，請優先查 datasheet、平台 bring-up guideline 或改用較保守的讀取方式。

若需手動讀取 PMBus `READ_VOUT`，可先設定 Page，再讀取 command `0x8B`。不同 IC 對 byte / word order 與 VOUT_MODE 解碼可能不同，下列指令主要用於確認通訊與大致資料變化：

```bash
# 設定 PMBus Page 0
i2cset -y 8 0x40 0x00 0x00

# 讀取 READ_VOUT，command 0x8B
i2cget -y 8 0x40 0x8B w
```

若能取得 `0xXXXX` 類結果，代表 I2C transaction 有回應。是否為正確電壓值，仍需結合 `VOUT_MODE`、driver 解碼、sysfs 讀值與電表量測比對。

###### Step 3：Device Tree 加入 PMBus / VR 節點

以下以 MP2971 在 `i2c8`、address `0x40` 為例。實際 compatible string 需以目前 kernel binding、driver 支援清單與 vendor BSP 為準。

```dts
&i2c8 {
    status = "okay";
    clock-frequency = <100000>;

    vr-controller@40 {
        compatible = "mps,mp2971";
        reg = <0x40>;
        label = "cpu_vr";
    };
};
```

常見 compatible / driver 方向：

```text
"mps,mp2971"
"mps,mp2973"
"isl,isl68137"
"ti,tps53679"
"pmbus"：通用 fallback，需確認 generic PMBus driver 能安全辨識該 device 的能力
```

Kernel 設定需包含 PMBus core、對應 PMBus device driver 或通用 PMBus driver。例如：

```text
CONFIG_PMBUS
CONFIG_SENSORS_PMBUS
CONFIG_SENSORS_MP2975 / CONFIG_SENSORS_ISL68137 / CONFIG_SENSORS_TPS53679 類似選項
```

實際 config 名稱會隨 kernel 版本與 vendor BSP 有差異，請用 `grep -R "config SENSORS_" drivers/hwmon/pmbus/` 或 kernel `.config` 驗證。

###### Step 4：確認 driver probe 與 hwmon sysfs 節點

開機後先看 driver 是否 probe 成功：

```bash
dmesg | grep -Ei 'pmbus|mp297|isl681|tps536|hwmon'
```

列出目前 hwmon 裝置：

```bash
for i in /sys/class/hwmon/hwmon*; do
    echo "$i: $(cat "$i/name" 2>/dev/null)"
done
```

假設 MP2971 對應到 `hwmon3`，可檢查 voltage input：

```bash
ls /sys/class/hwmon/hwmon3/in*_input
cat /sys/class/hwmon/hwmon3/in0_input
cat /sys/class/hwmon/hwmon3/in0_label 2>/dev/null || true
```

hwmon voltage input 通常以 millivolt 為單位，例如：

```text
1800 = 1.800 V
900  = 0.900 V
12000 = 12.000 V
```

多 Page VR 的 `in*_input` 對應需以 driver 與實機結果確認。常見但不可直接假設的映射如下：

```text
in0_input → Page 0，例如 VCCIN
in1_input → Page 1，例如 VCCGT
in2_input → Page 2，例如 VCCSA
```

若 driver 提供 `in*_label`，請優先用 label 與 schematic rail name 建立對照。若沒有 label，建議透過 Page 切換、負載變化、VR telemetry tool、oscilloscope / DMM 量測共同確認。

###### Step 5：Entity Manager / Sensor JSON 配置

設定檔常見位置包含：

```text
/usr/share/entity-manager/configurations/
meta-<platform>/recipes-phosphor/configuration/entity-manager/*.json
平台自有 sensor configuration recipe
```

以下為概念範例。實際 schema 需依專案採用的 `entity-manager` 與 sensor daemon 支援欄位調整。關鍵是 `Name`、`Type`、`Bus`、`Address`、`Page`、`ScaleFactor`、`PowerState` 與 thresholds 要對齊。

```json
{
    "Name": "CPU0_VCCIN",
    "Type": "MP2971",
    "Bus": 8,
    "Address": "0x40",
    "Page": 0,
    "PollInterval": 500,
    "ScaleFactor": 1.0,
    "Offset": 0.0,
    "MaxValue": 2.5,
    "MinValue": 0.0,
    "PowerState": "On",
    "Thresholds": [
        {
            "Name": "upper critical",
            "Direction": "greater than",
            "Severity": 1,
            "Value": 1.98
        },
        {
            "Name": "lower critical",
            "Direction": "less than",
            "Severity": 1,
            "Value": 1.62
        },
        {
            "Name": "upper non critical",
            "Direction": "greater than",
            "Severity": 0,
            "Value": 1.89
        },
        {
            "Name": "lower non critical",
            "Direction": "less than",
            "Severity": 0,
            "Value": 1.71
        }
    ]
}
```

注意事項：

- `Type` 必須與 sensor daemon / Entity Manager 目前支援的類型一致。若 JSON 被解析但 D-Bus sensor 未產生，優先查 Entity Manager log 與 sensor daemon log。
- `Page` 對多輸出 VR 十分關鍵。若 Page 錯誤，sensor 可能讀到另一條 rail，數值仍看似合理但對應錯誤。
- 若 hwmon driver 已輸出正確 mV，`ScaleFactor` 常設為 `1.0`。若 sense point 有外部比例網路，才依硬體比例補償。
- `PowerState` 建議與 rail 供電條件一致。CPU / DIMM VR 通常只在 host power on 後有效；PSU input、standby rail 則可能屬於 AlwaysOn。
- threshold 建議由 rail nominal 與 tolerance 推導，並與硬體保護門檻、VR fault limit、系統降載策略同步。

###### Step 6：啟動服務與 D-Bus 驗證

依平台實際服務名稱重啟對應 sensor service。若專案使用 `HwmonVoltageSensor` 類服務，可採用：

```bash
systemctl restart xyz.openbmc_project.HwmonVoltageSensor.service
journalctl -u xyz.openbmc_project.HwmonVoltageSensor.service -b --no-pager | tail -100
```

若平台使用 `psusensor` 或其他服務，請先列出相關 units：

```bash
systemctl list-units '*sensor*' --no-pager
systemctl list-units '*psu*' --no-pager
```

確認 D-Bus 物件：

```bash
busctl tree xyz.openbmc_project.HwmonVoltageSensor

busctl get-property \
  xyz.openbmc_project.HwmonVoltageSensor \
  /xyz/openbmc_project/sensors/voltage/CPU0_VCCIN \
  xyz.openbmc_project.Sensor.Value \
  Value

busctl introspect \
  xyz.openbmc_project.HwmonVoltageSensor \
  /xyz/openbmc_project/sensors/voltage/CPU0_VCCIN
```

若服務名稱不同，可先用以下方式找 sensor owner：

```bash
busctl tree | grep -i sensors
busctl get-property \
  $(busctl tree | grep -i HwmonVoltageSensor | head -1) \
  /xyz/openbmc_project/sensors/voltage/CPU0_VCCIN \
  xyz.openbmc_project.Sensor.Value \
  Value
```

實務上更穩定的方式是用 mapper 查 object owner：

```bash
busctl call xyz.openbmc_project.ObjectMapper \
  /xyz/openbmc_project/object_mapper \
  xyz.openbmc_project.ObjectMapper GetObject \
  sas \
  /xyz/openbmc_project/sensors/voltage/CPU0_VCCIN \
  0
```

##### 12.5.5 進階除錯與常見陷阱

| 問題現象 | 可能方向 | 排查 / 處理方式 |
| :--- | :--- | :--- |
| `i2cdetect` 可看到 address，但無 `in*_input` | kernel driver 未 bind；compatible 不匹配；PMBus driver 未啟用 | 查 `dmesg`、DTS compatible、kernel `.config`；必要時用 `new_device` 暫時驗證 driver |
| 讀值為 0、固定最大值或 `65535` | VR 未上電、PMBus timeout、device standby、讀到不支援 command | 確認 host power state、VR enable、PMBus status；降低 I2C clock 後比對 |
| VCCIN 應為 1.8 V 但顯示 0.9 V | Page / channel 對應錯誤；讀到其他 rail；driver 解碼或 scaling 不符 | 查 `in*_label`、切 Page 讀 `READ_VOUT`、用 DMM 量測 rail，建立對照表 |
| 多顆 VR address 相同 | I2C address strap 或 mux channel 判讀錯誤 | 查 schematic ADDR pin 與 mux topology；確認 bus number 是 mux 後 channel |
| D-Bus sensor 未出現 | JSON `Type`、`Bus`、`Address`、`Page` 或 schema 欄位不符合 daemon 預期 | 查 Entity Manager log、sensor daemon log、`busctl tree xyz.openbmc_project.EntityManager` |
| Redfish 看得到 sensor 但數值不變 | daemon poll 未更新、sysfs 本身不變、PowerState gating、讀值 cache | 直接 `cat in*_input`，再看 D-Bus `Value` 與 service journal |
| 電壓與電表有固定比例誤差 | 外部分壓、sense point 不同、driver scaling 與平台設計不一致 | 計算硬體比例並調整 `ScaleFactor` / platform config；保留量測紀錄 |
| log 出現 hwmon / pmbus symbol 或 module 相關錯誤 | PMBus core 或晶片 driver 未進 image / module 未載入 | 確認 kernel config、module autoload、`modprobe pmbus` 與 image package |
| threshold 觸發但沒有事件紀錄 | Threshold interface 存在但 logging policy 未接，或 alarm flag 未被消費 | 查 D-Bus threshold properties、phosphor-logging、event service 與 Redfish event 設定 |

##### 12.5.6 Voltage Sensor Porting 驗收 Checklist

硬體設計階段：

```text
[ ] Voltage source 確認：ADC / PMBus VR / PSU / 獨立 hwmon 晶片
[ ] Rail 名稱與 nominal voltage 確認
[ ] I2C bus / address / mux channel 確認
[ ] VR Page 數量與各 Page 對應 rail 確認
[ ] 外部 sense / feedback 分壓是否存在，若有則計算 ScaleFactor
[ ] Warning / Critical threshold 依 rail tolerance 與保護策略設定
[ ] 量測點、sense point、sysfs rail name 已建立對照
```

Device Tree / Kernel：

```text
[ ] 對應 I2C bus node `status = "okay"`
[ ] PMBus / VR / PSU / hwmon node 的 compatible 與 reg 正確
[ ] kernel config 已開啟 PMBus core 與對應 chip driver
[ ] 開機後 dmesg 無 probe 失敗或 timeout
[ ] /sys/class/hwmon/hwmonX/in*_input 存在且讀值合理
[ ] `in*_label` 或實測對照可正確映射到 rail
[ ] 使用 DMM / oscilloscope 比對 sysfs 數值，誤差符合平台規格
[ ] Power state 切換時，讀值、availability、daemon log 行為符合預期
```

Entity Manager / Userspace：

```text
[ ] JSON 設定檔已放入平台 layer 或 image 內正確路徑
[ ] Type 名稱與 sensor daemon 支援清單一致
[ ] Bus / Address / Page / Index 數值正確
[ ] ScaleFactor 與 Offset 已按硬體設計調整
[ ] PollInterval 符合監控需求，建議先以 500~2000 ms 驗證
[ ] PowerState 設定符合 rail 供電時序
[ ] Thresholds 上下限與 Severity 已設定並經 review
```

D-Bus / 系統整合：

```text
[ ] 對應 sensor service 啟動無錯誤
[ ] D-Bus tree 出現 /xyz/openbmc_project/sensors/voltage/<Name>
[ ] `xyz.openbmc_project.Sensor.Value` 可讀到 double 值，單位為 V
[ ] Warning / Critical threshold properties 寫入 D-Bus
[ ] Redfish /redfish/v1/Chassis/.../Sensors 可查到 sensor
[ ] 負載或電源變化時，sysfs 與 D-Bus 數值同步變化
[ ] 過壓 / 欠壓條件下，對應 alarm flag 變為 true
[ ] threshold 觸發時有 journal / event log / SEL 或平台定義事件
[ ] 若有電源管理或降載 policy，電壓異常時行為符合規格
```

##### 12.5.7 本章參考資料

- OpenBMC dbus-sensors README：https://github.com/openbmc/dbus-sensors/blob/master/README.md
- Linux kernel hwmon sysfs interface：https://www.kernel.org/doc/html/latest/hwmon/sysfs-interface.html
- Linux kernel PMBus driver documentation：https://docs.kernel.org/hwmon/pmbus.html
- Linux kernel PMBus register definitions：https://github.com/torvalds/linux/blob/master/drivers/hwmon/pmbus/pmbus.h

#### 12.6 Current Sensor

##### 12.6.1 適用情境

Current Sensor 用於監控系統中各電源軌或負載支路的電流消耗，常用於功耗估算、電源轉換效率分析、過流保護驗證、PSU / VR 健康狀態判讀，以及量產測試時的異常耗電篩查。

常見監控對象包含：

```text
PSU input current：電源供應器輸入電流
PSU output current：電源供應器輸出電流
VR output current：CPU Vcore、VCCIN、DIMM rail 等 VR 輸出電流
Board rail current：主機板 12V / 5V / 3V3 / standby rail 電流
GPU current：GPU 或 accelerator module 電流
DIMM current：記憶體模組或 memory power rail 電流
Fan current：風扇支路電流，常用於堵轉、短路或異常負載偵測
Hot-swap / eFuse current：輸入保護或板級支路電流
```

在 OpenBMC 中，Current Sensor 最終應以標準 sensor object 呈現，典型 D-Bus path 為：

```text
/xyz/openbmc_project/sensors/current/<sensor_name>
```

OpenBMC 的 sensor daemon 可能從 hwmon、D-Bus 或 direct driver access 讀值，再發佈 `xyz.openbmc_project.Sensor.Value`、threshold、availability、operational status 與 association 等介面。後續 Redfish、IPMI SDR、logging、fan / thermal policy 或 power policy 會再消費這些 D-Bus sensor object。

##### 12.6.2 資料路徑

Current Sensor 常見資料路徑可分為三類。

###### 路徑 A：分流電阻 + 放大器 + ADC

```text
電流通過分流電阻（Shunt Resistor）
    ↓
產生壓降：V_sense = I × R_shunt
    ↓
差動放大器 / current sense amplifier 放大壓降：V_adc = V_sense × Gain
    ↓
ADC 取樣，例如 BMC SoC 內建 ADC 或外部 ADC
    ↓
IIO / iio-hwmon / hwmon sysfs
    ↓
ADCSensor 或平台 sensor daemon
    ↓
D-Bus：/xyz/openbmc_project/sensors/current/<Name>
```

這條路徑適合 board rail、fan branch current、standby current 或客製量測點。主要風險是 scaling 同時受 `R_shunt`、amplifier gain、ADC 參考電壓、driver 輸出單位影響，任一資料錯誤都會造成固定比例偏差。

###### 路徑 B：PMBus / VR / PSU 控制器

```text
VR / PSU / Hot-swap Controller 內建 current sense 與 ADC
    ↓
PMBus command：READ_IIN / READ_IOUT
    ↓
Linux PMBus driver 或 chip-specific hwmon driver
    ↓
hwmon sysfs：/sys/class/hwmon/hwmonX/curr*_input
    ↓
PSUSensor / Hwmon 類 sensor daemon / 平台 sensor daemon
    ↓
D-Bus：/xyz/openbmc_project/sensors/current/<Name>
```

PMBus command code 中，常見 current / power 相關命令如下：

| PMBus command | Code | 常見用途 |
| --- | ---: | --- |
| `READ_IIN` | `0x89` | 輸入電流，例如 PSU input current |
| `READ_IOUT` | `0x8C` | 輸出電流，例如 VR output current / PSU output current |
| `READ_POUT` | `0x96` | 輸出功率，屬於 Power Sensor 範圍 |
| `READ_PIN` | `0x97` | 輸入功率，屬於 Power Sensor 範圍 |

Linux PMBus driver 可支援 voltage、current、power、temperature 等 sensor。PMBus generic device 通常不會依賴安全自動 probe，實務上需透過 DTS、I2C device instantiate、platform config 或 Entity Manager 讓 device 被明確建立。

###### 路徑 C：獨立 Current / Power Monitor IC

```text
INA219 / INA226 / INA233 / INA3221 / LTC2945 / Hot-swap Controller / eFuse
    ↓
I2C / SMBus driver
    ↓
hwmon sysfs：curr*_input、in*_input、power*_input
    ↓
Hwmon 類 daemon / PSUSensor / 平台 daemon
    ↓
D-Bus：/xyz/openbmc_project/sensors/current/<Name>
```

INA2xx 類 current shunt / power monitor 通常同時量測 shunt voltage 與 bus voltage，部分晶片可直接計算 current / power。Porting 時需確認 shunt resistor 設定來源，例如 device tree、platform data 或 driver 預設值，避免 driver 使用錯誤 shunt value。

##### 12.6.3 常見來源分類與特性

| 來源類型 | 感測原理 | Linux / OpenBMC 對應 | 關鍵注意事項 |
| :--- | :--- | :--- | :--- |
| 分流電阻 + ADC | `I = V_sense / R_shunt`，再經放大器與 ADC | IIO / iio-hwmon / ADCSensor / 平台 daemon | 需計算 `R_shunt`、Gain、ADC 單位與 `ScaleFactor` |
| PMBus VR | VR controller 內建 current sense | PMBus hwmon、VR chip driver、Hwmon 類 daemon | 需確認 Page、Phase、`READ_IOUT`、calibration 與 host power state |
| PMBus PSU | PSU 內建 input/output current telemetry | PMBus hwmon、PSUSensor | 需區分 input current、output current、fault status 與 redundancy 行為 |
| Hot-swap controller / eFuse | high-side current sense、OCP / fault latch | hwmon、PMBus 或平台 daemon | 常同時涉及 presence、power good、fault latch 與 event |
| INA2xx / INA3221 | 量測 shunt voltage 與 bus voltage | `ina2xx` / `ina3221` hwmon driver | `shunt-resistor` 設定需與 BOM 一致；多 channel 需建立 label 對照 |
| 風扇電流偵測 | 分流電阻 + ADC 或支路 current monitor | ADC / hwmon / 客製 daemon | 常用於異常偵測，需與 fan tach 判斷交叉驗證 |
| GPU / Accelerator current | PMBus / sideband / module controller | PMBus、MCTP / PLDM、GPU sensor daemon | 需注意 power state、module presence、telemetry refresh rate |

##### 12.6.4 單位與 ScaleFactor 設計原則

Current Sensor 最常見問題是單位混淆。建議每個 sensor 都明確記錄：

```text
硬體量測點：V_sense，通常是 V 或 mV
ADC sysfs：可能是 raw code、mV，或 driver 定義的 fixed-point value
hwmon curr*_input：Linux hwmon 規範通常為 milliampere（mA）
D-Bus Sensor.Value：OpenBMC Current Sensor 建議以 Ampere（A）檢查
Redfish Reading：依 schema / implementation 呈現，通常應可標示 A
```

Linux hwmon sysfs 值是 fixed-point single-value 檔案，current input `curr[1-*]_input` 的單位通常為 milliampere。因此：

```text
cat curr1_input = 15000
=> 15000 mA
=> 15 A
```

###### 12.6.4.1 分流電阻 + ADC 換算

硬體基本式：

```text
V_sense = I × R_shunt
V_adc = V_sense × Gain
I = V_adc / (Gain × R_shunt)
```

若 sysfs `inY_input` 已是 ADC pin 上的電壓，且單位為 mV：

```text
ADC_Pin_Voltage_V = inY_input / 1000
Current_A = ADC_Pin_Voltage_V / (Gain × R_shunt)
Current_A = inY_input × 0.001 / (Gain × R_shunt)
ScaleFactor = 0.001 / (Gain × R_shunt)
```

若 daemon 的輸入值已是 V：

```text
Current_A = input_V / (Gain × R_shunt)
ScaleFactor = 1 / (Gain × R_shunt)
```

若輸入值是 ADC raw code：

```text
ADC_Pin_Voltage_V = Raw_Code × (V_ref / 2^N)
Current_A = Raw_Code × (V_ref / 2^N) / (Gain × R_shunt)
ScaleFactor = (V_ref / 2^N) / (Gain × R_shunt)
```

範例：

```text
R_shunt = 0.001 ohm = 1 mΩ
Gain = 50
ADC sysfs = 50 mV
Current_A = 0.05 / (50 × 0.001) = 1.0 A

若 daemon ScaleFactor 乘在 mV 數值上：
ScaleFactor = 0.001 / (50 × 0.001) = 0.02
50 × 0.02 = 1.0 A

若 daemon ScaleFactor 乘在 V 數值上：
ScaleFactor = 1 / (50 × 0.001) = 20.0
0.05 × 20.0 = 1.0 A
```

因此，如果文件中寫 `ScaleFactor = 20.0`，需同步註明 daemon 的輸入值是 V；若輸入值是 mV，則應使用 `0.02`。這個差異是 Current Sensor porting 中很常見的 1000 倍錯誤來源。

###### 12.6.4.2 hwmon `curr*_input` 換算

如果 kernel driver 已輸出標準 hwmon `curr*_input`，通常代表：

```text
sysfs_current_mA = cat currX_input
Current_A = sysfs_current_mA / 1000
```

若 OpenBMC daemon 已把 hwmon current 從 mA 轉成 A，`ScaleFactor` 通常保留 `1.0`。若平台 daemon 直接把 sysfs 值當作 D-Bus value，則需補 `ScaleFactor = 0.001`。實務上需以該專案 sensor daemon 的行為為準，不能只看 JSON 欄位名稱判斷。

###### 12.6.4.3 PMBus Linear / Direct 換算

PMBus device 可能以 Linear11、Linear16 或 Direct format 回傳 telemetry。Linux PMBus core 與 chip-specific driver 通常會依 device capability、driver info 或 device-specific conversion 轉成 hwmon 單位。若讀值呈現固定比例偏差，需確認：

```text
[ ] PMBus driver 是否支援該 chip，或只是使用 generic pmbus
[ ] 該 channel 使用 Linear 或 Direct format
[ ] driver 中 m / b / R 係數是否符合 datasheet
[ ] IOUT / IIN calibration 是否由 driver、device NVM 或平台設定提供
[ ] Page / Phase 是否正確
[ ] sysfs 是 mA，還是已被平台 daemon 用其他方式處理
```

##### 12.6.5 Porting 路徑 A：分流電阻 + ADC 電流偵測

###### Step A1：確認硬體參數

從 schematic、BOM、datasheet 與量測資料取得：

```text
[ ] 分流電阻值 R_shunt，單位 ohm，例如 0.001 Ω
[ ] 分流電阻精度與溫度係數，例如 1%、0.5%、50 ppm/°C
[ ] 分流電阻位置：high-side / low-side
[ ] current sense amplifier 型號與 Gain
[ ] amplifier input common-mode range 是否涵蓋待測 rail
[ ] amplifier output offset / bidirectional current reference
[ ] ADC 參考電壓 V_ref
[ ] ADC 解析度 N-bit
[ ] ADC input range 與保護電路
[ ] 待測電流最大值與過流保護門檻
[ ] 電流方向定義：正向 / 反向 / bidirectional
```

設計檢查建議：

```text
V_sense_max = I_max × R_shunt
V_adc_max = V_sense_max × Gain
P_shunt_max = I_max^2 × R_shunt
```

需確認 `V_adc_max` 不會超出 ADC input range，`P_shunt_max` 不會超過分流電阻額定功率，且 `V_sense` 在低電流時仍高於 ADC noise floor。

###### Step A2：確認 ADC / iio-hwmon / sysfs

此部分與第 12.3 ADC Sensor 共用。Device Tree 需啟用 ADC controller 與必要的 iio-hwmon mapping。開機後先確認 sysfs：

```bash
for h in /sys/class/hwmon/hwmon*; do
    echo "== $h =="
    cat "$h/name" 2>/dev/null || true
    ls "$h"/in*_input 2>/dev/null || true
    ls "$h"/curr*_input 2>/dev/null || true
done

watch -n 1 'for f in /sys/class/hwmon/hwmon*/in*_input /sys/class/hwmon/hwmon*/curr*_input; do [ -e "$f" ] && echo "$f=$(cat $f)"; done'
```

若是通用 ADC，常見只會有 `in*_input`，需要在 sensor daemon / Entity Manager 進行換算。若是 current monitor driver，可能直接提供 `curr*_input`。

###### Step A3：建立量測對照表

Bring-up 階段建議至少建立 idle、typical load、stress load 三個負載點。

| 負載狀態 | sysfs raw / mV | DMM / clamp meter 實測 A | D-Bus A | 誤差 | 備註 |
| --- | ---: | ---: | ---: | ---: | --- |
| Host off / standby | [待填] | [待填] | [待填] | [待填] | [待填] |
| Host on idle | [待填] | [待填] | [待填] | [待填] | [待填] |
| CPU / GPU stress | [待填] | [待填] | [待填] | [待填] | [待填] |

若誤差呈固定比例，優先檢查 `R_shunt`、Gain、sysfs 單位與 `ScaleFactor`。若誤差隨負載變化，需檢查 amplifier offset、ADC 線性度、量測工具位置、PCB trace drop、溫度與濾波設定。

##### 12.6.6 Porting 路徑 B：PMBus / VR / PSU 電流偵測

###### Step B1：確認硬體資訊與 PMBus channel

從 schematic、board power tree、VR / PSU datasheet 取得：

```text
[ ] VR / PSU / HSC 型號
[ ] I2C bus number、mux channel、7-bit address
[ ] PMBus Page 對應 rail，例如 Page 0 = Vcore、Page 1 = VCCGT
[ ] PMBus Phase 是否需要指定
[ ] Current command：READ_IIN / READ_IOUT
[ ] IOUT / IIN calibration 或 sense resistor 設定來源
[ ] Device 是否需要上電或 host on 才回應該 command
[ ] 是否需要 vendor-specific unlock / telemetry enable
[ ] Fault / warning command：STATUS_IOUT、STATUS_INPUT、IOUT_OC_WARN_LIMIT 等
```

多 rail VR 需建立 Page 對照表：

| Device | Bus | Address | Page | Rail | 預期 sysfs | 備註 |
| --- | ---: | ---: | ---: | --- | --- | --- |
| CPU0 VR | 8 | 0x40 | 0 | CPU0_VCORE | curr1_input | [待填] |
| CPU0 VR | 8 | 0x40 | 1 | CPU0_VCCGT | curr2_input | [待填] |
| DIMM VR | 8 | 0x42 | 0 | P1V1_DIMM | curr1_input | [待填] |

###### Step B2：I2C / PMBus 基本通訊驗證

先確認 bus、mux channel 與 address。`i2cdetect` 對部分 device 可能有副作用，使用前需確認 device 行為。

```bash
i2cdetect -y <bus>

# 視 device 是否支援，讀 MFR_ID / MFR_MODEL
 i2cget -y <bus> <addr> 0x99
 i2cget -y <bus> <addr> 0x9A
```

讀取 Page 0 的 output current 前，可先切 Page。下列指令僅作 bring-up 輔助，實際 byte order 需依 `i2cget` 顯示與 PMBus word 格式確認：

```bash
# 設定 PAGE = 0
 i2cset -y <bus> <addr> 0x00 0x00

# READ_IOUT = 0x8C，word read
 i2cget -y <bus> <addr> 0x8C w

# READ_IIN = 0x89，word read
 i2cget -y <bus> <addr> 0x89 w
```

注意事項：

```text
- 某些 PMBus device 在 host off 或 rail disabled 時會回傳 0、NACK、0xffff 或設定 status fault。
- `i2cget ... w` 顯示的 word 可能需要 byte swap 後才符合 PMBus raw word。
- 手動讀取 telemetry 不代表 kernel driver conversion 一定正確，仍需比對 hwmon sysfs。
- 不建議在不了解 device 行為時寫入 calibration、limit 或 operation command。
```

###### Step B3：Device Tree / driver binding

PMBus VR 範例：

```dts
&i2c8 {
    status = "okay";
    clock-frequency = <100000>;

    vr-controller@40 {
        compatible = "mps,mp2971";
        reg = <0x40>;
        label = "cpu0_vr";
    };
};
```

INA2xx 類 current monitor 範例：

```dts
&i2c8 {
    status = "okay";

    current-monitor@41 {
        compatible = "ti,ina226";
        reg = <0x41>;
        shunt-resistor = <1000>; /* micro-ohm，需依 binding 與專案 kernel 確認 */
        label = "p12v_current_monitor";
    };
};
```

Kernel config 檢查方向：

```text
CONFIG_HWMON
CONFIG_I2C
CONFIG_PMBUS
CONFIG_SENSORS_PMBUS
CONFIG_SENSORS_INA2XX
CONFIG_SENSORS_INA3221
對應 VR / PSU / HSC chip-specific driver，例如 MP297x、TPS536xx、LTC、ADM、MAX、IR 等
```

實際 symbol 名稱會隨 kernel 版本與 vendor BSP 不同而改變，請以 `bitbake -c menuconfig virtual/kernel`、`.config`、driver Kconfig 與 `dmesg` 為準。

###### Step B4：確認 driver probe 與 hwmon sysfs

```bash
dmesg | grep -Ei 'pmbus|mp297|tps536|ina2|ina3221|hwmon|i2c'

for h in /sys/class/hwmon/hwmon*; do
    echo "== $h =="
    cat "$h/name" 2>/dev/null || true
    for f in "$h"/curr*_label "$h"/curr*_input "$h"/in*_input "$h"/power*_input; do
        [ -e "$f" ] && echo "$(basename "$f")=$(cat "$f")"
    done
done
```

`curr*_label` 若存在，優先以 label 建立對照；若不存在，需依 driver 文件、Page 順序、實際負載變化與 PMBus 手動讀值建立 mapping。

##### 12.6.7 Entity Manager / Sensor JSON 配置

不同 OpenBMC branch、平台 layer 與 sensor daemon 對 JSON 欄位的名稱可能不同。以下範例用於說明欄位意義，實際需參考專案的 Entity Manager schema、`sensor-info.json`、既有平台 JSON 與 daemon source。

###### PMBus / VR current 範例

```json
{
  "Name": "CPU0_VCORE_CURRENT",
  "Type": "MP2971",
  "Bus": 8,
  "Address": "0x40",
  "Page": 0,
  "PollInterval": 500,
  "ScaleFactor": 1.0,
  "Offset": 0.0,
  "MaxValue": 300.0,
  "MinValue": 0.0,
  "PowerState": "On",
  "Thresholds": [
    {
      "Name": "upper critical",
      "Direction": "greater than",
      "Severity": 1,
      "Value": 250.0
    },
    {
      "Name": "upper non critical",
      "Direction": "greater than",
      "Severity": 0,
      "Value": 200.0
    }
  ]
}
```

設定重點：

```text
- 若 daemon 已把 hwmon mA 轉成 D-Bus A，ScaleFactor 通常為 1.0。
- 若 daemon 直接使用 curr*_input 數值，需設定 ScaleFactor = 0.001。
- CPU / DIMM VR 通常只在 host power on 後有效，PowerState 可設為 On。
- PSU input current 或 standby rail current 可能為 AlwaysOn。
- Page 錯誤時可能仍有合理數字，因此需用負載變化驗證對應 rail。
```

###### 分流電阻 + ADC current 範例

```json
{
  "Name": "P12V_CURRENT",
  "Type": "ADC",
  "Index": 2,
  "ScaleFactor": 0.02,
  "Offset": 0.0,
  "PollInterval": 500,
  "MaxValue": 60.0,
  "MinValue": 0.0,
  "PowerState": "AlwaysOn",
  "Thresholds": [
    {
      "Name": "upper critical",
      "Direction": "greater than",
      "Severity": 1,
      "Value": 50.0
    }
  ]
}
```

上例假設 ADC sysfs 輸入值單位為 mV，且 `R_shunt = 1 mΩ`、`Gain = 50`：

```text
ScaleFactor = 0.001 / (50 × 0.001) = 0.02
```

若 ADC daemon 讀到的值已是 V，則同一組硬體應使用：

```text
ScaleFactor = 1 / (50 × 0.001) = 20.0
```

##### 12.6.8 啟動服務與 D-Bus 驗證

先找出平台實際的 sensor service：

```bash
systemctl list-units '*sensor*' --no-pager
systemctl list-units '*psu*' --no-pager
```

依平台重啟相關服務。若專案使用 HwmonCurrentSensor 類服務，可用：

```bash
systemctl restart xyz.openbmc_project.HwmonCurrentSensor.service
journalctl -u xyz.openbmc_project.HwmonCurrentSensor.service -b --no-pager | tail -100
```

若 Current Sensor 由 PSUSensor 或其他 daemon 產生，請改查對應 service：

```bash
journalctl -b --no-pager | grep -Ei 'current|curr|pmbus|psu|sensor|mp297|ina2'
```

確認 D-Bus object 是否存在：

```bash
busctl tree /xyz/openbmc_project/sensors
busctl tree /xyz/openbmc_project/sensors/current
```

讀取 Current Sensor 數值：

```bash
busctl get-property \
  <service_name> \
  /xyz/openbmc_project/sensors/current/CPU0_VCORE_CURRENT \
  xyz.openbmc_project.Sensor.Value \
  Value
```

若不知道 service owner，使用 ObjectMapper 查：

```bash
busctl call xyz.openbmc_project.ObjectMapper \
  /xyz/openbmc_project/object_mapper \
  xyz.openbmc_project.ObjectMapper GetObject \
  sas \
  /xyz/openbmc_project/sensors/current/CPU0_VCORE_CURRENT \
  0
```

建議至少比對三層讀值：

```text
PMBus / ADC 原始讀值
    ↔ hwmon / IIO sysfs
        ↔ D-Bus Sensor.Value
            ↔ Redfish / IPMI 顯示
```

##### 12.6.9 Redfish / IPMI / Event 整合驗證

Redfish 驗證：

```bash
curl -k -u root:<password> \
  https://<bmc-ip>/redfish/v1/Chassis/<chassis>/Sensors | jq

curl -k -u root:<password> \
  https://<bmc-ip>/redfish/v1/Chassis/<chassis>/Sensors/CPU0_VCORE_CURRENT | jq
```

驗證重點：

```text
[ ] Sensor 名稱與 D-Bus path 對應
[ ] Reading / Value 與 D-Bus 一致
[ ] ReadingUnits 為 A 或可清楚表示 Ampere
[ ] Warning / Critical threshold 顯示正確
[ ] Status.Health / State 與 D-Bus availability、operational status 一致
```

IPMI 驗證：

```bash
ipmitool sensor | grep -i current
ipmitool sdr elist | grep -i current
```

若 IPMI 看不到 Current Sensor，但 D-Bus / Redfish 都正常，需檢查 SDR generation、sensor number、entity ID、sensor type、threshold mapping 與 IPMI bridge policy。

Threshold / event 驗證：

```bash
busctl introspect <service_name> \
  /xyz/openbmc_project/sensors/current/CPU0_VCORE_CURRENT

journalctl -b --no-pager | grep -Ei 'CPU0_VCORE_CURRENT|threshold|critical|warning|current'

curl -k -u root:<password> \
  https://<bmc-ip>/redfish/v1/Systems/system/LogServices/EventLog/Entries | jq
```

##### 12.6.10 進階除錯與常見陷阱

| 問題現象 | 可能方向 | 排查 / 處理方式 |
| :--- | :--- | :--- |
| `curr*_input` 讀值為 0 | Host off、VR disabled、PSU standby、Page 錯、driver 未更新 | 確認 power state、enable signal、Page、sysfs refresh；與 PMBus `READ_IOUT` 比對 |
| `curr*_input` 不存在 | Driver 未 bind、compatible 錯、PMBus command 不支援、kernel config 未啟用 | 查 `dmesg`、DTS、Kconfig、`/sys/bus/i2c/devices/*/driver` |
| D-Bus sensor 未出現 | JSON `Type` / `Bus` / `Address` / `Page` 不符合 daemon 預期 | 查 Entity Manager log、sensor daemon log、ObjectMapper subtree |
| 讀值為負數 | current sense 正負端接反、bidirectional sensor offset 未處理 | 查 schematic high-side / low-side、shunt direction、driver sign handling |
| 讀值固定大 1000 倍 | mA 被當成 A，或 daemon 未做 hwmon 單位轉換 | 確認 `curr*_input` 單位；必要時設定 `ScaleFactor = 0.001` |
| 讀值固定小 1000 倍 | 已轉成 A 後又乘 0.001 | 比對 sysfs、D-Bus、Redfish；移除重複 scaling |
| 讀值與勾表差異固定比例 | `R_shunt`、Gain、PMBus coefficient、shunt-resistor 設定錯 | 查 BOM、datasheet、DTS、driver conversion、量測點位置 |
| 讀值隨負載跳動劇烈 | ADC noise、shunt 壓降太小、I2C refresh 慢、負載本身 pulse | 增加 averaging、調整 poll interval、用示波器檢查 ripple |
| 多 Page 電流全部相同 | driver 未正確切 Page、JSON Page 未生效、讀到同一 channel | 手動寫 PAGE 後讀 `READ_IOUT`；查 driver page support |
| PMBus 讀到 `0xffff` 或 NACK | rail off、command unsupported、device fault、bus timeout | 查 `STATUS_WORD`、`STATUS_IOUT`、host power、I2C 波形 |
| Redfish 數值不變 | sensor daemon 未更新、PowerState gating、sysfs cache、bmcweb route cache | 直接 `cat curr*_input`，再比對 D-Bus `Value` 與 Redfish |
| Threshold 觸發但無事件 | threshold interface 未建立、logging policy 未接、alarm flag 未變化 | 查 D-Bus threshold properties、phosphor-logging、EventLog |

##### 12.6.11 Current Sensor Porting 驗收 Checklist

硬體設計階段：

```text
[ ] Current source 類型確認：分流電阻 + ADC / PMBus VR / PSU / INA / HSC / eFuse
[ ] Power tree 中 sensor 量測點與 rail 名稱確認
[ ] 若為分流電阻架構：R_shunt、精度、溫度係數、額定功率確認
[ ] 若有 amplifier：Gain、offset、common-mode range、輸出範圍確認
[ ] 若為 PMBus VR：I2C bus、mux channel、address、Page、Phase 確認
[ ] 若為 INA / HSC：shunt-resistor / calibration 設定來源確認
[ ] 待測電流範圍、正常值、warning、critical、硬體 OCP 門檻確認
[ ] current sense 方向確認，避免正負號或 bidirectional offset 問題
```

Device Tree / Kernel：

```text
[ ] I2C bus node status = "okay"
[ ] I2C mux channel 與 bus number 對照完成
[ ] PMBus / VR / INA / HSC device node 加入，compatible 與 reg 正確
[ ] 必要 kernel config 已啟用，如 PMBus、chip-specific driver、INA2xx、hwmon
[ ] 開機後 dmesg 無 probe failure、timeout、unsupported command 相關錯誤
[ ] /sys/class/hwmon/hwmonX/name 可對應到目標 device
[ ] curr*_input 存在，且單位已確認為 mA 或平台定義值
[ ] curr*_label 或 Page 對照表已建立
[ ] 使用 DMM / clamp meter / PSU telemetry 比對，工程誤差在可接受範圍內
```

Entity Manager / Userspace：

```text
[ ] JSON 設定檔加入正確 layer，並已編入 image
[ ] `Name` 命名符合平台 sensor naming rule
[ ] `Type` 與 daemon / sensor-info 定義一致
[ ] 分流 + ADC 架構：Index、ScaleFactor、Offset 計算完成
[ ] PMBus 架構：Bus、Address、Page、PowerState 設定正確
[ ] ScaleFactor 已依 sysfs 單位確認，不重複乘 0.001 或漏轉 mA → A
[ ] PollInterval 符合需求，常見建議 500～1000 ms
[ ] PowerState 設定符合 rail 行為，例如 CPU VR 使用 On、standby rail 使用 AlwaysOn
[ ] Thresholds 與硬體保護門檻、系統降載策略一致
```

D-Bus / Redfish / IPMI：

```text
[ ] 對應 sensor service 啟動無錯誤
[ ] ObjectMapper 可找到 /xyz/openbmc_project/sensors/current/<Name>
[ ] busctl get-property 可讀取 Value，且單位以 A 檢查合理
[ ] Warning / Critical threshold property 存在且數值正確
[ ] Redfish Sensor resource 可看到該 current sensor
[ ] IPMI SDR / sensor list 依平台需求可看到該 sensor
[ ] 施加負載變化時，sysfs、D-Bus、Redfish 數值同步變化
[ ] Threshold 觸發時，D-Bus alarm flag、phosphor-logging、SEL / EventLog 行為符合預期
[ ] 若用於 P = V × I，已確認 voltage sensor 與 current sensor 的量測點相同或可接受
```

##### 12.6.12 Current Sensor 資料表範本

| Sensor Name | Source Type | Device | Bus / Addr | Page / Channel | Raw sysfs | sysfs unit | ScaleFactor | D-Bus unit | PowerState | Threshold | 備註 |
| --- | --- | --- | --- | --- | --- | --- | ---: | --- | --- | --- | --- |
| CPU0_VCORE_CURRENT | PMBus VR | MP2971 | 8 / 0x40 | Page 0 | curr1_input | mA | 1.0 或 0.001 | A | On | [待填] | [待填] |
| P12V_CURRENT | ADC + Shunt | ADC channel 2 | N/A | Index 2 | in2_input | mV | 0.02 | A | AlwaysOn | [待填] | R=1mΩ, Gain=50 |
| PSU0_INPUT_CURRENT | PMBus PSU | PSU0 | [待填] | input | curr1_input | mA | [待填] | A | AlwaysOn | [待填] | [待填] |

##### 12.6.13 本節參考資料

- Linux kernel hwmon sysfs interface：`curr[1-*]_input` 為 current input value，單位為 milliampere；hwmon sysfs 使用固定命名與 fixed-point single-value 檔案格式。
- Linux kernel PMBus driver documentation：PMBus driver 支援 voltage、current、power、temperature 等 sensor，且 PMBus device 通常需明確建立，不依賴安全自動 probe。
- Linux PMBus register definitions：`READ_IIN = 0x89`、`READ_IOUT = 0x8C`、`READ_POUT = 0x96`、`READ_PIN = 0x97`。
- OpenBMC dbus-sensors README：sensor daemon 可從 hwmon、D-Bus 或 direct driver access 讀取資料，並以 `/xyz/openbmc_project/sensors/<type>/<sensor_name>` 發佈 D-Bus sensor object。
- Linux INA2xx hwmon documentation：INA2xx 類 current shunt / power monitor 會量測 shunt drop 與 bus voltage，shunt resistor 可由 platform data、device tree 或部分 sysfs attribute 指定。

#### 12.7 Power Sensor

##### 12.7.1 適用情境

Power Sensor 用於監控系統中各元件或電源路徑的功耗，常用於能源效率評估、散熱設計驗證、功率預算管理、power capping、PSU redundancy、長測趨勢分析，以及現場耗電異常排查。

常見監控對象包含：

```text
PSU input power：電源供應器輸入功率，常用於整機 AC / DC 輸入耗電
PSU output power：電源供應器輸出功率，常用於 PSU loading 與 redundancy 判斷
CPU package power：CPU 封裝功率，可能由 CPU telemetry、PECI 或 VR PMBus 間接取得
GPU power：GPU 或 accelerator 模組功率，可能由 MCTP / PLDM、SMBPBI 或 vendor path 提供
Board power：主機板總功耗，可能由 HSC、PSU output 或 V × I 彙總取得
VR power：電壓調節模組輸出功率，例如 Vcore / DIMM rail power
DIMM power：記憶體模組或 memory rail 功耗
NVMe power：NVMe / EDSFF / U.2 / M.2 裝置功耗，可能由 NVMe-MI / PLDM 或平台控制器提供
```

在 OpenBMC 中，Power Sensor 最終應以標準 sensor object 呈現，典型 D-Bus path 為：

```text
/xyz/openbmc_project/sensors/power/<sensor_name>
```

Power Sensor 的 D-Bus `Value` 建議以 Watt（W）檢查與記錄；底層 Linux hwmon `power*_input` 通常是 microWatt（µW）。因此 porting 時需要明確記錄「底層 sysfs 單位」、「daemon 是否已換算」以及「D-Bus 顯示單位」。

##### 12.7.2 資料路徑

Power Sensor 的資料來源可分為四類：PMBus 直接讀取功率、軟體 V × I 計算、CPU / GPU / NVMe telemetry，以及平台虛擬彙總功率。

###### 路徑 A：PMBus 直接讀取功率（硬體計算）

```text
VR Controller / PSU / Hot-swap Controller / Power Monitor 內建功率計算
    ↓
PMBus command：READ_POUT / READ_PIN
    ↓
Linux PMBus driver 或 chip-specific hwmon driver
    ↓
hwmon sysfs：/sys/class/hwmon/hwmonX/power*_input
    ↓
PSUSensor / Hwmon 類 sensor daemon / 平台 sensor daemon
    ↓
D-Bus：/xyz/openbmc_project/sensors/power/<Name>
```

此路徑由硬體或 device firmware 直接計算功率，通常比單純 V × I 的軟體計算更接近 device 自身定義的 telemetry。VR、PSU、hot-swap controller、INA233 / INA2xx / LTC 類 power monitor 都可能提供此類資料。

###### 路徑 B：軟體計算功率（V × I）

```text
Voltage Sensor：/xyz/openbmc_project/sensors/voltage/<voltage_name>
Current Sensor：/xyz/openbmc_project/sensors/current/<current_name>
    ↓
ExternalSensor / VirtualSensor / 客製 daemon 定期讀取兩者
    ↓
計算 P = V × I
    ↓
D-Bus：/xyz/openbmc_project/sensors/power/<Name>
```

此路徑適合硬體沒有 `READ_POUT` / `READ_PIN`，但已有穩定 Voltage Sensor 與 Current Sensor 的場景，例如分流電阻 + ADC 架構。主要風險是 voltage 與 current 的取樣時間不一致、量測點不完全相同、單位已被重複換算，以及負載快速變動造成瞬時誤差。

###### 路徑 C：CPU / GPU / NVMe / Accelerator telemetry

```text
CPU / GPU / NVMe / Accelerator 內部 telemetry
    ↓
PECI / MCTP / PLDM / SMBus / SMBPBI / vendor interface
    ↓
對應 userspace daemon 或 kernel driver
    ↓
D-Bus：/xyz/openbmc_project/sensors/power/<Name>
```

此路徑常見於 CPU package power、GPU board power、NVMe power state 或 accelerator 功率。數值來源可能是裝置內部估算，不一定等同於 board rail 上的實際輸入功率，因此文件中需清楚標示 measure point 與資料來源。

###### 路徑 D：平台虛擬彙總功率

```text
多個 power / voltage / current sensors
    ↓
VirtualSensor / ExternalSensor / platform daemon
    ↓
加總、扣除、平均或效率計算
    ↓
D-Bus：/xyz/openbmc_project/sensors/power/<Name>
```

常見用途包含 board total power、CPU domain total power、GPU tray total power、PSU total output power 或整機估算功率。彙總功率應避免重複計入同一能量路徑，例如 PSU output power 已包含所有 downstream rail，再加上 CPU VR power 會造成 double counting。

##### 12.7.3 常見來源分類與特性

| 來源類型 | 讀取介面 | Linux / OpenBMC 對應 | 關鍵注意事項 |
| :--- | :--- | :--- | :--- |
| PMBus VR | `READ_POUT` (`0x96`) | PMBus hwmon、VR chip driver、Hwmon 類 daemon | 需確認 Page / Phase、POUT scaling、host power state |
| PMBus PSU | `READ_PIN` (`0x97`) / `READ_POUT` (`0x96`) | PMBus hwmon、PSUSensor | input 與 output power 需分開命名與驗證 |
| Hot-swap / eFuse / HSC | PMBus / I2C / register | hwmon、PMBus 或平台 daemon | 通常同時有 current、voltage、power、fault latch |
| INA233 / INA2xx / INA3221 | I2C / PMBus / hwmon | `ina2xx` / `ina233` / `ina3221` driver | shunt resistor、calibration、channel label 需對齊 BOM |
| 軟體 V × I | D-Bus 或 sysfs | ExternalSensor / VirtualSensor / 客製 daemon | Voltage / Current 需同量測點、同單位、同 power state |
| CPU package power | PECI / CPU telemetry / VR PMBus | IntelCPUSensor、PECI、VR hwmon | CPU package power 與 VR input/output power 定義不同 |
| GPU power | MCTP / PLDM / SMBPBI / vendor path | GPU sensor daemon / ExternalSensor | 需注意 GPU presence、driver readiness、功率限制狀態 |
| NVMe power | NVMe-MI / PLDM / vendor path | NVMe sensor daemon / ExternalSensor | 多數為裝置內部狀態或估算，需標示來源 |
| Board total power | PSU output、HSC input、sensor 加總 | PSUSensor / VirtualSensor | 需避免 double counting，並定義 AC input 或 DC board input |

##### 12.7.4 單位與 ScaleFactor 設計原則

Power Sensor 必須先分清楚三層單位：

```text
PMBus raw word：Linear11 / Linear16 / Direct format，依 device 與 driver 轉換
Linux hwmon power*_input：通常為 microwatt（µW）
OpenBMC D-Bus Sensor.Value：Power Sensor 建議以 Watt（W）檢查
```

Linux hwmon sysfs 規範中，`power[1-*]_input` 是 instantaneous power use，power 類屬性單位通常為 microWatt。換算如下：

```text
cat power1_input = 15000000
=> 15,000,000 µW
=> 15 W
```

常見 ScaleFactor 判斷：

```text
若 daemon 已將 hwmon µW 轉成 D-Bus W：ScaleFactor = 1.0
若 daemon 直接把 power*_input 當 D-Bus value：ScaleFactor = 0.000001
若來源是 mW：ScaleFactor = 0.001
若來源已是 W：ScaleFactor = 1.0
```

PMBus `READ_POUT` / `READ_PIN` 可能以 Linear 或 Direct 格式回傳。Linux PMBus core 與 chip-specific driver 通常會依 driver info、device capability 或 direct coefficient 轉成 hwmon 單位。若出現固定比例誤差，需確認：

```text
[ ] 該 device 是否由 chip-specific driver 支援，或只使用 generic pmbus
[ ] 功率 channel 是 Linear11、Linear16 還是 Direct format
[ ] driver 中 m / b / R 係數是否符合 datasheet
[ ] device NVM / register 內 POUT exponent / scale 是否與 driver 設定一致
[ ] sysfs power*_input 是 µW、mW、W 還是 raw-like value
[ ] OpenBMC daemon 是否已自行把 µW 轉成 W
```

若 voltage sensor 以 V，current sensor 以 A 發佈：

```text
Power_W = Voltage_V × Current_A
```

若底層仍是 mV 與 mA：

```text
Power_W = Voltage_mV × Current_mA / 1,000,000
```

PSU 與 VR 常同時具有 input power 與 output power：

```text
Input Power：進入 PSU / VR / HSC 的功率
Output Power：由 PSU / VR 輸出到下游負載的功率
Efficiency = Output Power / Input Power
Loss = Input Power - Output Power
```

命名時建議保留方向，例如 `PSU0_INPUT_POWER`、`PSU0_OUTPUT_POWER`、`CPU0_VCORE_VR_INPUT_POWER`、`CPU0_VCORE_OUTPUT_POWER`。若只記錄 `CPU0_POWER`，後續很難判斷它代表 CPU package power、VR output power、VR input power 或 board rail 估算功率。

##### 12.7.5 Porting 路徑 A：PMBus 直接讀取功率

###### Step A1：確認硬體資訊與功率 channel

從 schematic、BOM、power tree、VR / PSU / HSC datasheet 取得：

```text
[ ] 裝置型號，例如 MP2971、TPS53679、PSU 模組、ADM127x、INA233
[ ] I2C bus number、mux channel、7-bit address
[ ] PMBus Page 對應 rail，例如 Page 0 = Vcore、Page 1 = VCCGT
[ ] PMBus Phase 是否會影響功率讀值
[ ] 目標命令：READ_POUT（0x96）或 READ_PIN（0x97）
[ ] Power format：Linear / Direct / vendor-specific
[ ] POUT / PIN scale、exponent、coefficient 或 calibration 來源
[ ] 是否需要 host power on、rail enable 或 PSU on 才更新 telemetry
[ ] 是否有 hardware averaging、update interval 或 telemetry cache
[ ] fault / warning limit：POUT_OP_WARN_LIMIT、PIN_OP_WARN_LIMIT 等
```

PMBus command 對照：

| Command | Code | 功能 | 常見 sensor 命名 |
| --- | ---: | --- | --- |
| `READ_POUT` | `0x96` | 輸出功率 | `*_OUTPUT_POWER`、`*_VCORE_POWER` |
| `READ_PIN` | `0x97` | 輸入功率 | `*_INPUT_POWER` |
| `POUT_OP_WARN_LIMIT` | `0x6A` | output power warning limit | threshold 參考 |
| `PIN_OP_WARN_LIMIT` | `0x6B` | input power warning limit | threshold 參考 |

###### Step A2：I2C / PMBus 基本通訊驗證

```bash
# 掃描指定 bus；需先確認可安全使用
i2cdetect -y <bus>

# 視 device 是否支援，讀 MFR_ID / MFR_MODEL
i2cget -y <bus> <addr> 0x99
i2cget -y <bus> <addr> 0x9A

# 設定 PAGE = 0
i2cset -y <bus> <addr> 0x00 0x00

# READ_POUT = 0x96，word read
i2cget -y <bus> <addr> 0x96 w

# READ_PIN = 0x97，word read
i2cget -y <bus> <addr> 0x97 w
```

注意事項：

```text
- i2cget ... w 顯示的 word 可能需要 byte swap 才能解讀為 PMBus raw word。
- raw word 非 0 不代表 driver conversion 一定正確，仍需比對 hwmon sysfs 與外部功率計。
- host off、VR disabled、PSU standby 或 telemetry disabled 時，READ_POUT / READ_PIN 可能回 0、NACK、0xffff 或 stale value。
- 不建議在不了解 device 行為時寫入 warning / fault limit 或 calibration register。
```

###### Step A3：Device Tree / driver binding

PMBus VR 範例：

```dts
&i2c8 {
    status = "okay";
    clock-frequency = <100000>;

    vr-controller@40 {
        compatible = "mps,mp2971";
        reg = <0x40>;
        label = "cpu0_vr";
    };
};
```

INA233 / PMBus power monitor 範例：

```dts
&i2c8 {
    status = "okay";

    power-monitor@45 {
        compatible = "ti,ina233";
        reg = <0x45>;
        label = "p12v_power_monitor";
    };
};
```

Kernel config 檢查方向：

```text
CONFIG_HWMON
CONFIG_I2C
CONFIG_PMBUS
CONFIG_SENSORS_PMBUS
CONFIG_SENSORS_INA2XX / CONFIG_SENSORS_INA233 / CONFIG_SENSORS_INA3221
對應 VR / PSU / HSC chip-specific driver，例如 MP297x、TPS536xx、ADM127x、LTC、MAX、IR 等
```

###### Step A4：確認 driver probe 與 hwmon sysfs

```bash
dmesg | grep -Ei 'pmbus|mp297|tps536|ina2|ina233|adm127|ltc|psu|hwmon|i2c'

for h in /sys/class/hwmon/hwmon*; do
    echo "== $h =="
    cat "$h/name" 2>/dev/null || true
    for f in "$h"/power*_label "$h"/power*_input "$h"/in*_input "$h"/curr*_input; do
        [ -e "$f" ] && echo "$(basename "$f")=$(cat "$f")"
    done
done
```

若 `power*_label` 存在，優先用 label 建立 mapping；若不存在，需依 Page、driver 文件、負載變化與 PMBus manual read 建立對照。

```text
power1_input = 15000000 → 15 W
power2_input = 0        → 0 W，可能是 rail off、Page 錯、command unsupported 或尚未更新
```

###### Step A5：量測與對照

| 負載狀態 | sysfs `power*_input` | sysfs 換算 W | D-Bus W | 外部功率計 / PSU W | 誤差 | 備註 |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Host off / standby | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] |
| Host on idle | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] |
| CPU / GPU stress | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] |

若誤差固定為 1000 或 1,000,000 倍，通常是 mW / µW / W 換算問題。若誤差隨負載增加，需檢查 update interval、averaging、量測點差異、PSU efficiency、VR loss 與時間同步。

##### 12.7.6 Porting 路徑 B：軟體計算功率（V × I）

###### Step B1：確認 Voltage 與 Current Sensor 已正常運作

```bash
busctl tree /xyz/openbmc_project/sensors/voltage
busctl tree /xyz/openbmc_project/sensors/current

busctl get-property \
  <voltage_service> \
  /xyz/openbmc_project/sensors/voltage/CPU0_VCCIN \
  xyz.openbmc_project.Sensor.Value \
  Value

busctl get-property \
  <current_service> \
  /xyz/openbmc_project/sensors/current/CPU0_VCORE_CURRENT \
  xyz.openbmc_project.Sensor.Value \
  Value
```

###### Step B2：確認量測點一致性

```text
[ ] Voltage sensor 量到的是同一 rail 的輸出電壓
[ ] Current sensor 量到的是同一 rail 的輸出電流
[ ] Current sensor 不是 upstream input current，也不是多 rail total current
[ ] Voltage / Current 皆受相同 PowerState 控制
[ ] PollInterval 接近，且負載快速變化時可接受誤差
```

常見不一致情境：

```text
V = CPU Vcore output voltage，但 I = VR input current → P 不是 CPU Vcore output power
V = PSU output 12V，但 I = board branch current → P 是 branch power，不是 PSU output power
V = nominal voltage 固定值，但 I 為即時電流 → P 為估算值，不適合高精度 power capping
```

###### Step B3：ExternalSensor / VirtualSensor 配置

```json
{
  "Name": "CPU0_VCORE_POWER",
  "Type": "ExternalSensor",
  "PollInterval": 1000,
  "PowerState": "On",
  "SensorType": "power",
  "ScaleFactor": 1.0,
  "MaxValue": 300.0,
  "MinValue": 0.0,
  "Configuration": {
    "VoltageSensor": "/xyz/openbmc_project/sensors/voltage/CPU0_VCCIN",
    "CurrentSensor": "/xyz/openbmc_project/sensors/current/CPU0_VCORE_CURRENT",
    "Formula": "voltage * current"
  },
  "Thresholds": [
    {
      "Name": "upper critical",
      "Direction": "greater than",
      "Severity": 1,
      "Value": 250.0
    },
    {
      "Name": "upper non critical",
      "Direction": "greater than",
      "Severity": 0,
      "Value": 200.0
    }
  ]
}
```

若 voltage / current 已是 D-Bus V / A，`Formula = voltage * current` 的結果就是 W。若讀取來源是 mV / mA，需在 formula 或 ScaleFactor 統一換算。

##### 12.7.7 Entity Manager / Sensor JSON 配置

###### PMBus VR output power 範例

```json
{
  "Name": "CPU0_VCORE_POWER",
  "Type": "MP2971",
  "Bus": 8,
  "Address": "0x40",
  "Page": 0,
  "PollInterval": 500,
  "ScaleFactor": 1.0,
  "Offset": 0.0,
  "MaxValue": 300.0,
  "MinValue": 0.0,
  "PowerState": "On",
  "Thresholds": [
    {
      "Name": "upper critical",
      "Direction": "greater than",
      "Severity": 1,
      "Value": 250.0
    },
    {
      "Name": "upper non critical",
      "Direction": "greater than",
      "Severity": 0,
      "Value": 200.0
    }
  ]
}
```

###### PSU input power 範例

```json
{
  "Name": "PSU0_INPUT_POWER",
  "Type": "PSU",
  "Bus": 4,
  "Address": "0x58",
  "PollInterval": 1000,
  "ScaleFactor": 1.0,
  "MaxValue": 1000.0,
  "MinValue": 0.0,
  "PowerState": "AlwaysOn",
  "Thresholds": [
    {
      "Name": "upper critical",
      "Direction": "greater than",
      "Severity": 1,
      "Value": 900.0
    }
  ]
}
```

配置重點：

```text
- Name 必須清楚包含 input/output、rail/domain、device index。
- Type 需與專案 sensor-info / schema / daemon 支援類型一致。
- PMBus 多 Page 裝置需填 Page；若有 Phase，也需確認專案是否支援。
- ScaleFactor 需依 daemon 對 hwmon µW 的處理方式設定。
- PowerState 需符合功率來源：CPU / DIMM VR 通常 On；PSU input / standby rail 通常 AlwaysOn。
- MaxValue / threshold 應與 power budget、PSU rating、VR rating、thermal design power 對齊。
```

##### 12.7.8 啟動服務與 D-Bus 驗證

```bash
systemctl list-units '*sensor*' --no-pager
systemctl list-units '*psu*' --no-pager
systemctl list-units '*external*' --no-pager

systemctl restart xyz.openbmc_project.HwmonPowerSensor.service
journalctl -u xyz.openbmc_project.HwmonPowerSensor.service -b --no-pager | tail -100

journalctl -b --no-pager | grep -Ei 'power|pout|pin|psu|external|sensor|pmbus'

busctl tree /xyz/openbmc_project/sensors
busctl tree /xyz/openbmc_project/sensors/power

busctl get-property \
  <service_name> \
  /xyz/openbmc_project/sensors/power/CPU0_VCORE_POWER \
  xyz.openbmc_project.Sensor.Value \
  Value

busctl call xyz.openbmc_project.ObjectMapper \
  /xyz/openbmc_project/object_mapper \
  xyz.openbmc_project.ObjectMapper GetObject \
  sas \
  /xyz/openbmc_project/sensors/power/CPU0_VCORE_POWER \
  0
```

建議至少比對四層：

```text
PMBus raw / V × I inputs
    ↔ hwmon sysfs power*_input 或 source sensors
        ↔ D-Bus Sensor.Value
            ↔ Redfish / IPMI / logs
```

##### 12.7.9 Redfish / IPMI / Event / Power Policy 驗證

```bash
curl -k -u root:<password> \
  https://<bmc-ip>/redfish/v1/Chassis/<chassis>/Sensors | jq

curl -k -u root:<password> \
  https://<bmc-ip>/redfish/v1/Chassis/<chassis>/Sensors/CPU0_VCORE_POWER | jq

curl -k -u root:<password> \
  https://<bmc-ip>/redfish/v1/Chassis/<chassis>/PowerSubsystem | jq

ipmitool sensor | grep -Ei 'power|watt|psu'
ipmitool sdr elist | grep -Ei 'power|watt|psu'
```

驗證重點：

```text
[ ] Redfish sensor 名稱與 D-Bus path 對應
[ ] Reading / Value 與 D-Bus 一致
[ ] ReadingUnits 為 W 或可清楚表示 Watt
[ ] Warning / Critical threshold 顯示正確
[ ] Status.Health / State 與 D-Bus availability、operational status 一致
[ ] 若 power sensor 作為 power cap input，確認 consumer 讀取的是正確 sensor
[ ] 若 power sensor 用於 PSU redundancy，確認 PSU removal / fault / AC loss 時數值與 state 一致
[ ] 若 power sensor 用於 thermal policy，確認高負載時數值上升與 fan response 時序合理
```

Event 驗證：

```bash
busctl introspect <service_name> \
  /xyz/openbmc_project/sensors/power/CPU0_VCORE_POWER

journalctl -b --no-pager | grep -Ei 'CPU0_VCORE_POWER|threshold|critical|warning|power'

curl -k -u root:<password> \
  https://<bmc-ip>/redfish/v1/Systems/system/LogServices/EventLog/Entries | jq
```

##### 12.7.10 進階除錯與常見陷阱

| 問題現象 | 可能方向 | 排查 / 處理方式 |
| :--- | :--- | :--- |
| `power*_input` 不存在 | device 不支援 `READ_POUT` / `READ_PIN`；driver 未宣告 power capability；kernel config 未啟用 | 查 datasheet、driver Kconfig、`dmesg`、PMBus func flags；必要時使用 V × I 路徑 |
| `power*_input` 讀值為 0 | Host off、VR disabled、PSU standby、Page 錯、telemetry 未更新 | 確認 power state、enable signal、PMBus PAGE、手動讀 `READ_POUT` / `READ_PIN` |
| D-Bus sensor 未出現 | Entity Manager JSON `Type` / `Bus` / `Address` / `Page` 不符合 daemon 預期 | 查 Entity Manager log、sensor daemon log、ObjectMapper subtree |
| 讀值固定大 1,000,000 倍 | µW 被當成 W | 確認 `power*_input` 單位；必要時 `ScaleFactor = 0.000001` |
| 讀值固定小 1,000,000 倍 | 已轉 W 後又除以 1,000,000 | 比對 sysfs、D-Bus、Redfish，移除重複 scaling |
| 讀值固定大或小 1000 倍 | mW / W 或 µW / mW 換算錯誤 | 查 driver output、daemon conversion、JSON ScaleFactor |
| 多 Page 功率全部相同 | driver 未正確切 Page、JSON Page 未生效、讀到同一 channel | 手動設定 PAGE 後讀 `READ_POUT`；查 driver page support |
| 軟體 V × I 與 PMBus POUT 差距大 | 量測點不同、時間不同步、V/I sensor scaling 錯、PMBus 是 averaged power | 對齊 measurement point；比對 fixed load；確認 update interval |
| PSU input power 與 output power 不符 | PSU efficiency、loading、AC/DC input 定義不同 | 分別命名 input/output，使用 PSU datasheet efficiency curve 檢查 |
| board total power 加總過大 | double counting，例如 PSU output + VR output 重複計入 | 建立 power tree，標示每個 sensor 所在能量路徑 |
| 功率為負數 | Current sensor 為負、bidirectional sensor offset、formula sign 錯 | 回查 Current Sensor 方向與 offset；修正 formula 或 sign |
| Redfish 顯示功率但數值不變 | daemon poll 未更新、PowerState gating、sysfs cache、bmcweb cache | 直接 `cat power*_input`，再比對 D-Bus 與 Redfish |
| Threshold 觸發但無事件 | threshold interface 未建立、logging policy 未接、alarm flag 未變化 | 查 D-Bus threshold properties、phosphor-logging、EventLog |
| Power capping 行為異常 | consumer 使用錯 sensor 或單位錯 | 查 power cap service config、D-Bus path、Value 單位與上限設定 |

##### 12.7.11 Power Sensor Porting 驗收 Checklist

硬體設計階段：

```text
[ ] Power source 類型確認：PMBus 直接讀取 / 軟體 V × I / CPU telemetry / GPU telemetry / NVMe / 虛擬加總
[ ] Power tree 中量測點確認：input、output、rail、domain、package、board total
[ ] 若為 PMBus：I2C bus、mux channel、address、Page、Phase 確認
[ ] READ_POUT / READ_PIN 支援狀態確認
[ ] PMBus POUT / PIN scale、exponent、coefficient 或 calibration 來源確認
[ ] 若為 V × I：對應 Voltage Sensor 與 Current Sensor 的量測點一致
[ ] 功率範圍、TDP、PSU rating、VR rating、warning、critical 門檻確認
[ ] input power / output power 命名規則確認，避免後續判讀混淆
```

Device Tree / Kernel：

```text
[ ] I2C bus node status = "okay"
[ ] I2C mux channel 與 bus number 對照完成
[ ] PMBus / VR / PSU / INA / HSC device node 加入，compatible 與 reg 正確
[ ] 必要 kernel config 已啟用，如 PMBus、chip-specific driver、INA2xx、hwmon
[ ] 開機後 dmesg 無 probe failure、timeout、unsupported command 相關錯誤
[ ] /sys/class/hwmon/hwmonX/name 可對應到目標 device
[ ] power*_input 存在，且單位已確認為 µW 或平台定義值
[ ] power*_label 或 Page 對照表已建立
[ ] 若使用 V × I，voltage / current 來源 sensor 均已驗證
[ ] 使用外部功率計、PSU telemetry 或穩定負載比對，工程誤差在可接受範圍內
```

Entity Manager / Userspace：

```text
[ ] JSON 設定檔加入正確 layer，並已編入 image
[ ] Name 命名符合平台 sensor naming rule，且清楚標示 input/output
[ ] Type 與 daemon / sensor-info / schema 定義一致
[ ] PMBus 架構：Bus、Address、Page、PowerState 設定正確
[ ] V × I 架構：VoltageSensor、CurrentSensor、Formula 設定正確
[ ] ScaleFactor 已依 sysfs 單位確認，不重複換算 µW / mW / W
[ ] PollInterval 符合需求，常見建議 500～1000 ms
[ ] PowerState 設定符合功率來源，例如 CPU VR 使用 On、PSU input 使用 AlwaysOn
[ ] Thresholds 與 power budget、PSU rating、VR rating、thermal policy、power cap policy 一致
```

D-Bus / Redfish / IPMI / Policy：

```text
[ ] 對應 sensor service 啟動無錯誤
[ ] ObjectMapper 可找到 /xyz/openbmc_project/sensors/power/<Name>
[ ] busctl get-property 可讀取 Value，且單位以 W 檢查合理
[ ] Warning / Critical threshold property 存在且數值正確
[ ] Redfish Sensor 或 PowerSubsystem 依平台需求可看到該 power sensor
[ ] IPMI SDR / sensor list 依平台需求可看到該 sensor
[ ] 施加負載變化時，sysfs、D-Bus、Redfish 數值同步變化
[ ] Threshold 觸發時，D-Bus alarm flag、phosphor-logging、SEL / EventLog 行為符合預期
[ ] 若用於 power capping / thermal control / PSU redundancy，consumer 讀取 path 與單位均已確認
[ ] 若為 board total power，已確認沒有重複計入同一能量路徑
```

##### 12.7.12 Power Sensor 資料表範本

| Sensor Name | Source Type | Device | Bus / Addr | Page / Channel | Raw sysfs / Source | sysfs unit | ScaleFactor | D-Bus unit | PowerState | Threshold | 備註 |
| --- | --- | --- | --- | --- | --- | --- | ---: | --- | --- | --- | --- |
| CPU0_VCORE_POWER | PMBus VR | MP2971 | 8 / 0x40 | Page 0 | power1_input | µW | 1.0 或 0.000001 | W | On | [待填] | READ_POUT |
| PSU0_INPUT_POWER | PMBus PSU | PSU0 | 4 / 0x58 | input | power1_input | µW | [待填] | W | AlwaysOn | [待填] | READ_PIN |
| PSU0_OUTPUT_POWER | PMBus PSU | PSU0 | 4 / 0x58 | output | power2_input | µW | [待填] | W | AlwaysOn | [待填] | READ_POUT |
| CPU0_VCORE_POWER_EST | V × I | ExternalSensor | N/A | Vcore | voltage × current | V × A | 1.0 | W | On | [待填] | software calculated |
| BOARD_INPUT_POWER | HSC | ADM127x | [待填] | input | power1_input | µW | [待填] | W | AlwaysOn | [待填] | board inlet |

##### 12.7.13 本節參考資料

- Linux kernel hwmon sysfs interface：`power[1-*]_input` 為 instantaneous power use，power 類屬性單位為 microWatt；hwmon sysfs 使用 fixed-point single-value 檔案格式。
- Linux kernel PMBus driver documentation：PMBus driver 支援 voltage、current、power、temperature 等 sensor，且 PMBus device 通常需明確建立，不依賴安全自動 probe。
- Linux PMBus register definitions：`READ_POUT = 0x96`、`READ_PIN = 0x97`，另有 `POUT_OP_WARN_LIMIT = 0x6A` 與 `PIN_OP_WARN_LIMIT = 0x6B` 可作 threshold 設計參考。
- OpenBMC dbus-sensors README：sensor daemon 可從 hwmon、D-Bus 或 direct driver access 讀取資料，並以 `/xyz/openbmc_project/sensors/<type>/<sensor_name>` 發佈 D-Bus sensor object。

#### 12.8 Fan Tach Sensor

##### 12.8.1 適用情境

Fan Tach Sensor（風扇轉速感測器）用於讀取風扇實際轉速，單位通常是 RPM（Revolutions Per Minute，每分鐘轉數）。在 BMC 平台中，fan tach 是風扇控制迴路的回授訊號，用來確認 PWM 輸出後風扇是否確實轉到目標轉速，也用來偵測停轉、堵轉、轉速過低、風扇拔除、雙轉子風扇單 rotor 失效，以及風扇冗餘不足。

常見監控對象包含：

```text
System inlet fan：系統進風扇
System exhaust fan：系統出風扇
CPU heatsink fan：CPU 散熱風扇
PSU fan：電源供應器內建風扇
GPU fan：GPU / accelerator 散熱風扇
HDD / backplane fan：硬碟背板或風扇牆風扇
Fan module rotor：風扇模組內的單一 rotor，例如雙轉子風扇的 front / rear rotor
```

在 OpenBMC 中，fan tach sensor 典型 D-Bus path 為：

```text
/xyz/openbmc_project/sensors/fan_tach/<sensor_name>
```

`fan_tach` 的 `Value` 應以 RPM 檢查。若底層 Linux hwmon `fan*_input` 已輸出 RPM，通常不需要比例換算。若數值與外部轉速計呈現 2 倍、1/2、4 倍或 1/4 倍關係，優先檢查每轉脈衝數（Pulses Per Revolution, PPR）、tach divisor 與 channel 對應。

##### 12.8.2 資料路徑

Fan Tach Sensor 的完整資料路徑如下：

```text
風扇本體產生 Tachometer 脈衝訊號
    ↓
風扇連接器 Tach pin 經 pull-up / buffer / mux / CPLD 接到 BMC Tach input
    ↓
BMC Tachometer controller 計數脈衝或量測週期
    ↓
Linux kernel driver 依 PPR、clock、divisor、sample window 換算 RPM
    ↓
hwmon sysfs：/sys/class/hwmon/hwmonX/fan*_input
    ↓
FanSensor / PSUSensor / 平台 sensor daemon 讀取 sysfs
    ↓
D-Bus：/xyz/openbmc_project/sensors/fan_tach/<Name>
    ↓
phosphor-fan-presence / phosphor-fan-monitor / phosphor-pid-control / bmcweb / IPMI SDR
```

PWM 與 Tach 需分開看：

```text
PWM：BMC 輸出控制訊號，常見 25 kHz，用來控制風扇轉速
Tach：風扇輸出回授訊號，常見 open-drain，每轉 1～4 個脈衝
```

ASPEED G6 / AST2600 的 PWM controller 與 Fan Tacho controller 是獨立硬體區塊，常見 binding 中也將 PWM outputs 與 fan tach inputs 分開描述。因此 Device Tree 需同時確認 PWM pin、Tach pin、fan child node 與 channel 對應。

##### 12.8.3 關鍵硬體參數

Porting 前需從 schematic、BOM、風扇規格書、CPLD register map 與 board bring-up 記錄取得下列資料：

```text
[ ] 風扇型號、供應商、料號、風扇規格書版本
[ ] 風扇線材定義：GND、Power、Tach、PWM、Presence、Fault、FRU EEPROM
[ ] Tach 電氣型態：open-drain / open-collector / push-pull
[ ] Tach pull-up 電壓與阻值：BMC rail、fan rail、CPLD rail，是否有 level shift
[ ] 每轉脈衝數 PPR：常見為 2，也可能為 1、4 或 vendor-specific
[ ] Tach channel：連到 BMC Tach0 / Tach1 / ... 或經 CPLD / mux 後的 channel
[ ] PWM channel：控制該風扇的 PWM0 / PWM1 / ...
[ ] PWM 頻率需求：常見 25 kHz，但需以風扇規格書為準
[ ] PWM polarity：正常 duty 定義、是否反相、是否需要 pull-up
[ ] 最小啟動 duty / start boost：低速啟動失敗時需先給較高 PWM
[ ] Min RPM / Max RPM / Rated RPM / RPM tolerance
[ ] Lower warning / lower critical threshold
[ ] 風扇存在偵測：無、Tach-based、GPIO presence、CPLD presence、FRU EEPROM
[ ] 單顆風扇是否多 rotor：一個 PWM 可能對應兩個 tach feedback
[ ] 風扇模組對應 inventory path、FRU path 與 LED fault indicator
```

Tach 訊號頻率與 RPM 的關係：

```text
Tach_Frequency_Hz = RPM / 60 × PPR
RPM = Tach_Frequency_Hz × 60 / PPR
```

例：風扇 6000 RPM、PPR = 2：

```text
Tach_Frequency = 6000 / 60 × 2 = 200 Hz
```

若示波器量到 200 Hz，但 sysfs 顯示 12000 RPM，常見方向是 PPR 設成 1；若 sysfs 顯示 3000 RPM，常見方向是 PPR 設成 4，或 driver / DTS 對 PPR 的欄位沒有生效。

Tach 線常見為 open-drain / open-collector，需要外部 pull-up。設計與排查時需確認：

```text
[ ] Pull-up 電壓是否符合 BMC input absolute maximum rating
[ ] 若 fan tach 為 5V pull-up，是否有 level shifter 或 BMC pin 可容忍 5V
[ ] Pull-up 阻值是否造成上升時間過慢，尤其高轉速與長線材場景
[ ] 是否經 CPLD / buffer / mux，且該路徑在 BMC 讀取前已 enable
[ ] Tach pin 是否與其他 multi-function pin 或 strap function 衝突
[ ] 風扇拔除時 tach line 是否浮動，是否需 board-side pull-up / pull-down
```

##### 12.8.4 常見來源分類與特性

| 來源類型 | 底層來源 | OpenBMC 常見服務 | 注意事項 |
| :--- | :--- | :--- | :--- |
| BMC SoC tach controller | BMC Tach input → hwmon `fan*_input` | FanSensor | 需對齊 pinctrl、tach channel、PPR、PWM 對應 |
| generic `pwm-fan` driver | PWM + 可選 tach interrupt | FanSensor / hwmon | `fan1_input` 為 RPM；PWM 以 `pwm1` 0～255 控制 |
| ASPEED G6 PWM/Tach driver | `aspeed,ast2600-pwm-tach` | FanSensor | PWM 與 Tach 為獨立硬體；fan child node 需含 `tach-ch` |
| Nuvoton NPCM PWM/Fan | NPCM PWM / fan tach controller | FanSensor | 需確認 SoC binding 的 fan child node 與 channel 編號 |
| PSU 內建風扇 | PMBus / PSU hwmon `fan*_input` | PSUSensor | fan path 可能由 PSU service 建立，不一定是 FanSensor |
| Fan controller IC | I2C fan controller，例如 MAX / NCT / EMC | hwmon / FanSensor | 通常有 fan divisor、target RPM、PWM、fault register |
| CPLD / FPGA 計數 | CPLD register / I2C / LPC / mailbox | 客製 daemon / ExternalSensor | 需定義 register update rate、scale、timeout、stale condition |
| GPU / accelerator 風扇 | vendor telemetry | GPU daemon / ExternalSensor | 需區分 GPU internal fan 與 chassis fan |

##### 12.8.5 Porting 步驟 A：Device Tree / Kernel

###### Step A1：確認 SoC PWM/Tach controller node

AST2600 常見控制器節點形式如下，實際名稱與位置以專案 DTS / dtsi 為準：

```dts
&pwm_tach {
    status = "okay";
    pinctrl-names = "default";
    pinctrl-0 = <&pinctrl_pwm0_default &pinctrl_pwm1_default
                 &pinctrl_tach0_default &pinctrl_tach1_default>;
};
```

若使用 upstream ASPEED G6 PWM/Tach binding，fan child node 常見格式如下：

```dts
&pwm_tach {
    status = "okay";
    pinctrl-names = "default";
    pinctrl-0 = <&pinctrl_pwm0_default &pinctrl_pwm1_default
                 &pinctrl_tach0_default &pinctrl_tach1_default
                 &pinctrl_tach2_default>;

    fan-0 {
        tach-ch = /bits/ 8 <0x0>;
        pwms = <&pwm_tach 0 40000 0>;
    };

    fan-1 {
        tach-ch = /bits/ 8 <0x1 0x2>;
        pwms = <&pwm_tach 1 40000 0>;
    };
};
```

說明：

```text
pwms = <&pwm_tach 0 40000 0>
    0      ：PWM channel 0
    40000  ：period = 40000 ns = 25 kHz
    0      ：PWM flags，是否反相需依 binding / driver 定義

tach-ch = /bits/ 8 <0x1 0x2>
    表示該 fan node 有兩個 tach input，常見於雙轉子風扇或雙回授線
```

###### Step A2：generic `pwm-fan` driver 場景

若平台使用 generic `pwm-fan`，常見 DTS 如下：

```dts
fan0: pwm-fan {
    compatible = "pwm-fan";
    pwms = <&pwm 0 40000 0>;
    interrupts-extended = <&gpio5 1 IRQ_TYPE_EDGE_FALLING>;
    pulses-per-revolution = <2>;
    cooling-levels = <0 80 120 160 200 255>;
    #cooling-cells = <2>;
};
```

`pwm-fan` binding 使用 `pulses-per-revolution` 描述每轉脈衝數，預設常見為 2。若專案使用 vendor binding 或舊版 ASPEED driver，可能使用 `fan-ppr`、`aspeed,fan-ppr` 或其他欄位；請以 kernel binding 與 driver source 為準。

###### Step A3：Kernel config

確認必要 kernel config 已啟用：

```text
CONFIG_HWMON
CONFIG_PWM
CONFIG_SENSORS_PWM_FAN
CONFIG_PWM_ASPEED 或 SoC 對應 PWM driver
CONFIG_SENSORS_ASPEED_G6_PWM_TACH 或 vendor BSP 對應 ASPEED fan tach driver
CONFIG_GPIOLIB / CONFIG_GPIO_CDEV（若 presence 使用 GPIO）
CONFIG_THERMAL（若 fan 同時作為 cooling device）
```

實際 symbol 名稱會隨 kernel branch、OpenBMC branch 與 vendor BSP 改變，請以 `bitbake -c menuconfig virtual/kernel`、`tmp/work/.../.config`、Kconfig 與 `dmesg` 為準。

###### Step A4：開機 probe 與 pinctrl 檢查

```bash
dmesg | grep -Ei 'pwm|tach|fan|hwmon|aspeed|npcm'

cat /sys/kernel/debug/pinctrl/*/pinmux-pins 2>/dev/null | grep -Ei 'pwm|tach|fan'

for h in /sys/class/hwmon/hwmon*; do
    echo "== $h =="
    cat "$h/name" 2>/dev/null || true
    for f in "$h"/fan*_label "$h"/fan*_input "$h"/fan*_min "$h"/fan*_max "$h"/pwm*; do
        [ -e "$f" ] && echo "$(basename "$f")=$(cat "$f")"
    done
done
```

##### 12.8.6 Porting 步驟 B：sysfs 與硬體訊號驗證

###### Step B1：確認 hwmon fan input

```bash
find /sys/class/hwmon -maxdepth 2 -name 'fan*_input' -print
cat /sys/class/hwmon/hwmonX/fan1_input
```

預期輸出：

```text
3000
```

代表目前風扇轉速約 3000 RPM。`fan*_input` 若來自標準 hwmon 介面，通常就是 RPM。

###### Step B2：手動調整 PWM 並觀察 RPM

若 driver 提供 `pwm1`：

```bash
cat /sys/class/hwmon/hwmonX/pwm1_enable 2>/dev/null || true

# 依 driver 支援情況切到 manual；需在實驗室與安全負載下執行
echo 1 > /sys/class/hwmon/hwmonX/pwm1_enable

for v in 80 120 160 200 255; do
    echo $v > /sys/class/hwmon/hwmonX/pwm1
    sleep 5
    echo "pwm=$v rpm=$(cat /sys/class/hwmon/hwmonX/fan1_input)"
done
```

驗證重點：

```text
[ ] PWM 提高時 RPM 應跟著上升
[ ] PWM 降低時 RPM 應跟著下降，但會有機械慣性延遲
[ ] PWM = 0 時風扇是否停止，取決於 pwm1_enable mode、風扇規格與 board power design
[ ] 某些風扇低 duty 無法啟動，需要 start boost 或最小 duty
```

###### Step B3：示波器 / 邏輯分析儀量測 Tach

量測點建議：

```text
1. 風扇連接器 Tach pin
2. pull-up 後的 board-side tach node
3. buffer / CPLD / level shifter 後的 BMC-side tach node
4. BMC pin 附近，若 layout 允許
```

量測項目：

```text
[ ] Tach 高低電位是否符合 BMC input 規格
[ ] 是否有脈衝，頻率是否符合 RPM / 60 × PPR
[ ] 上升 / 下降時間是否過慢，是否有 ringing 或毛刺
[ ] 風扇拔除時 tach line 是否固定在預期狀態
[ ] PWM 改變後 tach frequency 是否同步變化
```

##### 12.8.7 Entity Manager / dbus-sensors 配置

OpenBMC 不同 branch 的 FanSensor schema 可能不同，以下以常見概念說明；實際欄位需以 `entity-manager` schema、平台既有 JSON、FanSensor source 與 journal log 為準。

###### 方式一：完整 Fan 裝置定義

```json
{
  "Name": "Fan0",
  "Type": "Fan",
  "Pwm": 0,
  "Tachs": [
    {
      "Name": "Fan0_Tach",
      "Index": 0
    }
  ],
  "MaxPwm": 255,
  "MinPwm": 30,
  "PollInterval": 1000,
  "PowerState": "AlwaysOn",
  "Thresholds": [
    {
      "Name": "lower critical",
      "Direction": "less than",
      "Severity": 1,
      "Value": 500
    },
    {
      "Name": "lower non critical",
      "Direction": "less than",
      "Severity": 0,
      "Value": 1000
    }
  ]
}
```

###### 方式二：雙轉子風扇

```json
{
  "Name": "Fan0",
  "Type": "Fan",
  "Pwm": 0,
  "Tachs": [
    {
      "Name": "Fan0_Front_Rotor",
      "Index": 0
    },
    {
      "Name": "Fan0_Rear_Rotor",
      "Index": 1
    }
  ],
  "MaxPwm": 255,
  "MinPwm": 40,
  "PowerState": "AlwaysOn",
  "Thresholds": [
    {
      "Name": "lower critical",
      "Direction": "less than",
      "Severity": 1,
      "Value": 800
    }
  ]
}
```

###### 方式三：獨立 Tach sensor

```json
{
  "Name": "Fan0_Tach",
  "Type": "Tach",
  "Index": 0,
  "PollInterval": 1000,
  "MaxValue": 30000,
  "MinValue": 0,
  "PowerState": "AlwaysOn",
  "Thresholds": [
    {
      "Name": "lower critical",
      "Direction": "less than",
      "Severity": 1,
      "Value": 500
    }
  ]
}
```

欄位檢查重點：

```text
[ ] Name：需符合平台命名規則，避免空白、特殊字元與重名
[ ] Type：需與 FanSensor / entity-manager schema 支援的 Type 一致
[ ] Pwm：需對應控制該風扇的 PWM channel
[ ] Tachs / Index：需對應 hwmon fanN_input 或 driver channel mapping
[ ] Thresholds：風扇 tach 通常以 lower threshold 為主
[ ] PowerState：系統風扇多為 AlwaysOn；host-only 風扇可能需依 chassis / host state gating
[ ] PollInterval：建議 500～1000 ms，需與控制迴路反應時間協調
```

##### 12.8.8 Fan Presence / Fan Monitor / PID Control 整合

`phosphor-fan-presence` 可用於更新 fan inventory object 上的 `xyz.openbmc_project.Inventory.Item.Present`。常見偵測方式包含：

```text
Tach-based：依 fan_tach sensor 是否存在且 RPM 合理判斷
GPIO-based：依 presence pin、CPLD GPIO 或 connector detect 判斷
Fallback / mixed：多種方式擇一或組合判斷
```

現代 phosphor-fan-presence 常見 runtime JSON 設定檔位置包含：

```text
/usr/share/phosphor-fan-presence/presence/config.json
/etc/phosphor-fan-presence/presence/config.json   # 測試覆寫用
/usr/share/phosphor-fan-presence/presence/<compatible-name>/config.json
```

概念例：

```json
[
  {
    "name": "Fan0",
    "path": "/system/chassis/motherboard/fan0",
    "methods": [
      {
        "type": "tach",
        "sensors": ["Fan0_Tach"]
      }
    ]
  },
  {
    "name": "Fan1",
    "path": "/system/chassis/motherboard/fan1",
    "methods": [
      {
        "type": "gpio",
        "key": 123,
        "physpath": "/sys/devices/platform/fan1_presence"
      }
    ]
  }
]
```

Fan monitor 常用於判斷 fan functional 狀態，例如 fan presence = true 但 tach = 0、目標 PWM 很高但 RPM 無法上升、雙轉子風扇其中一顆 rotor 失效。Presence 與 Functional 應分開定義：absent 不等同 failed，present 也不代表 rotor 正常。

`phosphor-pid-control` 或平台風扇控制服務會讀取溫度 sensor 與 fan tach sensor，再輸出 PWM target。整合時需確認 PWM sensor path 與 fan tach sensor path 對應正確、zone 設定包含該風扇、fan fail policy 已定義，例如任一 rotor fail 時進入 failsafe PWM。

##### 12.8.9 啟動服務與 D-Bus 驗證

先找出實際服務名稱：

```bash
systemctl list-units '*Fan*' --no-pager
systemctl list-units '*fan*' --no-pager
systemctl list-units '*sensor*' --no-pager
```

重啟與看 log：

```bash
systemctl restart xyz.openbmc_project.FanSensor.service
journalctl -u xyz.openbmc_project.FanSensor.service -b --no-pager | tail -100
journalctl -b --no-pager | grep -Ei 'fansensor|fan tach|fan_tach|tach|pwm|presence|fan-monitor'
```

確認 D-Bus object：

```bash
busctl tree xyz.openbmc_project.FanSensor
busctl tree /xyz/openbmc_project/sensors/fan_tach
```

讀取 RPM：

```bash
busctl get-property \
  xyz.openbmc_project.FanSensor \
  /xyz/openbmc_project/sensors/fan_tach/Fan0_Tach \
  xyz.openbmc_project.Sensor.Value \
  Value
```

若 service owner 不確定：

```bash
busctl call xyz.openbmc_project.ObjectMapper \
  /xyz/openbmc_project/object_mapper \
  xyz.openbmc_project.ObjectMapper GetObject \
  sas \
  /xyz/openbmc_project/sensors/fan_tach/Fan0_Tach \
  0
```

確認 inventory presence：

```bash
busctl get-property \
  xyz.openbmc_project.Inventory.Manager \
  /system/chassis/motherboard/fan0 \
  xyz.openbmc_project.Inventory.Item \
  Present
```

##### 12.8.10 Redfish / IPMI / Event 驗證

```bash
curl -k -u root:<password> \
  https://<bmc-ip>/redfish/v1/Chassis/<chassis>/Sensors | jq

curl -k -u root:<password> \
  https://<bmc-ip>/redfish/v1/Chassis/<chassis>/Sensors/Fan0_Tach | jq

curl -k -u root:<password> \
  https://<bmc-ip>/redfish/v1/Chassis/<chassis>/Thermal | jq

ipmitool sensor | grep -Ei 'fan|tach|rpm'
ipmitool sdr elist | grep -Ei 'fan|tach|rpm'
```

Event / alarm：

```bash
journalctl -b --no-pager | grep -Ei 'Fan0_Tach|fan|tach|threshold|critical|warning'

curl -k -u root:<password> \
  https://<bmc-ip>/redfish/v1/Systems/system/LogServices/EventLog/Entries | jq
```

驗證重點：

```text
[ ] Redfish sensor Reading 與 D-Bus Value 一致
[ ] ReadingUnits 為 RPM 或可清楚表示 fan speed
[ ] IPMI sensor type、unit 與 threshold 合理
[ ] fan absent 時 Redfish / IPMI 狀態符合平台政策
[ ] lower critical 觸發時 D-Bus alarm flag 與事件 log 同步產生
```

##### 12.8.11 進階除錯與常見陷阱

| 問題現象 | 可能方向 | 排查 / 處理方式 |
| :--- | :--- | :--- |
| `fan*_input` 不存在 | DTS 未啟用、driver 未載入、hwmon device 未建立、tach channel 未宣告 | 查 `dmesg`、kernel config、pinctrl、DTS compatible、fan child node |
| `fan*_input` 為 0 | 風扇未轉、PWM = 0、風扇沒供電、tach pin 接錯、PPR / divisor 不合理 | 先手動提高 PWM，確認風扇供電，再用示波器看 tach |
| RPM 為預期 2 倍或 1/2 | PPR 設錯 | 用示波器算頻率，套 `RPM = Hz × 60 / PPR` 回推 |
| RPM 偶發跳到極大值 | tach 毛刺、pull-up 過弱或過強、線材雜訊、divisor 太小 | 檢查波形、調整 fan divisor / sample、改善走線與濾波 |
| RPM 反應很慢 | sample window 太長、daemon poll 太慢、風扇慣性 | 區分 driver 更新率與 D-Bus poll interval，調整 PollInterval |
| PWM 改變但 RPM 不變 | PWM channel 對錯風扇、風扇固定全速、PWM polarity 錯、fan controller 接管 | 比對 schematic，逐一改 PWM 並觀察對應風扇 |
| 某一顆雙轉子風扇只看到一個 tach | DTS 只宣告一個 tach channel、Tachs JSON 只填一個 Index | 檢查 fan module pinout、tach-ch list、Entity Manager Tachs |
| fan_tach D-Bus object 未出現 | Entity Manager Type / Index 不符合 FanSensor 預期 | 查 FanSensor log、Entity Manager log、ObjectMapper |
| Presence=false 但 RPM 有值 | presence path / config 錯、GPIO polarity 錯、inventory path 不一致 | 比對 presence config sensor name、GPIO active state、inventory path |
| Presence=true 但 RPM=0 | 風扇插入但停止、tach pin 斷線、presence pin 無法代表 rotor OK | 區分 presence 與 functional，讓 monitor 負責 rotor fail |
| Redfish 顯示 N/A | bmcweb sensor mapping、association 或 D-Bus path 不完整 | 確認 sensor path、association、bmcweb log |
| 低轉速門檻誤觸發 | boot 初期風扇尚未啟動、host off policy、MinPwm 太低 | 加入 power state gating、啟動延遲、合理 MinPwm 與 hysteresis |
| Fan fail 後沒有 failsafe | fan monitor / PID policy 未接到該 sensor | 查 PID zone、fan monitor config、failsafe event |

##### 12.8.12 Fan Tach Sensor Porting 驗收 Checklist

硬體設計階段：

```text
[ ] 風扇型號與規格書確認：PPR、Max RPM、Min RPM、PWM 頻率、PWM duty 定義
[ ] Tach 電氣型態確認：open-drain / push-pull、pull-up 電壓、pull-up 阻值
[ ] Tach pin 到 BMC Tach channel 的 schematic 對照確認
[ ] PWM pin 到風扇 PWM input 的 schematic 對照確認
[ ] 是否經 CPLD / buffer / mux / level shifter，enable 條件已確認
[ ] Presence pin / Fault pin / FRU EEPROM 是否存在及其 owner 確認
[ ] 單風扇或雙轉子風扇、tach 數量確認
[ ] Lower warning / lower critical RPM 門檻與 thermal policy 確認
```

Device Tree / Kernel：

```text
[ ] PWM/Tach controller node status = "okay"
[ ] compatible、reg、clocks、resets、#pwm-cells 與 SoC binding 對齊
[ ] pinctrl 包含所有使用的 PWM 與 Tach pin，且無 pinmux 衝突
[ ] fan child node 已加入，pwms 與 tach-ch 正確
[ ] PPR 欄位已依 driver binding 設定，例如 pulses-per-revolution / fan-ppr
[ ] 必要 kernel config 啟用：HWMON、PWM、pwm-fan、SoC PWM/Tach driver
[ ] dmesg 無 probe failure、pinctrl failure、invalid channel 相關錯誤
[ ] /sys/class/hwmon/hwmonX/fan*_input 存在
[ ] 手動調整 PWM 時 RPM 會合理變化
[ ] 使用示波器或轉速計比對 RPM，誤差在工程可接受範圍內
```

Entity Manager / Userspace：

```text
[ ] Fan / Tach JSON 已加入正確 layer 並進 image
[ ] Type 與 FanSensor 支援 schema 一致
[ ] Pwm、Tachs、Index 與 DTS / hwmon channel mapping 一致
[ ] 雙轉子風扇已建立兩個 tach sensor 或符合平台命名規則
[ ] PollInterval 設定合理，常見建議 500～1000 ms
[ ] Thresholds 設定完成，以 lower warning / lower critical 為主
[ ] PowerState gating 符合平台狀態，例如 AlwaysOn、On、ChassisOn
[ ] phosphor-fan-presence config 中 sensor 名稱與 D-Bus sensor name 一致
[ ] fan monitor / PID config 有納入該 fan tach sensor
```

D-Bus / Redfish / IPMI / Event：

```text
[ ] FanSensor service 啟動無錯誤
[ ] ObjectMapper 可找到 /xyz/openbmc_project/sensors/fan_tach/<Name>
[ ] busctl get-property 可讀取 Value，單位以 RPM 檢查合理
[ ] Threshold interfaces 與 alarm properties 存在
[ ] Redfish Sensors 或 Thermal 可查到該 fan tach sensor
[ ] IPMI SDR / sensor list 依平台需求可查到 fan sensor
[ ] 手動降低 PWM 或停止風扇時，RPM 會下降並觸發 lower threshold
[ ] threshold 觸發時，D-Bus alarm flag、phosphor-logging、SEL / EventLog 符合預期
[ ] presence 狀態正確反映風扇插入 / 拔除
[ ] fan fail 時 failsafe PWM / thermal policy / shutdown policy 符合平台需求
```

##### 12.8.13 Fan Tach Sensor 資料表範本

| Fan Name | Rotor / Tach Name | PWM Channel | Tach Channel | PPR | hwmon input | D-Bus Path | Max RPM | Lower Warning | Lower Critical | Presence Method | 備註 |
| --- | --- | ---: | ---: | ---: | --- | --- | ---: | ---: | ---: | --- | --- |
| Fan0 | Fan0_Tach | 0 | 0 | 2 | fan1_input | /xyz/openbmc_project/sensors/fan_tach/Fan0_Tach | [待填] | [待填] | [待填] | Tach / GPIO | [待填] |
| Fan1 | Fan1_Front_Rotor | 1 | 1 | 2 | fan2_input | /xyz/openbmc_project/sensors/fan_tach/Fan1_Front_Rotor | [待填] | [待填] | [待填] | Tach / GPIO | dual rotor |
| Fan1 | Fan1_Rear_Rotor | 1 | 2 | 2 | fan3_input | /xyz/openbmc_project/sensors/fan_tach/Fan1_Rear_Rotor | [待填] | [待填] | [待填] | Tach / GPIO | dual rotor |

##### 12.8.14 本節參考資料

- Linux kernel `pwm-fan` 文件：`pwm-fan` 以 generic PWM interface 驅動風扇，透過 hwmon sysfs 暴露 `fan1_input`、`pwm1_enable` 與 `pwm1`；`fan1_input` 代表 fan tachometer speed in RPM。
- Linux kernel `pwm-fan` Device Tree binding：`compatible = "pwm-fan"`，`pwms` 為必要欄位；`pulses-per-revolution` 用來定義每轉脈衝數，範圍 1～4，預設為 2。
- Linux kernel ASPEED G6 PWM/Tach binding：AST2600 PWM controller 可支援最多 16 個 PWM outputs，Fan Tacho controller 可支援最多 16 個 fan tach input，兩者為獨立硬體區塊；fan child node 需描述 `tach-ch` 與 `pwms`。
- OpenBMC dbus-sensors README：sensor daemon 可從 hwmon、D-Bus 或 direct driver access 讀取感測資料，並以 `/xyz/openbmc_project/sensors/<type>/<sensor_name>` 發佈 D-Bus object。
- OpenBMC phosphor-fan-presence 文件：fan presence detection 透過設定檔更新 fan inventory object 的 `Present` property；目前常見 runtime JSON 設定檔位置包含 `/usr/share/phosphor-fan-presence/presence/config.json` 與 `/etc/phosphor-fan-presence/presence/config.json`。

#### 12.9 Fan PWM / Fan Control

##### 12.9.1 適用情境

Fan PWM（Pulse Width Modulation）用於控制散熱風扇的轉速，是 OpenBMC 熱管理系統中的輸出端。Fan Tach Sensor 負責回報實際 RPM，Fan PWM 則負責把控制器計算出的目標 duty 或目標轉速轉成硬體輸出訊號。兩者常一起出現在同一個風扇模組，但在 bring-up、DTS、JSON 與除錯時必須分開檢查。

常見應用場景包含：

```text
依溫度感測器動態調整風扇轉速
工廠測試、維修模式、熱流測試時固定 PWM
Thermal Policy / PID / Stepwise 風扇控制
風扇失效或溫度 sensor 失效時進入 failsafe PWM
開機預設轉速設定，避免 BMC 服務尚未啟動前風扇停止
風扇冗餘管理，例如單一風扇失效時提高同 zone 其他風扇轉速
電源狀態切換，例如 host off / standby / chassis on 的不同風扇策略
聲學目標與功耗最佳化，例如 idle 低轉速、stress 提高轉速
```

在 OpenBMC 中，PWM 不一定只以一般 numeric sensor 呈現。常見呈現方式包含：

```text
/xyz/openbmc_project/sensors/fan_pwm/<Name>
/xyz/openbmc_project/control/fanpwm/<Name>
/xyz/openbmc_project/sensors/fan_tach/<Name> 上的 Control.FanPwm interface
```

實際 path 與 interface 會受 OpenBMC branch、dbus-sensors、phosphor-hwmon、phosphor-fan-control、phosphor-pid-control 與平台 JSON/YAML 設定影響。Porting 時建議不要只記 `Fan0`，而是同時記錄：

```text
Fan inventory path
Fan Tach D-Bus path
Fan PWM D-Bus path
sysfs pwmN path
sysfs fanN_input path
控制服務名稱與 zone id
```

##### 12.9.2 資料路徑

Fan PWM / Fan Control 的典型資料流如下：

```text
Temperature / Margin / Power / Host telemetry sensors
    ↓
phosphor-pid-control / phosphor-fan-control / platform fan control daemon
    ↓
Zone policy：PID、Stepwise、fixed table、failsafe、manual override
    ↓
D-Bus control interface：Control.FanPwm 或 Control.FanSpeed
    ↓
FanSensor / PwmSensor / phosphor-hwmon / platform daemon
    ↓
sysfs：/sys/class/hwmon/hwmonX/pwmN 或 driver-specific pwm path
    ↓
Linux PWM driver：pwm-fan、ASPEED PWM/Tach、SoC PWM、I2C fan controller
    ↓
PWM pin / fan controller IC / power stage
    ↓
Fan motor speed changes
    ↓
Fan Tach 回授 RPM
```

依控制方式可分為兩種：

```text
PWM target control：控制器直接輸出 0～255 或 0～100% 類型的 PWM 值
RPM target control：控制器輸出目標 RPM，下一層 fan controller 再調整 PWM 以追 RPM
```

PWM target control 較直觀，常見於 BMC 直接接風扇 PWM 線的系統。RPM target control 則適合有硬體 fan controller IC 或平台軟體已建立內層 fan PID 的系統。兩者不可混用：若上層輸出 6000（原意 RPM）但下層當成 PWM raw value，通常會被 clamp 到最大值；若上層輸出 128（原意 PWM）但下層當成 RPM，風扇可能維持極低轉速或被判定異常。

##### 12.9.3 關鍵硬體參數

Porting 前需從 schematic、layout、風扇規格書、CPLD register map、power sequence 與 thermal requirement 取得下列資訊：

```text
[ ] 風扇型號、料號、風扇規格書版本
[ ] PWM 訊號電壓準位：3.3V / 5V / open-drain / push-pull / level shifted
[ ] PWM input 是否需要 pull-up、pull-down 或 series resistor
[ ] PWM 頻率範圍：常見 25 kHz，但需以風扇規格書為準
[ ] PWM duty range：0～100%、20～100%、30～100% 或 vendor-defined
[ ] PWM polarity：高 duty 轉速增加 / 反相 / 訊號斷線時全速
[ ] 最小啟動 duty：風扇從停止到開始轉動所需 duty
[ ] 最小穩定 duty：風扇已轉動後可維持不停止的 duty
[ ] 全速 duty：通常 100% 或 raw 255
[ ] 停止 duty：0% 是否真的停止，或風扇是否有內建最低轉速
[ ] PWM channel：PWM0 / PWM1 / ... 到 fan connector 的對照
[ ] Tach channel：用於驗證 PWM 效果的回授 sensor
[ ] 風扇供電 rail：12V / 5V 是否受 BMC、CPLD 或 host state 控制
[ ] 風扇模組是否一個 PWM 控多個 rotors
[ ] 風扇 fail 後的硬體預設：PWM floating、BMC reset、CPLD failsafe 時是否全速
```

###### 12.9.3.1 PWM 週期與頻率換算

Device Tree 中常用 period 表示 PWM 週期，單位通常是 ns：

```text
Frequency_Hz = 1,000,000,000 / Period_ns
Period_ns = 1,000,000,000 / Frequency_Hz
```

常見例：

```text
25 kHz → 40,000 ns
20 kHz → 50,000 ns
10 kHz → 100,000 ns
30 kHz → 33,333 ns
```

若風扇規格書建議 25 kHz，DTS 設為 `40000` ns 是常見起點。若出現低 duty 無法轉、噪音異常、轉速曲線不連續或 PWM duty 改變但 RPM 不明顯，需與硬體團隊確認實際 pin 波形與風扇接收頻率。

###### 12.9.3.2 raw PWM、百分比與 RPM

常見層級：

```text
sysfs pwmN：常見 raw 0～255，255 代表最大 duty
D-Bus fan_pwm Sensor.Value：部分實作顯示百分比 0～100
Control.FanPwm.Target：常見 raw target 0～255
phosphor-pid-control failsafePercent：語意為百分比，實際寫入需看 fan sensor scaling
FanSpeed.Target：語意為 RPM
```

建議資料表同時記錄 raw PWM 與百分比：

```text
PWM_percent = raw_pwm / 255 × 100
raw_pwm = round(PWM_percent × 255 / 100)
```

例：

```text
raw 30  ≈ 11.8%
raw 64  ≈ 25.1%
raw 128 ≈ 50.2%
raw 192 ≈ 75.3%
raw 255 = 100%
```

##### 12.9.4 常見控制架構

| 架構 | 輸出目標 | 寫入路徑 | 使用場景 | 注意事項 |
| :--- | :--- | :--- | :--- | :--- |
| SoC PWM 直接控風扇 | raw PWM / % | hwmon `pwmN` | BMC PWM pin 直接連 fan PWM input | 需確認 polarity、period、pinctrl、failsafe 預設 |
| `pwm-fan` | raw 0～255 | hwmon `pwm1` | generic Linux PWM fan | `pwm1_enable` mode 影響 `pwm1=0` 時行為 |
| ASPEED PWM/Tach | raw 0～255 | hwmon or driver path | AST2600 常見 | PWM 與 Tach 獨立；需對 channel |
| I2C fan controller | RPM 或 PWM | I2C register / hwmon | MAX31785 / MAX31790 / NCT 類 | 控制 IC 可能有內建閉環與 fault rule |
| phosphor-pid-control → sysfs | raw PWM 或 RPM | `writePath` | 使用 swampd 控制 zone | `readPath` / `writePath` 與 scaling 必須對齊 |
| phosphor-fan-control | FanSpeed / FanPWM | control path | fan presence/control/monitor stack | target_interface 與 target_path 需一致 |
| PSU fan | PSU command / PMBus | PSUSensor / PSU daemon | PSU 內建風扇 | 可能不是 chassis FanSensor，且尺度可能 0～100 |

##### 12.9.5 Porting 步驟 A：Device Tree / Kernel

###### Step A1：啟用 PWM controller 與 pinctrl

AST2600 / ASPEED G6 常見 PWM/Tach controller 節點：

```dts
&pwm_tach {
    status = "okay";
    pinctrl-names = "default";
    pinctrl-0 = <&pinctrl_pwm0_default &pinctrl_pwm1_default
                 &pinctrl_tach0_default &pinctrl_tach1_default>;
};
```

若 fan child node 同時描述 PWM 與 Tach：

```dts
&pwm_tach {
    status = "okay";
    pinctrl-names = "default";
    pinctrl-0 = <&pinctrl_pwm0_default &pinctrl_pwm1_default
                 &pinctrl_tach0_default &pinctrl_tach1_default>;

    fan-0 {
        tach-ch = /bits/ 8 <0x0>;
        pwms = <&pwm_tach 0 40000 0>;
    };

    fan-1 {
        tach-ch = /bits/ 8 <0x1>;
        pwms = <&pwm_tach 1 40000 0>;
    };
};
```

`pwms = <&pwm_tach 0 40000 0>` 的典型含意：

```text
&pwm_tach：PWM provider
0        ：PWM channel 0
40000    ：period = 40000 ns = 25 kHz
0        ：PWM flags，例如 normal polarity；反相需依 binding / driver 定義
```

###### Step A2：generic `pwm-fan` DTS 範例

若採 generic `pwm-fan`：

```dts
fan0: pwm-fan {
    compatible = "pwm-fan";
    pwms = <&pwm_tach 0 40000 0>;
    cooling-levels = <0 64 128 192 255>;
    #cooling-cells = <2>;
};
```

若同時接 tach interrupt：

```dts
fan0: pwm-fan {
    compatible = "pwm-fan";
    pwms = <&pwm 0 40000 0>;
    interrupts-extended = <&gpio5 1 IRQ_TYPE_EDGE_FALLING>;
    pulses-per-revolution = <2>;
    cooling-levels = <0 80 120 160 200 255>;
    #cooling-cells = <2>;
};
```

###### Step A3：Kernel config

```text
CONFIG_HWMON
CONFIG_PWM
CONFIG_SENSORS_PWM_FAN
CONFIG_PWM_ASPEED 或 SoC 對應 PWM driver
CONFIG_SENSORS_ASPEED_G6_PWM_TACH 或 vendor BSP 對應 ASPEED PWM/Tach driver
CONFIG_THERMAL（若使用 cooling-levels / thermal zone）
CONFIG_REGULATOR（若 fan-supply 由 regulator 控制）
```

###### Step A4：開機 probe 檢查

```bash
dmesg | grep -Ei 'pwm|fan|tach|hwmon|aspeed|npcm'

cat /sys/kernel/debug/pinctrl/*/pinmux-pins 2>/dev/null | grep -Ei 'pwm|tach|fan'

for h in /sys/class/hwmon/hwmon*; do
    echo "== $h =="
    cat "$h/name" 2>/dev/null || true
    for f in "$h"/pwm* "$h"/fan*_input "$h"/fan*_label; do
        [ -e "$f" ] && echo "$(basename "$f")=$(cat "$f")"
    done
done
```

##### 12.9.6 Porting 步驟 B：sysfs PWM 驗證

###### Step B1：找出 PWM 節點

```bash
find /sys/class/hwmon -maxdepth 2 -name 'pwm*' -print

for h in /sys/class/hwmon/hwmon*; do
    echo "== $h =="
    cat "$h/name" 2>/dev/null || true
    ls "$h"/pwm* 2>/dev/null || true
done
```

常見節點：

```text
pwm1
pwm1_enable
pwm1_auto_point1_pwm
pwm1_auto_point1_temp
```

不同 driver 的 `pwm1_enable` 語意可能不同。generic `pwm-fan` 文件中，`pwm1` 是 0～255，`255` 代表最大轉速；`pwm1_enable` 會影響 `pwm1=0` 時 PWM 與 regulator 的保留或關閉行為。實機測試前需先看當前 driver 文件與 sysfs 說明。

###### Step B2：安全手動測試

測試前建議：

```text
[ ] 確認可安全降低風扇轉速，避免 CPU / GPU / VR / DIMM 過熱
[ ] 確認有序列埠或 SSH session 可恢復控制
[ ] 準備回復全速指令
[ ] 若 host 正在高負載，先停止 stress test 或固定 failsafe
```

手動測試：

```bash
H=/sys/class/hwmon/hwmonX

# 記錄初始值
cat $H/name
cat $H/pwm1 2>/dev/null || true
cat $H/pwm1_enable 2>/dev/null || true
cat $H/fan1_input 2>/dev/null || true

# 視 driver 支援情況切到可由 pwm1 控制的模式
# 注意：pwm1_enable 值語意依 driver 而異，請先確認文件
echo 1 > $H/pwm1_enable 2>/dev/null || true

# 測試 duty 與 RPM 對應
for v in 64 128 192 255; do
    echo $v > $H/pwm1
    sleep 5
    echo "raw_pwm=$v rpm=$(cat $H/fan1_input 2>/dev/null || echo NA)"
done

# 回到安全值
echo 255 > $H/pwm1
```

測試記錄表：

| PWM raw | PWM % | RPM | Tach sensor | 溫度 | 備註 |
| ---: | ---: | ---: | --- | ---: | --- |
| 64 | 25.1 | [待填] | [待填] | [待填] | [待填] |
| 128 | 50.2 | [待填] | [待填] | [待填] | [待填] |
| 192 | 75.3 | [待填] | [待填] | [待填] | [待填] |
| 255 | 100.0 | [待填] | [待填] | [待填] | [待填] |

##### 12.9.7 Entity Manager / FanSensor / PwmSensor 配置

OpenBMC branch 與平台 layer 對 fan JSON 欄位差異較大，下列範例作為 porting 記錄範本。實際欄位需以 `entity-manager` schema、`dbus-sensors` FanSensor / PwmSensor source、既有平台 JSON 與 journal log 為準。

###### SoC PWM + Tach 風扇範例

```json
{
  "Name": "Fan0",
  "Type": "AspeedFan",
  "Pwm": 0,
  "Tachs": [
    {
      "Name": "Fan0_Tach",
      "Index": 0
    }
  ],
  "PwmName": "Fan0_PWM",
  "MaxPwm": 255,
  "MinPwm": 30,
  "PollInterval": 1000,
  "PowerState": "AlwaysOn",
  "Thresholds": [
    {
      "Name": "lower critical",
      "Direction": "less than",
      "Severity": 1,
      "Value": 500
    }
  ]
}
```

###### I2C fan controller 範例

```json
{
  "Type": "I2CFan",
  "Name": "FCB_FAN0_TACH",
  "Bus": 18,
  "Address": "0x23",
  "Index": 11,
  "Connector": {
    "Name": "FCB_FAN0_PWM",
    "Pwm": 0,
    "PwmName": "FCB_FAN0_PWM_PCT",
    "Tachs": [11]
  },
  "MaxReading": 25000,
  "PowerState": "AlwaysOn"
}
```

###### 純 PWM control object 範例

若平台將 PWM 視為 `fan_pwm` control object，而 tach sensor 另行建立：

```json
{
  "Name": "Fan0_PWM",
  "Type": "PwmSensor",
  "Index": 0,
  "MaxValue": 255,
  "MinValue": 0,
  "DefaultValue": 80,
  "PowerState": "AlwaysOn"
}
```

欄位檢查：

```text
[ ] Type 與 schema / daemon 支援型別一致
[ ] Pwm / Index 對應到 sysfs pwmN 與硬體 PWM channel
[ ] PwmName 對應 D-Bus fan_pwm object name
[ ] MinPwm 大於或等於風扇最低啟動需求
[ ] MaxPwm 符合 raw scale，系統 fan 常見 255，PSU fan 可能是 100
[ ] Tachs 對應 fan_tach sensor，方便用 RPM 驗證 PWM 效果
[ ] PowerState 與風扇供電 rail 一致
```

##### 12.9.8 D-Bus FanPwm / FanSpeed 介面驗證

OpenBMC 常見 fan control interface：

```text
xyz.openbmc_project.Control.FanPwm：Target 屬性常用於 PWM raw target
xyz.openbmc_project.Control.FanPWM：部分文件或舊設定以全大寫 PWM 命名，需以實機 introspect 為準
xyz.openbmc_project.Control.FanSpeed：Target 屬性常用於 RPM target
xyz.openbmc_project.Sensor.Value：部分 fan_pwm object 會以百分比顯示 Value
```

查找 fan PWM object：

```bash
busctl tree /xyz/openbmc_project | grep -Ei 'fan_pwm|fanpwm|pwm'

busctl tree xyz.openbmc_project.FanSensor 2>/dev/null | grep -Ei 'pwm|fan'
```

讀取與設定：

```bash
# 找出 service owner
busctl call xyz.openbmc_project.ObjectMapper \
  /xyz/openbmc_project/object_mapper \
  xyz.openbmc_project.ObjectMapper GetObject \
  sas \
  /xyz/openbmc_project/sensors/fan_pwm/Fan0_PWM \
  0

# 檢查 interface
busctl introspect <service_name> \
  /xyz/openbmc_project/sensors/fan_pwm/Fan0_PWM

# 設定 raw PWM target，signature 可能是 t 或 q，需以 introspect 為準
busctl set-property \
  <service_name> \
  /xyz/openbmc_project/sensors/fan_pwm/Fan0_PWM \
  xyz.openbmc_project.Control.FanPwm \
  Target t 128

# 讀回 Target
busctl get-property \
  <service_name> \
  /xyz/openbmc_project/sensors/fan_pwm/Fan0_PWM \
  xyz.openbmc_project.Control.FanPwm \
  Target
```

驗證順序：

```text
D-Bus Target 變更
    ↓
sysfs pwmN 變更
    ↓
PWM pin 波形 duty 改變
    ↓
風扇 RPM 變化
    ↓
fan_tach D-Bus Value 變化
```

##### 12.9.9 Thermal Policy：PID / Stepwise / Fan Control

###### 12.9.9.1 phosphor-pid-control JSON

`phosphor-pid-control` 可從 dedicated JSON 或 D-Bus 取得設定。常見 JSON 位置為：

```text
/usr/share/swampd/config.json
```

fan sensor 以 `readPath` 讀 fan tach，以 `writePath` 寫 PWM：

```json
{
  "sensors": [
    {
      "name": "fan0",
      "type": "fan",
      "readPath": "/xyz/openbmc_project/sensors/fan_tach/Fan0_Tach",
      "writePath": "/sys/class/hwmon/hwmon*/pwm1",
      "min": 0,
      "max": 255,
      "timeout": 4,
      "ignoreDbusMinMax": true,
      "unavailableAsFailed": true
    },
    {
      "name": "Ambient_Temp",
      "type": "temp",
      "readPath": "/xyz/openbmc_project/sensors/temperature/Ambient_Temp",
      "timeout": 5,
      "unavailableAsFailed": true
    }
  ],
  "zones": [
    {
      "id": 0,
      "minThermalOutput": 30.0,
      "failsafePercent": 100.0,
      "pids": ["fan0", "Ambient_Temp"]
    }
  ]
}
```

注意：`minThermalOutput` 在某些配置中常以最小 RPM 使用；若 fan controller 的輸出是 PWM percentage 或 raw PWM，需確認該值的語意和下層 scaling。`failsafePercent` 是 zone 進入 fail-safe 時用來寫 fan sensor 的值，常見策略為 100% 或全速。

###### 12.9.9.2 PID 參數與控制模式

常見控制策略：

```text
Stepwise：依溫度區間查表輸出 PWM 或 RPM，調校簡單、可預期性高
PID：依誤差、積分、微分與 feed-forward 調整，適合需要平滑控制的系統
Fan PID：追目標 RPM，輸出 PWM
Thermal PID：依溫度或 margin 產生目標 fan output
Open loop：只看溫度輸出 PWM，不看 tach 回授
Closed loop：比較目標 RPM 與實際 RPM，再調 PWM
```

調校時建議先完成下列資料：

```text
[ ] PWM raw → RPM 曲線
[ ] 溫度 sensor 位置、熱慣性與有效冷卻 fan zone
[ ] fan fail 時 failsafe PWM
[ ] acoustic target 與 idle 最低轉速
[ ] stress test 下 steady state 溫度
[ ] step up / step down 斜率限制，避免轉速忽高忽低
```

###### 12.9.9.3 phosphor-fan-control fans.json / zones

phosphor-fan-presence / fan-control 文件中，fan control 可指定 target interface：

```json
[
  {
    "name": "fan0",
    "zone": "0",
    "sensors": ["Fan0_Tach"],
    "target_interface": "xyz.openbmc_project.Control.FanPWM",
    "target_path": "/xyz/openbmc_project/control/fanpwm/"
  }
]
```

RPM 控制則可使用：

```json
[
  {
    "name": "fan0",
    "zone": "0",
    "sensors": ["Fan0_Tach"],
    "target_interface": "xyz.openbmc_project.Control.FanSpeed",
    "target_path": "/xyz/openbmc_project/sensors/fan_tach/"
  }
]
```

實機上要以 `busctl introspect` 確認 casing 與 path，例如 `FanPWM`、`FanPwm`、`fanpwm` 可能在不同元件或版本中有差異。

##### 12.9.10 Failsafe 與開機預設

Fan PWM 的 failsafe 設計需要覆蓋下列階段：

```text
BMC reset / BootROM / U-Boot 階段
Kernel probe 前
Kernel driver probe 後但 userspace service 未啟動
FanSensor / PwmSensor 啟動後
PID / fan-control 啟動後
PID service 停止、重啟或 reload configuration
溫度 sensor unavailable / fan tach unavailable / inventory absent
BMC kernel panic 或 watchdog reset
```

建議策略：

```text
[ ] 硬體預設：PWM floating 或 BMC reset 時風扇全速或安全轉速
[ ] Bootloader：若可控，維持安全 PWM，不依賴 userspace
[ ] Kernel driver：probe 後不要把 PWM 變成 0，或設定 default PWM
[ ] FanSensor / PwmSensor：當目前 PWM 為 0 時可設 default PWM
[ ] PID：sensor fail 或 zone fail-safe 時設 failsafePercent
[ ] offline failsafe：PID offline 或 service stop 時 fan 保持安全 PWM
[ ] strict failsafe：進入 fail-safe 時是否固定為 failsafePercent，或取 calculated PWM 與 failsafe 較高者
```

驗證項目：

```bash
# 觀察服務停止後是否進入安全 PWM
systemctl stop phosphor-pid-control.service
sleep 5
cat /sys/class/hwmon/hwmonX/pwm1
cat /sys/class/hwmon/hwmonX/fan1_input

# 恢復服務
systemctl start phosphor-pid-control.service
journalctl -u phosphor-pid-control.service -b --no-pager | tail -100
```

##### 12.9.11 Redfish / IPMI / Telemetry 驗證

Fan PWM 不一定會在 Redfish `Thermal` 或 `Sensors` 中呈現；許多平台只呈現 fan tach RPM，不呈現 PWM duty。若平台需求要顯示 PWM，需確認 bmcweb sensor mapping、sensor type、D-Bus path 與 association。

```bash
curl -k -u root:<password> \
  https://<bmc-ip>/redfish/v1/Chassis/<chassis>/Sensors | jq

curl -k -u root:<password> \
  https://<bmc-ip>/redfish/v1/Chassis/<chassis>/Thermal | jq

ipmitool sensor | grep -Ei 'fan|pwm|tach|rpm'
ipmitool sdr elist | grep -Ei 'fan|pwm|tach|rpm'
```

Telemetry / log 建議保存：

```text
[ ] PWM target
[ ] sysfs pwmN
[ ] fan tach RPM
[ ] controlling temperature / margin sensor
[ ] zone mode：auto / manual / failsafe
[ ] fan presence / functional state
[ ] service restart / fail / reload event
```

##### 12.9.12 進階除錯與常見陷阱

| 問題現象 | 可能方向 | 排查 / 處理方式 |
| :--- | :--- | :--- |
| `pwm*` sysfs 不存在 | DTS 未啟用、driver 未載入、kernel config 缺少 PWM / pwm-fan / SoC driver | 查 `dmesg`、`.config`、pinctrl、controller compatible |
| 寫入 `pwm1` 後 RPM 不變 | `pwm1_enable` 模式不對、風扇固定全速、PWM channel 對錯、PWM pin 無波形 | 先量 PWM pin，再逐一比對 fan connector 與 tach |
| 風扇無法從停止啟動 | duty 低於 start duty、供電 rail 未穩、風扇需要 start boost | 提高 MinPwm，加入啟動 boost 或開機預設全速 |
| PWM 與 RPM 不成比例 | 風扇內部控制曲線、PWM 頻率不合、tach PPR 錯、控制 IC 另有閉環 | 建 PWM→RPM 表，確認 PWM period 與 tach PPR |
| 設 0 後風扇未停 | 風扇內建最低轉速、`pwm1_enable` 保留 regulator、硬體 pull-up 導致全速 | 查風扇規格、driver 文件與 PWM pin 波形 |
| 設 255 仍非全速 | PWM polarity 反相、MaxPwm scale 不符、fan controller 限速 | 確認 flags、polarity、controller register、MaxPwm |
| D-Bus FanPwm 找不到 | PwmSensor 未建立、JSON Type / PwmName 不符合、service 未啟動 | 查 FanSensor log、ObjectMapper、Entity Manager log |
| 手動設定後很快被覆寫 | PID / fan-control 正在 auto mode | 切明確 manual mode、停止控制服務或使用平台提供的 override flow |
| 風扇長期全速 | failsafe 被觸發、溫度 sensor unavailable、fan tach timeout、zone mode 在 fail-safe | 查 phosphor-pid-control log、zone mode、failed sensors |
| 服務啟動時風扇短暫降到 0 | default PWM 不足、service 順序、driver probe 初始值為 0 | 設硬體 failsafe、kernel default、PwmSensor default、systemd dependency |
| Redfish 看不到 PWM | 平台只 expose tach，不 expose pwm | 確認需求；若需呈現，補 D-Bus sensor 與 bmcweb mapping |
| PSU fan PWM 尺度不對 | PSU fan 可能是 0～100，不是 0～255 | 查 PwmSensor scale、PSU daemon 與 PSU PMBus command |

##### 12.9.13 Fan PWM / Fan Control Porting 驗收 Checklist

硬體設計階段：

```text
[ ] 風扇型號與規格書確認：PWM frequency、voltage、duty range、polarity
[ ] PWM channel 與 fan connector 對照完成
[ ] Tach channel 與 PWM channel 配對完成
[ ] PWM pull-up / level shift / buffer / CPLD path 確認
[ ] 最小啟動 duty、最小穩定 duty、全速 duty 確認
[ ] 硬體 failsafe 狀態確認：BMC reset / pin floating / CPLD failsafe 時風扇狀態
[ ] host off / standby / chassis on 的風扇策略確認
```

Device Tree / Kernel：

```text
[ ] PWM controller node status = "okay"
[ ] pinctrl 包含所有 PWM pin，且無 pinmux 衝突
[ ] fan child node 或 pwm-fan node 加入，pwms channel 與 period 正確
[ ] 若使用 tach 回授，tach-ch / pulses-per-revolution 也已設定
[ ] kernel config 啟用 HWMON、PWM、pwm-fan、SoC PWM/Tach driver
[ ] dmesg 無 probe failure、invalid channel、pinctrl failure
[ ] /sys/class/hwmon/hwmonX/pwmN 存在
[ ] 手動設定 pwmN 後，示波器可看到 duty 改變
[ ] fan_tach RPM 隨 PWM 變化
```

Entity Manager / Userspace：

```text
[ ] Fan / PWM JSON 已加入正確 layer 並進 image
[ ] Type、Pwm、PwmName、Tachs / Index 與 schema 及硬體一致
[ ] MinPwm / MaxPwm / Default PWM 設定合理
[ ] PowerState gating 與風扇供電狀態一致
[ ] FanSensor / PwmSensor service 啟動無錯誤
[ ] ObjectMapper 可找到 fan_pwm 或 fan control object
[ ] Control.FanPwm / Control.FanPWM / Control.FanSpeed interface 依平台需求存在
```

Thermal Policy：

```text
[ ] phosphor-pid-control 或 fan-control 設定檔已加入 image
[ ] sensors readPath 對應 fan_tach 與 temperature sensor
[ ] fan writePath 對應 sysfs pwmN 或 D-Bus fan control path
[ ] zones id、minThermalOutput、failsafePercent、pids 設定合理
[ ] PID / Stepwise 參數已初步調校
[ ] manual / auto / failsafe mode 切換路徑已驗證
[ ] 溫度上升時 PWM 增加，溫度下降時 PWM 降低
[ ] fan fail 或 sensor fail 時進入預期 failsafe PWM
```

D-Bus / Redfish / IPMI / Event：

```text
[ ] busctl 可讀寫 Target，且 signature 與實機 introspect 一致
[ ] 設定 Target 後 sysfs pwmN 同步變化
[ ] sysfs pwmN 變化後 fan_tach RPM 同步變化
[ ] Redfish 依平台需求可看到 fan tach，若需要也可看到 fan_pwm
[ ] IPMI SDR / sensor list 依平台需求可看到 fan tach / pwm
[ ] 停止 PID service、拔除風扇、temperature sensor unavailable 等情境都有預期 log
[ ] SEL / Journal / EventLog 符合平台 event policy
```

##### 12.9.14 Fan PWM / Fan Control 資料表範本

| Fan Name | PWM Channel | PWM Path | PWM Period / Hz | MinPwm | MaxPwm | Default / Failsafe | Tach Sensor | Control Path | Zone | 備註 |
| --- | ---: | --- | --- | ---: | ---: | --- | --- | --- | ---: | --- |
| Fan0 | 0 | `/sys/class/hwmon/hwmonX/pwm1` | 40000 ns / 25 kHz | 30 | 255 | 255 | Fan0_Tach | `/xyz/openbmc_project/sensors/fan_pwm/Fan0_PWM` | 0 | [待填] |
| Fan1 | 1 | `/sys/class/hwmon/hwmonX/pwm2` | 40000 ns / 25 kHz | 30 | 255 | 255 | Fan1_Tach | `/xyz/openbmc_project/sensors/fan_pwm/Fan1_PWM` | 0 | [待填] |
| PSU0_FAN | [待填] | [待填] | [待填] | [待填] | 100 | 100 | PSU0_FAN_TACH | [待填] | [待填] | PSU fan scale may be 0～100 |

##### 12.9.15 本節參考資料

- Linux kernel `pwm-fan` 文件：`pwm-fan` 使用 generic PWM interface 驅動風扇，並透過 hwmon sysfs 提供 `fan1_input`、`pwm1_enable` 與 `pwm1`；其中 `pwm1` 為 0～255，255 代表最大轉速。
- OpenBMC dbus-sensors PwmSensor 架構資料：PwmSensor 透過 sysfs `pwm*` 控制風扇，並可提供 `Sensor.Value` 百分比與 `Control.FanPwm` raw target；系統風扇常見 raw scale 為 0～255，PSU fan 可能為 0～100。
- OpenBMC phosphor-dbus-interfaces control namespace：FanPwm 提供 `Target` 屬性用於 duty cycle，FanSpeed 提供 `Target` 屬性用於 RPM target。
- OpenBMC phosphor-fan-presence fan control 文件：fan control 可使用 `xyz.openbmc_project.Control.FanSpeed` 或 `xyz.openbmc_project.Control.FanPWM` 作為 target interface。
- OpenBMC phosphor-pid-control configure 文件：設定包含 `sensors` 與 `zones`；fan sensor 可透過 `readPath` 讀取 fan tach，透過 `writePath` 寫入 PWM；zone 中 `minThermalOutput` 常用作最低 thermal output，`failsafePercent` 用於 fail-safe 輸出。

#### 12.10 PSU Sensor

##### 12.10.1 適用情境

Power Supply Unit（PSU）是伺服器系統的電源核心。現代伺服器 PSU 多數支援 PMBus over I2C/SMBus，可提供電壓、電流、功率、溫度、風扇轉速、告警、FRU / Asset 與冗餘狀態。Linux kernel 的 PMBus hwmon driver 會把支援的 PMBus command 轉成 `/sys/class/hwmon/hwmonX/` 下的標準 hwmon 屬性；OpenBMC userspace 再由 `dbus-sensors` 的 `PSUSensor` 搭配 Entity Manager 設定建立 D-Bus sensor。

常見 PSU sensor：

```text
Input voltage / Output voltage
Input current / Output current
Input power / Output power
Temperature
Fan speed
Presence
Fault status
FRU / Asset data
Redundancy status
```

常見 D-Bus path：

```text
/xyz/openbmc_project/sensors/voltage/PSU0_Input_Voltage
/xyz/openbmc_project/sensors/voltage/PSU0_Output_Voltage
/xyz/openbmc_project/sensors/current/PSU0_Input_Current
/xyz/openbmc_project/sensors/current/PSU0_Output_Current
/xyz/openbmc_project/sensors/power/PSU0_Input_Power
/xyz/openbmc_project/sensors/power/PSU0_Output_Power
/xyz/openbmc_project/sensors/temperature/PSU0_Temp
/xyz/openbmc_project/sensors/fan_tach/PSU0_Fan
```

需分清楚三種狀態：

- `Sensor.Value`：電壓、電流、功率、溫度、轉速等讀值。
- `Inventory.Item.Present`：PSU 是否插入。
- `OperationalStatus.Functional`：PSU 在存在狀態下是否健康。

Presence 與 Functional 不宜混用。拔除 PSU 通常是 `Present=false`；插著但故障時通常是 `Present=true` 且 `Functional=false` 或產生 fault / event。

##### 12.10.2 資料路徑（Data Flow）

```text
PSU / CRPS / CFFPS / Vendor PSU
    PMBus over I2C/SMBus
    ↓
Linux Kernel
    pmbus / vendor-specific pmbus driver
    ↓
/sys/class/hwmon/hwmonX/
    ├── in*_input / in*_label          voltage, mV
    ├── curr*_input / curr*_label      current, mA
    ├── power*_input / power*_label    power, µW
    ├── temp*_input / temp*_label      temperature, m°C
    ├── fan*_input                     RPM
    └── *_alarm / *_fault / *_crit / *_max / *_min
    ↓
Userspace Daemons
    ├── Entity Manager                 inventory / Exposes / sensor config
    ├── PSUSensor (dbus-sensors)       hwmon → D-Bus sensor
    ├── phosphor-power / psu monitor   presence / fault / redundancy / event
    └── phosphor-regulators            VR / regulator rail，視平台需求啟用
    ↓
D-Bus
    ├── xyz.openbmc_project.Sensor.Value
    ├── xyz.openbmc_project.Sensor.Threshold.Warning / Critical
    ├── xyz.openbmc_project.State.Decorator.Availability
    ├── xyz.openbmc_project.State.Decorator.OperationalStatus
    ├── xyz.openbmc_project.Inventory.Item
    └── xyz.openbmc_project.Inventory.Decorator.Asset
    ↓
Northbound Interfaces
    ├── Redfish: /redfish/v1/Chassis/<id>/Power
    ├── Redfish: /redfish/v1/Chassis/<id>/PowerSubsystem/PowerSupplies
    ├── Redfish: /redfish/v1/Chassis/<id>/Sensors
    └── IPMI: SDR / Sensor reading / SEL
```

Linux PMBus driver 的 hwmon 屬性只會出現硬體與 driver 判定支援的項目；若 PSU 不支援某 command，或通用 `pmbus` driver 無法安全偵測該能力，對應 sysfs 檔案可能不存在。

##### 12.10.3 常見來源分類與特性

| 來源類型 | 通訊協定 | Linux / OpenBMC 對應 | 關鍵注意事項 |
| :--- | :--- | :--- | :--- |
| 標準 PMBus PSU | PMBus over I2C/SMBus | `pmbus` driver + `PSUSensor` | 需明確建立 I2C device；確認 bus / address / page / label。 |
| 廠商專用 PSU | PMBus + vendor extension | vendor pmbus driver，例如 `ibm-cffps`、`inspur-ipsps` | 可能需要客製 command、狀態解碼、FRU 讀取方式或 fan/fault 對應。 |
| CRPS / CFFPS PSU | PMBus + FRU EEPROM / vendor commands | `pmbus` / vendor driver + phosphor-power | 需處理 presence、redundancy、AC lost、fault LED、hot-plug。 |
| PSU fan | PMBus fan command 或 PSU 內部 controller | `fan*_input` → `fan_tach` sensor | 很多 PSU fan 只回報 RPM 與 fault，不由 BMC PWM 直接控制。 |
| PSU presence | GPIO、CPLD、PMBus ACK、FRU EEPROM | phosphor-power / GPIO monitor / platform daemon | GPIO 極性、CPLD bit、I2C NACK 與真正拔除需分開判讀。 |
| PSU fault / health | PMBus `STATUS_WORD` / `STATUS_*`、GPIO fault、CPLD latch | phosphor-power / vendor daemon / event monitor | `STATUS_WORD` 通常需搭配 `STATUS_INPUT` / `STATUS_TEMPERATURE` / `STATUS_FANS` 等細項解讀。 |

##### 12.10.4 Porting 前需確認的硬體與規格資料

```text
[必填] PSU 型號、廠商、form factor（CRPS / CFFPS / 客製）
[必填] PSU 數量與 slot 編號（PSU0、PSU1、...）
[必填] I2C bus number、mux channel、7-bit address
[必填] 使用通用 pmbus driver 或 vendor-specific driver
[必填] PMBus command 支援清單：READ_VIN、READ_VOUT、READ_IIN、READ_IOUT、READ_PIN、READ_POUT、READ_TEMPERATURE、READ_FAN_SPEED、STATUS_WORD 等
[必填] PSU main output 與 standby output：12V、12VSB、48V、54V 或其他設計
[必填] Presence 偵測來源：GPIO、CPLD bit、I2C ACK、FRU EEPROM、PMBus read
[必填] Fault / AC OK / DC OK / PSU FAIL / fan fault 訊號來源與極性
[建議] FRU / Asset data 來源：EEPROM、PMBus MFR_ID / MFR_MODEL / MFR_SERIAL
[建議] 冗餘策略：1+1、N+1、N+N、cold redundancy、active/standby
[建議] Threshold：輸入電壓上下限、輸出電壓上下限、功率上限、溫度上限、fan RPM 下限
```

PMBus 常見 command 與 hwmon 對應：

| PMBus command | Command code | 常見 sysfs / label | 單位 | 說明 |
| :--- | :--- | :--- | :--- | :--- |
| `READ_VIN` | `0x88` | `inX_input`, `inX_label=vin` | mV | 輸入電壓。 |
| `READ_IIN` | `0x89` | `currX_input`, `currX_label=iin` | mA | 輸入電流。 |
| `READ_VOUT` | `0x8B` | `inX_input`, `inX_label=voutY` | mV | 輸出電壓。 |
| `READ_IOUT` | `0x8C` | `currX_input`, `currX_label=ioutY` | mA | 輸出電流。 |
| `READ_TEMPERATURE_1` | `0x8D` | `tempX_input` | m°C | PSU 內部溫度。 |
| `READ_FAN_SPEED_1` | `0x90` | `fanX_input` | RPM | PSU 內部風扇轉速。 |
| `READ_POUT` | `0x96` | `powerX_input`, `powerX_label=poutY` | µW | 輸出功率。 |
| `READ_PIN` | `0x97` | `powerX_input`, `powerX_label=pin` | µW | 輸入功率。 |
| `STATUS_WORD` | `0x79` | `*_alarm` / `*_fault` 或 vendor daemon | bit field | PSU 總狀態。 |

##### 12.10.5 I2C / PMBus 通訊驗證

```bash
i2cdetect -y 4

# READ_VIN，word read；回傳是 PMBus raw format，不建議直接把十六進位值當電壓
i2cget -y 4 0x58 0x88 w

# READ_PIN
i2cget -y 4 0x58 0x97 w

# STATUS_WORD
i2cget -y 4 0x58 0x79 w
```

注意事項：

- `i2cdetect` / `i2cget` 對某些 device 可能造成副作用；bring-up 前需確認同 bus 上 device 可接受這類 access。
- `i2cget ... w` 顯示的是 SMBus word，endianness 與 PMBus Linear-11 / Linear-16 解碼需另外處理；進入 kernel hwmon 後，driver 會轉成標準單位。
- 若 bus 上有 I2C mux，需確認 mux channel、idle disconnect 設定與 BMC service 是否會改變 mux 狀態。
- I2C NACK 不一定代表 PSU 被拔除，也可能是 AC lost、standby rail 未穩、PSU booting、bus stuck 或 CPLD gate 關閉。

##### 12.10.6 Kernel Driver 與 Device Tree

Linux PMBus driver 通常不會任意掃描所有位址來尋找 PSU，需透過 Device Tree、board file 或 runtime `new_device` 明確建立 I2C client。`i2cdetect` 看得到位址，不代表 kernel driver 已經 bind。

```dts
&i2c4 {
    status = "okay";
    clock-frequency = <100000>;

    psu0: power-supply@58 {
        compatible = "pmbus";
        reg = <0x58>;
        label = "psu0";
    };

    psu1: power-supply@59 {
        compatible = "pmbus";
        reg = <0x59>;
        label = "psu1";
    };
};
```

Kernel config 檢查：

```text
CONFIG_I2C=y
CONFIG_HWMON=y
CONFIG_PMBUS=y
CONFIG_SENSORS_PMBUS=y
CONFIG_SENSORS_IBM_CFFPS=y        # 若使用 IBM CFFPS
CONFIG_SENSORS_INSPUR_IPSPS=y     # 若使用 Inspur PSU
```

```bash
dmesg | grep -Ei 'pmbus|cffps|ipsps|psu|power-supply'
ls -l /sys/bus/i2c/devices/4-0058/
readlink /sys/bus/i2c/devices/4-0058/driver

# 臨時驗證 driver bind
modprobe pmbus
echo pmbus 0x58 > /sys/bus/i2c/devices/i2c-4/new_device
```

##### 12.10.7 hwmon sysfs 節點與單位確認

```bash
for i in /sys/class/hwmon/hwmon*; do
    echo "$i: $(cat "$i/name" 2>/dev/null)"
done

HWMON=/sys/class/hwmon/hwmonX
cat $HWMON/name
ls $HWMON
cat $HWMON/in1_input       # voltage, mV
cat $HWMON/in1_label       # vin / vout1 / ...
cat $HWMON/curr1_input     # current, mA
cat $HWMON/curr1_label     # iin / iout1 / ...
cat $HWMON/power1_input    # power, µW
cat $HWMON/power1_label    # pin / pout1 / ...
cat $HWMON/temp1_input     # temperature, m°C
cat $HWMON/fan1_input      # RPM
```

hwmon 標準單位：

```text
in*_input       millivolt (mV)
curr*_input     milliampere (mA)
power*_input    microwatt (µW)
temp*_input     millidegree Celsius (m°C)
fan*_input      RPM
```

PSUSensor 會依 hwmon label 與 Entity Manager 設定建立 sensor。Bring-up 時建議建立「label → sysfs → D-Bus path」對照表，而不是假設 `in1` 一定是輸入電壓、`in2` 一定是輸出電壓。

```bash
for f in $HWMON/*_label; do
    base=${f%_label}
    echo "$(basename "$base") label=$(cat "$f") input=$(cat "${base}_input" 2>/dev/null)"
done

find $HWMON -maxdepth 1 -type f | grep -E 'alarm|fault|crit|max|min' | sort
```

##### 12.10.8 Entity Manager 配置

不同 OpenBMC 分支的 schema 與 dbus-sensors 支援欄位會有差異；以下為常見結構，實際需以專案 branch 的 schema、既有平台 JSON 與 `PSUSensorMain.cpp` 支援項目為準。

```json
{
    "Name": "PSU0",
    "Type": "PowerSupply",
    "Probe": "TRUE",
    "Exposes": [
        {
            "Name": "PSU0",
            "Type": "pmbus",
            "Bus": 4,
            "Address": "0x58",
            "PollRate": 5.0,
            "Labels": ["vin", "vout1", "iin", "iout1", "pin", "pout1", "temp1", "fan1"],
            "vin_Name": "PSU0_Input_Voltage",
            "vout1_Name": "PSU0_Output_Voltage",
            "iin_Name": "PSU0_Input_Current",
            "iout1_Name": "PSU0_Output_Current",
            "pin_Name": "PSU0_Input_Power",
            "pout1_Name": "PSU0_Output_Power",
            "temp1_Name": "PSU0_Temp",
            "fan1_Name": "PSU0_Fan"
        }
    ],
    "xyz.openbmc_project.Inventory.Decorator.Asset": {
        "Manufacturer": "[待填]",
        "Model": "[待填]",
        "PartNumber": "[待填]",
        "SerialNumber": "[待填]"
    }
}
```

PSU 需和 chassis / baseboard 建立供電關係，讓 Redfish 能把 sensor 與 power supply inventory 正確關聯。常見概念是 baseboard 端建立 `powered_by` port，PSU 端建立 `powering` port；實際 JSON 寫法需依專案 schema 確認。

##### 12.10.9 PSU Presence、Fault 與 Inventory

PSU presence 常見來源：GPIO、CPLD、PMBus ACK、FRU EEPROM。建議判讀原則：

| 情境 | Presence | Functional / Health | Sensor 行為 |
| :--- | :--- | :--- | :--- |
| PSU 拔除 | false | false 或 unavailable | sensor 可移除、標記 unavailable，或依平台策略保留但不更新。 |
| PSU 插入且正常 | true | true | sensor 正常更新。 |
| PSU 插入但 AC lost | true | false / warning | input voltage/power 可能為 0 或 unavailable，需產生事件。 |
| PSU 插入但 PMBus timeout | true 或待確認 | false / unavailable | 需區分 bus stuck、PSU booting、driver issue。 |
| PSU fan fault / OT / OC | true | false | D-Bus health 與 log 要能反映。 |

```bash
systemctl list-units | grep -Ei 'psu|power'
journalctl -b | grep -Ei 'psu|power supply|redundan|pmbus|cffps'
```

##### 12.10.10 啟動服務與 D-Bus 驗證

```bash
systemctl status xyz.openbmc_project.EntityManager.service --no-pager
journalctl -u xyz.openbmc_project.EntityManager.service -b --no-pager

systemctl status xyz.openbmc_project.PSUSensor.service --no-pager
journalctl -u xyz.openbmc_project.PSUSensor.service -b --no-pager

busctl tree xyz.openbmc_project.PSUSensor
busctl tree xyz.openbmc_project.ObjectMapper | grep -Ei 'PSU|PowerSupply|Input|Output'

busctl get-property \
  xyz.openbmc_project.PSUSensor \
  /xyz/openbmc_project/sensors/voltage/PSU0_Input_Voltage \
  xyz.openbmc_project.Sensor.Value \
  Value
```

##### 12.10.11 Redfish / IPMI / Event 驗證

```bash
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>/Power
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>/PowerSubsystem
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>/PowerSubsystem/PowerSupplies
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>/Sensors

ipmitool sdr list | grep -Ei 'psu|power|vin|vout|pin|pout|fan'
ipmitool sensor | grep -Ei 'psu|power|vin|vout|pin|pout|fan'
ipmitool sel list

journalctl -b | grep -Ei 'psu|power supply|threshold|critical|warning|fault'
```

需驗證拔除、插入、AC lost、fan fault、over temperature、over current、threshold event、Redundancy 狀態與 SEL / Journal 行為。

##### 12.10.12 進階除錯與常見陷阱

| 問題現象 | 可能方向 | 排查 / 解法 |
| :--- | :--- | :--- |
| `i2cdetect` 掃不到 PSU 位址 | PSU 未插入、AC/standby 未供電、bus / mux / address 錯誤、CPLD gate 關閉 | 確認 PSU slot、AC、mux channel、schematic bus、CPLD register；量測 SCL/SDA。 |
| `i2cdetect` 看得到，但無 hwmon | DTS 未建立 I2C client、driver 未啟用、compatible 不對 | 查 `dmesg`、`/sys/bus/i2c/devices`、kernel config；臨時用 `new_device` 驗證。 |
| hwmon 有節點但讀值為 0 | PSU standby、command 不支援、driver 判讀錯、PSU 尚未 ready | 對照 PMBus command list；等待 PSU ready；確認 12V main / 12VSB 狀態。 |
| 讀值倍率錯 | hwmon 單位與 D-Bus 單位換算錯、重複 scaling、vendor direct format 參數錯 | 同步比對 raw PMBus、sysfs、D-Bus、Redfish；確認 scale/offset 是否重複。 |
| D-Bus sensor 未出現 | Entity Manager JSON 未載入、Labels 不符、service 未啟動 | 查 Entity Manager log、PSUSensor log、`*_label` 檔案；確認 `Labels` 對上 hwmon label。 |
| Redfish 看不到 PSU | Association 不完整、inventory path 不符、bmcweb schema/feature 差異 | 檢查 Port association、ObjectMapper、bmcweb log。 |
| Presence 不正確 | GPIO 極性錯、CPLD bit 定義錯、PMBus timeout 被當拔除 | 拔插實測 GPIO/CPLD bit；區分 Present 與 Functional。 |
| PSU fault 無 log | STATUS command 未讀、fault bit 未對應 event、daemon 未啟用 | 檢查 `STATUS_WORD`、`*_alarm`、phosphor-power log 與 event mapping。 |

##### 12.10.13 PSU Sensor Porting 驗收 Checklist

```text
硬體 / 規格：
[ ] PSU 型號、form factor、slot 編號確認
[ ] I2C bus / mux channel / address 確認
[ ] PMBus command 支援清單確認
[ ] Presence / Fault / AC OK / DC OK 訊號來源與極性確認
[ ] FRU / Asset data 來源確認
[ ] Redundancy policy 確認
[ ] Thresholds 與額定範圍確認

Kernel / DTS：
[ ] I2C controller node status = okay
[ ] PSU I2C node compatible / reg 正確
[ ] CONFIG_PMBUS / CONFIG_SENSORS_PMBUS / vendor driver 啟用
[ ] dmesg 無 probe fail / timeout / bus error
[ ] /sys/bus/i2c/devices/<bus>-00<addr>/driver bind 正確
[ ] /sys/class/hwmon/hwmonX/name 對應 PSU driver
[ ] in / curr / power / temp / fan hwmon 節點存在且單位正確
[ ] *_label 對應 vin / vout / iin / iout / pin / pout / temp / fan

Entity Manager / Userspace：
[ ] PSU JSON 放入正確 layer / image
[ ] Type / Bus / Address / Labels 與 schema 對齊
[ ] <label>_Name 命名符合平台規範
[ ] PollRate 合理，I2C bus loading 可接受
[ ] Baseboard / Chassis / PSU association 完成
[ ] Presence / fault daemon 配置完成
[ ] FRU / Asset 可讀取或以平台資料補齊

D-Bus / Redfish / IPMI：
[ ] PSUSensor service 啟動無錯誤
[ ] busctl 可看到 voltage / current / power / temperature / fan_tach sensor
[ ] sensor Value 與 sysfs 換算一致
[ ] Availability / Functional 狀態符合插拔與故障情境
[ ] Redfish 可看到 PSU inventory 與 sensors
[ ] IPMI SDR / sensor reading / SEL 符合平台需求
[ ] 拔除 PSU、插入 PSU、AC lost、fault injection 行為都有驗證
[ ] critical / warning threshold 與 event log 可正常觸發
```

##### 12.10.14 PSU Sensor 資料表範本

| PSU Slot | I2C Bus | Mux Channel | Address | Driver | hwmon name | Label | sysfs | D-Bus Path | Presence Source | Fault Source | 備註 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| PSU0 | 4 | [待填] | 0x58 | pmbus | [待填] | vin | inX_input | /xyz/openbmc_project/sensors/voltage/PSU0_Input_Voltage | GPIO/CPLD/PMBus | STATUS_WORD/CPLD | [待填] |
| PSU0 | 4 | [待填] | 0x58 | pmbus | [待填] | pout1 | powerX_input | /xyz/openbmc_project/sensors/power/PSU0_Output_Power | GPIO/CPLD/PMBus | STATUS_WORD/CPLD | [待填] |
| PSU0 | 4 | [待填] | 0x58 | pmbus | [待填] | temp1 | tempX_input | /xyz/openbmc_project/sensors/temperature/PSU0_Temp | GPIO/CPLD/PMBus | STATUS_WORD/CPLD | [待填] |
| PSU0 | 4 | [待填] | 0x58 | pmbus | [待填] | fan1 | fanX_input | /xyz/openbmc_project/sensors/fan_tach/PSU0_Fan | GPIO/CPLD/PMBus | STATUS_FANS/CPLD | [待填] |

##### 12.10.15 本節參考資料

- Linux Kernel Documentation - Kernel driver pmbus: https://docs.kernel.org/hwmon/pmbus.html
- OpenBMC dbus-sensors README 與 PSUSensor source: https://github.com/openbmc/dbus-sensors
- OpenBMC Entity Manager README / schema / configurations: https://github.com/openbmc/entity-manager
- OpenBMC phosphor-power: https://github.com/openbmc/phosphor-power

#### 12.11 CPU Sensor / PECI / APML

##### 12.11.1 適用情境

CPU Sensor 用於監控伺服器中央處理器的溫度、功耗與健康狀態，是散熱政策、功耗管理、事件紀錄與系統保護的重要輸入。x86 伺服器平台依 CPU 廠商不同，常見有兩條 out-of-band 管理路徑：Intel 使用 PECI，AMD EPYC 使用 APML。

| 廠商 | 介面 | 全名 | 主要用途 |
| :--- | :--- | :--- | :--- |
| Intel | PECI | Platform Environment Control Interface | BMC 讀取 CPU package / core / DIMM thermal telemetry。 |
| AMD | APML | Advanced Platform Management Link | BMC 透過 SB-TSI / SB-RMI 讀 CPU temperature、power、power cap、DIMM thermal 與 APML event。 |

Intel PECI 常見項目：

```text
CPU package temperature
CPU DTS / thermal margin
CPU core temperature
Tcontrol / Tthrottle / Tjmax
DIMM temperature
CPU presence / CPU reachable state
```

AMD APML 常見項目：

```text
CPU package temperature, via SB-TSI
CPU package power, via SB-RMI
power cap / power cap max, via SB-RMI
DIMM TS0 / TS1 thermal sensor, via SB-RMI mailbox
APML_ALERT_L event notification, if routed to BMC GPIO
CPU presence / CPU reachable state
```

OpenBMC 中常見 D-Bus sensor path：

```text
# Intel PECI
/xyz/openbmc_project/sensors/temperature/CPU0_Temp
/xyz/openbmc_project/sensors/temperature/CPU0_Core0_Temp
/xyz/openbmc_project/sensors/temperature/DIMM0_Temp

# AMD APML
/xyz/openbmc_project/sensors/temperature/CPU0_Temp
/xyz/openbmc_project/sensors/temperature/DIMM_TS0_UMC0_Temp
/xyz/openbmc_project/sensors/temperature/DIMM_TS1_UMC0_Temp
/xyz/openbmc_project/sensors/power/CPU0_Power
```

CPU Sensor 與一般 board sensor 最大差異是 host power state dependency。CPU / DIMM telemetry 通常只有在 host 上電、CPU 初始化到一定階段、BIOS / firmware 完成必要訓練後才會穩定。因此 CPU sensor porting 不只要看 kernel driver，也要同步 host power state、BIOS 設定、socket presence、CPU generation 與 BMC service rescan 行為。

##### 12.11.2 Intel PECI 架構與資料路徑

PECI 是 Intel server CPU 常見 out-of-band thermal 管理介面。BMC 作為 originator，CPU 作為 responder。常見 PECI client address 依 socket 位置排列：

| Socket | PECI address |
| :--- | :--- |
| CPU0 | `0x30` |
| CPU1 | `0x31` |
| CPU2 | `0x32` |
| CPU3 | `0x33` |

Intel PECI 資料路徑：

```text
Intel CPU PECI responder, e.g. 0x30 / 0x31
    ↓
PECI single-wire bus
    ↓
BMC PECI controller, e.g. ASPEED PECI
    ↓
Linux PECI subsystem
    ├── PECI controller driver
    ├── PECI client device
    ├── peci-cputemp   CPU package / core temperature
    └── peci-dimmtemp  DIMM temperature
    ↓
hwmon sysfs
    ├── /sys/class/hwmon/hwmonX/temp*_input
    ├── /sys/class/hwmon/hwmonX/temp*_label
    ├── /sys/class/hwmon/hwmonX/temp*_max
    └── /sys/class/hwmon/hwmonX/temp*_crit
    ↓
IntelCPUSensor, dbus-sensors
    ↓
D-Bus Sensor.Value / Threshold / Availability / OperationalStatus
    ↓
Redfish / IPMI / phosphor-pid-control / phosphor-logging
```

Linux `peci-cputemp` 會提供 CPU package、DTS、Tcontrol、Tthrottle、Tjmax 與 per-core temperature 等 hwmon 屬性；所有 temperature value 以 millidegree Celsius 表示，且只有 target CPU powered on 時可量測。`peci-dimmtemp` 會提供 DIMM temperature，同樣以 millidegree Celsius 表示，且 DIMM thermal 屬性需等 BIOS 完成 memory training / testing 後才會出現。

##### 12.11.3 AMD APML 架構與資料路徑

AMD APML 由多個 sideband 協定與 driver 組成，常見子介面如下：

| 介面 | 全名 | 主要用途 |
| :--- | :--- | :--- |
| SB-TSI | Sideband Thermal Sensor Interface | CPU socket temperature、temperature threshold。 |
| SB-RMI | Sideband Remote Management Interface | socket power、power cap、power cap max、DIMM thermal mailbox、進階 mailbox command。 |
| APML_ALERT_L | APML alert line | APML event notification，視平台設計接到 GPIO。 |

常見 SB-RMI address：

| Socket | 常見 8-bit 表示 | 常見 7-bit 表示 |
| :--- | :--- | :--- |
| CPU0 | `0x78` | `0x3C` |
| CPU1 | `0x70` | `0x38` |

常見 SB-TSI address 依平台 address select pin 而定；許多平台使用 `0x4C` / `0x48`，仍需以 schematic 與 PPR 為準。

AMD APML 資料路徑：

```text
AMD EPYC CPU APML responder
    ↓
I2C or I3C bus from BMC to CPU socket
    ↓
Linux kernel drivers
    ├── sbtsi / apml_sbtsi
    │     CPU socket temperature, threshold
    ├── sbrmi / apml_sbrmi
    │     power1_input / power1_cap / power1_cap_max
    │     DIMM TS0 / TS1 temperature, if firmware supports mailbox command
    └── apml_alertl, optional
          APML_ALERT_L GPIO event notification
    ↓
hwmon sysfs
    ├── temp*_input / temp*_label
    ├── power1_input
    ├── power1_cap
    └── power1_cap_max
    ↓
HwmonTempSensor / platform daemon
    ↓
D-Bus Sensor.Value / Threshold / Availability / OperationalStatus
    ↓
Redfish / IPMI / phosphor-pid-control / phosphor-logging
```

AMD APML modules 主要支援 AMD Family 19h（包含第三代 AMD EPYC Milan）或更新的 server CPU。AMD APML library 也增加 Family 19h model 90h~9Fh 與 Family 1Ah model 00h~0Fh 相關功能；實際可用功能需以 CPU PPR、platform firmware、kernel driver 與 APML library 版本交叉確認。

##### 12.11.4 Porting 前需確認的硬體資料

Intel PECI：

```text
[必填] CPU vendor / generation / socket count
[必填] PECI bus 連到 BMC 哪個 controller
[必填] PECI address：CPU0=0x30、CPU1=0x31...
[必填] PECI pinmux / 電壓準位 / pull-up / routing
[必填] CPU presence / socket ID / board SKU 關係
[必填] Host power state dependency
[必填] BIOS 是否允許 BMC 透過 PECI 取得 thermal telemetry
[建議] CPU package / core / DIMM threshold
[建議] Fan policy 使用哪個 CPU sensor：Die / DTS / Tcontrol / margin
[建議] QEMU 無法驗證 PECI，需規劃實機 validation
```

AMD APML：

```text
[必填] CPU vendor / generation / socket count
[必填] CPU family / model 是否受 APML driver 支援
[必填] APML 使用 I2C 或 I3C
[必填] SB-TSI bus / address
[必填] SB-RMI bus / address
[必填] APML_ALERT_L GPIO 是否接到 BMC
[必填] Host power state dependency
[必填] Platform firmware 是否支援 SB-RMI mailbox command
[建議] DIMM TS0 / TS1 / UMC 對照
[建議] Power cap policy 與 host power budget
[建議] I3C bus support patch / kernel symbol dependency，若平台使用 I3C
```

##### 12.11.5 Intel PECI Device Tree 與 Kernel Config

Device Tree 範例：

```dts
&peci0 {
    status = "okay";
    pinctrl-names = "default";
    pinctrl-0 = <&pinctrl_peci0_default>;

    cpu@30 {
        compatible = "intel,peci-client";
        reg = <0x30>;
    };

    cpu@31 {
        compatible = "intel,peci-client";
        reg = <0x31>;
    };
};
```

Kernel config：

```text
CONFIG_PECI=y
CONFIG_PECI_ASPEED=y
CONFIG_SENSORS_PECI_CPUTEMP=y
CONFIG_SENSORS_PECI_DIMMTEMP=y
```

OpenBMC / Yocto 需確認 `dbus-sensors` 的 Intel CPU sensor 有被建入 image。不同分支的 PACKAGECONFIG 名稱可能略有差異，需先查該 branch 的 `meson.options` 與 recipe：

```bash
bitbake -e dbus-sensors | grep -i intel
bitbake-layers show-appends | grep dbus-sensors
```

常見 `.bbappend` 概念：

```bitbake
PACKAGECONFIG:append = " intelcpusensor"
```

##### 12.11.6 Intel PECI sysfs 與 IntelCPUSensor 驗證

Kernel / device 檢查：

```bash
dmesg | grep -i peci
ls -l /dev/peci-* 2>/dev/null
ls -l /sys/bus/peci/devices/ 2>/dev/null
```

hwmon 檢查：

```bash
for i in /sys/class/hwmon/hwmon*; do
    echo "$i: $(cat "$i/name" 2>/dev/null)"
done

HWMON=/sys/class/hwmon/hwmonX
cat $HWMON/name
ls $HWMON/temp*_input
cat $HWMON/temp1_label
cat $HWMON/temp1_input
cat $HWMON/temp1_max 2>/dev/null
cat $HWMON/temp1_crit 2>/dev/null
```

`peci-cputemp` 常見 label：

| label | 說明 |
| :--- | :--- |
| `Die` | CPU package die temperature。 |
| `DTS` | 依 DTS thermal profile 調整後的 CPU package temperature。 |
| `Tcontrol` | Fan Temperature target，常與 fan policy 相關。 |
| `Tthrottle` | Throttle temperature。 |
| `Tjmax` | Maximum junction temperature。 |
| `Core X` | Per-core temperature。 |

IntelCPUSensor service 檢查：

```bash
systemctl status xyz.openbmc_project.IntelCPUSensor.service --no-pager
journalctl -u xyz.openbmc_project.IntelCPUSensor.service -b --no-pager

busctl tree xyz.openbmc_project.IntelCPUSensor
busctl tree xyz.openbmc_project.ObjectMapper | grep -Ei 'cpu|dimm|peci'
```

讀取 D-Bus sensor：

```bash
busctl get-property   xyz.openbmc_project.IntelCPUSensor   /xyz/openbmc_project/sensors/temperature/CPU0_Temp   xyz.openbmc_project.Sensor.Value   Value
```

##### 12.11.7 IntelCPUSensor 偵測狀態機

IntelCPUSensor 有 CPU detection / DIMM readiness 狀態機，用來處理 CPU 尚未上電、PECI 尚未回應、hwmon device 尚未建立、DIMM 尚未完成 training 等情境。

| 狀態 | 說明 | 常見觀察 |
| :--- | :--- | :--- |
| `OFF` | CPU 尚未偵測到或 PECI ping 失敗 | Host off、CPU absent、PECI pinmux / driver 問題。 |
| `ON` | CPU ping 成功，已讀到 CPU ID，開始建立 PECI client / hwmon | CPU 已可通訊，但 DIMM sensor 不一定 ready。 |
| `READY` | CPU 與 DIMM thermal path 已就緒 | CPU / DIMM sensor 應可出現在 D-Bus。 |

典型流程：

```text
OFF
    CPU ping 成功
    ↓
ON
    讀 CPU ID
    export PECI client device
    等待 peci-cputemp / peci-dimmtemp hwmon
    ↓
READY
    建立 CPU / core / DIMM D-Bus sensors
```

若只看到 CPU sensor，沒有 DIMM sensor，需先確認 host BIOS 是否已完成 memory training、DIMM 是否安裝、`peci-dimmtemp` driver 是否建立 hwmon，以及 IntelCPUSensor 是否持續 rescan。

##### 12.11.8 AMD APML Device Tree 與 Kernel Config

AMD APML I2C device 範例：

```dts
&i2c3 {
    status = "okay";
    clock-frequency = <100000>;

    sbtsi@4c {
        compatible = "amd,sbtsi";
        reg = <0x4c>;
    };

    sbrmi@3c {
        compatible = "amd,sbrmi";
        reg = <0x3c>;
    };
};

&i2c4 {
    status = "okay";
    clock-frequency = <100000>;

    sbtsi@48 {
        compatible = "amd,sbtsi";
        reg = <0x48>;
    };

    sbrmi@38 {
        compatible = "amd,sbrmi";
        reg = <0x38>;
    };
};
```

若 SB-RMI driver / platform firmware 支援 DIMM thermal mailbox，可在 `sbrmi` node 補 `dimm-ids`。此屬性用於指出 populated UMC instance 的 TS0 mailbox address；TS1 通常由 driver 設定 bit 6 取得。

```dts
sbrmi@3c {
    compatible = "amd,sbrmi";
    reg = <0x3c>;
    dimm-ids = <0x80 0x90 0x81 0x91 0x82 0x92 0x83 0x93>;
};
```

Kernel config：

```text
CONFIG_SENSORS_SBTSI=y
CONFIG_SENSORS_SBRMI=y
```

若使用 AMD APML out-of-tree modules，需依專案 recipe / kernel source 整合：

```text
CONFIG_AMD_APML_SBTSI=m 或 y
CONFIG_AMD_APML_SBRMI=m 或 y
CONFIG_AMD_APML_ALERTL=m 或 y，若使用 APML_ALERT_L
```

##### 12.11.9 AMD APML sysfs 驗證

Driver / device 檢查：

```bash
dmesg | grep -Ei 'sbtsi|sbrmi|apml'
lsmod | grep -Ei 'sbtsi|sbrmi|apml'
```

I2C 掃描：

```bash
# 範例：socket 0 APML bus
i2cdetect -y 3
```

hwmon 檢查：

```bash
for i in /sys/class/hwmon/hwmon*; do
    echo "$i: $(cat "$i/name" 2>/dev/null)"
done

# SB-TSI CPU temperature
HWMON_TSI=/sys/class/hwmon/hwmonX
cat $HWMON_TSI/name
cat $HWMON_TSI/temp1_input
cat $HWMON_TSI/temp1_max 2>/dev/null
cat $HWMON_TSI/temp1_min 2>/dev/null

# SB-RMI package power / power cap
HWMON_RMI=/sys/class/hwmon/hwmonY
cat $HWMON_RMI/name
cat $HWMON_RMI/power1_input
cat $HWMON_RMI/power1_cap 2>/dev/null
cat $HWMON_RMI/power1_cap_max 2>/dev/null

# SB-RMI DIMM thermal channels, if supported
ls $HWMON_RMI/temp*_input 2>/dev/null
cat $HWMON_RMI/temp1_label 2>/dev/null
cat $HWMON_RMI/temp17_label 2>/dev/null
```

AMD APML units：

```text
temp*_input      millidegree Celsius (m°C)
power1_input     microwatt (µW)
power1_cap       microwatt (µW)
power1_cap_max   microwatt (µW)
```

SB-RMI DIMM thermal channel 對應：

| hwmon channel | label pattern | 說明 |
| :--- | :--- | :--- |
| `temp1` ~ `temp16` | `DIMM_TS0_UMC0` ~ `DIMM_TS0_UMC15` | TS0 for UMC 0~15。 |
| `temp17` ~ `temp32` | `DIMM_TS1_UMC0` ~ `DIMM_TS1_UMC15` | TS1 for UMC 0~15。 |

##### 12.11.10 Entity Manager 配置

不同 OpenBMC 分支與平台 JSON schema 有差異；以下內容作為設計範本，實際欄位需對齊專案 branch 的 Entity Manager schema 與 sensor daemon 支援項目。

Intel CPU：

```json
{
    "Name": "CPU0",
    "Type": "CPU",
    "Address": 48,
    "Index": 0,
    "MaxReading": 127,
    "MinReading": -10,
    "PowerState": "On",
    "Thresholds": [
        {
            "Name": "upper critical",
            "Direction": "greater than",
            "Severity": 1,
            "Value": 95.0
        },
        {
            "Name": "upper non critical",
            "Direction": "greater than",
            "Severity": 0,
            "Value": 85.0
        }
    ]
}
```

Intel DIMM：

```json
{
    "Name": "DIMM0",
    "Type": "DIMM",
    "Address": 48,
    "Index": 0,
    "MaxReading": 127,
    "MinReading": -10,
    "PowerState": "On",
    "Thresholds": [
        {
            "Name": "upper critical",
            "Direction": "greater than",
            "Severity": 1,
            "Value": 85.0
        }
    ]
}
```

注意：Intel PECI address 在許多 Entity Manager 配置中使用十進位；例如 `0x30` 寫成 `48`，`0x31` 寫成 `49`。若 schema 不接受十六進位字串，使用十進位可避免 service parse 失敗。

AMD SB-TSI：

```json
{
    "Name": "CPU0",
    "Type": "SBTSI",
    "Bus": 3,
    "Address": "0x4C",
    "Index": 0,
    "MaxReading": 127,
    "MinReading": -10,
    "PowerState": "On",
    "Thresholds": [
        {
            "Name": "upper critical",
            "Direction": "greater than",
            "Severity": 1,
            "Value": 95.0
        }
    ]
}
```

AMD SB-RMI power：

```json
{
    "Name": "CPU0_Power",
    "Type": "SBRMI",
    "Bus": 3,
    "Address": "0x3C",
    "Index": 0,
    "MaxReading": 400.0,
    "MinReading": 0.0,
    "PowerState": "On",
    "Thresholds": [
        {
            "Name": "upper critical",
            "Direction": "greater than",
            "Severity": 1,
            "Value": 350.0
        }
    ]
}
```

##### 12.11.11 啟動服務與 D-Bus 驗證

Intel PECI：

```bash
systemctl status xyz.openbmc_project.IntelCPUSensor.service --no-pager
journalctl -u xyz.openbmc_project.IntelCPUSensor.service -b --no-pager

busctl tree xyz.openbmc_project.ObjectMapper | grep -Ei 'cpu|dimm|peci'

busctl get-property   xyz.openbmc_project.IntelCPUSensor   /xyz/openbmc_project/sensors/temperature/CPU0_Temp   xyz.openbmc_project.Sensor.Value   Value
```

AMD APML：

```bash
systemctl status xyz.openbmc_project.HwmonTempSensor.service --no-pager
journalctl -u xyz.openbmc_project.HwmonTempSensor.service -b --no-pager

busctl tree xyz.openbmc_project.ObjectMapper | grep -Ei 'cpu|dimm|sbrmi|sbtsi|apml'

busctl get-property   xyz.openbmc_project.HwmonTempSensor   /xyz/openbmc_project/sensors/temperature/CPU0_Temp   xyz.openbmc_project.Sensor.Value   Value
```

若 AMD power sensor 由 PowerSensor / PSUSensor-like daemon 或平台 daemon 發佈，service owner 可能不是 `HwmonTempSensor`，需先用 ObjectMapper 找出 owner。

##### 12.11.12 Redfish / IPMI / Fan Policy 驗證

Redfish：

```bash
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Systems/system/Processors
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>/Thermal
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>/Sensors
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>/ThermalSubsystem
```

IPMI：

```bash
ipmitool sdr list | grep -Ei 'cpu|dimm|temp|power'
ipmitool sensor | grep -Ei 'cpu|dimm|temp|power'
ipmitool sel list
```

Fan policy：

```bash
journalctl -b | grep -Ei 'pid|thermal|fan|cpu|dimm|failsafe'
busctl tree xyz.openbmc_project.ObjectMapper | grep -Ei 'pid|thermal|fan'
```

驗證重點：

```text
[ ] Host off 時 CPU sensor 狀態符合設計：Unavailable、無 sensor，或保留但不更新
[ ] Host on 後 CPU sensor 會自動出現或恢復更新
[ ] CPU stress test 時 temperature 上升
[ ] Fan policy 使用的 CPU / DIMM sensor path 正確
[ ] 過溫 threshold 能產生 D-Bus alarm / SEL / Journal event
[ ] Redfish / IPMI 顯示與 D-Bus 值一致
```

##### 12.11.13 進階除錯與常見陷阱

| 問題現象 | Intel PECI 可能方向 | AMD APML 可能方向 | 排查 |
| :--- | :--- | :--- | :--- |
| device node 不存在 | PECI controller driver 未載入、DTS disabled、pinmux 錯 | I2C/I3C device 未建立、driver 未啟用 | 查 `dmesg`、DTS、kernel config。 |
| `i2cdetect` 看不到 APML address | 不適用 | bus / mux / address / host power state / address select pin | 查 schematic、host power、I2C waveform。 |
| hwmon 不存在 | CPU 未上電、PECI client 未 export、cputemp/dimmtemp 未 bind | sbtsi/sbrmi driver 未 bind、APML function 不支援 | 查 `/sys/bus/peci` 或 `/sys/bus/i2c/devices`。 |
| CPU temp 有，DIMM temp 無 | BIOS memory training 未完成、DIMM absent、dimmtemp driver 問題 | SB-RMI mailbox command 不支援、dimm-ids 錯 | 查 BIOS log、DIMM population、driver log。 |
| 讀值固定 0 或異常 | PECI completion code / host state / scaling 問題 | APML mailbox fail、firmware 不支援、unit 換算錯 | 比對 sysfs、D-Bus、Redfish。 |
| service 起不來 | IntelCPUSensor 未建入 image、EM JSON 格式錯 | HwmonTempSensor 未匹配 hwmon、JSON Type 不符 | 查 journal 與 Entity Manager log。 |
| Host reboot 後 sensor 沒回來 | rescan / state machine 卡住 | I2C bus stuck、driver 未重新 bind | restart sensor service，查 bus recovery。 |
| Fan 全速 | required CPU sensor unavailable | required CPU sensor unavailable | 查 fan policy required sensor 與 failsafe reason。 |
| Redfish 看不到 CPU sensor | association / naming / bmcweb mapping 不完整 | association / naming / bmcweb mapping 不完整 | 查 ObjectMapper、bmcweb log。 |

##### 12.11.14 CPU Sensor Porting 驗收 Checklist

```text
硬體 / 規格：
[ ] CPU vendor / model / generation 確認
[ ] Socket count / socket ID 確認
[ ] Intel PECI address 或 AMD APML bus/address 確認
[ ] Host power state dependency 確認
[ ] BIOS / firmware 支援情況確認
[ ] CPU / DIMM threshold 確認

Intel PECI：
[ ] PECI pinmux / DTS / controller status 正確
[ ] CONFIG_PECI / CONFIG_PECI_ASPEED 啟用
[ ] CONFIG_SENSORS_PECI_CPUTEMP 啟用
[ ] CONFIG_SENSORS_PECI_DIMMTEMP 啟用
[ ] /dev/peci-* 或 /sys/bus/peci/devices 存在
[ ] peci-cputemp hwmon 存在
[ ] peci-dimmtemp hwmon 存在，若平台需要 DIMM temp
[ ] IntelCPUSensor service 啟動正常

AMD APML：
[ ] CPU family / model 符合 driver 支援範圍
[ ] SB-TSI / SB-RMI DTS node 正確
[ ] CONFIG_SENSORS_SBTSI / CONFIG_SENSORS_SBRMI 啟用
[ ] 若使用 out-of-tree APML modules，recipe / module load 正常
[ ] sbtsi hwmon temp 可讀
[ ] sbrmi hwmon power 可讀
[ ] DIMM TS0 / TS1 channel 可讀，若 firmware 支援
[ ] APML_ALERT_L GPIO 驗證完成，若平台使用

Entity Manager / Userspace：
[ ] CPU / DIMM / SBTSI / SBRMI JSON 加入 image
[ ] Address 格式符合 schema
[ ] PowerState 設定符合 host state dependency
[ ] Thresholds 設定完成
[ ] D-Bus sensor path 命名符合平台規範

整合驗證：
[ ] Host off / on / reboot sensor 行為符合設計
[ ] busctl 可讀取 CPU / DIMM / power Value
[ ] Redfish 可看到 CPU / DIMM / thermal sensors
[ ] IPMI SDR / sensor reading 正常
[ ] CPU stress test 後溫度上升合理
[ ] Sensor missing 會觸發 fan failsafe 或 degraded policy
[ ] 過溫事件可產生 Journal / SEL
```

##### 12.11.15 CPU Sensor 資料表範本

| Socket | Vendor | Interface | Bus / Controller | Address | Driver | hwmon name | Label | sysfs | D-Bus Path | PowerState | 備註 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| CPU0 | Intel | PECI | peci0 | 0x30 | peci-cputemp | [待填] | Die | tempX_input | /xyz/openbmc_project/sensors/temperature/CPU0_Temp | On | [待填] |
| CPU0 | Intel | PECI | peci0 | 0x30 | peci-dimmtemp | [待填] | DIMM CI | tempX_input | /xyz/openbmc_project/sensors/temperature/DIMM0_Temp | On | [待填] |
| CPU0 | AMD | SB-TSI | i2c3 | 0x4C | sbtsi | [待填] | temp1 | temp1_input | /xyz/openbmc_project/sensors/temperature/CPU0_Temp | On | [待填] |
| CPU0 | AMD | SB-RMI | i2c3 | 0x3C | sbrmi | [待填] | power1 | power1_input | /xyz/openbmc_project/sensors/power/CPU0_Power | On | [待填] |

##### 12.11.16 本節參考資料

- Linux Kernel Documentation - peci-cputemp: https://docs.kernel.org/hwmon/peci-cputemp.html
- Linux Kernel Documentation - peci-dimmtemp: https://mjmwired.net/kernel/Documentation/hwmon/peci-dimmtemp.rst
- Linux Kernel Documentation - sbrmi: https://www.kernel.org/doc/html/latest/hwmon/sbrmi.html
- OpenBMC dbus-sensors README: https://github.com/openbmc/dbus-sensors
- OpenBMC Intel CPU Sensors: https://deepwiki.com/openbmc/dbus-sensors/3.1.2-intel-cpu-sensors
- AMD APML modules: https://github.com/amd/apml_modules
- AMD APML Library: https://www.amd.com/en/developer/e-sms/apml-library.html
- OpenBMC Entity Manager: https://github.com/openbmc/entity-manager

##### 12.11.17 回查結果

本節依 CPU Sensor / PECI / APML 需求補強後，已完成下列回查：

```text
[x] 是否說明 Intel PECI 與 AMD APML 差異
[x] 是否補上 Intel PECI 資料路徑與 Linux hwmon 對應
[x] 是否補上 AMD SB-TSI / SB-RMI / APML_ALERT_L 架構
[x] 是否補上 Device Tree、kernel config、Yocto / service 驗證
[x] 是否補上 IntelCPUSensor OFF / ON / READY 狀態機
[x] 是否補上 AMD APML DIMM TS0 / TS1 channel 對應
[x] 是否補上 Entity Manager JSON 範本與 address 格式提醒
[x] 是否補上 Host power state dependency
[x] 是否補上 Redfish / IPMI / Fan policy 驗證
[x] 是否補上常見陷阱、驗收 checklist 與資料表範本
```

上述項目已補齊，暫無需回到資料蒐集階段。

#### 12.12 NVMe Sensor

NVMe sensor 用於監控 NVMe SSD 的溫度、健康狀態、SMART warning、slot inventory 與 firmware 資訊。BMC 可能透過 SMBus Basic Management Command、NVMe-MI over MCTP、host proxy 或 vendor daemon 取得資料。Porting 重點包含 drive slot mapping、presence、endpoint、timeout、inventory 與 Redfish / IPMI 對外路徑。

| 檢查項目 | 說明 |
| --- | --- |
| Slot / Location | U.2、E1.S、M.2、EDSFF slot 編號與絲印需一致 |
| Presence source | PCIe PRSNT#、CPLD、I2C ACK 或 MCTP endpoint |
| Transport | SMBus、MCTP over SMBus、MCTP over PCIe VDM、host proxy |
| Bus / Address / EID | 實際通訊路徑、mux channel 與 endpoint ID |
| Timeout / PollRate | 避免單顆 drive timeout 阻塞整組 sensor |
| Inventory | model、serial、firmware、capacity、location |
| Event | insert/remove、over-temp、SMART warning、timeout |

常用驗證：

```bash
i2cdetect -l
i2cdetect -y <bus>
systemctl status mctpd --no-pager 2>/dev/null || true
busctl tree xyz.openbmc_project.MCTP 2>/dev/null || true
systemctl list-units '*nvme*' --no-pager
journalctl -u xyz.openbmc_project.nvmesensor.service -b --no-pager 2>/dev/null | tail -200
busctl tree /xyz/openbmc_project/sensors | grep -i nvme
busctl tree /xyz/openbmc_project/inventory | grep -Ei 'nvme|drive|ssd'
```

常見問題：D-Bus 有 inventory 但沒有 temperature，多半需回查 endpoint discovery、sensor daemon PACKAGECONFIG、Entity Manager config 與 association；熱插拔後若 object 沒消失，需檢查 presence signal 與 daemon state machine；host proxy 類 sensor 需處理 host reset 後 stale data。

#### 12.13 GPU Sensor

GPU / accelerator sensor 常見於 NVIDIA GPU、DPU、AI accelerator、PCIe switch 或 retimer。資料來源可能是 MCTP vendor defined message、I2C sideband、SMBPBI、host proxy 或 vendor daemon。常見 sensor 包含 temperature、power、energy、voltage、utilization、clock、PCIe link、error event 與 power limit。

| 類別 | D-Bus / Redfish 方向 | 注意事項 |
| --- | --- | --- |
| Temperature | `temperature` | GPU core、memory、board、retimer sensor 需分清楚 |
| Power | `power` | instantaneous、average、peak 定義需固定 |
| Energy | `energy` | counter wrap、reset 後行為需定義 |
| Voltage / Current | `voltage` / `current` | rail name 與 GPU domain 對齊 |
| Utilization | `utilization` | GPU / memory / engine 類型需明確 |
| Control | power cap / clock limit | 權限、persistency、host policy |

常用驗證：

```bash
systemctl list-units '*gpu*' '*mctp*' --no-pager
journalctl -u xyz.openbmc_project.nvidiagpusensor.service -b --no-pager 2>/dev/null | tail -200
busctl tree /xyz/openbmc_project/sensors | grep -Ei 'gpu|accelerator|pcie'
busctl tree /xyz/openbmc_project/inventory | grep -Ei 'gpu|accelerator|pcie'
busctl introspect <service> <gpu-object-path>
```

常見問題包含 mW/W 或 µW/W 換算錯、GPU reset 後 sensor stale、MCTP endpoint recovery 不完整、Redfish association 缺失，以及 fan policy 因 required GPU temp unavailable 進入 failsafe。

#### 12.14 External / Virtual Sensor

External sensor 是由外部來源寫入 BMC D-Bus 的 sensor，例如 host OS、BIOS、另一顆 BMC 或 vendor daemon。Virtual sensor 則由既有 sensor 與公式計算，例如 total power、zone max temperature、average inlet temperature、redundant voting 或 power efficiency。

External sensor 需定義：
- Writer owner 與 D-Bus 權限。
- `Timeout` 與 stale data 行為。
- `MinValue` / `MaxValue` 與錯誤值過濾。
- host off、host reset、writer daemon crash 後是否保留最後值、變 NaN、`Available=false` 或 `Functional=false`。

Virtual sensor 設計原則：
- input D-Bus path、單位與更新率要明確。
- 先統一單位，避免 `µW + W` 或 `mV + V`。
- total power 需避免 double counting。
- 若參與 fan / power policy，需定義任一 input unavailable 時的行為。

常用驗證：

```bash
systemctl status xyz.openbmc_project.externalsensor.service --no-pager 2>/dev/null || true
journalctl -u xyz.openbmc_project.externalsensor.service -b --no-pager 2>/dev/null | tail -100
systemctl status phosphor-virtual-sensor.service --no-pager 2>/dev/null || true
journalctl -u phosphor-virtual-sensor.service -b --no-pager 2>/dev/null | tail -100
busctl tree /xyz/openbmc_project/sensors | grep -Ei 'external|total|max|avg|virtual'
```

#### 12.15 Presence / Intrusion / GPIO State Sensor

Presence、intrusion 與 GPIO state 類 sensor 多半是 Boolean 或 enum，而不是連續讀值。這類訊號會影響 inventory、hot-swap、LED、event log、Redfish chassis 狀態、IPMI discrete sensor 與維修流程，因此需區分 `Present`、`Functional`、`Available`、`Fault`、`Intrusion`。

| 類型 | 來源 | 用途 | 注意事項 |
| --- | --- | --- | --- |
| FRU presence | GPIO、CPLD bit、EEPROM ACK、PMBus ACK | PSU、fan tray、riser、backplane 是否插入 | active level、debounce、hot-swap event |
| Chassis intrusion | GPIO、PCH/SMBus、hwmon alarm | 機箱開蓋偵測 | Automatic / Manual rearm |
| Fault state | GPIO、CPLD latch、PMBus STATUS_WORD | PSU fault、fan fault、VR fault | latch clear / W1C rule |
| Board / SKU state | GPIO strap、ADC strap、CPLD register | board ID、SKU ID、revision | boot-time 與 runtime 可能不同 |

常用驗證：

```bash
gpiodetect
gpioinfo | grep -Ei 'present|intrusion|fault|psu|fan'
gpioget $(gpiofind CHASSIS_INTRUSION_N)
systemctl status xyz.openbmc_project.intrusionsensor.service --no-pager 2>/dev/null || true
journalctl -u xyz.openbmc_project.intrusionsensor.service -b --no-pager 2>/dev/null | tail -100
busctl tree /xyz/openbmc_project/inventory | grep -Ei 'psu|fan|chassis|riser|drive'
ipmitool sdr elist | grep -Ei 'presence|intrusion|fault'
```

#### 12.16 Redfish Association

Redfish 是否顯示 sensor，不只取決於 D-Bus 上是否存在 sensor object，也取決於 ObjectMapper association、inventory path、Chassis 關聯，以及 bmcweb 對該 sensor type 的路徑掃描策略。D-Bus 有值但 Redfish `N/A` 或缺項，常見方向是 association 缺失或 sensor 被掛到錯的 chassis。

| Association | 用途 |
| --- | --- |
| `chassis` / `all_sensors` | 讓 Redfish Chassis 收到 sensor |
| `inventory` / `sensors` | 讓 FRU / board / PSU / fan 與 sensor 關聯 |
| `sensors` / `inventory` | event log / callout 回查 inventory |
| `contained_by` / `containing` | 建立 chassis / board / module topology |

常用檢查：

```bash
busctl introspect <service> <sensor-path> xyz.openbmc_project.Association.Definitions
busctl get-property <service> <sensor-path> xyz.openbmc_project.Association.Definitions Associations
journalctl -u bmcweb -b --no-pager | grep -Ei 'sensor|association|chassis|redfish' | tail -200
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>/Sensors
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>/Thermal
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>/Power
```

#### 12.17 Sensor 共用除錯指令與附錄

建議依序檢查：hardware → kernel/sysfs → config → service → D-Bus → Redfish/IPMI → event/policy。

版本與 baseline：

```bash
cat /etc/os-release
cat /etc/timestamp 2>/dev/null || true
uname -a
cat /proc/cmdline
systemctl --failed --no-pager
```

Kernel / sysfs：

```bash
for h in /sys/class/hwmon/hwmon*; do
    echo "== $h =="
    cat "$h/name" 2>/dev/null || true
    ls "$h" | grep -E '^(in|temp|fan|pwm|curr|power|energy)[0-9]+' || true
done
find /sys/class/hwmon -maxdepth 2 -type f | grep -E '/(name|in[0-9]+_input|temp[0-9]+_input|fan[0-9]+_input|pwm[0-9]+|curr[0-9]+_input|power[0-9]+_input)$' | sort
```

Entity Manager / service：

```bash
ls -l /usr/share/entity-manager/configurations/ 2>/dev/null
systemctl status xyz.openbmc_project.EntityManager.service --no-pager
journalctl -u xyz.openbmc_project.EntityManager.service -b --no-pager | tail -200
systemctl list-units '*sensor*' '*hwmon*' '*fan*' '*pid*' '*power*' --no-pager
```

D-Bus：

```bash
busctl tree /xyz/openbmc_project/sensors
busctl introspect <service> <object-path>
busctl get-property <service> <object-path> xyz.openbmc_project.Sensor.Value Value
busctl get-property <service> <object-path> xyz.openbmc_project.Sensor.Value Unit
busctl get-property <service> <object-path> xyz.openbmc_project.State.Decorator.Availability Available
busctl get-property <service> <object-path> xyz.openbmc_project.State.Decorator.OperationalStatus Functional
```

Redfish / IPMI：

```bash
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>/Sensors
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>/Thermal
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>/Power
ipmitool sdr elist
ipmitool sensor list
ipmitool sel list
```

單位速查：

| sysfs / raw | 常見單位 | D-Bus / Redfish 建議單位 | 換算 |
| --- | --- | --- | --- |
| `temp*_input` | milli-degree C | DegreesC | `/ 1000` |
| `in*_input` | mV | Volts | `/ 1000 × ScaleFactor` |
| `curr*_input` | mA | Amperes | `/ 1000` |
| `power*_input` | µW | Watts | `/ 1000000` |
| `fan*_input` | RPM | RPMS | 通常不換算 |
| `pwm*` | 0–255 | Percent 或 raw | `raw / 255 × 100` |

常見分層排查：

| 現象 | 優先分層 | 第一輪檢查 |
| --- | --- | --- |
| D-Bus 沒 sensor | config / daemon / sysfs | Entity Manager log、sensor daemon log、sysfs 是否存在 |
| sysfs 有值但 D-Bus 無值 | daemon mapping | daemon 是否支援該 hwmon name / label / index |
| D-Bus 有值但 Redfish 無值 | association / bmcweb | ObjectMapper association、bmcweb log、Chassis path |
| D-Bus 有值但 IPMI 無 SDR | ipmid mapping | `ipmitool sdr`、ipmid dbus-sdr log |
| 數值差 1000 倍 | unit / scale | sysfs raw、ScaleFactor、D-Bus Unit、Redfish output |
| fan 全速 | required sensor unavailable | fan control log、Available / Functional |

##### 12.17.2 本章參考資料

- OpenBMC docs - Sensor Architecture: https://github.com/openbmc/docs/blob/master/architecture/sensor-architecture.md
- OpenBMC dbus-sensors README: https://github.com/openbmc/dbus-sensors
- OpenBMC entity-manager README / docs: https://github.com/openbmc/entity-manager
- OpenBMC phosphor-hwmon README: https://github.com/openbmc/phosphor-hwmon
- OpenBMC phosphor-virtual-sensor README: https://github.com/openbmc/phosphor-virtual-sensor
- Linux kernel hwmon sysfs interface: https://docs.kernel.org/hwmon/sysfs-interface.html
- OpenBMC bmcweb Redfish sensor implementation: https://github.com/openbmc/bmcweb/blob/master/redfish-core/lib/sensors.hpp

### 13. Fan Control 與 Thermal Policy

本章承接第 12 章的 sensor porting：第 12 章回答「感測器如何被讀到、如何發佈到 D-Bus」，本章回答「系統如何依感測器資料調整 fan PWM / fan target，並在異常時進入安全風速」。對伺服器 BMC 來說，Fan Control 不是單純把 PWM 寫到某個 sysfs 檔案，而是由 host power state、thermal zone、sensor availability、fan tach feedback、presence、failsafe policy、Redfish / IPMI 顯示與事件紀錄共同組成的控制迴路。

本章目標：

- 建立 Fan Control / Thermal Policy 的共同資料路徑。
- 定義 Host Off、Boot、Host On、Failsafe 四種基本狀態。
- 說明 thermal zone、sensor group、fan group 與 policy 的關係。
- 說明 PID、stepwise、event-driven fan control 的適用情境。
- 建立 bring-up、debug、tuning、驗收 checklist。

#### 13.1 適用情境與控制目標

Fan Control 適用於下列場景：

```text
- BMC 需依 CPU / DIMM / VR / GPU / NVMe / PSU / ambient 溫度自動調整 fan speed
- Host off 時仍需維持 standby cooling
- Host boot 前後 thermal telemetry 尚未穩定，需要 boot airflow policy
- Sensor missing、tach lost、fan controller fail 時需進入 failsafe
- 系統需要在散熱、噪音、風扇壽命、功耗之間取得平衡
- 量產前需建立 thermal tuning baseline 與 acoustic baseline
```

Fan Control 的設計目標：

| 目標 | 說明 | 驗證方式 |
| :--- | :--- | :--- |
| 熱安全 | 所有關鍵元件溫度不超過規格 | stress test、thermal chamber、sensor log |
| 可預期 | 相同 sensor 條件下 fan target 一致 | log replay、固定負載測試 |
| 平順 | fan speed 不頻繁上下跳動 | fan PWM / RPM trend |
| 異常安全 | sensor 或 fan 異常時進入安全風速 | 拔 fan、mask sensor、停 service 測試 |
| 可除錯 | 可追蹤 input sensor、zone、controller、output | journal、D-Bus、policy log |
| 對外一致 | Redfish / IPMI / SEL 顯示與內部狀態一致 | API / SDR / SEL 驗證 |

#### 13.2 Fan Control 資料路徑

典型 Fan Control 資料流：

```text
Hardware Sensors
    ├── temperature: CPU / DIMM / VR / board / PSU / NVMe / GPU
    ├── fan tach: fan*_input
    ├── fan presence / fault GPIO
    └── host state: chassis state / power state
    ↓
Kernel / hwmon / IIO / PMBus
    ├── /sys/class/hwmon/hwmonX/temp*_input
    ├── /sys/class/hwmon/hwmonX/fan*_input
    └── /sys/class/hwmon/hwmonX/pwm*
    ↓
Sensor Daemons
    ├── dbus-sensors: FanSensor / HwmonTempSensor / PSUSensor / ADCSensor
    └── platform service: inventory / presence / host state
    ↓
D-Bus
    ├── /xyz/openbmc_project/sensors/temperature/...
    ├── /xyz/openbmc_project/sensors/fan_tach/...
    ├── /xyz/openbmc_project/control/...
    └── /xyz/openbmc_project/state/...
    ↓
Fan Control Policy
    ├── thermal zone mapping
    ├── PID / stepwise / event-driven policy
    ├── min / max / floor / ceiling
    ├── slew rate / hysteresis
    └── failsafe rule
    ↓
Output
    ├── PWM percentage
    ├── raw PWM value, e.g. 0~255
    ├── target RPM
    └── fan zone target
    ↓
Hardware Output
    ├── sysfs pwmN
    ├── D-Bus Control.FanPwm / FanSpeed target
    └── I2C fan controller register
    ↓
Feedback
    ├── fan tach RPM
    ├── Functional / Availability
    ├── phosphor-logging event
    ├── Redfish fan / thermal status
    └── IPMI SDR / SEL
```

Fan Control 常見有兩層閉迴路：

```text
Temperature loop:
    temperature sensor / margin sensor → thermal controller → target RPM or thermal output

Fan loop:
    fan tach RPM → fan controller → PWM output
```

若平台較簡單，也可以只有一層：

```text
Temperature sensor → stepwise table → PWM output
```

#### 13.3 Fan State Model

建議每個平台至少定義下列四種 fan state。這些 state 不一定要以同一個 daemon 的 enum 呈現，但在設計文件、test plan 與 debug log 中需能對齊。

| State | 觸發條件 | 建議行為 | 注意事項 |
| :--- | :--- | :--- | :--- |
| Host Off | Host power off、BMC standby | 使用最低安全 PWM 或 standby thermal policy | 仍需考慮 PSU、BMC SoC、NVMe backplane、retimer 等 standby 發熱源。 |
| Boot | Host power on transition、BIOS / OS telemetry 尚未穩定 | 給 boot floor，例如 50%~80% PWM 或固定 RPM | 避免 CPU / DIMM 尚未上報 telemetry 時 airflow 不足。 |
| Host On | Host running，主要 sensor 可讀 | 依 PID / stepwise / event policy 控制 | 正常閉迴路，需平衡散熱與噪音。 |
| Failsafe | sensor unavailable、tach lost、control write fail、host state unknown | 拉到 failsafe PWM / RPM，產生 event | Failsafe 值需足夠保護硬體，不建議為了噪音設太低。 |

狀態切換建議：

```text
BMC boot
    ↓
Offline / Init：先採安全預設 PWM
    ↓
Host Off：若 host off 且 standby sensors 正常
    ↓
Boot：host power transition 或 policy 要求預先提升 airflow
    ↓
Host On：sensor set 穩定且 control daemon ready
    ↓
Failsafe：任一必要條件失效
    ↓
Recover：必要 sensor / tach / control output 恢復後，依 hysteresis 與 hold time 回到前一狀態
```

狀態切換不宜只依單一 sensor value 判斷，建議同時納入：

- Host state / chassis state。
- 必要 sensor availability。
- Fan presence / tach validity。
- Control daemon 是否已載入 policy。
- 最近一次 PWM write 是否成功。
- 是否仍在 config reload / service shutdown 階段。

#### 13.4 Thermal Zone 設計

Thermal zone 是 fan policy 的核心。Zone 代表一組需要共同控制 airflow 的硬體區域，包含 input sensors、controlled fans、policy 與安全邊界。

常見 zone：

| Zone | Input sensors | Controlled fans | 典型目標 |
| :--- | :--- | :--- | :--- |
| CPU zone | CPU DTS / PECI / PLDM / margin | front fan bank / CPU fan | 保持 CPU margin 或 CPU temp 在 target 以下。 |
| DIMM zone | DIMM temp / memory controller temp | front fan bank | 防止 DIMM over temperature。 |
| VR zone | VR PMBus temp / power / current | front fan bank / local fan | 高負載時提升 airflow。 |
| PCIe / GPU zone | GPU temp / PCIe ambient / riser temp | GPU fan bank / chassis fan | 支援 high power add-in card。 |
| NVMe zone | NVMe composite temp / backplane temp | front fan / mid fan | 避免 drive throttle。 |
| PSU zone | PSU temp / PSU fan / inlet temp | PSU internal fan 或 chassis fan | 多數 PSU fan 由 PSU 自己控制，BMC 主要監控。 |
| Chassis ambient zone | inlet / outlet / board ambient | all chassis fans | 維持整機 airflow baseline。 |

Zone 設計欄位範本：

```text
Zone name: [待填]
Zone ID: [待填]
Controlled fans: [fan0, fan1, ...]
Input sensors: [CPU0_Temp, DIMM_A0_Temp, ...]
Required sensors: [待填]
Optional sensors: [待填]
Host state dependency: HostOff / Boot / HostOn / Always
Control algorithm: PID / Stepwise / Event-driven / Fixed
Min PWM / RPM: [待填]
Max PWM / RPM: [待填]
Failsafe PWM / RPM: [待填]
Slew rate up/down: [待填]
Hysteresis / hold time: [待填]
Recovery rule: [待填]
Owner: Thermal / BMC / HW
```

Zone 設計原則：

- 每個 fan 最好只有一個主要控制者，避免不同 daemon 同時寫同一個 PWM。
- 多個 zone 共享同一組 fan 時，通常取最大 fan request，避免某 zone 降速影響另一 zone。
- Required sensor 缺失應觸發 failsafe；optional sensor 缺失可標記 degraded 並使用 fallback。
- 若 sensor 來自 host telemetry，需定義 host off / host not ready 的 fallback 值。
- 若 fan bank 有冗餘設計，需定義單顆 fan fail 時的補償策略。

#### 13.5 OpenBMC Fan Control 架構選項

OpenBMC 常見 fan / thermal 相關元件如下：

| 元件 | 主要責任 | 常見輸入 | 常見輸出 |
| :--- | :--- | :--- | :--- |
| `dbus-sensors` FanSensor | 讀 fan tach，發佈 RPM sensor | hwmon `fan*_input` | `/xyz/openbmc_project/sensors/fan_tach/...` |
| `dbus-sensors` PwmSensor / control path | 暴露或寫入 PWM control | hwmon `pwm*` / config | D-Bus control 或 sysfs write |
| `phosphor-pid-control` | PID / stepwise thermal control | sensors、zones、D-Bus / JSON config | PWM / target RPM / zone output |
| `phosphor-fan-control` | event-driven fan control | events、groups、zones、D-Bus state | fan target / zone property / PWM request |
| `phosphor-fan-monitor` | fan health monitor | tach、presence、threshold | Functional、event、可選 power-off action |
| `phosphor-fan-presence` | fan presence detection | GPIO、tach、I2C | Inventory `Present` |
| `phosphor-state-manager` | host / chassis power state | host state | policy input |
| `bmcweb` | Redfish 顯示 | D-Bus sensor / inventory | Redfish thermal / fan resources |
| `phosphor-host-ipmid` | IPMI sensor / SEL | D-Bus sensor / event | SDR / SEL / OEM command |

常見選型：

```text
方案 A：phosphor-pid-control
    適合需要 PID / stepwise、zone-based thermal control、tuning log 的平台。

方案 B：phosphor-fan-control
    適合以事件、D-Bus state、timer、group condition 驅動 fan target 的平台。

方案 C：平台自訂 daemon
    適合有客製硬體控制器、特殊 redundancy、host co-processor 共同控制的情境。

方案 D：固定 PWM / fixed table
    適合 bring-up 初期或小型平台，但量產前仍需完成 abnormal path 驗證。
```

#### 13.6 PID Control 原理與參數

PID control 的目標是依誤差調整輸出，使溫度或 margin 接近目標值。Fan control 中常見有兩種 PID：

```text
Thermal PID:
    input  = temperature 或 margin
    output = target RPM 或 thermal output

Fan PID:
    input  = actual RPM
    output = PWM
```

常見參數：

| 參數 | 說明 | 調整方向 |
| :--- | :--- | :--- |
| `Kp` | 比例項，對目前誤差反應 | 太大容易震盪；太小反應慢。 |
| `Ki` | 積分項，補長期偏差 | 太大容易 windup；太小可能長期偏離 target。 |
| `Kd` | 微分項，對變化率反應 | 太大容易放大 sensor noise。 |
| sample time | 控制迴路週期 | 太短會增加 D-Bus / I2C loading; 太長反應慢。 |
| setpoint | 目標溫度、margin 或 RPM | 需依 component spec 與 thermal margin 設定。 |
| min output | 最低 fan request | 避免風量低於安全值或 fan stall。 |
| max output | 最高 fan request | 通常為 100% PWM 或 max RPM。 |
| slew rate | 每次允許變動幅度 | 降低噪音突變與 fan hunting。 |
| anti-windup | 限制積分累積 | 避免長時間高溫後降溫太慢。 |

Tuning 建議流程：

```text
1. 固定 PWM，建立溫度 / RPM / noise baseline。
2. 找出每個 zone 的最低安全 airflow。
3. 先只啟用 P，確認反應方向正確。
4. 加入小 Ki，修正長期偏差。
5. 視需要加入 Kd 或使用濾波降低 noise。
6. 設定 output min / max / slew rate。
7. 驗證負載 step up / step down。
8. 驗證 thermal chamber high ambient。
9. 驗證 fan fail / sensor fail / host telemetry missing。
10. 保存 tuning log 與版本。
```

PID 常見現象：

| 現象 | 可能方向 | 調整方向 |
| :--- | :--- | :--- |
| Fan speed 上下震盪 | `Kp` 太大、sample time 太短、sensor noise 大 | 降低 `Kp`、增加 hysteresis / filtering、放慢更新。 |
| 溫度長期高於 target | `Kp` / `Ki` 太小、min airflow 不足、zone mapping 錯 | 提高 `Kp` / `Ki`、檢查 fan bank 與 sensor mapping。 |
| 降溫後 fan 很久不降 | `Ki` windup、down slew rate 太低 | 加 anti-windup、調整 slew rate。 |
| 負載上升時反應慢 | sample time 太長、slew rate up 太小 | 縮短 sample time、提高 slew rate up。 |
| 低溫仍很吵 | min output 太高、failsafe 未解除、host state 錯 | 查 zone state、failsafe flag、host state。 |

#### 13.7 Stepwise / Table-based Fan Policy

Stepwise policy 使用溫度區間對應固定 fan output，適合早期 bring-up、小型平台、或不需要連續 PID 的 zone。

範例：

```text
CPU_Temp < 35°C       fan target = 25%
35°C ~ 45°C           fan target = 35%
45°C ~ 55°C           fan target = 50%
55°C ~ 65°C           fan target = 70%
65°C ~ 75°C           fan target = 90%
> 75°C                fan target = 100%
Sensor unavailable    fan target = failsafe
```

Stepwise 設計重點：

- 每個 step 需有 hysteresis，避免溫度在邊界附近時 fan speed 來回跳。
- 升速與降速可使用不同 threshold 或 hold time。
- 高溫區間 step 可以比較密，低溫區間 step 可以比較寬。
- 若多個 sensor 對同一 fan group 提出需求，通常取最大輸出。
- Stepwise table 需搭配 component spec、thermal chamber 與 acoustic tuning 資料。

#### 13.8 Event-driven Fan Control

Event-driven policy 適合處理非連續型條件，例如 host state、cable presence、fan tray presence、system type、service state、timer loop 或特定 D-Bus property 變化。

常見 trigger：

```text
- Host state 變為 Running
- Host state 變為 Off
- fan tray 插入 / 拔除
- sensor threshold alarm
- timer 每 2 秒重新計算 target
- thermal mode 切換，例如 Acoustic / Balanced / Performance
- system type / SKU / cooling type 不同
- redundancy lost
```

常見 action：

```text
- 設定 zone floor
- 設定 target RPM
- 設定 PWM percent
- 提高 failsafe percent
- 記錄 event
- 更改 thermal profile
- 將 zone 標記為 degraded
```

Event-driven policy 和 PID / stepwise 可以並存。常見方式是 Event policy 設定 floor / ceiling / profile，PID 或 stepwise 依 sensor 計算 target，最後取最大值或依優先序合併。

#### 13.9 Failsafe 設計

Failsafe 是 Fan Control 中最重要的安全路徑之一。Failsafe 不只代表 fan 全速，也代表「目前控制環境不完整，無法保證正常閉迴路判斷」。

常見 failsafe trigger：

```text
[ ] Required temperature sensor unavailable
[ ] Required margin sensor unavailable
[ ] Sensor value 為 NaN / 非有限值 / 超出合理範圍
[ ] Sensor timeout
[ ] Fan tach = 0
[ ] Fan tach 低於 lower critical threshold
[ ] Fan presence missing
[ ] PWM write failed
[ ] Fan controller I2C timeout
[ ] D-Bus object 消失
[ ] Entity Manager config reload 中
[ ] fan control daemon 啟動中或即將停止
[ ] Host state unknown
[ ] Thermal zone config missing
[ ] Redundancy lost
```

Failsafe output 設計：

| 類型 | 說明 | 使用時機 |
| :--- | :--- | :--- |
| fixed failsafe PWM | 固定 100% 或指定百分比 | 最保守，適合早期 bring-up。 |
| zone failsafe percent | 每個 zone 有自己的 failsafe percent | 多 zone 平台，可降低不必要噪音。 |
| fan-specific failsafe | 特定 fan bank / fan tray 有不同 failsafe | airflow path 差異大的系統。 |
| offline failsafe | daemon reload / shutdown / offline 時採用 failsafe | 防止服務暫停時風速掉太低。 |
| strict failsafe | failsafe 時強制使用 failsafe percent | 適合要求明確安全行為的平台。 |

Failsafe recovery 建議：

```text
1. 確認 required sensors 恢復且連續 N 次有效。
2. 確認 tach feedback 恢復且高於最低門檻。
3. 確認 PWM write 成功。
4. 等待 hold time，避免立即降速。
5. 逐步降低 fan speed，不要直接跳回低速。
6. 記錄 recovery event，便於追蹤。
```

#### 13.10 Thermal Mode / Fan Profile

許多平台會提供多種 thermal profile：

| Profile | 目標 | 典型行為 |
| :--- | :--- | :--- |
| Acoustic | 低噪音 | 較低 floor、較慢升速、較高溫度目標。 |
| Balanced | 預設平衡 | 散熱與噪音折衷。 |
| Performance | 散熱優先 | 較高 floor、較快升速、較低溫度目標。 |
| Max Cooling | 最大散熱 | 固定高 PWM 或 100%。 |
| Service / Manufacturing | 工廠或維修 | 固定值或測試用 profile。 |

Profile 切換需定義：

```text
- 是否允許 Redfish / IPMI / OEM command 修改
- 是否跨 reboot 保存
- 是否受 host policy 限制
- 是否需要權限控管
- 切換時是否立即生效
- 切換失敗時 fallback profile
```

#### 13.11 設定檔與部署路徑

不同 OpenBMC 實作使用不同設定來源，需先確認平台採用哪套 fan control 架構。

`phosphor-pid-control` 常見設定來源：

```text
- D-Bus configuration：由 Entity Manager 提供 Pid / Pid.Zone / Stepwise 類型設定
- JSON configuration：預設 /usr/share/swampd/config.json，可用 --conf 指定其他路徑
```

JSON 概念範本：

```json
{
    "sensors": [
        {
            "name": "fan0",
            "type": "fan",
            "readPath": "/xyz/openbmc_project/sensors/fan_tach/Fan0",
            "writePath": "/sys/class/hwmon/hwmonX/pwm1",
            "min": 0,
            "max": 255,
            "timeout": 4,
            "ignoreDbusMinMax": true,
            "unavailableAsFailed": true
        },
        {
            "name": "CPU0_Temp",
            "type": "temp",
            "readPath": "/xyz/openbmc_project/sensors/temperature/CPU0_Temp",
            "timeout": 4,
            "unavailableAsFailed": true
        }
    ],
    "zones": [
        {
            "id": 0,
            "minThermalOutput": 3000.0,
            "failsafePercent": 100.0,
            "pids": ["CPU0_Thermal", "Fan0_Controller"]
        }
    ]
}
```

`phosphor-fan-control` 常見設定檔：

```text
/usr/share/phosphor-fan-presence/control/manager.json
/usr/share/phosphor-fan-presence/control/profiles.json
/usr/share/phosphor-fan-presence/control/fans.json
/usr/share/phosphor-fan-presence/control/zones.json
/usr/share/phosphor-fan-presence/control/groups.json
/usr/share/phosphor-fan-presence/control/events.json
```

平台 layer 建議：

```text
meta-<platform>/recipes-phosphor/fans/phosphor-fan-presence/...
meta-<platform>/recipes-phosphor/fans/phosphor-pid-control/...
meta-<platform>/recipes-phosphor/configuration/entity-manager/...
```

部署後需確認：

```bash
# 確認設定檔存在
ls -l /usr/share/swampd/config.json 2>/dev/null
ls -l /usr/share/phosphor-fan-presence/control/ 2>/dev/null

# 確認 package / service 是否進 image
systemctl list-units | grep -Ei 'fan|pid|thermal|swampd'
```

#### 13.12 Bring-up 步驟

建議從「固定風速」逐步導入完整策略，不要一開始就直接啟用複雜 PID。

```text
Step 1：確認硬體與線路
    [ ] fan power rail 正常
    [ ] PWM pin / tach pin / presence pin 接線正確
    [ ] PPR、PWM polarity、fan voltage、min RPM、max RPM 確認

Step 2：確認 kernel / sysfs
    [ ] /sys/class/hwmon/hwmonX/fan*_input 存在
    [ ] /sys/class/hwmon/hwmonX/pwm* 存在且可寫
    [ ] tach RPM 與外部量測一致

Step 3：確認 D-Bus sensor
    [ ] fan_tach sensor 出現在 D-Bus
    [ ] temperature sensors 出現在 D-Bus
    [ ] Availability / Functional 正確

Step 4：手動固定 PWM 測試
    [ ] 寫入 30%、50%、70%、100% PWM
    [ ] 確認 RPM 單調上升
    [ ] 確認最低 PWM 不會造成 fan stall

Step 5：建 inventory / presence / monitor
    [ ] Present 反映 fan tray 插拔
    [ ] tach lost 會標記 Functional=false
    [ ] event / SEL 可追蹤

Step 6：建立 thermal zone
    [ ] sensor group 與 fan group 對齊 airflow path
    [ ] required / optional sensor 分清楚
    [ ] min / max / failsafe 設定完成

Step 7：先導入 stepwise policy
    [ ] 升溫時 fan target 上升
    [ ] 降溫時 fan target 平順下降
    [ ] threshold / hysteresis 合理

Step 8：導入 PID policy
    [ ] Kp / Ki / Kd 初始值保守
    [ ] tuning log 開啟
    [ ] step load / unload 測試完成

Step 9：驗證 failsafe
    [ ] mask temperature sensor
    [ ] 拔 fan 或讓 fan tach = 0
    [ ] 停 fan control service
    [ ] config reload / daemon restart

Step 10：整合 Redfish / IPMI / Event
    [ ] Redfish fan / thermal status 正確
    [ ] IPMI sensor reading 正確
    [ ] SEL / Journal event 正確
```

#### 13.13 D-Bus / systemd 驗證指令

```bash
# Fan / thermal 相關 service
systemctl list-units | grep -Ei 'fan|pid|thermal|swampd'

# 常見 service 狀態
systemctl status phosphor-pid-control.service --no-pager 2>/dev/null || true
systemctl status phosphor-fan-control@0.service --no-pager 2>/dev/null || true
systemctl status phosphor-fan-monitor.service --no-pager 2>/dev/null || true
systemctl status phosphor-fan-presence-tach.service --no-pager 2>/dev/null || true

# Journal
journalctl -b | grep -Ei 'fan|pid|thermal|failsafe|swampd|tach|pwm'

# D-Bus sensor tree
busctl tree xyz.openbmc_project.ObjectMapper | grep -Ei 'fan|thermal|temperature|tach|pwm'

# Fan tach value
busctl get-property \
  xyz.openbmc_project.FanSensor \
  /xyz/openbmc_project/sensors/fan_tach/Fan0 \
  xyz.openbmc_project.Sensor.Value \
  Value

# Sensor availability / functional
busctl introspect \
  xyz.openbmc_project.FanSensor \
  /xyz/openbmc_project/sensors/fan_tach/Fan0
```

若 service name 不同，先用 ObjectMapper 查 owner：

```bash
busctl call xyz.openbmc_project.ObjectMapper \
  /xyz/openbmc_project/object_mapper \
  xyz.openbmc_project.ObjectMapper \
  GetSubTree sias \
  /xyz/openbmc_project/sensors 0 1 xyz.openbmc_project.Sensor.Value
```

#### 13.14 sysfs / 手動 PWM 驗證

手動 PWM 測試前需確認平台允許人工寫入 PWM，且沒有另一個 daemon 同時覆寫。建議先停止 fan control daemon，保留 fan monitor 或視測試目的調整。

```bash
# 找出 fan hwmon
for i in /sys/class/hwmon/hwmon*; do
    echo "$i: $(cat "$i/name" 2>/dev/null)"
done

HWMON=/sys/class/hwmon/hwmonX

# 讀 fan tach
cat $HWMON/fan1_input

# 查看 PWM
ls $HWMON/pwm*
cat $HWMON/pwm1

# 若平台支援 pwm enable
cat $HWMON/pwm1_enable 2>/dev/null

# 手動寫入 raw PWM；0~255 僅為常見範圍，實際需看 driver
for v in 80 128 180 220 255; do
    echo $v > $HWMON/pwm1
    sleep 5
    echo "pwm=$v rpm=$(cat $HWMON/fan1_input)"
done
```

手動測試注意事項：

- 先確認 fan 最低啟轉 PWM，避免低 duty 造成停轉。
- 測試中需持續監控關鍵溫度。
- 測試完成需恢復自動控制 daemon。
- 如果 fan controller 有 watchdog / automatic mode，需確認手動寫入是否會被硬體覆寫。
- 若 fan control service 會定期寫 PWM，手動值可能很快被改回。

#### 13.15 Redfish / IPMI / Event 驗證

Redfish：

```bash
# Thermal 舊路徑，視 bmcweb build option 而定
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>/Thermal

# 新版 ThermalSubsystem，視平台支援而定
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>/ThermalSubsystem
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>/ThermalSubsystem/Fans
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>/ThermalSubsystem/ThermalMetrics

# Sensor collection
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>/Sensors
```

IPMI：

```bash
ipmitool sdr list | grep -Ei 'fan|tach|temp|thermal'
ipmitool sensor | grep -Ei 'fan|tach|temp|thermal'
ipmitool sel list
```

Event 驗證項目：

```text
[ ] fan tach lower critical 會產生日誌或 SEL
[ ] fan removed 會更新 inventory Present
[ ] fan failed 會更新 Functional=false
[ ] required temp sensor unavailable 會進 failsafe
[ ] failsafe entry / recovery 有 journal 可追蹤
[ ] Redfish Status.Health 與內部狀態一致
[ ] IPMI sensor status 與 D-Bus threshold 狀態一致
```

#### 13.16 Thermal Tuning 與量測資料

Thermal tuning 建議保存下列資料：

```text
[ ] BMC image version / fan policy version
[ ] BIOS / host firmware version
[ ] CPLD / fan board firmware version
[ ] Fan vendor / model / PPR / max RPM
[ ] Ambient temperature
[ ] Host workload / power level
[ ] Sensor list 與取樣週期
[ ] PWM / RPM / temp trend
[ ] Acoustic measurement, if required
[ ] Power consumption
[ ] Throttle / PROCHOT / thermal event
[ ] Test duration
```

建議測試矩陣：

| 測試 | 條件 | 觀察重點 |
| :--- | :--- | :--- |
| Idle | Host OS idle | fan floor、噪音、低溫穩定度。 |
| CPU stress | CPU 100% | CPU temp / margin、fan response。 |
| Memory stress | DIMM workload | DIMM temp、front fan response。 |
| GPU / PCIe stress | 高功耗 add-in card | PCIe / GPU zone airflow。 |
| NVMe stress | drive read/write | drive temp、backplane airflow。 |
| High ambient | thermal chamber | max fan、是否 throttle。 |
| Fan fail | 拔 fan / 遮斷 tach | failsafe、event、冗餘補償。 |
| Sensor fail | mask sensor / stop daemon | failsafe、recovery。 |
| AC cycle | cold boot | boot fan policy。 |
| Service restart | restart fan service | offline failsafe、recovery。 |

Thermal tuning 建議輸出圖表：

```text
- time vs CPU/DIMM/VR/GPU/NVMe temperature
- time vs fan PWM
- time vs fan RPM
- time vs power
- time vs thermal margin
- event timeline
```

#### 13.17 進階除錯與常見陷阱

| 問題現象 | 可能方向 | 排查 / 解法 |
| :--- | :--- | :--- |
| Fan 一直全速 | Failsafe 未解除、required sensor missing、host state unknown、config parse fail | 查 journal、failsafe flag、ObjectMapper、sensor Availability。 |
| Fan 完全不轉 | PWM polarity 錯、fan power rail 未開、enable pin 錯、fan presence 判斷錯 | 查 sysfs pwm、示波器量 PWM、確認 fan power。 |
| RPM 讀值為 0 | tach pin / pull-up / PPR 錯、fan 未轉、driver channel 錯 | 查 fan*_input、示波器量 tach、確認 DTS channel。 |
| RPM 亂跳 | tach noise、PPR 錯、PWM 太低、fan 老化 | 增加濾波、提高 minimum PWM、比對外部轉速計。 |
| 溫度高但 fan 不升速 | zone mapping 錯、sensor 未列入 policy、profile 錯、host state 錯 | 查 zone config、policy log、D-Bus sensor path。 |
| fan speed 震盪 | PID 參數不穩、hysteresis 不足、sensor noise | 降低 Kp、調整 Ki/Kd、加入 hold time。 |
| 降溫後 fan 不降 | failsafe 未 recovery、Ki windup、down slew rate 太小 | 查 failsafe reason、PID log、anti-windup。 |
| 手動 PWM 被改回 | fan control daemon 仍在寫入、hardware auto mode | 暫停 daemon 或切 manual mode；確認 controller mode。 |
| Redfish 看不到 fan | association / inventory / bmcweb mapping 不完整 | 查 D-Bus sensor、inventory association、bmcweb log。 |
| IPMI SDR 缺 fan | sensor type / naming / sensor map 不完整 | 查 dbus-sdr、ipmid log、sensor path。 |
| service restart 後 fan 低速 | offline failsafe 未設定、service dependency 不完整 | 設 boot default PWM、offline failsafe、systemd ordering。 |

#### 13.18 Fan Control Porting 驗收 Checklist

```text
硬體 / 線路：
[ ] Fan power rail、PWM pin、tach pin、presence pin 確認
[ ] Fan vendor / model / PPR / min RPM / max RPM 確認
[ ] PWM polarity、frequency、duty range 確認
[ ] Fan tray / rotor / redundancy 設計確認
[ ] 示波器量測 PWM 與 tach waveform

Kernel / sysfs：
[ ] PWM / tach driver probe 正常
[ ] fan*_input 讀值合理
[ ] pwm* 可寫入且 fan RPM 有對應變化
[ ] pwm*_enable / automatic mode 行為確認
[ ] DTS channel 與實體 fan 對應正確

D-Bus / Inventory：
[ ] fan_tach sensor path 正確
[ ] temperature sensor path 正確
[ ] Fan inventory Present 正確
[ ] Fan Functional 正確
[ ] Availability 與 sensor missing 行為正確

Policy / Control：
[ ] Host Off policy 完成
[ ] Boot policy 完成
[ ] Host On PID / stepwise policy 完成
[ ] Failsafe trigger 與 output 完成
[ ] Zone mapping 完成
[ ] Fan group / sensor group 完成
[ ] min / max / floor / ceiling 完成
[ ] slew rate / hysteresis / hold time 完成
[ ] profile / thermal mode 完成

異常測試：
[ ] 拔 fan 進入 fault / failsafe
[ ] tach lost 進入 fault / failsafe
[ ] required temp sensor missing 進入 failsafe
[ ] control daemon restart 時 fan 維持安全風速
[ ] config reload 後 policy 正常恢復
[ ] host state unknown 時採安全策略

對外介面：
[ ] Redfish Thermal / ThermalSubsystem / Sensors 顯示正確
[ ] IPMI SDR / sensor reading 正確
[ ] SEL / journal event 正確
[ ] fan fail / recovery event 可追蹤

Tuning / 量產：
[ ] idle / stress / high ambient 測試完成
[ ] acoustic baseline 完成
[ ] thermal tuning log 保存
[ ] policy version 與 image version 對齊
[ ] AC cycle / DC cycle / BMC reboot 測試完成
```

#### 13.19 Fan Control 資料表範本

| Zone | Fan Group | Fan | PWM Channel | Tach Channel | PPR | Min PWM | Max PWM | Min RPM | Max RPM | Required Sensors | Optional Sensors | Failsafe PWM | Profile | 備註 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| CPU Zone | Front Bank | Fan0 | pwm1 | fan1_input | [待填] | [待填] | [待填] | [待填] | [待填] | CPU0_Temp | Inlet_Temp | 100% | Balanced | [待填] |
| CPU Zone | Front Bank | Fan1 | pwm2 | fan2_input | [待填] | [待填] | [待填] | [待填] | [待填] | CPU0_Temp | Inlet_Temp | 100% | Balanced | [待填] |
| DIMM Zone | Front Bank | Fan2 | pwm3 | fan3_input | [待填] | [待填] | [待填] | [待填] | [待填] | DIMM_A0_Temp | Inlet_Temp | 100% | Balanced | [待填] |

#### 13.20 本章參考資料

- OpenBMC phosphor-pid-control: https://github.com/openbmc/phosphor-pid-control
- OpenBMC phosphor-pid-control configure.md: https://github.com/openbmc/phosphor-pid-control/blob/master/configure.md
- OpenBMC phosphor-pid-control tuning.md: https://github.com/openbmc/phosphor-pid-control/blob/master/tuning.md
- OpenBMC phosphor-fan-presence: https://github.com/openbmc/phosphor-fan-presence
- OpenBMC phosphor-fan-presence control configuration: https://github.com/openbmc/phosphor-fan-presence/blob/master/docs/control/README.md
- OpenBMC dbus-sensors: https://github.com/openbmc/dbus-sensors
- OpenBMC bmcweb Redfish implementation: https://github.com/openbmc/bmcweb

### 14. Power Control

本章整理 BMC 平台的 Power Control porting 與驗證方法。Power Control 不是單一 GPIO 問題，而是由 standby power、CPLD / FPGA / PMIC、BMC GPIO、PCH / SoC sideband、BIOS / UEFI、OpenBMC state manager、Redfish / IPMI 與事件紀錄共同構成的跨層流程。Bring-up 時若只看某一個 D-Bus property 或某一條 GPIO，容易漏掉實際電源時序、硬體 latch、host reset、BMC reboot recovery 與 power restore policy 的互動。

本章目標：

- 建立 BMC、CPLD、BIOS / UEFI 在 power control 上的責任邊界。
- 定義 chassis power、host power、BMC state、power button、reset、NMI、power policy 的資料路徑。
- 說明 OpenBMC 中 `phosphor-state-manager`、`x86-power-control`、systemd targets、D-Bus、Redfish / IPMI 的整合方式。
- 提供 porting 步驟、測試矩陣、常見問題與 checklist。

#### 14.1 Power Control 的基本概念

Power Control 在 BMC 系統中通常分成四層：

```text
管理介面層
    Redfish / IPMI / WebUI / CLI / automation
        ↓
OpenBMC 狀態層
    phosphor-state-manager / x86-power-control / platform power daemon
        ↓
硬體控制層
    GPIO / CPLD register / PMBus / PMIC / sequencer / eSPI sideband
        ↓
實體電源層
    standby rail / main rail / PGOOD / reset / PWRBTN / SLP_Sx / PLTRST / RSMRST
```

常見 power control 指令：

| 指令 | 語意 | 常見路徑 | 注意事項 |
| :--- | :--- | :--- | :--- |
| Power On | 開啟 chassis 或 host | Redfish / IPMI → D-Bus transition → power daemon → GPIO / CPLD | 需確認 standby rail、BMC Ready、CPLD ready、fault latch |
| Graceful Shutdown | 讓 host OS 正常關機 | Redfish / IPMI → host transition → ACPI / power button pulse | 需要 host OS 支援；timeout 後是否 force off 需定義 |
| Force Off | 強制關閉主電 | D-Bus / IPMI → power button long press 或 CPLD off | 需記錄事件，避免與 graceful off 混淆 |
| Power Cycle | 先 off 再 on | state manager target 或 x86-power-control state machine | off dwell time、PGOOD drop、VR discharge 需符合硬體需求 |
| Reset / Warm Reboot | 不移除所有電源，只重置 host | RESET_OUT、PLTRST、PCH reset path | 需區分 warm reset、cold reset、BMC reset |
| NMI | 對 host 送 Non-Maskable Interrupt | NMI_OUT 或 D-Bus NMI interface | 用於 crash dump / diagnostic，權限需受控 |
| BMC Reboot | 重啟 BMC | BMC state transition / systemctl reboot | 不應影響正在運作的 host |

#### 14.2 BMC / CPLD / BIOS 權責切分

x86 或伺服器平台常見權責如下：

| 元件 | 主要責任 | 常見訊號 / 介面 | Porting 注意事項 |
| :--- | :--- | :--- | :--- |
| BMC | 接收遠端 power command、更新 D-Bus state、驅動 PWRBTN / RESET / NMI、記錄事件 | GPIO、D-Bus、Redfish、IPMI、SEL | 不應直接取代 CPLD 的硬體保護；需遵守 policy 與 timeout |
| CPLD / FPGA | 硬體時序、rail enable、fault latch、reset gating、power button mux、watchdog | GPIO、I2C / LPC / eSPI register、interrupt | register map、clear rule、firmware version、預設值要記錄 |
| PMIC / Sequencer | power rail enable / power good 時序 | PMBus、GPIO、PGOOD | 需確認 rail dependency、PGOOD threshold、fault latch |
| PCH / CPU SoC | S-state、RSMRST、SLP_Sx、PLTRST、SMI/NMI、host reset | eSPI / LPC / GPIO sideband | 需與 BIOS / ME / PSP / AGESA 共同確認語意 |
| BIOS / UEFI | POST、boot progress、ACPI shutdown、inventory、host firmware log | POST_COMPLETE、boot progress、PLDM / IPMI / OEM | graceful shutdown、reset reason、boot complete 需對齊 |
| Host OS | 正常關機、重啟、crash dump | ACPI power button、NMI、OS watchdog | Graceful 與 Force 的差異需在測試中明確驗證 |

Power Control bring-up 時建議先用一張責任矩陣同步，不要讓 BMC、CPLD、BIOS 都試圖控制同一條訊號。

| 動作 / 狀態 | BMC | CPLD | BIOS / Host | 驗證方式 |
| :--- | :--- | :--- | :--- | :--- |
| PWRBTN pulse | 產生 pulse 或請 CPLD 產生 | mux / gate / debounce | 接收 ACPI event | LA 量測 PWRBTN 與 SLP_Sx |
| Force off | 下指令與記錄事件 | 拉電源 enable / long press / fault gate | 可能無法正常處理 | PGOOD drop、host off、SEL |
| Power restore | 讀 policy 並發 transition | AC restore state / latch | BIOS AC policy 需避免衝突 | AC cycle 測試 |
| Fault latch | 讀取並上報 | latch fault bit | 依平台回報 | CPLD dump + EventLog |
| BMC reset recovery | 重新 discover state | 維持 host power | host 持續運作 | BMC reboot while host on |

#### 14.3 OpenBMC Power Control 架構

OpenBMC 常見有兩種互補角色：

1. `phosphor-state-manager`：負責 BMC、Chassis、Host、Hypervisor 等 state object 的狀態追蹤與 transition request。它透過 D-Bus 對 Redfish / IPMI 等外部協定暴露目前狀態與要求的 transition，並大量使用 systemd targets 驅動電源動作。
2. `x86-power-control` 或平台 power daemon：負責實際 GPIO / eSPI / CPLD sideband 的監控與控制，維護 host power state machine，並將硬體事件與軟體 request 轉成具體電源動作。

典型資料流：

```text
Redfish Reset / IPMI chassis power command / obmcutil
    ↓
D-Bus RequestedPowerTransition / RequestedHostTransition
    ↓
phosphor-state-manager
    ↓
systemd target
    ├── obmc-chassis-poweron@0.target
    ├── obmc-chassis-poweroff@0.target
    ├── obmc-host-startmin@0.target
    └── obmc-host-stop@0.target
    ↓
platform power service / x86-power-control / CPLD service
    ↓
GPIO / CPLD / PMBus / eSPI
    ↓
PWRBTN / RESET / NMI / PGOOD / SLP_Sx / PLTRST / POST_COMPLETE
    ↓
state update / event log / Redfish / IPMI response
```

`phosphor-state-manager` 常見 state：

| Object | Current state | Requested transition | systemd targets / 補充 |
| :--- | :--- | :--- | :--- |
| BMC | `NotReady`、`Ready`、`Quiesced` | `Reboot` | 監看 `multi-user.target` 與 quiesce target |
| Chassis | `On`、`Off`、`BrownOut`、`UninterruptiblePowerSupply` | `On`、`Off`、`PowerCycle` | 常見 `obmc-chassis-poweron@.target`、`obmc-chassis-poweroff@.target` |
| Host | `Off`、`Running`、`TransitioningToRunning`、`TransitioningToOff`、`Quiesced`、`DiagnosticMode` | `Off`、`On`、`Reboot`、`GracefulWarmReboot`、`ForceWarmReboot` | 常見 `obmc-host-startmin@.target`、`obmc-host-stop@.target`、`obmc-host-quiesce@.target` |

`x86-power-control` 常見能力：

- BMC 內部維護 Host state machine。
- 支援 hard power on / off / cycle 與 soft power on / off / cycle。
- 可用 JSON 配置 GPIO 或 D-Bus 型訊號。
- 監控 power button、reset button、NMI / ID button、PowerOk、SIO power good、S5、POST complete 等訊號。
- 控制 PowerOut、ResetOut、NMIOut、SIO on control 等輸出。
- 依平台 feature 可使用 PLTRST 類訊號判斷 warm reset。

#### 14.4 重要電源訊號與語意

Power Control 的第一步是把每條訊號的硬體語意寫清楚。

| 類型 | 常見訊號 | 方向 | 用途 | 常見風險 |
| :--- | :--- | :--- | :--- | :--- |
| Standby power | `P3V3_AUX`、`P1V8_AUX`、`BMC_STBY_PGOOD` | HW → BMC/CPLD | BMC / CPLD standby ready | standby 未穩但 BMC 已讀 GPIO |
| Main rail enable | `MAIN_PWR_EN`、`S0_EN`、`PS_ON_N` | BMC/CPLD → Power | 開主電 | active low / open drain 語意錯 |
| Power good | `PS_PWROK`、`SIO_POWER_GOOD`、`PWRGD_CPU` | Power/CPLD/PCH → BMC | 判斷 power on 是否成功 | debounce、latched fault、PGOOD drop 太短 |
| Power button | `PWRBTN_N`、`POWER_OUT` | BMC/CPLD → PCH | 模擬按電源鍵 | pulse width、mux owner、長按行為 |
| Reset | `RSTBTN_N`、`RESET_OUT`、`PLTRST_N` | BMC/CPLD/PCH | host reset / warm reset | reset domain 混淆 |
| Sleep state | `SLP_S3_N`、`SLP_S4_N`、`SLP_S5_N`、`SIO_S5` | PCH → BMC/CPLD | 判斷 host sleep / off state | 不同 chipset 語意差異 |
| Resume reset | `RSMRST_N` | PCH/CPLD | PCH resume well reset | 上電時序與 BIOS 關聯高 |
| POST / boot | `POST_COMPLETE`、boot progress | BIOS/PCH → BMC | 判斷 host boot 完成或 warm reset | BIOS 未支援或 reset 時電位行為不同 |
| NMI | `NMI_OUT` | BMC/CPLD → PCH/CPU | 觸發 crash dump / diagnostic | 權限與誤觸發風險 |
| Fault latch | `VR_FAULT`、`THERMTRIP`、`OC_FAULT` | CPLD/PMIC → BMC | 阻止上電或記錄故障 | clear rule 與事件嚴重度需定義 |

建議量測欄位：

| Signal | SoC pin / GPIO line | Owner | Active | Default | Pull | Source / Sink | Debounce | Boot risk | 備註 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `PWRBTN_N` | `[待填]` | BMC/CPLD | Low pulse | High | Pull-up | BMC → PCH | `[待填]` | 誤觸發 host power | `[待填]` |
| `PS_PWROK` | `[待填]` | CPLD/PCH | High = OK | Low | `[待填]` | HW → BMC | `[待填]` | state 判斷錯 | `[待填]` |
| `PLTRST_N` | `[待填]` | PCH | High = deassert | Low | `[待填]` | PCH → BMC | `[待填]` | warm reset 判斷 | `[待填]` |

#### 14.5 Power Sequence 與時間戳

Power sequence 必須用 LA / scope 與 journal 一起記錄。單看軟體 log 通常無法確認 rail enable 與 PGOOD 的真實順序。

建議資料：

```text
AC applied
    ↓
Standby rails valid
    ↓
BMC boot / CPLD ready
    ↓
BMC Ready / power policy evaluated
    ↓
Power On request
    ↓
PWRBTN pulse or CPLD MAIN_PWR_EN
    ↓
Main rails ramp
    ↓
PGOOD asserted
    ↓
RSMRST / PLTRST sequence
    ↓
BIOS POST starts
    ↓
POST_COMPLETE / host running
```

時間戳表：

| Event | Signal / source | Target time | Measured time | Pass criteria | 備註 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| AC applied | AC input | t0 | `[待填]` | baseline | `[待填]` |
| Standby PGOOD | `BMC_STBY_PGOOD` | `[待填]` | `[待填]` | stable | `[待填]` |
| BMC Ready | D-Bus BMC state | `[待填]` | `[待填]` | Ready before policy on | `[待填]` |
| Power request | Redfish / IPMI / D-Bus | `[待填]` | `[待填]` | request accepted | `[待填]` |
| PWRBTN asserted | `PWRBTN_N` | `[待填]` | `[待填]` | pulse width 合規 | `[待填]` |
| Main PGOOD | `PS_PWROK` | `[待填]` | `[待填]` | timeout 內 asserted | `[待填]` |
| PLTRST deassert | `PLTRST_N` | `[待填]` | `[待填]` | BIOS 可開始 POST | `[待填]` |
| POST complete | `POST_COMPLETE` / boot progress | `[待填]` | `[待填]` | host running | `[待填]` |

#### 14.6 Porting 步驟

##### Step 1：收集硬體與平台資料

```text
- Chassis power source：PSU / DC input / battery / UPS
- Standby rail 與 always-on domain
- Main rail enable / power good / fault 訊號清單
- PWRBTN / RESET / NMI 的訊號路徑與 owner
- SLP_Sx / RSMRST / PLTRST / POST_COMPLETE 的來源
- Power fault latch 與 clear rule
- CPLD / PMIC / sequencer register map
- AC restore policy 與 NVRAM / settings 儲存位置
- Power cycle 最小 off dwell time
- Graceful shutdown timeout 與 fallback force off policy
- Host running 判斷依據：PGOOD、POST_COMPLETE、PLTRST、host heartbeat、OS response
- BMC reboot while host on 的預期行為
```

##### Step 2：Device Tree / GPIO Line Name

Power GPIO 建議一律命名清楚，並避免與 sensor / presence GPIO 混淆。

```dts
&gpio0 {
    status = "okay";
    gpio-line-names =
        "POWER_BUTTON_N", "RESET_BUTTON_N", "NMI_BUTTON_N", "ID_BUTTON_N",
        "PS_PWROK", "SIO_POWER_GOOD", "SIO_S5", "POST_COMPLETE",
        "POWER_OUT", "RESET_OUT", "NMI_OUT", "SIO_ONCONTROL",
        "PLTRST_N", "RSMRST_N", "MAIN_PWR_EN", "CPLD_PWR_FAULT";
};
```

檢查：

```bash
gpioinfo | grep -E 'POWER|RESET|NMI|PWROK|PLTRST|RSMRST|POST'
gpioget gpiochip0 PS_PWROK
gpioget gpiochip0 PLTRST_N
```

若 x86-power-control 使用 line name，DTS 的 `gpio-line-names` 與 JSON `LineName` 必須一致。

##### Step 3：x86-power-control JSON 配置

若平台使用 `x86-power-control`，通常需提供 `power-config-host0.json` 或 host instance 對應檔案。訊號可用 GPIO 或 D-Bus 型定義。

GPIO 型訊號：

```json
{
  "Name": "PostComplete",
  "LineName": "POST_COMPLETE",
  "Type": "GPIO"
}
```

D-Bus 型訊號：

```json
{
  "Name": "PowerButton",
  "DbusName": "xyz.openbmc_project.Chassis.Event",
  "Path": "/xyz/openbmc_project/Chassis/Event",
  "Interface": "xyz.openbmc_project.Chassis.Event",
  "Property": "PowerButton_Host1",
  "Type": "DBUS"
}
```

常見訊號對照：

| `Name` | 常見 line name | 類型 | 說明 |
| :--- | :--- | :--- | :--- |
| `PowerButton` | `POWER_BUTTON_N` | Input | 實體 power button |
| `ResetButton` | `RESET_BUTTON_N` | Input | 實體 reset button |
| `NMIButton` | `NMI_BUTTON_N` | Input | 實體 NMI button |
| `IdButton` | `ID_BUTTON_N` | Input | Identify button |
| `PowerOk` | `PS_PWROK` | Input | Power supply OK |
| `SioPowerGood` | `SIO_POWER_GOOD` | Input | Super I/O power good |
| `SIOS5` | `SIO_S5` | Input | S5 / sleep state |
| `PostComplete` | `POST_COMPLETE` | Input | BIOS POST complete |
| `PowerOut` | `POWER_OUT` | Output | 模擬 power button / power control |
| `ResetOut` | `RESET_OUT` | Output | 模擬 reset |
| `NMIOut` | `NMI_OUT` | Output | 送 NMI 到 host |
| `SioOnControl` | `SIO_ONCONTROL` | Output | 平台 SIO power control |

配置注意事項：

- Polarity 必須與 schematic / CPLD register map 對齊。
- Output pulse width、force-off hold time、power cycle off dwell time 必須符合平台規格。
- 若訊號由 CPLD 代理，BMC 不一定直接控制 host pin，JSON 需指向 BMC 實際看到的 GPIO 或 D-Bus property。
- 多 host 平台需明確區分 `host0`、`host1` 的配置檔、D-Bus path 與 GPIO line。

##### Step 4：phosphor-state-manager 與 systemd targets

`phosphor-state-manager` 的設計是由 D-Bus RequestedTransition 觸發 systemd target，再由 target 內的 service 完成平台動作。Porting 時要確認 target dependency 與 service ordering。

常見 target：

```bash
systemctl list-units 'obmc-*power*' 'obmc-host*' 'obmc-chassis*'
systemctl cat obmc-chassis-poweron@0.target
systemctl cat obmc-chassis-poweroff@0.target
systemctl cat obmc-host-startmin@0.target
systemctl cat obmc-host-stop@0.target
```

關鍵檢查：

- requested transition 寫入後，對應 target 是否被啟動。
- target 內的 platform service 是否成功完成。
- 若 target 成功但硬體沒有變化，需回到 platform power service / GPIO / CPLD 檢查。
- 若硬體已 power on 但 D-Bus state 仍是 Off，需檢查 PGOOD / discover state / service state update。

##### Step 5：Power Restore Policy

Power restore policy 決定 AC loss、BMC reboot 或系統電源事件後是否自動恢復開機。常見策略：

| Policy | 說明 | 驗證方式 |
| :--- | :--- | :--- |
| Always Off | AC 回來後保持關機 | AC cycle 後確認 chassis off |
| Always On | AC 回來後自動開機 | AC cycle 後確認 power on sequence |
| Restore Previous | 回到 AC loss 前狀態 | on/off 各跑一次 AC cycle |
| No Change / platform default | 交由 CPLD / BIOS / platform policy | 需定義權威來源 |

注意事項：

- BMC policy、BIOS AC policy、CPLD AC restore strap 不應互相衝突。
- 若啟用 only-allow-boot-when-bmc-ready，需確認 BMC Ready timeout 與 PowerRestoreDelay。
- 若 BMC reboot 時 host 已 running，BMC 必須重新 discover 狀態，不應造成 host 掉電。

##### Step 6：Redfish / IPMI / CLI 對外介面

Redfish 常用：

```bash
# 查 Chassis / System power 狀態
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Systems/system
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/chassis

# Power on / ForceOff / GracefulShutdown / PowerCycle 等 ResetType 依平台支援而定
curl -k -u root:0penBmc \
  -H 'Content-Type: application/json' \
  -X POST \
  https://<bmc>/redfish/v1/Systems/system/Actions/ComputerSystem.Reset \
  -d '{"ResetType":"On"}'
```

IPMI 常用：

```bash
ipmitool -I lanplus -H <bmc> -U root -P 0penBmc chassis power status
ipmitool -I lanplus -H <bmc> -U root -P 0penBmc chassis power on
ipmitool -I lanplus -H <bmc> -U root -P 0penBmc chassis power off
ipmitool -I lanplus -H <bmc> -U root -P 0penBmc chassis power cycle
ipmitool -I lanplus -H <bmc> -U root -P 0penBmc chassis power reset
ipmitool -I lanplus -H <bmc> -U root -P 0penBmc sel list
```

OpenBMC CLI / D-Bus：

```bash
obmcutil state
obmcutil poweron
obmcutil poweroff
obmcutil powercycle

busctl tree xyz.openbmc_project.State.Host
busctl tree xyz.openbmc_project.State.Chassis
busctl get-property \
  xyz.openbmc_project.State.Chassis \
  /xyz/openbmc_project/state/chassis0 \
  xyz.openbmc_project.State.Chassis \
  CurrentPowerState
busctl get-property \
  xyz.openbmc_project.State.Host \
  /xyz/openbmc_project/state/host0 \
  xyz.openbmc_project.State.Host \
  CurrentHostState
```

#### 14.7 Bring-up 驗證流程

建議依下列順序驗證，避免一開始直接測 Redfish power cycle 而難以判讀。

##### Phase 1：硬體原始訊號

```bash
gpioinfo
gpioget gpiochip0 PS_PWROK
gpioget gpiochip0 SIO_POWER_GOOD
gpioget gpiochip0 SIO_S5
gpioget gpiochip0 POST_COMPLETE
```

同步用 LA / scope 量測：

```text
PWRBTN_N
MAIN_PWR_EN
PS_PWROK
RSMRST_N
PLTRST_N
SLP_S5_N
POST_COMPLETE
RESET_OUT
```

##### Phase 2：service 與 D-Bus

```bash
systemctl status phosphor-host-state-manager.service
systemctl status phosphor-chassis-state-manager.service
systemctl status 'xyz.openbmc_project.Chassis.Control.Power@0.service'
journalctl -u phosphor-host-state-manager.service -b --no-pager
journalctl -u phosphor-chassis-state-manager.service -b --no-pager
journalctl -u 'xyz.openbmc_project.Chassis.Control.Power@0.service' -b --no-pager
busctl tree xyz.openbmc_project.State.Host
busctl tree xyz.openbmc_project.State.Chassis
```

##### Phase 3：單一動作驗證

| 測試 | 前置狀態 | 動作 | 預期結果 | 需收集 |
| :--- | :--- | :--- | :--- | :--- |
| Power On | AC on、host off | Redfish / IPMI power on | PGOOD on、host running | journal、D-Bus、LA |
| Graceful Off | host OS running | Graceful shutdown | OS 正常關機、PGOOD off | OS log、timeout、EventLog |
| Force Off | host running | ForceOff | PGOOD off、事件記錄 | PWRBTN long press / CPLD off |
| Power Cycle | host running | PowerCycle | PGOOD drop 後重新 on | off dwell time、POST |
| Reset | host running | Reset / WarmReboot | PLTRST 或 reset pulse，PGOOD 不一定 drop | PLTRST、POST_COMPLETE |
| NMI | host running | NMI | host crash dump / diagnostic | OS / BIOS / BMC log |
| BMC Reboot | host running | BMC reboot | host 不掉電，BMC 回來後 state 正確 | PGOOD、D-Bus state |
| AC Cycle | host on/off 各一次 | 移除 AC 再恢復 | 符合 restore policy | LA、journal、EventLog |

##### Phase 4：長測與壓力測試

```text
[ ] power on/off 100 cycles
[ ] power cycle 100 cycles
[ ] graceful shutdown + force fallback
[ ] BMC reboot while host running 50 cycles
[ ] AC cycle with RestorePolicy=AlwaysOn / AlwaysOff / Previous
[ ] CPLD fault injection
[ ] PGOOD glitch injection（若硬體可支援）
[ ] Redfish / IPMI 同時發 request 的互斥測試
[ ] Host boot hang / POST timeout 測試
```

#### 14.8 Power Fault 與異常處理

Power fault 不建議只用「power on failed」統稱，需保留可追溯的 fault source。

| 類型 | 可能來源 | 建議處理 |
| :--- | :--- | :--- |
| PGOOD timeout | PSU、VR、PMIC、CPLD、short | 停止 power on、讀 CPLD / PMIC fault、記錄 EventLog |
| BrownOut | 輸入電源不足或 rail drop | Chassis 狀態可標示 BrownOut，避免持續 retry |
| VR fault | VR PMBus STATUS_WORD、CPLD latch | 上報 fault sensor，必要時阻止再次 power on |
| Thermal trip | PROCHOT / THERMTRIP / CPLD latch | 強制關機並記錄 thermal event |
| Power button stuck | GPIO 長時間 asserted | 記錄 button fault，避免重複 power transition |
| Reset stuck | PLTRST / RSMRST 不釋放 | 標示 host boot failure，保存 timing |
| POST timeout | BIOS 未完成 POST | 記錄 boot failure，收集 POST code / BIOS log |
| BMC service fail | state manager 或 power daemon failed | 進入保守狀態，不任意切換 host power |

事件紀錄建議包含：

```text
- Time / monotonic timestamp
- Requested transition
- Previous state / current state
- Fault signal raw value
- CPLD / PMIC register dump
- Power policy
- BMC / CPLD / BIOS version
- Redfish / IPMI requester（若可取得）
```

#### 14.9 常見問題與排查

| 問題現象 | 可能方向 | 建議檢查 |
| :--- | :--- | :--- |
| Redfish power on 回成功但主機沒上電 | D-Bus target 成功但 GPIO / CPLD 未動作 | 查 systemd target、power daemon log、LA 量測 PWRBTN / MAIN_PWR_EN |
| IPMI power status 與實際不符 | PGOOD / S-state 判斷來源錯 | 比對 `PS_PWROK`、`SIO_S5`、D-Bus state |
| Power button pulse 產生但 host 無反應 | pulse width、polarity、mux owner、PCH power domain | LA 量測 PWRBTN_N；確認 CPLD mux / BIOS setting |
| Force off 不會斷電 | 長按時間不足、CPLD gate、PS_ON_N 路徑錯 | 量測 long press、PS_ON_N、MAIN_PWR_EN |
| Power cycle 太快導致下一次開機失敗 | off dwell time 不足、VR 未放電 | 增加 cycle off delay；量測 rail discharge |
| BMC reboot 後 state 顯示 Off 但 host 仍 running | discover state 不完整 | 檢查 PGOOD query、`/run/openbmc/chassis@0-on` 邏輯、state manager log |
| AC restore 行為不符 | BMC policy、BIOS policy、CPLD strap 衝突 | 逐一固定 policy 測試；記錄權威來源 |
| Graceful shutdown 永遠 timeout | Host OS 沒處理 ACPI power button | 檢查 OS log、BIOS ACPI、power button event |
| POST_COMPLETE 不變 | BIOS 未驅動、GPIO polarity 錯、reset 行為不同 | 改用 PLTRST / boot progress / host heartbeat 交叉確認 |
| PGOOD 抖動導致 state 反覆變化 | 訊號雜訊或 debounce 不足 | scope 量測；加 debounce / filter / CPLD latch |
| power daemon 啟動失敗 | JSON line name 不存在或 schema 不符 | `journalctl -u xyz.openbmc_project.Chassis.Control.Power@0.service` |
| 多 host 控錯節點 | instance / GPIO / Redfish path 對錯 | 檢查 host index、config file、D-Bus path |

建議排查順序：

```text
1. 先確認 hardware raw signal：GPIO / CPLD / LA / scope
2. 確認 kernel 看得到 GPIO line name 與正確 value
3. 確認 power daemon 配置與 service log
4. 確認 phosphor-state-manager state 與 systemd target
5. 確認 Redfish / IPMI 對外狀態
6. 最後才判斷 policy / BIOS / OS 行為
```

#### 14.10 Power Control Checklist

```text
硬體 / CPLD：
[ ] Power sequence 文件已取得
[ ] Standby rail、main rail、PGOOD、reset、PWRBTN、SLP_Sx、PLTRST、RSMRST mapping 完成
[ ] CPLD / PMIC / sequencer register map 完成
[ ] Fault latch 與 clear rule 已定義
[ ] Power button / reset / NMI owner 與 mux path 確認
[ ] Active high / active low 與 pull resistor 確認
[ ] Power cycle off dwell time 確認
[ ] Graceful shutdown timeout 與 force fallback policy 確認

Device Tree / Kernel：
[ ] GPIO line name 完整定義
[ ] pinctrl 設定正確且無衝突
[ ] GPIO expander / CPLD / PMBus driver probe 正常
[ ] gpioget 可讀到 PGOOD / S-state / POST / reset 狀態
[ ] dmesg 無關鍵 GPIO / I2C / PMBus probe error

OpenBMC service：
[ ] phosphor-state-manager 相關 service 啟動正常
[ ] x86-power-control 或平台 power daemon 啟動正常
[ ] power-config-hostX.json 與 DTS line name 一致
[ ] systemd targets dependency 與 ordering 正確
[ ] D-Bus CurrentPowerState / CurrentHostState 正確
[ ] Requested transition 可觸發對應 target
[ ] BMC reboot while host on 後可重新 discover state

Redfish / IPMI：
[ ] Redfish Systems Reset action 支援平台預期 ResetType
[ ] IPMI chassis power on/off/cycle/reset/status 正確
[ ] Power fault / transition event 有 journal / EventLog / SEL
[ ] 多使用者或併發 request 有互斥保護

驗證 / 量測：
[ ] Power on timing 完成量測
[ ] Power off timing 完成量測
[ ] Power cycle timing 完成量測
[ ] Reset / warm reboot timing 完成量測
[ ] AC cycle + restore policy 完成驗證
[ ] BMC reboot while host running 完成驗證
[ ] Fault injection / PGOOD timeout 完成驗證
[ ] 長測 cycle 數與版本資訊已記錄
```

#### 14.12 本章參考資料

- OpenBMC phosphor-state-manager README：<https://grok.openbmc.org/raw/openbmc/phosphor-state-manager/README.md>
- OpenBMC phosphor-state-manager repository：<https://github.com/openbmc/phosphor-state-manager>
- OpenBMC x86-power-control README：<https://github.com/openbmc/x86-power-control>
- OpenBMC x86-power-control 架構說明：<https://deepwiki.com/openbmc/x86-power-control>
- phosphor-dbus-interfaces state definitions：<https://github.com/openbmc/phosphor-dbus-interfaces>
- DMTF Redfish ComputerSystem Reset schema：<https://redfish.dmtf.org/schemas/>
- IPMI v2.0 specification：Chassis Control / Chassis Status commands

### 15. Inventory / FRU / Asset 資料模型

本章整理 BMC 平台中 Inventory、FRU、Asset、VPD、Field Replaceable Unit EEPROM、Entity Manager、D-Bus inventory object、Redfish Chassis / Systems / Components 與 IPMI FRU / SDR 的資料模型與排查方法。Inventory 不是單純的「清單」，而是 BMC 對實體硬體拓樸、可插拔元件、製造資訊、序號、料號、版本、位置、presence、functional 狀態與 sensor / power / thermal association 的共同資料基準。

Inventory / FRU / Asset 問題常見現象包含：Redfish inventory 缺件、IPMI FRU 顯示欄位不一致、FRU EEPROM 讀不到、序號 / product name 跟標籤不一致、PSU / fan / riser 插拔後狀態不更新、Entity Manager probe 不匹配、D-Bus object path 改名導致 bmcweb / ipmid / sensor daemon 找不到 association、factory reset 後資產資料消失、量產燒錄資料被 FW update 覆蓋。

本章的目標是把「資料權威端」、「欄位對映」、「OpenBMC D-Bus object」、「Redfish / IPMI 對外呈現」、「動態 presence」、「製造寫入」、「資料保存」、「log 收集」與「驗收 checklist」串在一起，避免不同團隊各自維護一份名稱與序號資料。

#### 15.1 基本名詞與資料邊界

<table>
<tr><th>名詞</th><th>說明</th><th>BMC porting 關注點</th></tr>
<tr><td>Inventory</td><td>BMC 內部對實體元件與拓樸的表示，通常由 D-Bus object 與 associations 組成</td><td>object path、interface、Present / Functional、containment、sensor association</td></tr>
<tr><td>FRU</td><td>Field Replaceable Unit，可現場更換的元件及其識別資料</td><td>EEPROM 格式、I2C path、IPMI FRU 欄位、Redfish Asset 欄位</td></tr>
<tr><td>Asset</td><td>資產識別資料，例如 Manufacturer、Model、PartNumber、SerialNumber、AssetTag</td><td>資料權威端、製造寫入、更新是否保留</td></tr>
<tr><td>VPD</td><td>Vital Product Data，平台或元件的重要製造 / 識別資料</td><td>來源可能是 EEPROM、BIOS table、CPLD、NVRAM、provisioning file</td></tr>
<tr><td>Presence</td><td>實體是否存在</td><td>來源可能是 GPIO、FRU EEPROM ACK、PMBus ACK、CPLD bit、MCTP discovery</td></tr>
<tr><td>Functional</td><td>存在且功能狀態可用</td><td>PSU present 但 fault、fan present 但 tach fail，都應與 Present 分開描述</td></tr>
<tr><td>Association</td><td>D-Bus object 之間的關係，例如 contained_by、inventory、sensors</td><td>Redfish / IPMI / policy 常依賴 association 找到元件關係</td></tr>
<tr><td>Probe</td><td>Entity Manager 用來判斷某 entity 是否存在或適用的規則</td><td>Probe source、比對欄位、SKU / FRU 差異、熱插拔更新</td></tr>
</table>

建議先定義每一類資料的權威端：

<table>
<tr><th>資料類型</th><th>可能權威端</th><th>不建議作法</th><th>備註</th></tr>
<tr><td>Baseboard 序號</td><td>Baseboard FRU EEPROM / manufacturing provisioning</td><td>同時在 EEPROM、JSON、Redfish override 各放不同值</td><td>需和機身標籤 / 工廠系統一致</td></tr>
<tr><td>Chassis AssetTag</td><td>Factory database / user writable setting</td><td>FW update 時重設為預設值</td><td>若允許使用者修改，需定義保存位置</td></tr>
<tr><td>PSU inventory</td><td>PSU FRU / PMBus MFR commands</td><td>只用 slot 名稱推測 model / serial</td><td>PSU absent 時需移除或標 unavailable</td></tr>
<tr><td>Fan tray inventory</td><td>FRU EEPROM / GPIO presence + static config</td><td>fan absent 仍保留舊序號且 Present=true</td><td>需處理熱插拔與 debounce</td></tr>
<tr><td>CPU / DIMM inventory</td><td>BIOS SMBIOS / host firmware / PECI / SPD</td><td>BMC static JSON 與 host 實際裝置不同步</td><td>host off 時資料可用性需定義</td></tr>
<tr><td>Riser / PCIe device</td><td>GPIO ID、FRU EEPROM、MCTP / PLDM、BIOS table</td><td>只依 SKU 假設固定存在</td><td>需支援不同 riser 組合</td></tr>
<tr><td>CPLD / FPGA version</td><td>CPLD register / update manifest</td><td>手寫在 JSON 但未隨更新改變</td><td>需與 update service 對齊</td></tr>
</table>

#### 15.2 OpenBMC Inventory 架構

OpenBMC inventory 通常由多個 daemon 共同建立，並透過 D-Bus object 暴露。常見資料流如下：

```text
FRU EEPROM / GPIO / PMBus / SMBIOS / MCTP / static JSON
    ↓
fru-device / Entity Manager / platform daemon / host inventory daemon
    ↓
D-Bus inventory object
    /xyz/openbmc_project/inventory/...
    ↓
phosphor-dbus-interfaces inventory item interfaces
    Present / PrettyName / Asset / Chassis / Board / PowerSupply / Fan / Dimm ...
    ↓
ObjectMapper / associations
    ↓
bmcweb Redfish / phosphor-host-ipmid / sensor daemon / logging / policy
```

OpenBMC `entity-manager` 的設計目標是把實體元件對映到 BMC 上的軟體資源，並降低新平台移植時需要維護的客製差異；它使用 Entity、Exposes、Probe 等概念描述硬體與其可提供的功能。`fru-device` 是常見 detection daemon，會掃描可用 I2C bus 上的 IPMI FRU EEPROM，並把解析結果提供給 D-Bus，供 Entity Manager 與其他 consumer 使用。

常見元件與職責：

<table>
<tr><th>元件 / service</th><th>主要職責</th><th>常見輸入</th><th>常見輸出 / 消費者</th></tr>
<tr><td>fru-device</td><td>掃描 I2C FRU EEPROM、解析 IPMI FRU 格式、發布 FRU 欄位</td><td>I2C EEPROM、baseboard FRU file、blocklist</td><td>Entity Manager、inventory object、debug CLI</td></tr>
<tr><td>Entity Manager</td><td>依 Probe 與 JSON config 建立 entity / exposes / inventory</td><td>FRU D-Bus、GPIO presence、static JSON、schema</td><td>sensor daemons、inventory manager、policy daemons</td></tr>
<tr><td>phosphor-dbus-interfaces</td><td>定義標準 D-Bus inventory interface</td><td>YAML interface definitions</td><td>sdbusplus binding、service contracts</td></tr>
<tr><td>ObjectMapper</td><td>提供 object path、service、interface 查找</td><td>D-Bus object registrations</td><td>bmcweb、ipmid、sensor daemon、debug</td></tr>
<tr><td>platform inventory daemon</td><td>處理平台客製來源，例如 CPLD、GPIO ID、MCTP discovery</td><td>CPLD register、GPIO、host interface</td><td>inventory object、association、event</td></tr>
<tr><td>bmcweb</td><td>將 inventory / asset / health 呈現為 Redfish resource</td><td>D-Bus inventory、associations、sensors</td><td>Redfish client / WebUI</td></tr>
<tr><td>phosphor-host-ipmid</td><td>提供 IPMI FRU / SDR / SEL 對外介面</td><td>D-Bus inventory、FRU data、config</td><td>ipmitool / host management tool</td></tr>
</table>

#### 15.3 D-Bus Inventory object 與 interface 設計

Inventory object 通常位於 `/xyz/openbmc_project/inventory` namespace。每個實體元件至少應有可識別的 object path，並依元件類型套用對應 interface，例如 `xyz.openbmc_project.Inventory.Item`、`xyz.openbmc_project.Inventory.Decorator.Asset`、`xyz.openbmc_project.Inventory.Item.Board`、`PowerSupply`、`Fan`、`Dimm`、`Cpu` 等。

Object path 命名建議：

```text
/xyz/openbmc_project/inventory/system
/xyz/openbmc_project/inventory/system/chassis
/xyz/openbmc_project/inventory/system/chassis/motherboard
/xyz/openbmc_project/inventory/system/chassis/motherboard/bmc
/xyz/openbmc_project/inventory/system/chassis/motherboard/psu0
/xyz/openbmc_project/inventory/system/chassis/motherboard/fan0
/xyz/openbmc_project/inventory/system/chassis/motherboard/dimm0
/xyz/openbmc_project/inventory/system/chassis/motherboard/riser0
```

命名建議：

- object path 應穩定，不應因 hwmon index、I2C bus number、probe 順序改變。
- 可插拔 slot 建議使用 slot 名稱，例如 `psu0`、`fan3`、`riser1`，而不是直接用 FRU product name。
- 同一類型元件序號需與 silk screen / service manual 一致。
- 若資料來自不同來源，object path 仍應維持同一個 inventory identity，避免 Redfish / IPMI 看到重複項目。
- 不建議把 transient debug object 暴露到 production inventory tree。

常見 inventory property：

<table>
<tr><th>Property / Interface</th><th>用途</th><th>資料來源</th><th>注意事項</th></tr>
<tr><td>Present</td><td>實體是否存在</td><td>GPIO、FRU ACK、PMBus、CPLD、Probe result</td><td>不要和 Functional 混用</td></tr>
<tr><td>PrettyName</td><td>人類可讀名稱</td><td>config、FRU product name</td><td>不應作為程式唯一識別</td></tr>
<tr><td>Manufacturer</td><td>製造商</td><td>FRU Board/Product area、PMBus MFR_ID、SMBIOS</td><td>需定義優先順序</td></tr>
<tr><td>Model</td><td>型號</td><td>FRU product name / part model</td><td>需和 Redfish Model 對映</td></tr>
<tr><td>PartNumber</td><td>料號</td><td>FRU part number、ERP / factory provisioning</td><td>量產資料需保護</td></tr>
<tr><td>SerialNumber</td><td>序號</td><td>FRU serial、factory provisioning、PMBus MFR_SERIAL</td><td>不可被 FW update 覆蓋</td></tr>
<tr><td>AssetTag</td><td>資產標籤</td><td>FRU product asset tag、user setting</td><td>若可寫，需權限與保存策略</td></tr>
<tr><td>BuildDate / MfgDate</td><td>製造時間</td><td>FRU manufacturing date、factory database</td><td>格式與時區需一致</td></tr>
<tr><td>Version / Revision</td><td>硬體版本</td><td>FRU custom field、CPLD register、silicon ID</td><td>需區分 board rev、CPLD rev、FW rev</td></tr>
<tr><td>Functional</td><td>功能狀態</td><td>fault bit、sensor status、daemon 判斷</td><td>Present=true 但 Functional=false 是有效狀態</td></tr>
</table>

#### 15.4 FRU EEPROM 與 IPMI FRU 格式

IPMI FRU 資料通常存放在 I2C EEPROM 中，常見於 baseboard、PSU、fan tray、riser、backplane、GPU carrier、front panel 等。FRU 格式通常由 common header 指向不同 area，例如 chassis、board、product、multi-record 等。每個 area 有自己的長度、欄位與 checksum。

FRU 設計重點：

- 必須定義 EEPROM 型號、I2C bus、mux path、address、address width、page size、WP pin、容量。
- 必須定義 FRU data 的 owner：工廠工具、BMC service、field service tool 或 PSU vendor。
- 必須定義哪些欄位可寫、誰可寫、何時可寫、寫入失敗如何回復。
- BMC FW update 不應覆蓋 baseboard serial / asset tag / field provisioning 資料。
- FRU checksum 錯時需報清楚，不能默默使用半解析欄位。

常見 IPMI FRU 欄位對映：

<table>
<tr><th>FRU area</th><th>欄位</th><th>Inventory / Asset 對映</th><th>Redfish 常見對映</th><th>備註</th></tr>
<tr><td>Chassis</td><td>Chassis Type</td><td>Chassis 類型</td><td>ChassisType</td><td>需符合產品外型</td></tr>
<tr><td>Chassis</td><td>Part Number</td><td>Chassis PartNumber</td><td>PartNumber</td><td>機箱料號</td></tr>
<tr><td>Chassis</td><td>Serial Number</td><td>Chassis SerialNumber</td><td>SerialNumber</td><td>機身序號</td></tr>
<tr><td>Board</td><td>Manufacturer</td><td>Board Manufacturer</td><td>Manufacturer</td><td>主板製造商</td></tr>
<tr><td>Board</td><td>Product Name</td><td>Board PrettyName / Model</td><td>Model / Name</td><td>需避免和整機 product name 混淆</td></tr>
<tr><td>Board</td><td>Serial Number</td><td>Board SerialNumber</td><td>SerialNumber</td><td>主板序號</td></tr>
<tr><td>Board</td><td>Part Number</td><td>Board PartNumber</td><td>PartNumber</td><td>主板料號</td></tr>
<tr><td>Product</td><td>Manufacturer</td><td>System Manufacturer</td><td>ComputerSystem Manufacturer</td><td>整機製造商</td></tr>
<tr><td>Product</td><td>Product Name</td><td>System Model</td><td>ComputerSystem Model</td><td>整機型號</td></tr>
<tr><td>Product</td><td>Part / Version</td><td>System PartNumber / Version</td><td>PartNumber / SKU</td><td>專案需定義對映</td></tr>
<tr><td>Product</td><td>Serial Number</td><td>System SerialNumber</td><td>SerialNumber</td><td>外部管理最常使用</td></tr>
<tr><td>Product</td><td>Asset Tag</td><td>AssetTag</td><td>AssetTag</td><td>可能可由使用者修改</td></tr>
</table>

#### 15.5 資料來源優先順序與衝突處理

同一欄位可能有多個來源。例如 PSU model 可來自 FRU EEPROM、PMBus MFR_MODEL、Entity Manager JSON、vendor inventory daemon。若未定義優先順序，Redfish / IPMI / WebUI 可能顯示不同資料。

建議每個欄位建立 priority：

<table>
<tr><th>欄位</th><th>Priority 1</th><th>Priority 2</th><th>Priority 3</th><th>衝突處理</th></tr>
<tr><td>System SerialNumber</td><td>Factory provisioned FRU Product Serial</td><td>secure manufacturing file</td><td>static config placeholder</td><td>若不一致，記錄 event 並標示待確認</td></tr>
<tr><td>Baseboard PartNumber</td><td>Board FRU Part Number</td><td>GPIO SKU ID + lookup table</td><td>Entity Manager JSON</td><td>FRU 解析失敗才 fallback</td></tr>
<tr><td>PSU Model</td><td>PSU FRU Product Name</td><td>PMBus MFR_MODEL</td><td>slot default config</td><td>若 PSU absent，不使用舊值作為 present item</td></tr>
<tr><td>Fan tray SerialNumber</td><td>Fan tray FRU Serial</td><td>manufacturing database</td><td>N/A</td><td>沒有序號時標未知，不偽造</td></tr>
<tr><td>CPLD Version</td><td>CPLD register</td><td>update manifest</td><td>static config</td><td>register 讀不到時標 unavailable</td></tr>
<tr><td>AssetTag</td><td>User writable setting / Redfish PATCH</td><td>FRU Product Asset Tag</td><td>factory default</td><td>需定義寫回 FRU 或 persistent store</td></tr>
</table>

衝突處理原則：

- 不要默默覆蓋量產資料；需保留 before / after log。
- 對外欄位只能有一個明確權威端；其他來源作為 fallback 或診斷資訊。
- 若不同介面需不同語意，例如 System Serial vs Board Serial，必須分開欄位，不要共用。
- 若 FRU 缺欄位，不建議填入會誤導維修的假資料；可顯示 unknown / unavailable。
- 若允許 Redfish 更新 AssetTag，需明確定義寫到 FRU EEPROM、persistent setting 或平台資料庫。

#### 15.6 Entity Manager JSON 與 Probe 設計

Entity Manager 常以 JSON 設定描述 entity、probe rule 與 exposes。Probe 可依 FRU 欄位、GPIO presence、DevicePresence、SMBIOS、MCTP discovery 或其他 D-Bus interface 判斷某個配置是否適用。

簡化範本：

```json
{
  "Name": "Example Baseboard",
  "Probe": "xyz.openbmc_project.FruDevice({'BOARD_PRODUCT_NAME': 'EXAMPLE_BOARD'})",
  "Type": "Board",
  "Exposes": [
    {
      "Name": "Baseboard",
      "Type": "InventoryItem",
      "PrettyName": "Example Baseboard"
    },
    {
      "Name": "inlet_temp",
      "Type": "TMP75",
      "Bus": 5,
      "Address": "0x48"
    }
  ]
}
```

Probe 設計建議：

- Probe 欄位要使用穩定且量產可控的資料，例如 board product name、part number、SKU ID。
- 不建議使用 serial number 作為 platform config probe，因為每台都不同。
- Probe rule 需容許 FRU 欄位大小寫、空白、vendor old format 的差異，或在工廠端先標準化。
- 可插拔元件需定義插入、拔除、重新插入後的 object 更新行為。
- 一個 FRU 對應多個 Exposes 時，需確認其中任何 sensor / device 失敗不會讓整個 entity 被移除，除非符合設計。

#### 15.7 Presence、Functional、Available 與 Health

Inventory 與 sensor / power / thermal policy 最容易混淆的是 Present、Functional、Available、Health。建議採用下列語意：

<table>
<tr><th>狀態</th><th>語意</th><th>例子</th><th>對外呈現建議</th></tr>
<tr><td>Present</td><td>實體是否插入或存在</td><td>PSU 插入、fan tray 插入、DIMM 存在</td><td>Inventory Item Present</td></tr>
<tr><td>Available</td><td>目前讀值或服務是否可取得</td><td>PSU present 但 PMBus 暫時 timeout</td><td>Sensor Availability</td></tr>
<tr><td>Functional</td><td>元件是否功能正常</td><td>fan present 但 tach 為 0、PSU present 但 fault</td><td>OperationalStatus Functional=false</td></tr>
<tr><td>Health</td><td>聚合後的健康狀態</td><td>Redfish Status Health Warning / Critical</td><td>Redfish Status</td></tr>
<tr><td>Enabled</td><td>是否被管理軟體啟用</td><td>slot disabled、fan policy disabled</td><td>Redfish State / Enabled</td></tr>
</table>

設計提醒：

- Present=false 時，不應同時報該元件 sensor threshold critical。
- Present=true 但 Available=false 可表示通訊暫時失敗，需要 retry 與 event debounce。
- Present=true 但 Functional=false 可表示元件在但有 fault，應保留 inventory 並顯示 fault。
- Health 應是 policy 聚合結果，不應直接等同單一 GPIO 或單一 PMBus bit。
- 熱插拔元件需在拔除後清除或更新 sensor association，避免 Redfish 顯示 orphan sensor。

#### 15.8 Association 與拓樸模型

OpenBMC inventory 需要 association 來表達物理包含、sensor 屬於哪個元件、元件位於哪個 chassis / board / slot。這些 association 會影響 Redfish resource 階層、IPMI SDR、power / thermal policy 與 event log 的 location。

常見 association：

<table>
<tr><th>Association</th><th>用途</th><th>例子</th><th>注意事項</th></tr>
<tr><td>contained_by / containing</td><td>物理包含關係</td><td>fan0 contained_by chassis</td><td>不要形成循環</td></tr>
<tr><td>inventory / sensors</td><td>sensor 與 inventory item 關係</td><td>psu0 voltage sensor belongs to psu0</td><td>Redfish sensor placement 依賴此關係</td></tr>
<tr><td>chassis / all_sensors</td><td>chassis 下所有 sensor</td><td>system/chassis → sensors</td><td>需避免漏掉可插拔元件 sensor</td></tr>
<tr><td>powered_by</td><td>電源供應關係</td><td>drive backplane powered_by psu0</td><td>若平台支援可補</td></tr>
<tr><td>cooled_by</td><td>冷卻關係</td><td>CPU cooled_by fan zone</td><td>fan policy 可引用</td></tr>
</table>

排查 association：

```bash
busctl tree xyz.openbmc_project.ObjectMapper | grep -i inventory
busctl introspect <service> <object_path>
busctl get-property <service> <object_path> xyz.openbmc_project.Association.Definitions Associations
```

#### 15.9 Redfish / IPMI 對映

Inventory 對外通常會映射到 Redfish 與 IPMI。兩者語意不同：Redfish 偏向 resource model 與 JSON schema；IPMI FRU 偏向 legacy FRU areas 與 SDR。不能假設兩者欄位完全一對一。

<table>
<tr><th>BMC 內部資料</th><th>Redfish 可能 resource</th><th>IPMI 可能呈現</th><th>注意事項</th></tr>
<tr><td>System inventory</td><td>ComputerSystem</td><td>Product FRU</td><td>System serial 與 board serial 需分清楚</td></tr>
<tr><td>Chassis inventory</td><td>Chassis</td><td>Chassis FRU</td><td>ChassisType / AssetTag / SerialNumber</td></tr>
<tr><td>Baseboard</td><td>Chassis / Assembly / Manager relation</td><td>Board FRU</td><td>Board product name 不一定等於 system model</td></tr>
<tr><td>PSU</td><td>PowerSupply / PowerSubsystem</td><td>FRU + sensors</td><td>presence、power readout、fault 狀態需一致</td></tr>
<tr><td>Fan</td><td>Fan / ThermalSubsystem</td><td>Fan SDR / FRU</td><td>fan tray 與 fan rotor 需分層</td></tr>
<tr><td>DIMM / CPU</td><td>Memory / Processor</td><td>可能由 OEM IPMI / SMBIOS</td><td>來源常是 BIOS / host inventory</td></tr>
<tr><td>Drive / PCIe</td><td>Drive / PCIeDevice / Storage</td><td>平台依需求</td><td>可能來自 MCTP / PLDM / host table</td></tr>
</table>

Redfish 檢查：

```bash
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Systems
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Managers
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>/Power
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>/Thermal
```

IPMI 檢查：

```bash
ipmitool fru print
ipmitool fru print <fru_id>
ipmitool sdr elist
ipmitool sensor list
ipmitool sel list
```

#### 15.10 製造寫入、provisioning 與 field update

Inventory / FRU / Asset 有一部分屬於量產階段資料，不應被一般韌體更新流程覆蓋。建議把資料分成 factory data、field writable data、runtime cache 三類。

<table>
<tr><th>資料類型</th><th>例子</th><th>寫入時機</th><th>保存位置</th><th>保護策略</th></tr>
<tr><td>Factory data</td><td>serial number、part number、MAC、UUID、manufacture date</td><td>工廠燒錄 / final test</td><td>FRU EEPROM、secure storage、factory partition</td><td>FW update 不覆蓋；需權限控管</td></tr>
<tr><td>Field writable data</td><td>AssetTag、Location、user label</td><td>現場管理或 Redfish PATCH</td><td>persistent setting 或可寫 FRU 欄位</td><td>需 audit log 與權限</td></tr>
<tr><td>Runtime cache</td><td>parsed FRU cache、host inventory cache</td><td>service 啟動或 discovery 後</td><td>/var/lib 或 memory</td><td>可重建；factory reset policy 需定義</td></tr>
<tr><td>Derived data</td><td>SKU name、friendly name、slot label</td><td>依 Probe / config 產生</td><td>Entity Manager config</td><td>不可覆蓋權威序號</td></tr>
</table>

製造流程建議：

1. 工廠工具寫入 FRU / asset 欄位。
2. BMC boot 後讀回 FRU，產生 D-Bus inventory object。
3. Redfish / IPMI / CLI 讀到的欄位與工廠資料庫比對。
4. 執行 AC cycle、BMC reboot、FW update、factory reset 後再次比對。
5. 保存 provisioning log、FRU binary dump、BMC inventory dump 與版本資訊。

#### 15.11 FRU / Inventory 資料保存與安全

Asset data 常包含序號、資產標籤、位置資訊、MAC、UUID、客戶識別資訊。需考慮 field service、RMA、資安與隱私需求。

建議：

- SerialNumber / PartNumber / MAC / UUID 不應被一般使用者無權限修改。
- AssetTag 若允許修改，需透過 Redfish / CLI 權限控管與審計紀錄。
- Factory reset 是否清除 AssetTag、Location、user label 需符合產品政策。
- RMA 換板時需定義保留機身序號或更換主板序號的流程。
- FRU EEPROM 寫入需避免斷電中斷造成 checksum 損壞；必要時保留備份。
- 若 inventory 會暴露客戶自定義 label，log 收集對外分享前需評估遮蔽策略。

#### 15.12 Target 端檢查與 log 收集

建議建立固定 log 套件：

```bash
mkdir -p /tmp/inventory-debug
cat /etc/os-release > /tmp/inventory-debug/os-release.txt
uname -a > /tmp/inventory-debug/uname.txt
cat /proc/cmdline > /tmp/inventory-debug/proc-cmdline.txt

dmesg -T > /tmp/inventory-debug/dmesg.txt
journalctl -b --no-pager > /tmp/inventory-debug/journal.txt
systemctl --failed > /tmp/inventory-debug/systemctl-failed.txt 2>&1

# FRU / Entity Manager / Inventory services
systemctl status xyz.openbmc_project.EntityManager.service --no-pager > /tmp/inventory-debug/entity-manager-status.txt 2>&1
systemctl status xyz.openbmc_project.FruDevice.service --no-pager > /tmp/inventory-debug/fru-device-status.txt 2>&1
journalctl -u xyz.openbmc_project.EntityManager.service -b --no-pager > /tmp/inventory-debug/entity-manager-journal.txt 2>&1
journalctl -u xyz.openbmc_project.FruDevice.service -b --no-pager > /tmp/inventory-debug/fru-device-journal.txt 2>&1

# D-Bus inventory
busctl tree xyz.openbmc_project.ObjectMapper > /tmp/inventory-debug/objectmapper-tree.txt 2>&1
busctl tree xyz.openbmc_project.EntityManager > /tmp/inventory-debug/entity-manager-tree.txt 2>&1
busctl tree xyz.openbmc_project.Inventory.Manager > /tmp/inventory-debug/inventory-manager-tree.txt 2>&1
busctl tree xyz.openbmc_project.FruDevice > /tmp/inventory-debug/fru-device-tree.txt 2>&1
busctl tree xyz.openbmc_project.ObjectMapper | grep -i inventory > /tmp/inventory-debug/inventory-paths.txt 2>&1

# I2C / EEPROM
command -v i2cdetect >/dev/null 2>&1 && i2cdetect -l > /tmp/inventory-debug/i2cdetect-l.txt 2>&1
ls -l /sys/bus/i2c/devices > /tmp/inventory-debug/sys-bus-i2c-devices.txt 2>&1
find /sys/bus/i2c/devices -maxdepth 3 -name eeprom -print > /tmp/inventory-debug/eeprom-files.txt 2>&1

# GPIO presence
gpiodetect > /tmp/inventory-debug/gpiodetect.txt 2>&1 || true
gpioinfo > /tmp/inventory-debug/gpioinfo.txt 2>&1 || true

# Redfish / IPMI local tools, if available
ipmitool fru print > /tmp/inventory-debug/ipmi-fru-print.txt 2>&1 || true
ipmitool sdr elist > /tmp/inventory-debug/ipmi-sdr-elist.txt 2>&1 || true
ipmitool sel list > /tmp/inventory-debug/ipmi-sel-list.txt 2>&1 || true

tar czf /tmp/inventory-debug-$(date +%Y%m%d-%H%M%S).tar.gz -C /tmp inventory-debug
```

若要保存 FRU binary，請先確認資料是否可分享：

```bash
# 範例：保存 EEPROM binary，bus/address 需依平台替換
cp /sys/bus/i2c/devices/<bus>-00<addr>/eeprom /tmp/inventory-debug/fru-<bus>-<addr>.bin 2>/dev/null || true
```

#### 15.13 常見問題與排查入口

<table>
<tr><th>現象</th><th>可能方向</th><th>第一輪檢查</th></tr>
<tr><td>Redfish 看不到某個元件</td><td>D-Bus inventory object 未建立，或 association 缺失</td><td>busctl tree、ObjectMapper、bmcweb journal</td></tr>
<tr><td>IPMI FRU 有資料但 Redfish 沒資料</td><td>FRU 只被 ipmid 使用，未轉成 inventory object</td><td>fru-device tree、Entity Manager Probe、inventory path</td></tr>
<tr><td>Redfish 有 inventory 但 IPMI FRU 缺欄位</td><td>IPMI FRU ID / mapping 未更新</td><td>ipmitool fru print、ipmid journal、FRU config</td></tr>
<tr><td>FRU EEPROM 讀不到</td><td>I2C path、address、WP、EEPROM size、mux、power 問題</td><td>i2cdetect、/sys/bus/i2c/devices、scope</td></tr>
<tr><td>FRU checksum error</td><td>資料寫入中斷、格式錯、area length 錯</td><td>fru-device journal、binary dump、factory tool</td></tr>
<tr><td>序號顯示 unknown</td><td>FRU 欄位空、Probe fallback 未定義、權威端讀取失敗</td><td>FRU dump、D-Bus value、factory log</td></tr>
<tr><td>PSU 拔掉後 inventory 仍 Present=true</td><td>presence source 未更新，使用舊 cache</td><td>GPIO / PMBus presence、fru-device journal、Entity Manager object</td></tr>
<tr><td>Fan tray 插入後 sensor 不出現</td><td>inventory 建立了但 Exposes / sensor daemon 未收到 config</td><td>Entity Manager journal、dbus-sensors journal、association</td></tr>
<tr><td>Factory reset 後資產資料消失</td><td>factory reset 清掉 persistent store 或 FRU cache 當成權威端</td><td>reset script、保存策略、FRU EEPROM 原始資料</td></tr>
<tr><td>FW update 後料號變回預設</td><td>image 內 static config 覆蓋 runtime / factory data</td><td>update script、rwfs migration、inventory config</td></tr>
<tr><td>不同介面顯示不同 model</td><td>Redfish / IPMI / D-Bus 使用不同來源</td><td>欄位優先順序表、bmcweb / ipmid log</td></tr>
<tr><td>Object path 每次開機不同</td><td>依 bus number / hwmon index / discovery order 命名</td><td>命名規則、Probe source、service log</td></tr>
</table>

#### 15.14 Bring-up 建議流程

- 建立所有實體元件清單：system、chassis、baseboard、BMC、PSU、fan、riser、backplane、drive、CPU、DIMM、CPLD、FPGA、NIC、GPU。
- 對每個元件定義資料權威端：FRU EEPROM、PMBus MFR command、SMBIOS、CPLD register、GPIO ID、Entity Manager JSON、manufacturing provisioning。
- 建立欄位對映表：Manufacturer、Model、PartNumber、SerialNumber、AssetTag、Version、Location、Present、Functional。
- 建立 object path 命名規則，確保 path 穩定且與 service manual slot 名稱一致。
- 對可插拔元件定義 presence source、debounce、插入 / 拔除後 D-Bus object 更新行為。
- 對每個 FRU EEPROM 驗證 I2C path、address、EEPROM size、WP、checksum、欄位內容。
- 撰寫或更新 Entity Manager JSON，確認 Probe 與 Exposes 不會互相衝突。
- 驗證 D-Bus inventory object、associations、ObjectMapper 查找結果。
- 驗證 Redfish / IPMI / WebUI 顯示一致。
- 做異常測試：FRU missing、checksum error、hot-plug、service restart、BMC reboot、AC cycle、FW update、factory reset。
- 保存 inventory-debug log、FRU binary dump、Redfish output、IPMI output 與工廠資料比對結果。

#### 15.15 當前平台 Inventory / FRU / Asset 實測表

<table>
<tr><th>項目</th><th>資料來源</th><th>D-Bus object</th><th>Redfish / IPMI 對映</th><th>實測值</th><th>狀態</th></tr>
<tr><td>System Model</td><td>[待填]</td><td>[待填]</td><td>ComputerSystem Model / Product FRU</td><td>[待填]</td><td>[待確認]</td></tr>
<tr><td>System SerialNumber</td><td>[待填]</td><td>[待填]</td><td>ComputerSystem SerialNumber / Product FRU</td><td>[待填]</td><td>[待確認]</td></tr>
<tr><td>Chassis SerialNumber</td><td>[待填]</td><td>[待填]</td><td>Chassis SerialNumber / Chassis FRU</td><td>[待填]</td><td>[待確認]</td></tr>
<tr><td>Baseboard PartNumber</td><td>[待填]</td><td>[待填]</td><td>Board FRU / Redfish Assembly</td><td>[待填]</td><td>[待確認]</td></tr>
<tr><td>Baseboard SerialNumber</td><td>[待填]</td><td>[待填]</td><td>Board FRU / Redfish Assembly</td><td>[待填]</td><td>[待確認]</td></tr>
<tr><td>BMC FRU / version</td><td>[待填]</td><td>[待填]</td><td>Manager / BMC inventory</td><td>[待填]</td><td>[待確認]</td></tr>
<tr><td>PSU0 inventory</td><td>[待填]</td><td>[待填]</td><td>PowerSupply / FRU / sensors</td><td>[待填]</td><td>[待確認]</td></tr>
<tr><td>PSU1 inventory</td><td>[待填]</td><td>[待填]</td><td>PowerSupply / FRU / sensors</td><td>[待填]</td><td>[待確認]</td></tr>
<tr><td>Fan tray inventory</td><td>[待填]</td><td>[待填]</td><td>Fan / Thermal / FRU</td><td>[待填]</td><td>[待確認]</td></tr>
<tr><td>Riser inventory</td><td>[待填]</td><td>[待填]</td><td>PCIeSlot / Assembly</td><td>[待填]</td><td>[待確認]</td></tr>
<tr><td>DIMM inventory</td><td>[待填]</td><td>[待填]</td><td>Memory / host inventory</td><td>[待填]</td><td>[待確認]</td></tr>
<tr><td>CPU inventory</td><td>[待填]</td><td>[待填]</td><td>Processor / host inventory</td><td>[待填]</td><td>[待確認]</td></tr>
<tr><td>CPLD version</td><td>[待填]</td><td>[待填]</td><td>Assembly / OEM field</td><td>[待填]</td><td>[待確認]</td></tr>
<tr><td>AssetTag</td><td>[待填]</td><td>[待填]</td><td>Chassis / System AssetTag</td><td>[待填]</td><td>[待確認]</td></tr>
</table>

FRU EEPROM 實測表：

<table>
<tr><th>FRU</th><th>I2C path</th><th>Address</th><th>EEPROM</th><th>WP</th><th>FRU areas</th><th>Checksum</th><th>Owner</th><th>狀態</th></tr>
<tr><td>Baseboard</td><td>[待填]</td><td>[待填]</td><td>[待填]</td><td>[待填]</td><td>[待填]</td><td>[待填]</td><td>Factory/BMC</td><td>[待確認]</td></tr>
<tr><td>PSU0</td><td>[待填]</td><td>[待填]</td><td>[待填]</td><td>N/A</td><td>[待填]</td><td>[待填]</td><td>PSU vendor</td><td>[待確認]</td></tr>
<tr><td>PSU1</td><td>[待填]</td><td>[待填]</td><td>[待填]</td><td>N/A</td><td>[待填]</td><td>[待填]</td><td>PSU vendor</td><td>[待確認]</td></tr>
<tr><td>Fan board</td><td>[待填]</td><td>[待填]</td><td>[待填]</td><td>[待填]</td><td>[待填]</td><td>[待填]</td><td>Factory/BMC</td><td>[待確認]</td></tr>
<tr><td>Riser</td><td>[待填]</td><td>[待填]</td><td>[待填]</td><td>[待填]</td><td>[待填]</td><td>[待填]</td><td>Factory/BMC</td><td>[待確認]</td></tr>
</table>

#### 15.16 回查結果

本章已回查前後文並補齊下列銜接點：

- 第 3 章 Pinmux / GPIO 已有 presence / intrusion / GPIO state，本章補上 presence 與 inventory object、functional、association 的資料模型。
- 第 5 章與第 10 章已涵蓋 I2C / PMBus，本章補上 FRU EEPROM、PSU FRU、PMBus MFR 欄位與 inventory 對映。
- 第 11 章 OpenBMC 常用 Project 已介紹 Entity Manager、ObjectMapper、dbus-sensors，本章把這些服務套用到 Inventory / FRU / Asset 流程。
- 第 12～14 章 Sensor 章節會使用 inventory association 將 sensor 連到實體元件，本章補上 association 與 Redfish / IPMI 呈現方式。
- 第 16 章 Power Control 可引用 PSU inventory、presence、functional 與 PMBus fault 狀態，避免 power policy 與 inventory 顯示不一致。
- 第 2 章 Flash / Storage 與更新流程已說明 persistent data，本章補上 factory data、field writable data、runtime cache 的保存與 factory reset policy。

#### 15.17 驗收 Checklist

-  所有實體元件已建立 inventory 清單與 object path 命名規則。
-  每個 asset 欄位已定義權威端、fallback、衝突處理與 owner。
-  FRU EEPROM 的 I2C path、address、size、WP、checksum、欄位內容已驗證。
-  Entity Manager Probe 可正確匹配 board / SKU / FRU，不會因 serial number 差異失敗。
-  D-Bus inventory object 位於穩定 path，且 Present / Functional / Asset 欄位正確。
-  Association 已建立，sensor、power、thermal、inventory、chassis 關係可由 ObjectMapper 查到。
-  Redfish System / Chassis / Power / Thermal / Assembly 顯示與 D-Bus inventory 一致。
-  IPMI FRU / SDR 顯示與 FRU EEPROM、D-Bus inventory 一致，差異已有明確說明。
-  可插拔元件插入 / 拔除 / 重插後，inventory、sensor、event 狀態可正確更新。
-  Present=false 不會產生誤導性的 threshold critical；Present=true + fault 可正確顯示 Functional=false 或 Health warning。
-  AssetTag / Location 等可寫欄位有權限控管、審計與保存策略。
-  FW update、BMC reboot、AC cycle、factory reset 不會破壞 factory data。
-  FRU checksum error、EEPROM missing、Probe mismatch、service restart 等異常流程已測試。
-  inventory-debug log、FRU binary dump、Redfish output、IPMI output、factory 比對結果已保存。

#### 15.18 本章參考資料

- OpenBMC entity-manager README: [https://github.com/openbmc/entity-manager](https://github.com/openbmc/entity-manager)
- OpenBMC phosphor-dbus-interfaces inventory item definitions: [https://github.com/openbmc/phosphor-dbus-interfaces/tree/master/yaml/xyz/openbmc_project/Inventory/Item](https://github.com/openbmc/phosphor-dbus-interfaces/tree/master/yaml/xyz/openbmc_project/Inventory/Item)
- OpenBMC phosphor-dbus-interfaces repository: [https://github.com/openbmc/phosphor-dbus-interfaces](https://github.com/openbmc/phosphor-dbus-interfaces)
- IPMI Platform Management FRU Information Storage Definition: [https://www.intel.com/content/www/us/en/products/docs/servers/ipmi/ipmi-platform-mgt-fru-infostore-def-v1-0-rev-1-3-spec-update.html](https://www.intel.com/content/www/us/en/products/docs/servers/ipmi/ipmi-platform-mgt-fru-infostore-def-v1-0-rev-1-3-spec-update.html)
- DMTF Redfish Schema Index: [https://redfish.dmtf.org/schemas/v1/](https://redfish.dmtf.org/schemas/v1/)


### 16. Logging / Event / Telemetry

本章整理 BMC 平台中的 Logging、Event、SEL、Redfish EventLog、Redfish EventService、Telemetry、MetricReport、audit / security log、crash dump、remote syslog 與現場 log package 設計。Logging / Event / Telemetry 是 bring-up、長測、量產、RMA 與現場維修時最重要的事後分析基礎。若 log 設計不完整，即使硬體或軟體有正確偵測到 fault，也可能在 Redfish、IPMI、journal、SEL、遠端監控平台看到不同結果，造成維修判讀困難。

本章先定義 log 與 event 的分層，再說明 OpenBMC `phosphor-logging`、systemd-journal、D-Bus logging entry、Redfish EventLog / LogService、IPMI SEL、Redfish EventService subscription、TelemetryService / MetricReport、remote syslog、容量與保存策略、事件去重與 rate limit、時間同步、log 收集與驗收方式。

#### 16.1 基本分層與資料流

Logging / Event / Telemetry 建議分成下列層級：

```text
硬體 / 韌體 / service 狀態
  sensor threshold、PMBus fault、CPLD latch、watchdog、update error、security event
    ↓
局部觀測資料
  kernel dmesg、systemd journal、driver sysfs、D-Bus properties、raw status register
    ↓
標準事件物件
  OpenBMC logging entry、SEL record、Redfish EventLog Entry、audit event
    ↓
外部通知 / 長期收集
  Redfish EventService、remote syslog、telemetry metric report、external monitoring
    ↓
現場分析 / RMA
  debug package、timeline、callout、root cause record、維修動作
```

<table>
<tr><th>類型</th><th>用途</th><th>粒度</th><th>保存週期</th><th>典型消費者</th></tr>
<tr><td>systemd journal</td><td>service log、structured metadata、debug trace</td><td>高</td><td>依 storage policy</td><td>FW / QA / field debug</td></tr>
<tr><td>kernel log / dmesg</td><td>kernel driver、probe、panic、hardware error</td><td>中～高</td><td>當次 boot 為主</td><td>BSP / driver debug</td></tr>
<tr><td>OpenBMC event log</td><td>標準化事件 object</td><td>中</td><td>持久保存或輪替</td><td>bmcweb、ipmid、field service</td></tr>
<tr><td>IPMI SEL</td><td>legacy event log</td><td>中</td><td>容量有限</td><td>ipmitool、host management</td></tr>
<tr><td>Redfish EventLog</td><td>RESTful LogService entries</td><td>中</td><td>依產品政策</td><td>Redfish client、WebUI</td></tr>
<tr><td>Redfish EventService</td><td>事件主動推送</td><td>event-level</td><td>外部接收端保存</td><td>NMS、monitoring system</td></tr>
<tr><td>Telemetry / MetricReport</td><td>週期或條件式 metric 聚合</td><td>metric-level</td><td>本地或遠端</td><td>容量規劃、趨勢分析</td></tr>
<tr><td>Audit / security log</td><td>登入、權限、設定變更、更新、憑證</td><td>高價值事件</td><td>通常需較長保存</td><td>資安 / compliance</td></tr>
<tr><td>crash dump / core dump</td><td>服務崩潰與 kernel panic 分析</td><td>高</td><td>受容量限制</td><td>FW debug</td></tr>
</table>

設計原則：

- Journal 是詳細原始資料；EventLog / SEL 是對外可讀事件；Telemetry 是可統計 metric。三者不應互相取代。
- 一個 hardware fault 可能同時產生 journal、D-Bus logging entry、Redfish EventLog 與 SEL，但欄位與時間戳需能互相對照。
- 不要把連續 sensor sample 全部寫成 event；只有 threshold transition、availability 變化、fault latch、policy change 才適合作為 event。
- Debug log 預設不應無限制寫入 rwfs，需有容量、輪替、遠端轉存與清除政策。

#### 16.2 OpenBMC phosphor-logging 與 D-Bus logging entry

OpenBMC 常用 `phosphor-logging` 作為 event 與 journal logging 的基礎。它提供 structured logging API，將程式 log 寫入 systemd journal；同時由 `phosphor-log-manager` 管理 D-Bus event log objects。OpenBMC event log 常見路徑為：

```text
/xyz/openbmc_project/logging/entry/<id>
```

常見 interface：

<table>
<tr><th>Interface</th><th>用途</th><th>檢查重點</th></tr>
<tr><td>xyz.openbmc_project.Logging.Entry</td><td>事件主要資料，例如 Message、Severity、Timestamp、Resolved、AdditionalData</td><td>Severity 是否正確，AdditionalData 是否足以排查</td></tr>
<tr><td>xyz.openbmc_project.Association.Definitions</td><td>事件與 inventory / callout 的關聯</td><td>Redfish / 維修指引依賴此資料</td></tr>
<tr><td>xyz.openbmc_project.Object.Delete</td><td>刪除單筆事件</td><td>需受權限與 audit 控管</td></tr>
<tr><td>xyz.openbmc_project.Software.Version</td><td>事件發生時的軟體版本</td><td>現場比對版本與 RMA 很重要</td></tr>
</table>

檢查指令：

```bash
busctl tree xyz.openbmc_project.Logging
busctl introspect xyz.openbmc_project.Logging /xyz/openbmc_project/logging/entry/1
busctl get-property xyz.openbmc_project.Logging /xyz/openbmc_project/logging/entry/1 xyz.openbmc_project.Logging.Entry Message
journalctl -u xyz.openbmc_project.Logging.service -b --no-pager
```

事件建立建議欄位：

<table>
<tr><th>欄位</th><th>建議內容</th><th>原因</th></tr>
<tr><td>Message / MessageId</td><td>可穩定對映 registry 的事件名稱</td><td>便於 Redfish / SEL / 翻譯 / 自動處理</td></tr>
<tr><td>Severity</td><td>Informational / Warning / Critical</td><td>外部監控與告警分級依賴此欄位</td></tr>
<tr><td>Timestamp</td><td>UTC 或明確時區時間</td><td>需能與 host log、scope waveform 對齊</td></tr>
<tr><td>AdditionalData</td><td>sensor path、threshold、raw value、register、bus、slot、version</td><td>避免只看到「fault」但無法定位</td></tr>
<tr><td>Callout / Inventory association</td><td>疑似元件 inventory path</td><td>維修與 Redfish Health 對映</td></tr>
<tr><td>Resolved</td><td>事件是否已修復或解除</td><td>避免舊 fault 長期影響 health</td></tr>
<tr><td>Software version</td><td>BMC image / service version</td><td>比對已知問題與修復版本</td></tr>
</table>

#### 16.3 Journal、kernel log 與 service log

Journal 與 kernel log 是最細的軟體觀測資料。Bring-up 與 field debug 時，建議每個事件同時保存 event log 與 journal window。

常用指令：

```bash
# 當次 boot 全部 journal
journalctl -b --no-pager

# 上一次 boot journal
journalctl -b -1 --no-pager

# 指定 service
journalctl -u xyz.openbmc_project.EntityManager.service -b --no-pager
journalctl -u xyz.openbmc_project.Logging.service -b --no-pager
journalctl -u xyz.openbmc_project.State.Host.service -b --no-pager

# kernel log
dmesg -T
journalctl -k -b --no-pager

# 依關鍵字過濾
journalctl -b --no-pager | grep -Ei 'error|fail|fault|critical|timeout|watchdog|pmbus|sensor|logging|event|sel'
```

保存策略：

- 開發版可拉高 journal verbosity；量產版需避免 debug log 過量寫入 flash。
- 若使用 persistent journal，需明確設定最大容量與輪替策略。
- 若只使用 volatile journal，故障重開後可能失去上一輪關鍵 log；建議對 watchdog / panic / update failure 類事件有額外保存策略。
- Service restart loop 需有 rate limit，避免 journal 被單一錯誤洗掉。

#### 16.4 SEL、Redfish EventLog 與 LogService

IPMI SEL 與 Redfish EventLog 都是對外事件紀錄，但欄位與語意不同。SEL 容量通常較小，欄位也較固定；Redfish EventLog 可以承載 MessageId、MessageArgs、Severity、Created、Resolved、Links 等較完整資料。

<table>
<tr><th>項目</th><th>IPMI SEL</th><th>Redfish EventLog</th><th>OpenBMC D-Bus event</th></tr>
<tr><td>主要用途</td><td>legacy management 工具</td><td>RESTful 管理與自動化</td><td>BMC 內部共同事件物件</td></tr>
<tr><td>事件識別</td><td>sensor number / event type / offset</td><td>MessageId / Registry / EntryType</td><td>Message / AdditionalData</td></tr>
<tr><td>容量</td><td>通常有限</td><td>依產品設計</td><td>依 phosphor-logging 與 storage policy</td></tr>
<tr><td>清除方式</td><td>IPMI clear SEL</td><td>LogService.ClearLog</td><td>D-Bus Delete / DeleteAll</td></tr>
<tr><td>關聯資訊</td><td>有限</td><td>Links / OriginOfCondition</td><td>Association / callout</td></tr>
</table>

檢查指令：

```bash
# IPMI
ipmitool sel info
ipmitool sel list
ipmitool sel elist
ipmitool sel get <id>

# Redfish EventLog
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Systems/system/LogServices/EventLog/Entries
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Managers/bmc/LogServices
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis

# D-Bus logging
busctl tree xyz.openbmc_project.Logging
```

設計重點：

- 同一事件若同步轉成 SEL 與 Redfish EventLog，需避免重複計數或 severity 不一致。
- Clear SEL / ClearLog 是否也清 D-Bus logging entry，需要依產品政策明確定義。
- EventLog 滿時策略需記錄：循環覆寫、拒絕新增、刪最舊、遠端轉存後清除。
- Redfish EventLog 的 MessageId 應可對應 message registry，避免外部工具只能解析自由文字。

#### 16.5 Redfish EventService 與事件推送

Redfish EventService 用於讓外部監控系統訂閱事件，BMC 在事件發生時以 HTTPS POST 傳送到 listener。這適合資料中心監控、事件集中化與即時告警，但需要網路、TLS、retry、queue、權限與訂閱生命週期管理。

典型流程：

```text
Redfish client 建立 subscription
    POST /redfish/v1/EventService/Subscriptions
        Destination = https://listener/event
        EventFormatType = Event 或 MetricReport
        RegistryPrefixes / ResourceTypes / Context 等篩選條件
    ↓
BMC 保存 subscription
    ↓
事件產生：sensor threshold、log entry、state change、security event
    ↓
BMC 對 listener 送出 HTTPS POST
    ↓
listener 回應 2xx，或 BMC 依 retry policy 重送 / queue / drop
```

檢查項目：

<table>
<tr><th>項目</th><th>檢查內容</th><th>風險</th></tr>
<tr><td>Destination</td><td>URL、DNS、路由、TLS 憑證</td><td>BMC 建立訂閱成功但實際送不到</td></tr>
<tr><td>EventFormatType</td><td>Event / MetricReport</td><td>Telemetry subscription 與 event subscription 混用</td></tr>
<tr><td>Filter</td><td>RegistryPrefixes、ResourceTypes、OriginResources</td><td>收到過多或收不到預期事件</td></tr>
<tr><td>Retry</td><td>重送次數、間隔、queue size</td><td>listener down 時塞滿 BMC storage / memory</td></tr>
<tr><td>Security</td><td>HTTPS、憑證、帳號權限、secret handling</td><td>事件外洩或無法驗證 receiver</td></tr>
<tr><td>Audit</td><td>建立 / 刪除 subscription 是否有記錄</td><td>無法追蹤誰修改告警路徑</td></tr>
</table>

測試指令：

```bash
# 查 EventService
curl -k -u root:0penBmc https://<bmc>/redfish/v1/EventService
curl -k -u root:0penBmc https://<bmc>/redfish/v1/EventService/Subscriptions

# 建立測試 subscription，body 需依平台支援欄位調整
curl -k -u root:0penBmc -H 'Content-Type: application/json' \
  -X POST https://<bmc>/redfish/v1/EventService/Subscriptions \
  -d '{"Destination":"https://<listener>/redfish-events","EventFormatType":"Event","Context":"test-subscription"}'
```

#### 16.6 Telemetry、Metric、MetricReport

Telemetry 著重於「持續或週期性 metric 收集」，例如 CPU power、PSU input power、fan speed、temperature、network throughput、memory usage、boot time、service restart count。它和 event 的差異是：event 描述狀態轉換或異常；telemetry 描述時間序列或聚合資料。

Redfish TelemetryService 的常見能力包含：

- 查詢 metric metadata，例如 metric definition、metric property。
- 建立 MetricReportDefinition，定義一組 metric 如何聚合。
- 產生 MetricReport，本地保存或遠端推送。
- 搭配 EventService 用 `EventFormatType=MetricReport` 將 metric report 送往 listener。

Telemetry 設計範圍：

<table>
<tr><th>Metric 類型</th><th>來源</th><th>用途</th><th>注意事項</th></tr>
<tr><td>Temperature</td><td>D-Bus sensors / hwmon</td><td>熱設計、長測趨勢</td><td>sample rate 不宜過高</td></tr>
<tr><td>Voltage / Current / Power</td><td>PMBus / ADC / D-Bus sensors</td><td>功耗分析、PSU loading</td><td>需標示 input/output 與 rail</td></tr>
<tr><td>Fan RPM / PWM</td><td>fan daemon / hwmon</td><td>thermal policy 驗證</td><td>需和 fan profile 對齊</td></tr>
<tr><td>BMC resource</td><td>/proc、systemd、cgroup</td><td>memory leak、CPU loading</td><td>避免 telemetry 本身造成負載</td></tr>
<tr><td>Boot time</td><td>systemd-analyze、journal timestamp</td><td>效能 baseline</td><td>需分 AC boot / warm reboot / service ready</td></tr>
<tr><td>Event count</td><td>logging entry / SEL / journal</td><td>error rate、flapping 偵測</td><td>需做去重與時間窗</td></tr>
</table>

Telemetry 設計建議：

- 對外 metric name、unit、scale、sampling interval 需穩定。
- 長測資料應優先遠端收集；BMC 本地只保留短期或必要摘要。
- Telemetry 不應寫滿 rwfs；需限制報告數量、檔案大小與保留時間。
- Sensor unavailable 時需用明確狀態表示，不要使用 0 取代未知值。
- MetricReport 的時間戳需與 EventLog、journal 使用同一時間基準。

#### 16.7 事件分類、Severity 與去重

事件分類需讓 FW、QA、field service、NOC 看到相同語意。建議建立平台事件分類表：

<table>
<tr><th>分類</th><th>例子</th><th>Severity 建議</th><th>是否需要 SEL</th><th>是否需要推送</th></tr>
<tr><td>Hardware fault</td><td>VR fault、PSU fault、fan fail、ECC threshold</td><td>Warning / Critical</td><td>是</td><td>是</td></tr>
<tr><td>Sensor threshold</td><td>溫度 / 電壓 / 電流超界</td><td>Warning / Critical</td><td>依平台</td><td>是</td></tr>
<tr><td>Availability</td><td>sensor unavailable、PMBus timeout</td><td>Warning</td><td>依平台</td><td>視持續時間</td></tr>
<tr><td>Inventory change</td><td>PSU / fan / drive 插拔</td><td>Informational / Warning</td><td>依平台</td><td>可選</td></tr>
<tr><td>Firmware update</td><td>update start / success / fail / rollback</td><td>Info / Warning / Critical</td><td>是</td><td>是</td></tr>
<tr><td>Power state</td><td>power on/off/cycle、watchdog reset</td><td>Info / Warning</td><td>依平台</td><td>可選</td></tr>
<tr><td>Security</td><td>login fail、password change、cert change、secure boot fail</td><td>Warning / Critical</td><td>依政策</td><td>是</td></tr>
<tr><td>Debug / trace</td><td>service retry、temporary timeout</td><td>Debug / Info</td><td>否</td><td>否</td></tr>
</table>

去重與 rate limit：

- Threshold assert / deassert 應成對記錄，避免每次 polling 都新增一筆。
- 同一 fault bit 若維持 asserted，只應在首次 asserted、狀態變化、超過時間窗時記錄。
- 通訊 timeout 類事件建議用連續失敗 N 次才上報，恢復時記錄 recover。
- Hot-plug 抖動需 debounce，避免插拔瞬間產生大量 SEL。
- Service restart loop 需限制 event 量，並保留第一筆與摘要。

#### 16.8 Time sync、timestamp 與跨系統時間線

事件分析需要把 BMC journal、Redfish EventLog、SEL、Host log、scope waveform、CPLD latch time 對齊。若時間不準，會大幅增加排查成本。

時間設計重點：

- BMC boot 早期尚未 NTP sync 前的事件，需要標示未同步或保存 monotonic timestamp。
- SEL / EventLog / journal 建議都能對應到 UTC 或明確時區。
- Redfish `Created` / `EventTimestamp` 應符合資料中心監控工具期待格式。
- RTC / NTP / PTP / host time sync 的權威端需明確。
- AC loss 後若 RTC 沒電，時間會回到預設值；log 收集需同時保存 uptime / boot id。

指令：

```bash
timedatectl status
timedatectl timesync-status 2>/dev/null || true
journalctl --list-boots
cat /proc/uptime
cat /etc/os-release
```

#### 16.9 Remote syslog 與外部收集

Remote syslog 可用於集中收集 BMC log，降低本地 flash 寫入與現場 log 遺失風險。設計時需確認 protocol、TLS、server reachable、queue、rate limit 與安全政策。

<table>
<tr><th>項目</th><th>建議記錄</th><th>注意事項</th></tr>
<tr><td>Protocol</td><td>UDP / TCP / TLS</td><td>UDP 可能遺失；TLS 需憑證管理</td></tr>
<tr><td>Server</td><td>FQDN / IP / port</td><td>DNS、route、management VLAN</td></tr>
<tr><td>Filter</td><td>facility、severity、service</td><td>避免 debug log 全量外送</td></tr>
<tr><td>Queue</td><td>網路斷線時如何暫存</td><td>不可無限制佔用 rwfs</td></tr>
<tr><td>Security</td><td>CA、client cert、auth</td><td>避免 log 外洩或被偽造 server 接收</td></tr>
<tr><td>Audit</td><td>remote syslog config change</td><td>需記錄誰修改 server</td></tr>
</table>

檢查指令依平台而定，常見方向：

```bash
systemctl status rsyslog --no-pager 2>/dev/null || true
systemctl status phosphor-rsyslog-conf --no-pager 2>/dev/null || true
journalctl -u rsyslog -b --no-pager 2>/dev/null || true
journalctl -u xyz.openbmc_project.Syslog.Config.service -b --no-pager 2>/dev/null || true
```

#### 16.10 Log 容量、輪替與清除政策

Log 設計必須有容量上限與清除策略。若沒有上限，event storm 或 service spam 可能填滿 rwfs，進一步造成設定無法寫入、update 失敗或 service crash。

<table>
<tr><th>資料</th><th>常見路徑 / 來源</th><th>容量策略</th><th>清除策略</th></tr>
<tr><td>systemd journal</td><td>/var/log/journal 或 volatile</td><td>SystemMaxUse / RuntimeMaxUse</td><td>journalctl --vacuum-size / time</td></tr>
<tr><td>phosphor logging entries</td><td>D-Bus / persistent store</td><td>max entries / max size</td><td>Delete / DeleteAll / ClearLog</td></tr>
<tr><td>SEL</td><td>IPMI SEL store</td><td>固定筆數</td><td>ipmitool sel clear</td></tr>
<tr><td>Redfish EventLog</td><td>LogService entries</td><td>依 backend</td><td>LogService.ClearLog</td></tr>
<tr><td>core dump</td><td>/var/lib/systemd/coredump</td><td>限制單檔與總量</td><td>coredumpctl cleanup / tmpfiles</td></tr>
<tr><td>debug package</td><td>/tmp 或 /var/tmp</td><td>上傳前暫存</td><td>重開機清除或明確刪除</td></tr>
<tr><td>telemetry reports</td><td>Redfish / local file / remote</td><td>保留最近 N 份 / 時間窗</td><td>輪替 / 遠端轉存</td></tr>
</table>

驗證項目：

- event storm 時不會填滿 rwfs。
- log 滿時策略符合產品需求：覆寫最舊、拒絕新增、告警、遠端轉存。
- 清除 LogService / SEL / D-Bus logging entry 需要適當權限，且清除動作本身應有 audit log。
- Factory reset 是否清 event log / audit log / telemetry data 需明確定義。
- RMA log package 不應依賴已被清除的 volatile log。

#### 16.11 Security / Audit log

Security log 應涵蓋登入、登出、認證失敗、使用者 / 權限變更、密碼變更、憑證匯入、TLS 設定、SSH key、Redfish subscription、firmware update、secure boot、factory reset、remote syslog 設定變更等。

建議欄位：

<table>
<tr><th>欄位</th><th>內容</th><th>注意事項</th></tr>
<tr><td>Actor</td><td>使用者、service account、host、local console</td><td>避免記錄密碼或 token</td></tr>
<tr><td>Action</td><td>登入、設定變更、更新、清 log、建立 subscription</td><td>需使用穩定事件名稱</td></tr>
<tr><td>Target</td><td>被修改的 resource / object path / Redfish URI</td><td>便於審計</td></tr>
<tr><td>Result</td><td>success / failure / denied</td><td>失敗原因需足以排查但不洩漏秘密</td></tr>
<tr><td>Source</td><td>remote IP、session、interface</td><td>需考慮隱私與法規</td></tr>
<tr><td>Timestamp</td><td>UTC time / boot id</td><td>需能與其他 log 對齊</td></tr>
</table>

#### 16.12 Crash dump、core dump 與 watchdog 事件

Service crash、kernel panic、watchdog reset 需要保存最小可用證據：版本、上一輪 journal、core dump、reset reason、watchdog source、service status 與 event log。

指令：

```bash
coredumpctl list 2>/dev/null || true
coredumpctl info <PID> 2>/dev/null || true
systemctl --failed
journalctl -b -1 --no-pager > /tmp/journal-previous.txt 2>&1
journalctl -k -b -1 --no-pager > /tmp/kernel-previous.txt 2>&1
```

watchdog event 建議欄位：

- watchdog source：SoC、systemd、CPLD、external supervisor。
- reset target：BMC-only、host-only、full board。
- last heartbeat service / timestamp。
- reset reason register。
- previous boot journal 是否可讀。
- 是否伴隨 power fault / thermal fault / update flow。

#### 16.13 Logging / Event / Telemetry 實作對照表

<table>
<tr><th>事件來源</th><th>觸發條件</th><th>D-Bus logging</th><th>SEL</th><th>Redfish EventLog</th><th>EventService</th><th>Telemetry</th><th>備註</th></tr>
<tr><td>Sensor threshold</td><td>warning / critical assert / deassert</td><td>是</td><td>依平台</td><td>是</td><td>是</td><td>sensor metric</td><td>避免 polling 重複新增</td></tr>
<tr><td>PSU fault</td><td>PMBus STATUS fault / presence change</td><td>是</td><td>是</td><td>是</td><td>是</td><td>power metric</td><td>先保存 fault snapshot</td></tr>
<tr><td>Fan fail</td><td>tach fail / fan missing</td><td>是</td><td>是</td><td>是</td><td>是</td><td>RPM / PWM</td><td>presence 與 tach fail 分開</td></tr>
<tr><td>Firmware update</td><td>start / success / failure / rollback</td><td>是</td><td>依平台</td><td>是</td><td>是</td><td>可選</td><td>需記錄版本與 image id</td></tr>
<tr><td>Security</td><td>login fail / cert change / user change</td><td>是</td><td>依政策</td><td>是</td><td>是</td><td>否</td><td>需遮蔽敏感資料</td></tr>
<tr><td>Watchdog reset</td><td>timeout / reboot</td><td>是</td><td>是</td><td>是</td><td>是</td><td>boot metric</td><td>需關聯 reset reason</td></tr>
<tr><td>Inventory change</td><td>hot-plug insert / remove</td><td>視需求</td><td>視需求</td><td>是</td><td>可選</td><td>否</td><td>需 debounce</td></tr>
<tr><td>Performance</td><td>boot time / CPU / memory / bandwidth</td><td>否</td><td>否</td><td>否</td><td>可選</td><td>是</td><td>適合 Telemetry 而非 EventLog</td></tr>
</table>

#### 16.14 Target 端 log 收集套件

```bash
mkdir -p /tmp/logging-debug
cat /etc/os-release > /tmp/logging-debug/os-release.txt
uname -a > /tmp/logging-debug/uname.txt
cat /proc/cmdline > /tmp/logging-debug/proc-cmdline.txt
cat /proc/uptime > /tmp/logging-debug/proc-uptime.txt
timedatectl status > /tmp/logging-debug/timedatectl.txt 2>&1
journalctl --list-boots > /tmp/logging-debug/journal-boots.txt 2>&1

# journal / kernel
journalctl -b --no-pager > /tmp/logging-debug/journal-current.txt
journalctl -b -1 --no-pager > /tmp/logging-debug/journal-previous.txt 2>&1
journalctl -k -b --no-pager > /tmp/logging-debug/journal-kernel-current.txt
journalctl -k -b -1 --no-pager > /tmp/logging-debug/journal-kernel-previous.txt 2>&1
dmesg -T > /tmp/logging-debug/dmesg.txt
systemctl --failed > /tmp/logging-debug/systemctl-failed.txt 2>&1

# logging service
systemctl status xyz.openbmc_project.Logging.service --no-pager > /tmp/logging-debug/logging-status.txt 2>&1
journalctl -u xyz.openbmc_project.Logging.service -b --no-pager > /tmp/logging-debug/logging-journal.txt 2>&1
busctl tree xyz.openbmc_project.Logging > /tmp/logging-debug/dbus-logging-tree.txt 2>&1
busctl tree xyz.openbmc_project.ObjectMapper > /tmp/logging-debug/dbus-objectmapper.txt 2>&1

# Redfish / IPMI, if available
ipmitool sel info > /tmp/logging-debug/ipmi-sel-info.txt 2>&1 || true
ipmitool sel elist > /tmp/logging-debug/ipmi-sel-elist.txt 2>&1 || true
ipmitool sdr elist > /tmp/logging-debug/ipmi-sdr-elist.txt 2>&1 || true

# crash / core dump
coredumpctl list > /tmp/logging-debug/coredump-list.txt 2>&1 || true

# storage usage
df -h > /tmp/logging-debug/df-h.txt
df -i > /tmp/logging-debug/df-i.txt
journalctl --disk-usage > /tmp/logging-debug/journal-disk-usage.txt 2>&1

tar czf /tmp/logging-debug-$(date +%Y%m%d-%H%M%S).tar.gz -C /tmp logging-debug
```

Redfish dump 範本：

```bash
mkdir -p /tmp/logging-debug/redfish
curl -k -u root:0penBmc https://<bmc>/redfish/v1/EventService > /tmp/logging-debug/redfish/EventService.json 2>&1
curl -k -u root:0penBmc https://<bmc>/redfish/v1/EventService/Subscriptions > /tmp/logging-debug/redfish/EventService-Subscriptions.json 2>&1
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Systems/system/LogServices > /tmp/logging-debug/redfish/System-LogServices.json 2>&1
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Systems/system/LogServices/EventLog/Entries > /tmp/logging-debug/redfish/EventLog-Entries.json 2>&1
curl -k -u root:0penBmc https://<bmc>/redfish/v1/TelemetryService > /tmp/logging-debug/redfish/TelemetryService.json 2>&1
```

#### 16.15 常見問題與排查入口

<table>
<tr><th>現象</th><th>可能方向</th><th>第一輪檢查</th></tr>
<tr><td>D-Bus logging entry 沒產生</td><td>事件沒有 commit、logging service fail、error YAML / registry 不匹配</td><td>journal、busctl tree Logging、service status</td></tr>
<tr><td>journal 有錯但 EventLog 沒有</td><td>只是 debug log，未建立標準 event</td><td>檢查 service event path 與 phosphor-logging usage</td></tr>
<tr><td>SEL 有事件但 Redfish 沒有</td><td>轉換橋接或 LogService mapping 缺失</td><td>ipmitool、bmcweb journal、D-Bus logging entry</td></tr>
<tr><td>Redfish EventLog 有事件但 SEL 沒有</td><td>平台政策不轉 SEL 或 sensor mapping 缺失</td><td>event policy、ipmid journal、SDR mapping</td></tr>
<tr><td>事件重複大量產生</td><td>threshold polling 重複、fault 未 debounce、service restart loop</td><td>timestamp、AdditionalData、journal window</td></tr>
<tr><td>EventService subscription 建立但收不到</td><td>listener unreachable、TLS、DNS、filter、queue fail</td><td>bmcweb journal、network、listener log</td></tr>
<tr><td>Telemetry 沒資料</td><td>TelemetryService 未啟用、MetricReportDefinition 缺、sensor association 缺</td><td>Redfish Telemetry URI、D-Bus sensors、bmcweb journal</td></tr>
<tr><td>Log 滿導致 service 異常</td><td>rwfs 滿、journal 無上限、event storm</td><td>df -h、journalctl --disk-usage、event count</td></tr>
<tr><td>時間戳錯亂</td><td>NTP 未 sync、RTC 無效、timezone / UTC 混用</td><td>timedatectl、journal boots、EventLog Created</td></tr>
<tr><td>清 log 後無 audit</td><td>ClearLog / DeleteAll 未產生安全事件</td><td>bmcweb / logging / audit policy</td></tr>
<tr><td>Crash 後沒有 core</td><td>coredump disabled、容量不足、tmpfiles 清掉</td><td>coredumpctl、systemd-coredump config、df</td></tr>
</table>

#### 16.16 Bring-up 建議流程

- 建立事件分類表：hardware fault、sensor threshold、availability、inventory change、update、power state、security、debug。
- 對每個事件定義 MessageId、Severity、AdditionalData、callout、是否進 SEL、是否進 Redfish EventLog、是否推送 EventService。
- 確認 `phosphor-logging` service、D-Bus logging entry、journal structured metadata 正常。
- 確認 sensor threshold assert / deassert、PMBus fault、CPLD fault、watchdog reset、update failure 都能留下一致事件。
- 驗證 Redfish EventLog、IPMI SEL、D-Bus logging entry 的時間、severity、來源、元件關聯一致。
- 建立 EventService subscription 測試 listener，驗證事件 POST、retry、queue、filter、TLS。
- 若平台支援 TelemetryService，建立至少一組 MetricReportDefinition 並驗證報告內容、單位、時間戳、遠端推送。
- 設定 log 容量上限、輪替、清除與 factory reset 政策。
- 做 event storm、service restart loop、listener offline、rwfs nearly full、NTP not synced、AC cycle、BMC reboot 測試。
- 保存 logging-debug package、Redfish dump、IPMI dump、journal、scope / host log 對齊結果。

#### 16.17 當前平台 Logging / Event / Telemetry 實測表

<table>
<tr><th>項目</th><th>指令 / 來源</th><th>實測值</th><th>備註</th></tr>
<tr><td>phosphor-logging service</td><td>systemctl status / journalctl</td><td>[待填]</td><td>service 是否 active</td></tr>
<tr><td>D-Bus logging entries</td><td>busctl tree xyz.openbmc_project.Logging</td><td>[待填]</td><td>entry count / latest event</td></tr>
<tr><td>Journal storage mode</td><td>journalctl --disk-usage / journald.conf</td><td>[待填]</td><td>persistent / volatile</td></tr>
<tr><td>SEL status</td><td>ipmitool sel info</td><td>[待填]</td><td>容量與使用率</td></tr>
<tr><td>Redfish EventLog</td><td>curl LogServices/EventLog</td><td>[待填]</td><td>Entry schema 與 ClearLog</td></tr>
<tr><td>EventService</td><td>curl EventService</td><td>[待填]</td><td>subscription 支援欄位</td></tr>
<tr><td>TelemetryService</td><td>curl TelemetryService</td><td>[待填]</td><td>MetricReportDefinition</td></tr>
<tr><td>Remote syslog</td><td>rsyslog / phosphor-rsyslog-conf</td><td>[待填]</td><td>protocol / server / TLS</td></tr>
<tr><td>Security audit</td><td>登入 / 設定變更測試</td><td>[待填]</td><td>是否有事件</td></tr>
<tr><td>Sensor threshold event</td><td>fault injection</td><td>[待填]</td><td>assert / deassert</td></tr>
<tr><td>PSU / fan fault event</td><td>fault injection</td><td>[待填]</td><td>callout / AdditionalData</td></tr>
<tr><td>Update event</td><td>firmware update 測試</td><td>[待填]</td><td>start / success / fail / rollback</td></tr>
<tr><td>Watchdog reset event</td><td>watchdog 測試</td><td>[待填]</td><td>reset reason 對齊</td></tr>
<tr><td>Log full policy</td><td>容量壓力測試</td><td>[待填]</td><td>輪替 / 拒絕 / 清除</td></tr>
</table>

#### 16.18 回查結果

本章已回查前後文並補齊下列銜接點：

- 第 2 章 Flash / Storage 已說明 rwfs 與 persistent data，本章補上 journal、event log、core dump、telemetry report 的容量與清除策略。
- 第 10 章 I2C / PMBus 已說明 PMBus fault，本章補上 fault snapshot 後如何形成 D-Bus logging、SEL、Redfish EventLog 與 EventService 推送。
- 第 12～14 章 Sensor / Fan / Power 會產生 threshold、fan fail、power fault 事件，本章補上事件分類、severity、去重與外部呈現方式。
- 第 15 章 Inventory / FRU / Asset 已定義 callout 與 association，本章補上 logging entry 與 inventory association、Redfish OriginOfCondition 的關係。
- 第 17 章 Presence / Intrusion / GPIO State Sensor 可引用本章的 event debounce、security / audit log 與 intrusion event policy。
- 第 24 章 Security Baseline 可引用本章的 audit log、remote syslog、ClearLog 權限與敏感資料遮蔽策略。
- 第 27～28 章 Debug Methodology / Toolkit 可引用本章 logging-debug package 作為現場收集基礎。

#### 16.19 驗收 Checklist

-  已建立平台事件分類、severity、MessageId、AdditionalData 與 callout 規範。
-  `phosphor-logging`、systemd journal、D-Bus logging entry 正常運作。
-  Redfish EventLog、IPMI SEL、D-Bus logging entry 的同一事件可互相對照。
-  Sensor threshold assert / deassert 不會重複洗 log，且恢復事件可正確產生。
-  PSU / VR / CPLD fault 會先保存 raw status snapshot，再依政策清除 fault。
-  EventService subscription 可建立、刪除、推送、retry，listener offline 行為已驗證。
-  TelemetryService / MetricReport 若平台支援，metric name、unit、sampling interval、timestamp 已驗證。
-  journal、EventLog、SEL、core dump、telemetry report 的容量上限與輪替策略已設定。
-  ClearLog / SEL clear / DeleteAll 有權限控管，且清除動作本身可被 audit。
-  remote syslog 若平台支援，server、protocol、TLS、queue、filter 已驗證。
-  NTP / RTC / timestamp / boot id 可讓 BMC log、host log、scope waveform 對齊。
-  event storm、service restart loop、rwfs nearly full、AC cycle、BMC reboot、watchdog reset 測試已完成。
-  logging-debug package、Redfish dump、IPMI dump、journal、core dump、版本資訊已保存。

#### 16.20 本章參考資料

- OpenBMC phosphor-logging README: [https://github.com/openbmc/phosphor-logging/blob/master/README.md](https://github.com/openbmc/phosphor-logging/blob/master/README.md)
- OpenBMC phosphor-logging core overview: [https://deepwiki.com/openbmc/phosphor-logging/2-core-logging-system](https://deepwiki.com/openbmc/phosphor-logging/2-core-logging-system)
- Redfish Event Service overview: [https://servermanagementportal.ext.hpe.com/docs/concepts/redfishevents](https://servermanagementportal.ext.hpe.com/docs/concepts/redfishevents)
- Redfish Telemetry Service overview: [https://redfish.redoc.ly/docs/concepts/redfishtelemetry/](https://redfish.redoc.ly/docs/concepts/redfishtelemetry/)
- DMTF Redfish Telemetry White Paper DSP2051: [https://www.dmtf.org/sites/default/files/standards/documents/DSP2051_1.0.0.pdf](https://www.dmtf.org/sites/default/files/standards/documents/DSP2051_1.0.0.pdf)
- Redfish Schema Index: [https://redfish.dmtf.org/schemas/v1/](https://redfish.dmtf.org/schemas/v1/)


### 17. Presence / Intrusion / GPIO State Sensor

本章整理 OpenBMC 中 Presence、Intrusion 與 GPIO State 類狀態感測器的 porting 方法。這類資料通常不是溫度、電壓、電流、功率或轉速等連續數值，而是代表硬體是否存在、機殼是否被開啟、GPIO / CPLD bit 是否 asserted 的布林或列舉狀態。它們會影響 inventory、FRU / asset、fan / power policy、Redfish / IPMI 對外呈現、SEL / EventLog 與安全稽核。

需要先分清楚兩個語意：

- `Present`：元件物理上是否存在，例如 PSU 插入、Fan tray 插入、Cable 扣上。
- `Functional` / `OperationalStatus`：元件存在後是否可正常工作，例如風扇存在但 tach 為 0、PSU 存在但 AC lost。

建議不要把 `Present=false` 與 `Functional=false` 混用，否則 Redfish / IPMI、event log 與 control policy 可能出現不一致。

#### 17.1 適用情境

常見項目包含：

```text
Fan presence          風扇或風扇模組是否存在
PSU presence          電源供應器是否存在
Drive presence        HDD / SSD / NVMe carrier 是否存在
Cable presence        纜線、背板 cable、riser cable 是否連接
Chassis intrusion     機殼是否被打開或 tamper switch 是否觸發
Module presence       擴充卡、riser、GPU、accelerator、fan board 是否存在
CPU presence          CPU socket 是否安裝 CPU
DIMM presence         記憶體插槽是否安裝 DIMM
GPIO state            fault、alert、ID、strap、latch 類單一狀態
CPLD bit state        CPLD / FPGA 維護的 presence、fault、ID、interrupt bit
```

常見 D-Bus 介面：

| 介面 / 類型 | 用途 | 常見消費者 |
| :--- | :--- | :--- |
| `xyz.openbmc_project.Inventory.Item.Present` | inventory 物件是否存在 | bmcweb、IPMI、fan / power policy |
| `xyz.openbmc_project.State.Decorator.OperationalStatus` | inventory 或 sensor 是否 functional | Redfish Health、internal policy |
| `xyz.openbmc_project.State.Decorator.Availability` | sensor 是否目前可讀 | Redfish sensor status |
| `xyz.openbmc_project.Inventory.Source.DevicePresence` | gpio-presence-sensor 偵測到硬體後，供 Entity Manager Probe 使用 | Entity Manager |
| `xyz.openbmc_project.Configuration.GPIODeviceDetect` | GPIO presence 偵測配置 | gpio-presence-sensor |
| `xyz.openbmc_project.Chassis.Intrusion` | 機殼入侵狀態與 rearm 模式 | bmcweb、EventLog、SEL |
| `xyz.openbmc_project.Configuration.ChassisIntrusionSensor` | intrusion sensor 配置，欄位依 branch 而定 | IntrusionSensor daemon |

常見 D-Bus 路徑：

```text
/xyz/openbmc_project/inventory/system/chassis/motherboard/fan0
/xyz/openbmc_project/inventory/system/chassis/motherboard/dimm_c0a1
/xyz/openbmc_project/inventory/system/chassis/powersupply0
/xyz/openbmc_project/Intrusion/Chassis_Intrusion
/xyz/openbmc_project/Chassis/Intrusion
```

不同 OpenBMC branch / vendor fork 的 service name、object path 或 JSON schema 可能不同，實作前需以目前專案 source tree 與實機 `busctl tree` 為準。

#### 17.2 常見來源

| 來源 | 說明 | 優點 | 常見風險 |
| :--- | :--- | :--- | :--- |
| BMC SoC GPIO | BMC 直接讀取 pin 腳 | 簡單、延遲低、可用 edge event | polarity、pull resistor、pinmux、line name 錯誤 |
| I2C GPIO expander | PCA955x、PCA953x、TCA64xx 等 | GPIO 數量可擴充 | I2C bus abnormal 時 presence 不可讀 |
| CPLD / FPGA register | CPLD 維護 presence / fault / latch bit | 可整合多個訊號、可做 latch | bit 定義、clear rule、版本差異需完整記錄 |
| MCU / EC | 由板上 MCU / EC 回報 | 可納入 debounce 與複合判斷 | 通訊協定、timeout 與 firmware version 需管控 |
| PMBus / FRU EEPROM ACK | 透過裝置是否回應判斷存在 | 不需額外 GPIO | 需區分拔出、bus error、device busy |
| hwmon sysfs | kernel driver 暴露 `intrusion*_alarm` 或 fault input | 可沿用 kernel driver | sysfs 名稱與 driver 支援依平台而異 |
| PCH / SMBus register | PCH 維護 chassis intrusion 狀態 | 常見於 x86 平台 | register、mask、rearm rule 需與 BIOS / PCH 文件對齊 |

Bring-up 前建議建立對照表：

| Item | Inventory path | Source type | GPIO / CPLD / I2C | Present / Active 條件 | Owner | 備註 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Fan0 | `/system/chassis/motherboard/fan0` | GPIO | `FAN0_PRESENT_N` | Low = present | BMC/HW | `[待填]` |
| PSU0 | `/system/chassis/powersupply0` | GPIO + PMBus | `PSU0_PRESENT_N`, bus/address `[待填]` | Low = present + PMBus ACK | BMC/HW | `[待填]` |
| Chassis cover | `/xyz/openbmc_project/Intrusion/Chassis_Intrusion` | GPIO | `CHASSIS_INTRUSION` | 依 schematic | BMC/HW/Security | `[待填]` |

#### 17.3 資料路徑（Data Flow）

GPIO based presence detection：

```text
硬體 presence pin / switch / cable detect
    ↓
BMC SoC GPIO / GPIO expander / CPLD register
    ↓
Linux GPIO subsystem / libgpiod / hwmon / I2C driver
    ↓
Userspace daemon
    ├── gpio-presence-sensor（新設計）
    │   ├── 讀取 Entity Manager 的 GPIODeviceDetect 配置
    │   ├── 依 PresencePinNames / PresencePinValues 判斷是否存在
    │   └── expose Inventory.Source.DevicePresence 供 Entity Manager Probe 使用
    ├── phosphor-multi-gpio-presence（舊式）
    │   └── 依 LineName / ActiveLow 直接更新 Inventory.Item.Present
    ├── phosphor-gpio-monitor / phosphor-fan-presence（依平台）
    │   └── 透過 gpio-keys / evdev 或 GPIO event 更新 inventory / fan presence
    └── 平台自訂 daemon
        └── 讀 CPLD / MCU / PMBus / FRU EEPROM 後更新 D-Bus
    ↓
D-Bus
    ├── Inventory.Item.Present
    ├── Inventory.Source.DevicePresence
    ├── State.Decorator.OperationalStatus
    └── Configuration.GPIODeviceDetect
    ↓
Entity Manager / Inventory / Redfish / IPMI / fan policy / event log
```

Chassis Intrusion：

```text
機殼開關 / tamper switch
    ↓
GPIO pin / PCH SMBus register / hwmon sysfs intrusion alarm
    ↓
IntrusionSensor daemon（dbus-sensors）
    ├── GPIO-based：libgpiod edge event
    ├── PCH-based：I2C/SMBus polling
    └── Hwmon-based：讀取 hwmon sysfs
    ↓
D-Bus xyz.openbmc_project.Chassis.Intrusion
    ├── Status = Normal / HardwareIntrusion
    └── Rearm = Automatic / Manual
    ↓
Redfish Chassis PhysicalSecurity / EventLog / SEL / Journal
```

#### 17.4 Porting 步驟

##### Step 1：確認硬體資訊

從 schematic、board spec、CPLD register map、BIOS / PCH 文件取得：

```text
- 目標元件名稱與 slot 編號
- 訊號來源：SoC GPIO、expander、CPLD、MCU、PCH、hwmon、PMBus、FRU EEPROM
- GPIO line name、SoC pin、GPIO chip / offset、或 CPLD offset / bit
- Active high / active low，或 bit value 與狀態的對應關係
- Debounce 需求與時間
- 是否需要 latch；若有 latch，clear rule 是 W1C、read-clear、power-cycle clear 或 software clear
- Inventory path 與 FRU / asset / association
- 熱插拔時軟體需要採取的動作
- 若為 intrusion：Automatic / Manual rearm，以及誰可以清除事件
- Redfish / IPMI / SEL 是否需要露出與記錄
```

##### Step 2：確認 GPIO / CPLD / hwmon 原始讀值

```bash
gpiodetect
gpioinfo
gpioget gpiochip0 4
gpioget gpiochip0 FAN0_PRESENT_N
```

legacy sysfs 僅作為舊平台排查：

```bash
ls /sys/class/gpio/
cat /sys/class/gpio/gpioN/value
```

CPLD / I2C register 類來源需先確認讀值，並注意 `i2cget` / `i2cset` 是否可能對裝置造成副作用：

```bash
i2cdetect -y <bus>
i2cget -y <bus> <addr> <reg>
```

hwmon 類來源：

```bash
find /sys/class/hwmon -maxdepth 3 -type f | grep -E 'intrusion|alarm|fault|present|label'
for h in /sys/class/hwmon/hwmon*; do echo === $h ===; cat $h/name 2>/dev/null; ls $h; done
```

##### Step 3：Device Tree GPIO 命名與 pinctrl

為了讓 userspace 能依名稱取得 GPIO，需在 DTS 中定義 `gpio-line-names`，並確認 pinctrl 沒有被其他功能占用。

```dts
&gpio0 {
    status = "okay";
    gpio-line-names =
        "", "", "", "",                     /* 0-3 */
        "FAN0_PRESENT_N", "", "", "",       /* 4-7 */
        "FAN1_PRESENT_N", "", "", "",       /* 8-11 */
        "CHASSIS_INTRUSION", "", "", "",    /* 12-15 */
        ...;
};
```

GPIO 命名建議：

| 元件 | 建議命名 | 說明 |
| :--- | :--- | :--- |
| Fan presence | `FAN<N>_PRESENT_N` | `_N` 表示 active low |
| PSU presence | `PSU<N>_PRESENT_N` | N 與 PSU slot 編號一致 |
| Drive presence | `DRV<N>_PRSNT_N` 或 `DRIVE<N>_PRESENT_N` | 對齊背板 slot |
| Cable presence | `CABLE_<NAME>_PRESENT_N` | `<NAME>` 建議用 schematic net 名稱 |
| DIMM presence | `DIMM_<LOC>_PRESENT_N` | `<LOC>` 對齊 BIOS / silk / inventory |
| Chassis intrusion | `CHASSIS_INTRUSION` 或 `CHASSIS_INTRUSION_N` | 依 polarity 命名 |
| Fault pin | `<COMP>_FAULT_N` | presence 與 fault 不要混用 |

檢查：

```bash
gpioinfo | grep -E 'FAN0_PRESENT|CHASSIS_INTRUSION|PSU0_PRESENT'
ls /sys/firmware/devicetree/base
```

若改 DTS 後 line name 沒變，優先排查是否燒到正確 image、U-Boot 是否載入正確 DTB、FIT image 是否含舊 DTB，或 overlay / platform DTS 是否覆蓋。

##### Step 4：Entity Manager 配置（GPIO Presence，新設計）

新設計的 `gpio-presence-sensor` 位於 `entity-manager`，透過 `xyz.openbmc_project.Configuration.GPIODeviceDetect` 取得配置。設計重點是：presence daemon 偵測到硬體存在後，expose `xyz.openbmc_project.Inventory.Source.DevicePresence`，再讓 Entity Manager 用 Probe 建立該硬體對應的 inventory / sensor / FRU 配置。

單一 GPIO 範例：

```json
{
  "Name": "My Chassis",
  "Probe": "xyz.openbmc_project.FruDevice({'BOARD_PRODUCT_NAME': 'MYBOARDPRODUCT*'})",
  "Type": "Board",
  "Exposes": [
    {
      "Name": "com.example.Hardware.cable0",
      "Type": "GPIODeviceDetect",
      "PresencePinNames": ["CABLE0_PRESENT_N"],
      "PresencePinValues": [0]
    }
  ]
}
```

多 GPIO 組合範例：

```json
{
  "Name": "My Chassis",
  "Type": "Board",
  "Exposes": [
    {
      "Name": "com.example.Hardware.ComputeCard",
      "Type": "GPIODeviceDetect",
      "PresencePinNames": ["presence-slot0a", "presence-slot0b"],
      "PresencePinValues": [0, 1]
    },
    {
      "Name": "com.example.Hardware.AirBlocker",
      "Type": "GPIODeviceDetect",
      "PresencePinNames": ["presence-slot0a", "presence-slot0b"],
      "PresencePinValues": [1, 1]
    }
  ]
}
```

被偵測到的硬體可用 `Inventory.Source.DevicePresence` 作為 Probe 條件：

```json
{
  "Name": "My Fan Board 0",
  "Probe": "xyz.openbmc_project.Inventory.Source.DevicePresence({'Name': 'com.example.Hardware.fanboard0'})",
  "Type": "Board",
  "Exposes": [
    {
      "Name": "fanboard_air_inlet",
      "Type": "TMP75",
      "Bus": 5,
      "Address": "0x48"
    }
  ]
}
```

欄位說明：

| 欄位 | 說明 |
| :--- | :--- |
| `Type` | `GPIODeviceDetect` |
| `Name` | presence source 名稱，需與後續 Probe 條件一致 |
| `PresencePinNames` | GPIO line name 陣列，對應 DTS `gpio-line-names` |
| `PresencePinValues` | 每條 GPIO 被視為 present 時的值；`0` 常對應 active low present |

注意：新設計通常不是直接寫 `Inventory.Item.Present`，而是先 expose `Inventory.Source.DevicePresence`，讓 Entity Manager 決定後續 inventory / sensor 配置。

##### Step 5：舊式 phosphor-multi-gpio-presence / phosphor-inventory-manager

舊式設計會先由 `phosphor-inventory-manager` 建立 static inventory，再由 `phosphor-multi-gpio-presence` 依 GPIO 狀態更新 `xyz.openbmc_project.Inventory.Item.Present`。

presence daemon JSON 範例：

```json
{
  "Name": "DIMM_C0A1",
  "LineName": "PLUG_DETECT_DIMM_C0A1",
  "ActiveLow": true,
  "Bias": "PULL_UP",
  "Inventory": "/system/chassis/motherboard/dimm_c0a1"
}
```

static inventory YAML 範例：

```yaml
- name: Add DIMMs
  type: startup
  actions:
    - name: createObjects
      objs:
        /system/chassis/motherboard/dimm_c0a1:
          xyz.openbmc_project.Inventory.Decorator.Replaceable:
            FieldReplaceable: true
          xyz.openbmc_project.State.Decorator.OperationalStatus:
            Functional: true
          xyz.openbmc_project.Inventory.Item:
            PrettyName: "DIMM C0A1"
            Present: false
```

舊式平台維護時需確認：

- static inventory 與 presence config 使用相同 inventory path。
- `ActiveLow=true` 表示 GPIO low 時 `Present=true`。
- 若同一元件還有 FRU EEPROM、PMBus、tach 等偵測方式，需定義優先順序。

##### Step 6：Chassis Intrusion Sensor 配置

`IntrusionSensor` daemon 屬於 `dbus-sensors`。常見來源包含 GPIO、PCH / I2C、hwmon。不同 branch 的 JSON schema 可能不同，常見類型是 `ChassisIntrusionSensor`，並以 `Class` 選擇 `Gpio`、`Hwmon`、`I2C` 或平台特定 class。

GPIO 類範例：

```json
{
  "Name": "Chassis_Intrusion_Status",
  "Type": "ChassisIntrusionSensor",
  "Class": "Gpio",
  "GpioPolarity": "High",
  "Rearm": "Manual"
}
```

hwmon 類範例：

```json
{
  "Name": "Chassis_Intrusion_Status",
  "Type": "ChassisIntrusionSensor",
  "Class": "Aspeed2600_Hwmon",
  "Rearm": "Manual"
}
```

PCH / I2C 類範例：

```json
{
  "Name": "Chassis_Intrusion_Status",
  "Type": "ChassisIntrusionSensor",
  "Class": "I2C",
  "Bus": 13,
  "Address": "0x20",
  "Rearm": "Automatic"
}
```

實際欄位需以專案 branch 為準：

```bash
grep -R "ChassisIntrusionSensor" -n entity-manager/schemas dbus-sensors/src
grep -R "GpioPolarity\|Rearm\|CHASSIS_INTRUSION\|chassis_intrusion" -n dbus-sensors/src/intrusion
```

Rearm 模式：

| 模式 | 說明 | 驗收重點 |
| :--- | :--- | :--- |
| `Automatic` | 硬體狀態回到 closed / normal 後，D-Bus `Status` 自動回到 `Normal` | 開蓋→HardwareIntrusion，關蓋→Normal |
| `Manual` | 觸發後即使關蓋仍維持 `HardwareIntrusion`，直到管理介面執行 rearm / reset | 開蓋→HardwareIntrusion，關蓋仍維持，rearm 後 Normal |

##### Step 7：Fan presence 與 fan tach / fan control 整合

Fan presence 可能由三種方式判斷：

| 方式 | 說明 | 適用情境 |
| :--- | :--- | :--- |
| Tach-based | 有 RPM 視為存在或 functional | 小型平台、無獨立 presence pin |
| GPIO-based | 專用 `FAN*_PRESENT_N` | 風扇托盤 / hot-swap fan module |
| Mixed | GPIO 判斷 present，tach 判斷 functional | 建議用於可更換風扇模組 |

若使用 `phosphor-fan-presence` 或舊式 GPIO detection，可能會透過 `gpio-keys` / evdev event number：

```yaml
- gpio:
  - PrettyName: "Fan0"
    Inventory: /system/chassis/motherboard/fan0
    key: 123
    Description: "Chassis location A1"
```

整合規則建議：

- `Present=false`：fan tach sensor 可標示 unavailable，並依熱策略決定是否進 failsafe。
- `Present=true` 且 tach=0：較接近 `Functional=false` 或 fault，不應當成 absent。
- 多 rotor fan：模組 presence 只有一個，但 tach sensor 可能有兩個或更多。
- Fan board 不存在時，該 board 下所有 fan / temp sensors 應隨 Probe 被移除或標示 unavailable。

##### Step 8：D-Bus 驗證

Presence 狀態：

```bash
busctl tree xyz.openbmc_project.Inventory.Manager
busctl get-property   xyz.openbmc_project.Inventory.Manager   /xyz/openbmc_project/inventory/system/chassis/motherboard/fan0   xyz.openbmc_project.Inventory.Item   Present
```

gpio-presence-sensor：

```bash
systemctl status xyz.openbmc_project.gpiopresence.service
journalctl -u xyz.openbmc_project.gpiopresence.service -b --no-pager
busctl tree xyz.openbmc_project.EntityManager | grep -i gpio
busctl tree xyz.openbmc_project.EntityManager | grep -i DevicePresence
```

Chassis Intrusion：

```bash
systemctl status xyz.openbmc_project.IntrusionSensor.service
journalctl -u xyz.openbmc_project.IntrusionSensor.service -b --no-pager
busctl tree xyz.openbmc_project.IntrusionSensor
busctl get-property   xyz.openbmc_project.IntrusionSensor   /xyz/openbmc_project/Intrusion/Chassis_Intrusion   xyz.openbmc_project.Chassis.Intrusion   Status
```

若路徑不同，使用：

```bash
busctl introspect xyz.openbmc_project.IntrusionSensor <object-path>
```

##### Step 9：Redfish / IPMI 驗證

```bash
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<chassis-id>
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<chassis-id>/Assembly
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<chassis-id> | jq '.PhysicalSecurity'
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Systems/system/LogServices/EventLog/Entries

ipmitool -I lanplus -H <bmc> -U root -P 0penBmc sensor list
ipmitool -I lanplus -H <bmc> -U root -P 0penBmc sdr elist
ipmitool -I lanplus -H <bmc> -U root -P 0penBmc sel list
```

若 Redfish / IPMI 看不到 presence，先確認 D-Bus inventory 是否存在，再檢查 association、chassis mapping、bmcweb / IPMI SDR 產生策略。

#### 17.5 進階除錯與常見陷阱

| 問題現象 | 可能方向 | 建議檢查 |
| :--- | :--- | :--- |
| GPIO 讀值與預期相反 | Active high / low 或 `PresencePinValues` 設定不符 | 量測 pin 腳；比對 schematic；修正 `PresencePinValues` 或 legacy `ActiveLow` |
| `gpioinfo` 看不到 line name | DTS `gpio-line-names` 未更新、DTB 未載入、GPIO controller 不同 | 檢查 deploy DTB、U-Boot/FIT、`/sys/firmware/devicetree/base` |
| presence 插拔不更新 | GPIO 不支援 edge、daemon 沒監控到、debounce 過長或 signal bounce | 看 journal；用 `gpiomon` 測 edge；確認 pull-up/down |
| 一開機 presence 狀態錯 | 上電時序導致 pin 尚未穩定、CPLD 還沒 ready | 加入初始化延遲、穩定條件或由 CPLD 提供 ready bit |
| 元件拔掉後 sensor 還存在 | Entity Manager Probe 沒被撤回、舊式 inventory 未更新 | 查 `DevicePresence` 物件是否移除；查 service log |
| 元件存在但 `Functional=false` | presence 來源正常，但 tach / PMBus / hwmon 故障 | 分開檢查 `Present` 與 `OperationalStatus` 來源 |
| PSU 拔出與 AC lost 混淆 | GPIO presence、PMBus ACK、AC input fault 語意沒分清 | 定義 PSU present、input lost、output fault 三種狀態 |
| Intrusion 無法清除 | `Rearm=Manual` 但未執行 rearm，或硬體 latch 未清 | 確認 D-Bus / Redfish rearm 流程與 CPLD clear rule |
| Intrusion 一直 HardwareIntrusion | polarity 錯、switch 常態電位不同、pull resistor 錯 | 量測開蓋 / 關蓋電位；確認 `GpioPolarity` |
| `IntrusionSensor` service 起不來 | JSON schema 欄位不符、line name 不存在、hwmon path 不存在 | `journalctl -u xyz.openbmc_project.IntrusionSensor.service` |
| Redfish PhysicalSecurity 不更新 | bmcweb mapping 或 object path 不符 | 查 D-Bus path、bmcweb journal、Redfish response |
| event log 沒紀錄 | 沒產生 PropertiesChanged、logging policy 未接上 | 監看 `busctl monitor`、`journalctl`、EventLog |
| CPLD bit 讀值不穩 | I2C timeout、CPLD firmware 版本差異、clear rule 不明 | 建立 register dump；記錄 CPLD version；與 HW 同步 bit 定義 |

建議除錯順序：

```text
1. 先看硬體原始訊號：示波器 / LA / GPIO / CPLD register
2. 再看 kernel 可見狀態：gpioinfo / hwmon / i2c / dmesg
3. 再看 userspace daemon：systemctl / journalctl
4. 再看 D-Bus object：busctl tree / get-property / introspect
5. 再看消費端：Entity Manager Probe、inventory、Redfish、IPMI、event log
```

#### 17.6 Presence / Intrusion / GPIO State Sensor 完整 Checklist

```text
硬體設計階段：
[ ] 元件與 slot 編號確認
[ ] Presence / intrusion / fault / alert 訊號來源確認
[ ] GPIO / CPLD / I2C / hwmon / PCH mapping 完成
[ ] Active high / active low 或 bit value 語意確認
[ ] Pull-up / pull-down 電阻與預設電位確認
[ ] Debounce 需求確認
[ ] Latch 與 clear rule 確認
[ ] Inventory path 與 FRU / asset / association 確認
[ ] Chassis intrusion rearm 模式確認：Automatic / Manual
[ ] Redfish / IPMI / SEL 需求確認

Device Tree / Kernel：
[ ] GPIO controller status = "okay"
[ ] pinctrl 設定正確，pin 未被其他 function 占用
[ ] gpio-line-names 定義正確
[ ] 開機後 gpioinfo 可看到 line name
[ ] 若用 GPIO expander，I2C bus、address、driver probe 正常
[ ] 若用 hwmon，sysfs alarm / fault / intrusion file 存在
[ ] 若用 CPLD，register map 與 driver / daemon 對齊

Entity Manager / Userspace：
[ ] 新設計：GPIODeviceDetect 使用 PresencePinNames / PresencePinValues
[ ] Probe 條件可依 DevicePresence 啟用後續 inventory / sensor
[ ] 舊式：phosphor-multi-gpio-presence LineName / ActiveLow / Inventory 正確
[ ] static inventory 的 Present default 合理
[ ] ChassisIntrusionSensor JSON 欄位符合目前 branch schema
[ ] Fan presence 與 fan tach / functional policy 分開
[ ] PSU presence / AC lost / PMBus fault 分開

D-Bus / 系統整合：
[ ] gpio-presence-sensor service 啟動無錯誤
[ ] Entity Manager 可看到 GPIODeviceDetect 配置
[ ] DevicePresence object 隨插拔正確建立 / 移除
[ ] Inventory.Item.Present 正確變化
[ ] OperationalStatus / Availability 語意正確
[ ] IntrusionSensor service 啟動無錯誤
[ ] Intrusion Status 可讀取 Normal / HardwareIntrusion
[ ] Manual rearm 或 Automatic rearm 行為符合需求

硬體測試：
[ ] 元件插入 / 移除時，GPIO / CPLD raw value 正確變化
[ ] Present=true / false 與 raw value 對應正確
[ ] 插拔 debounce 後沒有 bounce event storm
[ ] AC cycle 後 presence 初始值正確
[ ] BMC reboot 後 presence / intrusion 狀態合理
[ ] 機殼開啟 / 關閉時 intrusion 狀態正確
[ ] Manual rearm 前後行為已驗證
[ ] Hot-swap 元件移除時，對應 sensors / inventory / fan policy 行為正確

Redfish / IPMI / 事件：
[ ] Redfish Chassis / Assembly / Inventory 可反映 presence
[ ] Redfish PhysicalSecurity 可反映 intrusion
[ ] IPMI SDR / sensor list / SEL 符合平台需求
[ ] presence change 或 intrusion event 有 journal / EventLog / SEL
[ ] Redfish / IPMI 不會把 absent 誤報為 failed，或把 failed 誤報為 absent
```

#### 17.7 常用指令速查

```bash
# GPIO / device tree
gpiodetect
gpioinfo
gpioget gpiochip0 <offset-or-line-name>
gpiomon gpiochip0 <offset-or-line-name>
find /sys/firmware/devicetree/base -name '*gpio*' -o -name '*pinctrl*'

# hwmon / I2C
find /sys/class/hwmon -maxdepth 3 -type f | grep -E 'present|fault|alarm|intrusion|label|name'
i2cdetect -y <bus>
i2cget -y <bus> <addr> <reg>

# service
systemctl status xyz.openbmc_project.EntityManager.service
systemctl status xyz.openbmc_project.gpiopresence.service
systemctl status xyz.openbmc_project.IntrusionSensor.service
journalctl -u xyz.openbmc_project.EntityManager.service -b --no-pager
journalctl -u xyz.openbmc_project.gpiopresence.service -b --no-pager
journalctl -u xyz.openbmc_project.IntrusionSensor.service -b --no-pager

# D-Bus
busctl tree xyz.openbmc_project.EntityManager
busctl tree xyz.openbmc_project.Inventory.Manager
busctl tree xyz.openbmc_project.IntrusionSensor
busctl introspect <service> <object-path>
busctl get-property <service> <object-path> <interface> <property>
busctl monitor
```

#### 17.9 本章參考資料

- OpenBMC GPIO based hardware inventory design：<https://github.com/openbmc/docs/blob/master/designs/inventory/gpio-based-hardware-inventory.md>
- OpenBMC entity-manager gpio-presence-sensor README：<https://github.com/openbmc/entity-manager/blob/master/src/gpio-presence/README.md>
- OpenBMC dbus-sensors README：<https://github.com/openbmc/dbus-sensors>
- OpenBMC dbus-sensors Intrusion Sensors 說明：<https://deepwiki.com/openbmc/dbus-sensors/3.6.2-intrusion-sensors>
- OpenBMC / dbus-sensors intrusion Rearm property commit 說明：<https://gbmc.googlesource.com/dbus-sensors/+/b318dcaeaf0e847b6f0e2bc9365873ebe4e5dabd>
- Linux GPIO character device / libgpiod 文件：<https://www.kernel.org/doc/html/latest/driver-api/gpio/>
- DMTF Redfish Chassis / PhysicalSecurity schema：<https://redfish.dmtf.org/schemas/>




---

## 第四部分：Host Communication


### 18. KCS / BT / SSIF / eSPI

KCS/IPMI 適合 host OS 與 BMC 的 legacy 管理通道；eSPI 是新平台常見 host-BMC sideband，包含 peripheral channel、OOB、virtual wire、flash channel。驗證時需確認 host reset、PLTRST、virtual wire、POST code、boot progress、watchdog。

### 19. BIOS / UEFI 與 BMC 互動

需建立 BIOS-BMC interface contract：

| Feature        | Transport     | Owner    | Timing   | Data format     | Error handling |
| -------------- | ------------- | -------- | -------- | --------------- | -------------- |
| POST code      | LPC/eSPI      | BIOS/BMC | POST     | byte/code table | timeout        |
| Boot progress  | IPMI/PLDM/OEM | BIOS/BMC | POST     | enum            | last state     |
| Boot order     | Redfish/IPMI  | BMC/BIOS | pre-boot | attribute       | reject/retry   |
| Host inventory | PLDM/IPMI/OEM | BIOS/BMC | POST/OS  | FRU format      | stale mark     |

### 20. MCTP / PLDM / SPDM

本章整理 BMC 平台中 MCTP、PLDM 與 SPDM 的架構、porting、bring-up、除錯與驗收方法。MCTP（Management Component Transport Protocol）是平台內部管理通訊的傳輸層，可承載在 SMBus / I2C、PCIe VDM、I3C、UART / serial、USB 等不同媒體上，並以 EID（Endpoint ID）描述管理 endpoint。PLDM（Platform Level Data Model）是 MCTP 之上的管理資料模型，可用於 base discovery、platform monitoring/control、BIOS 設定、FRU inventory、firmware update、event。SPDM（Security Protocol and Data Model）則提供裝置認證、憑證、量測、challenge、session 與安全訊息基礎。

BMC 平台採用 MCTP / PLDM / SPDM 後，管理路徑會從傳統 IPMI / SMBus / vendor command 分散模式，逐步收斂到標準化 transport、endpoint discovery、message type、terminus、PDR、certificate chain、measurement 與 firmware update flow。這一章的目標是讓新平台 porting 能清楚回答：哪條 physical link 跑 MCTP、誰是 bus owner、EID 如何分配、endpoint 支援哪些 message type、PLDM terminus 如何建立、PDR / sensor / FRU / firmware update 如何對映到 OpenBMC D-Bus、SPDM attestation 與 secure session 是否啟用，以及發生 timeout / discovery fail / attestation fail 時要收哪些 log。

#### 20.1 分層模型與資料流

建議先用下列分層理解 MCTP / PLDM / SPDM：

```text
Physical / Binding layer
  SMBus/I2C、PCIe VDM、I3C、USB、serial、vendor bridge
    ↓
MCTP transport layer
  EID、message type、fragmentation、routing、control command、MTU
    ↓
Upper protocols
  PLDM、SPDM、NC-SI over MCTP、vendor-defined message
    ↓
OpenBMC services
  mctpd、pldmd、libpldm、SPDM requester/responder、platform daemon
    ↓
D-Bus / inventory / sensors / firmware update / security policy
    ↓
Redfish / IPMI / event / telemetry / field service
```

<table>
<tr><th>層級</th><th>主要責任</th><th>常見資料</th><th>排查入口</th></tr>
<tr><td>Physical binding</td><td>實際通訊媒體與封包承載</td><td>I2C bus、PCIe BDF、I3C dynamic address、link state</td><td>scope / LA、lspci、i2cdetect、kernel log</td></tr>
<tr><td>MCTP</td><td>endpoint 定址、routing、message type、MTU、fragmentation</td><td>EID、UUID、network id、route、message tag</td><td>mctp tools、mctpd D-Bus、tcpdump / trace、journal</td></tr>
<tr><td>PLDM</td><td>平台管理資料模型</td><td>terminus、TID、PDR、sensor、FRU、BIOS attributes、FW update</td><td>pldmtool、pldmd journal、PDR dump、D-Bus object</td></tr>
<tr><td>SPDM</td><td>裝置身分、認證、量測、安全 session</td><td>capabilities、algorithms、cert chain、measurement、session id</td><td>SPDM trace、libspdm log、security event</td></tr>
<tr><td>OpenBMC integration</td><td>將資料轉成 D-Bus / Redfish / update flow</td><td>inventory、sensor、version、event、firmware activation</td><td>busctl、bmcweb、software inventory、EventLog</td></tr>
</table>

#### 20.2 MCTP 基本概念

MCTP 是管理元件間的 common transport。它以 endpoint 為單位建立通訊，不要求上層協定知道底層是 SMBus、PCIe VDM 或其他 media。

常見名詞：

<table>
<tr><th>名詞</th><th>說明</th><th>Bring-up 注意事項</th></tr>
<tr><td>Endpoint</td><td>支援 MCTP 的管理端點，例如 BMC、NIC、GPU、CXL device、retimer、satellite controller</td><td>需確認 Endpoint UUID、EID、message type support</td></tr>
<tr><td>EID</td><td>Endpoint ID，MCTP network 內的 logical address</td><td>需定義 static / dynamic 分配與 persistence</td></tr>
<tr><td>Bus owner</td><td>某個 binding 上負責 discovery / EID assignment 的管理者</td><td>多 BMC 或 host / BMC 共用時需清楚定義</td></tr>
<tr><td>Message type</td><td>MCTP payload 類型，例如 Control、PLDM、SPDM、NC-SI、Vendor Defined</td><td>endpoint discovery 後需確認支援清單</td></tr>
<tr><td>MTU / packet size</td><td>單段 transport 可承載大小</td><td>PLDM FW update / SPDM cert chain 會受到影響</td></tr>
<tr><td>Message tag</td><td>request / response match 的 tag</td><td>timeout / retry / concurrent request 需管理</td></tr>
<tr><td>Routing</td><td>跨 bridge / 多 segment MCTP path</td><td>需保存 route table 與 bridge entry</td></tr>
<tr><td>Network ID</td><td>Linux / OpenBMC 中區分 MCTP network 的識別</td><td>多 transport 平台需避免混淆</td></tr>
</table>

MCTP bring-up 最小成功條件：

- physical link 可用，例如 I2C ACK、PCIe device present、I3C target online。
- MCTP binding driver / daemon 啟動。
- endpoint discovery 成功，能取得 endpoint ID / UUID / supported message types。
- BMC route table 能送 request 並收到 response。
- 上層 PLDM / SPDM 能完成 basic command，例如 GetPLDMTypes 或 SPDM GET_VERSION。

#### 20.3 MCTP transport binding：SMBus / I2C、PCIe VDM、I3C

不同 binding 的排查方式差異很大，文件需保存每條 link 的 owner、physical path、EID 分配與上層用途。

<table>
<tr><th>Binding</th><th>常見用途</th><th>優點</th><th>風險</th><th>第一輪檢查</th></tr>
<tr><td>SMBus / I2C</td><td>PSU、VR、retimer、satellite controller、OCP NIC sideband</td><td>硬體普遍、低成本</td><td>bus stuck、address conflict、低速、大 message fragment 成本</td><td>I2C waveform、mctp-i2c driver、bus owner</td></tr>
<tr><td>PCIe VDM</td><td>NIC、GPU、accelerator、CXL / PCIe endpoint</td><td>適合 PCIe device 管理</td><td>依 host power / link training / BDF；hot-plug 複雜</td><td>lspci、PCIe link state、VDM support</td></tr>
<tr><td>I3C</td><td>新平台管理 bus</td><td>支援動態 address、較高 throughput</td><td>controller / target 支援度與 tooling 需確認</td><td>I3C bus enumeration、kernel log</td></tr>
<tr><td>USB / serial</td><td>特定 bridge 或 debug path</td><td>可跨 subsystem</td><td>標準化與量產支援需確認</td><td>driver、device node、protocol trace</td></tr>
<tr><td>Vendor bridge</td><td>CPLD / MCU 轉接</td><td>可支援既有硬體</td><td>需清楚 bridge 行為、MTU、retry、error mapping</td><td>bridge log、vendor tool、scope</td></tr>
</table>

平台表格範本：

<table>
<tr><th>Endpoint</th><th>Binding</th><th>Physical path</th><th>EID</th><th>UUID</th><th>Message types</th><th>Owner</th><th>狀態</th></tr>
<tr><td>OCP NIC</td><td>PCIe VDM / SMBus [待填]</td><td>[待填]</td><td>[待填]</td><td>[待填]</td><td>PLDM / SPDM [待填]</td><td>BMC / Host [待填]</td><td>[待確認]</td></tr>
<tr><td>Retimer0</td><td>I2C / SMBus</td><td>[待填]</td><td>[待填]</td><td>[待填]</td><td>PLDM / SPDM [待填]</td><td>BMC</td><td>[待確認]</td></tr>
<tr><td>GPU0</td><td>PCIe VDM</td><td>[待填]</td><td>[待填]</td><td>[待填]</td><td>PLDM / SPDM / vendor [待填]</td><td>BMC / Host</td><td>[待確認]</td></tr>
</table>

#### 20.4 Linux / OpenBMC MCTP stack

OpenBMC 平台可能採用 kernel MCTP socket（AF_MCTP）、userspace mctpd、或 vendor stack。新平台需要先確認目前專案的 MCTP stack 邊界。

常見元件：

<table>
<tr><th>元件</th><th>用途</th><th>常見檢查點</th></tr>
<tr><td>kernel MCTP</td><td>提供 MCTP network、route、AF_MCTP socket 與 binding driver</td><td>kernel config、link、route、netlink</td></tr>
<tr><td>mctpd</td><td>管理 endpoint discovery、EID、D-Bus 介面</td><td>service status、D-Bus object、endpoint signal</td></tr>
<tr><td>mctp tools</td><td>查 link / route / endpoint，送 control command</td><td>工具版本與 kernel stack 是否相容</td></tr>
<tr><td>pldmd</td><td>監聽 MCTP endpoint，建立 PLDM terminus，處理 PLDM request / response</td><td>terminus table、PDR、pldmtool</td></tr>
<tr><td>SPDM requester</td><td>對 endpoint 執行 discovery、certificate、challenge、measurement</td><td>policy、cert chain、algorithm、session</td></tr>
</table>

常用檢查：

```bash
# service 與 kernel log
systemctl status mctpd --no-pager 2>/dev/null || true
systemctl status pldmd --no-pager 2>/dev/null || true
journalctl -u mctpd -b --no-pager 2>/dev/null
journalctl -u pldmd -b --no-pager 2>/dev/null
dmesg | grep -Ei 'mctp|pldm|spdm|vdm|i3c'

# D-Bus
busctl tree xyz.openbmc_project.MCTP 2>/dev/null || true
busctl tree xyz.openbmc_project.PLDM 2>/dev/null || true
busctl tree xyz.openbmc_project.ObjectMapper | grep -Ei 'MCTP|PLDM|SPDM' || true

# Linux MCTP tools，依 image 內容而定
mctp link 2>/dev/null || true
mctp route 2>/dev/null || true
mctp addr 2>/dev/null || true
```

#### 20.5 MCTP discovery、EID 分配與 route

MCTP discovery 是上層 PLDM / SPDM 能否運作的基礎。若 endpoint 沒有 EID 或 route 不正確，上層常只看到 timeout。

建議記錄欄位：

<table>
<tr><th>項目</th><th>說明</th><th>資料來源</th></tr>
<tr><td>EID assignment mode</td><td>static、dynamic、pre-assigned、host assigned</td><td>platform design、mctpd config</td></tr>
<tr><td>Bus owner</td><td>誰負責 Set Endpoint ID / discovery</td><td>BMC / host / bridge policy</td></tr>
<tr><td>Endpoint UUID</td><td>endpoint 穩定識別</td><td>MCTP Control Get Endpoint UUID</td></tr>
<tr><td>Supported message types</td><td>PLDM、SPDM、vendor-defined 等</td><td>MCTP Control Get Message Type Support</td></tr>
<tr><td>MTU</td><td>path transmission unit</td><td>MCTP Control / binding config</td></tr>
<tr><td>Route table</td><td>EID 到 link / next hop 的對照</td><td>mctp route / D-Bus</td></tr>
<tr><td>Endpoint state</td><td>discovered、reachable、lost、removed</td><td>mctpd journal / D-Bus signal</td></tr>
</table>

常見問題：

- BMC 與 host 都嘗試當 bus owner，造成 EID 變動或重複。
- Endpoint reset 後 EID 消失，上層 PLDM terminus 沒有重新 discovery。
- Hot-plug 端點移除後 route 還在，造成 request timeout。
- 多 transport 到同一 endpoint 時，route priority 未定義。
- MCTP bridge 兩側 network id / EID range 設計不清楚。

#### 20.6 PLDM 基本概念與 Types

PLDM 定義多種 Type，每種 Type 對應一組管理功能。OpenBMC `pldmd` 常透過 MCTP 發現 endpoint，建立 terminus，讀取 PDR，再把 sensor / inventory / BIOS / firmware update 資料接到 D-Bus 或平台 service。

<table>
<tr><th>PLDM Type</th><th>用途</th><th>BMC 常見使用情境</th></tr>
<tr><td>Type 0 Base</td><td>protocol discovery、version、type、command support</td><td>建立 terminus 的第一步</td></tr>
<tr><td>Type 1 SMBIOS</td><td>SMBIOS table transfer</td><td>host inventory / system info，依平台支援</td></tr>
<tr><td>Type 2 Platform</td><td>sensor、effecter、PDR、event</td><td>remote sensor、state set、control</td></tr>
<tr><td>Type 3 BIOS</td><td>BIOS attributes 與 configuration</td><td>遠端 BIOS 設定 / host firmware config</td></tr>
<tr><td>Type 4 FRU</td><td>FRU records 與 inventory</td><td>endpoint FRU / device inventory</td></tr>
<tr><td>Type 5 Firmware Update</td><td>標準化裝置 FW update flow</td><td>NIC、retimer、satellite controller 更新</td></tr>
<tr><td>OEM / vendor Type</td><td>廠商擴充</td><td>平台特定功能，需風險控管</td></tr>
</table>

PLDM bring-up 最小流程：

```text
MCTP endpoint reachable
    ↓
PLDM Base：GetPLDMVersion / GetPLDMTypes / GetPLDMCommands
    ↓
建立 terminus / TID
    ↓
若支援 Platform：讀 PDR repository
    ↓
建立 sensor / effecter / inventory / event mapping
    ↓
若支援 FRU：讀 FRU records 並對映 inventory
    ↓
若支援 FW Update：查 component / version / transfer capability
```

#### 20.7 PLDM PDR、sensor、effecter 與 event

PDR（Platform Descriptor Record）是 PLDM Platform Monitoring and Control 的核心資料結構，用來描述 sensor、effecter、entity association、state set 等。BMC 需要理解 PDR 才能把 remote endpoint 的 sensor 和 control 對映到 OpenBMC D-Bus。

<table>
<tr><th>資料</th><th>用途</th><th>OpenBMC 對映</th><th>注意事項</th></tr>
<tr><td>Numeric Sensor PDR</td><td>連續數值 sensor，例如 temperature、voltage、power</td><td>D-Bus sensor Value / thresholds</td><td>scale、unit、range、state 需正確</td></tr>
<tr><td>State Sensor PDR</td><td>離散狀態，例如 presence、fault、link state</td><td>inventory / event / state property</td><td>state set mapping 需完整</td></tr>
<tr><td>Numeric Effecter PDR</td><td>可調數值，例如 power limit、fan target</td><td>control interface / policy daemon</td><td>權限與安全限制需定義</td></tr>
<tr><td>State Effecter PDR</td><td>可設狀態，例如 reset、enable、mode</td><td>control method</td><td>不可無限制暴露危險控制</td></tr>
<tr><td>Entity Association PDR</td><td>描述元件層級與關係</td><td>inventory association</td><td>需與 Redfish / service manual slot 名稱對齊</td></tr>
<tr><td>PLDM Event</td><td>endpoint 主動上報事件</td><td>Logging / EventLog / sensor update</td><td>需處理 ack、sequence、去重</td></tr>
</table>

PDR 排查：

```bash
# 工具名稱依平台 image 而定
pldmtool base GetPLDMTypes 2>/dev/null || true
pldmtool base GetPLDMCommands 2>/dev/null || true
pldmtool platform GetPDR 2>/dev/null || true
journalctl -u pldmd -b --no-pager | grep -Ei 'PDR|terminus|sensor|effecter|event'
```

常見問題：

- PDR scale / unit 錯，造成 Redfish sensor 值不合理。
- PDR entity association 不完整，sensor 沒有掛到正確 inventory。
- Endpoint event enable 未設定，sensor 狀態只能靠 polling。
- Event receiver 未註冊或 ack flow 錯，endpoint 重複送 event。
- PDR repository change 事件後，BMC 未重新讀 PDR。

#### 20.8 PLDM FRU、BIOS 與 Firmware Update

PLDM FRU 可提供 endpoint inventory；PLDM BIOS 可支援 host firmware / BIOS attributes；PLDM Firmware Update 可支援標準化裝置更新。這些功能通常比 basic sensor 更牽涉產品政策、權限與安全。

PLDM FRU：

- 需定義 FRU record set 如何對映到 OpenBMC inventory object。
- 需區分 endpoint 自身 FRU 與 endpoint 管理的 downstream FRU。
- 若同一欄位也存在 IPMI FRU / PMBus MFR / Redfish，需定義優先順序。

PLDM BIOS：

- 需定義哪些 BIOS attributes 可讀 / 可寫。
- 需確認變更何時生效：立即、下次 host reboot、下次 AC cycle。
- 需保存 BIOS attribute pending / current / default 的差異。
- 需有權限、audit log 與 rollback policy。

PLDM Firmware Update：

- 需確認 endpoint 支援的 transfer size、component classification、activation method。
- 需定義 firmware image package、version、signature、component ID 與 rollback policy。
- 需處理 update 中斷、endpoint reset、BMC reset、host power state 變化。
- 需將 activation / progress / failure reason 對映到 OpenBMC software inventory、Redfish UpdateService 與 event log。

#### 20.9 SPDM 基本概念與安全流程

SPDM 用於 requester 與 responder 之間的安全協商、裝置認證、量測與安全 session。BMC 常作為 requester，對 NIC、GPU、CXL device、retimer、security component 等 endpoint 進行 attestation。

典型 SPDM 流程：

```text
GET_VERSION / VERSION
    ↓
GET_CAPABILITIES / CAPABILITIES
    ↓
NEGOTIATE_ALGORITHMS / ALGORITHMS
    ↓
GET_DIGESTS / DIGESTS
    ↓
GET_CERTIFICATE / CERTIFICATE
    ↓
CHALLENGE / CHALLENGE_AUTH
    ↓
GET_MEASUREMENTS / MEASUREMENTS
    ↓
可選：KEY_EXCHANGE / FINISH 建立 secured session
    ↓
可選：secured message carrying management traffic
```

SPDM porting 需要先定義：

<table>
<tr><th>項目</th><th>需要確認</th><th>備註</th></tr>
<tr><td>Requester / Responder</td><td>BMC、host、device 誰發起 SPDM</td><td>多 requester 場景需協調 session</td></tr>
<tr><td>Transport binding</td><td>SPDM over MCTP、PCIe DOE、TCP、storage binding 等</td><td>本章聚焦 SPDM over MCTP</td></tr>
<tr><td>Version</td><td>雙方支援 SPDM 版本</td><td>需與 libspdm / endpoint firmware 對齊</td></tr>
<tr><td>Algorithms</td><td>hash、asym、DHE、AEAD、measurement hash</td><td>安全政策需定義最低要求</td></tr>
<tr><td>Certificate chain</td><td>slot、root CA、intermediate、device cert</td><td>需有 trust anchor 與 provisioning 流程</td></tr>
<tr><td>Measurements</td><td>measurement block、index、manifest、TCB value</td><td>需定義 expected value 與驗證資料庫</td></tr>
<tr><td>Session</td><td>是否建立 secure session</td><td>會影響 message size、timeout、key lifecycle</td></tr>
<tr><td>Policy</td><td>認證失敗如何處理</td><td>log only、degrade、block device、raise event</td></tr>
</table>

#### 20.10 SPDM 信任鏈、量測與 policy

SPDM 是否有價值，取決於 trust anchor、certificate validation、measurement expected value 與 policy 是否完整。只送 GET_VERSION 不代表完成裝置安全驗證。

建議政策表：

<table>
<tr><th>檢查項目</th><th>Pass 條件</th><th>Fail 行為</th><th>Log / Event</th></tr>
<tr><td>版本支援</td><td>endpoint 支援平台允許的 SPDM version</td><td>標記 unsupported</td><td>Warning event</td></tr>
<tr><td>演算法</td><td>符合最低 hash / asym / AEAD 要求</td><td>拒絕 attestation 或 downgrade warning</td><td>Security event</td></tr>
<tr><td>憑證鏈</td><td>可追溯到信任錨且未過期 / revoked</td><td>Functional=false 或 security health warning</td><td>Critical / Warning</td></tr>
<tr><td>Challenge</td><td>signature 驗證通過</td><td>不信任 endpoint</td><td>Critical event</td></tr>
<tr><td>Measurements</td><td>measurement digest 與 expected value / allowlist 符合</td><td>依產品策略隔離或告警</td><td>Security event + raw digest</td></tr>
<tr><td>Session</td><td>key exchange 成功，secured message 可收發</td><td>fallback 或阻擋敏感 command</td><td>Warning event</td></tr>
</table>

注意事項：

- 憑證與 measurement expected value 屬於安全資料，需有安全更新與回復機制。
- 若允許 firmware update 改變 measurement，update flow 必須同步更新 expected value 或 manifest。
- SPDM log 不應記錄 private key、session secret 或完整敏感資料。
- Attestation 結果需能對映到 inventory / Redfish Health / EventLog / security audit。

#### 20.11 OpenBMC 整合：D-Bus、Inventory、Redfish、Event

MCTP / PLDM / SPDM 的結果不應只停在 protocol tool output，應整合到平台狀態。

<table>
<tr><th>資料</th><th>OpenBMC 對映</th><th>外部呈現</th><th>注意事項</th></tr>
<tr><td>MCTP endpoint</td><td>D-Bus endpoint object / inventory association</td><td>Redfish OEM / inventory</td><td>endpoint remove 時需更新</td></tr>
<tr><td>PLDM FRU</td><td>inventory Asset / FRU fields</td><td>Redfish Chassis / Assembly / Device</td><td>需定義權威端</td></tr>
<tr><td>PLDM sensor</td><td>D-Bus Sensor.Value / Availability / thresholds</td><td>Redfish Sensor / Thermal / Power</td><td>scale / unit / association 要正確</td></tr>
<tr><td>PLDM event</td><td>phosphor-logging entry</td><td>SEL / Redfish EventLog / EventService</td><td>需去重與 ack</td></tr>
<tr><td>PLDM FW update</td><td>software inventory / activation</td><td>Redfish UpdateService</td><td>需 progress / failure reason</td></tr>
<tr><td>SPDM attestation</td><td>security status / inventory decorator / event</td><td>Redfish Health / Security event</td><td>需保護敏感資料</td></tr>
</table>

#### 20.12 Build / Yocto / Kernel 設定重點

平台需確認 kernel、daemon、library、tool、D-Bus interface 與 service file 都包含在 image。

Build 端檢查：

```bash
# kernel config
bitbake -e virtual/kernel | grep '^S='
grep -R "CONFIG_MCTP" tmp/work/*/linux-*/build/.config 2>/dev/null || true

# package / recipe
bitbake -s | grep -Ei 'mctp|pldm|spdm|libmctp|libpldm|libspdm'
bitbake obmc-phosphor-image -g

# service file / package content
find tmp/work -path '*mctp*' -o -path '*pldm*' -o -path '*spdm*' | head -200
```

Target 端檢查：

```bash
systemctl list-units | grep -Ei 'mctp|pldm|spdm'
which mctp 2>/dev/null || true
which pldmtool 2>/dev/null || true
ls -l /usr/bin | grep -Ei 'mctp|pldm|spdm' || true
```

需保存的版本：

- kernel version 與 MCTP config。
- mctpd / pldmd / libpldm / libmctp / SPDM library 版本或 commit。
- endpoint firmware version。
- PLDM / MCTP / SPDM spec version 與 vendor compliance statement。
- Yocto layer / recipe commit。

#### 20.13 Target 端 log 收集套件

```bash
mkdir -p /tmp/mctp-pldm-spdm-debug
cat /etc/os-release > /tmp/mctp-pldm-spdm-debug/os-release.txt
uname -a > /tmp/mctp-pldm-spdm-debug/uname.txt
cat /proc/cmdline > /tmp/mctp-pldm-spdm-debug/proc-cmdline.txt

dmesg -T > /tmp/mctp-pldm-spdm-debug/dmesg.txt
journalctl -b --no-pager > /tmp/mctp-pldm-spdm-debug/journal.txt
systemctl --failed > /tmp/mctp-pldm-spdm-debug/systemctl-failed.txt 2>&1

# services
systemctl status mctpd --no-pager > /tmp/mctp-pldm-spdm-debug/mctpd-status.txt 2>&1 || true
systemctl status pldmd --no-pager > /tmp/mctp-pldm-spdm-debug/pldmd-status.txt 2>&1 || true
journalctl -u mctpd -b --no-pager > /tmp/mctp-pldm-spdm-debug/mctpd-journal.txt 2>&1 || true
journalctl -u pldmd -b --no-pager > /tmp/mctp-pldm-spdm-debug/pldmd-journal.txt 2>&1 || true

# D-Bus
busctl tree xyz.openbmc_project.ObjectMapper > /tmp/mctp-pldm-spdm-debug/objectmapper.txt 2>&1
busctl tree xyz.openbmc_project.MCTP > /tmp/mctp-pldm-spdm-debug/dbus-mctp.txt 2>&1 || true
busctl tree xyz.openbmc_project.PLDM > /tmp/mctp-pldm-spdm-debug/dbus-pldm.txt 2>&1 || true

# MCTP tools
mctp link > /tmp/mctp-pldm-spdm-debug/mctp-link.txt 2>&1 || true
mctp addr > /tmp/mctp-pldm-spdm-debug/mctp-addr.txt 2>&1 || true
mctp route > /tmp/mctp-pldm-spdm-debug/mctp-route.txt 2>&1 || true

# PLDM tools
pldmtool base GetPLDMTypes > /tmp/mctp-pldm-spdm-debug/pldm-types.txt 2>&1 || true
pldmtool base GetPLDMCommands > /tmp/mctp-pldm-spdm-debug/pldm-commands.txt 2>&1 || true
pldmtool platform GetPDR > /tmp/mctp-pldm-spdm-debug/pldm-pdr.txt 2>&1 || true

# physical hints
lspci -vv > /tmp/mctp-pldm-spdm-debug/lspci-vv.txt 2>&1 || true
i2cdetect -l > /tmp/mctp-pldm-spdm-debug/i2cdetect-l.txt 2>&1 || true
ls -l /sys/bus/i2c/devices > /tmp/mctp-pldm-spdm-debug/sys-bus-i2c.txt 2>&1 || true

tar czf /tmp/mctp-pldm-spdm-debug-$(date +%Y%m%d-%H%M%S).tar.gz -C /tmp mctp-pldm-spdm-debug
```

若有 SPDM tool 或 vendor attestation tool，需額外保存：

```bash
# 依平台工具調整
# spdmtool get-version > /tmp/mctp-pldm-spdm-debug/spdm-version.txt
# spdmtool get-capabilities > /tmp/mctp-pldm-spdm-debug/spdm-capabilities.txt
# spdmtool get-measurements > /tmp/mctp-pldm-spdm-debug/spdm-measurements.txt
```

#### 20.14 常見問題與排查入口

<table>
<tr><th>現象</th><th>可能方向</th><th>第一輪檢查</th></tr>
<tr><td>MCTP endpoint 掃不到</td><td>physical link、binding driver、bus owner、endpoint power state</td><td>dmesg、mctpd journal、scope / lspci / i2cdetect</td></tr>
<tr><td>EID 重複或跳動</td><td>多個 bus owner、dynamic EID policy 不一致、endpoint reset</td><td>mctp route、mctpd D-Bus、power timeline</td></tr>
<tr><td>PLDM GetTypes timeout</td><td>MCTP route 錯、message type 不支援、endpoint busy</td><td>MCTP message type support、pldmd journal</td></tr>
<tr><td>PDR 讀取失敗</td><td>terminus 未建立、PDR repository error、large transfer / MTU 問題</td><td>pldmtool、PDR trace、MTU</td></tr>
<tr><td>PLDM sensor 值不合理</td><td>PDR scale / unit / entity mapping 錯</td><td>PDR dump、D-Bus sensor、raw value</td></tr>
<tr><td>PLDM event 重複</td><td>event ack flow 錯、endpoint retry、BMC 未去重</td><td>pldmd journal、event sequence、logging entries</td></tr>
<tr><td>PLDM FW update 中斷</td><td>transfer size、timeout、endpoint reset、activation policy</td><td>update log、MCTP trace、endpoint FW log</td></tr>
<tr><td>SPDM negotiation fail</td><td>version / capability / algorithm mismatch</td><td>SPDM transcript、policy、library version</td></tr>
<tr><td>SPDM certificate fail</td><td>trust anchor、cert chain、time、slot id、revocation</td><td>cert dump、time sync、security policy</td></tr>
<tr><td>SPDM measurement mismatch</td><td>endpoint firmware 不同、manifest 未更新、expected value 錯</td><td>measurement digest、FW version、manifest</td></tr>
<tr><td>Hot-plug 後 endpoint 沒回來</td><td>route stale、discovery 沒重新跑、power state gating</td><td>mctpd signal、kernel hotplug、D-Bus endpoint</td></tr>
<tr><td>Redfish 沒看到 PLDM sensor</td><td>D-Bus association 缺、sensor mapping 未建立</td><td>busctl、ObjectMapper、bmcweb journal</td></tr>
</table>

#### 20.15 Bring-up 建議流程

- 建立 MCTP endpoint 表，列出 endpoint、binding、physical path、power state、owner、EID、UUID、message type。
- 先驗證 physical link，再驗證 MCTP discovery，不要直接從 PLDM timeout 判斷問題。
- 確認 bus owner 與 EID assignment policy，做 BMC reboot、endpoint reset、host power cycle 後確認 EID 穩定性。
- 對每個 endpoint 執行 MCTP Control discovery，保存 UUID、message type、MTU、route。
- 對支援 PLDM 的 endpoint 執行 Base discovery，保存 type / command support。
- 若支援 Platform，讀 PDR repository，建立 sensor / effecter / event mapping，驗證 D-Bus 與 Redfish。
- 若支援 FRU / BIOS / FW update，逐項驗證資料來源、權限、update 中斷回復與 event log。
- 若支援 SPDM，先跑 version / capability / algorithm，再跑 certificate / challenge / measurement，最後依需求測 secure session。
- 對所有安全結果建立 event / inventory / health mapping，不只保留 tool output。
- 做 hot-plug、endpoint reset、BMC reboot、host power state transition、bus fault、timeout、firmware update、attestation fail 測試。
- 保存 mctp-pldm-spdm-debug log、protocol trace、Redfish output、event log、版本與 endpoint firmware 資訊。

#### 20.16 當前平台 MCTP / PLDM / SPDM 實測表

<table>
<tr><th>項目</th><th>指令 / 來源</th><th>實測值</th><th>備註</th></tr>
<tr><td>MCTP kernel config</td><td>kernel .config</td><td>[待填]</td><td>CONFIG_MCTP / binding driver</td></tr>
<tr><td>MCTP services</td><td>systemctl / journal</td><td>[待填]</td><td>mctpd / vendor daemon</td></tr>
<tr><td>Endpoint list</td><td>mctpd D-Bus / mctp tool</td><td>[待填]</td><td>EID / UUID / route</td></tr>
<tr><td>Transport bindings</td><td>schematic / lspci / i2c</td><td>[待填]</td><td>SMBus / PCIe / I3C</td></tr>
<tr><td>Bus owner policy</td><td>platform design</td><td>[待填]</td><td>BMC / host / bridge</td></tr>
<tr><td>Message type support</td><td>MCTP control</td><td>[待填]</td><td>PLDM / SPDM / vendor</td></tr>
<tr><td>PLDM terminus list</td><td>pldmd / pldmtool</td><td>[待填]</td><td>TID / endpoint mapping</td></tr>
<tr><td>PLDM command support</td><td>GetPLDMTypes / Commands</td><td>[待填]</td><td>Base / Platform / FRU / FWU</td></tr>
<tr><td>PDR repository</td><td>pldmtool platform GetPDR</td><td>[待填]</td><td>sensor / effecter count</td></tr>
<tr><td>PLDM sensor mapping</td><td>D-Bus / Redfish</td><td>[待填]</td><td>unit / scale / association</td></tr>
<tr><td>PLDM FRU mapping</td><td>inventory / Redfish</td><td>[待填]</td><td>權威端</td></tr>
<tr><td>PLDM FW update</td><td>update test</td><td>[待填]</td><td>progress / activation / rollback</td></tr>
<tr><td>SPDM version / capability</td><td>SPDM tool / log</td><td>[待填]</td><td>版本與演算法</td></tr>
<tr><td>SPDM certificate</td><td>cert chain validation</td><td>[待填]</td><td>trust anchor / slot</td></tr>
<tr><td>SPDM measurement</td><td>measurement digest</td><td>[待填]</td><td>expected value</td></tr>
<tr><td>Event / health mapping</td><td>EventLog / Redfish</td><td>[待填]</td><td>attestation / PLDM event</td></tr>
</table>

#### 20.17 回查結果

本章已回查前後文並補齊下列銜接點：

- 第 5 章周邊匯流排已介紹 MCTP / PLDM / SPDM 所需 physical binding，本章補上 endpoint、EID、route、PLDM terminus 與 SPDM attestation 流程。
- 第 10 章 I2C / PMBus 已涵蓋 SMBus / I2C bring-up，本章補上 MCTP over SMBus / I2C 的 bus owner、EID 與多 endpoint 注意事項。
- 第 15 章 Inventory / FRU / Asset 已定義資料權威端，本章補上 PLDM FRU 與 endpoint inventory 對映。
- 第 16 章 Logging / Event / Telemetry 已定義事件與安全 log，本章補上 PLDM event、SPDM attestation fail、FW update fail 的 logging / health 對映。
- 第 18～19 章 Host communication 相關章節可引用本章的 host / BMC sideband、PCIe VDM、BIOS / firmware PLDM flow。
- 第 24 章 Security Baseline 可引用本章的 SPDM trust anchor、certificate、measurement、policy 與 audit log。
- 第 25 章 Firmware Update 可引用本章的 PLDM Firmware Update 流程、transfer size、activation 與 rollback 測試。

#### 20.18 驗收 Checklist

-  已建立所有 MCTP endpoint、binding、physical path、EID、UUID、message type 與 owner 表。
-  Physical link、binding driver、mctpd / vendor MCTP daemon 已驗證。
-  EID assignment、bus owner、route table、MTU、message type support 已記錄。
-  BMC reboot、endpoint reset、host power cycle 後，endpoint discovery 與 route 可恢復。
-  PLDM Base discovery、type / command support 已驗證。
-  PLDM PDR repository 可讀，sensor / effecter / event / entity association 對映正確。
-  PLDM sensor 已對映到 D-Bus / Redfish，scale、unit、availability、association 已驗證。
-  PLDM FRU / BIOS / Firmware Update 若平台支援，權限、event、rollback 與 update 中斷回復已測試。
-  SPDM version、capability、algorithm negotiation 已完成。
-  SPDM certificate chain、challenge、measurement 驗證與 policy 已定義。
-  SPDM fail / measurement mismatch / cert fail 會產生 security event，且不洩漏敏感資料。
-  Hot-plug、route stale、timeout、endpoint reset、bus fault、large transfer、event storm 已測試。
-  mctp-pldm-spdm-debug log、protocol trace、journal、Redfish、EventLog、endpoint firmware version 已保存。

#### 20.19 本章參考資料

- DMTF MCTP Base Specification DSP0236: [https://www.dmtf.org/sites/default/files/standards/documents/DSP0236_1.3.3.pdf](https://www.dmtf.org/sites/default/files/standards/documents/DSP0236_1.3.3.pdf)
- DMTF SPDM Specification DSP0274: [https://www.dmtf.org/standards/spdm](https://www.dmtf.org/standards/spdm)
- DMTF SPDM over MCTP Binding Specification DSP0275: [https://www.dmtf.org/sites/default/files/standards/documents/DSP0275_1.0.2.pdf](https://www.dmtf.org/sites/default/files/standards/documents/DSP0275_1.0.2.pdf)
- DMTF libspdm reference implementation: [https://github.com/DMTF/libspdm](https://github.com/DMTF/libspdm)
- OpenBMC MCTP / PLDM communication overview: [https://deepwiki.com/openbmc/docs/4.7-mctp-and-pldm-communication](https://deepwiki.com/openbmc/docs/4.7-mctp-and-pldm-communication)
- OpenBMC PLDM overview: [https://deepwiki.com/openbmc/pldm](https://deepwiki.com/openbmc/pldm)
- OpenBMC MCTP design note: [https://github.com/CodeConstruct/openbmc-docs/blob/master/designs/mctp/mctp.md](https://github.com/CodeConstruct/openbmc-docs/blob/master/designs/mctp/mctp.md)


### 21. IPMI 通用知識

IPMI 提供 sensor、SEL、FRU、power control、SOL、LAN 管理等能力。新設計應限制不安全 cipher suite，並避免新增不必要 OEM command。

OEM command 範本：NetFn、Cmd、Request、Response、Completion Code、權限、狀態依賴、錯誤處理、測試案例。

### 22. Redfish 通用知識

Redfish 資源常用路徑：

- `/redfish/v1/Systems`
- `/redfish/v1/Managers`
- `/redfish/v1/Chassis`
- `/redfish/v1/UpdateService`
- `/redfish/v1/EventService`
- `/redfish/v1/AccountService`
- `/redfish/v1/SessionService`
- `/redfish/v1/TaskService`

Schema 相容策略：新增欄位不得破壞既有 client；OEM extension 需命名清楚；錯誤回應需帶 message registry。

### 23. Network Services

必填：DHCP/static、VLAN、hostname、DNS、NTP/PTP、MAC 來源、bonding、NIC failover、link ready time、IPv6 policy。量測開機可連線時間時要拆分：kernel driver ready、link up、DHCP lease、service listening、API first success。

---

## 第六部分：安全與韌體維運

### 24. Security Baseline

基準項目：secure boot、韌體簽章、anti-rollback、密碼政策、預設帳號、首次登入改密碼、TLS 憑證、IPMI cipher suite、最小服務集、審計 log、debug port policy、secret storage、量產 key 與開發 key 分離。

密碼政策建議與近代 NIST 方向一致：重視長度、阻擋常見或外洩密碼、避免無意義的固定週期變更；但最終仍需依產品安全規範與客戶需求決定。

### 25. Firmware Update

更新流程：上傳 image → 驗證 manifest/signature/version/machine → 建立 software object → activation → progress → reboot 或切換 slot → health check → commit / rollback。

Power loss 測試必做：更新前、寫入 bootloader、寫入 kernel、寫入 rootfs、切 slot、首次開機、commit 前斷電。

### 26. Secure Recovery / RMA / Field Service

RMA 應先保存：BMC version、BIOS version、CPLD version、boot count、reset reason、SEL、journal、dmesg、update history、FRU、sensor snapshot、network config、crash dump。Factory reset 需明確列出會清除與不會清除的資料。

---

## 第七部分：除錯、效能與測試

### 27. Debug Methodology

問題單最小資料：現象、重現率、版本、步驟、預期、實際、log、量測點、最近變更、是否與 AC/DC cycle 有關。排查時先固定硬體、韌體、設定與測試工具版本。

### 28. Debug Toolkit

常用指令：

```bash
dmesg -T
journalctl -b
journalctl -u <service>
busctl tree xyz.openbmc_project.ObjectMapper
gpiodetect && gpioinfo
i2cdetect -y <bus>
i2cget -y <bus> <addr> <reg>
tcpdump -i <iface> -w /tmp/cap.pcap
ethtool <iface>
ipmitool sensor list
curl -k https://<bmc>/redfish/v1/
```

### 29. 各類 Sensor 共用除錯指令及附錄

本節整理各類 Sensor 共用的除錯入口，適用於 ADC、Temperature、Voltage、Current、Power、Fan Tach、Fan PWM、PSU、CPU、NVMe、GPU、External 與 Presence 類型。實務上建議依「硬體訊號 → kernel / sysfs → sensor daemon → D-Bus → association / inventory → Redfish / IPMI → event / log」的順序排查，避免只看單一介面造成判讀落差。

#### 29.1 除錯路徑總覽

Sensor 問題通常可以先切成六層：

| 層級 | 主要確認項目 | 常見工具 |
| ---- | ------------ | -------- |
| 硬體 / bus | 電源、reset、I2C ACK、PMBus page、ADC channel、tach / PWM 波形、GPIO polarity | 示波器、DMM、LA、`i2cdetect`、CPLD register |
| Kernel / driver | driver probe、Device Tree、hwmon / iio / gpio / peci / mctp node | `dmesg`、`ls /sys/class/hwmon`、`find /sys` |
| sysfs | `*_input`、`*_label`、`*_enable`、`pwm*`、單位與 scale | `cat`、`grep`、`find` |
| OpenBMC daemon | Entity Manager config、dbus-sensors / phosphor-hwmon service、power state gating | `systemctl`、`journalctl` |
| D-Bus | object path、service name、Value、Unit、Availability、Functional、Threshold | `busctl tree`、ObjectMapper `GetSubTree`、`get-property` |
| 外部介面 | Redfish / IPMI 是否有值、狀態、閾值、inventory association、event | `curl`、`ipmitool`、Redfish validator |

建議先保存下列資訊，方便跨 HW / BMC / BIOS / CPLD / ME / FW 同步：

- BMC image version、kernel commit、DTS commit、Entity Manager JSON commit。
- sensor 名稱、D-Bus path、Redfish URI、IPMI SDR name。
- bus / mux channel / address / page / channel / label / hwmon name。
- 量測值、sysfs 值、D-Bus 值、Redfish 值、IPMI 值。
- service status、journal、dmesg、ObjectMapper 查詢結果。
- host power state、device presence、CPLD / PSU / VR fault status。

#### 29.2 Kernel / sysfs

Kernel / sysfs 層要先確認 driver 是否有 probe、hwmon / iio / gpio / peci / mctp node 是否存在，以及 sysfs 數值單位是否符合 Linux hwmon 慣例。

```bash
# sensor / hwmon 相關 kernel log
dmesg | grep -i sensor
dmesg | grep -i hwmon
dmesg | grep -Ei 'i2c|pmbus|adc|iio|peci|tach|fan|thermal|nvme|mctp|gpio'

# hwmon 裝置清單
ls -l /sys/class/hwmon/
cat /sys/class/hwmon/hwmon*/name

# 找出所有常見 sensor input
find /sys/class/hwmon -name '*_input' -o -name '*_label' -o -name 'pwm*' | sort

# 顯示 hwmon name 與 input 對照
for h in /sys/class/hwmon/hwmon*; do
    echo "== $h =="
    cat "$h/name" 2>/dev/null
    for f in "$h"/*_label "$h"/*_input "$h"/pwm*; do
        [ -e "$f" ] && echo "$(basename "$f")=$(cat "$f" 2>/dev/null)"
    done
done
```

常見 hwmon 檔名與單位：

| sysfs 類型 | 常見檔案 | 常見單位 / 意義 | 注意事項 |
| ---------- | -------- | --------------- | -------- |
| Voltage | `in*_input` | mV | 電阻分壓、VR page、PSU label 需由平台設定補正 |
| Temperature | `temp*_input` | millidegree Celsius | 例：`30125` 代表 30.125°C |
| Current | `curr*_input` | mA | shunt resistance、PMBus format、driver scale 需確認 |
| Power | `power*_input` | µW | OpenBMC 顯示常轉成 W，需避免 double scale |
| Fan Tach | `fan*_input` | RPM | PPR、tach polarity、dual rotor mapping 需確認 |
| PWM | `pwm*` | raw duty，常見 0–255 | 不同 driver 的 `pwm*_enable` 語意可能不同 |
| Energy | `energy*_input` | µJ 或 driver 定義 | Redfish / telemetry 使用前需確認累積範圍與 rollover |

sysfs 常見判讀方向：

- `hwmon*/name` 存在但沒有對應 `*_input`：driver 已 probe，但該 channel 未啟用、label 不符、硬體不支援、page / phase 未選到。
- `*_input` 固定 0：可能是硬體未上電、bus 讀到 0、scale / channel 錯、sensor daemon power state gating。
- sysfs 有值但 D-Bus 沒 sensor：多半在 Entity Manager config、daemon matching、service 啟動或 JSON type / index / label 對應。
- D-Bus 有值但 Redfish 沒值：常見在 chassis / inventory association、bmcweb path mapping、Redfish feature flag 或 service cache。

#### 29.3 I2C / SMBus / PMBus

I2C / SMBus / PMBus 排查前要先確認 bus number、mux channel、address、device power state、host / BMC ownership，以及該 device 是否允許被掃描。部分 PMBus、EEPROM、VR、MCU 裝置在不合適的時間讀取可能造成狀態改變或拉長 bus timeout，`i2cdetect`、`i2cdump` 應在知道風險後使用。

```bash
# 列出 I2C bus
ls -l /dev/i2c-*
i2cdetect -l

# 掃描指定 bus；執行前需確認該 bus 上 device 可接受 probing
i2cdetect -y <bus>

# 讀取單一 register；PMBus 需確認 command/page
i2cget -y <bus> <addr> <reg>

# dump register；可能對部分 device 有副作用，建議只在已確認安全時使用
i2cdump -y <bus> <addr>

# 常見 PMBus：先確認 page，再讀 command；實際 command 依 PMBus / vendor spec
# PAGE=0x00, READ_VOUT=0x8B, READ_IOUT=0x8C, READ_TEMPERATURE_1=0x8D,
# READ_FAN_SPEED_1=0x90, READ_POUT=0x96, READ_PIN=0x97, STATUS_WORD=0x79
```

I2C / PMBus 檢查表：

| 項目 | 確認方式 | 常見問題 |
| ---- | -------- | -------- |
| Bus number | `i2cdetect -l`、DTS、schematic | BMC kernel bus 編號與 schematic bus name 不同 |
| Mux channel | `/sys/bus/i2c/devices`、mux driver log | mux 未 probe、channel 未 enable、上層 bus 無 power |
| Address | schematic、datasheet、`i2cdetect` | 7-bit / 8-bit address 混淆、strap 錯 |
| Driver binding | `dmesg`、`/sys/bus/i2c/drivers` | compatible 不符、driver 未啟用、manual bind 未做 |
| PMBus page | datasheet、vendor spec | page / phase 錯造成 label 與值對不上 |
| Fault bit | PMBus `STATUS_WORD` / vendor register | present 但 fault，或 input lost 被誤判成 absent |
| Timing | bus speed、clock stretching、timeout | 100k / 400k 不符、device stretch 過長 |

#### 29.4 systemd service

Sensor daemon 通常由 Entity Manager 或各 sensor service 依設定建立 D-Bus object。不同平台可能使用 dbus-sensors、phosphor-hwmon 或 vendor daemon，實際 service 名稱需以 image 內容為準。

```bash
# 找出 sensor 相關 service
systemctl list-units --type=service | grep -Ei 'sensor|hwmon|fan|power|psu|entity|thermal|inventory|fru'

# 常見服務狀態
systemctl status xyz.openbmc_project.EntityManager.service
systemctl status xyz.openbmc_project.ADCSensor.service
systemctl status xyz.openbmc_project.HwmonTempSensor.service
systemctl status xyz.openbmc_project.FanSensor.service
systemctl status xyz.openbmc_project.PSUSensor.service
systemctl status xyz.openbmc_project.ExternalSensor.service
systemctl status xyz.openbmc_project.IntelCPUSensor.service
systemctl status xyz.openbmc_project.NVMeSensor.service
systemctl status bmcweb.service
```

常見檢查方向：

- service `inactive`：可能套件未進 image、feature 未啟用、被 condition / power state 限制。
- service `failed`：先看 `journalctl -u`，再確認 JSON schema、bus / address、權限、D-Bus name 衝突。
- service 正常但沒有 object：確認 Entity Manager 的 `Exposes` 是否有匹配該 sensor type，以及 daemon 是否支援該 type。
- service restart 後短暫有值再消失：可能是 device absent、read timeout、threshold parse fail、association 或 availability policy。

#### 29.5 journal

journal 的目標是比對 service 啟動流程、config reload、device matching、讀值失敗、threshold alarm 與 bmcweb 查詢行為。

```bash
# 本次開機 sensor 相關 log
journalctl -b | grep -Ei 'sensor|hwmon|entity|threshold|fan|pwm|psu|pmbus|peci|nvme|gpu|redfish'

# 常見 service log
journalctl -u xyz.openbmc_project.EntityManager.service -b --no-pager
journalctl -u xyz.openbmc_project.ADCSensor.service -b --no-pager
journalctl -u xyz.openbmc_project.HwmonTempSensor.service -b --no-pager
journalctl -u xyz.openbmc_project.FanSensor.service -b --no-pager
journalctl -u xyz.openbmc_project.PSUSensor.service -b --no-pager
journalctl -u xyz.openbmc_project.ExternalSensor.service -b --no-pager
journalctl -u bmcweb.service -b --no-pager

# 追蹤即時變化
journalctl -f | grep -Ei 'sensor|threshold|fan|psu|redfish|bmcweb'
```

建議保存：

- service start / restart 時間點。
- 讀取失敗訊息，例如 permission denied、timeout、invalid configuration、missing item。
- threshold alarm 上升 / 解除時間點。
- sensor value 變成 NaN、Unavailable、Functional=false 的前後 log。
- Redfish request 的 HTTP status 與 bmcweb log。

#### 29.6 D-Bus / ObjectMapper

OpenBMC sensor 的核心觀念是把 sensor 映射成 D-Bus object。典型 path 為 `/xyz/openbmc_project/sensors/<type>/<sensor_name>`，常見 interface 包含 `xyz.openbmc_project.Sensor.Value`、`xyz.openbmc_project.Sensor.Threshold.Warning`、`xyz.openbmc_project.Sensor.Threshold.Critical`、`xyz.openbmc_project.State.Decorator.Availability`、`xyz.openbmc_project.State.Decorator.OperationalStatus` 與 `xyz.openbmc_project.Association.Definitions`。

```bash
# 快速列出 sensors D-Bus tree
busctl tree | grep /xyz/openbmc_project/sensors
busctl tree xyz.openbmc_project.ObjectMapper | grep sensors

# 由 ObjectMapper 查出所有 sensor objects 與 service
busctl call xyz.openbmc_project.ObjectMapper \
  /xyz/openbmc_project/object_mapper \
  xyz.openbmc_project.ObjectMapper GetSubTree \
  sias /xyz/openbmc_project/sensors 0 0

# 只查有 Sensor.Value interface 的 objects
busctl call xyz.openbmc_project.ObjectMapper \
  /xyz/openbmc_project/object_mapper \
  xyz.openbmc_project.ObjectMapper GetSubTree \
  sias /xyz/openbmc_project/sensors 0 1 \
  xyz.openbmc_project.Sensor.Value

# 已知 sensor path 時，先查 service name
busctl call xyz.openbmc_project.ObjectMapper \
  /xyz/openbmc_project/object_mapper \
  xyz.openbmc_project.ObjectMapper GetObject \
  sas <sensor_path> 0

# 讀取 Value / Unit / Availability / Functional
busctl get-property \
  <service_name> \
  <sensor_path> \
  xyz.openbmc_project.Sensor.Value \
  Value

busctl get-property \
  <service_name> \
  <sensor_path> \
  xyz.openbmc_project.Sensor.Value \
  Unit

busctl get-property \
  <service_name> \
  <sensor_path> \
  xyz.openbmc_project.State.Decorator.Availability \
  Available

busctl get-property \
  <service_name> \
  <sensor_path> \
  xyz.openbmc_project.State.Decorator.OperationalStatus \
  Functional

# 查看完整 interface / property
busctl introspect <service_name> <sensor_path>
```

D-Bus 判讀重點：

| 現象 | 可能方向 | 建議確認 |
| ---- | -------- | -------- |
| 找不到 sensor path | daemon 未建立 object、config type / index 不符、power state 不符 | service log、Entity Manager exposed config、sysfs |
| path 存在但 `Value` 讀不到 | interface 未掛上、daemon 初始化部分失敗 | `busctl introspect`、journal |
| `Available=false` | device absent、host off、timeout、policy gating | presence、host state、daemon log |
| `Functional=false` | sensor fault、讀值不可信、threshold / monitor 判定異常 | fault register、journal、threshold status |
| Threshold property 不存在 | JSON 未設定、daemon 不支援、sensor type 不使用 threshold | config、phosphor-dbus-interfaces |
| `Unit` 與預期不一致 | sensor type 錯、daemon mapping 錯 | D-Bus path type、JSON Type、bmcweb mapping |

#### 29.7 Redfish

Redfish 層主要確認三件事：chassis 是否存在、sensor 是否掛到正確 chassis / inventory association、bmcweb 是否把 D-Bus sensor type 映射到對應 Redfish resource。

```bash
# Chassis collection
curl -k -u root:<password> \
  https://<bmc_ip>/redfish/v1/Chassis/

# 指定 chassis
curl -k -u root:<password> \
  https://<bmc_ip>/redfish/v1/Chassis/<chassis_id>

# 新式 Sensors collection；是否可用取決於 bmcweb build / platform policy
curl -k -u root:<password> \
  https://<bmc_ip>/redfish/v1/Chassis/<chassis_id>/Sensors

# Legacy / 相容路徑；不少平台仍需要同時驗證
curl -k -u root:<password> \
  https://<bmc_ip>/redfish/v1/Chassis/<chassis_id>/Thermal

curl -k -u root:<password> \
  https://<bmc_ip>/redfish/v1/Chassis/<chassis_id>/Power

# 若有 jq，可快速查看 sensor members
curl -k -u root:<password> \
  https://<bmc_ip>/redfish/v1/Chassis/<chassis_id>/Sensors | jq '.Members'
```

Redfish 與 D-Bus 常見映射：

| Redfish resource | 常見 D-Bus sensor type | 說明 |
| ---------------- | ---------------------- | ---- |
| `/Chassis/<id>/Sensors` | 多數 sensor type | 新式 unified sensor collection，依 bmcweb feature / schema 支援度而定 |
| `/Chassis/<id>/Thermal` | `temperature`、`fan_tach`、`fan_pwm` | legacy thermal view，仍常用於相容性驗證 |
| `/Chassis/<id>/Power` | `voltage`、`power` | legacy power view，部分 current / PSU 資訊可能走其他 resource 或 OEM 欄位 |
| `/Chassis/<id>/PowerSubsystem` | power supply / power control 資訊 | 依平台與 bmcweb 支援度而定 |
| `/Chassis/<id>/ThermalSubsystem` | fan / thermal control 資訊 | 依平台與 bmcweb 支援度而定 |

Redfish 若沒有 sensor，但 D-Bus 有值，優先確認：

- sensor path 是否在 `/xyz/openbmc_project/sensors/<type>/...`。
- sensor 是否有 chassis `all_sensors` association。
- sensor 是否有 inventory association，尤其 fan、PSU、VR、CPU、drive 類 sensor。
- bmcweb 是否支援該 sensor type 與目標 resource。
- chassis id 是否正確，不同平台可能是 `chassis`、`system`、`baseboard` 或專案自訂名稱。
- `bmcweb` 是否需要 restart 或等待 ObjectMapper 更新。

#### 29.8 IPMI / SDR / SEL

若平台仍提供 IPMI，需確認 D-Bus sensor 是否被 IPMI SDR policy 收錄，單位、線性化、threshold、event type 是否與需求一致。

```bash
# Sensor 清單與讀值
ipmitool -I lanplus -H <bmc_ip> -U root -P <password> sensor list
ipmitool -I lanplus -H <bmc_ip> -U root -P <password> sdr elist

# SEL / event
ipmitool -I lanplus -H <bmc_ip> -U root -P <password> sel list
ipmitool -I lanplus -H <bmc_ip> -U root -P <password> sel elist

# 本機 BMC 端若有 ipmitool
ipmitool sensor list
ipmitool sdr elist
ipmitool sel elist
```

IPMI 排查方向：

| 現象 | 可能方向 | 建議確認 |
| ---- | -------- | -------- |
| D-Bus 有 sensor，但 IPMI 無 | SDR config / allowlist / entity mapping 未收錄 | `phosphor-host-ipmid` log、SDR policy |
| IPMI 名稱截斷 | SDR name 長度限制 | 命名規則、縮寫表 |
| IPMI 值 scale 錯 | linearization / M-B-R / unit 設定 | SDR dump、D-Bus raw value |
| threshold 事件沒進 SEL | event policy、threshold alarm、SEL service | `busctl introspect` threshold、SEL log |
| Sensor 顯示 `na` | unavailable / host state gating / reading failed | D-Bus `Available`、`Functional`、service log |

#### 29.9 Entity Manager / configuration

Entity Manager 或平台 sensor config 是 sysfs / hardware 與 D-Bus object 的橋接。不同 sensor type 的欄位不同，但共通檢查方向一致。

```bash
# 找平台 sensor / entity config；實際路徑依 image 而定
find /usr/share -iname '*.json' | grep -Ei 'entity|sensor|config|platform'
find /etc -iname '*.json' | grep -Ei 'entity|sensor|config|platform'

# Entity Manager exposed objects
busctl tree xyz.openbmc_project.EntityManager
busctl introspect xyz.openbmc_project.EntityManager /xyz/openbmc_project/inventory

# 查 config 中特定 sensor name
grep -R "<sensor_name>" /usr/share /etc 2>/dev/null
```

共通欄位檢查：

| 欄位 | 檢查重點 |
| ---- | -------- |
| `Name` | 需符合 D-Bus object path 字元限制，避免空白、斜線、特殊字元 |
| `Type` | 需與 sensor daemon 支援的 type 完全一致 |
| `Bus` / `Address` | I2C / PMBus 類 sensor 必填；需對齊 mux 後的 runtime bus number |
| `Index` | ADC / hwmon input 類常用；需對齊 `inX_input`、`tempX_input`、`fanX_input` |
| `ScaleFactor` / `Offset` | 需記錄硬體換算依據與量測比對結果 |
| `PowerState` | `Always`、`On`、`BiosPost` 等需對齊 sensor 實際可讀時機 |
| `Thresholds` | warning / critical / direction / hysteresis 需對齊規格 |
| `PollRate` / `PollInterval` | 過短可能造成 bus loading，過長可能影響 event 反應 |
| Association / Inventory | Redfish / IPMI 可見性常受此影響 |

#### 29.10 常見一次性收集腳本

以下腳本適合在問題單初期收集 baseline。正式使用前可依平台裁切，避免包含敏感資訊。

```bash
#!/bin/sh
OUT=/tmp/sensor_debug_$(date +%Y%m%d_%H%M%S)
mkdir -p "$OUT"

uname -a > "$OUT/uname.txt"
cat /etc/os-release > "$OUT/os-release.txt" 2>/dev/null

# Kernel / sysfs
dmesg > "$OUT/dmesg.txt"
ls -l /sys/class/hwmon > "$OUT/hwmon-list.txt" 2>&1
for h in /sys/class/hwmon/hwmon*; do
    [ -d "$h" ] || continue
    name=$(cat "$h/name" 2>/dev/null)
    safe=$(echo "$name" | tr '/ ' '__')
    dir="$OUT/hwmon_${safe}_$(basename "$h")"
    mkdir -p "$dir"
    cp "$h/name" "$dir/name" 2>/dev/null
    for f in "$h"/*_input "$h"/*_label "$h"/*_min "$h"/*_max "$h"/*_crit "$h"/*_lcrit "$h"/pwm* "$h"/fan*_pulses; do
        [ -e "$f" ] && cat "$f" > "$dir/$(basename "$f")" 2>/dev/null
    done
done

# systemd / journal
systemctl --failed > "$OUT/systemctl-failed.txt" 2>&1
systemctl list-units --type=service | grep -Ei 'sensor|hwmon|fan|power|psu|entity|thermal|inventory|fru|bmcweb' > "$OUT/sensor-services.txt" 2>&1
journalctl -b > "$OUT/journal-b.txt" 2>&1

# D-Bus
busctl tree > "$OUT/busctl-tree.txt" 2>&1
busctl call xyz.openbmc_project.ObjectMapper /xyz/openbmc_project/object_mapper xyz.openbmc_project.ObjectMapper GetSubTree sias /xyz/openbmc_project/sensors 0 1 xyz.openbmc_project.Sensor.Value > "$OUT/dbus-sensors.txt" 2>&1

# config
find /usr/share /etc -iname '*.json' 2>/dev/null | grep -Ei 'entity|sensor|platform|config' > "$OUT/json-list.txt"

tar czf "$OUT.tar.gz" -C /tmp "$(basename "$OUT")"
echo "$OUT.tar.gz"
```

#### 29.11 Sensor Type 快速對照

| Sensor 種類 | 常見 D-Bus type | 常見來源 | 主要確認項目 | 常見 sysfs / 介面 |
| ----------- | --------------- | -------- | ------------ | ----------------- |
| ADC | `voltage` | IIO / `iio-hwmon` | ADC channel、Vref、scale、分壓比例 | `in*_input` |
| Temperature | `temperature` | hwmon / PECI / PMBus / NVMe-MI | `temp*_input`、單位、offset、threshold | `temp*_input` |
| Voltage | `voltage` | ADC / PMBus / hwmon | rail tolerance、scale、page / label | `in*_input` |
| Current | `current` | PMBus / hwmon / shunt monitor | shunt、scale、單位、page / phase | `curr*_input` |
| Power | `power` | PMBus / PECI / GPU / V×I | µW → W、power meter 比對、是否 double count | `power*_input` |
| Energy | `energy` | PMBus / telemetry / accumulator | 累積單位、rollover、reset 行為 | `energy*_input` |
| Fan Tach | `fan_tach` | hwmon fan input / fan controller | RPM、PPR、rotor、lower threshold | `fan*_input` |
| Fan PWM | `fan_pwm` 或 control interface | `pwm` sysfs / fan controller | duty range、polarity、thermal policy | `pwm*` |
| PSU | 多種類型 | PMBus / hwmon / FRU / GPIO | presence、fault、redundancy、FRU | PMBus / `hwmon` / inventory |
| CPU | `temperature` / `power` | PECI / APML / hwmon | host power state、CPU presence、readiness | `peci-*`、`temp*_input` |
| NVMe | `temperature` / health | NVMe-MI / MCTP / PCIe | slot mapping、drive presence、endpoint | MCTP / daemon D-Bus |
| GPU | `temperature` / `power` / utilization | MCTP / telemetry / vendor daemon | endpoint、presence、fault、inventory | daemon D-Bus / telemetry |
| External | 依設定 | D-Bus / external daemon | timeout、unavailable policy、更新頻率 | D-Bus property |
| Presence | state / inventory | GPIO / CPLD / PMBus ACK / FRU | active level、debounce、present vs functional | libgpiod / inventory |

#### 29.12 常見問題索引

| 問題 | 第一輪判斷 | 建議入口 |
| ---- | ---------- | -------- |
| `hwmon` 不見 | driver 未 probe、DT / kernel config / I2C 問題 | `dmesg`、`i2cdetect`、`/sys/bus/i2c/devices` |
| sysfs 有值但 D-Bus 沒值 | config / daemon matching 問題 | Entity Manager JSON、`journalctl -u <sensor service>` |
| D-Bus 有值但 Redfish 無值 | association / bmcweb mapping 問題 | ObjectMapper association、`journalctl -u bmcweb` |
| Redfish 有 sensor 但 `Reading` 為 null | D-Bus unavailable / functional false | `Available`、`Functional`、power state |
| IPMI 無 sensor | SDR policy / naming / entity mapping | `phosphor-host-ipmid` log、`ipmitool sdr elist` |
| 數值倍率錯 | sysfs 單位、ScaleFactor、Redfish/IPMI scale | sysfs ↔ D-Bus ↔ Redfish ↔ 量測值比對 |
| threshold 不觸發 | threshold 未掛 interface、direction / hysteresis / event policy | `busctl introspect`、journal、SEL |
| fan RPM 不合理 | PPR、tach channel、PWM mapping、波形問題 | `fan*_input`、示波器、PWM manual test |
| PSU present 但無讀值 | input power lost、PMBus fault、page wrong | PMBus status、FRU、presence GPIO |
| host off 時 sensor 消失 | `PowerState` / host gating 符合設定或設定過嚴 | Entity Manager config、host state |

#### 29.13 Porting / Debug Checklist

- [ ] 硬體：sensor 型號、bus / address / channel / page、供電、reset、presence、fault、量測點已確認。
- [ ] Device Tree：compatible、reg、pinctrl、io-channels、pulses-per-revolution、mux、status 已確認。
- [ ] Kernel config：hwmon / iio / pmbus / peci / gpio / pwm / mctp 相關選項已進 image。
- [ ] sysfs：`hwmon*/name`、`*_input`、`*_label`、`pwm*` 存在且單位正確。
- [ ] config：Entity Manager JSON 的 `Name`、`Type`、`Bus`、`Address`、`Index`、`ScaleFactor`、`PowerState`、`Thresholds` 已對齊實機。
- [ ] service：sensor daemon 啟動正常，journal 無持續 timeout / parse error / unavailable loop。
- [ ] D-Bus：ObjectMapper 查得到 sensor，`Value`、`Unit`、`Available`、`Functional`、threshold interface 符合預期。
- [ ] association：chassis `all_sensors` 與 inventory `sensors` association 已建立。
- [ ] Redfish：`/Chassis/<id>/Sensors`、`Thermal`、`Power` 依平台 policy 可回應。
- [ ] IPMI：若平台支援 IPMI，`sensor list`、`sdr elist`、SEL threshold event 已驗證。
- [ ] 量測比對：DMM / power meter / thermal chamber / tach meter 與 sysfs / D-Bus / Redfish 數值已建立誤差 baseline。
- [ ] 異常測試：device absent、bus timeout、host off、PSU unplug、fan stall、threshold crossing、service restart 已驗證。

#### 29.14 參考資料

- OpenBMC Sensor Architecture  
  <https://github.com/openbmc/docs/blob/master/architecture/sensor-architecture.md>

- OpenBMC dbus-sensors  
  <https://github.com/openbmc/dbus-sensors>

- OpenBMC ObjectMapper Architecture  
  <https://github.com/openbmc/docs/blob/master/architecture/object-mapper.md>

- Linux hwmon sysfs interface  
  <https://docs.kernel.org/hwmon/sysfs-interface.html>

- OpenBMC bmcweb Redfish sensor / power / thermal implementation  
  <https://github.com/openbmc/bmcweb>

### 30. Performance / Resource / Boot Time
Boot time 拆解：BootROM、U-Boot、kernel、userspace、network ready、API ready。systemd 可用 `systemd-analyze`、`blame`、`critical-chain` 與 `plot` 檢查。

資源監控：CPU、memory、D-Bus call rate、sensor polling interval、journal size、flash write rate、network connection count。

### 31. 通用測試矩陣

| 測項                     | 目的             | Pass criteria                   | Log           |
| ------------------------ | ---------------- | ------------------------------- | ------------- |
| Boot Test                | BMC 可正常開機   | Redfish/IPMI/SSH ready          | dmesg/journal |
| AC Cycle                 | 外部斷電恢復     | 狀態符合 AC policy              | power log     |
| DC Cycle                 | host power cycle | host 狀態正確                   | SEL/journal   |
| BMC Reset                | BMC reset        | host 影響符合設計               | reset reason  |
| Update                   | 韌體更新         | version changed, service normal | update log    |
| Power Loss During Update | 復原能力         | 可回復或 rollback               | serial log    |
| Sensor Threshold         | event 正確       | assert/deassert 正確            | SEL/EventLog  |
| Fan Fail                 | failsafe         | PWM 拉高 / event                | tach log      |
| Network VLAN             | 網路設定         | ping/API success                | tcpdump       |
| Secure Boot              | 開機保護         | 非授權 image 被拒絕             | boot log      |
| Factory Reset            | 回復預設         | 指定資料清除                    | audit log     |

---

## 第八部分：工廠與生產

### 32. Manufacturing / Factory

產線流程：進入生產模式 → 燒錄 MAC/Serial/UUID/FRU → 寫入 key/cert（如適用）→ board/SKU ID 檢查 → sensor quick test → fan test → network test → Redfish/IPMI smoke test → 出廠重置 → 關閉 debug / manufacturing mode。

### 33. Calibration / Board Data / Provisioning

校正資料需定義：來源、公式、儲存位置、備份、版本、checksum、更新權限。Provisioning 失敗需可重試且不得留下半寫入資料。

---

## 第九部分：平台差異筆記本

### 34. SoC 筆記標準填寫模板

| 項目           | AST2600                           | NPCM7xx | 其他   |
| -------------- | --------------------------------- | ------- | ------ |
| CPU core       | Dual Cortex-A7 [待確認頻率]       | [待填]  | [待填] |
| Boot source    | SPI/eMMC [依平台]                 | [待填]  | [待填] |
| DDR            | DDR4 on AST2600                   | [待填]  | [待填] |
| Host interface | LPC/eSPI                          | [待填]  | [待填] |
| Network        | MAC + PHY / NC-SI                 | [待填]  | [待填] |
| Secure boot    | 支援，依 OTP/key 設定             | [待填]  | [待填] |
| 常見風險       | strap、pinmux、eSPI、flash layout | [待填]  | [待填] |

### 當前專案例外清單

| Issue  | Description | Risk   | Workaround | Owner  | Status |
| ------ | ----------- | ------ | ---------- | ------ | ------ |
| [待填] | [待填]      | [待填] | [待填]     | [待填] | [待填] |

---

## 第十部分：附錄

### A1. 常見 I2C Device Address 速查表

| 類型         | 常見 address | 備註               |
| ------------ | ------------ | ------------------ |
| EEPROM       | 0x50-0x57    | FRU / SPD 常見範圍 |
| PMBus PSU/VR | 0x40-0x7f    | 依料號而定         |
| I2C mux      | 0x70-0x77    | PCA954x 常見       |
| RTC          | 0x68         | 常見但需看料號     |

### A4. Redfish 常用路徑速查表

| 功能         | 路徑                           |
| ------------ | ------------------------------ |
| Service root | `/redfish/v1/`               |
| Managers     | `/redfish/v1/Managers`       |
| Systems      | `/redfish/v1/Systems`        |
| Chassis      | `/redfish/v1/Chassis`        |
| Update       | `/redfish/v1/UpdateService`  |
| Event        | `/redfish/v1/EventService`   |
| Account      | `/redfish/v1/AccountService` |
| Session      | `/redfish/v1/SessionService` |

### A8. 新平台移植速查表

1. 取得 schematic、BOM、power sequence、CPLD map、SoC datasheet、BIOS-BMC interface。
2. 確認 boot strap、UART、flash、DDR、reset、clock。
3. 建立 Yocto machine、U-Boot、kernel config、DTS include tree。
4. Bring-up console、flash boot、DDR、kernel、rootfs。
5. 補 I2C bus map、GPIO table、sensor config、fan config、power control。
6. 驗證 Redfish/IPMI、host interface、network、update、recovery。
7. 跑通 AC/DC/BMC reset/update/power loss/security/factory tests。
8. 固化差異筆記與量產 SOP。

### A9. Bring-up 最小檢查清單

- [ ] Power rail 正常
- [ ] Reset deassert 正常
- [ ] Clock 正常
- [ ] Strap 量測與設計一致
- [ ] UART 有 log
- [ ] Bootloader 可讀 flash
- [ ] DDR init pass
- [ ] Kernel boot pass
- [ ] rootfs mount pass
- [ ] network ready
- [ ] Redfish/IPMI basic pass
- [ ] Sensor/Fan/Power basic pass
- [ ] update/recovery basic pass

### A10. 常用指令索引

參見第 26 章 Debug Toolkit。

### A11. 故障現象索引

| 現象           | 優先檢查                               |
| -------------- | -------------------------------------- |
| 無 UART        | power/reset/clock/strap/UART pinmux    |
| U-Boot 卡住    | flash/DDR/env/bootcmd                  |
| Kernel panic   | bootargs/rootfs/DT memory/driver       |
| Sensor missing | I2C bus/mux/address/driver/DT/config   |
| Fan full speed | sensor unavailable/fan daemon/failsafe |
| Redfish 失敗   | bmcweb/session/cert/D-Bus backend      |
| IPMI timeout   | host interface/ipmid/KCS/eSPI/LPC      |
| 更新後無法開機 | slot/env/manifest/signature/rootfs     |

## 參考來源 URL

- Linux Device Tree documentation: https://www.kernel.org/doc/html/latest/devicetree/usage-model.html
- Linux GPIO DT binding: https://mjmwired.net/kernel/Documentation/devicetree/bindings/gpio/
- Linux UBIFS documentation: https://www.kernel.org/doc/html/v5.8/filesystems/ubifs.html
- Linux MTD/UBI FAQ: http://linux-mtd.infradead.org/faq/ubi.html
- Yocto layers documentation: https://docs.yoctoproject.org/dev/dev-manual/layers.html
- OpenBMC sensor architecture: https://github.com/openbmc/docs/blob/master/architecture/sensor-architecture.md
- OpenBMC code update: https://github.com/openbmc/docs/blob/master/architecture/code-update/code-update.md
- DMTF Redfish DSP0266 versions: https://www.dmtf.org/dsp/DSP0266
- IPMI v2.0 specification: https://www.intel.com/content/dam/www/public/us/en/documents/product-briefs/ipmi-second-gen-interface-spec-v2-rev1-1.pdf
- ASPEED AST2600 product page: https://www.aspeedtech.com/server_ast2600/


- Yocto Project Technical Overview: [https://www.yoctoproject.org/development/technical-overview/](https://www.yoctoproject.org/development/technical-overview/)
- Yocto Project Understanding and Creating Layers: [https://docs.yoctoproject.org/dev/dev-manual/layers.html](https://docs.yoctoproject.org/dev/dev-manual/layers.html)
- Yocto Project Building Guide: [https://docs.yoctoproject.org/dev-manual/building.html](https://docs.yoctoproject.org/dev-manual/building.html)
- Poky repository note: [https://git.yoctoproject.org/poky/about/](https://git.yoctoproject.org/poky/about/)
- OpenEmbedded and The Yocto Project: [https://www.openembedded.org/wiki/OpenEmbedded_and_The_Yocto_Project](https://www.openembedded.org/wiki/OpenEmbedded_and_The_Yocto_Project)
- OpenBMC Yocto development: [https://github.com/openbmc/docs/blob/master/yocto-development.md](https://github.com/openbmc/docs/blob/master/yocto-development.md)

- Yocto Project Reference Manual - externalsrc class: [https://docs.yoctoproject.org/ref-manual/classes.html](https://docs.yoctoproject.org/ref-manual/classes.html)
