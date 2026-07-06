# BMC 通用 Porting 技術參考手冊目錄

## 第零部分：手冊使用說明

0.1 手冊目的
0.2 適用範圍
0.3 符號與標記規則
0.4 參考標準與規格書清單
0.5 名詞定義
0.6 修訂紀錄
0.7 資料來源可信度分級


## 第一部分：硬體底層抽象層

1. Boot Flow 與 SoC 初始化
   1.1 BMC SoC 典型開機流程
   1.2 Boot Strap / Reset Strap 原理
   1.3 SPI-NOR / SPI-NAND / eMMC 初始化流程差異
   1.4 DDR 初始化
   1.5 Watchdog 在開機各階段的角色
   1.6 各 SoC 開機流程差異速查
   1.7 Boot Failure 分類與排查入口
   1.8 當前平台 Boot Strap 設定與實際量測值

2. Flash Partition 與儲存架構
   2.1 通用 Flash Layout 設計原則
   2.2 A/B Slot 分割策略
   2.3 Golden Image / Recovery Partition 設計
   2.4 OverlayFS 與 Read-write RootFS 設計取捨
   2.5 Partition Size 估算方法
   2.6 Flash 寫入壽命與 Log 儲存對策
   2.7 各 SoC 支援的 Flash 類型與最大容量
   2.8 當前平台 Partition Table 與 U-Boot 環境變數
   2.9 MTD / UBI / UBIFS / SquashFS / ext4 對照
   2.10 /proc/mtd、fw_printenv、mtdparts 對照方式
   2.11 Flash Erase Block / Page Size 對 Partition 對齊的影響

3. Pinmux / GPIO 通用設計模式
   3.1 Pinmux 基本概念
   3.2 GPIO 屬性
   3.3 GPIO Hog 與 Device Tree 固定配置
   3.4 常見 GPIO 分類速查
   3.5 GPIO 開機默認狀態設計原則
   3.6 上電時序中 GPIO 的關鍵時序要求
   3.7 各 SoC GPIO Bank 架構差異
   3.8 當前平台 Pinmux Table 與關鍵 GPIO 清單

4. Reset / Clock / Power Domain
   4.1 Reset 類型
   4.2 Reset Source 判讀方式
   4.3 Reset Domain 劃分
   4.4 Clock Source 與 Clock Tree
   4.5 PLL / Clock Gate 對周邊 IP 的影響
   4.6 Power Rail Dependency
   4.7 低功耗狀態與 Wake Source
   4.8 當前平台 Reset Tree / Clock Tree / Power Rail 對照表

5. 周邊匯流排通用知識
   5.1 I2C / SMBus 匯流排原理
   5.2 I2C Mux / Switch 拓樸設計
   5.3 I2C Bus 速率選擇與負載考量
   5.4 SPI 介面
   5.5 UART 介面
   5.6 ADC 原理
   5.7 PWM / Tach 原理
   5.8 PECI 介面
   5.9 eSPI / LPC 介面
   5.10 NC-SI / RGMII / RMII 網路介面
   5.11 PCIe 基礎
   5.12 USB Gadget 模式
   5.13 各 SoC 周邊 IP 差異速查
   5.14 當前平台 Bus Map 與 Device Tree 節點對應

6. CPLD / FPGA / Board Glue Logic
   6.1 BMC 與 CPLD 的常見分工
   6.2 Power Sequence 由 BMC 控還是 CPLD 控
   6.3 Reset Tree 與 Reset Source 判讀
   6.4 CPLD Register Map 筆記方式
   6.5 I2C / LPC / GPIO 連到 CPLD 的常見模式
   6.6 CPLD Firmware Version 讀取方式
   6.7 CPLD 更新流程與風險
   6.8 Board ID / SKU ID / GPIO Strap 由 CPLD 提供的情境
   6.9 Debug 注意事項
   6.10 當前平台 CPLD Register Map 與關鍵 Bit 定義


## 第二部分：BSP、Kernel 與 Device Tree

7. Build System 與 BSP 結構
   7.1 Yocto / OpenEmbedded 基本架構
   7.2 Layer 結構與優先權
   7.3 Machine / Distro / Image 配置關係
   7.4 Kernel Defconfig / Fragment 管理方式
   7.5 Device Tree Include 階層整理方法
   7.6 U-Boot 配置檔與 Board Config 對應
   7.7 RootFS Package 增減方式
   7.8 編譯產物對照表
   7.9 OpenBMC / AMI / Yocto BSP 目錄差異
   7.10 當前平台 Source Tree 地圖與常改檔案清單

8. Device Tree 通用寫法與排查
   8.1 Device Tree 基本結構
   8.2 Compatible / Reg / Interrupts / Clocks / Resets 用法
   8.3 Pinctrl 節點設計
   8.4 GPIO Phandle 與 Active-Low / Active-High 寫法
   8.5 I2C 裝置節點寫法
   8.6 I2C Mux 節點寫法
   8.7 SPI Flash Partition 節點寫法
   8.8 Hwmon / Sensor 相關節點寫法
   8.9 Chosen / Aliases / Memory 節點
   8.10 Overlay / Include / Override 規則
   8.11 常見錯誤
   8.12 當前平台 DTS Include Tree 與重要節點索引
   8.13 Binding 文件查找方式
   8.14 dts / dtb / dtbo 轉換與反編譯
   8.15 dtc warning 常見訊息整理

9. Kernel Driver 與核心服務
   9.1 I2C 子系統架構
   9.2 GPIO 子系統架構
   9.3 SPI 子系統架構
   9.4 Watchdog 子系統架構
   9.5 網路子系統架構
   9.6 USB Gadget 架構
   9.7 各平台核心驅動差異速查
   9.8 Driver Probe 流程
   9.9 Probe Deferred 常見原因
   9.10 Module / Built-in Driver 差異
   9.11 sysfs / debugfs / procfs 查詢入口


## 第三部分：平台監控與控制

10. I2C / PMBus 裝置驅動架構
    10.1 I2C Device Address 確認方法
    10.2 常見 I2C 裝置類型與驅動
    10.3 I2C Mux 在 Device Tree 中的描述方式
    10.4 I2C Bus Recovery 實作
    10.5 I2C Clock Stretching 問題排查
    10.6 PMBus 通用命令集
    10.7 各平台 I2C 除錯工具差異
    10.8 當前平台 I2C 裝置清單與驅動載入狀態

11. Sensor 抽象層
    11.1 感測器數據流
    11.2 感測器 Scaling 公式
    11.3 感測器閾值設計原則
    11.4 Polling 間隔與系統負載最佳實務
    11.5 Sensor Fail / Unavailable 狀態傳播
    11.6 Event Assert / Deassert 與 Debounce 機制
    11.7 OpenBMC / AMI 各家 Sensor 框架差異
    11.8 當前平台 Sensor List 與 SDR 映射對照表

12. Fan Control
    12.1 PID 控制理論
    12.2 Fan Table / Fan Curve 設計
    12.3 分區控制與 Thermal 關聯
    12.4 Host On / Host Off / Boot / Failsafe 四種風扇策略
    12.5 手動模式與自動模式切換邏輯
    12.6 PWM 與 Tach 的極性與脈衝數換算
    12.7 風扇故障與缺席偵測原理
    12.8 各家風控框架差異
    12.9 當前平台 Fan Zone 劃分與 PID 參數最終數值

13. Power Control
    13.1 標準 x86 電源時序
    13.2 BMC / CPLD / BIOS 三者權責劃分設計模式
    13.3 Power Button 行為定義
    13.4 AC 恢復策略
    13.5 Graceful Shutdown 與 Force Off 實作
    13.6 Power Fault 偵測與保護
    13.7 PSU 備援與負載平衡概念
    13.8 各 SoC 電源管理 IP 差異
    13.9 當前平台完整 Power Sequence 時序量測記錄

14. Inventory / FRU / Asset 資料模型
    14.1 Inventory 資料來源
    14.2 IPMI FRU 與 Redfish Inventory 對應
    14.3 Chassis / Board / Product 欄位設計
    14.4 Serial Number / Part Number / Asset Tag 管理
    14.5 多節點 / 多主機平台 Inventory 模型
    14.6 Hot-plug 裝置 Inventory 更新
    14.7 Entity Manager / Config JSON 類型整理
    14.8 當前平台 Inventory Source Map

15. Logging / Event / Telemetry
    15.1 Log 類型分類
    15.2 Event 生命週期
    15.3 SEL 與 Redfish EventLog 對應
    15.4 Sensor Event 與 Threshold Event
    15.5 Log Persistence 策略
    15.6 Log 滿時處理策略
    15.7 遠端 Log 傳送
    15.8 當前平台 Event Mapping Table
    15.9 Log Bundle 標準內容


## 第四部分：Host Communication

16. KCS / BT / SSIF / eSPI
    16.1 KCS 協定
    16.2 BT 協定
    16.3 SSIF 協定
    16.4 eSPI Virtual Wires 定義
    16.5 eSPI Snoop
    16.6 BIOS POST Code 與 Boot Progress 映射
    16.7 Host Watchdog
    16.8 當前平台 Host Interface 驗證 Check List

17. BIOS / UEFI 與 BMC 互動
    17.1 BIOS 與 BMC 的資料交換路徑
    17.2 Boot Progress / POST Code 映射
    17.3 BIOS Setup Attribute 與 Redfish BIOS Resource
    17.4 Boot Order 控制
    17.5 Host Inventory 更新時機
    17.6 FRB / Host Watchdog 行為
    17.7 BIOS 更新由 BMC 代理的流程
    17.8 CMOS Clear / BIOS Recovery 與 BMC 的關係
    17.9 當前平台 BIOS-BMC Interface 對照表

18. MCTP / PLDM / SPDM
    18.1 MCTP 協定架構
    18.2 MCTP over PCIe VDM / I2C / SMBus 綁定
    18.3 MCTP Discovery 流程
    18.4 PLDM 基礎
    18.5 PLDM Monitoring & Control
    18.6 PLDM Firmware Update
    18.7 PLDM FRU Data
    18.8 NVMe-MI
    18.9 SPDM 認證與量測
    18.10 當前平台 MCTP 路由表與 Endpoint 清單
    18.11 Transport / Endpoint / EID 對照表
    18.12 Static EID 與 Dynamic EID 管理
    18.13 Endpoint Reset 後 Discovery 行為
    18.14 MCTP Routing Debug 筆記


## 第五部分：管理介面與網路

19. IPMI 通用知識
    19.1 IPMI 架構
    19.2 IPMI LAN
    19.3 IPMI SDR 結構
    19.4 IPMI SEL 格式
    19.5 IPMI FRU 格式
    19.6 IPMI SOL
    19.7 IPMI OEM Command 設計原則
    19.8 當前平台 IPMI 實作差異

20. Redfish 通用知識
    20.1 Redfish 架構
    20.2 核心資源路徑
    20.3 感測器 / 熱 / 電源資源映射
    20.4 UpdateService 流程
    20.5 EventService / SSE
    20.6 AccountService / SessionService
    20.7 TaskService
    20.8 Redfish Privilege Mapping
    20.9 Schema 版本向前相容策略
    20.10 當前平台 Redfish 實作覆蓋率

21. Network Services
    21.1 DHCP / Static IP / VLAN 設定
    21.2 NTP / PTP 時間同步
    21.3 DNS / Hostname 解析
    21.4 NIC Bonding 與 ARP Monitor
    21.5 DHCP Timeout 與 Retry 策略
    21.6 MAC Address 管理
    21.7 各平台網路驅動差異
    21.8 當前平台網路設定與開機連線時間量測


## 第六部分：安全與韌體維運

22. Security Baseline
    22.1 Secure Boot
    22.2 韌體簽章與 Anti-Rollback
    22.3 密碼原則
    22.4 默認帳號與首次登入強制改密碼
    22.5 TLS / HTTPS 證書管理
    22.6 IPMI Cipher Suite 安全性選擇
    22.7 服務最小化原則
    22.8 審計日誌記錄範圍
    22.9 USB Mass Storage 啟用/禁用原則
    22.10 當前平台 CVE 掃描與修補記錄
    22.11 Key / Certificate / Secret 管理
    22.12 OTP / eFuse / TPM / Secure Storage 對照
    22.13 開發版與量產版安全設定差異
    22.14 Debug Port 在 Secure Mode 下的限制

23. Firmware Update
    23.1 更新流程通用模型
    23.2 更新失敗復原機制
    23.3 更新進度回報
    23.4 Power Loss 中斷更新處理
    23.5 支援更新元件類型
    23.6 各平台更新機制差異
    23.7 當前平台更新流程步驟記錄與 Recovery 按鍵組合

24. Secure Recovery / RMA / Field Service
    24.1 RMA 情境下如何讀取故障資訊
    24.2 現場恢復出廠設定方式
    24.3 客戶端 Log Bundle 收集方式
    24.4 現場更新失敗救援
    24.5 SSH / Debug Port 開啟條件
    24.6 機台序號與 FRU 不一致時的處理流程


## 第七部分：除錯、效能與測試

25. Debug Methodology
    25.1 問題分類
    25.2 重現條件
    25.3 最小化變因
    25.4 Log 收集策略
    25.5 Reset / Power Cycle 類型確認
    25.6 版本資訊保存
    25.7 Hardware Signal 與 Software Log 對齊

26. Debug Toolkit
    26.1 dmesg
    26.2 journalctl
    26.3 busctl
    26.4 gpioget / gpioset
    26.5 i2cdetect / i2cget / i2cset / i2cdump
    26.6 tcpdump / nc / ethtool / arping
    26.7 pldmtool / mctpctl
    26.8 ipmitool
    26.9 curl Redfish
    26.10 有限儲存空間下 Packet Capture 循環儲存策略
    26.11 Core Dump 產生與 GDB 分析
    26.12 ramoops / pstore 解析流程

27. Performance / Resource / Boot Time
    27.1 開機時間拆解
    27.2 systemd critical-chain 分析
    27.3 CPU / Memory / Flash 使用量觀察
    27.4 D-Bus Service 數量與啟動成本
    27.5 Sensor Polling 對 CPU Loading 的影響
    27.6 Log 寫入對 Flash 與效能的影響
    27.7 網路 Ready Time 量測
    27.8 當前平台 Boot Time Baseline

28. 通用測試矩陣
    28.1 Boot Test
    28.2 AC Cycle
    28.3 DC Cycle
    28.4 Warm Reset
    28.5 BMC Reset
    28.6 Host Reset
    28.7 Firmware Update
    28.8 Power Loss During Update
    28.9 Sensor Threshold
    28.10 Fan Fail
    28.11 PSU Fail
    28.12 Network DHCP / Static / VLAN
    28.13 IPMI Basic Command
    28.14 Redfish Service Check
    28.15 SEL / Event Log
    28.16 Secure Boot
    28.17 Factory Reset


## 第八部分：工廠與生產

29. Manufacturing / Factory
    29.1 生產模式進入方式與安全控管
    29.2 MAC / Serial Number / UUID / FRU 燒錄標準流程
    29.3 Board ID / SKU ID 硬體分位偵測
    29.4 出廠預設值重置範圍
    29.5 產線快速測試項目
    29.6 Golden Image 救援流程
    29.7 當前平台生產 SOP 與產線檢測腳本

30. Calibration / Board Data / Provisioning
    30.1 電壓 / 電流 / 溫度校正方法
    30.2 校正資料儲存位置
    30.3 Provisioning 流程
    30.4 MAC / UUID / Serial / Asset Tag 資料權威來源
    30.5 Key / Certificate 寫入流程
    30.6 FRU / Inventory / Redfish 顯示一致性檢查
    30.7 Provisioning 失敗後的回復方式
    30.8 當前平台 Board Data Map


## 第九部分：平台差異筆記本

31. 各平台差異對照總表
    31.1 SoC 筆記標準填寫模板（強制使用）

32. ASPEED AST2600 筆記（按 31.1 模板填寫）

33. Nuvoton NPCM7xx 筆記（按 31.1 模板填寫）

34. Renesas / Microchip / 其他 SoC 筆記（按 31.1 模板填寫）

35. 當前專案例外清單


## 第十部分：附錄

A1. 常見 I2C Device Address 速查表
A2. 常見 Sensor Type Code 對照表
A3. IPMI OEM Command 設計範本
A4. Redfish 常用路徑速查表
A5. OpenBMC / AMI / Yocto 目錄結構差異速查
A6. 示波器量測 Power Sequence 標準步驟
A7. Long Run 測試腳本範例
A8. 新平台移植速查表（空白填寫版）
A9. Bring-up 最小檢查清單（兩頁內）
A10. 常用指令索引
A11. 故障現象索引