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

設計原則：

- bootloader、kernel、readonly rootfs、rw data、persistent config、log、recovery image 分區需分開評估。
- A/B slot 適合需要不中斷更新與 rollback 的平台。
- Golden image 應保持唯讀，更新流程不得覆寫，除非有明確安全流程。
- read-only SquashFS + writable overlay 可降低 rootfs 被意外修改的風險；UBIFS 適合 raw NAND 上的可寫資料。
- 分區需依 erase block / page size 對齊，避免寫入放大與邊界錯誤。

常見配置：

| 類型                 | 適用場景               | 注意事項                              |
| -------------------- | ---------------------- | ------------------------------------- |
| SPI-NOR + static MTD | 小容量、簡單更新       | 容量有限，log 應節制                  |
| SPI-NAND + UBI/UBIFS | raw NAND、大容量       | 需處理 bad block、VID header、LEB/PEB |
| eMMC + ext4          | 大容量、block device   | 需規劃 wear、fsck、power loss         |
| SquashFS + OverlayFS | 穩定 rootfs + 可寫設定 | overlay 空間需監控                    |

平台必填：`/proc/mtd`、`fw_printenv`、`mtdparts`、U-Boot bootargs、image manifest、rollback policy。

### 3. Pinmux / GPIO 通用設計模式

GPIO 欄位建議：

| Signal | SoC Pin | GPIO line | Active | Default      | Owner         | Purpose | Boot risk |
| ------ | ------- | --------: | ------ | ------------ | ------------- | ------- | --------- |
| [待填] | [待填]  |    [待填] | H/L    | input/output | BMC/CPLD/BIOS | [待填]  | [待填]    |

設計原則：

- reset、power enable、write protect、presence、interrupt 類 GPIO 必須標示 active high/low。
- 會影響 host power 的 GPIO，開機預設值需與 HW pull resistor 一致。
- GPIO hog 適合固定狀態且早期就要建立的訊號。
- Device Tree 中每個 GPIO consumer 應使用具意義的名稱，例如 `reset-gpios`、`enable-gpios`、`presence-gpios`。

### 4. Reset / Clock / Power Domain

Reset 類型：POR、cold reset、warm reset、BMC-only reset、host reset、SoC peripheral reset、watchdog reset。排查時需同時保存 reset reason register 與外部 reset signal 量測。

Clock / power 檢查表：

| Domain    | Rail   | Clock            | Reset      | Dependency | Ready 條件    |
| --------- | ------ | ---------------- | ---------- | ---------- | ------------- |
| BMC core  | [待填] | [待填]           | [待填]     | [待填]     | [待填]        |
| MAC/RGMII | [待填] | 25/125MHz [待填] | [待填]     | PHY power  | link up       |
| eSPI/LPC  | [待填] | [待填]           | host reset | host PCH   | channel ready |

### 5. 周邊匯流排通用知識

I2C / SMBus：需整理 bus number、mux channel、device address、driver、timeout、clock frequency、pull-up、loading。`i2cdetect` 僅作為輔助，對部分 device 可能產生副作用，執行前需知道該 device 行為。

SPI：需確認 mode、clock、CS polarity、flash opcode、dual/quad enable、WP/HOLD pin 狀態。

UART：bring-up 初期至少保留一組 console，紀錄 baud rate 與 pin header。

ADC / PWM / Tach：sensor scaling、fan pulse per revolution、PWM polarity 必須與硬體一致。

PECI / eSPI / LPC / NC-SI / RGMII / RMII / PCIe / USB gadget：需建立 bus map 與 DT node 對照表。

### 6. CPLD / FPGA / Board Glue Logic

CPLD 常見職責：power sequence、reset mux、LED、board ID、SKU ID、fault latch、presence detect、write protect、BMC-host sideband。

CPLD register map 筆記範本：

| Offset | Name   |    Bit | R/W | Default | Meaning | Clear rule | Owner    |
| -----: | ------ | -----: | --- | ------- | ------- | ---------- | -------- |
| [待填] | [待填] | [待填] | R/W | [待填]  | [待填]  | W1C/RO/RW  | BMC/CPLD |

---

## 第二部分：BSP、Kernel 與 Device Tree

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

DT 是描述硬體拓樸的資料結構，讓 kernel 不需把板級資訊硬寫在 driver 中。建議所有裝置先查 binding，再寫 DTS。

基本規則：

- `compatible` 必須與 driver match table 對上。
- `reg` 描述位址或 bus address。
- `interrupts` / `interrupt-parent` 需符合 interrupt controller binding。
- `clocks` / `resets` 需確認 provider node 存在。
- GPIO 需寫清楚 active high/low。
- I2C 裝置位址必須是 7-bit address，避免把 8-bit address 填入 DT。
- mux 後 bus 需建立 channel 子節點，並確認 alias 與 runtime bus number 對得上。

排查入口：

```bash
# 反編譯 DTB
dtc -I dtb -O dts -o running.dts /sys/firmware/fdt

# 找 kernel probe / deferred probe
dmesg | grep -i -E "probe|defer|i2c|gpio|spi|watchdog"
cat /sys/kernel/debug/devices_deferred 2>/dev/null
```

### 9. Kernel Driver 與核心服務

Driver probe 典型流程：driver 註冊 → bus match → 讀 DT / ACPI / platform data → 取得 regulator/clock/reset/gpio/irq → 初始化硬體 → 建立 sysfs/debugfs/hwmon/input/net 等 interface。

Probe deferred 常見原因：clock provider 尚未 ready、regulator 未註冊、GPIO controller 未 ready、I2C mux 未 ready、interrupt controller 設定缺漏。

---

## 第三部分：平台監控與控制

### 10. I2C / PMBus 裝置驅動架構

每個 I2C device 需有：bus/channel/address、part number、driver、DT node、sysfs path、Redfish/IPMI 對映、失效策略。

PMBus：需確認 page、phase、linear format、direct format、voltage/current/power scaling、fault bit 與 clear fault 流程。

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
#### 12.7 Power Sensor
#### 12.8 Fan Tach Sensor
#### 12.9 PSU Sensor
#### 12.10 CPU / PECI Sensor
#### 12.11 NVMe Sensor
#### 12.12 GPU Sensor
#### 12.13 External / Virtual Sensor
#### 12.14 Presence / Intrusion / GPIO State Sensor
#### 12.15 Redfish Association
#### 12.16 Sensor 共用除錯指令與附錄

### 13. Fan Control

風控策略需定義四種狀態：Host Off、Host On、Boot、Failsafe。Failsafe 應在 sensor unavailable、fan tach lost、控制程式異常、unknown thermal state 時生效。

PID 調整保留資料：Kp/Ki/Kd、sample time、target sensor、min/max PWM、slew rate、anti-windup、zone mapping。

### 14. Power Control

x86 平台常見 BMC/CPLD/BIOS 權責：

- BMC：接收遠端 power command、控制 PWRBTN、讀取 power state、記錄事件。
- CPLD：硬體時序、fault latch、critical reset gating。
- BIOS/UEFI：POST、boot progress、host inventory、setup attribute。

Power sequence 必填：每條 rail enable / power good / reset / PWRBTN / SLP_Sx / PLTRST / RSMRST 的時間戳。

### 15. Inventory / FRU / Asset 資料模型

資料來源需定義權威端：EEPROM、CPLD register、BIOS table、Entity Manager JSON、manufacturing provisioning。FRU 與 Redfish Inventory 欄位需一致。

### 16. Logging / Event / Telemetry

Log 分類：BMC system log、kernel log、journal、SEL、Redfish EventLog、sensor event、firmware update log、安全 log、crash dump。Log 滿時策略需明確：循環覆寫、停止新增、遠端轉存、壓縮保存。

---

## 第四部分：Host Communication

### 17. KCS / BT / SSIF / eSPI

KCS/IPMI 適合 host OS 與 BMC 的 legacy 管理通道；eSPI 是新平台常見 host-BMC sideband，包含 peripheral channel、OOB、virtual wire、flash channel。驗證時需確認 host reset、PLTRST、virtual wire、POST code、boot progress、watchdog。

### 18. BIOS / UEFI 與 BMC 互動

需建立 BIOS-BMC interface contract：

| Feature        | Transport     | Owner    | Timing   | Data format     | Error handling |
| -------------- | ------------- | -------- | -------- | --------------- | -------------- |
| POST code      | LPC/eSPI      | BIOS/BMC | POST     | byte/code table | timeout        |
| Boot progress  | IPMI/PLDM/OEM | BIOS/BMC | POST     | enum            | last state     |
| Boot order     | Redfish/IPMI  | BMC/BIOS | pre-boot | attribute       | reject/retry   |
| Host inventory | PLDM/IPMI/OEM | BIOS/BMC | POST/OS  | FRU format      | stale mark     |

### 19. MCTP / PLDM / SPDM

MCTP 是平台內部管理傳輸層，可跑在 SMBus/I2C、PCIe VDM 等介面，使用 EID 描述 endpoint。PLDM 提供 monitoring/control、FRU、firmware update 等管理資料模型。SPDM 用於裝置認證、憑證、量測與安全通道。

---

## 第五部分：管理介面與網路

### 20. IPMI 通用知識

IPMI 提供 sensor、SEL、FRU、power control、SOL、LAN 管理等能力。新設計應限制不安全 cipher suite，並避免新增不必要 OEM command。

OEM command 範本：NetFn、Cmd、Request、Response、Completion Code、權限、狀態依賴、錯誤處理、測試案例。

### 21. Redfish 通用知識

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

### 22. Network Services

必填：DHCP/static、VLAN、hostname、DNS、NTP/PTP、MAC 來源、bonding、NIC failover、link ready time、IPv6 policy。量測開機可連線時間時要拆分：kernel driver ready、link up、DHCP lease、service listening、API first success。

---

## 第六部分：安全與韌體維運

### 23. Security Baseline

基準項目：secure boot、韌體簽章、anti-rollback、密碼政策、預設帳號、首次登入改密碼、TLS 憑證、IPMI cipher suite、最小服務集、審計 log、debug port policy、secret storage、量產 key 與開發 key 分離。

密碼政策建議與近代 NIST 方向一致：重視長度、阻擋常見或外洩密碼、避免無意義的固定週期變更；但最終仍需依產品安全規範與客戶需求決定。

### 24. Firmware Update

更新流程：上傳 image → 驗證 manifest/signature/version/machine → 建立 software object → activation → progress → reboot 或切換 slot → health check → commit / rollback。

Power loss 測試必做：更新前、寫入 bootloader、寫入 kernel、寫入 rootfs、切 slot、首次開機、commit 前斷電。

### 25. Secure Recovery / RMA / Field Service

RMA 應先保存：BMC version、BIOS version、CPLD version、boot count、reset reason、SEL、journal、dmesg、update history、FRU、sensor snapshot、network config、crash dump。Factory reset 需明確列出會清除與不會清除的資料。

---

## 第七部分：除錯、效能與測試

### 26. Debug Methodology

問題單最小資料：現象、重現率、版本、步驟、預期、實際、log、量測點、最近變更、是否與 AC/DC cycle 有關。排查時先固定硬體、韌體、設定與測試工具版本。

### 27. Debug Toolkit

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

### 28. Performance / Resource / Boot Time

Boot time 拆解：BootROM、U-Boot、kernel、userspace、network ready、API ready。systemd 可用 `systemd-analyze`、`blame`、`critical-chain` 與 `plot` 檢查。

資源監控：CPU、memory、D-Bus call rate、sensor polling interval、journal size、flash write rate、network connection count。

### 29. 通用測試矩陣

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

### 30. Manufacturing / Factory

產線流程：進入生產模式 → 燒錄 MAC/Serial/UUID/FRU → 寫入 key/cert（如適用）→ board/SKU ID 檢查 → sensor quick test → fan test → network test → Redfish/IPMI smoke test → 出廠重置 → 關閉 debug / manufacturing mode。

### 31. Calibration / Board Data / Provisioning

校正資料需定義：來源、公式、儲存位置、備份、版本、checksum、更新權限。Provisioning 失敗需可重試且不得留下半寫入資料。

---

## 第九部分：平台差異筆記本

### 32. SoC 筆記標準填寫模板

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
