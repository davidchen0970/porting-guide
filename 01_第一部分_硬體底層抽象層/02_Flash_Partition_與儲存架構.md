### 2. Flash Partition 與儲存架構

本章整理 BMC 韌體在 flash / eMMC / SD / SSD 類儲存媒體上的分層架構、分割區規劃、檔案系統選擇、映像格式、更新流程、rollback、資料保存與排查方法。這一章先把名詞分清楚，再談各種 layout，避免把「分割區」、「檔案系統」與「更新包格式」混在同一層討論。

BMC 平台常同時出現 SPI-NOR、SPI-NAND、eMMC、MTD partition、UBI volume、SquashFS、UBIFS、ext4、OverlayFS、`.static.mtd.tar`、`.ubi.mtd.tar`、`.wic`、`fitImage` 等名詞。這些不是同一類東西：有些描述儲存媒體，有些描述空間切割，有些描述可 mount 的檔案系統，有些只是 build / 燒錄 / 更新時使用的封裝格式。若不先建立分層模型，後面排查 rootfs mount failure、update failure、rollback failure、rwfs 滿載或 factory reset 時，很容易找錯層。

#### 2.1 三層模型：分割區、檔案系統、檔案格式

建議先用下列三層模型理解本章：

```text
儲存媒體 / Storage media
    ↓
分割區 / Volume：資料放在哪一段空間
    ↓
檔案系統：這段空間如何被 kernel mount 與讀寫
    ↓
檔案格式 / 映像格式：build、燒錄、更新、傳輸時如何封裝
```

| 層級 | 回答的問題 | 常見例子 | 常見檢查方式 |
| --- | --- | --- | --- |
| 儲存媒體 | 實體或邏輯儲存裝置是什麼？ | SPI-NOR、SPI-NAND、eMMC、SD、SATA SSD、NVMe | schematic、BOM、dmesg、`lsblk`、`cat /proc/mtd` |
| 分割區 / Volume | 資料放在儲存媒體哪一段？ | MTD partition、UBI volume、MBR partition、GPT partition | `/proc/mtd`、`cat /proc/partitions`、`lsblk`、`sfdisk -l`、`sgdisk -p`、`ubinfo -a` |
| 檔案系統 | 分割區 / volume 內如何被 mount 與讀寫？ | SquashFS、JFFS2、UBIFS、ext4、OverlayFS、tmpfs | `findmnt -R /`、`mount`、`cat /proc/mounts`、`dmesg` |
| 檔案格式 / 映像格式 | build output、燒錄檔、更新包長什麼樣子？ | `.squashfs`、`.ubifs`、`.ubi`、`.wic`、`.mtd.tar`、`fitImage`、`MANIFEST` | `file`、`tar tf`、`sha256sum`、`tar xfO image.tar MANIFEST` |

幾個容易混淆的例子：

- `rofs` 通常是 partition / volume name，不是檔案系統名稱。`rofs` 裡常放 SquashFS。
- `rwfs` 也是 partition / volume name，裡面可能是 JFFS2、UBIFS 或 ext4。
- UBI 是 raw flash 上的 volume / wear leveling / bad block 管理層；UBIFS 才是可 mount 的檔案系統。
- `.ubi` 是 UBI image，可能含多個 UBI volume；其中某個 volume 可能放 UBIFS，也可能放 SquashFS。
- `.mtd.tar` 是 OpenBMC 更新包格式，不是檔案系統。
- `.wic` 通常是 disk image，常用於 eMMC / SD 類 block device，裡面可包含 MBR / GPT 與多個 partition。
- OverlayFS 是 runtime merged view，由 lowerdir、upperdir、workdir 組成，不是單一 partition。

#### 2.2 Raw flash 與 block device 的分割方式

BMC 儲存媒體大致可分為 raw flash 類與 block device 類。兩者的分割區描述方式不同，不能直接套同一套名詞。

| 儲存類型 | Linux 視角 | 分割區 / volume 描述方式 | 常見 device | MBR / GPT 適用性 |
| --- | --- | --- | --- | --- |
| SPI-NOR | MTD raw flash | DTS fixed-partitions、U-Boot `mtdparts`、platform flash layout | `/dev/mtd0`、`/dev/mtd1` | 通常不使用 MBR / GPT |
| SPI-NAND / raw NAND | MTD raw flash | MTD partition + UBI volume table | `/dev/mtdX`、`/dev/ubi0_*` | 通常不使用 MBR / GPT |
| eMMC | block device | MBR 或 GPT partition table | `/dev/mmcblk0p1`、`/dev/mmcblk0p2` | 適用，BMC 新平台建議優先 GPT |
| SD / USB mass storage | block device | MBR 或 GPT partition table | `/dev/sdX1`、`/dev/mmcblkXp1` | 適用 |
| SATA / NVMe | block device | MBR 或 GPT partition table | `/dev/sdX1`、`/dev/nvme0n1p1` | 適用 |

##### 2.2.1 MTD partition

MTD partition 用於 raw flash。它描述 flash 上固定 offset 與 size 的區段，常由 Device Tree `fixed-partitions` 或 kernel cmdline `mtdparts` 建立。

```text
mtd0: u-boot
mtd1: u-boot-env
mtd2: kernel
mtd3: rofs
mtd4: rwfs
```

MTD partition 重點：

- offset / size 需對齊 erase block。
- partition name 需與 U-Boot、initramfs、update service 使用的名稱一致。
- raw NAND / SPI-NAND 需另外考慮 bad block、ECC、OOB 與燒錄工具。
- MTD partition 不等同於 filesystem；例如 `mtd3: rofs` 裡可能放 SquashFS raw image。

##### 2.2.2 UBI volume

UBI 通常建立在某個 MTD partition 上，例如 `mtd3: ubi`。UBI attach 後，裡面會有多個 UBI volume。

```text
mtd3: ubi

ubi0:kernel-a
ubi0:rofs-a
ubi0:kernel-b
ubi0:rofs-b
ubi0:rwfs
```

UBI volume 重點：

- UBI 管理 raw flash 的 wear leveling、bad block 與 volume table。
- UBI volume 可分 static / dynamic。readonly image 常用 static volume；可寫資料常用 dynamic volume。
- `rofs-a` 這類 UBI volume 裡可放 SquashFS，並透過 ubiblock 提供 block-like 介面給 kernel mount。
- `rwfs` 這類 UBI volume 則常放 UBIFS。
- UBI volume 不等同於 GPT partition，`ubinfo -a` 才是主要檢查入口。

##### 2.2.3 MBR / GPT partition table

MBR / GPT 用於 block device，例如 eMMC、SD、SATA SSD、NVMe。BMC 若使用 eMMC 作為 rootfs / data 儲存，應在本章明確記錄 partition table 類型。

| 項目 | MBR | GPT |
| --- | --- | --- |
| 適用情境 | legacy boot、舊工具鏈、簡單 partition layout | 新平台、A/B slot、多 partition、需要穩定識別 |
| Partition 數量 | 傳統限制較多 | 支援更多 partition |
| 識別方式 | device node、partition type | PARTUUID、partition name、GUID |
| 備援資訊 | 較少 | 有 primary / backup GPT header |
| BMC 建議 | 除非 bootloader / 工具鏈限制，否則不優先 | eMMC 新平台建議優先評估 |

GPT 對 BMC eMMC 平台通常比較友善，原因如下：

- 可使用 `PARTUUID`，bootargs 比 `/dev/mmcblk0p2` 穩定。
- 可使用 partition name，例如 `rootfs-a`、`rootfs-b`、`rw-data`。
- 適合 A/B slot 與多 partition 規劃。
- 有 primary / backup GPT header，便於偵測 partition table 損壞。
- Yocto `.wic` 常用於產生含 partition table 的 eMMC / SD image。

注意：MBR / GPT 只描述 block device 上的 partition table，不等同於檔案系統，也不等同於 update image format。

例如 eMMC 上可能是：

```text
GPT partition table
  ├─ rootfs-a partition：裡面放 SquashFS 或 ext4
  ├─ rootfs-b partition：裡面放 SquashFS 或 ext4
  └─ rw-data partition：裡面放 ext4

build output：obmc-phosphor-image-<machine>.wic
```

同樣地，SPI-NOR / SPI-NAND 這類 raw flash 通常不使用 MBR / GPT：

```text
SPI-NOR：DTS fixed-partitions / U-Boot mtdparts → MTD partitions
SPI-NAND：DTS fixed-partitions / U-Boot mtdparts → MTD partition → UBI volumes
```

#### 2.3 檔案系統選型

檔案系統決定 partition / volume 內的資料如何被 kernel mount 與讀寫。選型時需考量媒體類型、是否可寫、容量、power loss、wear、更新方式與資料保存政策。

| 檔案系統 / Layer | 適用媒體 | 常見用途 | 優點 | 注意事項 |
| --- | --- | --- | --- | --- |
| SquashFS | MTD / UBI static volume / block partition | readonly rootfs | 壓縮率高、內容固定、適合 image 更新 | 不可直接寫；需搭配 OverlayFS 或重新產生 image |
| JFFS2 | MTD raw flash | 小型 writable partition | 架構簡單、適合小 NOR | mount / scan 成本與容量相關；大型 NAND 不建議優先選 |
| UBI | MTD raw flash | volume / wear leveling / bad block 管理 | raw NAND / SPI-NAND 友善 | 不是 filesystem；需設定 PEB、LEB、VID header、volume |
| UBIFS | UBI dynamic volume | `/var`、persistent config、rwfs | 支援 journal / compression，適合 raw flash | 不適用 eMMC / block device |
| ubiblock + SquashFS | UBI static volume | raw flash 上的 readonly rootfs | 讓 SquashFS 放在 UBI volume 內 | rootfs volume、bootcmd、bootargs 需一致 |
| ext4 | block device | eMMC rootfs / data / log | 成熟、工具完整 | 需規劃 journal、fsck、power loss、wear |
| OverlayFS | lower + upper filesystem | readonly rootfs + writable upper | rootfs 可保持唯讀，變更落在 upper | upperdir / workdir 需在同一 filesystem，空間需監控 |
| tmpfs | RAM | `/run`、`/tmp`、暫存上傳 image | 不寫 flash | 受 RAM 限制，重開機即消失 |

OverlayFS 建議明確記錄 lower / upper / workdir：

```text
lowerdir: readonly rootfs，例如 SquashFS
upperdir: writable data，例如 UBIFS / JFFS2 / ext4
workdir : 與 upperdir 位於同一 filesystem 的工作目錄
merged  : userspace 看到的 root filesystem
```

排查 rootfs 可寫資料遺失時，不能只看 `rofs` 是否正常，還要查 OverlayFS 是否正確掛載、upper filesystem 是否可寫、space / inode 是否滿載。

```sh
findmnt -R /
cat /proc/mounts | grep -E 'overlay|squashfs|ubifs|jffs2|ext4'
dmesg | grep -Ei 'overlay|squashfs|ubi|ubifs|jffs2|ext4'
df -h
df -i
```

#### 2.4 檔案格式 / 映像格式

檔案格式 / 映像格式是 build、燒錄、更新、傳輸時的封裝方式，不一定等同 target 上最後 mount 的 filesystem。

| 格式 | 層級 | 常見用途 | 注意事項 |
| --- | --- | --- | --- |
| `.squashfs` | filesystem image | readonly rootfs | 可被放入 MTD partition、UBI volume 或 block partition |
| `.ext4` | filesystem image | eMMC rootfs / data | 通常寫入 block partition 或包入 `.wic` |
| `.ubifs` | filesystem image | UBIFS volume 內容 | 需搭配正確 `mkfs.ubifs` 參數 |
| `.ubi` | UBI image | 內含 UBI volume table 與 volumes | 不是 UBIFS；可能包含 SquashFS volume 與 UBIFS volume |
| `.wic` | disk image | eMMC / SD 類整碟映像 | 通常含 MBR / GPT 與多個 partition |
| `.mtd` / raw image | raw flash image | 工廠燒錄或整顆 flash image | raw NAND 場景需確認 bad block / ECC / OOB policy |
| `.static.mtd.tar` | update package | OpenBMC static MTD 更新包 | tar 內通常含 partition image 與 MANIFEST |
| `.ubi.mtd.tar` | update package | OpenBMC UBI layout 更新包 | tar 內檔案需對應 updater 期待的 partition / volume |
| `fitImage` | boot image container | kernel / DTB / initramfs bundle，可搭簽章 | bootcmd、load address、signature policy 需對齊 |
| `.dtb` | hardware description blob | Device Tree binary | kernel 實際載入哪一份 DTB 需確認 |
| `MANIFEST` | metadata | version、purpose、MachineName、簽章資訊 | update service 驗證依據之一 |

常見對照：

```text
範例 A：SPI-NOR static MTD
  儲存媒體：SPI-NOR
  分割區：mtd3 = rofs
  檔案系統：SquashFS
  映像檔：obmc-phosphor-image-<machine>.squashfs
  更新包：obmc-phosphor-image-<machine>.static.mtd.tar

範例 B：SPI-NAND UBI
  儲存媒體：SPI-NAND
  MTD 分割區：mtd3 = ubi
  UBI volume：ubi0:rofs-a、ubi0:rwfs
  檔案系統：rofs-a 內為 SquashFS，rwfs 內為 UBIFS
  映像檔：obmc-phosphor-image-<machine>.ubi
  更新包：obmc-phosphor-image-<machine>.ubi.mtd.tar

範例 C：eMMC GPT A/B
  儲存媒體：eMMC
  Partition table：GPT
  分割區：rootfs-a、rootfs-b、rw-data
  檔案系統：rootfs-a/b 可為 SquashFS 或 ext4，rw-data 可為 ext4
  映像檔：obmc-phosphor-image-<machine>.wic
```

#### 2.5 設計目標與分區原則

Flash / storage layout 的設計目標不是只讓 image 能開機，而是要同時滿足可更新、可回復、可保存、可追蹤與安全需求。

| 目標 | 說明 | 常見設計手段 |
| --- | --- | --- |
| 可開機 | BootROM、SPL、U-Boot、kernel、DTB、rootfs offset 正確 | 固定 offset、DTS fixed-partitions、U-Boot mtdparts / bootargs、GPT PARTUUID |
| 可更新 | 支援 Redfish / Web / scp / TFTP / local update | image manifest、software manager、A/B slot、activation state |
| 可回復 | 更新失敗可回到前一版或 golden image | boot attempt counter、boot priority、rollback policy、recovery partition |
| 可保存 | 網路設定、使用者、SSH key、FRU cache、event log 不因更新消失 | rwfs、persistent volume、白名單搬移、factory reset policy |
| 可控風險 | 降低任意寫入 rootfs、power loss、wear 對系統的影響 | readonly rootfs、OverlayFS、UBI、fsync policy、log rotation |
| 可追蹤 | 現場能判讀目前 running slot、image version、partition map | `/proc/mtd`、`lsblk`、`ubinfo`、`fw_printenv`、manifest、os-release、journal |
| 安全 | 支援 secure boot、image signature、anti-rollback、field mode | 簽章驗證、唯讀 golden image、rollback index、write protect |

分區規劃建議：

- BootROM 會讀取的區域需符合 SoC datasheet / BootROM 要求的 offset、header、alignment 與 media type。
- bootloader 與 bootloader env 分開管理；env 應有 CRC / redundant env 或可恢復預設值。
- kernel、DTB、rootfs 與 rw data 需明確切開，避免更新 rootfs 時碰到 persistent data。
- readonly rootfs 建議使用 SquashFS / EROFS / dm-verity 類設計，將內容變更收斂到正式 image build。
- writable data 需依資料重要性分層，不建議把大量 log、dump、temporary image 與永久設定放在同一小區域。
- raw NAND / SPI-NAND 需要將 bad block、ECC、OOB、VID header offset、PEB / LEB size 納入規劃。
- eMMC / SD / SSD 類 block device 需考量 MBR / GPT、fsck、journal、power loss、wear 與 discard / trim policy。
- BMC 新平台若使用 eMMC，建議優先評估 GPT，並使用 PARTUUID / UUID / label，避免 device enumeration 改變導致 rootfs 找錯。
- A/B slot 需要一套明確的「誰選 slot、誰標記成功、誰回退」機制，不能只把分區複製兩份。
- Golden image / recovery image 若作為最後救援入口，應有 write protect 或更新權限控管。
- 每次更動分區表、image type、U-Boot env、DTS fixed-partitions、`.wks` 或 update script，都要同步更新本章表格與測試紀錄。

#### 2.6 常見 BMC Flash / Storage Layout 模式

##### 2.6.1 SPI-NOR + static MTD

適用於 SPI-NOR 容量有限、平台更新流程相對單純的情境。

```text
0x00000000  u-boot          fixed, bootloader
0x00100000  u-boot-env      fixed, boot variables
0x00120000  kernel          Linux kernel / fitImage
0x00720000  rofs            SquashFS readonly rootfs
0x03920000  rwfs            JFFS2 / writable overlay
```

Bring-up 重點：

- DTS fixed-partitions、U-Boot mtdparts、kernel bootargs、image package 內的 partition name 必須一致。
- `/proc/mtd` 中 partition name 需與 init script / update script 使用的名稱一致，例如 `kernel`、`rofs`、`rwfs`。
- U-Boot env offset / size 不可與其他分區重疊；若有 redundant env，兩份 env 都要列入表格。
- `rwfs` 若使用 JFFS2，需確認 erase block size、cleanmarker、mount time 與容量是否符合需求。
- log 與 dump 優先放 tmpfs 或外部收集系統，避免小 NOR 上的 `rwfs` 被寫滿。

##### 2.6.2 SPI-NAND / raw NAND + UBI

適用於 raw flash 容量較大且需要 wear leveling 的平台。典型架構會將一段 MTD partition attach 成 UBI device，內含多個 UBI volume。

```text
MTD partitions:
  mtd0: u-boot
  mtd1: u-boot-env
  mtd2: fit / kernel fallback
  mtd3: ubi

UBI volumes on mtd3:
  kernel-a     static / dynamic volume, FIT or kernel
  rofs-a       static volume, SquashFS via ubiblock
  kernel-b     static / dynamic volume
  rofs-b       static volume, SquashFS via ubiblock
  rwfs         dynamic volume, UBIFS
```

Bring-up 重點：

- 確認 BootROM 與 U-Boot 是否能處理 SPI-NAND 的 ECC、OOB 與 bad block policy。
- 初次燒錄需使用適合 UBI 的工具與參數，例如 `ubiformat` / `ubinize` / platform flash writer。
- kernel bootargs 常見包含 `ubi.mtd=`、`root=`、`rootfstype=ubifs` 或 `root=/dev/ubiblockX_Y`。
- UBI attach log 對排查很重要，需留意 PEB size、LEB size、VID header offset、bad PEB、volume table。
- 不建議把 UBIFS 映像用一般 block 寫入方式直接 `dd` 到 raw NAND；需確認工具是否保留 UBI / ECC / bad block 語意。

##### 2.6.3 eMMC + MBR / GPT + ext4 / SquashFS

適用於需要大容量、較多 log / dump / factory data 的平台。eMMC 是 block device，底層已有 FTL，因此不使用 UBIFS。

```text
/dev/mmcblk0boot0      optional bootloader area
/dev/mmcblk0boot1      optional backup bootloader area
/dev/mmcblk0p1         boot / EFI / FIT / kernel
/dev/mmcblk0p2         rootfs-a
/dev/mmcblk0p3         rootfs-b
/dev/mmcblk0p4         rw-data
/dev/mmcblk0p5         logs / dumps / factory, optional
```

建議：

- 新平台優先評估 GPT；若使用 MBR，需留下 bootloader / tool 限制原因。
- bootargs 優先使用 PARTUUID / UUID / label，避免 `/dev/mmcblk0pX` 編號變動造成 rootfs 找錯。
- 若用 `.wic` 產生 eMMC image，需保存 `.wks`、partition label、partition type、alignment、filesystem type。
- ext4 需評估 journal mode、commit interval、fsck policy、systemd mount timeout 與突然斷電測試結果。
- 若使用 dm-verity / signed rootfs，rootfs partition 應保持唯讀，persistent data 放獨立 partition。
- eMMC health / lifetime estimate 若可讀，應納入量產診斷與現場 log。

##### 2.6.4 SPI-NOR + eMMC 混合架構

部分 SoC BootROM 只支援從 SPI-NOR 啟動，但平台需要較大 rootfs / data 空間，此時常見做法是 SPI-NOR 放 bootloader / recovery，eMMC 放 kernel / rootfs / data。

| 區域 | 媒體 | 用途 | 風險 |
| --- | --- | --- | --- |
| BootROM 讀取區 | SPI-NOR | SPL / U-Boot | SPI-NOR layout 與 recovery 需穩定 |
| Boot config | SPI-NOR / U-Boot env | root device、slot metadata | env 損壞可能造成找不到 eMMC |
| rootfs-a/b | eMMC GPT partition | A/B rootfs | bootargs / PARTUUID 需對齊 |
| rw-data | eMMC GPT partition | persistent data | factory reset 範圍需明確 |
| recovery | SPI-NOR 或 eMMC | rescue image | 需定義入口與退出條件 |

#### 2.7 A/B slot、Golden image 與 rollback

A/B slot 的核心是「新 image 先寫到非目前 running slot，下一次開機試跑新 slot，確認成功後才標記為穩定」。可套用於 MTD、UBI 或 eMMC，但所需 metadata 與 bootloader policy 需提早定義。

| 項目 | 建議定義 |
| --- | --- |
| Slot 名稱 | A/B、primary/backup、image0/image1，需全文件一致 |
| Slot 內容 | kernel、DTB、rootfs 是否都雙份；rwfs 是否共用 |
| Boot selection | U-Boot env、CPLD register、bootloader metadata、GPT partition attribute、software manager |
| Trial boot | 新 slot 啟動前是否設定 bootcount / upgrade_available |
| Success criteria | systemd target 到達、BMC service ready、network ready、版本暴露成功 |
| Mark-good 時機 | 首次成功 boot 後由 userspace 或 update manager 寫回 env / metadata |
| Rollback 條件 | kernel panic、rootfs mount 失敗、watchdog reset、mark-good timeout |
| Persistent data | 更新與 rollback 期間是否共用，schema migration 如何處理 |
| 安全政策 | anti-rollback index、簽章驗證、field mode、golden image 更新權限 |

常見風險：

- rootfs A/B 有做，但 kernel / DTB 仍只用單份，導致 rollback 不完整。
- U-Boot env 更新中斷後無法判斷 active slot；建議評估 redundant env 或 metadata journal。
- userspace 未完成 mark-good，但 watchdog timeout 太短，造成反覆回退。
- rwfs 共用後，新版 service 寫入的設定與舊版 service 不相容；需有 migration / downgrade policy。
- eMMC GPT A/B 若只靠 partition number，不使用 PARTUUID / label，後續調整 partition table 時容易造成 bootargs mismatch。

Golden / recovery image 建議：

- Golden image 預設唯讀，更新流程需有明確授權、簽章與維修程序。
- Golden image 功能可精簡，但至少應具備網路、更新服務、基本 shell / serial、版本資訊與硬體識別能力。
- 若 golden image 與 production image 共用 rwfs，需避免 rescue flow 寫壞 production 設定。
- 需定義啟動條件：strap、GPIO、CPLD register、bootcount failed、手動指令、watchdog rollback。
- 需定義退出條件：成功重新刷寫 production image 後是否自動切回 primary。

#### 2.8 分區表與平台必填資料

Bring-up 前至少填完下表，並在每次更動 image layout / U-Boot env / DTS / `.wks` / update service 後更新。

| 項目 | 目前平台值 | 資料來源 | 責任窗口 | 狀態 |
| --- | --- | --- | --- | --- |
| Boot media 類型 | [待填] | schematic / BOM / SoC strap | HW / BMC | [待確認] |
| Flash / eMMC 型號 | [待填] | BOM / jedec id / ext_csd | HW | [待確認] |
| 容量 | [待填] | datasheet / kernel log | HW / BMC | [待確認] |
| Raw flash erase block / page size | [待填] | datasheet / mtdinfo | BMC | [待確認] |
| Block device sector size | [待填] | lsblk / sysfs | BMC | [待確認] |
| ECC / OOB policy | [待填] | SoC BSP / NAND datasheet | BMC / HW | [待確認] |
| MBR / GPT | [待填] | `sfdisk -l` / `sgdisk -p` / `.wks` | BMC | [待確認] |
| U-Boot env offset / size | [待填] | U-Boot config / fw_env.config | BMC | [待確認] |
| Redundant env | [待填] | U-Boot config | BMC | [待確認] |
| Partition source | DTS / mtdparts / UBI volume / MBR / GPT [待填] | DTS / bootargs / build artifacts | BMC | [待確認] |
| Update image type | static.mtd.tar / ubi.mtd.tar / wic / custom [待填] | tmp/deploy/images | BMC | [待確認] |
| A/B slot | 有 / 無 [待填] | update design | BMC / PM | [待確認] |
| Golden / recovery image | 有 / 無 [待填] | schematic / image layout | BMC / HW | [待確認] |
| Persistent data policy | rwfs / overlay / whitelist [待填] | init script / service config | BMC | [待確認] |
| Factory reset scope | [待填] | product policy | BMC / PM / Security | [待確認] |
| Secure boot / signature | [待填] | security design | Security / BMC | [待確認] |
| Rollback policy | [待填] | update design | BMC / QA | [待確認] |

分區明細範本：

| 名稱 | Device / Volume | Offset / Start | Size | Partition table / Volume layer | FS | Mount point | 更新時是否覆寫 | 保存策略 | 備註 |
| --- | --- | ---: | ---: | --- | --- | --- | --- | --- | --- |
| u-boot | mtd0 | [待填] | [待填] | MTD | none | N/A | 預設否 | golden / factory tool | BootROM 讀取路徑 |
| u-boot-env | mtd1 | [待填] | [待填] | MTD | env | N/A | 依流程 | redundant env [待填] | fw_env.config 需對齊 |
| kernel-a | mtd2 / ubi volume / p1 | [待填] | [待填] | MTD / UBI / GPT | FIT / Image | N/A | 是 | A slot | [待填] |
| rofs-a | mtd3 / ubi volume / p2 | [待填] | [待填] | MTD / UBI / GPT | SquashFS / ext4 | / lower | 是 | A slot | [待填] |
| kernel-b | [待填] | [待填] | [待填] | [待填] | [待填] | N/A | 是 | B slot | [待填] |
| rofs-b | [待填] | [待填] | [待填] | [待填] | SquashFS / ext4 | / lower | 是 | B slot | [待填] |
| rwfs / rw-data | [待填] | [待填] | [待填] | MTD / UBI / GPT | JFFS2 / UBIFS / ext4 | /var、/etc overlay | 否 | 保存 | 需監控容量與 inode |
| logs / dumps | [待填] | [待填] | [待填] | block / UBI | ext4 / UBIFS | /var/log / dumps | 視政策 | 可清除 | 避免擠壓設定空間 |
| recovery | [待填] | [待填] | [待填] | [待填] | [待填] | rescue root | 預設否 | write protect | [待填] |

#### 2.9 Device Tree、U-Boot、Yocto 與 update service 對齊

Flash / storage layout 可能同時出現在 DTS、U-Boot env、Yocto image recipe、`.wks`、initramfs script、update service 與文件中。排查時需先確認「哪一份資料是目前 running image 實際使用的來源」。

| 來源 | 檔案 / 指令 | 作用 |
| --- | --- | --- |
| Device Tree fixed-partitions | `arch/.../dts/*.dts` | raw flash 上建立 `/proc/mtd` partition |
| U-Boot mtdparts | `printenv mtdparts` / `bootargs` | bootloader 與 kernel partition 傳遞 |
| U-Boot env config | `/etc/fw_env.config` | Linux userspace 讀寫 env offset |
| UBI config | ubinize cfg / image recipe | 建立 UBI volume table 與 volume 內容 |
| WIC layout | `.wks` / image recipe | 建立 eMMC / SD disk image、MBR / GPT、partition filesystem |
| Initramfs / preinit | obmc init scripts、preinit-mounts | 掛載 rofs / rwfs / overlay |
| Update service | phosphor-bmc-code-mgmt / platform updater | 擷取 tar、驗證 manifest、寫入分區 / volume |

DTS fixed-partitions 範例：

```dts
&fmc {
    status = "okay";

    flash@0 {
        status = "okay";
        m25p,fast-read;
        label = "bmc";

        partitions {
            compatible = "fixed-partitions";
            #address-cells = <1>;
            #size-cells = <1>;

            uboot@0 {
                label = "u-boot";
                reg = <0x00000000 0x00100000>;
                read-only;
            };

            uboot_env@100000 {
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

fw_env.config 範例：

```text
# device       offset      env-size    sector-size
/dev/mtd1      0x0000      0x10000     0x10000
# redundant env 範例：
# /dev/mtd2    0x0000      0x10000     0x10000
```

eMMC / GPT bootargs 建議：

```text
root=PARTUUID=<rootfs-a-partuuid> rootfstype=squashfs ro
# 或
root=UUID=<rootfs-uuid> rootwait ro
```

檢查重點：

- raw flash：DTS partition label、U-Boot `mtdparts`、update package 內名稱需一致。
- UBI：`ubi.mtd=`、volume name、ubinize cfg、update service target 需一致。
- eMMC：`.wks`、GPT partition name、PARTUUID、bootargs、systemd mount unit 需一致。
- A/B：active slot metadata、bootargs、軟體 inventory、functional association 需能互相對照。

#### 2.10 Build 與 image 產出檢查

常用檢查：

```sh
# build 端：確認 image type 與輸出
bitbake -e obmc-phosphor-image | grep '^IMAGE_FSTYPES='
bitbake -e obmc-phosphor-image | grep -E '^(MACHINE|DISTRO|FLASH_SIZE|IMAGE_ROOTFS_SIZE)='
ls -lh tmp/deploy/images/${MACHINE}/

# 檢查 tar 內容與 manifest
tar tf tmp/deploy/images/${MACHINE}/*.mtd.tar | sort
tar xfO tmp/deploy/images/${MACHINE}/*.mtd.tar MANIFEST

# 檢查常見 image
ls -lh tmp/deploy/images/${MACHINE}/*{squashfs,ubi,wic,ext4,mtd.tar} 2>/dev/null

# 若是 wic image，可進一步檢查 partition table
wic ls tmp/deploy/images/${MACHINE}/*.wic 2>/dev/null || true
```

需保存：

| 資料 | 範例指令 | 用途 |
| --- | --- | --- |
| image manifest | `tar xfO image.tar MANIFEST` | 驗證 version、purpose、MachineName、KeyType |
| image type | `bitbake -e image | grep IMAGE_FSTYPES` | 確認 static / UBI / wic |
| partition config | DTS、ubinize cfg、`.wks` | 確認 layout source |
| U-Boot config | grep `CONFIG_ENV_`、`CONFIG_BOOTCOUNT` | 確認 env / bootcount / A/B policy |
| kernel config | grep MTD、UBI、UBIFS、OVERLAY_FS、EXT4、MMC | 確認 filesystem / media 支援 |
| deploy checksum | `sha256sum image` | 現場比對 |

#### 2.11 Target 端檢查指令與 log 收集

##### 2.11.1 Partition / volume / filesystem

```sh
# raw flash / MTD
cat /proc/mtd
mtdinfo -a 2>/dev/null

# UBI / UBIFS
ubinfo -a 2>/dev/null
cat /sys/class/ubi/ubi*/mtd_num 2>/dev/null
cat /sys/class/ubi/ubi*/volumes_count 2>/dev/null

# block device / MBR / GPT
cat /proc/partitions
lsblk -f 2>/dev/null
blkid 2>/dev/null
sfdisk -l 2>/dev/null
sgdisk -p /dev/mmcblk0 2>/dev/null || true

# mount 與空間
findmnt -R /
mount
cat /proc/mounts
df -h
df -i
```

##### 2.11.2 Kernel log pattern

```sh
dmesg | grep -Ei 'mtd|spi-nor|spi.*nand|nand|ubi|ubifs|jffs2|squashfs|overlay|mmc|gpt|mbr|partition|ext4|verity|vfs'
dmesg -T > /tmp/dmesg-storage.txt
journalctl -b > /tmp/journal-storage.txt
```

| Log pattern | 可能方向 | 後續檢查 |
| --- | --- | --- |
| `mtd: partition ... extends beyond the end` | DTS / mtdparts size 超出 flash | 核對 flash size、partition offset |
| `spi-nor ... unrecognized JEDEC id` | flash 型號或 SPI wiring / mode 問題 | JEDEC ID、DTS compatible、SPI clock |
| `UBI error: bad VID header offset` | ubinize / kernel UBI 參數不一致 | VID header、min_io_size、sub-page |
| `UBI: attaching mtdX` 後失敗 | bad block、ECC、volume table 問題 | mtdinfo、ubiformat、flash dump |
| `UBIFS error` | UBIFS metadata 或 mount 參數問題 | ubinfo、journal、power loss 歷史 |
| `SQUASHFS error` | rofs 損壞或讀取錯誤 | image checksum、flash readback |
| `overlayfs: upper fs does not support xattr` | upper filesystem 不符合 OverlayFS 需求 | rwfs filesystem、mount option |
| `VFS: Cannot open root device` | root= / rootfstype / initramfs 錯 | bootargs、initramfs、partition name |
| `GPT: Use GNU Parted to correct GPT errors` | GPT header / backup table 異常 | `sgdisk -v`、image / flash readback |
| `EXT4-fs warning/error` | eMMC / ext4 / power loss 問題 | fsck、eMMC health、journal policy |

##### 2.11.3 U-Boot env 與 slot 狀態

```sh
fw_printenv 2>/tmp/fw_printenv.err | sort
cat /tmp/fw_printenv.err
fw_printenv bootcount upgrade_available bootlimit 2>/dev/null
fw_printenv obmc_bootpart openbmconce bootargs mtdparts 2>/dev/null
```

若 `fw_printenv` 失敗，先檢查：

```sh
cat /etc/fw_env.config
cat /proc/mtd
hexdump -C /dev/mtdX | head
```

##### 2.11.4 OpenBMC software update 狀態

```sh
busctl tree xyz.openbmc_project.Software.BMC.Updater 2>/dev/null
busctl tree xyz.openbmc_project.Software.Version 2>/dev/null
busctl tree xyz.openbmc_project.Software.Activation 2>/dev/null
systemctl status phosphor-bmc-code-mgmt.service --no-pager 2>/dev/null
journalctl -u phosphor-bmc-code-mgmt.service -b --no-pager 2>/dev/null | tail -200
journalctl -b --no-pager | grep -Ei 'software|activation|updater|image|manifest|version|flash|mtd|ubi|wic|gpt|partition' | tail -300
```

#### 2.12 更新流程與 rollback 驗證

更新流程建議拆成「上傳、驗證、寫入、切換、重開機、mark-good、清理」幾段，各段都應有 log 與失敗回復策略。

| 階段 | 檢查項目 | 需要保存的 log / 狀態 |
| --- | --- | --- |
| 上傳 | image 是否完整、空間是否足夠 | `/tmp/images`、`df -h`、bmcweb log |
| 驗證 | manifest、MachineName、purpose、signature | MANIFEST、journal、activation object |
| 寫入 | 目標 slot、partition / volume、進度 | activation progress、dmesg、updater journal |
| 切換 | U-Boot env / boot metadata / GPT slot metadata | `fw_printenv` before/after、slot metadata |
| 重開機 | 是否從新 slot 開機 | UART log、bootargs、`/proc/cmdline` |
| mark-good | 成功條件是否達成 | systemd ready、software active / functional association |
| rollback | 失敗時是否回到前一 slot | bootcount、watchdog reset reason、previous slot boot log |
| 清理 | 非 running image 是否可刪除 | software inventory、flash free space |

最小驗證矩陣：

| 測試 | 預期結果 | 備註 |
| --- | --- | --- |
| 同版更新 | 可完成 activation，重開後版本一致 | 驗證基本流程 |
| 升版更新 | 新 slot 開機並標記 functional | 保存 before / after manifest |
| 降版更新 | 依 policy 允許或拒絕 | 若有 anti-rollback 需明確記錄 |
| 更新中斷電 | 不應造成雙 slot 都不可開機 | AC loss timing 需記錄 |
| 寫入中 BMC reset | 可回到舊版或繼續處理 | 觀察 update metadata |
| 新 image kernel panic | bootloader 回退到舊 slot | 需驗證 bootcount / watchdog |
| 新 image userspace fail | 未 mark-good 時回退或停留救援 | 需定義 timeout |
| rwfs 滿載 | update 應拒絕或清楚報錯 | `df -h` / journal |
| factory reset | 只清指定資料，不破壞 image | 驗證保留清單 |
| golden boot | 可進救援 image 並重新刷寫 | 測試手動 / 自動入口 |

#### 2.13 Persistent data、log 與 factory reset

| 資料類型 | 常見路徑 | 是否應保留於更新 | Factory reset 是否清除 | 備註 |
| --- | --- | --- | --- | --- |
| Network config | `/etc/systemd/network`、network manager state | 是 | 視產品需求 | 現場管理連線依賴此資料 |
| User / password | `/etc/passwd`、`/etc/shadow`、使用者資料庫 | 是 | 通常清除或回預設 | 需符合安全政策 |
| SSH host key | `/etc/ssh/ssh_host_*` | 是 | 視安全政策 | 清除後 client 會看到 host key 變更 |
| TLS certificate | `/etc/ssl`、`/var/lib` | 是 | 視產品需求 | 需避免私鑰外洩 |
| FRU cache | `/var/lib`、Entity Manager cache | 通常是 | 視來源 | 若可由 EEPROM 重建，可清除 |
| SEL / event log | `/var/log`、phosphor-logging | 視產品需求 | 通常可清除 | 需定義容量與輪替 |
| Crash dump | `/var/lib/systemd/coredump`、`/var/dump` | 視需求 | 可清除 | 避免佔滿 rwfs |
| Firmware staging | `/tmp/images`、`/var/tmp` | 否 | 可清除 | 優先放 tmpfs 或 staging partition |
| Factory data | `/var/lib/factory`、VPD backup | 是 | 通常不可清除 | 建議獨立分區或保護機制 |
| Calibration data | `/var/lib/platform/calibration` | 是 | 通常不可清除 | sensor / fan / power policy 可能使用 |

建議：

- 對每個保存資料建立 owner、路徑、格式版本、migration policy 與 reset policy。
- rwfs 空間需設定監控與 log rotation，避免 event log 或 dump 佔滿導致 service 寫入失敗。
- Factory reset 不應等同於 erase all flash；需明確列出可清與不可清資料。
- 若支援 downgrade，需定義新舊版本設定檔相容性；必要時保留版本戳記與 migration log。

#### 2.14 常見問題與排查入口

| 現象 | 可能方向 | 第一輪檢查 |
| --- | --- | --- |
| `/proc/mtd` 分區名稱不對 | DTS fixed-partitions 未更新，或 bootargs mtdparts 覆蓋 | dmesg、`/proc/cmdline`、DTB 反編譯 |
| `lsblk` 看不到預期 partition | `.wic` / GPT / MBR / eMMC probe 問題 | dmesg mmc、`sfdisk -l`、`sgdisk -p` |
| U-Boot 能讀 flash，但 kernel 找不到 rootfs | bootargs root= / ubi.mtd / rootfstype / PARTUUID 不對 | `printenv bootargs`、dmesg、`/proc/mtd`、`blkid` |
| 更新後仍開舊版 | slot metadata 未切換、mark-good / priority 未更新 | `fw_printenv`、software association、UART boot log |
| 更新後無法開機 | kernel / DTB / rofs slot 不一致 | dump active slot offset、比對 manifest |
| rwfs 掛載失敗 | JFFS2 / UBIFS / ext4 metadata 問題 | dmesg filesystem log、mtdinfo / fsck |
| OverlayFS 沒套上 | initramfs / preinit mount 順序錯、upper 不支援 xattr | `findmnt`、journal、dmesg overlayfs |
| `fw_printenv` 讀不到 | `fw_env.config` 錯或 env CRC 壞 | `/etc/fw_env.config`、U-Boot `printenv` |
| UBI attach 失敗 | ubinize 參數、VID header、bad block、ECC 不一致 | dmesg UBI、`ubinfo`、`mtdinfo` |
| SquashFS error | rofs 寫入不完整、flash read error、offset 錯 | sha256、mtd readback、dmesg |
| eMMC rootfs 偶發 read-only | ext4 journal / eMMC health / power loss | dmesg ext4/mmc、fsck、EXT_CSD |
| GPT warning / partition table mismatch | `.wic` 寫入不完整、backup header 未修正、容量不同 | `sgdisk -v`、`sfdisk -l`、reflash image |
| update tar 被拒絕 | MANIFEST MachineName / purpose / signature 不符 | updater journal、`tar xfO MANIFEST` |
| factory reset 後不可登入 | reset scope 清掉必要帳號或網路設定 | reset script、保留清單、journal |

#### 2.15 Bring-up 建議流程

1. 確認 media：SPI-NOR、SPI-NAND、eMMC、SD、SSD，並記錄型號、容量、電壓、strap。
2. 依 media 選分割方式：raw flash 使用 MTD / UBI；block device 使用 MBR / GPT。
3. 確認 filesystem：rofs / rwfs / data / log 各自使用 SquashFS、JFFS2、UBIFS、ext4 或 OverlayFS。
4. 確認映像格式：static mtd、UBI、wic、raw image、update tar、MANIFEST。
5. 對齊 partition source：DTS、U-Boot mtdparts、U-Boot env、`.wks`、ubinize cfg、Yocto image layout、update script。
6. 確認 kernel support：SPI-NOR / NAND / eMMC、MTD、UBI、UBIFS、SquashFS、OverlayFS、ext4、MMC、partition parser。
7. boot 一次乾淨 image，保存 UART、dmesg、`/proc/mtd`、`/proc/cmdline`、`findmnt`、`df`、`lsblk`、`ubinfo`。
8. 驗證 rwfs / overlay：建立檔案、重開機後確認保留，factory reset 後確認清除範圍。
9. 驗證更新：同版、升版、失敗回復、斷電、watchdog、rollback。
10. 驗證 golden / recovery：手動入口、自動入口、重新刷寫 production image。
11. 長測：AC cycle、BMC reboot、update loop、rwfs fill、log rotation、power loss。
12. 文件收斂：更新本章分區表、log、版本、owner 與已知限制。

#### 2.16 當前平台 Flash / Storage 實測表

| 項目 | 指令 / 來源 | 實測值 | 備註 |
| --- | --- | --- | --- |
| BMC image version | `cat /etc/os-release` | [待填] | VERSION_ID / BUILD_ID |
| Kernel version | `uname -a` | [待填] | 需對應 DTS commit |
| Bootargs | `cat /proc/cmdline` | [待填] | root= / ubi.mtd / mtdparts / PARTUUID |
| Raw flash partition | `cat /proc/mtd` | [待填] | raw flash 平台必填 |
| Block partition | `lsblk -f`; `sfdisk -l`; `sgdisk -p` | [待填] | eMMC / SD / SSD 平台必填 |
| Mount tree | `findmnt -R /` | [待填] | rofs / rwfs / overlay |
| Disk usage | `df -h`; `df -i` | [待填] | rwfs inode 也需看 |
| U-Boot env | `fw_printenv` | [待填] | 保存 before / after update |
| UBI info | `ubinfo -a` | [待填] | UBI 平台必填 |
| eMMC info | `mmc extcsd read` / sysfs | [待填] | eMMC 平台必填 |
| Update inventory | `busctl tree` / software objects | [待填] | active / functional association |
| Redfish UpdateService | curl UpdateService | [待填] | 若平台支援 Redfish |
| Golden image entry | strap / env / GPIO / CPLD | [待填] | 手動與自動入口 |
| Factory reset result | reset 後 diff | [待填] | 確認保留清單 |

建議保存 log 套件：

```sh
mkdir -p /tmp/storage-debug
cat /etc/os-release > /tmp/storage-debug/os-release.txt
uname -a > /tmp/storage-debug/uname.txt
cat /proc/cmdline > /tmp/storage-debug/proc-cmdline.txt
cat /proc/mtd > /tmp/storage-debug/proc-mtd.txt 2>&1
cat /proc/partitions > /tmp/storage-debug/proc-partitions.txt
findmnt -R / > /tmp/storage-debug/findmnt.txt
mount > /tmp/storage-debug/mount.txt
df -h > /tmp/storage-debug/df-h.txt
df -i > /tmp/storage-debug/df-i.txt
fw_printenv > /tmp/storage-debug/fw_printenv.txt 2>&1
mtdinfo -a > /tmp/storage-debug/mtdinfo.txt 2>&1
ubinfo -a > /tmp/storage-debug/ubinfo.txt 2>&1
blkid > /tmp/storage-debug/blkid.txt 2>&1
lsblk -f > /tmp/storage-debug/lsblk-f.txt 2>&1
sfdisk -l > /tmp/storage-debug/sfdisk-l.txt 2>&1
sgdisk -p /dev/mmcblk0 > /tmp/storage-debug/sgdisk-p-mmcblk0.txt 2>&1 || true
sgdisk -v /dev/mmcblk0 > /tmp/storage-debug/sgdisk-v-mmcblk0.txt 2>&1 || true
dmesg -T > /tmp/storage-debug/dmesg.txt
journalctl -b --no-pager > /tmp/storage-debug/journal.txt
tar czf /tmp/storage-debug-$(date +%Y%m%d-%H%M%S).tar.gz -C /tmp storage-debug
```

#### 2.17 驗收 Checklist

- [ ] Boot media 型號、容量、erase block / page size 或 block sector size 已記錄。
- [ ] 已明確區分儲存媒體、分割區 / volume、檔案系統、檔案格式 / 映像格式。
- [ ] Raw flash 平台已確認 MTD partition / UBI volume；block device 平台已確認 MBR / GPT。
- [ ] eMMC / SD / SSD 平台已記錄 partition label、PARTUUID / UUID、filesystem type 與 `.wks` 來源。
- [ ] BootROM、U-Boot、kernel、userspace 對同一份 layout 的理解一致。
- [ ] DTS fixed-partitions / U-Boot mtdparts / UBI config / WIC layout / update script 未互相矛盾。
- [ ] `/proc/mtd`、`ubinfo`、`lsblk`、`sfdisk` 或 `sgdisk` 輸出與設計表一致。
- [ ] rootfs 掛載型態符合設計：SquashFS / UBIFS / ext4 / OverlayFS。
- [ ] rwfs 可寫、重開機保留，且空間與 inode 有監控方式。
- [ ] `fw_printenv` / `fw_setenv` 可正常讀寫，且 env offset / size 正確。
- [ ] software update 可完成同版與升版測試。
- [ ] A/B slot 可切換、mark-good、rollback，並保存相關 log。
- [ ] 更新中斷電 / BMC reset / watchdog reset 不會讓系統進入不可回復狀態。
- [ ] Golden / recovery image 可啟動並可重新刷寫 production image。
- [ ] Factory reset 清除範圍與保留範圍已驗證。
- [ ] 安全設定包含 image signature、secure boot、anti-rollback、field mode 或其不啟用理由。
- [ ] 量產燒錄工具、維修流程與本章分區表一致。

#### 2.18 本章參考資料

- Linux kernel documentation - UBI File System: https://www.kernel.org/doc/html/latest/filesystems/ubifs.html
- Linux MTD project - UBIFS FAQ and HOWTO: http://linux-mtd.infradead.org/faq/ubifs.html
- Linux kernel documentation - Overlay Filesystem: https://www.kernel.org/doc/html/latest/filesystems/overlayfs.html
- OpenBMC docs - Flash Layout and Filesystem Documentation: https://github.com/openbmc/docs/blob/master/architecture/code-update/flash-layout.md
- OpenBMC docs - Code Update: https://github.com/openbmc/docs/blob/master/architecture/code-update/code-update.md
- U-Boot documentation - Environment variables and boot flow: https://docs.u-boot.org/
- Yocto Project Reference Manual - Images and filesystem types: https://docs.yoctoproject.org/ref-manual/
