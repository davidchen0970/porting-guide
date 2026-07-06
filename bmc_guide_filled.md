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
| 2026-07-06 |  0.2 | Copilot | 撰寫 Yocto 章節 |
| 2026-07-06 |  0.3 | Copilot | 撰寫常用變數、目錄結構與 BitBake 建構流程 |
| 2026-07-06 |  0.4 | Copilot | 撰寫在 Docker 中建立 Yocto 專案並建置完整映像 |
| 2026-07-06 |  0.5 | Copilot | 撰寫單獨建置與除錯特定套件章節 |
| 2026-07-06 |  0.6 | Copilot | 撰寫使用 .bbappend 修改套件行為章節 |

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


### 7.1 Yocto 簡介

Yocto Project 是一個開源協作專案，用來幫助開發者建立針對特定硬體架構（target boards）的**自訂 Linux 作業系統**。在 BMC porting 情境中，Yocto 的價值是把 kernel、bootloader、rootfs、package、SDK、license 資訊與平台差異，放進一套可重現的建構流程中管理。

它處理了嵌入式 Linux 開發常見的幾個問題：硬體架構碎片化、軟體元件相依複雜、建構流程難以重現。Yocto 提供一套標準化工具鏈，讓開發者可以：

- 從原始碼建構 Linux 映像
- 精確控制要放入哪些套件
- 管理套件之間的相依關係
- 支援跨平台編譯，例如 ARM、x86、MIPS、RISC-V 等
- 長期維護產品生命週期
- 輸出 rootfs、kernel、bootloader、package feed、SDK 與 license / SBOM 相關資料

Yocto 由多個核心元件所組成，為了方便理解，可以用**人體**來類比：

| 名稱 | 解釋 | 類比 |
|---|---|---|
| **Poky** | Yocto 的參考發行版，整合 BitBake、OpenEmbedded-Core 與參考 metadata。 | 完整的人體樣本 |
| **BitBake** | 負責解析 metadata 並執行建構流程的任務引擎。 | 大腦（發號施令） |
| **OpenEmbedded** | 提供建構系統的核心架構與 metadata，例如 recipes、classes、configuration。 | 身體的骨架與器官 |

補充說明：

- Poky 是 Yocto Project 提供的「**參考用完整組合**」，它是一個可以實際建出映像的參考組合，但**不是唯一選項**。可以拿 Poky 來改，也可以依專案需求自行組合 BitBake、OE-Core 與各 layers。
- 近年的 Yocto 文件中，Poky 的角色更偏向參考與測試目標；新的工作流程也可使用個別 clone 的 `bitbake`、`openembedded-core`、`meta-yocto`，或使用 `bitbake-setup` 建立建構環境。`poky` 作為 DISTRO 設定仍然存在。
- OpenBMC 是另一個完整的「人體」，它**使用** Yocto / OpenEmbedded / BitBake 工具來建構 BMC 映像，但不要把 OpenBMC 和 Poky 混在一起看。

#### 7.1.1 Yocto Build Flow（簡化流程）

![](https://docs.yoctoproject.org/2.1/yocto-project-qs/figures/yocto-environment.png)

常見的 Yocto 架構圖資訊量很大，初學時可先用「從左到右」的流程理解：

1. **準備階段（Prepare）**
   - BitBake 開始運作，讀取四類設定：
     - **User Configuration**：例如 `build/conf/local.conf`
     - **Metadata**：各 layer 的 recipes、classes、conf
     - **Machine Configuration**：硬體設定，例如 `qemux86-64`、`ast2600-evb`、專案 machine
     - **Policy Configuration**：發行版政策，例如 `poky`、OpenBMC distro 設定
   - 這些設定決定「要建構什麼」以及「如何建構」。

2. **擷取與打補丁（Fetch / Patch）**
   - BitBake 根據 `SRC_URI` 變數，從 Git、HTTP、local file 或 mirror 取得原始碼，對應 task 通常是 `do_fetch`。
   - 接著將 patches 套用到原始碼上，對應 task 通常是 `do_patch`。

3. **配置、編譯與安裝（Configure / Compile / Install）**
   - 執行建構前設定，對應 `do_configure`，例如 Autotools、CMake、Meson 的設定階段。
   - 開始編譯，對應 `do_compile`。
   - 將編譯好的檔案安裝到暫存目的地，對應 `do_install`。
   - 不同 recipe 之間可能存在 build-time dependency，因此 BitBake 會依任務依賴圖排程。

4. **部署到 Sysroot 與打包（Populate Sysroot / Package）**
   - 將可供其他 recipe 使用的 headers、libraries、pkg-config files 等部署到 sysroot，對應 `do_populate_sysroot`。
   - 將安裝結果拆成多個 package，對應 `do_package`。

5. **產生安裝套件（Write RPM / DEB / IPK）**
   - 將 package 轉成目標平台可使用的格式，例如 RPM、DEB、IPK。
   - BMC 專案常見產出位置包含 `tmp/deploy/rpm/`、`tmp/deploy/ipk/` 或依 distro 設定而定的 package deploy 目錄。

6. **QA 檢查（QA Check）**
   - Yocto 在建構過程中會執行多種 QA 檢查，例如 metadata、runtime dependency、license、installed-vs-shipped、rpath、host contamination 等。
   - QA issue 不一定每次都會讓 build fail，實際行為會受 `WARN_QA`、`ERROR_QA`、distro policy 影響。

7. **套件供給（Package Feeds）**
   - 建出的 package 可作為 package feed，放在 `tmp/deploy/` 底下。
   - 若產品支援線上套件更新，可進一步規劃 package feed server；若是 BMC 韌體，多數情境仍以 image update 為主。

8. **產生映像與 SDK（Image / SDK Generation）**
   - BitBake 最後會依 image recipe 產生 rootfs 與可燒錄映像，例如 ext4、wic、ubi、mtd tar、squashfs 等。
   - 也可以產生 SDK 或 eSDK，供應用程式開發者使用。

#### 7.1.2 Poky

Poky 是 Yocto 的**參考發行版**（reference distribution）。白話文來說，它是一組「可以拿來建出參考 Linux 系統」的建構工具與 metadata 組合。它提供：

- OpenEmbedded 建構系統相關元件，例如 BitBake 與 OpenEmbedded-Core
- 一組參考 metadata，幫助開發者建立自訂發行版
- 參考 machine、image、distro 設定，用於學習、測試與驗證建構環境

傳統 Poky repository 的根目錄常見結構如下：

```text
poky/
├── bitbake/                     # BitBake 主程式（Python）
├── build/                       # 編譯輸出目錄（執行 oe-init-build-env 後產生）
├── contrib/                     # 貢獻者工具
├── meta/                        # OpenEmbedded-Core 的 metadata（recipes、classes、機器配置）
├── meta-poky/                   # Poky 參考發行版的額外 metadata
├── meta-selftest/               # 自我測試用的 recipes 與 append 檔
├── meta-skeleton/               # BSP 和 Kernel 開發的 recipes 範本
├── meta-yocto-bsp/              # Yocto 計畫的參考 BSP metadata
├── oe-init-build-env            # 設定編譯環境的腳本
└── scripts/                     # 輔助工具腳本
```

`build/` 資料夾是在執行 `source oe-init-build-env` 後建立的，裡面包含 `conf/`、暫存資料、sstate-cache，以及最終輸出的映像檔。

需要注意的是，Poky repository 的使用方式會隨 Yocto 版本演進而調整。若專案採用新版本 Yocto，建議先查該版本的官方文件，確認目前建議的環境建立方式。

#### 7.1.3 OpenEmbedded

OpenEmbedded 是一套**建構框架**，可視為前面類比中的「身體骨架與器官」。它主要由下列部分組成：

- **OE-Core（OpenEmbedded-Core）**：核心 metadata，包含基礎 recipes、classes 與 configuration。
- **BitBake**：建構引擎，負責排程與執行任務。
- **meta-openembedded**：社群維護的額外 recipes 集合，常見的 `meta-oe`、`meta-python`、`meta-networking` 等都在這個體系內。

OE-Core 是許多 OpenEmbedded 衍生系統共用的「標準骨架」。Yocto Project 與 OpenBMC 都大量使用 OE-Core 的模型。

常見檔案類型：

- **Recipe（`.bb`）**：描述如何下載、設定、編譯、安裝、打包某個軟體套件。
- **Append（`.bbappend`）**：在不直接修改原 recipe 的前提下，追加 patch、設定或安裝內容。
- **Class（`.bbclass`）**：定義共用建構邏輯，例如 `cmake.bbclass`、`meson.bbclass`、`systemd.bbclass`。
- **Configuration（`.conf`）**：定義 machine、distro、layer、local build policy 等設定。

#### 7.1.4 BitBake

BitBake 是一個**任務執行引擎**（task execution engine），主要用來解析與執行 Yocto / OpenEmbedded 專案中的 recipes。它的概念與 GNU Make 有些相似，但更適合處理大量套件、交叉編譯、任務依賴、快取與平行排程。

BitBake 的運作流程大致如下：

1. **解析基礎設定**：讀取 `bblayers.conf`、各 layer 的 `layer.conf`、`bitbake.conf`、`local.conf` 等。
2. **建立 BBFILES 清單**：根據 `BBFILES` 變數，找到所有 `.bb` 與 `.bbappend` 檔案。
3. **解析 Recipes 與 Classes**：將 metadata 載入並展開變數、繼承 class、套用 override。
4. **產生任務依賴圖**：根據 `DEPENDS`、`RDEPENDS`、task dependency 與 class logic，建立任務順序。
5. **執行任務**：依依賴順序平行執行 `do_fetch`、`do_unpack`、`do_patch`、`do_configure`、`do_compile`、`do_install`、`do_package`、`do_rootfs` 等任務。
6. **使用 cache 與 sstate**：若任務輸入未改變，可重用 shared state，降低重建時間。

使用 BitBake 的好處：

- 可以組出完整嵌入式 Linux 發行版
- 透過依賴圖管理套件與任務順序
- 可平行處理多個 recipe 與 task，加快建置速度
- 可透過 sstate-cache 改善重複建構時間
- 可把 build-time dependency 與 runtime dependency 分開描述

常用指令：

```bash
# 建立 image
bitbake core-image-minimal

# OpenBMC 常見 image target
bitbake obmc-phosphor-image

# 只跑特定 recipe 的某個 task
bitbake -c compile <recipe>
bitbake -c clean <recipe>
bitbake -c cleansstate <recipe>

# 查 recipe 使用的變數展開結果
bitbake -e <recipe> | less

# 查 layers
bitbake-layers show-layers
bitbake-layers show-recipes
bitbake-layers show-appends

# 產生 dependency graph
bitbake -g <target>
```

#### 7.1.5 Layer Model

Layer Model 是 Yocto 用來管理套件與客製化內容的核心機制，設計目標是**同時支援協作與客製化**。

白話文來說，Layer Model 就是**把肉一層一層疊起來**的起司蛋糕概念：

- **Layer 就是一層起司**：每一層包含一組相關 recipes 與設定。BSP、GUI、中介軟體、應用服務、公司共用政策都可以分開放。
- **重複 recipe 會依規則處理**：如果同一個 recipe 名稱出現在多個 layer 中，BitBake 會依 layer priority、version、`PREFERRED_VERSION` 等規則選擇。
- **`.bbappend` 可追加既有 recipe**：不修改原 recipe，也能增加 patch、service、config 或安裝檔案。
- **最終結果是疊合後的系統**：所有 layer 疊加後，BitBake 依優先權、override 與設定產出完整系統。
- **Layer 可以重複使用**：同一個 BSP layer、feature layer 或公司共用 layer 可在多個專案使用。
- **分層是為了降耦合**：更換硬體時替換 BSP layer，新增功能時加入 feature layer，量產政策放在 distro / product layer。

常見 layer 分層方式：

**第一種：由大到小、由廣泛到精細**

- 底層：OE-Core / 基礎系統
- 中層：BSP（板級支援套件）、SoC vendor layer、中介軟體
- 上層：發行版政策、產品設定、應用程式、OEM 客製化

**第二種：企業內部常見分層**

- **Root Layer**：由硬體製造商、SoC vendor 或 upstream 專案提供的基礎 layer，例如 OpenBMC 常用 layer。
- **Model Layer**：針對特定平台、板子、SKU 所設計的 layer。
- **Recipe Layer**：針對特定工具、服務、OEM 套件或公司共用元件所提供的 layer。

OpenBMC 常見 layer 類型：

```text
openbmc/
├── meta/                         # OE-Core / Yocto 相關基礎 layer
├── meta-openembedded/            # 社群 recipes，例如 meta-oe、meta-python、meta-networking
├── meta-phosphor/                # OpenBMC 核心服務與共用設定
├── meta-aspeed/                  # ASPEED SoC BSP
├── meta-nuvoton/                 # Nuvoton SoC BSP
├── meta-ibm/、meta-facebook/等    # vendor / platform layer
└── build/                        # 建構輸出
```

實務建議：

- 不要直接改 upstream layer，優先用專案 layer + `.bbappend` 管理差異。
- 平台相關設定放 machine layer；產品政策放 distro 或 product layer；應用程式放 application layer。
- Layer priority 不宜濫用，否則後續很難追蹤 recipe 來源。
- 每個 layer 應清楚定義相依 layer，寫在 `conf/layer.conf` 的 `LAYERDEPENDS`。

#### 7.1.6 OpenBMC 和 Yocto 的關係

重要澄清：OpenBMC **不是** Yocto 的競爭者，而是 Yocto 的**使用者**。

**Yocto Project** 是一個框架，用來建立各式各樣的嵌入式 Linux 系統。它提供工具、metadata 與建構基礎設施。

**OpenBMC** 則是一個專門為伺服器 BMC（Baseboard Management Controller）設計的韌體堆疊。它包含硬體監控、感測器管理、遠端電源控制、IPMI / Redfish 支援、軟體更新、事件紀錄等功能。

OpenBMC 本身使用 Yocto 工具來建構。OpenBMC 借用 BitBake、layer model、OpenEmbedded-Core 與大量 metadata，再疊加 BMC 專屬服務與平台設定。因此：

- Yocto / OpenEmbedded / BitBake：提供建構框架。
- OpenBMC：提供 BMC runtime 架構與服務集合。
- OpenBMC image：是 Yocto build system 建出的 BMC 韌體映像。

OpenBMC 常見建構流程：

```bash
# 進入 OpenBMC source tree
cd openbmc

# 設定 machine；不同專案 machine 名稱不同
. setup <machine_name>

# 開始建構 BMC image
bitbake obmc-phosphor-image

# 產出通常位於
ls tmp/deploy/images/<machine_name>/
```

#### 7.1.7 BMC Porting 時 Yocto 需要優先確認的檔案

| 項目 | 常見位置 | 用途 | Porting 注意事項 |
|---|---|---|---|
| Machine conf | `conf/machine/<machine>.conf` | 定義 MACHINE、SoC、kernel、UBoot、image type | 需對齊實際 board、flash type、SoC BSP |
| Layer conf | `conf/layer.conf` | 定義 BBFILES、LAYERDEPENDS、layer priority | 確認相依 layer 與 priority 是否合理 |
| Kernel recipe / bbappend | `recipes-kernel/linux/` | 指定 kernel source、defconfig、DTS、patch | DTS、driver patch、config fragment 是 bring-up 重點 |
| U-Boot recipe / bbappend | `recipes-bsp/u-boot/` | 指定 bootloader source、defconfig、env、patch | flash layout、bootcmd、secure boot、recovery 需同步 |
| Image recipe | `recipes-phosphor/images/` 或 product layer | 定義 rootfs 內容 | 確認需要的 service、tool、debug package 是否進 image |
| Packagegroup | `recipes-*/packagegroups/` | 集中管理套件集合 | 適合控管 feature 開關與產品差異 |
| Systemd service | `recipes-*/<pkg>/files/*.service` | 定義 daemon 啟動方式 | 需檢查 dependency、restart policy、boot time impact |
| Entity Manager / Sensor config | `recipes-phosphor/configuration/` 或平台 layer | 定義 inventory、sensor、FRU、presence | 需對齊 schematic、I2C bus map、Redfish/IPMI mapping |

#### 7.1.8 Yocto / OpenBMC 常見排查入口

```bash
# 確認目前 machine / distro / image 相關變數
bitbake -e obmc-phosphor-image | grep -E "^(MACHINE|DISTRO|IMAGE_FSTYPES|PREFERRED_PROVIDER|BBLAYERS)="

# 查某個 recipe 實際來源
bitbake-layers show-recipes <recipe>
bitbake-layers show-appends | grep <recipe>

# 進入 recipe 開發流程
bitbake -c devshell <recipe>

# 清掉某個 recipe 的 sstate 後重建
bitbake -c cleansstate <recipe>
bitbake <recipe>

# 只重跑 image rootfs
bitbake -c rootfs obmc-phosphor-image

# 找 deploy image
ls tmp/deploy/images/${MACHINE}/

# 找 package 輸出
find tmp/deploy -maxdepth 3 -type f | grep -E "\.(rpm|ipk|deb)$" | head

# 找 recipe workdir
bitbake -e <recipe> | grep '^WORKDIR='
```

#### 7.1.9 小結

Yocto 可以理解成「可重現的嵌入式 Linux 建構框架」，BitBake 是任務引擎，OpenEmbedded 提供 metadata 骨架，Poky 是參考發行版，OpenBMC 則是在這套框架上建出的 BMC 韌體專案。對 BMC porting 來說，最重要的是把 machine、layer、kernel、U-Boot、image、sensor / inventory config、firmware update layout 這幾塊關係釐清，後續 debug 才能有效率地把問題定位到 BSP、kernel、Device Tree、user space service 或平台設定。


### 7.2 常用變數、目錄結構與 BitBake 建構流程

這章整理 Yocto 的「廚房」：目錄怎麼放、設定檔怎麼寫、常用變數代表什麼、BitBake 如何解析 metadata 並執行 tasks。熟悉這些內容後，排查 BMC image 建構失敗、recipe 沒有被套用、layer 優先權不如預期、sstate 沒有命中等問題會更有效率。

#### 7.2.1 目錄結構

執行 `source oe-init-build-env` 後，常見流程會建立或切換到 `build/` 目錄。`build/` 是整個建構過程的工作核心，包含設定檔、下載資料、快取、中間產物與最終輸出。

```text
build/
├── bitbake-cookerdaemon.log   # BitBake cooker daemon 的執行日誌
├── cache/                     # BitBake 解析快取，加速下次解析
├── conf/                      # 設定檔，例如 local.conf、bblayers.conf
├── downloads/                 # 下載的原始碼與 SCM mirror，通常由 DL_DIR 指定
├── sstate-cache/              # Shared State Cache，通常由 SSTATE_DIR 指定
└── tmp/                       # 建構中間產物與最終輸出，通常由 TMPDIR 指定
    ├── work/                  # 各 recipe 的工作目錄，含 source、build output、log
    ├── deploy/                # image、SDK、套件等輸出
    ├── sysroots-components/   # sysroot 元件資料
    ├── stamps/                # task stamp，用於判斷 task 是否需要重跑
    └── log/                   # build log 與部分統計資料
```

各目錄用途：

- `conf/`：最重要的設定檔所在地，包含 `local.conf` 與 `bblayers.conf`。
- `downloads/`：`do_fetch` 下載的 tarball、Git mirror 或其他 source cache 會放在這裡。此目錄可跨專案共用，降低重複下載成本。
- `sstate-cache/`：Shared State Cache，保存可重用的 task 輸出。若 task 的輸入與 signature 沒有變化，BitBake 可從 sstate 還原結果，減少重建時間。
- `tmp/`：建構過程的主要工作區。`tmp/work/` 是各 recipe 的獨立工作空間，`tmp/deploy/` 是 image、package、SDK 等輸出位置。
- `tmp/work/<machine或arch>/<recipe>/<version>/`：常見 recipe workdir，可找到 `temp/log.do_*`、`image/`、`package/`、`packages-split/`、source tree 等資料。
- `tmp/deploy/images/<machine>/`：BMC image、kernel、DTB、U-Boot、manifest、tarball 或 flash image 的常見輸出位置。

實務建議：

- `downloads/` 與 `sstate-cache/` 可透過共用目錄、符號連結或 NFS 提供給多個開發者或 CI 使用，節省網路頻寬與建構時間。
- CI 環境若共用 sstate，需同時控管 Yocto branch、layer revisions、host distro、compiler 版本與 `MACHINE` / `DISTRO`，避免 cache 命中行為難以追蹤。
- 若懷疑 sstate 造成舊檔被重用，先針對單一 recipe 使用 `bitbake -c cleansstate <recipe>`，不建議一開始就刪整個 `sstate-cache/`。

#### 7.2.2 設定檔說明

##### `local.conf`：個人建構設定

`local.conf` 是使用者自訂建構選項的主要設定檔，通常位於 `build/conf/local.conf`。它適合放開發者本機或 CI job 層級的設定，例如 target machine、下載目錄、sstate 目錄、package format、平行建構參數等。

| 項目 | 說明 | 變數 | 常見預設或範例 |
|---|---|---|---|
| 目標機器 | 要編譯給哪塊板子或 QEMU target | `MACHINE` | `qemux86-64`、`ast2600-evb`、`<project-machine>` |
| 下載目錄 | source archive / Git mirror 位置 | `DL_DIR` | `${TOPDIR}/downloads` |
| 快取目錄 | Shared State Cache 位置 | `SSTATE_DIR` | `${TOPDIR}/sstate-cache` |
| 輸出目錄 | 建構中間產物與 deploy 資料 | `TMPDIR` | `${TOPDIR}/tmp` |
| 發行版政策 | distro policy，例如 libc、init、feature set | `DISTRO` | `poky`、OpenBMC distro 設定 |
| 套件格式 | 產生 RPM、DEB 或 IPK | `PACKAGE_CLASSES` | `package_rpm`、`package_ipk` |
| SDK 架構 | SDK 執行端架構 | `SDKMACHINE` | `x86_64`、`i686` |
| 映像功能 | debug-tweaks、ssh-server 等 image feature | `EXTRA_IMAGE_FEATURES` | 依 distro / image 而定 |
| BitBake 任務數 | BitBake 同時排程多少 task | `BB_NUMBER_THREADS` | 可依 CPU 數與 RAM 調整 |
| 編譯核心數 | 傳給 make / ninja 等工具的平行度 | `PARALLEL_MAKE` | 例如 `-j 16` |

常見設定：

```bitbake
MACHINE = "<project-machine>"
DISTRO = "openbmc-phosphor"
PACKAGE_CLASSES = "package_ipk"

DL_DIR = "/data/yocto/downloads"
SSTATE_DIR = "/data/yocto/sstate-cache"
TMPDIR = "${TOPDIR}/tmp"

BB_NUMBER_THREADS = "16"
PARALLEL_MAKE = "-j 16"
```

建議：

- `BB_NUMBER_THREADS` 與 `PARALLEL_MAKE` 不一定越大越好。若主機 RAM 或 I/O 不足，過高平行度可能造成 swap、I/O wait 或 random build failure。
- BMC 專案常見瓶頸包含 C++ service 編譯、Rust package、node / web UI、kernel build 與 image rootfs；可透過 `buildstats` 或 CI log 觀察實際耗時。
- 若多人共用 `DL_DIR` / `SSTATE_DIR`，建議放在 `site.conf` 或 CI template，而不是每個人的 `local.conf` 各自維護。

##### `bblayers.conf`：決定載入哪些 layers

`bblayers.conf` 定義 BitBake 要載入哪些 layers，通常位於 `build/conf/bblayers.conf`。BitBake 解析 base configuration 時會讀取此檔，並依此找到每個 layer 的 `conf/layer.conf`。

```bitbake
POKY_BBLAYERS_CONF_VERSION = "2"

BBPATH = "${TOPDIR}"
BBFILES ?= ""

BBLAYERS ?= " \
  /home/yocto/poky/meta \
  /home/yocto/poky/meta-poky \
  /home/yocto/poky/meta-yocto-bsp \
  /home/yocto/openbmc/meta-phosphor \
  /home/yocto/openbmc/meta-aspeed \
  /home/yocto/project/meta-my-platform \
  "
```

重點變數：

- `BBLAYERS`：列出所有 layer 的路徑。BitBake 會讀取每個 layer 的 `conf/layer.conf`。
- `BBPATH`：BitBake 搜尋 `.conf`、`.bbclass` 等檔案的路徑基礎。
- `BBFILES`：定位 `.bb` 與 `.bbappend` 檔案的 pattern，通常由各 layer 的 `layer.conf` 追加。

注意事項：

- `BBLAYERS` 的順序會影響 layer 被加入 `BBPATH` 與 metadata 搜尋的先後，但 recipe 選擇與覆蓋不只看順序；更關鍵的是各 layer 在 `layer.conf` 中設定的 `BBFILE_PRIORITY_<collection>`、recipe version、`PREFERRED_PROVIDER`、`PREFERRED_VERSION` 與 override。
- 若同一 recipe 被多個 layer 提供，可用 `bitbake-layers show-overlayed` 與 `bitbake-layers show-recipes <name>` 確認實際採用來源。
- 若 `.bbappend` 沒有套上，常見原因是檔名版本不匹配、layer 沒有加入 `BBLAYERS`、`BBFILES` pattern 沒有包含該路徑，或 layer dependency 沒有滿足。

##### `layer.conf`：每個 layer 的自我介紹

每個 layer 根目錄下通常都有 `conf/layer.conf`，用來宣告該 layer 的 collection name、recipe 搜尋 pattern、priority 與相依 layer。

| 參數 | 說明 |
|---|---|
| `BBPATH` | 將該 layer 加入 BitBake 搜尋路徑 |
| `BBFILES` | 指定該 layer 內 `.bb` 與 `.bbappend` 的位置 |
| `BBFILE_COLLECTIONS` | 註冊 layer collection name |
| `BBFILE_PATTERN_<name>` | 比對路徑，判斷某個 recipe 屬於哪個 collection |
| `BBFILE_PRIORITY_<name>` | layer priority，數字越大優先權越高 |
| `LAYERDEPENDS_<name>` | 宣告此 layer 依賴哪些其他 layer |
| `LAYERSERIES_COMPAT_<name>` | 宣告此 layer 相容哪些 Yocto release series |

```bitbake
BBPATH .= ":${LAYERDIR}"
BBFILES += "${LAYERDIR}/recipes-*/*/*.bb \
            ${LAYERDIR}/recipes-*/*/*.bbappend"

BBFILE_COLLECTIONS += "myplatform"
BBFILE_PATTERN_myplatform = "^${LAYERDIR}/"
BBFILE_PRIORITY_myplatform = "10"

LAYERDEPENDS_myplatform = "core openembedded-layer meta-phosphor"
LAYERSERIES_COMPAT_myplatform = "scarthgap styhead walnascar"
```

BMC porting 建議：

- SoC vendor layer、OpenBMC core layer、company common layer、platform layer 最好有清楚的相依順序與責任邊界。
- 平台差異優先放在 `meta-<platform>`，不要直接改 `meta-phosphor`、`meta-aspeed`、`meta-nuvoton` 或 upstream layer。
- 新增 `.bbappend` 後，先用 `bitbake-layers show-appends | grep <recipe>` 確認有被 BitBake 看到。

#### 7.2.3 常用變數

##### 套件命名相關

| 變數 | 說明 | 範例 |
|---|---|---|
| `PN` | recipe / package name，通常由 recipe 檔名推導 | `busybox` |
| `PV` | package version | `1.36.1` |
| `PR` | package revision，常見預設為 `r0` | `r0` |
| `PE` | epoch，用於特殊版本排序 | `1` |
| `PF` | 完整 recipe working name，常見為 `${PN}-${PV}-${PR}` | `busybox-1.36.1-r0` |
| `BP` | base package name，常見為 `${BPN}-${PV}` | `busybox-1.36.1` |
| `BPN` | 不含特殊 prefix / suffix 的 base package name | `busybox` |

##### 目錄路徑相關

| 變數 | 說明 | 常見用途 |
|---|---|---|
| `TOPDIR` | build directory，例如 `build/` | 設定相對於 build root 的路徑 |
| `TMPDIR` | 建構中間產物 root | 預設常見為 `${TOPDIR}/tmp` |
| `WORKDIR` | 單一 recipe 的工作目錄 | 找 source、patch、log、image staging |
| `S` | 原始碼目錄 | `do_configure` / `do_compile` 常用工作目錄 |
| `B` | build directory | out-of-tree build 時與 `S` 分開 |
| `D` | 暫存安裝 root | `do_install` 安裝目的地 |
| `DL_DIR` | source download cache | 共用下載資料 |
| `SSTATE_DIR` | shared state cache | 共用 task 輸出快取 |
| `DEPLOY_DIR` | deploy 輸出 root | package/image/SDK 輸出根目錄 |
| `DEPLOY_DIR_IMAGE` | 目標 machine 的 image 輸出位置 | 找 BMC flash image、kernel、DTB |
| `sysconfdir` | 設定檔安裝路徑 | 常見為 `/etc` |
| `systemd_system_unitdir` | systemd system unit 目錄 | 安裝 `.service` |

##### 原始碼與相依相關

| 變數 | 說明 | 範例 |
|---|---|---|
| `SRC_URI` | 原始碼、patch、本地檔案來源 | `git://...`、`file://xxx.patch` |
| `SRCREV` | Git revision | commit hash、`${AUTOREV}` |
| `FILESEXTRAPATHS` | 擴充 `file://` 搜尋路徑 | bbappend 常用 |
| `DEPENDS` | build-time dependency | `openssl zlib` |
| `RDEPENDS:${PN}` | runtime dependency | `${PN}` 執行時需要的 package |
| `RRECOMMENDS:${PN}` | runtime recommended package | 可被移除的建議相依 |
| `PROVIDES` | recipe 提供的 virtual target | `virtual/kernel` |
| `RPROVIDES:${PN}` | runtime package 提供的名稱 | package alias |

##### Package 與 image 相關

| 變數 | 說明 | 常見用途 |
|---|---|---|
| `PACKAGES` | recipe 會切出的 package 清單 | `${PN}`、`${PN}-dev`、`${PN}-dbg` |
| `FILES:${PN}` | 指定哪些檔案進入 package | 補 installation path |
| `INSANE_SKIP:${PN}` | 跳過特定 QA check | 需謹慎使用並留下原因 |
| `IMAGE_INSTALL` | image 安裝 package 清單 | 加入工具或 service |
| `IMAGE_FEATURES` | image feature | ssh-server、package-management 等 |
| `EXTRA_IMAGE_FEATURES` | 額外 image feature | debug-tweaks 常見於開發版 |
| `IMAGE_FSTYPES` | image 輸出格式 | `tar.bz2 ext4 wic ubi mtd` |

##### 安裝路徑變數

| 變數 | 典型值 | 說明 |
|---|---|---|
| `prefix` | `/usr` | 安裝根目錄 |
| `exec_prefix` | `${prefix}` | 架構相關檔案的安裝根目錄 |
| `bindir` | `${exec_prefix}/bin` | 一般命令 |
| `sbindir` | `${exec_prefix}/sbin` | 系統管理命令 |
| `libdir` | `${exec_prefix}/lib` 或 `${exec_prefix}/lib64` | 函式庫檔案 |
| `includedir` | `${exec_prefix}/include` | 標頭檔 |
| `datadir` | `${prefix}/share` | 架構無關資料 |
| `sysconfdir` | `/etc` | 設定檔 |
| `localstatedir` | `/var` | log、spool、state data |

使用範例：

```bitbake
do_install() {
    install -d ${D}${bindir}
    install -m 0755 myapp ${D}${bindir}/

    install -d ${D}${sysconfdir}/myapp
    install -m 0644 myconfig.conf ${D}${sysconfdir}/myapp/
}
```

重點：`${D}` 是 `do_install` 的暫存根目錄，安裝檔案時應安裝到 `${D}${bindir}`、`${D}${sysconfdir}` 等路徑，而不是直接寫到 host 的 `/usr/bin` 或 `/etc`。

#### 7.2.4 BitBake 指令

BitBake 是 Yocto / OpenEmbedded 的建構引擎，負責解析 metadata、管理相依關係、安排 task、使用 sstate 並產生 package / image / SDK。

基本用法：

```bash
bitbake <recipe_or_image>
```

例如：

```bash
bitbake zstd-native
bitbake core-image-minimal
bitbake obmc-phosphor-image
```

常用選項：

| 選項 | 說明 | 範例 |
|---|---|---|
| `-c <task>` | 只執行指定 task | `bitbake -c compile zstd-native` |
| `-e` | 顯示變數展開後的環境 | `bitbake -e zstd-native | grep '^S='` |
| `-f` | 強制重跑指定 target 或 task | `bitbake -c compile -f zstd-native` |
| `-k` | 遇到部分錯誤時繼續跑可執行的 task | `bitbake -k obmc-phosphor-image` |
| `-g` | 產生 dependency graph 檔案 | `bitbake -g obmc-phosphor-image` |
| `-p` | 只解析 metadata，不執行建構 | `bitbake -p` |
| `-s` | 顯示 recipe 版本摘要 | `bitbake -s | grep busybox` |
| `-c listtasks` | 列出 recipe 可用 tasks | `bitbake -c listtasks busybox` |

清理任務：

| 指令 | 說明 | 使用時機 |
|---|---|---|
| `bitbake -c clean <recipe>` | 清除該 recipe 的多數 build 輸出，保留下載資料與 sstate | 一般重建 |
| `bitbake -c cleansstate <recipe>` | `clean` 加上刪除該 recipe 的 sstate | 懷疑 sstate 命中舊結果 |
| `bitbake -c cleanall <recipe>` | `cleansstate` 加上刪除 `DL_DIR` 內相關下載資料 | source 下載或 mirror 異常時才考慮 |

排查常用：

```bash
bitbake -e <recipe> | less
bitbake -e <recipe> | grep '^WORKDIR='
bitbake -e <recipe> | grep '^SRC_URI='
bitbake -c listtasks <recipe>
bitbake -c devshell <recipe>
bitbake -c compile -f <recipe>
bitbake-layers show-layers
bitbake-layers show-recipes <recipe>
bitbake-layers show-appends
bitbake-layers show-overlayed
```

#### 7.2.5 BitBake 執行流程

BitBake 的執行過程可分為兩大階段：**解析階段（Parsing Phase）**與**執行階段（Execution Phase）**。

##### 解析階段（Parsing Phase）

1. 讀取 `bblayers.conf`，確認要載入哪些 layers。
2. 讀取每個 layer 的 `conf/layer.conf`，建構 `BBPATH`、`BBFILES`、collection、priority 與 layer dependency。
3. 讀取 `bitbake.conf`、`local.conf`、distro conf、machine conf 與其他 include / require 檔。
4. 根據 `BBFILES` 找到所有 `.bb` 與 `.bbappend`。
5. 解析 recipes、classes、configuration、overrides 與 anonymous python。
6. 建立 providers、preferences、task dependency 與 runqueue。

常見解析階段問題：

| 現象 | 可能方向 | 檢查方式 |
|---|---|---|
| recipe 找不到 | layer 未加入、`BBFILES` pattern 不含該路徑 | `bitbake-layers show-recipes` |
| bbappend 沒套上 | 檔名版本不合、layer 未加入 | `bitbake-layers show-appends` |
| provider 衝突 | 多個 recipe 提供同一 virtual target | 查 `PREFERRED_PROVIDER_*` |
| layer dependency error | `LAYERDEPENDS` 未滿足 | `bitbake-layers show-layers` |
| Yocto series 不相容 | `LAYERSERIES_COMPAT` 不含目前 release | 檢查各 layer `conf/layer.conf` |

##### 執行階段（Execution Phase）

解析完成後，BitBake 依 runqueue 執行 task。task 是否需要重跑取決於 dependency、stamp、signature 與 sstate 狀態。

一般 recipe 的常見 task：

| 順序 | 任務名稱 | 說明 |
|---:|---|---|
| 1 | `do_fetch` | 根據 `SRC_URI` 取得原始碼、本地檔案與 patch |
| 2 | `do_unpack` | 解壓縮或展開 source 到 `WORKDIR` |
| 3 | `do_patch` | 套用 patches |
| 4 | `do_configure` | 執行建構前設定，例如 Autotools、CMake、Meson |
| 5 | `do_compile` | 編譯 source |
| 6 | `do_install` | 將編譯結果安裝到 `${D}` |
| 7 | `do_populate_sysroot` | 將 headers、libraries 等部署到 sysroot，供其他 recipe 使用 |
| 8 | `do_package` | 將 `${D}` 的內容拆成 packages |
| 9 | `do_package_qa` | 執行 package QA 檢查 |
| 10 | `do_package_write_rpm` / `do_package_write_ipk` / `do_package_write_deb` | 依 `PACKAGE_CLASSES` 產生套件 |
| 11 | `do_populate_lic` | 收集授權資訊 |
| 12 | `do_build` | 預設總任務，依賴完成正常建構所需 tasks |

Image recipe 額外 task：

| 任務名稱 | 說明 |
|---|---|
| `do_rootfs` | 建立 root filesystem，安裝 package、執行 postprocess |
| `do_image` | 將 rootfs 轉為 image 產物前的共用階段 |
| `do_image_<fstype>` | 產生指定格式，例如 `do_image_ext4`、`do_image_wic`、`do_image_ubi` |
| `do_image_complete` | image 完成階段，常見 manifest、symlink、deploy 收尾 |
| `do_populate_sdk` | 產生標準 SDK |
| `do_populate_sdk_ext` | 產生 extensible SDK |

擴充 task 的常見方式：

```bitbake
do_install:append() {
    install -d ${D}${sysconfdir}/myapp
    install -m 0644 ${WORKDIR}/myapp.conf ${D}${sysconfdir}/myapp/
}

python do_print_info() {
    bb.note("PN=%s" % d.getVar("PN"))
}
addtask print_info after do_configure before do_compile
```

#### 7.2.6 Metadata、Recipe 與 Layer

Metadata 是 Yocto 建構系統的核心資料，告訴 BitBake **要建構什麼**以及**如何建構**。主要分為：

- **Recipes（`.bb`）**：描述單一套件的建構方式。
- **Append files（`.bbappend`）**：在不直接修改原 recipe 的前提下，追加平台差異。
- **Classes（`.bbclass`）**：定義共用建構邏輯。
- **Configuration（`.conf`）**：定義 machine、distro、layer、local policy 等。

典型 recipe 目錄：

```text
meta-my-layer/
└── recipes-helloworld/
    └── hello-single/
        ├── files/
        │   ├── helloworld.c
        │   └── hello.service
        └── hello_1.0.bb
```

最小 recipe 範例：

```bitbake
SUMMARY = "Simple hello application"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://helloworld.c"
S = "${WORKDIR}"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} helloworld.c -o helloworld
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 helloworld ${D}${bindir}/
}
```

`.bbappend` 可在不改 upstream `.bb` 的狀態下，對 recipe 追加 patch、設定檔、systemd service、編譯參數或安裝內容。

```bitbake
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append = " \
    file://0001-platform-fix.patch \
    file://example.conf \
"

do_install:append() {
    install -d ${D}${sysconfdir}/example
    install -m 0644 ${WORKDIR}/example.conf ${D}${sysconfdir}/example/
}
```

Layer 是 recipe 之上的組織單元，一個 layer 可以包含 recipes、classes、configuration、machine settings、distro policy 與 image 定義。常見命名包含 `meta`、`meta-poky`、`meta-yocto-bsp`、`meta-phosphor`、`meta-aspeed`、`meta-nuvoton`、`meta-<company>`、`meta-<platform>`。

`bitbake-layers` 常用指令：

```bash
bitbake-layers create-layer ../meta-my-layer
bitbake-layers add-layer ../meta-my-layer
bitbake-layers remove-layer ../meta-my-layer
bitbake-layers show-layers
bitbake-layers show-recipes <recipe>
bitbake-layers show-appends
bitbake-layers show-overlayed
```

#### 7.2.7 BMC Porting 檢查重點

| 檢查項目 | 指令 / 檔案 | 預期結果 |
|---|---|---|
| machine 是否正確 | `grep ^MACHINE build/conf/local.conf` | 指向目前平台 machine |
| layer 是否載入 | `bitbake-layers show-layers` | 看到 SoC、OpenBMC、platform layers |
| recipe 是否選對 | `bitbake-layers show-recipes <recipe>` | 採用預期 layer 版本 |
| bbappend 是否套上 | `bitbake-layers show-appends | grep <recipe>` | platform bbappend 有列出 |
| image type 是否正確 | `bitbake -e obmc-phosphor-image | grep ^IMAGE_FSTYPES=` | 符合 flash layout，例如 `mtd`、`ubi` |
| kernel config 是否進去 | `bitbake -e virtual/kernel`、`tmp/work/.../defconfig` | config fragment 有套用 |
| DTS 是否進 image | `tmp/deploy/images/<machine>/*.dtb` | 產出正確 DTB |
| U-Boot env 是否正確 | U-Boot recipe / env / deploy output | bootcmd、mtdparts、slot 設定符合平台 |
| rootfs 是否含 service | `oe-pkgdata-util find-path`、image rootfs | package 有進 rootfs |
| sstate 是否異常 | `bitbake -c cleansstate <recipe>` 後重建 | 行為與預期一致 |

#### 7.2.8 本章參考資料

- Yocto Project Reference Manual - Variables: [https://docs.yoctoproject.org/ref-manual/variables.html](https://docs.yoctoproject.org/ref-manual/variables.html)
- Yocto Project Reference Manual - Tasks: [https://docs.yoctoproject.org/ref-manual/tasks.html](https://docs.yoctoproject.org/ref-manual/tasks.html)
- BitBake User Manual: [https://docs.yoctoproject.org/bitbake/](https://docs.yoctoproject.org/bitbake/)
- Yocto Project Development Tasks Manual - Understanding and Creating Layers: [https://docs.yoctoproject.org/dev/dev-manual/layers.html](https://docs.yoctoproject.org/dev/dev-manual/layers.html)
- OpenEmbedded Layer Index: [https://layers.openembedded.org](https://layers.openembedded.org)


### 7.3 在 Docker 中建立 Yocto 專案並建置完整映像

本章說明如何用 Docker 建立可重現的 Yocto build host，下載 Poky、初始化 build directory，並建置 `core-image-minimal`。此流程可用來驗證 Yocto 環境，也可作為 BMC / OpenBMC CI container 的基礎。

#### 7.3.1 為什麼要在 Docker 中建置 Yocto？

Yocto 對 build host 有明確需求：支援的 Linux distribution、必要套件，以及 Git、tar、Python、gcc、GNU make 等工具版本，都會隨 Yocto release 改變。若直接在本機安裝，可能遇到 host OS 太新或太舊、相依套件版本不合、同時維護多個 Yocto branch 時環境互相衝突等問題。

Docker 的價值是提供隔離且可重現的 build environment。可以在 container 內固定 Linux distribution 與套件清單，讓專案成員與 CI 使用相同建構基準。相較於 VM，Docker 通常更輕量，因為它使用 host Linux kernel，不需模擬完整硬體。

重要提醒：Yocto / BitBake 不建議以 `root` 身分執行。建構過程會建立大量檔案、執行 install step、產生 rootfs；若以 root 執行，容易造成檔案權限錯亂或誤寫 host 檔案。因此 Docker image 內應建立非 root 使用者，例如 `yocto`，並以該使用者執行 `bitbake`。

#### 7.3.2 建立 Docker Container

以下 Dockerfile 以 Fedora 38 為基礎。實際專案需依目前 Yocto release 的官方 system requirements 調整 base image 與套件清單。

```dockerfile
FROM fedora:38

# 建立非 root 使用者
RUN groupadd -g 1000 yocto && \
    useradd -m -u 1000 -g yocto yocto

# 安裝 Yocto 常用建構套件；實際清單需依 Yocto release 調整
RUN dnf update -y && dnf install -y \
    sudo \
    glibc-locale-source \
    glibc-langpack-en \
    librsvg2-tools \
    bc \
    @development-tools \
    gdisk \
    openssl-devel \
    bzip2 \
    ccache \
    chrpath \
    cpio \
    cpp \
    diffstat \
    diffutils \
    file \
    findutils \
    gawk \
    gcc \
    gcc-c++ \
    git \
    glibc-devel \
    gzip \
    hostname \
    libacl \
    make \
    ncurses-devel \
    patch \
    perl \
    perl-Data-Dumper \
    perl-File-Compare \
    perl-File-Copy \
    perl-FindBin \
    perl-Text-ParseWords \
    perl-Thread-Queue \
    perl-bignum \
    perl-locale \
    python3 \
    python3-GitPython \
    python3-jinja2 \
    python3-pexpect \
    python3-pip \
    rpcgen \
    socat \
    tar \
    texinfo \
    unzip \
    wget \
    which \
    xz \
    zstd \
    vim \
    lz4 \
    && dnf clean all

# 給予 yocto 使用者 sudo 權限；CI image 可依安全政策移除
RUN echo "yocto ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/yocto && \
    chmod 0440 /etc/sudoers.d/yocto

USER yocto
WORKDIR /home/yocto
CMD ["/bin/bash"]
```

常見套件用途：

| 套件 | 用途 |
|---|---|
| `git` | 從 Git repository 擷取原始碼，常用於 `do_fetch` |
| `wget` | 從 HTTP / HTTPS / FTP 下載 source archive |
| `make` / `gcc` / `gcc-c++` | 建構 host tools、native tools、target packages |
| `chrpath` | 調整 ELF RPATH，常見於 SDK / native tools |
| `cpio` | 建立 initramfs 或處理 cpio archive |
| `diffstat` | 顯示 patch 統計資訊 |
| `file` | 判斷檔案型態，常用於 QA 檢查 |
| `patch` | 套用 recipe patches，對應 `do_patch` |
| `perl` / `python3` | Yocto、BitBake、recipes 與輔助工具常用 runtime |
| `texinfo` | 建構 GNU info 文件 |
| `unzip` / `xz` / `zstd` / `lz4` | 處理不同壓縮格式 |
| `socat` | QEMU 網路轉發與測試情境常用工具 |
| `ccache` | 編譯快取，可縮短部分重建時間 |
| `ncurses-devel` | `menuconfig` / `nconfig` 類工具需要的 terminal UI library |

建立 Docker image：

```bash
mkdir -p ~/docker-yocto
cd ~/docker-yocto
vim Dockerfile

docker build -t yocto-fedora:38 .
```

啟動 container：

```bash
mkdir -p ~/yocto-work

docker run -itd \
    --name yocto_fedora38 \
    --memory=32g \
    --memory-swap=32g \
    -v ~/yocto-work:/work \
    yocto-fedora:38

docker exec -it yocto_fedora38 bash
```

參數說明：

- `-v ~/yocto-work:/work`：將 host 目錄掛載到 container 內，保存 source、downloads、sstate-cache 與最終 image。
- `--memory=32g --memory-swap=32g`：限制 container 記憶體與 swap。近期 Yocto quick build 文件建議準備較高 RAM；若只給 4 GB，簡單 image 可能可行，但大型 image 容易 OOM。
- `--name yocto_fedora38`：指定 container 名稱，方便後續 `docker exec`、`docker stop`、`docker start`。

若主機資源有限，優先降低 BitBake / make 平行度：

```bitbake
BB_NUMBER_THREADS = "4"
PARALLEL_MAKE = "-j 4"
```

Windows / WSL / Docker Desktop 注意事項：

- Yocto build directory 不建議放在 Windows NTFS 掛載路徑上，因為大小寫、symlink、inode、檔案權限與 I/O 行為可能造成額外問題。
- 若使用 WSL2，建議把 source、`build/`、`downloads/`、`sstate-cache/` 放在 WSL2 Linux filesystem 內，而不是 `/mnt/c/...`。
- 若需要從 Windows 取出產物，可只將 `tmp/deploy/images/<machine>/` 複製到 Windows 端。

#### 7.3.3 下載 Poky 並初始化

進入 container 後，下載 Poky 並切到目標分支。以下以 `walnascar` 為例；實際專案需依客戶、SoC vendor、OpenBMC branch 或 Yocto release policy 選擇 branch。

```bash
cd /work

git clone git://git.yoctoproject.org/poky.git
cd poky

git branch -a | grep walnascar
git checkout -t origin/walnascar -b my-walnascar

source oe-init-build-env
```

執行 `source oe-init-build-env` 後，通常會進入 `build/` 目錄，並產生：

```text
build/conf/local.conf
build/conf/bblayers.conf
```

第一次建置前建議調整 `conf/local.conf`：

```bitbake
# QEMU 目標；若是實體板，改為對應 MACHINE
MACHINE ?= "qemux86-64"

# 平行度需依 CPU / RAM / I/O 調整
BB_NUMBER_THREADS = "8"
PARALLEL_MAKE = "-j 8"

# 將 downloads 與 sstate-cache 放到 build 外層，方便多個 build 共用
DL_DIR = "/work/yocto-cache/downloads"
SSTATE_DIR = "/work/yocto-cache/sstate-cache"
```

建議目錄規劃：

```text
/work/
├── poky/
│   └── build/
└── yocto-cache/
    ├── downloads/
    └── sstate-cache/
```

#### 7.3.4 執行第一次 BitBake

建立最小 Linux image：

```bash
bitbake core-image-minimal
```

`core-image-minimal` 是驗證 build host、toolchain、metadata 與 QEMU target 的常見起點。第一次建構會花較久，因為需要下載 source、建構 native tools、cross toolchain、target packages 與 rootfs。第二次以後若 `downloads/` 與 `sstate-cache/` 命中，時間會縮短。

建構完成後，輸出通常位於：

```bash
ls tmp/deploy/images/qemux86-64/
```

常見產物：

```text
core-image-minimal-qemux86-64.ext4
core-image-minimal-qemux86-64.manifest
core-image-minimal-qemux86-64.testdata.json
bzImage
modules-qemux86-64.tgz
```

可用 QEMU 測試 image：

```bash
runqemu qemux86-64
```

若 container 內缺少 `/dev/kvm` 權限，QEMU 仍可能以軟體模擬方式啟動，但速度會慢很多。若要使用 KVM，可在 `docker run` 時加入：

```bash
docker run -itd \
    --name yocto_fedora38 \
    --device /dev/kvm \
    --group-add $(getent group kvm | cut -d: -f3) \
    -v ~/yocto-work:/work \
    yocto-fedora:38
```

#### 7.3.5 效能最佳化與最佳實務

保存建構產物：不要只把重要資料放在 container writable layer。container 移除後，內部資料也會消失。建議至少保存：

```text
/work/yocto-cache/downloads/
/work/yocto-cache/sstate-cache/
/work/poky/build/tmp/deploy/images/<machine>/
```

善用 sstate 快取：

```bitbake
SSTATE_DIR = "/work/yocto-cache/sstate-cache"
```

團隊共用 sstate 時，需注意：

- 共用目錄權限需允許 container 內的 UID/GID 讀寫。
- 不同 Yocto release、不同 host distro、不同 layer revision 混用時，sstate 命中率與可追蹤性會下降。
- CI 可使用唯讀 upstream sstate mirror 加上 job local writable sstate，降低互相污染。

記憶體與磁碟空間建議：

- `core-image-minimal`：建議準備 100 GB 等級磁碟空間較穩妥。
- OpenBMC image：依平台與 Web UI / debug package 狀態不同，建議保留更多空間給 `tmp/`、`downloads/`、`sstate-cache/`。
- 若記憶體有限，先降低 `BB_NUMBER_THREADS` 與 `PARALLEL_MAKE`。
- 可用 `docker stats` 觀察 container 記憶體與 CPU 使用。

```bash
docker stats yocto_fedora38
```

UID/GID 權限建議：若 host 掛載目錄屬於 UID 1000 / GID 1000，container 內也使用 UID 1000 / GID 1000 的 `yocto` 使用者，可避免許多 `Permission denied` 或 root-owned output。

若開發機 UID/GID 不一定是 1000，可把 Dockerfile 改成 build args：

```dockerfile
ARG USER_ID=1000
ARG GROUP_ID=1000
RUN groupadd -g ${GROUP_ID} yocto && \
    useradd -m -u ${USER_ID} -g yocto yocto
```

建置時指定：

```bash
docker build \
    --build-arg USER_ID=$(id -u) \
    --build-arg GROUP_ID=$(id -g) \
    -t yocto-fedora:38 .
```

#### 7.3.6 常見問題與排查

| 問題 | 可能原因 | 排查 / 處理方式 |
|---|---|---|
| `OE-core's config sanity checker detected a potential misconfiguration` | Host distro、必要工具或 shell 環境不符合 Yocto sanity check | 查看 `tmp/log/cooker/*`，確認 Yocto release 支援的 host distro 與套件版本 |
| `Permission denied` | bind mount 權限或 UID/GID 不一致 | 對齊 host 與 container 的 UID/GID，檢查 `/work` 權限 |
| `do_patch` 失敗 | patch 不適用、換行格式、檔案權限或 source revision 不對 | 看 `temp/log.do_patch`，進 `WORKDIR` 檢查 patch context |
| 建構中途被 kill | 記憶體不足或 Docker memory limit 太低 | 提高 `--memory`，或降低 `BB_NUMBER_THREADS` / `PARALLEL_MAKE` |
| `do_fetch` 失敗 | 網路、DNS、proxy、憑證、Git protocol 被擋 | 設定 `http_proxy` / `https_proxy`，或改用 mirror / premirror |
| 建構速度很慢 | 未命中 sstate、I/O 慢、平行度不合理 | 檢查 `SSTATE_DIR`、磁碟 I/O、`BB_NUMBER_THREADS`、`PARALLEL_MAKE` |
| Windows 掛載點建構失敗 | 檔案系統大小寫、symlink、權限或 I/O 行為不符合 Linux 預期 | 將 `TMPDIR`、source tree、sstate 放在 Linux filesystem |
| `make menuconfig` 失敗 | 缺少 ncurses 或 terminal 設定不足 | 安裝 `ncurses-devel`，確認 `TERM` 設定；必要時使用 `screen` / `tmux` |
| `runqemu` 很慢 | container 沒有 KVM 權限 | 加入 `--device /dev/kvm` 與 kvm group，或接受軟體模擬速度 |
| Docker 內 DNS 失敗 | Docker daemon DNS 設定或公司網路限制 | 檢查 `/etc/resolv.conf`，必要時於 Docker daemon 設定 DNS |

常用 log 位置：

```bash
# BitBake cooker log
ls -l bitbake-cookerdaemon.log

# 單一 recipe task log
find tmp/work -path '*temp/log.do_compile*' | head
find tmp/work -path '*temp/log.do_fetch*' | head
find tmp/work -path '*temp/log.do_patch*' | head

# 最近失敗訊息
find tmp/work -path '*temp/log.do_*' -mtime -1 | sort | tail
```

#### 7.3.7 BMC / OpenBMC 專案延伸

若目標不是 Poky 的 `core-image-minimal`，而是 OpenBMC image，流程通常會變成：

```bash
cd /work

git clone https://github.com/openbmc/openbmc.git
cd openbmc

# 依平台選擇 machine
. setup <machine>

bitbake obmc-phosphor-image
```

OpenBMC 專案建議額外確認：

| 項目 | 檢查方式 | 說明 |
|---|---|---|
| MACHINE | `. setup <machine>` 後檢查 `conf/local.conf` | 確認平台是否正確 |
| SoC layer | `bitbake-layers show-layers` | 需看到 `meta-aspeed`、`meta-nuvoton` 或對應 SoC layer |
| image output | `tmp/deploy/images/<machine>/` | 找 `.static.mtd.tar`、`.ubi.mtd.tar` 或平台定義 image |
| sensor config | platform layer / Entity Manager config | 對齊 I2C bus map 與 schematic |
| update format | image manifest / phosphor software manager | 對齊 update service 與 flash layout |

#### 7.3.8 本章參考資料

- Yocto Project Quick Build: [https://docs.yoctoproject.org/brief-yoctoprojectqs/index.html](https://docs.yoctoproject.org/brief-yoctoprojectqs/index.html)
- Yocto Project Reference Manual - System Requirements: [https://docs.yoctoproject.org/ref-manual/system-requirements.html](https://docs.yoctoproject.org/ref-manual/system-requirements.html)
- Docker Docs - Bind mounts: [https://docs.docker.com/engine/storage/bind-mounts/](https://docs.docker.com/engine/storage/bind-mounts/)
- Docker Docs - Resource constraints: [https://docs.docker.com/engine/containers/resource_constraints/](https://docs.docker.com/engine/containers/resource_constraints/)
- AMD / Xilinx Wiki - Building Yocto Images using a Docker Container: [https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/2823422188/Building+Yocto+Images+using+a+Docker+Container](https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/2823422188/Building+Yocto+Images+using+a+Docker+Container)

### 7.4 單獨建置與除錯特定套件

在日常開發中，很少需要每次都從頭建置整個 image。更常見的是只修改某個 application、library、kernel、kernel module、OpenBMC service 或 recipe，然後希望快速驗證修改是否正確。Yocto / BitBake 的建構單位是 **recipe**，因此可以只針對單一 recipe 執行 `fetch`、`patch`、`compile`、`install`、`package`、`deploy` 等 tasks；BitBake 會根據相依關係、stamp 與 sstate 判斷哪些任務需要重跑。

#### 7.4.1 為什麼要單獨建置一個套件？

| 場景                 | 說明                                                        | 常用指令                                                      |
| -------------------- | ----------------------------------------------------------- | ------------------------------------------------------------- |
| 開發新功能           | 修改某個 application、daemon、kernel module，先確認能否編譯 | `bitbake -c compile -f <recipe>`                            |
| 修 bug               | recipe 或 source 編譯失敗，修改後重新驗證                   | `bitbake <recipe>`                                          |
| 驗證 patch           | 測試 patch 是否可套用、是否造成編譯錯誤                     | `bitbake -c patch -f <recipe>`                              |
| 調整 feature         | 修改`PACKAGECONFIG`、編譯選項或 recipe 變數               | `bitbake -e <recipe>`、`bitbake -c configure -f <recipe>` |
| 取出產物             | 只需要某個 library、binary、kernel image 或 module          | `bitbake -c deploy <recipe>`                                |
| OpenBMC service 開發 | 修改 phosphor service 或平台 service 後快速重建             | `bitbake <service-recipe>`                                  |

關鍵觀念：

- `bitbake <recipe>` 會執行該 recipe 的預設 build task，並自動處理 build-time dependencies。
- `bitbake -c <task> <recipe>` 可指定只跑某個 task，例如 `compile`、`install`、`package`、`deploy`。
- `-f` 會讓指定 task 忽略既有 stamp，強制重跑。
- 若只是臨時改 `tmp/work` 內 source，速度很快，但 `clean` 後修改會消失；正式修改應回到 layer，用 `.bbappend`、patch 或 `devtool` 管理。

#### 7.4.2 單獨建置一個套件

假設要建置 `zstd-native`：

```bash
bitbake zstd-native
```

BitBake 會檢查 `zstd-native` 的相依項目，並依任務關係執行必要流程，例如：

```text
do_fetch → do_unpack → do_patch → do_configure → do_compile → do_install
         → do_populate_sysroot → do_package → do_package_qa → do_package_write_*
```

若之前已經建置過，相同 task 可能透過 stamp 或 sstate 判斷不需要重跑，因此第二次建置通常會快很多。

只執行特定 task：

```bash
# 只下載原始碼
bitbake -c fetch zstd-native

# 展開 source 並套用 patch，用於檢查 patch 是否衝突
bitbake -c patch zstd-native

# 只編譯
bitbake -c compile zstd-native

# 只執行安裝到 ${D}
bitbake -c install zstd-native

# 列出此 recipe 可用 tasks
bitbake -c listtasks zstd-native
```

強制重新執行某個 task：

```bash
# 強制重新編譯，忽略 compile task 的 stamp
bitbake -c compile -f zstd-native

# 如果 patch 或 configure 有改，從較早階段重跑
bitbake -c patch -f zstd-native
bitbake -c configure -f zstd-native
bitbake -c compile -f zstd-native
```

補充：`-C <task>` 也是常用方式，它會讓指定 task 的 stamp 失效，然後執行預設 build 流程。例如：

```bash
# 清掉 compile stamp 後，接著跑預設 build
bitbake -C compile zstd-native
```

#### 7.4.3 建置產物在哪裡？

單獨建置一個 recipe 後，常見產物位置如下：

| 路徑                                                          | 內容                                  | 用途                                             |
| ------------------------------------------------------------- | ------------------------------------- | ------------------------------------------------ |
| `tmp/work/<arch或machine>/<pn>/<pv>/`                       | 該 recipe 的工作目錄                  | 找 source、build output、task log                |
| `tmp/work/.../<pn>/<pv>/temp/`                              | task log 與 run script                | 排查`log.do_compile`、`run.do_compile`       |
| `tmp/work/.../<pn>/<pv>/image/`                             | `do_install` 安裝到 `${D}` 的結果 | 確認檔案是否安裝到正確路徑                       |
| `tmp/work/.../<pn>/<pv>/package/`                           | package 前的中間資料                  | 排查 package 切分問題                            |
| `tmp/work/.../<pn>/<pv>/packages-split/`                    | 拆分後的 package 內容                 | 確認`${PN}`、`${PN}-dev`、`${PN}-dbg` 內容 |
| `tmp/deploy/rpm/`、`tmp/deploy/ipk/`、`tmp/deploy/deb/` | 最終套件檔                            | 找`.rpm`、`.ipk`、`.deb`                   |
| `tmp/deploy/images/<machine>/`                              | kernel、DTB、U-Boot、image 等         | `virtual/kernel`、U-Boot、image recipe 常用    |
| `tmp/sysroots-components/`                                  | sysroot 元件                          | 確認 headers / libraries 是否進 sysroot          |

快速找 recipe 工作目錄：

```bash
bitbake -e zstd-native | grep '^WORKDIR='
bitbake -e zstd-native | grep '^S='
bitbake -e zstd-native | grep '^B='
```

開發時最常看的位置：

```bash
# 安裝結果
ls ${WORKDIR}/image/

# package 拆分結果
ls ${WORKDIR}/packages-split/

# task log
ls ${WORKDIR}/temp/log.do_*
```

#### 7.4.4 完整開發循環：Modify → Build → Test

以下以 `zstd-native` 為例，說明臨時修改 source 並驗證的流程。

Step 1：找到 source 目錄：

```bash
bitbake -e zstd-native | grep '^S='
```

可能輸出：

```text
S="/home/yocto/poky/build/tmp/work/x86_64-linux/zstd-native/1.5.7/git"
```

Step 2：進入 source 目錄並修改：

```bash
cd /home/yocto/poky/build/tmp/work/x86_64-linux/zstd-native/1.5.7/git
vim lib/zstd.h
```

注意：直接修改 `tmp/work/` 是臨時測試方式，適合快速確認方向。若後續執行 `clean`、重新 unpack，或 sstate 還原，修改可能消失。確認可行後，應把修改轉成 patch、`.bbappend`，或使用 `devtool modify / devtool finish` 納入正式 layer。

Step 3：重新編譯：

```bash
bitbake -c compile -f zstd-native
```

Step 4：重新安裝與打包：

```bash
bitbake -c install -f zstd-native
bitbake -c package -f zstd-native
```

Step 5：若要讓最終 image 納入變更，再重建 image：

```bash
bitbake core-image-minimal
```

OpenBMC service 常見流程：

```bash
# 找 recipe
bitbake-layers show-recipes | grep phosphor

# 單獨建置 service
bitbake <service-recipe>

# 若 image 要包含更新後 package
bitbake obmc-phosphor-image
```

#### 7.4.5 建置失敗時如何排查

BitBake 失敗時通常會印出失敗 task 與 log 位置，例如：

```text
ERROR: Logfile of failure stored in:
/tmp/work/x86_64-linux/zstd-native/1.5.7/temp/log.do_compile.12345
```

查看 log：

```bash
less /home/yocto/poky/build/tmp/work/x86_64-linux/zstd-native/1.5.7/temp/log.do_compile.12345

# 通常也會有無序號 symlink 或最新 log
less tmp/work/x86_64-linux/zstd-native/1.5.7/temp/log.do_compile
```

常見失敗情境：

| 失敗 task         | 可能原因                                                                                    | 排查入口                                                  |
| ----------------- | ------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| `do_fetch`      | 網路、proxy、DNS、Git branch / commit 不存在、憑證問題                                      | `log.do_fetch`、`SRC_URI`、`SRCREV`、mirror 設定    |
| `do_unpack`     | 壓縮檔格式錯、檔案損壞、fetch 結果不完整                                                    | `log.do_unpack`、`DL_DIR`                             |
| `do_patch`      | patch context 不符、source revision 不對、patch 順序錯                                      | `log.do_patch`、`patches/`、`quilt`                 |
| `do_configure`  | 缺少 build dependency、`PACKAGECONFIG` 不合理、toolchain file 問題                        | `log.do_configure`、`DEPENDS`、`EXTRA_OECONF`       |
| `do_compile`    | 語法錯誤、compiler flag 不相容、missing header / library                                    | `log.do_compile`、`S`、`B`、`CFLAGS`、`LDFLAGS` |
| `do_install`    | 未加`${D}`、安裝目錄不存在、權限或路徑錯 | `log.do_install`、`${D}`、`do_install()` |                                                           |
| `do_package`    | `FILES:${PN}` 未涵蓋、package split 錯誤                                                  | `packages-split/`、`FILES:*`                          |
| `do_package_qa` | rpath、installed-vs-shipped、already-stripped、ldflags 等 QA issue                          | `log.do_package_qa`、`INSANE_SKIP`                    |

從失敗點繼續：

```bash
# do_compile 失敗，修正 source 後重跑 compile
bitbake -c compile -f zstd-native

# do_configure 相關問題，通常從 configure 重跑
bitbake -c configure -f zstd-native
bitbake -c compile -f zstd-native

# do_patch 相關問題，從 patch 重跑
bitbake -c patch -f zstd-native
bitbake -c compile -f zstd-native
```

進入開發 shell：

```bash
# 進入 recipe 的建構環境，便於手動執行 make / ninja / cmake
bitbake -c devshell zstd-native

# 部分 recipe 可用 menuconfig，例如 kernel / busybox
bitbake -c menuconfig virtual/kernel
```

#### 7.4.6 clean / cleansstate / cleanall 何時使用？

| 指令                                | 清除範圍                                        | 適用情境                         | 注意事項                             |
| ----------------------------------- | ----------------------------------------------- | -------------------------------- | ------------------------------------ |
| `bitbake -c clean <recipe>`       | 清除多數 build output，保留`DL_DIR` 與 sstate | 一般重新建置                     | 相對安全，常用                       |
| `bitbake -c cleansstate <recipe>` | `clean` 加上移除該 recipe sstate              | 懷疑 sstate 還原舊結果           | 下次會慢，因為要重建                 |
| `bitbake -c cleanall <recipe>`    | `cleansstate` 加上刪除下載資料                | source / mirror 異常或要重新下載 | 謹慎使用，可能造成重新下載大量資料   |
| `bitbake -C <task> <recipe>`      | 指定 task stamp 失效後跑預設 build              | 想從某 task 後重跑完整流程       | 適合比`-f` 更貼近完整 build 的驗證 |

實務建議：

- 一般 code / recipe 修改：先用 `bitbake -c compile -f <recipe>` 或 `bitbake -C compile <recipe>`。
- 懷疑 workdir 舊檔干擾：用 `clean`。
- 懷疑 sstate 還原異常：用 `cleansstate`。
- 除非確認 source cache 有問題，否則少用 `cleanall`。

#### 7.4.7 實戰案例：修改 Linux Kernel

Kernel 是 BMC porting 最常單獨建置的目標之一。常見目標是修改 driver、DTS、defconfig 或 config fragment。

1. 建置 kernel：

```bash
bitbake virtual/kernel
```

2. 找 kernel source：

```bash
bitbake -e virtual/kernel | grep '^S='
bitbake -e virtual/kernel | grep '^B='
```

3. 修改 driver 或 DTS：

```bash
cd <kernel-source>
vim drivers/char/xxx.c
# 或修改 arch/arm/boot/dts/... / arch/arm64/boot/dts/...
```

4. 重新編譯 kernel：

```bash
bitbake -c compile -f virtual/kernel
```

5. 部署 kernel image / DTB / modules：

```bash
bitbake -c deploy virtual/kernel
```

6. 查看部署結果：

```bash
ls tmp/deploy/images/${MACHINE}/
```

7. 若是 QEMU target，可用：

```bash
runqemu qemux86-64
```

BMC kernel / DTS 額外提醒：

- 若變更 DTS，需確認實際 deploy 的 `.dtb` 是目標平台使用的那一份。
- 若變更 config fragment，需確認最終 `.config` 是否真的包含該選項。
- 若使用 OpenBMC，kernel image、DTB 與 rootfs 打包方式會受 machine 與 image type 影響，需同步檢查 `tmp/deploy/images/<machine>/` 的 `.mtd`、`.ubi`、fitImage 或其他平台產物。

#### 7.4.8 何時該改用 devtool？

直接修改 `tmp/work` 適合短時間測試，但不適合作為正式修改流程。以下情境建議使用 `devtool`：

| 情境                                      | 建議工具                            |
| ----------------------------------------- | ----------------------------------- |
| 要長時間修改某 recipe source              | `devtool modify <recipe>`         |
| 要新增一個 application / package          | `devtool add` 或手寫 recipe       |
| 要把本地修改整理成 patch 並放回 layer     | `devtool finish <recipe> <layer>` |
| 要部署單一 recipe 產物到 live target 測試 | `devtool deploy-target`           |
| 要移除 workspace 內的臨時 recipe 修改     | `devtool reset <recipe>`          |

典型 devtool 流程：

```bash
# 取出 recipe source 到 workspace
 devtool modify zstd-native

# 修改 source 後建置
 devtool build zstd-native

# 完成後把修改整理回指定 layer
 devtool finish zstd-native ../meta-my-layer

# 若只是取消 workspace 狀態
 devtool reset zstd-native
```

#### 7.4.9 本章參考資料

- BitBake User Manual - Execution: [https://docs.yoctoproject.org/bitbake/bitbake-user-manual/bitbake-user-manual-execution.html](https://docs.yoctoproject.org/bitbake/bitbake-user-manual/bitbake-user-manual-execution.html)
- BitBake User Manual: [https://docs.yoctoproject.org/bitbake/](https://docs.yoctoproject.org/bitbake/)
- Yocto Project Reference Manual - Tasks: [https://docs.yoctoproject.org/ref-manual/tasks.html](https://docs.yoctoproject.org/ref-manual/tasks.html)
- Yocto Project Development Tasks Manual - devtool: [https://docs.yoctoproject.org/dev/dev-manual/devtool.html](https://docs.yoctoproject.org/dev/dev-manual/devtool.html)

### 7.5 使用 .bbappend 修改套件行為

在 Yocto / OpenBMC 開發中，常見需求是調整既有套件的行為，但不直接修改原本的 `.bb`。原始 recipe 可能來自 OE-Core、meta-openembedded、meta-phosphor、SoC vendor layer 或 BSP layer；若直接改，後續更新時容易被覆蓋，也會讓平台差異不易追蹤。因此平台差異建議放在自己的 layer，透過 `.bbappend` 追加。

#### 7.5.1 什麼是 .bbappend？

`.bbappend` 是 BitBake append file。它必須對應到一個存在的 `.bb` recipe，且 root filename 要相同，差異只在副檔名。例如 `zstd_1.5.7.bb` 可對應 `zstd_1.5.7.bbappend`、`zstd_1.5.%.bbappend` 或 `zstd_%.bbappend`。

可以這樣理解：

- `.bb`：原始食譜。
- `.bbappend`：補充便條，只寫需要追加或調整的部分。
- BitBake：解析 recipe 時，把符合條件的 `.bbappend` 合併進 metadata。

常見用途：加 patch、加設定檔、加 systemd override、調整 `PACKAGECONFIG` / `EXTRA_OECMAKE` / `EXTRA_OEMESON`、追加 `DEPENDS` / `RDEPENDS:${PN}`、在 `do_install` 後追加安裝內容、針對 machine 或 class 做差異化設定。

#### 7.5.2 命名規範

| 檔名 | 套用範圍 | 適用情境 |
|------|----------|----------|
| `zstd_1.5.7.bbappend` | 只套用到 `zstd_1.5.7.bb` | patch 高度綁定特定版本 |
| `zstd_1.5.%.bbappend` | 套用到 `zstd_1.5.x` | 同一 minor series 行為接近 |
| `zstd_%.bbappend` | 套用到所有 `zstd` 版本 | 平台設定不依賴版本，最常見 |

注意：`%` 通常只放在 `.bbappend` 前面。若 recipe 升級，精準版本 append 可能失效；使用 `recipe_%.bbappend` 較能承受版本更新。若 append 找不到對應 recipe，BitBake 通常會在 parsing 階段報錯。

#### 7.5.3 目錄結構與 FILESEXTRAPATHS

建議把 `.bbappend` 放在自己的 layer，目錄分類盡量跟原 recipe 接近：

```text
meta-my-layer/
└── recipes-extended/
    └── zstd/
        ├── zstd_%.bbappend
        └── zstd/
            └── 0001-fix-compile-error.patch
```

`zstd_%.bbappend`：

```bitbake
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append = " file://0001-fix-compile-error.patch"
```

變數說明：

- `${THISDIR}`：目前 `.bbappend` 所在目錄。
- `${PN}`：目前 recipe / package name。
- `${BPN}`：base package name；遇到 `-native`、`nativesdk-`、multilib 變體時常比 `${PN}` 穩定。
- `FILESEXTRAPATHS`：擴充 `file://` 搜尋路徑。
- `SRC_URI`：列出 source、patch 或本地檔案。

常用寫法：

```bitbake
# 一般 recipe 常用
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# native / nativesdk 也會套用時，常改用 BPN
FILESEXTRAPATHS:prepend := "${THISDIR}/${BPN}:"

# 檔案統一放 files/ 時
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
```

BMC porting 建議：若 append 會作用到 `cmake-native`、`zstd-native` 或 `nativesdk-*`，優先評估 `${BPN}` 或 `files/`。因為 native variant 的 `${PN}` 可能是 `cmake-native`，但實際檔案目錄常是 `cmake/`。

#### 7.5.4 常用語法

```bitbake
# 追加變數；字串前面的空格要保留
SRC_URI:append = " file://0001-platform-fix.patch"
DEPENDS:append = " openssl"
RDEPENDS:${PN}:append = " bash"

# 插入變數；字串後面的空格要保留
CFLAGS:prepend = "-DDEBUG "

# 移除 list-like 變數中的項目
PACKAGECONFIG:remove = "x11"

# 完全覆寫，需謹慎
PACKAGECONFIG = "ssl zlib"
```

建議優先使用 `:append`、`:prepend`、`:remove`，非必要不要直接用 `=` 覆寫整個變數。override-style 的 `:append` / `:prepend` 不會自動補空格，所以 `SRC_URI:append = " file://my.patch"` 前面的空格是必要的。

追加 task 內容：

```bitbake
do_install:append() {
    install -d ${D}${sysconfdir}/myapp
    install -m 0644 ${WORKDIR}/myapp.conf ${D}${sysconfdir}/myapp/myapp.conf
}
```

`do_install` 內正式要進 package 的檔案應安裝到 `${D}` 底下，例如 `${D}${bindir}`、`${D}${sysconfdir}`、`${D}${datadir}`。`${B}` 是 build directory，不等於 package 安裝目的地。

針對 machine / class 做差異：

```bitbake
SRC_URI:append:my-bmc-machine = " file://0001-my-bmc-only.patch"
EXTRA_OECMAKE:append:class-native = " -DENABLE_TOOLS=ON"

do_install:append:class-target() {
    install -d ${D}${sysconfdir}/platform
}
```

#### 7.5.5 動手做：用 .bbappend 修改 cmake-native 行為

Step 1：建立或加入自己的 layer：

```bash
bitbake-layers create-layer ../meta-my-layer
bitbake-layers add-layer ../meta-my-layer
bitbake-layers show-layers
```

Step 2：確認 recipe：

```bash
bitbake-layers show-recipes cmake
bitbake -e cmake-native | grep -E '^(PN|BPN|PV|FILE)='
```

注意：雖然建置目標是 `cmake-native`，append 檔名通常仍是 `cmake_%.bbappend`。原因是 `cmake-native` 多半是由 `cmake` recipe 透過 class extension 產生，不是檔名叫 `cmake-native_*.bb` 的獨立 recipe。

Step 3：建立 append：

```bash
mkdir -p ../meta-my-layer/recipes-devtools/cmake
vim ../meta-my-layer/recipes-devtools/cmake/cmake_%.bbappend
```

先放最小內容確認 append 被解析：

```bitbake
python () {
    bb.note("meta-my-layer: cmake append parsed for PN=%s BPN=%s" % (d.getVar("PN"), d.getVar("BPN")))
}
```

確認 append 有套上：

```bash
bitbake -p
bitbake-layers show-appends | grep -A5 -B2 'cmake'
```

Step 4A：練習用，寫檔到 build directory：

```bitbake
do_install:append:class-native() {
    install -d ${B}/cmake2
    echo "Try to write line to the file." > ${B}/cmake2/appendFile.txt
}
```

```bash
bitbake -c install -f cmake-native
cat tmp/work/x86_64-linux/cmake-native/*/build/cmake2/appendFile.txt
```

這個做法適合確認 `do_install:append` 有執行，但不代表檔案會被打包或進 rootfs。

Step 4B：正式安裝用，寫到 `${D}`：

```bitbake
FILESEXTRAPATHS:prepend := "${THISDIR}/${BPN}:"

SRC_URI:append:class-native = " file://appendFile.txt"

do_install:append:class-native() {
    install -d ${D}${datadir}/cmake2
    install -m 0644 ${WORKDIR}/appendFile.txt ${D}${datadir}/cmake2/appendFile.txt
}

FILES:${PN}:append:class-native = " ${datadir}/cmake2/appendFile.txt"
```

```text
meta-my-layer/
└── recipes-devtools/
    └── cmake/
        ├── cmake_%.bbappend
        └── cmake/
            └── appendFile.txt
```

```bash
bitbake -c install -f cmake-native
find tmp/work -path '*cmake-native*image*appendFile.txt' -print

bitbake -c package -f cmake-native
find tmp/work -path '*cmake-native*packages-split*appendFile.txt' -print
```

補充：`cmake-native` 的產物主要給 build host sysroot 使用，不一定會進 target image。若目標是讓檔案進 BMC rootfs，應修改 target recipe、image recipe 或 packagegroup。

#### 7.5.6 完整範例：對 zstd 加 patch

```text
meta-my-layer/
└── recipes-extended/
    └── zstd/
        ├── zstd_%.bbappend
        └── zstd/
            └── 0001-fix-platform-build.patch
```

```bitbake
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append = " file://0001-fix-platform-build.patch"
```

驗證：

```bash
bitbake-layers show-appends | grep -A5 -B2 'zstd'
bitbake -c patch -f zstd
bitbake -c compile -f zstd
bitbake zstd
```

若 patch 失敗，先看：

```bash
bitbake -e zstd | grep '^WORKDIR='
find tmp/work -path '*zstd*temp/log.do_patch*' -print
```

常見方向包含 source revision 已變更、patch context 不符合、patch 順序不對、`FILESEXTRAPATHS` 路徑沒對上。

#### 7.5.7 多個 .bbappend 的順序與 layer priority

同一個 recipe 可以被多個 layer 的 `.bbappend` 修改。查看 layer priority：

```bash
bitbake-layers show-layers
```

查看 append：

```bash
bitbake-layers show-appends | grep -A20 -B2 '<recipe>'
```

查看變數最終值：

```bash
bitbake -e <recipe> | less
bitbake -e <recipe> | grep -n '^SRC_URI='
bitbake -e <recipe> | grep -n '^PACKAGECONFIG='
```

建議不要只靠 layer priority 猜結果；以 `bitbake-layers show-appends` 與 `bitbake -e` 展開值為準。若多個 layer 都在改同一變數，盡量用 `:append`、`:prepend`、`:remove` 表達意圖。

#### 7.5.8 常見錯誤與排查

| 現象 | 可能方向 | 檢查方式 |
|------|----------|----------|
| `.bbappend` 沒套上 | 檔名版本不合、layer 未加入、`BBFILES` pattern 不含路徑 | `bitbake-layers show-appends`、`show-layers`、`conf/layer.conf` |
| `No recipes available for ...bbappend` | append 找不到對應 recipe | 確認 recipe 是否存在、版本是否匹配、branch 是否一致 |
| `file://xxx.patch` 找不到 | `FILESEXTRAPATHS` 或目錄結構不對 | `bitbake -e <recipe> | grep '^FILESPATH='` |
| patch 無法套用 | source revision 不符、patch context 改變、patch 順序不對 | `log.do_patch`、`WORKDIR`、`quilt` |
| `do_install` 成功但 package 沒檔案 | 安裝到 `${B}` 而非 `${D}`，或 `FILES:${PN}` 未涵蓋 | `WORKDIR/image`、`packages-split`、`log.do_package_qa` |
| `installed-vs-shipped` QA issue | 檔案進 `${D}` 但沒被任何 package 收走 | 補 `FILES:${PN}:append` 或調整安裝路徑 |
| 修改後結果沒變 | task stamp / sstate 命中，或改到錯的 variant | `bitbake -c cleansstate <recipe>`、`bitbake -e` |
| 只想改 target 卻影響 native | 缺少 class override | 使用 `:class-target` 或 `:class-native` |
| 只想改某板子卻影響全部 machine | 缺少 machine override | 使用 `:append:<machine>` 或 machine-specific 檔案路徑 |

排查順序：

```bash
bitbake-layers show-layers
bitbake-layers show-recipes <recipe>
bitbake-layers show-appends | grep -A10 -B2 '<recipe>'
bitbake -e <recipe> | grep '^FILESPATH='
bitbake -e <recipe> | grep '^SRC_URI='
bitbake -e <recipe> | grep '^PACKAGECONFIG='
bitbake -c patch -f <recipe>
bitbake -c compile -f <recipe>
bitbake -c install -f <recipe>
```

#### 7.5.9 BMC / OpenBMC 常見場景

加入平台設定檔：

```bitbake
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"
SRC_URI:append = " file://platform.conf"

do_install:append() {
    install -d ${D}${sysconfdir}/platform
    install -m 0644 ${WORKDIR}/platform.conf ${D}${sysconfdir}/platform/platform.conf
}

FILES:${PN}:append = " ${sysconfdir}/platform/platform.conf"
```

加入 systemd override：

```bitbake
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"
SRC_URI:append = " file://10-platform.conf"

do_install:append() {
    install -d ${D}${systemd_system_unitdir}/my-service.service.d
    install -m 0644 ${WORKDIR}/10-platform.conf ${D}${systemd_system_unitdir}/my-service.service.d/10-platform.conf
}

FILES:${PN}:append = " ${systemd_system_unitdir}/my-service.service.d/10-platform.conf"
```

加入 kernel config fragment 或 DTS patch：

```bitbake
FILESEXTRAPATHS:prepend := "${THISDIR}/${BPN}:"
SRC_URI:append:my-bmc-machine = " file://my-bmc.cfg"
SRC_URI:append:my-bmc-machine = " file://0001-arm-dts-add-my-platform-sensors.patch"
```

驗證重點：patch 是否套用到正確 kernel source、deploy 的 DTB 是否為目標 machine 使用的 DTB、實機 `/sys/firmware/fdt` 反編譯後是否包含預期 node。

#### 7.5.10 本章重點

1. `.bbappend` 一律放在自己的 layer，不直接修改 upstream / vendor layer。
2. 檔名優先使用 `recipe_%.bbappend`，除非 patch 嚴格綁定特定版本。
3. 有 `file://` patch 或本地檔案時，補上 `FILESEXTRAPATHS`。
4. native / nativesdk 相關 append 優先評估 `${BPN}` 或 `files/` 目錄。
5. 追加 list-like 變數時注意空格，例如 `SRC_URI:append = " file://x.patch"`。
6. 優先使用 `:append`、`:prepend`、`:remove`，非必要不要直接 `=` 覆寫整個變數。
7. 要進 package 的檔案應安裝到 `${D}`，並確認 `FILES:${PN}` 涵蓋該路徑。
8. 用 `:class-target`、`:class-native`、machine override 控制影響範圍。
9. 新增 append 後先跑 `bitbake-layers show-appends`，再用 `bitbake -e` 檢查變數展開值。
10. 修改 recipe 行為後，至少驗證 patch、configure、compile、install、package；若會進 image，再重建 image 或 rootfs。

#### 7.5.11 本章參考資料

- Yocto Project Development Tasks Manual - Understanding and Creating Layers: https://docs.yoctoproject.org/dev-manual/layers.html
- Yocto Project Reference Manual - Append Files: https://docs.yoctoproject.org/ref-manual/terms.html#term-Append-Files
- BitBake User Manual - Syntax and Operators: https://docs.yoctoproject.org/bitbake/bitbake-user-manual/bitbake-user-manual-metadata.html
- Yocto Project Reference Manual - Variables: https://docs.yoctoproject.org/ref-manual/variables.html

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


- Yocto Project Technical Overview: [https://www.yoctoproject.org/development/technical-overview/](https://www.yoctoproject.org/development/technical-overview/)
- Yocto Project Understanding and Creating Layers: [https://docs.yoctoproject.org/dev/dev-manual/layers.html](https://docs.yoctoproject.org/dev/dev-manual/layers.html)
- Yocto Project Building Guide: [https://docs.yoctoproject.org/dev-manual/building.html](https://docs.yoctoproject.org/dev-manual/building.html)
- Poky repository note: [https://git.yoctoproject.org/poky/about/](https://git.yoctoproject.org/poky/about/)
- OpenEmbedded and The Yocto Project: [https://www.openembedded.org/wiki/OpenEmbedded_and_The_Yocto_Project](https://www.openembedded.org/wiki/OpenEmbedded_and_The_Yocto_Project)
- OpenBMC Yocto development: [https://github.com/openbmc/docs/blob/master/yocto-development.md](https://github.com/openbmc/docs/blob/master/yocto-development.md)
