# BMC 通用 Porting 技術參考


## 檔案結構

- `00_手冊使用說明.md`：原文件開頭、手冊說明與修訂紀錄。
- `NN_第X部分_.../`：依文件中的「第X部分」建立的資料夾。
- `NN_章節名稱.md`：各主章節內容，保留原章節內的小節。

## 章節索引

### 第一部分：硬體底層抽象層

- [1. Boot Flow 與 SoC 初始化](01_第一部分_硬體底層抽象層/01_Boot_Flow_與_SoC_初始化.md)
- [2. Flash Partition 與儲存架構](01_第一部分_硬體底層抽象層/02_Flash_Partition_與儲存架構.md)
- [3. Pinmux / GPIO 通用設計模式](01_第一部分_硬體底層抽象層/03_Pinmux_GPIO_通用設計模式.md)
- [4. Reset / Clock / Power Domain](01_第一部分_硬體底層抽象層/04_Reset_Clock_Power_Domain.md)
- [5. 周邊匯流排通用知識](01_第一部分_硬體底層抽象層/05_周邊匯流排通用知識.md)
- [6. CPLD / FPGA / Board Glue Logic](01_第一部分_硬體底層抽象層/06_CPLD_FPGA_Board_Glue_Logic.md)

## 第二部分：BSP、Kernel 與 Device Tree

- [7. Build System 與 BSP 結構](02_第二部分_BSP_Kernel_與_Device_Tree/07_Build_System_與_BSP_結構.md)
- [8. Device Tree 通用寫法與排查](02_第二部分_BSP_Kernel_與_Device_Tree/08_Device_Tree_通用寫法與排查.md)
- [9. Kernel Driver 與核心服務](02_第二部分_BSP_Kernel_與_Device_Tree/09_Kernel_Driver_與核心服務.md)

## 第三部分：平台監控與控制

- [10. I2C / PMBus Framework](03_第三部分_平台監控與控制/10_I2C_PMBus_Framework.md)
- [11. OpenBMC 常用 Project 與服務速查](03_第三部分_平台監控與控制/11_OpenBMC_常用_Project_與服務速查.md)
- [12. Sensor 抽象層](03_第三部分_平台監控與控制/12_Sensor_抽象層.md)
- [13. Fan Control 與 Thermal Policy](03_第三部分_平台監控與控制/13_Fan_Control_與_Thermal_Policy.md)
- [14. Power Control](03_第三部分_平台監控與控制/14_Power_Control.md)
- [15. Inventory / FRU / Asset 資料模型](03_第三部分_平台監控與控制/15_Inventory_FRU_Asset_資料模型.md)
- [16. Logging / Event / Telemetry](03_第三部分_平台監控與控制/16_Logging_Event_Telemetry.md)
- [17. Presence / Intrusion / GPIO State Sensor](03_第三部分_平台監控與控制/17_Presence_Intrusion_GPIO_State_Sensor.md)


### 第四部分：Host Communication

- [18. KCS / BT / SSIF / eSPI](04_第四部分_Host_Communication/18_KCS_BT_SSIF_eSPI.md)
- [19. BIOS / UEFI 與 BMC 互動](04_第四部分_Host_Communication/19_BIOS_UEFI_與_BMC_互動.md)

## 第五部分：管理介面與網路

- [20. MCTP / PLDM / SPDM](05_第五部分_管理介面與網路/20_MCTP_PLDM_SPDM.md)
- [21. IPMI 通用知識](05_第五部分_管理介面與網路/21_IPMI_通用知識.md)
- [22. Redfish 通用知識](05_第五部分_管理介面與網路/22_Redfish_通用知識.md)
- [23. Network Services](05_第五部分_管理介面與網路/23_Network_Services.md)

### 第六部分：安全與韌體維運

- [24. Security Baseline](06_第六部分_安全與韌體維運/24_Security_Baseline.md)
- [25. Firmware Update](06_第六部分_安全與韌體維運/25_Firmware_Update.md)
- [26. Secure Recovery / RMA / Field Service](06_第六部分_安全與韌體維運/26_Secure_Recovery_RMA_Field_Service.md)

### 第七部分：除錯、效能與測試

- [27. Debug Methodology](07_第十部分_附錄/27_Debug_Methodology.md)
- [28. Debug Toolkit](07_第十部分_附錄/28_Debug_Toolkit.md)
- [29. 各類 Sensor 共用除錯指令及附錄](07_第十部分_附錄/29_各類_Sensor_共用除錯指令及附錄.md)
- [30. Performance / Resource / Boot Time](07_第十部分_附錄/30_Performance_Resource_Boot_Time.md)
- [31. 通用測試矩陣](07_第十部分_附錄/31_通用測試矩陣.md)

### 第八部分：工廠與生產

- [32. Manufacturing / Factory](08_第八部分_工廠與生產/32_Manufacturing_Factory.md)
- [33. Calibration / Board Data / Provisioning](08_第八部分_工廠與生產/33_Calibration_Board_Data_Provisioning.md)

### 第九部分：平台差異筆記本

- [34. SoC 筆記標準填寫模板](06_第九部分_平台差異筆記本/34_SoC_筆記標準填寫模板.md)


### 第十部分：附錄

- [附錄 A01：常用縮寫與名詞對照](10_第十部分_附錄/A01_常用縮寫與名詞對照.md)
- [附錄 A02：常用指令速查](10_第十部分_附錄/A02_常用指令速查.md)
- [附錄 A03：Log 收集套件範本](10_第十部分_附錄/A03_Log_收集套件範本.md)
- [附錄 A04：Bring-up 與驗收 Checklist](10_第十部分_附錄/A04_Bring-up_與驗收_Checklist.md)
- [附錄 A05：文件填寫範本](10_第十部分_附錄/A05_文件填寫範本.md)
