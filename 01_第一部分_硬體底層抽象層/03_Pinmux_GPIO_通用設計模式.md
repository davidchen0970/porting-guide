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
