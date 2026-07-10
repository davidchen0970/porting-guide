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
