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


| 角色 | 說明 | BMC 常見例子 | 檢查入口 |
| --- | --- | --- | --- |
| Bus | device 與 driver 的 match domain | platform、i2c、spi、pci、mdio、usb、mctp | /sys/bus、dmesg |
| Device | kernel 看到的硬體實體或 logical device | i2c-5/5-0048、spi0.0、platform device、eth0 | /sys/bus/*/devices |
| Driver | 支援一類 device 的 kernel driver | tmp75、pmbus、aspeed-gpio、aspeed-pwm-tacho | /sys/bus/*/drivers、lsmod |
| Probe | driver 對 device 初始化 | 讀 DT、request IRQ、enable clock、register hwmon | dmesg、dynamic debug、trace |
| Subsystem | driver 對 userspace 暴露的標準介面 | hwmon、iio、gpio、mtd、net、watchdog | /sys/class、debugfs |


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


| Resource | 常見 API / 來源 | probe 失敗常見現象 | 排查入口 |
| --- | --- | --- | --- |
| MMIO reg | platform resource、ioremap | driver probe fail、register read timeout | /proc/iomem、dmesg |
| I2C client | DT child node、new_device | device 不存在或 driver 不綁定 | /sys/bus/i2c/devices |
| SPI device | SPI child node、chip select | flash probe fail、JEDEC ID 錯 | dmesg spi-nor、/proc/mtd |
| Clock | clocks / clock-names | -EPROBE_DEFER、baud / bus speed 異常 | clk_summary、dmesg |
| Reset | resets / reset-names、reset-gpios | device timeout、link 不起 | debugfs reset、scope |
| Regulator | vdd-supply、regulator-fixed | supply not found、device 無 ACK | /sys/class/regulator、dmesg |
| GPIO | reset-gpios、enable-gpios、interrupt-gpios | GPIO busy、polarity 反相 | gpioinfo、debugfs gpio |
| IRQ | interrupts、interrupt-parent | 事件不觸發、IRQ storm | /proc/interrupts、dmesg |
| Pinctrl | pinctrl-0、pinctrl-names | bus 無波形、GPIO 不動 | pinctrl debugfs |


#### 9.3 Bus match：platform、I2C、SPI、PCI、MDIO

不同 bus 的 match key 不同。排查 driver 不 probe 時，先確認 device 是否存在，再確認 match key 是否正確。


| Bus | Device 來源 | Driver match key | BMC 常見例子 | 檢查入口 |
| --- | --- | --- | --- | --- |
| platform | DT SoC node / platform device | of_match_table compatible | GPIO、PWM、ADC、watchdog、LPC/eSPI | /sys/bus/platform/devices |
| I2C | DT child node / new_device / detection daemon | i2c_device_id、of_match_table | temperature sensor、EEPROM、PMBus、CPLD | /sys/bus/i2c/devices |
| SPI | DT child node / spi controller | of_match_table / spi id | SPI-NOR、SPI-NAND、TPM、ADC | /sys/bus/spi/devices |
| PCI | PCI enumeration | vendor / device ID、class code | NIC、GPU、accelerator、PCIe switch | lspci、/sys/bus/pci/devices |
| MDIO | MDIO scan 或 DT PHY node | PHY ID / compatible | Ethernet PHY | /sys/bus/mdio_bus/devices |
| USB | USB enumeration | VID / PID / class | USB gadget / host debug devices | lsusb、/sys/bus/usb/devices |


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


| Subsystem | 常見路徑 | BMC 用途 | 常見 consumer |
| --- | --- | --- | --- |
| hwmon | /sys/class/hwmon/hwmonX | temperature、voltage、current、power、fan RPM | dbus-sensors、psusensor、fansensor |
| IIO | /sys/bus/iio/devices/iio:deviceX | ADC raw value、scale、channel | adcsensor、iio-hwmon |
| GPIO | /dev/gpiochipX、gpioinfo | presence、reset、power enable、fault | gpio-monitor、Entity Manager、platform daemon |
| MTD | /proc/mtd、/dev/mtdX | flash partition、update、rwfs | update service、storage scripts |
| netdev | /sys/class/net、ip link | BMC network、NC-SI、RGMII | networkd、bmcweb、SSH |
| watchdog | /dev/watchdog、/sys/class/watchdog | BMC recovery | systemd、watchdog daemon |
| input | /dev/input/eventX | buttons、GPIO keys | button handler、power control |
| rtc | /sys/class/rtc/rtcX | timekeeping | systemd-timesyncd、time service |
| debugfs | /sys/kernel/debug | pinctrl、clk、gpio、tracing | debug only |


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


| Kernel interface | OpenBMC service | D-Bus 目標 | 常見問題 |
| --- | --- | --- | --- |
| hwmon | dbus-sensors、psusensor、hwmontempsensor | /xyz/openbmc_project/sensors/... | hwmon label / scale / config 不匹配 |
| IIO / iio-hwmon | adcsensor | voltage sensor | ADC channel / scale 不對 |
| GPIO | gpio presence、power control、intrusion | inventory / state / event | line name / polarity / busy |
| MTD / UBI | phosphor-bmc-code-mgmt、update scripts | software inventory | partition name 不一致 |
| watchdog | systemd watchdog、platform watchdog | state / event | reset 範圍與 timeout 不明 |
| netdev | systemd-networkd、phosphor-network | network config / Redfish EthernetInterface | link / MAC / DHCP / NC-SI |


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


| 現象 | 可能方向 | 第一輪檢查 |
| --- | --- | --- |
| driver 完全沒有 probe log | device 未建立、compatible 不匹配、kernel config 未開、module 未載入 | DTS、/sys/bus、dmesg、/proc/config.gz |
| probe 回傳 -EPROBE_DEFER | clock / regulator / reset / GPIO / pinctrl provider 未 ready | devices_deferred、dmesg、clk / regulator / gpio |
| I2C driver 沒綁定 | address 錯、DT node 缺、id_table 不匹配、device 已被其他 driver 綁定 | /sys/bus/i2c/devices、driver symlink、i2cdetect |
| hwmonX 每次不同 | hwmon index 動態分配 | 用 name / label / device path，不要寫死 hwmonX |
| sysfs 有值但 D-Bus 沒值 | OpenBMC config / service / label / power state gating 問題 | journal、busctl、Entity Manager config |
| GPIO busy | GPIO hog、driver consumer、另一個 daemon 已 request | gpioinfo consumer、debugfs gpio |
| IRQ storm | trigger type 錯、status 未 clear、level interrupt 仍 asserted | /proc/interrupts、scope、driver log |
| network link 不起 | PHY driver、MDIO、reset、clock、phy-mode | dmesg、ethtool、MDIO sysfs、scope |
| watchdog 非預期 reset | timeout 太短、feed service fail、reset target 不明 | journal previous boot、reset reason、watchdog sysfs |
| kernel oops | driver bug、error path、race、IRQ / workqueue 問題 | 完整 oops log、symbol、kernel commit |


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


| 項目 | 指令 / 來源 | 實測值 | 備註 |
| --- | --- | --- | --- |
| Kernel version | uname -a | [待填] | 需對應 kernel commit |
| Kernel config | zcat /proc/config.gz | [待填] | 關鍵 driver config |
| Boot driver log | dmesg -T | [待填] | 保存完整 log |
| Deferred probe | /sys/kernel/debug/devices_deferred | [待填] | 需逐項說明原因 |
| Platform devices | /sys/bus/platform/devices | [待填] | SoC controller |
| I2C devices | /sys/bus/i2c/devices | [待填] | sensor / FRU / PMBus |
| SPI devices | /sys/bus/spi/devices | [待填] | flash / TPM |
| hwmon mapping | /sys/class/hwmon | [待填] | 不要只記 hwmonX |
| IIO mapping | /sys/bus/iio/devices | [待填] | ADC channel |
| GPIO chips | gpioinfo | [待填] | line name / consumer |
| Clock summary | clk_summary | [待填] | key controller clock |
| Regulator state | /sys/class/regulator | [待填] | supply dependency |
| Watchdog | /sys/class/watchdog | [待填] | timeout / nowayout |
| Network driver | ip link / ethtool | [待填] | MAC / PHY / NC-SI |
| OpenBMC consumer | busctl / journal | [待填] | D-Bus object 對照 |


#### 9.15 回查結果

本章已回查前後文並補齊下列銜接點：

- 第 4 章 Reset / Clock / Power Domain 已描述 dependency，本章補上 probe、deferred probe 與 resource provider 排查。
- 第 5 章周邊匯流排已描述各 bus，本章補上 platform / I2C / SPI / PCI / MDIO driver match 與 sysfs 對照。
- 第 8 章 Device Tree 已描述 DTS，本章補上 DT node 如何進入 bus match / probe / subsystem interface。
- 第 10 章 I2C / PMBus 會依本章的 I2C driver、hwmon、deferred probe 方法進一步展開。
- 第 12 章 Sensor 抽象層會使用本章的 hwmon / IIO / GPIO interface 轉成 D-Bus sensor。
- 第 16 章 Logging / Event / Telemetry 可引用本章 panic、oops、driver log 與 kernel-driver-debug 套件。
- 第 27～28 章 Debug Methodology / Toolkit 可引用本章的 dynamic debug、ftrace、debugfs 與 log package。

#### 9.16 驗收 Checklist

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
