# BMC Porting Guide / Checklist 目錄 v2.0

## 0. 文件資訊

* 0.1 文件目的
* 0.2 適用平台
* 0.3 專案代號 / Board Name
* 0.4 BMC 韌體版本
* 0.5 Hardware Revision
* 0.6 BIOS / CPLD / FPGA / VR / PSU 版本
* 0.7 BMC SoC / SDK / BSP 版本
* 0.8 參考文件
* 0.9 名詞定義
* 0.10 修訂紀錄
* 0.11 Owner / Reviewer / Approver

---

## 1. Porting Scope 確認

* 1.1 來源平台與目標平台比較
* 1.2 BMC SoC / SDK / Framework 確認
* 1.3 OpenBMC / AMI / Insyde / Vendor Stack 確認
* 1.4 支援功能清單
* 1.5 不支援或延後支援項目
* 1.6 客戶需求 / 專案需求整理
* 1.7 硬體相依條件
* 1.8 BIOS / CPLD / FPGA 相依條件
* 1.9 Security Requirement
* 1.10 Manufacturing Requirement
* 1.11 Validation Requirement
* 1.12 Risk List
* 1.13 Porting 優先順序
* 1.14 Milestone / Schedule

---

## 2. Build & Development Environment Checklist

> 這章新增，讓工程師可以先建立可重現的 build flow。

* 2.1 Source Repository 位置
* 2.2 Branch / Tag / Commit ID
* 2.3 Repo Manifest / Submodule 版本
* 2.4 Yocto Layer 架構
* 2.5 SDK / Toolchain 版本
* 2.6 Build Host OS 需求
* 2.7 Build Dependency 套件清單
* 2.8 Build Command
* 2.9 Clean Build Flow
* 2.10 Incremental Build Flow
* 2.11 Kernel Config Diff
* 2.12 Device Tree Source 位置
* 2.13 Board Config 位置
* 2.14 Patch 管理規則
* 2.15 Vendor Patch / Project Patch 分層
* 2.16 Build Artifact 產出路徑
* 2.17 Image Naming Rule
* 2.18 Build Log 保存方式
* 2.19 CI Build 設定
* 2.20 Reproducible Build 確認

---

## 3. Board Bring-up Checklist

* 3.1 BMC Power Rail 確認
* 3.2 Reset Strap / Boot Strap 確認
* 3.3 BMC Boot Source 確認
* 3.4 UART Console 確認
* 3.5 DDR 初始化確認
* 3.6 Clock / Reset 初始化確認
* 3.7 Bootloader 啟動確認
* 3.8 U-Boot Environment 確認
* 3.9 Kernel Boot 確認
* 3.10 Root Filesystem 掛載確認
* 3.11 Init Service 啟動確認
* 3.12 Watchdog 設定
* 3.13 BMC Reset / Reboot 行為確認
* 3.14 BMC Ready Signal 確認
* 3.15 基本開機 Log 檢查
* 3.16 First Boot 行為確認
* 3.17 AC Power Applied 後 BMC 狀態確認

---

## 4. Boot Flow / Storage / Partition Checklist

> 這章從原本 Bring-up 中獨立出來，避免 flash layout 問題拖到後期才發現。

* 4.1 Boot Flow Review
* 4.2 Boot ROM / SPL / U-Boot 流程確認
* 4.3 SPI-NOR 初始化
* 4.4 SPI-NAND 初始化
* 4.5 eMMC 初始化
* 4.6 Dual Flash 架構確認
* 4.7 Flash Partition Table 確認
* 4.8 U-Boot Partition
* 4.9 U-Boot Environment Partition
* 4.10 Kernel Partition
* 4.11 Device Tree Partition
* 4.12 RootFS Partition
* 4.13 RWFS / Overlay Partition
* 4.14 Scratch / Log Partition
* 4.15 Recovery Partition
* 4.16 Golden Image Partition
* 4.17 Firmware Update Slot A/B
* 4.18 Partition Size Margin 確認
* 4.19 Flash Wear / Write Cycle 風險確認
* 4.20 Power Loss During Update 測試
* 4.21 Boot Failure Recovery
* 4.22 Boot Time Measurement
* 4.23 Boot Time Optimization
* 4.24 AC Applied to BMC Ready 時間
* 4.25 AC Applied to Network Ready 時間
* 4.26 AC Applied to IPMI Ready 時間
* 4.27 AC Applied to Redfish Ready 時間

---

## 5. Pinmux / GPIO Checklist

> 原 Chapter 3 / 4 重排後，先確認腳位功能，再確認周邊匯流排。

* 5.1 Pinmux Table Review
* 5.2 GPIO Table 整理
* 5.3 GPIO Direction 確認
* 5.4 GPIO Active Level 確認
* 5.5 GPIO Default State 確認
* 5.6 GPIO Pull-up / Pull-down 確認
* 5.7 GPIO Open-drain 設定
* 5.8 GPIO Hog 設定
* 5.9 Power Control GPIO
* 5.10 Reset Control GPIO
* 5.11 Power Good GPIO
* 5.12 Presence Detect GPIO
* 5.13 Fault Detect GPIO
* 5.14 LED Control GPIO
* 5.15 Button Input GPIO
* 5.16 Board ID GPIO
* 5.17 SKU ID GPIO
* 5.18 Jumper Detect GPIO
* 5.19 CMOS Clear Detect GPIO
* 5.20 Recovery Mode Detect GPIO
* 5.21 Manufacturing Mode Detect GPIO
* 5.22 Device Tree / Platform Config 更新
* 5.23 開機期間 GPIO 狀態確認
* 5.24 AC Cycle / DC Cycle 後 GPIO 狀態確認
* 5.25 GPIO Race Condition 檢查

---

## 6. Peripheral Interface Checklist

* 6.1 I2C / SMBus Bus Map 整理
* 6.2 I3C Bus Map 整理
* 6.3 I2C Mux / Switch Channel 確認
* 6.4 SPI Interface 確認
* 6.5 UART Interface 確認
* 6.6 USB Interface 確認
* 6.7 ADC Channel 確認
* 6.8 PWM Channel 確認
* 6.9 Tach Channel 確認
* 6.10 PECI Interface 確認
* 6.11 LPC Interface 確認
* 6.12 eSPI Interface 確認
* 6.13 KCS Interface 確認
* 6.14 SSIF Interface 確認
* 6.15 NC-SI Interface 確認
* 6.16 RGMII / RMII Interface 確認
* 6.17 PCIe Interface 確認
* 6.18 USB Gadget Interface 確認
* 6.19 Device Tree Node 確認
* 6.20 Driver Binding 確認

---

## 7. I2C / SMBus / PMBus Device Checklist

* 7.1 I2C Bus Number 對應
* 7.2 I2C Device Address 確認
* 7.3 I2C Mux 拓樸確認
* 7.4 I2C Bus Speed 確認
* 7.5 EEPROM / FRU Device
* 7.6 Temperature Sensor
* 7.7 Voltage / Current Monitor
* 7.8 ADC Device
* 7.9 Fan Controller
* 7.10 PSU PMBus
* 7.11 VR PMBus
* 7.12 CPLD / FPGA Register Access
* 7.13 Retimer / Clock Buffer
* 7.14 DIMM SPD
* 7.15 CPU PECI Bridge
* 7.16 I2C Address Conflict 檢查
* 7.17 I2C Stuck Bus Recovery
* 7.18 Clock Stretching 確認
* 7.19 Device Power Dependency 確認
* 7.20 I2C Error Handling
* 7.21 I2C Scan / Discovery
* 7.22 I2C Stress Test
* 7.23 High Temperature I2C Stability
* 7.24 Low Voltage I2C Stability

---

## 8. Sensor Porting Checklist

* 8.1 Sensor List 建立
* 8.2 Sensor Source 對應
* 8.3 Sensor Scan / Discovery
* 8.4 Sensor Name 定義
* 8.5 Sensor Type 定義
* 8.6 Sensor Unit 設定
* 8.7 Sensor Reading Scale 確認
* 8.8 Offset / Slope 設定
* 8.9 Signed / Unsigned 確認
* 8.10 Threshold 設定
* 8.11 Hysteresis 設定
* 8.12 Sensor Polling Interval 設定
* 8.13 Sensor Available / Unavailable 狀態
* 8.14 Sensor Fail 行為確認
* 8.15 Sensor Timeout 行為確認
* 8.16 IPMI SDR 對應
* 8.17 Redfish Sensor 對應
* 8.18 Web UI Sensor 顯示確認
* 8.19 SEL / Event 觸發確認
* 8.20 Deassert Event 確認
* 8.21 Sensor Accuracy 驗證
* 8.22 Sensor Boundary 驗證
* 8.23 Sensor Long Run 驗證
* 8.24 Sensor Polling Stress
* 8.25 IPMI / Redfish / Web UI 數值一致性

---

## 9. Fan Control Checklist

* 9.1 Fan 數量與位置確認
* 9.2 Fan Zone 定義
* 9.3 PWM Channel 對應
* 9.4 Tach Channel 對應
* 9.5 PWM Polarity 確認
* 9.6 Tach Polarity 確認
* 9.7 Tach Pulse Per Revolution 確認
* 9.8 Duplicated Tach / Half RPM 檢查
* 9.9 Fan Presence 偵測
* 9.10 Fan Fault 偵測
* 9.11 Fan Curve / Fan Table 設定
* 9.12 Thermal Sensor 關聯
* 9.13 PID / Control Policy 設定
* 9.14 Host On Fan Policy
* 9.15 Host Off Fan Policy
* 9.16 BMC Boot Fan Policy
* 9.17 BMC Not Ready Fan Policy
* 9.18 Sensor Fail Failsafe Policy
* 9.19 Fan Fail Failsafe Policy
* 9.20 PSU Fail Fan Policy
* 9.21 Over Temperature Fan Policy
* 9.22 Manual Fan Mode
* 9.23 Auto Fan Mode
* 9.24 Fan Speed Accuracy 驗證
* 9.25 Fan Ramp Up / Ramp Down 驗證
* 9.26 Fan Hot-plug 驗證
* 9.27 Acoustic 驗證
* 9.28 Thermal 驗證
* 9.29 Fan Control Long Run

---

## 10. Power Control Checklist

* 10.1 Power Sequence Review
* 10.2 BMC / CPLD / BIOS 分工確認
* 10.3 Power Button 行為
* 10.4 Reset Button 行為
* 10.5 Power On 流程
* 10.6 Power Off 流程
* 10.7 Power Cycle 流程
* 10.8 Hard Reset 流程
* 10.9 Graceful Shutdown 流程
* 10.10 Force Off 流程
* 10.11 AC Recovery Policy
* 10.12 Power Restore Policy
* 10.13 Power Fault 偵測
* 10.14 Host Power Status 回報
* 10.15 Power Sequence Timeout 處理
* 10.16 Power Good Debounce
* 10.17 Long Press Power Button
* 10.18 Chassis Intrusion
* 10.19 CMOS Clear 行為
* 10.20 AC Cycle 驗證
* 10.21 DC Cycle 驗證
* 10.22 Reboot / Reset Stress Test
* 10.23 Brown-out / Low Voltage 測試
* 10.24 High Temperature Power Cycle 測試

---

## 11. Host Interface Checklist

* 11.1 KCS Interface
* 11.2 BT Interface
* 11.3 SSIF Interface
* 11.4 LPC / eSPI Interface
* 11.5 BIOS 與 BMC 通訊
* 11.6 BIOS POST Code
* 11.7 Host Boot Status
* 11.8 Host Watchdog
* 11.9 BIOS Attribute
* 11.10 Host Reset Event
* 11.11 Host Crash / Timeout 處理
* 11.12 Boot Option
* 11.13 BIOS Shared Memory
* 11.14 BIOS Event 傳遞
* 11.15 Host Interface Stress Test

---

## 12. MCTP / PLDM / SPDM Checklist

> 這章新增，對 AST2600 / eBMC / PCIe 裝置管理平台很重要。

* 12.1 MCTP Requirement 確認
* 12.2 MCTP over PCIe VDM
* 12.3 MCTP over I2C / SMBus
* 12.4 MCTP Endpoint ID 分配
* 12.5 MCTP Routing Table
* 12.6 MCTP Discovery
* 12.7 MCTP Binding Driver
* 12.8 PLDM Requirement 確認
* 12.9 PLDM Base
* 12.10 PLDM Platform Monitoring and Control
* 12.11 PLDM BIOS Control and Configuration
* 12.12 PLDM Firmware Update
* 12.13 PLDM FRU Data
* 12.14 NVMe-MI 支援
* 12.15 Retimer Management
* 12.16 PCIe Device Inventory
* 12.17 SPDM Requirement 確認
* 12.18 SPDM Certificate
* 12.19 SPDM Measurement
* 12.20 SPDM Secure Session
* 12.21 MCTP / PLDM / SPDM Error Handling
* 12.22 MCTP / PLDM Stress Test
* 12.23 Redfish Inventory Mapping
* 12.24 Firmware Update Mapping

---

## 13. IPMI Checklist

* 13.1 IPMI Channel 設定
* 13.2 IPMI LAN 設定
* 13.3 IPMI User Management
* 13.4 Chassis Command
* 13.5 Sensor Command
* 13.6 SDR Table
* 13.7 SEL Command
* 13.8 FRU Command
* 13.9 Watchdog Command
* 13.10 Boot Option
* 13.11 SOL
* 13.12 OEM Command
* 13.13 IPMI Cipher Suite
* 13.14 IPMI Privilege
* 13.15 IPMI Session Timeout
* 13.16 IPMI over LAN
* 13.17 IPMI KCS
* 13.18 IPMI SSIF
* 13.19 IPMI Stress Test
* 13.20 IPMI / Redfish 資料一致性

---

## 14. Redfish Checklist

* 14.1 Redfish Service Root
* 14.2 Manager Resource
* 14.3 ComputerSystem Resource
* 14.4 Chassis Resource
* 14.5 Sensor Resource
* 14.6 Thermal Resource
* 14.7 Power Resource
* 14.8 LogServices
* 14.9 UpdateService
* 14.10 AccountService
* 14.11 SessionService
* 14.12 EventService
* 14.13 TaskService
* 14.14 BIOS Attribute
* 14.15 CertificateService
* 14.16 TelemetryService
* 14.17 HostInterface
* 14.18 PCIeDevice / PCIeFunction
* 14.19 Redfish Schema Version 確認
* 14.20 Redfish Privilege Mapping
* 14.21 Redfish Event Subscription
* 14.22 Redfish Firmware Update Flow
* 14.23 Redfish Conformance Test
* 14.24 Redfish / IPMI / Web UI 資料一致性

---

## 15. Web UI Checklist

* 15.1 Login / Logout
* 15.2 First Login Password Change
* 15.3 Dashboard
* 15.4 Sensor Page
* 15.5 Event Log Page
* 15.6 Inventory Page
* 15.7 Power Control Page
* 15.8 Fan Control Page
* 15.9 Network Setting Page
* 15.10 User Management Page
* 15.11 Firmware Update Page
* 15.12 KVM Page
* 15.13 SOL Page
* 15.14 Virtual Media Page
* 15.15 SSL Certificate Page
* 15.16 Time / NTP Page
* 15.17 Factory Reset
* 15.18 Browser Compatibility Test
* 15.19 Session Timeout
* 15.20 Web UI Security Test

---

## 16. FRU / Inventory Checklist

* 16.1 Board FRU
* 16.2 Product FRU
* 16.3 Chassis FRU
* 16.4 PSU FRU
* 16.5 Fan Inventory
* 16.6 CPU Inventory
* 16.7 DIMM Inventory
* 16.8 PCIe Device Inventory
* 16.9 NVMe Inventory
* 16.10 NIC Inventory
* 16.11 Storage / Backplane Inventory
* 16.12 Retimer Inventory
* 16.13 CPLD / FPGA Version
* 16.14 BIOS Version
* 16.15 BMC Version
* 16.16 PSU Firmware Version
* 16.17 MAC Address
* 16.18 Serial Number
* 16.19 Asset Tag
* 16.20 UUID
* 16.21 Manufacturing Date
* 16.22 IPMI / Redfish / Web UI 顯示一致性

---

## 17. Firmware Update Checklist

* 17.1 BMC Firmware Update
* 17.2 BIOS Firmware Update
* 17.3 CPLD Firmware Update
* 17.4 FPGA Firmware Update
* 17.5 PSU Firmware Update
* 17.6 Retimer Firmware Update
* 17.7 NIC Firmware Update
* 17.8 Backplane Firmware Update
* 17.9 NVMe Firmware Update
* 17.10 Update Image Format
* 17.11 Signature Verification
* 17.12 Version Check
* 17.13 Anti-Rollback
* 17.14 Update Progress 回報
* 17.15 Update Failure Handling
* 17.16 Rollback / Recovery
* 17.17 Dual Image / Golden Image
* 17.18 Redfish Update
* 17.19 Web UI Update
* 17.20 IPMI Update
* 17.21 PLDM Firmware Update
* 17.22 Power Loss During Update
* 17.23 Firmware Update Stress Test
* 17.24 Firmware Update Event / Log

---

## 18. KVM / SOL / Virtual Media Checklist

* 18.1 KVM Video Capture
* 18.2 KVM Keyboard
* 18.3 KVM Mouse
* 18.4 KVM Resolution
* 18.5 KVM Performance
* 18.6 KVM Multi-session Policy
* 18.7 Host On / Off 狀態切換
* 18.8 SOL UART Routing
* 18.9 SOL Baud Rate
* 18.10 IPMI SOL
* 18.11 Web SOL
* 18.12 SOL Log Capture
* 18.13 Virtual Media USB Routing
* 18.14 ISO Mount / Unmount
* 18.15 Virtual Media Host Detection
* 18.16 USB Mass Storage Enable / Disable Policy
* 18.17 KVM / SOL / Media Long Run

---

## 19. Network Checklist

* 19.1 Dedicated NIC
* 19.2 Shared NIC / NC-SI
* 19.3 MAC Address 來源
* 19.4 IPv4
* 19.5 IPv6
* 19.6 DHCP
* 19.7 Static IP
* 19.8 VLAN
* 19.9 DNS
* 19.10 Hostname
* 19.11 NTP
* 19.12 Bonding / NIC Failover
* 19.13 Network Reset 行為
* 19.14 Link Up / Link Down Event
* 19.15 Network Service 啟動順序
* 19.16 Network Ready Time
* 19.17 Web / SSH / IPMI / Redfish 連線確認
* 19.18 Network Stress Test
* 19.19 NC-SI Failover Test
* 19.20 IPv6 Security 檢查

---

## 20. Time / RTC / Timestamp Checklist

> 這章新增，避免 NTP 藏在 Network 裡被忽略。

* 20.1 RTC Device 確認
* 20.2 RTC Battery 狀態
* 20.3 RTC Battery Low Event
* 20.4 Default Time Policy
* 20.5 Timezone 設定
* 20.6 NTP Client
* 20.7 NTP Server 設定
* 20.8 PTP Requirement 確認
* 20.9 Time Sync After AC Cycle
* 20.10 Time Sync After BMC Reboot
* 20.11 Time Sync Without Network
* 20.12 SEL Timestamp
* 20.13 Redfish Log Timestamp
* 20.14 System Journal Timestamp
* 20.15 Audit Log Timestamp
* 20.16 Firmware Update Log Timestamp
* 20.17 Factory Default Time 驗證

---

## 21. Security Checklist

* 21.1 Secure Boot
* 21.2 Firmware Signature
* 21.3 Anti-Rollback
* 21.4 Password Policy
* 21.5 Default Account Policy
* 21.6 First Login Password Change
* 21.7 User Role / Privilege
* 21.8 Account Lockout
* 21.9 SSH Policy
* 21.10 HTTPS / TLS
* 21.11 Certificate Management
* 21.12 IPMI Cipher Suite
* 21.13 Redfish Session Security
* 21.14 LDAP / AD / RADIUS
* 21.15 Audit Log
* 21.16 Service Enable / Disable
* 21.17 USB Mass Storage Enable / Disable Policy
* 21.18 Debug Port Policy
* 21.19 Factory Mode Security
* 21.20 Recovery Mode Security
* 21.21 Session Timeout
* 21.22 CSRF / XSS 防護
* 21.23 Vulnerability Scan
* 21.24 CVE Scan
* 21.25 Penetration Test
* 21.26 Security Regression Test

---

## 22. Logging / Event Checklist

* 22.1 SEL Event Mapping
* 22.2 Redfish Event Log
* 22.3 System Journal
* 22.4 Audit Log
* 22.5 Firmware Update Log
* 22.6 User Login / Logout Event
* 22.7 Sensor Threshold Event
* 22.8 Sensor Unavailable Event
* 22.9 Fan Event
* 22.10 PSU Event
* 22.11 Power Event
* 22.12 Thermal Event
* 22.13 Watchdog Event
* 22.14 BIOS POST Event
* 22.15 PCIe Event
* 22.16 MCTP / PLDM Event
* 22.17 Security Event
* 22.18 Event Severity
* 22.19 Event Timestamp
* 22.20 Deassert Event
* 22.21 Duplicate Event Suppression
* 22.22 Log Full Policy
* 22.23 Log Clear 行為
* 22.24 AC Cycle 後 Log 保留確認
* 22.25 Log Export

---

## 23. Debug / Trace / Crash Dump Checklist

> 這章新增，讓 porting issue 有固定資訊同步方式。

* 23.1 Debug UART 使用方式
* 23.2 BMC Boot Log 收集
* 23.3 Kernel Log 收集
* 23.4 System Journal 收集
* 23.5 Service Status 收集
* 23.6 Core Dump Enable
* 23.7 Core Dump 收集方式
* 23.8 Core Dump 解析方式
* 23.9 kdump 設定
* 23.10 ramoops / pstore 設定
* 23.11 Persistent Journal 設定
* 23.12 Watchdog Reset Log
* 23.13 BMC Crash Log
* 23.14 Host Crash Log
* 23.15 I2C Debug Command
* 23.16 GPIO Debug Command
* 23.17 Sensor Debug Command
* 23.18 Fan Debug Command
* 23.19 IPMI Debug Command
* 23.20 Redfish Debug Command
* 23.21 Network Packet Capture
* 23.22 MCTP / PLDM Trace
* 23.23 Firmware Update Debug Log
* 23.24 Issue Log Package Format
* 23.25 Debug Data Privacy 檢查

---

## 24. Manufacturing / Factory Checklist

* 24.1 Manufacturing Mode
* 24.2 Manufacturing Mode Entry Method
* 24.3 Jumper Detect
* 24.4 CMOS Clear Detect
* 24.5 Recovery Mode Entry Method
* 24.6 MAC Address 燒錄
* 24.7 Serial Number 燒錄
* 24.8 FRU 寫入
* 24.9 Asset Tag 寫入
* 24.10 UUID 寫入
* 24.11 Board ID / SKU ID 設定
* 24.12 Default Configuration
* 24.13 Factory Reset
* 24.14 LED Test
* 24.15 Fan Test
* 24.16 Sensor Scan
* 24.17 I2C Scan
* 24.18 Firmware Version Check
* 24.19 Production Test Command
* 24.20 Golden Image Recovery
* 24.21 Recovery Button / Jumper Flow
* 24.22 Factory Security Policy
* 24.23 出貨前檢查項目
* 24.24 Factory Log 保存方式

---

## 25. Validation Checklist

* 25.1 Basic Function Test
* 25.2 AC Cycle Test
* 25.3 DC Cycle Test
* 25.4 Host Reboot Test
* 25.5 BMC Reboot Test
* 25.6 Power Cycle Test
* 25.7 Sensor Test
* 25.8 Fan Control Test
* 25.9 Thermal Test
* 25.10 PSU Fail Test
* 25.11 Fan Fail Test
* 25.12 Network Stress Test
* 25.13 IPMI Stress Test
* 25.14 Redfish Stress Test
* 25.15 Web UI Test
* 25.16 KVM / SOL Test
* 25.17 Firmware Update Test
* 25.18 MCTP / PLDM Test
* 25.19 Security Test
* 25.20 RTC / Timestamp Test
* 25.21 Boot Time Test
* 25.22 Low Voltage Test
* 25.23 High Temperature Test
* 25.24 Thermal Chamber Test
* 25.25 Long Run Test
* 25.26 Regression Test
* 25.27 Corner Case Test
* 25.28 Fault Injection Test

---

## 26. Issue Tracking Checklist

* 26.1 Known Issue List
* 26.2 Issue Priority 定義
* 26.3 Issue Severity 定義
* 26.4 Issue Owner
* 26.5 Reproduce Step
* 26.6 Failure Rate
* 26.7 Failure Log 收集
* 26.8 Impact Scope
* 26.9 Workaround
* 26.10 Root Cause Analysis
* 26.11 Fix Version
* 26.12 Regression Result
* 26.13 Open / Fixed / Verified 狀態
* 26.14 Release Blocker 清單
* 26.15 Customer Impact Statement

---

## 27. Release Checklist

* 27.1 Release Version 確認
* 27.2 Build Tag 確認
* 27.3 Commit ID 確認
* 27.4 Firmware Image 確認
* 27.5 Checksum 確認
* 27.6 Signature 確認
* 27.7 Release Note
* 27.8 Supported Hardware Revision
* 27.9 Supported BIOS / CPLD / FPGA 版本
* 27.10 Known Issue
* 27.11 Upgrade Path
* 27.12 Downgrade Policy
* 27.13 Recovery 方法
* 27.14 Validation Report
* 27.15 Security Scan Report
* 27.16 Manufacturing Readiness
* 27.17 客戶交付項目
* 27.18 Archive Package

---

## 28. Appendix

* 28.1 GPIO Table Template
* 28.2 Pinmux Table Template
* 28.3 I2C Bus Map Template
* 28.4 I2C Device List Template
* 28.5 Sensor List Template
* 28.6 Fan Table Template
* 28.7 Power Sequence Template
* 28.8 Boot Time Measurement Template
* 28.9 Flash Partition Table Template
* 28.10 SDR Mapping Template
* 28.11 SEL Event Mapping Template
* 28.12 Redfish Mapping Template
* 28.13 MCTP Endpoint Mapping Template
* 28.14 PLDM Function Mapping Template
* 28.15 Firmware Update Matrix Template
* 28.16 Security Checklist Template
* 28.17 Manufacturing Checklist Template
* 28.18 Test Report Template
* 28.19 Long Run Test Template
* 28.20 Debug Log Collection Guide
* 28.21 Core Dump / Crash Log Analysis Guide
* 28.22 常用 Debug Command
* 28.23 Release Note Template
* 28.24 Known Issue Template
