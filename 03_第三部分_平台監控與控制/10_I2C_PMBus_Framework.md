### 10. I2C / PMBus Framework

本章獨立整理 BMC 平台中的 Linux I2C / SMBus / PMBus framework。Sensor 章節會討論各類 sensor 如何從 hwmon / dbus-sensors 進入 D-Bus、Redfish 與 IPMI；本章則聚焦在 sensor 之前的 bus framework：I2C adapter 如何建立、client device 如何被 instantiate、I2C mux 如何形成 adapter tree、PMBus driver 如何綁定、PMBus sensor 如何映射到 hwmon 與 OpenBMC，以及 PMBus debug 時應先收哪些資料。

Linux kernel 的 I2C/SMBus 文件將 I2C subsystem 拆成 protocol、device instantiate、bus driver、mux/complex topology、sysfs、driver writing、fault injection 等主題；BMC 平台若未先建立這層框架，後續 sensor、FRU、PSU、VR、CPLD、GPIO expander、fan controller 章節會混在一起排查。PMBus 則是跑在 SMBus/I2C 之上的 power-management protocol，Linux PMBus driver 會透過 hwmon 暴露 voltage、current、power、temperature 等資料，但 PMBus command 標準化不代表每顆裝置都支援同一組命令，因此 driver 選型與 debug 需要特別保守。

#### 10.1 Linux I2C Architecture

Linux I2C framework 的核心物件可以簡化為三個：`i2c_adapter`、`i2c_client`、`i2c_driver`。Adapter 代表一條可執行 I2C transaction 的 bus；client 代表 bus 上某個 address 的 device；driver 則是支援某類 client 的 kernel driver。

```text
SoC I2C controller / mux child bus
    ↓
i2c_adapter
    ↓
Device Tree child node / new_device / board info
    ↓
i2c_client：bus + 7-bit address + device type
    ↓
i2c_driver match / probe
    ↓
hwmon / gpiochip / nvmem / regmap / misc / custom sysfs
    ↓
OpenBMC daemon / D-Bus / Redfish / IPMI
```


| Linux 物件 | 代表什麼 | BMC 常見例子 | 排查入口 |
| --- | --- | --- | --- |
| `i2c_adapter` | 一條 root bus 或 mux child bus | BMC I2C5、PCA9548 channel 0 | `i2cdetect -l`、`/sys/bus/i2c/devices/i2c-*` |
| `i2c_client` | 某條 adapter 上的 7-bit address device | `5-0048` TMP75、`20-0058` PSU PMBus | `/sys/bus/i2c/devices/-00` |
| `i2c_driver` | 支援某類 client 的 driver | `tmp75`、`pmbus`、`pca953x`、`at24` | `/sys/bus/i2c/drivers`、driver symlink |
| `i2c_mux` | 在 parent bus 下建立 child adapters | `pca954x`、GPIO mux、CPLD mux | adapter tree、`i2cdetect -l`、mux driver log |
| hwmon | 硬體監控標準 sysfs 介面 | PSU power、VR voltage、temperature | `/sys/class/hwmon/hwmonX` |


Linux I2C device 不像 PCI / USB 會由硬體自行完整枚舉。對 embedded / BMC 平台，kernel 通常需要透過 Device Tree child node、ACPI、board data 或 debug 用的 `new_device` 明確建立 client。這代表「bus 掃得到 ACK」不等於「driver 已經 probe」，也不等於「OpenBMC sensor 會出現」。

基本檢查：

```bash
# 列出 logical I2C adapters
i2cdetect -l

# 列出 I2C bus / client / mux child adapters
ls -l /sys/bus/i2c/devices
find /sys/bus/i2c/devices -maxdepth 2 -type l -o -type d | sort

# 查看 client 綁定的 driver
readlink /sys/bus/i2c/devices/<bus>-00<addr>/driver 2>/dev/null
cat /sys/bus/i2c/devices/<bus>-00<addr>/name 2>/dev/null

# 查看 kernel log
dmesg | grep -Ei 'i2c|smbus|pmbus|hwmon|mux|nack|timeout|arbitration|stuck'
```

#### 10.2 Adapter：root adapter、mux child adapter 與 bus number

`i2c_adapter` 是 Linux 送出 I2C transfer 的入口。Root adapter 通常對應 SoC I2C controller；mux child adapter 則是 I2C mux framework 在 parent adapter 底下建立的 logical bus。


| Adapter 類型 | 來源 | Linux 表示 | 注意事項 |
| --- | --- | --- | --- |
| Root adapter | SoC I2C controller driver | `i2c-0`、`i2c-5` | 需要 pinctrl、clock、reset、bus-frequency |
| Mux child adapter | PCA954x / GPIO mux / CPLD mux | `i2c-20` 這類 logical bus | bus number 可能受 probe order 影響 |
| Arbitrated adapter | multi-master / external master arbitration | child adapter | 需要 arbitration policy |
| Gate adapter | 存取前需開 gate | child adapter | select / deselect timing 會影響 timeout |


Adapter debug 重點：

- `i2cdetect -l` 顯示的是 logical adapter，不一定等同 schematic 上的 physical bus。
- 若 adapter 是 mux 後的 channel，文件需記錄 parent bus、mux address、channel id。
- 不建議在 OpenBMC JSON 或腳本中只寫死 bus number；若不得不寫，需驗證重開機、driver probe order 改變、kernel 更新後是否穩定。
- Adapter name、device path、mux path 比純 bus number 更適合做長期對照。
- Bus frequency 需符合最慢 device 與 signal integrity；PMBus / PSU / hot-plug bus 不一定適合跑 fast mode。

拓樸表範本：


| Physical bus | Linux adapter | Mux path | Bus frequency | Power domain | Owner | 狀態 |
| --- | --- | --- | --- | --- | --- | --- |
| BMC I2C5 | [待填] | none | [待填] | 3V3_AUX | BMC | [待確認] |
| BMC I2C6 → PCA9548 ch0 | [待填] | 0x70/ch0 | [待填] | PSU standby | BMC/PSU | [待確認] |
| BMC I2C6 → PCA9548 ch1 | [待填] | 0x70/ch1 | [待填] | PSU standby | BMC/PSU | [待確認] |


#### 10.3 Client Device：建立方式、address、driver binding

`i2c_client` 是「某條 adapter 上某個 7-bit address 的 device」。BMC 常見 client 包含 EEPROM、temperature sensor、GPIO expander、I2C mux、PMBus PSU / VR / HSC、CPLD / FPGA、fan controller。

常見建立方式：


| 方式 | 用途 | 優點 | 限制 |
| --- | --- | --- | --- |
| Device Tree child node | 固定存在的 embedded device | 正式、可描述 GPIO / IRQ / supply | 不適合純動態熱插拔資訊 |
| `new_device` | bring-up / debug 暫時建立 client | 快速驗證 driver 是否可綁定 | 不應作為正式產品路徑 |
| driver detect | 少數 legacy driver 掃描 address | 自動化 | PMBus / EEPROM / CPLD 不建議隨意偵測 |
| platform daemon | 依 FRU / presence / SKU 動態建立 | 可支援可插拔與 SKU 差異 | 需處理 race、remove、service restart |


DTS 範本：

```dts
&i2c5 {
    status = "okay";
    bus-frequency = <100000>;

    temperature-sensor@48 {
        compatible = "ti,tmp75";
        reg = <0x48>;
    };

    eeprom@50 {
        compatible = "atmel,24c64";
        reg = <0x50>;
        pagesize = <32>;
    };
};
```

重要規則：

- I2C address 使用 7-bit address；若 datasheet 寫 0x90 / 0x91，通常 DTS / `new_device` 要填 0x48。
- 同一 bus segment 上不可有 address conflict；mux 不同 channel 可重複 address。
- `compatible` / driver name / modalias 需和 kernel driver 支援表對上。
- `i2cdetect` 掃到 ACK 只表示有 device 回應，不表示 driver 正確或資料可安全讀取。
- `UU` 表示 address 已被 kernel driver 佔用，不是錯誤。

Debug 用 `new_device`：

```bash
# 範例：在 i2c-5 0x48 暫時建立 tmp75 client
echo tmp75 0x48 > /sys/bus/i2c/devices/i2c-5/new_device

# 移除 debug client
echo 0x48 > /sys/bus/i2c/devices/i2c-5/delete_device
```

#### 10.4 Mux：I2C adapter tree 與複雜拓樸

BMC 平台常用 PCA9548 / PCA9546 / GPIO mux / CPLD mux 將多個相同 address 的裝置隔離到不同 channel，例如 PSU0 / PSU1 都是 0x58。Linux I2C mux framework 會把每個 mux channel 表示成一個 child adapter。Kernel 文件也指出複雜 I2C topology 可能用於避免 address collision、處理外部 master arbitration、或透過 gate 隔離 bus noise；Linux 會以 adapter tree 表達這些拓樸。

```text
root adapter i2c-6
  └── mux@70 pca9548
        ├── channel 0 → child adapter i2c-20 → psu0@58
        ├── channel 1 → child adapter i2c-21 → psu1@58
        └── channel 2 → child adapter i2c-22 → riser@50
```

DTS 範本：

```dts
&i2c6 {
    status = "okay";

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

Mux debug 重點：

- 先確認 parent adapter 可用，再確認 mux client 是否 probe，再確認 child adapter 是否建立。
- 若 child adapter 不存在，後面的 PSU / sensor driver 不會 probe。
- `i2c-mux-idle-disconnect` 可降低 channel 互相干擾，但會增加 select / deselect 行為，需要看裝置是否能接受。
- Multi-level mux 需保存完整 path，不要只寫最後 bus number。
- 若 mux select 需要 I2C transfer，需注意 locking、nested transfer、timeout 與 deadlock 風險。

Mux 檢查：

```bash
i2cdetect -l
ls -l /sys/bus/i2c/devices | grep -E 'i2c-|0070|0071'
dmesg | grep -Ei 'i2c.*mux|pca954|pca954x|mux'
```

#### 10.5 PMBus Driver Framework

PMBus 是用於 power converter / PSU / VR / HSC 的 power-management protocol，通常跑在 SMBus / I2C 上。Linux PMBus driver 位於 hwmon subsystem 下，常見架構為 PMBus core、generic PMBus driver、device-specific PMBus driver。Kernel PMBus 文件說明 generic PMBus driver 支援電壓、電流、功率、溫度等 hwmon 監控資料，但 PMBus device 不會被 PMBus driver 安全地自動探測，通常需要明確建立 device；PMBus core 文件也提醒：PMBus command 雖標準化，但沒有每顆裝置都必需支援的命令，且 unsupported command 的反應可能從錯誤、回 0xff/0xffff、設 status bit 到 bus hang 都可能發生。

```text
I2C client：bus + address + driver name
    ↓
pmbus generic driver 或 vendor-specific driver
    ↓
pmbus_core：page / command / format / status / hwmon registration
    ↓
/sys/class/hwmon/hwmonX
    ↓
OpenBMC psusensor / dbus-sensors
```

PMBus driver 類型：


| Driver 類型 | 用途 | 優點 | 風險 |
| --- | --- | --- | --- |
| generic `pmbus` | 標準 PMBus command 足夠時 | 導入快 | page / format / status / quirk 可能不足 |
| vendor-specific driver | 晶片已有 upstream driver，例如 adm1275、ltc2978、ina233、ir35221 | 支援較完整 | 需確認 kernel 版本與 device ID |
| custom driver | 需要 MFR command、特殊 coefficient、初始化、fault mapping | 可正確處理平台需求 | 需維護與 upstream 對齊 |
| userspace direct I2C | 短期 debug 或 vendor tool | 快速驗證 register | 不宜與 kernel driver 同時存取同 address |


PMBus 必填資料：


| 項目 | 內容 | 來源 |
| --- | --- | --- |
| Device type | PSU / VR / HSC / power monitor | schematic、BOM |
| Bus path | root bus、mux address、channel | DTS、i2cdetect -l |
| Address | 7-bit PMBus address | schematic、strap、datasheet |
| Driver | generic pmbus 或 chip-specific | kernel docs、driver source |
| Pages | rail / output channel 數量 | datasheet、driver info |
| Format | LINEAR11 / LINEAR16 / DIRECT / VOUT_MODE | datasheet、driver implementation |
| Status command | STATUS_WORD、STATUS_VOUT、STATUS_IOUT 等 | PMBus spec、datasheet |
| Fault clear | CLEAR_FAULTS 是否允許、何時清 | power policy、vendor guide |


#### 10.6 PMBus Sensor Mapping

PMBus driver probe 後，資料通常出現在 hwmon。OpenBMC 再透過 psusensor / dbus-sensors / Entity Manager config，把 hwmon channel 轉成 D-Bus sensor、Redfish Power / Thermal / Sensor 與 IPMI SDR。

```text
PMBus command
  READ_VIN / READ_VOUT / READ_IIN / READ_IOUT / READ_PIN / READ_POUT / READ_TEMPERATURE_*
    ↓
PMBus driver / pmbus_core
    ↓
hwmon sysfs
  in*_input、curr*_input、power*_input、temp*_input、fan*_input、*_label、*_alarm、*_fault
    ↓
OpenBMC sensor daemon
    ↓
D-Bus sensor path
  /xyz/openbmc_project/sensors/voltage/...
  /xyz/openbmc_project/sensors/current/...
  /xyz/openbmc_project/sensors/power/...
  /xyz/openbmc_project/sensors/temperature/...
    ↓
Redfish / IPMI / EventLog / Telemetry
```

常見 hwmon 對映：


| PMBus command | hwmon 類型 | OpenBMC sensor type | 常見 Redfish 位置 | 注意事項 |
| --- | --- | --- | --- | --- |
| READ_VIN | `in*_input` | voltage | PowerSupply / Sensor | input voltage，不是 output rail |
| READ_VOUT | `in*_input` | voltage | Voltage sensor / rail | 需依 page 對應 rail |
| READ_IIN | `curr*_input` | current | PowerSupply input | input current |
| READ_IOUT | `curr*_input` | current | Rail / PSU output | page / phase 需分清楚 |
| READ_PIN | `power*_input` | power | PowerSupply input power | 單位通常為 microwatt |
| READ_POUT | `power*_input` | power | PSU output / rail power | 不可和 PIN 混用 |
| READ_TEMPERATURE_* | `temp*_input` | temperature | Thermal / Sensor | 需知道 sensor 位置 |
| READ_FAN_SPEED_* | `fan*_input` | fan_tach | Thermal / Fan | 不是每顆 PMBus 裝置支援 |


Mapping 注意事項：

- 不要依賴 `hwmonX` 固定；要用 `name`、`label`、device path、bus/address 或 Entity Manager config 對映。
- Page 代表 rail / output channel；phase 代表多相 VR 的 phase。總電流和 phase 電流需分清楚。
- Input power、output power、rail power、system power 是不同語意，不應用同一 sensor name。
- Sensor threshold 要依平台 power spec 設定，不能只沿用 reference board。
- PSU absent 或 PMBus timeout 時，sensor 應標 unavailable / functional false，而不是用 0 當作正常讀值。

Hwmon dump：

```bash
for h in /sys/class/hwmon/hwmon*; do
    echo "==== $h"
    cat "$h/name" 2>/dev/null
    grep -H . "$h"/*_input "$h"/*_label "$h"/*_alarm "$h"/*_fault 2>/dev/null
done
```

#### 10.7 PMBus Debug

PMBus debug 需分層，不建議一開始就用 `i2cget` 任意讀寫 command。部分 PMBus 裝置對 unsupported command 反應不一致，可能設 fault bit 或造成 bus hang。第一輪應優先使用 kernel driver 已暴露的 hwmon、driver log、PMBus status snapshot 與 vendor guide 中明確安全的 read command。

Debug 順序：

1. 確認 physical：power domain、presence、pull-up、SDA/SCL waveform、mux channel。
2. 確認 I2C：adapter 存在、address ACK、沒有 address conflict、沒有 bus stuck。
3. 確認 client：DTS / new_device / driver binding 是否建立。
4. 確認 PMBus driver：generic 或 vendor-specific 是否 probe，hwmon 是否出現。
5. 確認 sensor mapping：hwmon channel、label、page、unit、scale。
6. 確認 status：STATUS_WORD、STATUS_*、MFR_STATUS snapshot。
7. 確認 OpenBMC：D-Bus sensor、availability、functional、threshold、event。
8. 最後才看 raw PMBus command 與 vendor-specific register。

常用指令：

```bash
# I2C topology
i2cdetect -l
ls -l /sys/bus/i2c/devices

# PMBus / hwmon
dmesg | grep -Ei 'pmbus|hwmon|psu|vr|ina|adm|ltc|ir|isl|mps|tps|timeout|nack'
find /sys/class/hwmon -maxdepth 3 -type f -print | sort

# driver binding
readlink /sys/bus/i2c/devices/<bus>-00<addr>/driver 2>/dev/null
cat /sys/bus/i2c/devices/<bus>-00<addr>/name 2>/dev/null

# OpenBMC
busctl tree xyz.openbmc_project.PSUSensor 2>/dev/null
busctl tree xyz.openbmc_project.ObjectMapper | grep -i sensors
journalctl -u xyz.openbmc_project.PSUSensor.service -b --no-pager 2>/dev/null
journalctl -b --no-pager | grep -Ei 'pmbus|psu|sensor|timeout|unavailable|functional'
```

若需要 raw PMBus 讀取，建議建立 approved command list：


| Command | 用途 | 是否安全讀取 | 備註 |
| --- | --- | --- | --- |
| STATUS_WORD | 總 fault 狀態 | [待填] | 先保存再 clear |
| STATUS_INPUT | input fault | [待填] | PSU AC lost / UV / OV |
| STATUS_VOUT | output voltage fault | [待填] | page dependent |
| STATUS_IOUT | output current fault | [待填] | page / phase dependent |
| STATUS_TEMPERATURE | temperature fault | [待填] | 需對應 temp sensor |
| READ_VIN / VOUT | voltage telemetry | [待填] | format 需確認 |
| READ_IIN / IOUT | current telemetry | [待填] | scale / shunt / coefficient |
| READ_PIN / POUT | power telemetry | [待填] | input / output 不可混用 |
| CLEAR_FAULTS | 清除 latched fault | 需審核 | 清除前需保存 snapshot |


#### 10.8 Device Tree 與 OpenBMC config 邊界

I2C / PMBus framework 容易把 DTS、Entity Manager JSON、dbus-sensors config 混在一起。建議分工如下：


| 資料 | 建議放置位置 | 原因 |
| --- | --- | --- |
| SoC I2C controller enable | DTS | 硬體 controller 與 pinmux |
| I2C mux / fixed child devices | DTS | kernel 需建立 adapter / client |
| GPIO reset / interrupt / supply | DTS | driver probe dependency |
| PSU / VR sensor name | Entity Manager / dbus-sensors config | 產品命名與 Redfish / IPMI policy |
| Sensor threshold | Entity Manager / policy config | 依平台規格變動 |
| Presence gating | Inventory / Entity Manager / platform daemon | 依 slot / hot-plug / power state |
| PMBus quirk / format | kernel vendor driver | 屬於 device-specific 行為 |


#### 10.9 Target 端 I2C / PMBus Framework log 收集

```bash
mkdir -p /tmp/i2c-pmbus-framework-debug
cat /etc/os-release > /tmp/i2c-pmbus-framework-debug/os-release.txt
uname -a > /tmp/i2c-pmbus-framework-debug/uname.txt
cat /proc/cmdline > /tmp/i2c-pmbus-framework-debug/proc-cmdline.txt
zcat /proc/config.gz > /tmp/i2c-pmbus-framework-debug/proc-config.txt 2>&1

dmesg -T > /tmp/i2c-pmbus-framework-debug/dmesg.txt
journalctl -b --no-pager > /tmp/i2c-pmbus-framework-debug/journal.txt
systemctl --failed > /tmp/i2c-pmbus-framework-debug/systemctl-failed.txt 2>&1

# I2C adapter / client / mux topology
i2cdetect -l > /tmp/i2c-pmbus-framework-debug/i2cdetect-l.txt 2>&1
ls -l /sys/bus/i2c/devices > /tmp/i2c-pmbus-framework-debug/sys-bus-i2c-devices.txt 2>&1
find /sys/bus/i2c/devices -maxdepth 3 -print > /tmp/i2c-pmbus-framework-debug/i2c-tree.txt 2>&1
find /sys/bus/i2c/drivers -maxdepth 2 -print > /tmp/i2c-pmbus-framework-debug/i2c-drivers.txt 2>&1

# hwmon / PMBus
find /sys/class/hwmon -maxdepth 3 -type f -print > /tmp/i2c-pmbus-framework-debug/hwmon-files.txt 2>&1
for h in /sys/class/hwmon/hwmon*; do
    b=$(basename "$h")
    mkdir -p "/tmp/i2c-pmbus-framework-debug/$b"
    cp -a "$h"/* "/tmp/i2c-pmbus-framework-debug/$b/" 2>/dev/null || true
done

# OpenBMC sensors
busctl tree xyz.openbmc_project.ObjectMapper > /tmp/i2c-pmbus-framework-debug/objectmapper.txt 2>&1
busctl tree xyz.openbmc_project.PSUSensor > /tmp/i2c-pmbus-framework-debug/psusensor-tree.txt 2>&1 || true
busctl tree xyz.openbmc_project.HwmonTempSensor > /tmp/i2c-pmbus-framework-debug/hwmontempsensor-tree.txt 2>&1 || true
journalctl -u xyz.openbmc_project.PSUSensor.service -b --no-pager > /tmp/i2c-pmbus-framework-debug/psusensor-journal.txt 2>&1 || true
journalctl -u xyz.openbmc_project.EntityManager.service -b --no-pager > /tmp/i2c-pmbus-framework-debug/entity-manager-journal.txt 2>&1 || true

tar czf /tmp/i2c-pmbus-framework-debug-$(date +%Y%m%d-%H%M%S).tar.gz -C /tmp i2c-pmbus-framework-debug
```

#### 10.10 常見問題與排查入口


| 現象 | 可能方向 | 第一輪檢查 |
| --- | --- | --- |
| `i2cdetect -l` 沒有 root bus | DTS controller disabled、pinctrl / clock / reset / kernel config | DTS、dmesg、clk_summary、devices_deferred |
| Mux 後 child bus 不存在 | mux client 未 probe、compatible 錯、parent bus fail | dmesg、/sys/bus/i2c/devices、mux address ACK |
| Address 掃不到 ACK | 7-bit address 錯、power off、reset asserted、mux channel 錯、bus stuck | schematic、scope、i2cdetect、presence |
| Address 顯示 `UU` | kernel driver 已佔用 | driver symlink、hwmon output |
| PMBus driver 不 probe | client 未建立、driver name 不符、generic 不適用、kernel config 缺 | DTS / new_device、dmesg、/proc/config.gz |
| hwmon 有值但 OpenBMC 沒 sensor | Entity Manager config、label、PowerState、service 問題 | journal、busctl、config JSON |
| PMBus 數值比例錯 | LINEAR / DIRECT / VOUT_MODE、coefficient、shunt resistor 錯 | driver docs、raw register、datasheet |
| PSU absent 時報 critical | presence gating 缺、read failure 被當超界 | presence GPIO、Availability、Functional |
| Bus 偶發 timeout | clock stretching、bus capacitance、hot-plug、multi-master | LA waveform、dmesg、bus speed 降低測試 |
| Clear fault 後無法分析 | 未保存 STATUS snapshot | 調整 debug / event flow |


#### 10.11 Bring-up 建議流程

- 先建立 physical I2C topology：root adapter、mux、channel、address、pull-up、power domain、owner。
- 在 DTS 啟用 root adapter 與固定 mux，確認 `i2cdetect -l` 有 root bus 與 mux child adapters。
- 逐一建立 client device，確認 7-bit address、driver binding 與 sysfs device path。
- 對 PMBus 裝置先選 driver：generic、vendor-specific 或 custom。
- 確認 PMBus page、phase、format、status command 與 fault clear policy。
- 驗證 hwmon channel，建立 PMBus command → hwmon file → OpenBMC sensor name 對照表。
- 補 Entity Manager / dbus-sensors config，確認 D-Bus、Redfish、IPMI 呈現一致。
- 做 PSU absent、AC lost、VR fault、bus stuck、mux reset、service restart、BMC reboot 測試。
- 保存 i2c-pmbus-framework-debug、scope / LA waveform、PMBus status snapshot 與版本資訊。

#### 10.12 當前平台 I2C / PMBus Framework 實測表


| 項目 | 來源 / 指令 | 實測值 | 備註 |
| --- | --- | --- | --- |
| I2C root adapters | i2cdetect -l / DTS | [待填] | physical bus 對照 |
| I2C mux tree | /sys/bus/i2c/devices | [待填] | parent / child adapter |
| PMBus clients | /sys/bus/i2c/devices | [待填] | bus-address-driver |
| PMBus driver type | driver symlink / kernel config | [待填] | generic / vendor / custom |
| PMBus pages | datasheet / driver / debug | [待填] | rail mapping |
| PMBus format | datasheet / driver | [待填] | LINEAR / DIRECT / VOUT_MODE |
| hwmon mapping | /sys/class/hwmon | [待填] | input/output/rail |
| D-Bus mapping | busctl tree sensors | [待填] | sensor path |
| Redfish / IPMI mapping | curl / ipmitool | [待填] | Power / Sensor / SDR |
| Fault snapshot | STATUS_WORD / STATUS_* | [待填] | clear 前保存 |
| Bus recovery | timeout / stuck test | [待填] | recovery policy |


#### 10.13 回查結果

本章已依「I2C / PMBus Framework」角度回查並補齊下列銜接點：

- 第 5 章已有周邊匯流排通用知識，本章把 I2C adapter / client / mux / PMBus driver framework 獨立整理，供後續 sensor 章節引用。
- 第 8 章 Device Tree 已說明 I2C / mux 節點寫法，本章補上 DTS 進入 Linux I2C framework 後的 adapter / client / driver 對照。
- 第 9 章 Kernel Driver 已說明 driver model 與 deferred probe，本章補上 I2C-specific bus model、PMBus driver 與 hwmon mapping。
- 第 12 章 Sensor 抽象層與後續 Voltage / Current / Power / PSU Sensor 可引用本章的 PMBus sensor mapping，而不需要在每個 sensor 章節重複 bus framework。
- 第 15 章 Inventory / FRU / Asset 可引用本章處理 FRU EEPROM / PSU PMBus path 與 bus topology。
- 第 16 章 Logging / Event / Telemetry 可引用本章 PMBus fault snapshot 與 bus timeout event policy。

#### 10.14 驗收 Checklist

-  I2C root adapter、mux child adapter、physical path、logical bus number 已建立對照。
-  Client device 的 7-bit address、driver、power domain、presence source 已確認。
-  I2C mux parent / child adapter tree 與 schematic 一致。
-  不依賴不穩定的 bus number，或已驗證 bus number 在重開機 / 更新後穩定。
-  PMBus driver 選型已確認：generic、vendor-specific 或 custom。
-  PMBus page、phase、LINEAR / DIRECT / VOUT_MODE、status command 已驗證。
-  hwmon channel 與 PMBus command / rail / PSU slot 對映正確。
-  OpenBMC D-Bus sensor、Redfish、IPMI SDR 與 hwmon 對映一致。
-  PSU absent、PMBus timeout、bus stuck 不會被誤判為一般 threshold critical。
-  CLEAR_FAULTS 前會保存 STATUS_WORD / STATUS_* / MFR fault snapshot。
-  i2c-pmbus-framework-debug、waveform、PMBus status、service journal 已保存。

#### 10.15 本章參考資料

- Linux kernel documentation - I2C/SMBus Subsystem: [https://www.kernel.org/doc/html/latest/i2c/index.html](https://www.kernel.org/doc/html/latest/i2c/index.html)
- Linux kernel documentation - I2C muxes and complex topologies: [https://www.kernel.org/doc/html/v5.14/i2c/i2c-topology.html](https://www.kernel.org/doc/html/v5.14/i2c/i2c-topology.html)
- Linux kernel source - I2C mux framework: [https://github.com/torvalds/linux/blob/master/drivers/i2c/i2c-mux.c](https://github.com/torvalds/linux/blob/master/drivers/i2c/i2c-mux.c)
- Linux kernel documentation - PMBus driver: [https://docs.kernel.org/hwmon/pmbus.html](https://docs.kernel.org/hwmon/pmbus.html)
- Linux kernel documentation - PMBus core driver and internal API: [https://docs.kernel.org/hwmon/pmbus-core.html](https://docs.kernel.org/hwmon/pmbus-core.html)
- Linux kernel documentation - Hardware Monitoring: [https://www.kernel.org/doc/html/latest/hwmon/index.html](https://www.kernel.org/doc/html/latest/hwmon/index.html)
