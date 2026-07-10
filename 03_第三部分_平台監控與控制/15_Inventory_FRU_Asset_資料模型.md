### 15. Inventory / FRU / Asset 資料模型

本章整理 BMC 平台中 Inventory、FRU、Asset、VPD、Field Replaceable Unit EEPROM、Entity Manager、D-Bus inventory object、Redfish Chassis / Systems / Components 與 IPMI FRU / SDR 的資料模型與排查方法。Inventory 不是單純的「清單」，而是 BMC 對實體硬體拓樸、可插拔元件、製造資訊、序號、料號、版本、位置、presence、functional 狀態與 sensor / power / thermal association 的共同資料基準。

Inventory / FRU / Asset 問題常見現象包含：Redfish inventory 缺件、IPMI FRU 顯示欄位不一致、FRU EEPROM 讀不到、序號 / product name 跟標籤不一致、PSU / fan / riser 插拔後狀態不更新、Entity Manager probe 不匹配、D-Bus object path 改名導致 bmcweb / ipmid / sensor daemon 找不到 association、factory reset 後資產資料消失、量產燒錄資料被 FW update 覆蓋。

本章的目標是把「資料權威端」、「欄位對映」、「OpenBMC D-Bus object」、「Redfish / IPMI 對外呈現」、「動態 presence」、「製造寫入」、「資料保存」、「log 收集」與「驗收 checklist」串在一起，避免不同團隊各自維護一份名稱與序號資料。

#### 15.1 基本名詞與資料邊界


| 名詞 | 說明 | BMC porting 關注點 |
| --- | --- | --- |
| Inventory | BMC 內部對實體元件與拓樸的表示，通常由 D-Bus object 與 associations 組成 | object path、interface、Present / Functional、containment、sensor association |
| FRU | Field Replaceable Unit，可現場更換的元件及其識別資料 | EEPROM 格式、I2C path、IPMI FRU 欄位、Redfish Asset 欄位 |
| Asset | 資產識別資料，例如 Manufacturer、Model、PartNumber、SerialNumber、AssetTag | 資料權威端、製造寫入、更新是否保留 |
| VPD | Vital Product Data，平台或元件的重要製造 / 識別資料 | 來源可能是 EEPROM、BIOS table、CPLD、NVRAM、provisioning file |
| Presence | 實體是否存在 | 來源可能是 GPIO、FRU EEPROM ACK、PMBus ACK、CPLD bit、MCTP discovery |
| Functional | 存在且功能狀態可用 | PSU present 但 fault、fan present 但 tach fail，都應與 Present 分開描述 |
| Association | D-Bus object 之間的關係，例如 contained_by、inventory、sensors | Redfish / IPMI / policy 常依賴 association 找到元件關係 |
| Probe | Entity Manager 用來判斷某 entity 是否存在或適用的規則 | Probe source、比對欄位、SKU / FRU 差異、熱插拔更新 |


建議先定義每一類資料的權威端：


| 資料類型 | 可能權威端 | 不建議作法 | 備註 |
| --- | --- | --- | --- |
| Baseboard 序號 | Baseboard FRU EEPROM / manufacturing provisioning | 同時在 EEPROM、JSON、Redfish override 各放不同值 | 需和機身標籤 / 工廠系統一致 |
| Chassis AssetTag | Factory database / user writable setting | FW update 時重設為預設值 | 若允許使用者修改，需定義保存位置 |
| PSU inventory | PSU FRU / PMBus MFR commands | 只用 slot 名稱推測 model / serial | PSU absent 時需移除或標 unavailable |
| Fan tray inventory | FRU EEPROM / GPIO presence + static config | fan absent 仍保留舊序號且 Present=true | 需處理熱插拔與 debounce |
| CPU / DIMM inventory | BIOS SMBIOS / host firmware / PECI / SPD | BMC static JSON 與 host 實際裝置不同步 | host off 時資料可用性需定義 |
| Riser / PCIe device | GPIO ID、FRU EEPROM、MCTP / PLDM、BIOS table | 只依 SKU 假設固定存在 | 需支援不同 riser 組合 |
| CPLD / FPGA version | CPLD register / update manifest | 手寫在 JSON 但未隨更新改變 | 需與 update service 對齊 |


#### 15.2 OpenBMC Inventory 架構

OpenBMC inventory 通常由多個 daemon 共同建立，並透過 D-Bus object 暴露。常見資料流如下：

```text
FRU EEPROM / GPIO / PMBus / SMBIOS / MCTP / static JSON
    ↓
fru-device / Entity Manager / platform daemon / host inventory daemon
    ↓
D-Bus inventory object
    /xyz/openbmc_project/inventory/...
    ↓
phosphor-dbus-interfaces inventory item interfaces
    Present / PrettyName / Asset / Chassis / Board / PowerSupply / Fan / Dimm ...
    ↓
ObjectMapper / associations
    ↓
bmcweb Redfish / phosphor-host-ipmid / sensor daemon / logging / policy
```

OpenBMC `entity-manager` 的設計目標是把實體元件對映到 BMC 上的軟體資源，並降低新平台移植時需要維護的客製差異；它使用 Entity、Exposes、Probe 等概念描述硬體與其可提供的功能。`fru-device` 是常見 detection daemon，會掃描可用 I2C bus 上的 IPMI FRU EEPROM，並把解析結果提供給 D-Bus，供 Entity Manager 與其他 consumer 使用。

常見元件與職責：


| 元件 / service | 主要職責 | 常見輸入 | 常見輸出 / 消費者 |
| --- | --- | --- | --- |
| fru-device | 掃描 I2C FRU EEPROM、解析 IPMI FRU 格式、發布 FRU 欄位 | I2C EEPROM、baseboard FRU file、blocklist | Entity Manager、inventory object、debug CLI |
| Entity Manager | 依 Probe 與 JSON config 建立 entity / exposes / inventory | FRU D-Bus、GPIO presence、static JSON、schema | sensor daemons、inventory manager、policy daemons |
| phosphor-dbus-interfaces | 定義標準 D-Bus inventory interface | YAML interface definitions | sdbusplus binding、service contracts |
| ObjectMapper | 提供 object path、service、interface 查找 | D-Bus object registrations | bmcweb、ipmid、sensor daemon、debug |
| platform inventory daemon | 處理平台客製來源，例如 CPLD、GPIO ID、MCTP discovery | CPLD register、GPIO、host interface | inventory object、association、event |
| bmcweb | 將 inventory / asset / health 呈現為 Redfish resource | D-Bus inventory、associations、sensors | Redfish client / WebUI |
| phosphor-host-ipmid | 提供 IPMI FRU / SDR / SEL 對外介面 | D-Bus inventory、FRU data、config | ipmitool / host management tool |


#### 15.3 D-Bus Inventory object 與 interface 設計

Inventory object 通常位於 `/xyz/openbmc_project/inventory` namespace。每個實體元件至少應有可識別的 object path，並依元件類型套用對應 interface，例如 `xyz.openbmc_project.Inventory.Item`、`xyz.openbmc_project.Inventory.Decorator.Asset`、`xyz.openbmc_project.Inventory.Item.Board`、`PowerSupply`、`Fan`、`Dimm`、`Cpu` 等。

Object path 命名建議：

```text
/xyz/openbmc_project/inventory/system
/xyz/openbmc_project/inventory/system/chassis
/xyz/openbmc_project/inventory/system/chassis/motherboard
/xyz/openbmc_project/inventory/system/chassis/motherboard/bmc
/xyz/openbmc_project/inventory/system/chassis/motherboard/psu0
/xyz/openbmc_project/inventory/system/chassis/motherboard/fan0
/xyz/openbmc_project/inventory/system/chassis/motherboard/dimm0
/xyz/openbmc_project/inventory/system/chassis/motherboard/riser0
```

命名建議：

- object path 應穩定，不應因 hwmon index、I2C bus number、probe 順序改變。
- 可插拔 slot 建議使用 slot 名稱，例如 `psu0`、`fan3`、`riser1`，而不是直接用 FRU product name。
- 同一類型元件序號需與 silk screen / service manual 一致。
- 若資料來自不同來源，object path 仍應維持同一個 inventory identity，避免 Redfish / IPMI 看到重複項目。
- 不建議把 transient debug object 暴露到 production inventory tree。

常見 inventory property：


| Property / Interface | 用途 | 資料來源 | 注意事項 |
| --- | --- | --- | --- |
| Present | 實體是否存在 | GPIO、FRU ACK、PMBus、CPLD、Probe result | 不要和 Functional 混用 |
| PrettyName | 人類可讀名稱 | config、FRU product name | 不應作為程式唯一識別 |
| Manufacturer | 製造商 | FRU Board/Product area、PMBus MFR_ID、SMBIOS | 需定義優先順序 |
| Model | 型號 | FRU product name / part model | 需和 Redfish Model 對映 |
| PartNumber | 料號 | FRU part number、ERP / factory provisioning | 量產資料需保護 |
| SerialNumber | 序號 | FRU serial、factory provisioning、PMBus MFR_SERIAL | 不可被 FW update 覆蓋 |
| AssetTag | 資產標籤 | FRU product asset tag、user setting | 若可寫，需權限與保存策略 |
| BuildDate / MfgDate | 製造時間 | FRU manufacturing date、factory database | 格式與時區需一致 |
| Version / Revision | 硬體版本 | FRU custom field、CPLD register、silicon ID | 需區分 board rev、CPLD rev、FW rev |
| Functional | 功能狀態 | fault bit、sensor status、daemon 判斷 | Present=true 但 Functional=false 是有效狀態 |


#### 15.4 FRU EEPROM 與 IPMI FRU 格式

IPMI FRU 資料通常存放在 I2C EEPROM 中，常見於 baseboard、PSU、fan tray、riser、backplane、GPU carrier、front panel 等。FRU 格式通常由 common header 指向不同 area，例如 chassis、board、product、multi-record 等。每個 area 有自己的長度、欄位與 checksum。

FRU 設計重點：

- 必須定義 EEPROM 型號、I2C bus、mux path、address、address width、page size、WP pin、容量。
- 必須定義 FRU data 的 owner：工廠工具、BMC service、field service tool 或 PSU vendor。
- 必須定義哪些欄位可寫、誰可寫、何時可寫、寫入失敗如何回復。
- BMC FW update 不應覆蓋 baseboard serial / asset tag / field provisioning 資料。
- FRU checksum 錯時需報清楚，不能默默使用半解析欄位。

常見 IPMI FRU 欄位對映：


| FRU area | 欄位 | Inventory / Asset 對映 | Redfish 常見對映 | 備註 |
| --- | --- | --- | --- | --- |
| Chassis | Chassis Type | Chassis 類型 | ChassisType | 需符合產品外型 |
| Chassis | Part Number | Chassis PartNumber | PartNumber | 機箱料號 |
| Chassis | Serial Number | Chassis SerialNumber | SerialNumber | 機身序號 |
| Board | Manufacturer | Board Manufacturer | Manufacturer | 主板製造商 |
| Board | Product Name | Board PrettyName / Model | Model / Name | 需避免和整機 product name 混淆 |
| Board | Serial Number | Board SerialNumber | SerialNumber | 主板序號 |
| Board | Part Number | Board PartNumber | PartNumber | 主板料號 |
| Product | Manufacturer | System Manufacturer | ComputerSystem Manufacturer | 整機製造商 |
| Product | Product Name | System Model | ComputerSystem Model | 整機型號 |
| Product | Part / Version | System PartNumber / Version | PartNumber / SKU | 專案需定義對映 |
| Product | Serial Number | System SerialNumber | SerialNumber | 外部管理最常使用 |
| Product | Asset Tag | AssetTag | AssetTag | 可能可由使用者修改 |


#### 15.5 資料來源優先順序與衝突處理

同一欄位可能有多個來源。例如 PSU model 可來自 FRU EEPROM、PMBus MFR_MODEL、Entity Manager JSON、vendor inventory daemon。若未定義優先順序，Redfish / IPMI / WebUI 可能顯示不同資料。

建議每個欄位建立 priority：


| 欄位 | Priority 1 | Priority 2 | Priority 3 | 衝突處理 |
| --- | --- | --- | --- | --- |
| System SerialNumber | Factory provisioned FRU Product Serial | secure manufacturing file | static config placeholder | 若不一致，記錄 event 並標示待確認 |
| Baseboard PartNumber | Board FRU Part Number | GPIO SKU ID + lookup table | Entity Manager JSON | FRU 解析失敗才 fallback |
| PSU Model | PSU FRU Product Name | PMBus MFR_MODEL | slot default config | 若 PSU absent，不使用舊值作為 present item |
| Fan tray SerialNumber | Fan tray FRU Serial | manufacturing database | N/A | 沒有序號時標未知，不偽造 |
| CPLD Version | CPLD register | update manifest | static config | register 讀不到時標 unavailable |
| AssetTag | User writable setting / Redfish PATCH | FRU Product Asset Tag | factory default | 需定義寫回 FRU 或 persistent store |


衝突處理原則：

- 不要默默覆蓋量產資料；需保留 before / after log。
- 對外欄位只能有一個明確權威端；其他來源作為 fallback 或診斷資訊。
- 若不同介面需不同語意，例如 System Serial vs Board Serial，必須分開欄位，不要共用。
- 若 FRU 缺欄位，不建議填入會誤導維修的假資料；可顯示 unknown / unavailable。
- 若允許 Redfish 更新 AssetTag，需明確定義寫到 FRU EEPROM、persistent setting 或平台資料庫。

#### 15.6 Entity Manager JSON 與 Probe 設計

Entity Manager 常以 JSON 設定描述 entity、probe rule 與 exposes。Probe 可依 FRU 欄位、GPIO presence、DevicePresence、SMBIOS、MCTP discovery 或其他 D-Bus interface 判斷某個配置是否適用。

簡化範本：

```json
{
  "Name": "Example Baseboard",
  "Probe": "xyz.openbmc_project.FruDevice({'BOARD_PRODUCT_NAME': 'EXAMPLE_BOARD'})",
  "Type": "Board",
  "Exposes": [
    {
      "Name": "Baseboard",
      "Type": "InventoryItem",
      "PrettyName": "Example Baseboard"
    },
    {
      "Name": "inlet_temp",
      "Type": "TMP75",
      "Bus": 5,
      "Address": "0x48"
    }
  ]
}
```

Probe 設計建議：

- Probe 欄位要使用穩定且量產可控的資料，例如 board product name、part number、SKU ID。
- 不建議使用 serial number 作為 platform config probe，因為每台都不同。
- Probe rule 需容許 FRU 欄位大小寫、空白、vendor old format 的差異，或在工廠端先標準化。
- 可插拔元件需定義插入、拔除、重新插入後的 object 更新行為。
- 一個 FRU 對應多個 Exposes 時，需確認其中任何 sensor / device 失敗不會讓整個 entity 被移除，除非符合設計。

#### 15.7 Presence、Functional、Available 與 Health

Inventory 與 sensor / power / thermal policy 最容易混淆的是 Present、Functional、Available、Health。建議採用下列語意：


| 狀態 | 語意 | 例子 | 對外呈現建議 |
| --- | --- | --- | --- |
| Present | 實體是否插入或存在 | PSU 插入、fan tray 插入、DIMM 存在 | Inventory Item Present |
| Available | 目前讀值或服務是否可取得 | PSU present 但 PMBus 暫時 timeout | Sensor Availability |
| Functional | 元件是否功能正常 | fan present 但 tach 為 0、PSU present 但 fault | OperationalStatus Functional=false |
| Health | 聚合後的健康狀態 | Redfish Status Health Warning / Critical | Redfish Status |
| Enabled | 是否被管理軟體啟用 | slot disabled、fan policy disabled | Redfish State / Enabled |


設計提醒：

- Present=false 時，不應同時報該元件 sensor threshold critical。
- Present=true 但 Available=false 可表示通訊暫時失敗，需要 retry 與 event debounce。
- Present=true 但 Functional=false 可表示元件在但有 fault，應保留 inventory 並顯示 fault。
- Health 應是 policy 聚合結果，不應直接等同單一 GPIO 或單一 PMBus bit。
- 熱插拔元件需在拔除後清除或更新 sensor association，避免 Redfish 顯示 orphan sensor。

#### 15.8 Association 與拓樸模型

OpenBMC inventory 需要 association 來表達物理包含、sensor 屬於哪個元件、元件位於哪個 chassis / board / slot。這些 association 會影響 Redfish resource 階層、IPMI SDR、power / thermal policy 與 event log 的 location。

常見 association：


| Association | 用途 | 例子 | 注意事項 |
| --- | --- | --- | --- |
| contained_by / containing | 物理包含關係 | fan0 contained_by chassis | 不要形成循環 |
| inventory / sensors | sensor 與 inventory item 關係 | psu0 voltage sensor belongs to psu0 | Redfish sensor placement 依賴此關係 |
| chassis / all_sensors | chassis 下所有 sensor | system/chassis → sensors | 需避免漏掉可插拔元件 sensor |
| powered_by | 電源供應關係 | drive backplane powered_by psu0 | 若平台支援可補 |
| cooled_by | 冷卻關係 | CPU cooled_by fan zone | fan policy 可引用 |


排查 association：

```bash
busctl tree xyz.openbmc_project.ObjectMapper | grep -i inventory
busctl introspect <service> <object_path>
busctl get-property <service> <object_path> xyz.openbmc_project.Association.Definitions Associations
```

#### 15.9 Redfish / IPMI 對映

Inventory 對外通常會映射到 Redfish 與 IPMI。兩者語意不同：Redfish 偏向 resource model 與 JSON schema；IPMI FRU 偏向 legacy FRU areas 與 SDR。不能假設兩者欄位完全一對一。


| BMC 內部資料 | Redfish 可能 resource | IPMI 可能呈現 | 注意事項 |
| --- | --- | --- | --- |
| System inventory | ComputerSystem | Product FRU | System serial 與 board serial 需分清楚 |
| Chassis inventory | Chassis | Chassis FRU | ChassisType / AssetTag / SerialNumber |
| Baseboard | Chassis / Assembly / Manager relation | Board FRU | Board product name 不一定等於 system model |
| PSU | PowerSupply / PowerSubsystem | FRU + sensors | presence、power readout、fault 狀態需一致 |
| Fan | Fan / ThermalSubsystem | Fan SDR / FRU | fan tray 與 fan rotor 需分層 |
| DIMM / CPU | Memory / Processor | 可能由 OEM IPMI / SMBIOS | 來源常是 BIOS / host inventory |
| Drive / PCIe | Drive / PCIeDevice / Storage | 平台依需求 | 可能來自 MCTP / PLDM / host table |


Redfish 檢查：

```bash
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Systems
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Managers
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>/Power
curl -k -u root:0penBmc https://<bmc>/redfish/v1/Chassis/<id>/Thermal
```

IPMI 檢查：

```bash
ipmitool fru print
ipmitool fru print <fru_id>
ipmitool sdr elist
ipmitool sensor list
ipmitool sel list
```

#### 15.10 製造寫入、provisioning 與 field update

Inventory / FRU / Asset 有一部分屬於量產階段資料，不應被一般韌體更新流程覆蓋。建議把資料分成 factory data、field writable data、runtime cache 三類。


| 資料類型 | 例子 | 寫入時機 | 保存位置 | 保護策略 |
| --- | --- | --- | --- | --- |
| Factory data | serial number、part number、MAC、UUID、manufacture date | 工廠燒錄 / final test | FRU EEPROM、secure storage、factory partition | FW update 不覆蓋；需權限控管 |
| Field writable data | AssetTag、Location、user label | 現場管理或 Redfish PATCH | persistent setting 或可寫 FRU 欄位 | 需 audit log 與權限 |
| Runtime cache | parsed FRU cache、host inventory cache | service 啟動或 discovery 後 | /var/lib 或 memory | 可重建；factory reset policy 需定義 |
| Derived data | SKU name、friendly name、slot label | 依 Probe / config 產生 | Entity Manager config | 不可覆蓋權威序號 |


製造流程建議：

1. 工廠工具寫入 FRU / asset 欄位。
2. BMC boot 後讀回 FRU，產生 D-Bus inventory object。
3. Redfish / IPMI / CLI 讀到的欄位與工廠資料庫比對。
4. 執行 AC cycle、BMC reboot、FW update、factory reset 後再次比對。
5. 保存 provisioning log、FRU binary dump、BMC inventory dump 與版本資訊。

#### 15.11 FRU / Inventory 資料保存與安全

Asset data 常包含序號、資產標籤、位置資訊、MAC、UUID、客戶識別資訊。需考慮 field service、RMA、資安與隱私需求。

建議：

- SerialNumber / PartNumber / MAC / UUID 不應被一般使用者無權限修改。
- AssetTag 若允許修改，需透過 Redfish / CLI 權限控管與審計紀錄。
- Factory reset 是否清除 AssetTag、Location、user label 需符合產品政策。
- RMA 換板時需定義保留機身序號或更換主板序號的流程。
- FRU EEPROM 寫入需避免斷電中斷造成 checksum 損壞；必要時保留備份。
- 若 inventory 會暴露客戶自定義 label，log 收集對外分享前需評估遮蔽策略。

#### 15.12 Target 端檢查與 log 收集

建議建立固定 log 套件：

```bash
mkdir -p /tmp/inventory-debug
cat /etc/os-release > /tmp/inventory-debug/os-release.txt
uname -a > /tmp/inventory-debug/uname.txt
cat /proc/cmdline > /tmp/inventory-debug/proc-cmdline.txt

dmesg -T > /tmp/inventory-debug/dmesg.txt
journalctl -b --no-pager > /tmp/inventory-debug/journal.txt
systemctl --failed > /tmp/inventory-debug/systemctl-failed.txt 2>&1

# FRU / Entity Manager / Inventory services
systemctl status xyz.openbmc_project.EntityManager.service --no-pager > /tmp/inventory-debug/entity-manager-status.txt 2>&1
systemctl status xyz.openbmc_project.FruDevice.service --no-pager > /tmp/inventory-debug/fru-device-status.txt 2>&1
journalctl -u xyz.openbmc_project.EntityManager.service -b --no-pager > /tmp/inventory-debug/entity-manager-journal.txt 2>&1
journalctl -u xyz.openbmc_project.FruDevice.service -b --no-pager > /tmp/inventory-debug/fru-device-journal.txt 2>&1

# D-Bus inventory
busctl tree xyz.openbmc_project.ObjectMapper > /tmp/inventory-debug/objectmapper-tree.txt 2>&1
busctl tree xyz.openbmc_project.EntityManager > /tmp/inventory-debug/entity-manager-tree.txt 2>&1
busctl tree xyz.openbmc_project.Inventory.Manager > /tmp/inventory-debug/inventory-manager-tree.txt 2>&1
busctl tree xyz.openbmc_project.FruDevice > /tmp/inventory-debug/fru-device-tree.txt 2>&1
busctl tree xyz.openbmc_project.ObjectMapper | grep -i inventory > /tmp/inventory-debug/inventory-paths.txt 2>&1

# I2C / EEPROM
command -v i2cdetect >/dev/null 2>&1 && i2cdetect -l > /tmp/inventory-debug/i2cdetect-l.txt 2>&1
ls -l /sys/bus/i2c/devices > /tmp/inventory-debug/sys-bus-i2c-devices.txt 2>&1
find /sys/bus/i2c/devices -maxdepth 3 -name eeprom -print > /tmp/inventory-debug/eeprom-files.txt 2>&1

# GPIO presence
gpiodetect > /tmp/inventory-debug/gpiodetect.txt 2>&1 || true
gpioinfo > /tmp/inventory-debug/gpioinfo.txt 2>&1 || true

# Redfish / IPMI local tools, if available
ipmitool fru print > /tmp/inventory-debug/ipmi-fru-print.txt 2>&1 || true
ipmitool sdr elist > /tmp/inventory-debug/ipmi-sdr-elist.txt 2>&1 || true
ipmitool sel list > /tmp/inventory-debug/ipmi-sel-list.txt 2>&1 || true

tar czf /tmp/inventory-debug-$(date +%Y%m%d-%H%M%S).tar.gz -C /tmp inventory-debug
```

若要保存 FRU binary，請先確認資料是否可分享：

```bash
# 範例：保存 EEPROM binary，bus/address 需依平台替換
cp /sys/bus/i2c/devices/<bus>-00<addr>/eeprom /tmp/inventory-debug/fru-<bus>-<addr>.bin 2>/dev/null || true
```

#### 15.13 常見問題與排查入口


| 現象 | 可能方向 | 第一輪檢查 |
| --- | --- | --- |
| Redfish 看不到某個元件 | D-Bus inventory object 未建立，或 association 缺失 | busctl tree、ObjectMapper、bmcweb journal |
| IPMI FRU 有資料但 Redfish 沒資料 | FRU 只被 ipmid 使用，未轉成 inventory object | fru-device tree、Entity Manager Probe、inventory path |
| Redfish 有 inventory 但 IPMI FRU 缺欄位 | IPMI FRU ID / mapping 未更新 | ipmitool fru print、ipmid journal、FRU config |
| FRU EEPROM 讀不到 | I2C path、address、WP、EEPROM size、mux、power 問題 | i2cdetect、/sys/bus/i2c/devices、scope |
| FRU checksum error | 資料寫入中斷、格式錯、area length 錯 | fru-device journal、binary dump、factory tool |
| 序號顯示 unknown | FRU 欄位空、Probe fallback 未定義、權威端讀取失敗 | FRU dump、D-Bus value、factory log |
| PSU 拔掉後 inventory 仍 Present=true | presence source 未更新，使用舊 cache | GPIO / PMBus presence、fru-device journal、Entity Manager object |
| Fan tray 插入後 sensor 不出現 | inventory 建立了但 Exposes / sensor daemon 未收到 config | Entity Manager journal、dbus-sensors journal、association |
| Factory reset 後資產資料消失 | factory reset 清掉 persistent store 或 FRU cache 當成權威端 | reset script、保存策略、FRU EEPROM 原始資料 |
| FW update 後料號變回預設 | image 內 static config 覆蓋 runtime / factory data | update script、rwfs migration、inventory config |
| 不同介面顯示不同 model | Redfish / IPMI / D-Bus 使用不同來源 | 欄位優先順序表、bmcweb / ipmid log |
| Object path 每次開機不同 | 依 bus number / hwmon index / discovery order 命名 | 命名規則、Probe source、service log |


#### 15.14 Bring-up 建議流程

- 建立所有實體元件清單：system、chassis、baseboard、BMC、PSU、fan、riser、backplane、drive、CPU、DIMM、CPLD、FPGA、NIC、GPU。
- 對每個元件定義資料權威端：FRU EEPROM、PMBus MFR command、SMBIOS、CPLD register、GPIO ID、Entity Manager JSON、manufacturing provisioning。
- 建立欄位對映表：Manufacturer、Model、PartNumber、SerialNumber、AssetTag、Version、Location、Present、Functional。
- 建立 object path 命名規則，確保 path 穩定且與 service manual slot 名稱一致。
- 對可插拔元件定義 presence source、debounce、插入 / 拔除後 D-Bus object 更新行為。
- 對每個 FRU EEPROM 驗證 I2C path、address、EEPROM size、WP、checksum、欄位內容。
- 撰寫或更新 Entity Manager JSON，確認 Probe 與 Exposes 不會互相衝突。
- 驗證 D-Bus inventory object、associations、ObjectMapper 查找結果。
- 驗證 Redfish / IPMI / WebUI 顯示一致。
- 做異常測試：FRU missing、checksum error、hot-plug、service restart、BMC reboot、AC cycle、FW update、factory reset。
- 保存 inventory-debug log、FRU binary dump、Redfish output、IPMI output 與工廠資料比對結果。

#### 15.15 當前平台 Inventory / FRU / Asset 實測表


| 項目 | 資料來源 | D-Bus object | Redfish / IPMI 對映 | 實測值 | 狀態 |
| --- | --- | --- | --- | --- | --- |
| System Model | [待填] | [待填] | ComputerSystem Model / Product FRU | [待填] | [待確認] |
| System SerialNumber | [待填] | [待填] | ComputerSystem SerialNumber / Product FRU | [待填] | [待確認] |
| Chassis SerialNumber | [待填] | [待填] | Chassis SerialNumber / Chassis FRU | [待填] | [待確認] |
| Baseboard PartNumber | [待填] | [待填] | Board FRU / Redfish Assembly | [待填] | [待確認] |
| Baseboard SerialNumber | [待填] | [待填] | Board FRU / Redfish Assembly | [待填] | [待確認] |
| BMC FRU / version | [待填] | [待填] | Manager / BMC inventory | [待填] | [待確認] |
| PSU0 inventory | [待填] | [待填] | PowerSupply / FRU / sensors | [待填] | [待確認] |
| PSU1 inventory | [待填] | [待填] | PowerSupply / FRU / sensors | [待填] | [待確認] |
| Fan tray inventory | [待填] | [待填] | Fan / Thermal / FRU | [待填] | [待確認] |
| Riser inventory | [待填] | [待填] | PCIeSlot / Assembly | [待填] | [待確認] |
| DIMM inventory | [待填] | [待填] | Memory / host inventory | [待填] | [待確認] |
| CPU inventory | [待填] | [待填] | Processor / host inventory | [待填] | [待確認] |
| CPLD version | [待填] | [待填] | Assembly / OEM field | [待填] | [待確認] |
| AssetTag | [待填] | [待填] | Chassis / System AssetTag | [待填] | [待確認] |


FRU EEPROM 實測表：


| FRU | I2C path | Address | EEPROM | WP | FRU areas | Checksum | Owner | 狀態 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Baseboard | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | Factory/BMC | [待確認] |
| PSU0 | [待填] | [待填] | [待填] | N/A | [待填] | [待填] | PSU vendor | [待確認] |
| PSU1 | [待填] | [待填] | [待填] | N/A | [待填] | [待填] | PSU vendor | [待確認] |
| Fan board | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | Factory/BMC | [待確認] |
| Riser | [待填] | [待填] | [待填] | [待填] | [待填] | [待填] | Factory/BMC | [待確認] |


#### 15.16 回查結果

本章已回查前後文並補齊下列銜接點：

- 第 3 章 Pinmux / GPIO 已有 presence / intrusion / GPIO state，本章補上 presence 與 inventory object、functional、association 的資料模型。
- 第 5 章與第 10 章已涵蓋 I2C / PMBus，本章補上 FRU EEPROM、PSU FRU、PMBus MFR 欄位與 inventory 對映。
- 第 11 章 OpenBMC 常用 Project 已介紹 Entity Manager、ObjectMapper、dbus-sensors，本章把這些服務套用到 Inventory / FRU / Asset 流程。
- 第 12～14 章 Sensor 章節會使用 inventory association 將 sensor 連到實體元件，本章補上 association 與 Redfish / IPMI 呈現方式。
- 第 16 章 Power Control 可引用 PSU inventory、presence、functional 與 PMBus fault 狀態，避免 power policy 與 inventory 顯示不一致。
- 第 2 章 Flash / Storage 與更新流程已說明 persistent data，本章補上 factory data、field writable data、runtime cache 的保存與 factory reset policy。

#### 15.17 驗收 Checklist

-  所有實體元件已建立 inventory 清單與 object path 命名規則。
-  每個 asset 欄位已定義權威端、fallback、衝突處理與 owner。
-  FRU EEPROM 的 I2C path、address、size、WP、checksum、欄位內容已驗證。
-  Entity Manager Probe 可正確匹配 board / SKU / FRU，不會因 serial number 差異失敗。
-  D-Bus inventory object 位於穩定 path，且 Present / Functional / Asset 欄位正確。
-  Association 已建立，sensor、power、thermal、inventory、chassis 關係可由 ObjectMapper 查到。
-  Redfish System / Chassis / Power / Thermal / Assembly 顯示與 D-Bus inventory 一致。
-  IPMI FRU / SDR 顯示與 FRU EEPROM、D-Bus inventory 一致，差異已有明確說明。
-  可插拔元件插入 / 拔除 / 重插後，inventory、sensor、event 狀態可正確更新。
-  Present=false 不會產生誤導性的 threshold critical；Present=true + fault 可正確顯示 Functional=false 或 Health warning。
-  AssetTag / Location 等可寫欄位有權限控管、審計與保存策略。
-  FW update、BMC reboot、AC cycle、factory reset 不會破壞 factory data。
-  FRU checksum error、EEPROM missing、Probe mismatch、service restart 等異常流程已測試。
-  inventory-debug log、FRU binary dump、Redfish output、IPMI output、factory 比對結果已保存。

#### 15.18 本章參考資料

- OpenBMC entity-manager README: [https://github.com/openbmc/entity-manager](https://github.com/openbmc/entity-manager)
- OpenBMC phosphor-dbus-interfaces inventory item definitions: [https://github.com/openbmc/phosphor-dbus-interfaces/tree/master/yaml/xyz/openbmc_project/Inventory/Item](https://github.com/openbmc/phosphor-dbus-interfaces/tree/master/yaml/xyz/openbmc_project/Inventory/Item)
- OpenBMC phosphor-dbus-interfaces repository: [https://github.com/openbmc/phosphor-dbus-interfaces](https://github.com/openbmc/phosphor-dbus-interfaces)
- IPMI Platform Management FRU Information Storage Definition: [https://www.intel.com/content/www/us/en/products/docs/servers/ipmi/ipmi-platform-mgt-fru-infostore-def-v1-0-rev-1-3-spec-update.html](https://www.intel.com/content/www/us/en/products/docs/servers/ipmi/ipmi-platform-mgt-fru-infostore-def-v1-0-rev-1-3-spec-update.html)
- DMTF Redfish Schema Index: [https://redfish.dmtf.org/schemas/v1/](https://redfish.dmtf.org/schemas/v1/)
