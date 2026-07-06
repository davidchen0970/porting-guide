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

### 0.7 資料來源可信度分級

- A：官方標準、Linux kernel 文件、Yocto 文件、SoC datasheet、board schematic。
- B：OpenBMC 官方 repository / design document。
- C：廠商應用手冊、白皮書、公開技術文章。
- D：論壇、部落格、推測性資料，只能作為排查線索。

---

## 第一部分：硬體底層抽象層

### 1. Boot Flow 與 SoC 初始化

BMC 典型開機流程：

1. Power rails 穩定，reset deassert。
2. Strap pin latch：決定 boot source、bus width、secure boot、debug mode 等。
3. BootROM 從 SPI-NOR / SPI-NAND / eMMC 載入第一階段 bootloader。
4. SPL / U-Boot 初始化 clock、DDR、pinmux、基本 console。
5. U-Boot 載入 kernel、DTB、rootfs，帶入 bootargs。
6. Kernel 初始化 driver，掛載 rootfs。
7. systemd 啟動 BMC services。
8. 管理協定就緒：SSH / Redfish / IPMI / Web / Host interface。

Boot failure 建議分層：

- 無 UART：檢查 power、reset、strap、clock、UART pinmux。
- BootROM 無法讀 flash：檢查 boot source strap、CS/CLK/MOSI/MISO、flash voltage、flash mode。
- DDR fail：檢查 DDR voltage、clock、routing、training log、SoC DDR config。
- Kernel panic：檢查 bootargs、DT memory、rootfs、driver probe。
- userspace fail：檢查 systemd failed units、journal、read-write partition、overlay。

平台必填表：

| 項目                | 設定 / 量測值 | 責任窗口        |
| ------------------- | ------------- | --------------- |
| Boot source strap   | [待填]        | HW/BMC          |
| Secure boot strap   | [待填]        | HW/BMC/Security |
| UART console pin    | [待填]        | HW/BMC          |
| Flash 型號 / 容量   | [待填]        | HW/BMC          |
| DDR 型號 / 容量     | [待填]        | HW/BMC          |
| Reset deassert 時間 | [待填]        | HW              |

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

### 11. Sensor 抽象層

Sensor 資料流：driver/hwmon → userspace sensor daemon → D-Bus object → Redfish/IPMI/SEL/Event。Sensor 狀態需區分：正常、不可用、讀值超界、device 不存在、bus error、timeout。

Sensor 欄位範本：

| Name   | Type             | Source    | Scale  | Unit    | Warning | Critical | D-Bus path | Redfish | IPMI SDR |
| ------ | ---------------- | --------- | ------ | ------- | ------: | -------: | ---------- | ------- | -------- |
| [待填] | temp/voltage/fan | hwmon/i2c | [待填] | C/V/RPM |  [待填] |   [待填] | [待填]     | [待填]  | [待填]   |

### 12. Fan Control

風控策略需定義四種狀態：Host Off、Host On、Boot、Failsafe。Failsafe 應在 sensor unavailable、fan tach lost、控制程式異常、unknown thermal state 時生效。

PID 調整保留資料：Kp/Ki/Kd、sample time、target sensor、min/max PWM、slew rate、anti-windup、zone mapping。

### 13. Power Control

x86 平台常見 BMC/CPLD/BIOS 權責：

- BMC：接收遠端 power command、控制 PWRBTN、讀取 power state、記錄事件。
- CPLD：硬體時序、fault latch、critical reset gating。
- BIOS/UEFI：POST、boot progress、host inventory、setup attribute。

Power sequence 必填：每條 rail enable / power good / reset / PWRBTN / SLP_Sx / PLTRST / RSMRST 的時間戳。

### 14. Inventory / FRU / Asset 資料模型

資料來源需定義權威端：EEPROM、CPLD register、BIOS table、Entity Manager JSON、manufacturing provisioning。FRU 與 Redfish Inventory 欄位需一致。

### 15. Logging / Event / Telemetry

Log 分類：BMC system log、kernel log、journal、SEL、Redfish EventLog、sensor event、firmware update log、安全 log、crash dump。Log 滿時策略需明確：循環覆寫、停止新增、遠端轉存、壓縮保存。

---

## 第四部分：Host Communication

### 16. KCS / BT / SSIF / eSPI

KCS/IPMI 適合 host OS 與 BMC 的 legacy 管理通道；eSPI 是新平台常見 host-BMC sideband，包含 peripheral channel、OOB、virtual wire、flash channel。驗證時需確認 host reset、PLTRST、virtual wire、POST code、boot progress、watchdog。

### 17. BIOS / UEFI 與 BMC 互動

需建立 BIOS-BMC interface contract：

| Feature        | Transport     | Owner    | Timing   | Data format     | Error handling |
| -------------- | ------------- | -------- | -------- | --------------- | -------------- |
| POST code      | LPC/eSPI      | BIOS/BMC | POST     | byte/code table | timeout        |
| Boot progress  | IPMI/PLDM/OEM | BIOS/BMC | POST     | enum            | last state     |
| Boot order     | Redfish/IPMI  | BMC/BIOS | pre-boot | attribute       | reject/retry   |
| Host inventory | PLDM/IPMI/OEM | BIOS/BMC | POST/OS  | FRU format      | stale mark     |

### 18. MCTP / PLDM / SPDM

MCTP 是平台內部管理傳輸層，可跑在 SMBus/I2C、PCIe VDM 等介面，使用 EID 描述 endpoint。PLDM 提供 monitoring/control、FRU、firmware update 等管理資料模型。SPDM 用於裝置認證、憑證、量測與安全通道。

---

## 第五部分：管理介面與網路

### 19. IPMI 通用知識

IPMI 提供 sensor、SEL、FRU、power control、SOL、LAN 管理等能力。新設計應限制不安全 cipher suite，並避免新增不必要 OEM command。

OEM command 範本：NetFn、Cmd、Request、Response、Completion Code、權限、狀態依賴、錯誤處理、測試案例。

### 20. Redfish 通用知識

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

### 21. Network Services

必填：DHCP/static、VLAN、hostname、DNS、NTP/PTP、MAC 來源、bonding、NIC failover、link ready time、IPv6 policy。量測開機可連線時間時要拆分：kernel driver ready、link up、DHCP lease、service listening、API first success。

---

## 第六部分：安全與韌體維運

### 22. Security Baseline

基準項目：secure boot、韌體簽章、anti-rollback、密碼政策、預設帳號、首次登入改密碼、TLS 憑證、IPMI cipher suite、最小服務集、審計 log、debug port policy、secret storage、量產 key 與開發 key 分離。

密碼政策建議與近代 NIST 方向一致：重視長度、阻擋常見或外洩密碼、避免無意義的固定週期變更；但最終仍需依產品安全規範與客戶需求決定。

### 23. Firmware Update

更新流程：上傳 image → 驗證 manifest/signature/version/machine → 建立 software object → activation → progress → reboot 或切換 slot → health check → commit / rollback。

Power loss 測試必做：更新前、寫入 bootloader、寫入 kernel、寫入 rootfs、切 slot、首次開機、commit 前斷電。

### 24. Secure Recovery / RMA / Field Service

RMA 應先保存：BMC version、BIOS version、CPLD version、boot count、reset reason、SEL、journal、dmesg、update history、FRU、sensor snapshot、network config、crash dump。Factory reset 需明確列出會清除與不會清除的資料。

---

## 第七部分：除錯、效能與測試

### 25. Debug Methodology

問題單最小資料：現象、重現率、版本、步驟、預期、實際、log、量測點、最近變更、是否與 AC/DC cycle 有關。排查時先固定硬體、韌體、設定與測試工具版本。

### 26. Debug Toolkit

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

### 27. Performance / Resource / Boot Time

Boot time 拆解：BootROM、U-Boot、kernel、userspace、network ready、API ready。systemd 可用 `systemd-analyze`、`blame`、`critical-chain` 與 `plot` 檢查。

資源監控：CPU、memory、D-Bus call rate、sensor polling interval、journal size、flash write rate、network connection count。

### 28. 通用測試矩陣

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

### 29. Manufacturing / Factory

產線流程：進入生產模式 → 燒錄 MAC/Serial/UUID/FRU → 寫入 key/cert（如適用）→ board/SKU ID 檢查 → sensor quick test → fan test → network test → Redfish/IPMI smoke test → 出廠重置 → 關閉 debug / manufacturing mode。

### 30. Calibration / Board Data / Provisioning

校正資料需定義：來源、公式、儲存位置、備份、版本、checksum、更新權限。Provisioning 失敗需可重試且不得留下半寫入資料。

---

## 第九部分：平台差異筆記本

### 31. SoC 筆記標準填寫模板

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
