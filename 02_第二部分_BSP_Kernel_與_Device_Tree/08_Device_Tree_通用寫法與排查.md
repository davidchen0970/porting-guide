### 8. Device Tree 通用寫法與排查

Device Tree（DT）是 Linux kernel 用來描述非自動枚舉硬體拓樸的資料結構。BMC 平台的 I2C 裝置、SPI flash、GPIO、pinctrl、PWM、tach、ADC、watchdog、reset controller、clock、regulator、MCTP endpoint、eSPI/LPC/KCS、NC-SI、USB gadget 等，多數都會在 DTS / DTSI / DTB 中留下硬體描述。DT 的重點不是把 board schematic 原封不動搬進 kernel，而是用對應 binding 描述「kernel driver 需要知道、且無法自行偵測」的資訊。

對 BMC porting 而言，Device Tree 是硬體設計、BSP、kernel driver、OpenBMC service 與現場排查之間的共同基準。若 DT 寫錯，常見現象不一定直接顯示為 DT error，而可能是 sensor 不出現、I2C bus 掃不到裝置、GPIO polarity 反相、fan PWM 無輸出、flash partition 錯位、kernel deferred probe、OpenBMC inventory 缺項、Redfish / IPMI 顯示不一致。因此本章把 DT 寫法、binding 檢查、BMC 常見節點範本、build / runtime 驗證、log 收集與驗收 checklist 放在同一個章節。

#### 8.1 Device Tree 在 BMC Porting 中的角色

DT 在 BMC bring-up 中主要回答下列問題：

- 這顆 board 使用哪一個 SoC、哪一份 SoC DTSI、哪一份 board DTS。
- 哪些 SoC controller 被啟用，例如 I2C、SPI、UART、MAC、PWM、tach、ADC、watchdog、eSPI、LPC、KCS。
- 每個 controller 的 pinmux、clock、reset、interrupt、DMA、bus speed、status 是否正確。
- 每個 bus 底下有哪些 child device，address / chip select / interrupt / reset / GPIO / supply 是否正確。
- flash partition、reserved-memory、chosen bootargs、aliases、gpio-line-names 是否與 U-Boot、Yocto image、OpenBMC service 對齊。
- 哪些設定屬於硬體描述，哪些應放在 Entity Manager JSON、systemd service、policy config 或 userspace 設定檔。


| 層級 | Device Tree 負責內容 | 不建議放在 Device Tree 的內容 | 排查入口 |
| --- | --- | --- | --- |
| SoC / Board | MMIO address、interrupt、clock、reset、pinctrl、controller status | 會依產品政策變動的 runtime policy | dtc、dmesg、/proc/device-tree |
| Bus / Device | I2C address、SPI chip select、reg、compatible、GPIO、supply、interrupt | sensor threshold、fan curve、FRU inventory policy | dmesg、i2cdetect、ls -l /sys/bus |
| Storage | MTD fixed-partitions、flash compatible、SPI mode | 更新策略、software inventory state | /proc/mtd、dmesg mtd/ubi |
| GPIO / Pinmux | gpio-line-names、pinctrl state、consumer GPIO polarity | 按鈕長按策略、LED pattern policy | gpioinfo、pinctrl debugfs |
| OpenBMC userspace | 提供 kernel device 與 line name 基礎 | Entity Manager probe rule、sensor scale / threshold、thermal policy | busctl、journalctl、systemctl |


建議分工原則：

- 「硬體接線與 SoC controller 能力」放在 DTS / DTSI。
- 「裝置是否存在、在哪個 bus address、需要哪條 reset / interrupt / GPIO」通常放在 DTS；若裝置為可插拔且由 FRU / GPIO presence 決定，需搭配 Entity Manager 或對應 daemon。
- 「sensor threshold、fan policy、SKU 差異、使用者可調設定」通常放在 OpenBMC config 或 userspace policy，不建議塞進 DTS。
- 「CPLD register map」若無通用 kernel driver，可先在 CPLD 章節與平台 service 文件記錄；若有 MFD / regmap driver，再用 DT 描述 bus / address / interrupt / child function。

#### 8.2 DTS / DTSI / DTB / Overlay 與檔案位置


| 名詞 | 說明 | BMC 常見用途 | 注意事項 |
| --- | --- | --- | --- |
| DTS | Device Tree Source，通常描述單一 board | board-specific controller enable、I2C device、GPIO line name、flash partition | board DTS 應盡量覆寫 / 啟用 SoC DTSI 既有節點，避免重複定義 SoC 內部 block |
| DTSI | DTS include file，通常描述 SoC、package、共用板階變體 | SoC base map、clock/reset/pinctrl controller、common board design | 共用 DTSI 改動會影響多個平台，送審前需確認影響範圍 |
| DTB | 編譯後 binary blob，bootloader 傳給 kernel | 實際開機使用的硬體描述 | 必須確認 running DTB 是本次 build 產物，不只看 source |
| DTBO / Overlay | 覆加在 base DTB 上的片段 | 少數 SKU、runtime expansion | BMC 量產平台若使用 overlay，需明確記錄套用順序與 bootloader 設定 |
| Binding | 某類硬體節點的格式規範 | 確認 compatible、required properties、child node 格式 | 寫 DTS 前先查 binding，避免自創 property |


OpenBMC / Yocto 平台常見來源位置：

```text
Linux kernel tree:
  arch/arm/boot/dts/aspeed/
  arch/arm/boot/dts/nuvoton/
  arch/arm64/boot/dts/
  Documentation/devicetree/bindings/

OpenBMC meta layer:
  meta-*/recipes-kernel/linux/linux-*.bbappend
  meta-*/recipes-kernel/linux/linux-*/<patch>.patch
  meta-*/conf/machine/<machine>.conf

Build output:
  tmp/work/<machine>-*/linux-*/<version>/git/arch/.../boot/dts/
  tmp/deploy/images/<machine>/*.dtb
  tmp/deploy/images/<machine>/fitImage 或 image package
```

Bring-up 時至少要確認三份內容是否一致：

1. `arch/.../boot/dts/<board>.dts`：source 是否為預期版本。
2. `tmp/deploy/images/<machine>/*.dtb`：build output 是否有更新。
3. `/sys/firmware/fdt` 或 `/proc/device-tree`：target 實際 running DTB 是否為新版本。

#### 8.3 Binding 優先原則與 DTS 寫作規則

寫 DTS 前先查 binding。DT binding 是 kernel driver 與硬體描述之間的契約，常見格式為 YAML schema，位置通常在 `Documentation/devicetree/bindings/`。若平台使用的 kernel 版本仍包含舊式 `.txt` binding，也需要以該 kernel tree 為準。

基本規則：

- `compatible` 必須能對上 driver 的 `of_match_table` 或 binding 允許的字串。
- `reg` 的 cell 數量由 parent bus 的 `#address-cells` 與 `#size-cells` 決定。
- node name 的 `@unit-address` 應與 `reg` 的第一個 address 對應；沒有 `reg` 時不應加 `@...`。
- `interrupts` / `interrupt-parent` / `interrupts-extended` 必須符合 interrupt controller binding。
- `clocks` / `clock-names`、`resets` / `reset-names`、`*-supply` 的名稱與順序需符合 driver 期待。
- GPIO consumer property 建議使用 `<function>-gpios`，例如 `reset-gpios`、`enable-gpios`、`presence-gpios`。
- GPIO polarity 要用 `GPIO_ACTIVE_LOW` / `GPIO_ACTIVE_HIGH`，並用實測電位驗證。
- I2C child node 的 `reg` 使用 7-bit address，不要把 8-bit address 或含 R/W bit 的值填入。
- `status = "okay";` 只能代表 kernel 可嘗試 probe，不代表硬體一定可用；仍需檢查 rail、reset、clock、pinmux。
- 不要把臨時 debug property 留在產品 DTS；若需要 debug knob，應放在 driver debugfs、module parameter 或平台設定中。

DTS coding style 建議：

- node name、property name 使用小寫、數字與 dash；label 使用小寫、數字與 underscore。
- unit address 使用小寫十六進位；除 bus 格式需要外，不加無意義前導零。
- 同一 bus 底下有 unit address 的 child node 依 address 排序。
- property 順序建議為：`compatible`、`reg`、`ranges`、common properties、vendor properties、`status`、child nodes。
- board DTS 中啟用 SoC controller 時，盡量使用 `&label { ... };` 覆寫現有節點。
- `status` 若預設即為 `"okay"`，可依專案風格省略；但 BMC porting 初期為了可讀性，常保留明確的 `status = "okay";`。

#### 8.4 `compatible`、`reg`、`ranges` 與 address cells

`compatible` 決定 driver matching 與 binding schema；`reg` 決定 device address；`#address-cells` / `#size-cells` 決定 child `reg` 的 cell 格式。這三者錯誤時，常見現象是 driver 不 probe、address 錯位、resource range 不正確，或 dtbs_check 出現 schema warning。


| Parent bus | 常見 cells | Child `reg` 意義 | 範例 |
| --- | --- | --- | --- |
| MMIO bus / SoC bus | `#address-cells = <1 or 2>`；`#size-cells = <1 or 2>` | MMIO base + size | `reg = <0x1e780000 0x1000>;` |
| I2C bus | `#address-cells = <1>`；`#size-cells = <0>` | 7-bit I2C address | `reg = <0x48>;` |
| SPI bus | `#address-cells = <1>`；`#size-cells = <0>` | chip select index | `reg = <0>;` |
| MDIO bus | `#address-cells = <1>`；`#size-cells = <0>` | PHY address | `reg = <1>;` |


```dts
&i2c5 {
    status = "okay";

    temperature-sensor@48 {
        compatible = "ti,tmp75";
        reg = <0x48>;
    };
};

&fmc {
    status = "okay";

    flash@0 {
        compatible = "jedec,spi-nor";
        reg = <0>;
        spi-max-frequency = <50000000>;
    };
};
```

排查重點：

- I2C datasheet 若列出 `0x90 / 0x91` 這類 8-bit address，DTS 應填 `0x48`。
- SPI flash 的 `reg = <0>;` 通常代表 CS0，不是 flash offset。
- 若 child node 有 `@xx` 但沒有 `reg`，dtc 可能出現 unit address warning。
- 若 `reg` cell 數量錯，dtc / dtbs_check 可能報錯，driver 也可能拿到錯誤 resource。

#### 8.5 Node status、disabled 預設與 board DTS 覆寫策略

SoC DTSI 通常會把 controller node 先定義好，並將 board 未必使用的 controller 設為 disabled。Board DTS 再依 schematic 啟用需要的 controller。

```dts
/* SoC DTSI */
i2c5: i2c-bus@1e78a200 {
    compatible = "aspeed,ast2600-i2c-bus";
    reg = <0x1e78a200 0x80>;
    interrupts = <GIC_SPI 115 IRQ_TYPE_LEVEL_HIGH>;
    status = "disabled";
};

/* Board DTS */
&i2c5 {
    status = "okay";

    eeprom@50 {
        compatible = "atmel,24c64";
        reg = <0x50>;
        pagesize = <32>;
    };
};
```

建議策略：

- Board DTS 中只啟用實際接線且已驗證 power / reset / pinmux 的 controller。
- 未接的 controller 保持 disabled，避免 driver probe 造成 timeout 或誤佔 pinmux。
- 若 controller 暫時 disabled 是因為硬體 rework、driver 未 ready 或安全政策，請在註解與本章實測表補上原因。
- 多 SKU 共用 DTSI 時，可建立 common DTSI，再由各 SKU DTS 覆寫 `status`、child device、gpio-line-names。

#### 8.6 Pinctrl、GPIO line name 與 consumer GPIO

Pinctrl 代表 pin 的功能選擇與電氣設定；GPIO node 代表 Linux GPIO controller；consumer GPIO property 代表某個 driver 使用哪條 GPIO。這三者不要混在一起判讀。

```dts
&pinctrl {
    pinctrl_i2c7_default: i2c7-default {
        function = "I2C7";
        groups = "I2C7";
    };
};

&i2c7 {
    status = "okay";
    pinctrl-names = "default";
    pinctrl-0 = <&pinctrl_i2c7_default>;
};

&gpio0 {
    gpio-line-names =
        /* A0-A7 */
        "pwrbtn-n", "pltrst-n", "host-pgood", "bios-wp-n",
        "psu0-present-n", "psu1-present-n", "fan0-present-n", "fan1-present-n";
};
```

Consumer GPIO 範本：

```dts
device@40 {
    compatible = "vendor,device";
    reg = <0x40>;
    reset-gpios = <&gpio0 12 GPIO_ACTIVE_LOW>;
    interrupt-parent = <&gpio0>;
    interrupts = <13 IRQ_TYPE_LEVEL_LOW>;
};
```

檢查重點：

- `gpio-line-names` 順序必須與 gpio controller line offset 完全一致。
- line name 是排查與 OpenBMC config 對齊用，不會自動建立 driver consumer。
- `GPIO_ACTIVE_LOW` 會影響 gpiod logical value；請同時記錄 physical level 與 logical state。
- 若同一 pin 被 pinctrl 設成 I2C / UART / PWM，就不能同時當一般 GPIO 使用。
- GPIO expander 上的 line name 也需要填，避免 target 上只看到 `P00`、`P01` 這類無語意名稱。

#### 8.7 Interrupt、IRQ type 與 event line

Interrupt 類訊號在 BMC 平台常用於 PMBus ALERT、GPIO expander INT、thermal alert、fault latch、中斷式 button / intrusion。DT 需描述 interrupt parent 與 trigger type，driver 仍需要讀取裝置 status 才能知道事件來源。

```dts
&i2c7 {
    gpio_expander0: gpio@20 {
        compatible = "nxp,pca9555";
        reg = <0x20>;
        gpio-controller;
        #gpio-cells = <2>;
        interrupt-parent = <&gpio0>;
        interrupts = <42 IRQ_TYPE_LEVEL_LOW>;
        gpio-line-names =
            "psu0-present-n", "psu1-present-n", "riser0-present-n", "riser1-present-n",
            "fanboard0-present-n", "fanboard1-present-n", "reserved-exp0-6", "reserved-exp0-7",
            "fault-led", "uid-led", "reserved-exp0-10", "reserved-exp0-11",
            "wp-enable", "mux-sel0", "mux-sel1", "expander-int-n";
    };
};
```

排查重點：

- active low line 通常不等於 edge falling；需依硬體與 driver 確認 `IRQ_TYPE_LEVEL_LOW`、`IRQ_TYPE_EDGE_FALLING` 等設定。
- level interrupt 若 source status 未清，可能造成 IRQ storm。
- shared interrupt 需確認每個裝置都能讀 status 並清除自己的事件。
- GPIO expander INT pin 的 supply / reset 依賴也要記錄；expander 掉電時 interrupt line 可能浮動。

#### 8.8 Clock、reset、regulator 與 power dependency

Driver probe 成功常需要四個條件同時成立：clock 可用、reset 已釋放、rail 穩定、pinmux 已套用。DT 只能描述 dependency 與參數，無法取代實機 timing 量測。

```dts
vdd_3v3_aux: regulator-vdd-3v3-aux {
    compatible = "regulator-fixed";
    regulator-name = "vdd_3v3_aux";
    regulator-min-microvolt = <3300000>;
    regulator-max-microvolt = <3300000>;
    regulator-always-on;
};

ethernet@1e660000 {
    compatible = "vendor,soc-mac";
    reg = <0x1e660000 0x1000>;
    clocks = <&syscon 42>;
    clock-names = "macclk";
    resets = <&rst 12>;
    reset-names = "mac";
    phy-mode = "rgmii-id";
    phy-handle = <&ethphy0>;
    status = "okay";
};

ethernet-phy@0 {
    reg = <0>;
    vdd-supply = <&vdd_3v3_aux>;
    reset-gpios = <&gpio0 46 GPIO_ACTIVE_LOW>;
    reset-assert-us = <10000>;
    reset-deassert-us = <30000>;
};
```

檢查重點：

- `clock-names` / `reset-names` 必須符合 driver 期待；名稱錯時可能出現 `failed to get clock` 或 `failed to get reset`。
- `*-supply` 名稱必須符合 binding；不是所有 driver 都會主動要求 regulator。
- fixed regulator 若由 GPIO 控制，需確認 active level、startup delay、boot-on / always-on 設定。
- BMC reboot 不應讓 host critical rail 掉電，除非產品政策明確如此。

#### 8.9 I2C / SMBus / PMBus 節點

BMC 的 sensor、FRU EEPROM、GPIO expander、MUX、PMBus PSU / VR、CPLD 常在 I2C / SMBus 上。DTS 與 Entity Manager 的邊界需要事先定義：固定存在且 driver 需要 kernel 管理的 device 可放 DTS；依 FRU / SKU / presence 動態建立的 sensor，常由 Entity Manager config 描述。

```dts
&i2c5 {
    status = "okay";
    bus-frequency = <100000>;

    eeprom@50 {
        compatible = "atmel,24c64";
        reg = <0x50>;
        pagesize = <32>;
    };

    temperature-sensor@48 {
        compatible = "ti,tmp75";
        reg = <0x48>;
    };
};
```

I2C mux 範本：

```dts
&i2c6 {
    status = "okay";

    i2c-mux@70 {
        compatible = "nxp,pca9548";
        reg = <0x70>;
        #address-cells = <1>;
        #size-cells = <0>;

        i2c@0 {
            reg = <0>;
            #address-cells = <1>;
            #size-cells = <0>;

            eeprom@50 {
                compatible = "atmel,24c02";
                reg = <0x50>;
            };
        };
    };
};
```


| 現象 | 可能方向 | 第一輪檢查 |
| --- | --- | --- |
| I2C 裝置完全沒有 ACK | address 錯、mux channel 錯、rail/reset 未 ready、pinmux 錯 | i2cdetect、scope SDA/SCL、pinctrl、power rail |
| driver 沒有 probe | compatible 不匹配、kernel config 未啟用、binding property 缺失 | dmesg、modinfo、grep of_match_table |
| mux 後 bus number 跟文件不同 | runtime bus number 依 probe 順序建立 | `i2cdetect -l`、/sys/bus/i2c/devices |
| PMBus sensor 值不出現 | kernel hwmon 與 dbus-sensors / Entity Manager 邊界未對齊 | /sys/class/hwmon、Entity Manager journal、D-Bus sensor tree |


#### 8.10 SPI、Flash 與 fixed-partitions

SPI flash 節點會影響 boot flash probe、/proc/mtd partition、software update target 與 recovery 流程。DTS fixed-partitions 必須與 U-Boot env、Yocto image layout、update service 完全對齊。

```dts
&fmc {
    status = "okay";

    flash@0 {
        compatible = "jedec,spi-nor";
        reg = <0>;
        spi-max-frequency = <50000000>;
        m25p,fast-read;
        label = "bmc";

        partitions {
            compatible = "fixed-partitions";
            #address-cells = <1>;
            #size-cells = <1>;

            u-boot@0 {
                label = "u-boot";
                reg = <0x00000000 0x00100000>;
                read-only;
            };

            u-boot-env@100000 {
                label = "u-boot-env";
                reg = <0x00100000 0x00020000>;
            };

            kernel@120000 {
                label = "kernel";
                reg = <0x00120000 0x00600000>;
            };

            rofs@720000 {
                label = "rofs";
                reg = <0x00720000 0x03200000>;
            };

            rwfs@3920000 {
                label = "rwfs";
                reg = <0x03920000 0x006e0000>;
            };
        };
    };
};
```

檢查重點：

- `label` 與 update service、/proc/mtd、U-Boot mtdparts 使用的名稱一致。
- `reg` offset / size 需對齊 erase block，且不可超出 flash 容量。
- 若 bootloader 使用不同 DTB 或內建 partition table，kernel 看到的 /proc/mtd 可能與 source DTS 不一致。
- SPI-NAND / raw NAND 若使用 UBI，需確認 ECC / bad block / ubinize 參數；DT 只處理 MTD partition，UBI volume table 另行管理。

#### 8.11 UART、console、chosen 與 aliases

早期 bring-up 需要穩定 UART console。DT 中的 `chosen` 與 `aliases` 會影響 console、stdout-path、I2C bus alias、MAC alias 等命名。

```dts
/ {
    aliases {
        serial4 = &uart5;
        i2c5 = &i2c5;
        ethernet0 = &mac0;
    };

    chosen {
        stdout-path = &uart5;
        bootargs = "console=ttyS4,115200n8 earlycon";
    };
};

&uart5 {
    status = "okay";
    pinctrl-names = "default";
    pinctrl-0 = <&pinctrl_uart5_default>;
};
```

注意事項：

- `stdout-path`、U-Boot `bootargs`、kernel config 的 console driver 需一致。
- 若 U-Boot 會動態修改 `/chosen/bootargs`，target 上需要讀 `/proc/cmdline` 而不是只看 DTS source。
- `aliases` 可影響 device numbering；若專案依賴固定 `i2c-N` 或 `ttySx`，需保存 running DT 與 dmesg。
- BMC 平台常有多個 UART：debug console、host SOL、MCU / CPLD UART，需避免 pinmux 與 alias 混淆。

#### 8.12 Ethernet、NC-SI、MDIO 與 PHY

BMC network DT 常牽涉 MAC controller、MDIO PHY、RGMII/RMII pinmux、NC-SI、PHY reset、clock source 與 NVMAC address 來源。網路不通時，不一定是 network service 問題，也可能是 DT 描述的 phy-mode、clock、reset 或 MDIO address 錯。

```dts
&mac0 {
    status = "okay";
    phy-mode = "rgmii-id";
    phy-handle = <&ethphy0>;
    pinctrl-names = "default";
    pinctrl-0 = <&pinctrl_rgmii1_default>;
};

&mdio0 {
    status = "okay";

    ethphy0: ethernet-phy@1 {
        reg = <1>;
        reset-gpios = <&gpio0 46 GPIO_ACTIVE_LOW>;
        reset-assert-us = <10000>;
        reset-deassert-us = <30000>;
    };
};
```

NC-SI 平台需額外確認：

- MAC node 是否設定為 NC-SI 模式所需 compatible / property。
- Sideband 連到哪一個 host NIC package / channel。
- Host NIC、PCH、main rail、RMII / RBT clock、reset timing 是否 ready。
- BMC network service 是否在 host off 狀態下仍重複報錯；若 NC-SI 依賴 host power，service 需有合理 retry / gating。

排查入口：

```bash
dmesg | grep -Ei 'eth|mac|mdio|phy|rgmii|rmii|ncsi|link'
ip link
ethtool eth0 2>/dev/null
cat /sys/class/net/eth0/carrier 2>/dev/null
find /sys/bus/mdio_bus/devices -maxdepth 2 -type f -print 2>/dev/null
```

#### 8.13 PWM / Tach / ADC / Watchdog / RTC 常見節點

BMC sensor 與 fan control 需要 PWM / tach / ADC 等 controller 先在 DT 中啟用，之後 kernel driver 才會提供 hwmon / sysfs / D-Bus service 的基礎。

```dts
&pwm_tacho {
    status = "okay";
    pinctrl-names = "default";
    pinctrl-0 = <&pinctrl_pwm0_default &pinctrl_tach0_default>;
};

&adc0 {
    status = "okay";
};

&wdt1 {
    status = "okay";
};

&i2c3 {
    status = "okay";

    rtc@51 {
        compatible = "nxp,pcf8563";
        reg = <0x51>;
    };
};
```

檢查重點：

- PWM 或 tach 無輸出 / 無讀值時，同時查 pinmux、clock、fan power、tach pull-up、driver consumer。
- ADC raw value 出現但 sensor 值不對，可能是分壓電阻、scale、offset、Entity Manager config 問題，不一定是 DT 問題。
- Watchdog 啟用前需確認 reset 範圍、timeout、systemd watchdog policy 與 bring-up 是否衝突。
- RTC 若在 host-off / standby 狀態無供電，I2C probe 可能失敗；需記錄 power domain。

#### 8.14 Reserved memory、memory node 與 bootargs

BMC 平台有時會保留記憶體給 framebuffer、video engine、host interface、crash dump、secure firmware 或 DMA buffer。Reserved memory 和 memory node 寫錯可能造成 kernel panic、driver DMA failure、video capture 異常或隨機 memory corruption。

```dts
/ {
    memory@80000000 {
        device_type = "memory";
        reg = <0x80000000 0x20000000>;
    };

    reserved-memory {
        #address-cells = <1>;
        #size-cells = <1>;
        ranges;

        video_engine_memory: framebuffer@9f000000 {
            reg = <0x9f000000 0x01000000>;
            no-map;
        };
    };
};
```

檢查重點：

- memory size 必須與 bootloader / DDR init 實際容量一致。
- reserved region 不可與 kernel、initramfs、CMA、其他 reserved-memory 重疊。
- 若 U-Boot 會修改 memory node 或 reserved-memory，需以 target running DT 為準。
- `no-map`、`reusable`、`shared-dma-pool` 等屬性需依 driver binding 使用。

#### 8.15 Build-time 驗證：dtc、dtbs、dtbs_check

建議將 DTS 修改分成三層檢查：語法、schema、實機。

```bash
# 在 kernel tree 內編譯所有或特定 DTB
make ARCH=arm dtbs
make ARCH=arm <vendor>/<board>.dtb

# 提高 dtc warning 等級
make ARCH=arm W=1 dtbs
make ARCH=arm W=2 dtbs

# 檢查 binding schema
make ARCH=arm dt_binding_check
make ARCH=arm dtbs_check

# 只檢查特定 binding 或特定 DTB，依 kernel 版本支援調整
make ARCH=arm CHECK_DTBS=y <vendor>/<board>.dtb
make ARCH=arm DT_SCHEMA_FILES=/gpio/ dtbs_check
```

Yocto / OpenBMC build 端常用檢查：

```bash
# 找到 kernel workdir
bitbake -e virtual/kernel | grep '^S='
bitbake -e virtual/kernel | grep '^B='

# 只編譯 kernel / device tree
bitbake virtual/kernel -c compile -f
bitbake virtual/kernel -c deploy

# 檢查 deploy DTB 是否更新
ls -lh tmp/deploy/images/${MACHINE}/*.dtb
strings tmp/deploy/images/${MACHINE}/*.dtb | head

# 若 kernel recipe 有獨立 dtbs task，依專案支援使用
bitbake virtual/kernel -c listtasks | grep -i dtb
```

建議保存：

- kernel commit、DTS patch commit、machine config commit。
- `make W=1 dtbs` / `dtbs_check` 的 log。
- `tmp/deploy/images/${MACHINE}` 中 DTB / fitImage / image package 的 timestamp 與 checksum。
- target running DTB 反編譯後的 `running.dts`。

#### 8.16 Target 端檢查與 running DTB 反編譯

Target 上排查時要先確認 kernel 實際收到的 DTB。Source 正確不代表 running DTB 正確，常見原因包含 bootloader 仍載入舊 DTB、FIT image 內 DTB 沒更新、A/B slot 用了另一份 image、U-Boot overlay 修改過 `/chosen` 或 memory node。

```bash
mkdir -p /tmp/dt-debug

# 讀 model / compatible / bootargs
tr '\0' '\n' < /proc/device-tree/model > /tmp/dt-debug/model.txt 2>&1
tr '\0' '\n' < /proc/device-tree/compatible > /tmp/dt-debug/compatible.txt 2>&1
cat /proc/cmdline > /tmp/dt-debug/proc-cmdline.txt

# 反編譯 running FDT
cp /sys/firmware/fdt /tmp/dt-debug/running.dtb 2>/dev/null
if command -v dtc >/dev/null 2>&1; then
    dtc -I dtb -O dts -o /tmp/dt-debug/running.dts /sys/firmware/fdt 2>/tmp/dt-debug/dtc-running.err
fi

# 檢查 device tree filesystem
find /proc/device-tree -maxdepth 3 -type f | sort > /tmp/dt-debug/proc-device-tree-files.txt

# kernel probe / deferred probe
cat /sys/kernel/debug/devices_deferred > /tmp/dt-debug/devices-deferred.txt 2>&1

dmesg -T > /tmp/dt-debug/dmesg.txt
journalctl -b --no-pager > /tmp/dt-debug/journal.txt
```

特定子系統檢查：

```bash
# I2C
ls -l /sys/bus/i2c/devices > /tmp/dt-debug/i2c-devices.txt 2>&1
i2cdetect -l > /tmp/dt-debug/i2c-bus-list.txt 2>&1

# GPIO / pinctrl
gpiodetect > /tmp/dt-debug/gpiodetect.txt 2>&1
gpioinfo > /tmp/dt-debug/gpioinfo.txt 2>&1
mount | grep debugfs || mount -t debugfs debugfs /sys/kernel/debug
cat /sys/kernel/debug/gpio > /tmp/dt-debug/debug-gpio.txt 2>&1
find /sys/kernel/debug/pinctrl -maxdepth 3 -type f -print > /tmp/dt-debug/pinctrl-files.txt 2>&1

# Clock / regulator / reset dependency
cat /sys/kernel/debug/clk/clk_summary > /tmp/dt-debug/clk-summary.txt 2>&1
find /sys/class/regulator -maxdepth 3 -type f -print -exec sh -c 'echo ==== $1; cat $1 2>/dev/null' _ {} \; > /tmp/dt-debug/regulator.txt 2>&1

# MTD / storage
cat /proc/mtd > /tmp/dt-debug/proc-mtd.txt 2>&1
cat /proc/partitions > /tmp/dt-debug/proc-partitions.txt 2>&1

tar czf /tmp/dt-debug-$(date +%Y%m%d-%H%M%S).tar.gz -C /tmp dt-debug
```

#### 8.17 常見問題與排查入口


| 現象 | 可能方向 | 第一輪檢查 |
| --- | --- | --- |
| 修改 DTS 後 target 沒變 | DTB 未 deploy、FIT image 未更新、bootloader 載入舊 slot | deploy timestamp、U-Boot boot log、/sys/firmware/fdt checksum |
| `compatible` 正確但 driver 未 probe | kernel config 未開、status disabled、binding 必填 property 缺、driver built as module 未載入 | dmesg、zcat /proc/config.gz、lsmod、/proc/device-tree node |
| I2C device 不出現 | 7-bit address 錯、mux channel 錯、pinmux / pull-up / rail / reset 問題 | i2cdetect、scope、pinctrl、DTS child node |
| GPIO line name 錯位 | gpio-line-names 順序錯、bank offset 理解錯、running DTB 舊 | gpioinfo、/proc/device-tree、DTS bank 對照 |
| presence / fault 反相 | GPIO_ACTIVE_LOW / userspace logical value / physical level 混淆 | scope、gpioget、gpioinfo active-low、OpenBMC config |
| driver deferred probe | clock / regulator / reset provider 未 ready 或 phandle 錯 | /sys/kernel/debug/devices_deferred、dmesg、clk_summary、regulator |
| flash partition 不符合預期 | DTS fixed-partitions、U-Boot mtdparts、bootloader partition table 不一致 | /proc/mtd、/proc/cmdline、running.dts、U-Boot env |
| UART console 不見 | stdout-path、bootargs、pinmux、clock、baud rate 不一致 | U-Boot env、/proc/cmdline、pinctrl、scope UART TX |
| MAC link 不起 | phy-mode、MDIO address、PHY reset / clock / rail、NC-SI dependency | dmesg、MDIO sysfs、scope REFCLK、ethtool |
| dtbs_check 出現 unrelated warnings | kernel tree 既有平台 warning、schema 版本差異 | 先限縮到特定 DTB / binding，再比對本次 patch 新增 warning |
| OpenBMC inventory 缺裝置 | kernel device 未 probe、Entity Manager Probe 不匹配、presence source 不一致 | D-Bus tree、journal、/sys/bus devices、GPIO presence |


#### 8.18 Bring-up 建議流程

- 先確認 SoC DTSI、board DTS、machine config、kernel recipe 使用的是同一個平台名稱。
- 從 boot-critical device 開始：UART、boot flash、DDR memory node、watchdog、reset reason、MAC / NC-SI。
- 逐條啟用 bus controller：I2C、SPI、PWM/tach、ADC、eSPI/LPC/KCS、USB gadget；每次啟用後保存 dmesg 與 `/sys/bus` 狀態。
- 建立 schematic net → DTS node → Linux device → OpenBMC object 對照表。
- 對每個 I2C / SPI child 填 `compatible`、`reg`、driver、kernel config、power dependency、owner。
- 對每條 GPIO 填 line name、offset、active level、physical level、logical state、consumer。
- 對 flash partition 核對 DTS、U-Boot mtdparts、Yocto image layout、update service。
- 每次 DTS patch 都跑 dtc / dtbs / dtbs_check，至少確認沒有本次新增的 warning。
- 每次更新 image 後從 target 反編譯 running DTB，確認實際內容已更新。
- 將 DT debug log、UART log、dmesg、journal、bus scan、gpioinfo、pinctrl、clk_summary 一起保存。

#### 8.19 當前平台 Device Tree 實測表


| 項目 | 指令 / 來源 | 實測值 | 備註 |
| --- | --- | --- | --- |
| Board DTS 檔名 | kernel tree / machine config | [待填] | 需對應 MACHINE |
| SoC DTSI | #include / git grep | [待填] | SoC revision / package 差異 |
| DTB build output | tmp/deploy/images/${MACHINE} | [待填] | 記錄 checksum |
| Running model | cat /proc/device-tree/model | [待填] | target 實際值 |
| Running compatible | tr '\0' '\n' < /proc/device-tree/compatible | [待填] | 需含 board 與 SoC compatible |
| Kernel bootargs | cat /proc/cmdline | [待填] | chosen / U-Boot 最終結果 |
| I2C bus list | i2cdetect -l | [待填] | mux 後 bus number 需保存 |
| GPIO line names | gpioinfo | [待填] | 與 schematic 對照 |
| Flash partitions | cat /proc/mtd | [待填] | 需與第 2 章一致 |
| Deferred probe | cat /sys/kernel/debug/devices_deferred | [待填] | 需說明每一項原因 |
| Pinctrl 狀態 | /sys/kernel/debug/pinctrl | [待填] | 關鍵 pinmux 必填 |
| Clock summary | /sys/kernel/debug/clk/clk_summary | [待填] | 關鍵 controller clock 必填 |
| Regulator 狀態 | /sys/class/regulator | [待填] | 若 DTS 有 supply 必填 |
| OpenBMC object 對照 | busctl tree | [待填] | inventory / sensor / network |


#### 8.20 回查結果

本章已回頭檢查前後文，並補齊下列銜接點：

- 第 2 章 Flash / Storage 已有 partition 與 update 流程，本章補上 DTS fixed-partitions 與 `/proc/mtd` 對齊方式。
- 第 3 章 Pinmux / GPIO 已有 GPIO line、active level、OpenBMC presence，本章補上 DT 中 pinctrl、gpio-line-names 與 consumer GPIO 寫法。
- 第 4 章 Reset / Clock / Power Domain 已有 dependency 與 timing，本章補上 `clocks`、`resets`、`*-supply` 與 deferred probe 的檢查入口。
- 第 5 章周邊匯流排已涵蓋 I2C / SPI / UART / NC-SI 等 bus，本章補上各 bus 在 DTS 中的常見節點與 runtime 驗證。
- 第 7 章 Build System 已涵蓋 Yocto / kernel build，本章補上 `virtual/kernel`、DTB deploy、`dtbs_check` 與 running DTB 反編譯流程。

#### 8.21 驗收 Checklist

-  Board DTS、SoC DTSI、MACHINE、kernel recipe、deploy DTB 已確認對應同一平台。
-  DTS 修改後已確認 DTB / FIT image / update package 重新產出。
-  Target running DTB 已反編譯並與 source patch 比對。
-  `compatible`、`reg`、`#address-cells`、`#size-cells` 已依 binding 檢查。
-  I2C device address 已確認為 7-bit address，mux channel 與 runtime bus number 已記錄。
-  SPI flash partition 與 U-Boot mtdparts、Yocto image layout、update service 一致。
-  GPIO line name、active level、physical level、logical state 已實測。
-  pinctrl state 已確認，沒有互斥功能共用同一 pin。
-  interrupt parent、IRQ type、clear rule、debounce / latch policy 已確認。
-  clocks / resets / supplies 與 driver binding 一致，沒有未解釋的 deferred probe。
-  UART console、chosen bootargs、aliases、stdout-path 與實際 console 對齊。
-  MAC / PHY / NC-SI mode、MDIO address、reset / clock / rail 已驗證。
-  PWM / tach / ADC / watchdog / RTC controller 已依平台需求啟用並驗證 sysfs / D-Bus。
-  reserved-memory 與 memory node 無重疊，容量與 DDR init / bootloader 一致。
-  dtc W=1 / W=2 與 dtbs_check 已保存 log，新增 warning 已處理或記錄原因。
-  DT debug log 套件、UART、dmesg、journal、gpioinfo、pinctrl、clk_summary 已保存。

#### 8.22 本章參考資料

- Linux kernel documentation - Linux and the Devicetree: [https://www.kernel.org/doc/html/latest/devicetree/usage-model.html](https://www.kernel.org/doc/html/latest/devicetree/usage-model.html)
- Linux kernel documentation - Open Firmware and Devicetree index: [https://docs.kernel.org/devicetree/index.html](https://docs.kernel.org/devicetree/index.html)
- Devicetree Specification: [https://www.devicetree.org/specifications/](https://www.devicetree.org/specifications/)
- Devicetree Specification basics: [https://devicetree-specification.readthedocs.io/en/stable/devicetree-basics.html](https://devicetree-specification.readthedocs.io/en/stable/devicetree-basics.html)
- Linux kernel documentation - DTS coding style: [https://docs.kernel.org/devicetree/bindings/dts-coding-style.html](https://docs.kernel.org/devicetree/bindings/dts-coding-style.html)
- Linux kernel documentation - Writing Devicetree Bindings in json-schema: [https://www.kernel.org/doc/html/latest/devicetree/bindings/writing-schema.html](https://www.kernel.org/doc/html/latest/devicetree/bindings/writing-schema.html)
- Devicetree schema tools: [https://github.com/devicetree-org/dt-schema](https://github.com/devicetree-org/dt-schema)
