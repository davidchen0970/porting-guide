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
