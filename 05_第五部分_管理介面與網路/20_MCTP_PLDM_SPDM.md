### 20. MCTP / PLDM / SPDM

本章整理 BMC 平台中 MCTP、PLDM 與 SPDM 的架構、porting、bring-up、除錯與驗收方法。MCTP（Management Component Transport Protocol）是平台內部管理通訊的傳輸層，可承載在 SMBus / I2C、PCIe VDM、I3C、UART / serial、USB 等不同媒體上，並以 EID（Endpoint ID）描述管理 endpoint。PLDM（Platform Level Data Model）是 MCTP 之上的管理資料模型，可用於 base discovery、platform monitoring/control、BIOS 設定、FRU inventory、firmware update、event。SPDM（Security Protocol and Data Model）則提供裝置認證、憑證、量測、challenge、session 與安全訊息基礎。

BMC 平台採用 MCTP / PLDM / SPDM 後，管理路徑會從傳統 IPMI / SMBus / vendor command 分散模式，逐步收斂到標準化 transport、endpoint discovery、message type、terminus、PDR、certificate chain、measurement 與 firmware update flow。這一章的目標是讓新平台 porting 能清楚回答：哪條 physical link 跑 MCTP、誰是 bus owner、EID 如何分配、endpoint 支援哪些 message type、PLDM terminus 如何建立、PDR / sensor / FRU / firmware update 如何對映到 OpenBMC D-Bus、SPDM attestation 與 secure session 是否啟用，以及發生 timeout / discovery fail / attestation fail 時要收哪些 log。

#### 20.1 分層模型與資料流

建議先用下列分層理解 MCTP / PLDM / SPDM：

```text
Physical / Binding layer
  SMBus/I2C、PCIe VDM、I3C、USB、serial、vendor bridge
    ↓
MCTP transport layer
  EID、message type、fragmentation、routing、control command、MTU
    ↓
Upper protocols
  PLDM、SPDM、NC-SI over MCTP、vendor-defined message
    ↓
OpenBMC services
  mctpd、pldmd、libpldm、SPDM requester/responder、platform daemon
    ↓
D-Bus / inventory / sensors / firmware update / security policy
    ↓
Redfish / IPMI / event / telemetry / field service
```


| 層級 | 主要責任 | 常見資料 | 排查入口 |
| --- | --- | --- | --- |
| Physical binding | 實際通訊媒體與封包承載 | I2C bus、PCIe BDF、I3C dynamic address、link state | scope / LA、lspci、i2cdetect、kernel log |
| MCTP | endpoint 定址、routing、message type、MTU、fragmentation | EID、UUID、network id、route、message tag | mctp tools、mctpd D-Bus、tcpdump / trace、journal |
| PLDM | 平台管理資料模型 | terminus、TID、PDR、sensor、FRU、BIOS attributes、FW update | pldmtool、pldmd journal、PDR dump、D-Bus object |
| SPDM | 裝置身分、認證、量測、安全 session | capabilities、algorithms、cert chain、measurement、session id | SPDM trace、libspdm log、security event |
| OpenBMC integration | 將資料轉成 D-Bus / Redfish / update flow | inventory、sensor、version、event、firmware activation | busctl、bmcweb、software inventory、EventLog |


#### 20.2 MCTP 基本概念

MCTP 是管理元件間的 common transport。它以 endpoint 為單位建立通訊，不要求上層協定知道底層是 SMBus、PCIe VDM 或其他 media。

常見名詞：


| 名詞 | 說明 | Bring-up 注意事項 |
| --- | --- | --- |
| Endpoint | 支援 MCTP 的管理端點，例如 BMC、NIC、GPU、CXL device、retimer、satellite controller | 需確認 Endpoint UUID、EID、message type support |
| EID | Endpoint ID，MCTP network 內的 logical address | 需定義 static / dynamic 分配與 persistence |
| Bus owner | 某個 binding 上負責 discovery / EID assignment 的管理者 | 多 BMC 或 host / BMC 共用時需清楚定義 |
| Message type | MCTP payload 類型，例如 Control、PLDM、SPDM、NC-SI、Vendor Defined | endpoint discovery 後需確認支援清單 |
| MTU / packet size | 單段 transport 可承載大小 | PLDM FW update / SPDM cert chain 會受到影響 |
| Message tag | request / response match 的 tag | timeout / retry / concurrent request 需管理 |
| Routing | 跨 bridge / 多 segment MCTP path | 需保存 route table 與 bridge entry |
| Network ID | Linux / OpenBMC 中區分 MCTP network 的識別 | 多 transport 平台需避免混淆 |


MCTP bring-up 最小成功條件：

- physical link 可用，例如 I2C ACK、PCIe device present、I3C target online。
- MCTP binding driver / daemon 啟動。
- endpoint discovery 成功，能取得 endpoint ID / UUID / supported message types。
- BMC route table 能送 request 並收到 response。
- 上層 PLDM / SPDM 能完成 basic command，例如 GetPLDMTypes 或 SPDM GET_VERSION。

#### 20.3 MCTP transport binding：SMBus / I2C、PCIe VDM、I3C

不同 binding 的排查方式差異很大，文件需保存每條 link 的 owner、physical path、EID 分配與上層用途。


| Binding | 常見用途 | 優點 | 風險 | 第一輪檢查 |
| --- | --- | --- | --- | --- |
| SMBus / I2C | PSU、VR、retimer、satellite controller、OCP NIC sideband | 硬體普遍、低成本 | bus stuck、address conflict、低速、大 message fragment 成本 | I2C waveform、mctp-i2c driver、bus owner |
| PCIe VDM | NIC、GPU、accelerator、CXL / PCIe endpoint | 適合 PCIe device 管理 | 依 host power / link training / BDF；hot-plug 複雜 | lspci、PCIe link state、VDM support |
| I3C | 新平台管理 bus | 支援動態 address、較高 throughput | controller / target 支援度與 tooling 需確認 | I3C bus enumeration、kernel log |
| USB / serial | 特定 bridge 或 debug path | 可跨 subsystem | 標準化與量產支援需確認 | driver、device node、protocol trace |
| Vendor bridge | CPLD / MCU 轉接 | 可支援既有硬體 | 需清楚 bridge 行為、MTU、retry、error mapping | bridge log、vendor tool、scope |


平台表格範本：


| Endpoint | Binding | Physical path | EID | UUID | Message types | Owner | 狀態 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| OCP NIC | PCIe VDM / SMBus [待填] | [待填] | [待填] | [待填] | PLDM / SPDM [待填] | BMC / Host [待填] | [待確認] |
| Retimer0 | I2C / SMBus | [待填] | [待填] | [待填] | PLDM / SPDM [待填] | BMC | [待確認] |
| GPU0 | PCIe VDM | [待填] | [待填] | [待填] | PLDM / SPDM / vendor [待填] | BMC / Host | [待確認] |


#### 20.4 Linux / OpenBMC MCTP stack

OpenBMC 平台可能採用 kernel MCTP socket（AF_MCTP）、userspace mctpd、或 vendor stack。新平台需要先確認目前專案的 MCTP stack 邊界。

常見元件：


| 元件 | 用途 | 常見檢查點 |
| --- | --- | --- |
| kernel MCTP | 提供 MCTP network、route、AF_MCTP socket 與 binding driver | kernel config、link、route、netlink |
| mctpd | 管理 endpoint discovery、EID、D-Bus 介面 | service status、D-Bus object、endpoint signal |
| mctp tools | 查 link / route / endpoint，送 control command | 工具版本與 kernel stack 是否相容 |
| pldmd | 監聽 MCTP endpoint，建立 PLDM terminus，處理 PLDM request / response | terminus table、PDR、pldmtool |
| SPDM requester | 對 endpoint 執行 discovery、certificate、challenge、measurement | policy、cert chain、algorithm、session |


常用檢查：

```bash
# service 與 kernel log
systemctl status mctpd --no-pager 2>/dev/null || true
systemctl status pldmd --no-pager 2>/dev/null || true
journalctl -u mctpd -b --no-pager 2>/dev/null
journalctl -u pldmd -b --no-pager 2>/dev/null
dmesg | grep -Ei 'mctp|pldm|spdm|vdm|i3c'

# D-Bus
busctl tree xyz.openbmc_project.MCTP 2>/dev/null || true
busctl tree xyz.openbmc_project.PLDM 2>/dev/null || true
busctl tree xyz.openbmc_project.ObjectMapper | grep -Ei 'MCTP|PLDM|SPDM' || true

# Linux MCTP tools，依 image 內容而定
mctp link 2>/dev/null || true
mctp route 2>/dev/null || true
mctp addr 2>/dev/null || true
```

#### 20.5 MCTP discovery、EID 分配與 route

MCTP discovery 是上層 PLDM / SPDM 能否運作的基礎。若 endpoint 沒有 EID 或 route 不正確，上層常只看到 timeout。

建議記錄欄位：


| 項目 | 說明 | 資料來源 |
| --- | --- | --- |
| EID assignment mode | static、dynamic、pre-assigned、host assigned | platform design、mctpd config |
| Bus owner | 誰負責 Set Endpoint ID / discovery | BMC / host / bridge policy |
| Endpoint UUID | endpoint 穩定識別 | MCTP Control Get Endpoint UUID |
| Supported message types | PLDM、SPDM、vendor-defined 等 | MCTP Control Get Message Type Support |
| MTU | path transmission unit | MCTP Control / binding config |
| Route table | EID 到 link / next hop 的對照 | mctp route / D-Bus |
| Endpoint state | discovered、reachable、lost、removed | mctpd journal / D-Bus signal |


常見問題：

- BMC 與 host 都嘗試當 bus owner，造成 EID 變動或重複。
- Endpoint reset 後 EID 消失，上層 PLDM terminus 沒有重新 discovery。
- Hot-plug 端點移除後 route 還在，造成 request timeout。
- 多 transport 到同一 endpoint 時，route priority 未定義。
- MCTP bridge 兩側 network id / EID range 設計不清楚。

#### 20.6 PLDM 基本概念與 Types

PLDM 定義多種 Type，每種 Type 對應一組管理功能。OpenBMC `pldmd` 常透過 MCTP 發現 endpoint，建立 terminus，讀取 PDR，再把 sensor / inventory / BIOS / firmware update 資料接到 D-Bus 或平台 service。


| PLDM Type | 用途 | BMC 常見使用情境 |
| --- | --- | --- |
| Type 0 Base | protocol discovery、version、type、command support | 建立 terminus 的第一步 |
| Type 1 SMBIOS | SMBIOS table transfer | host inventory / system info，依平台支援 |
| Type 2 Platform | sensor、effecter、PDR、event | remote sensor、state set、control |
| Type 3 BIOS | BIOS attributes 與 configuration | 遠端 BIOS 設定 / host firmware config |
| Type 4 FRU | FRU records 與 inventory | endpoint FRU / device inventory |
| Type 5 Firmware Update | 標準化裝置 FW update flow | NIC、retimer、satellite controller 更新 |
| OEM / vendor Type | 廠商擴充 | 平台特定功能，需風險控管 |


PLDM bring-up 最小流程：

```text
MCTP endpoint reachable
    ↓
PLDM Base：GetPLDMVersion / GetPLDMTypes / GetPLDMCommands
    ↓
建立 terminus / TID
    ↓
若支援 Platform：讀 PDR repository
    ↓
建立 sensor / effecter / inventory / event mapping
    ↓
若支援 FRU：讀 FRU records 並對映 inventory
    ↓
若支援 FW Update：查 component / version / transfer capability
```

#### 20.7 PLDM PDR、sensor、effecter 與 event

PDR（Platform Descriptor Record）是 PLDM Platform Monitoring and Control 的核心資料結構，用來描述 sensor、effecter、entity association、state set 等。BMC 需要理解 PDR 才能把 remote endpoint 的 sensor 和 control 對映到 OpenBMC D-Bus。


| 資料 | 用途 | OpenBMC 對映 | 注意事項 |
| --- | --- | --- | --- |
| Numeric Sensor PDR | 連續數值 sensor，例如 temperature、voltage、power | D-Bus sensor Value / thresholds | scale、unit、range、state 需正確 |
| State Sensor PDR | 離散狀態，例如 presence、fault、link state | inventory / event / state property | state set mapping 需完整 |
| Numeric Effecter PDR | 可調數值，例如 power limit、fan target | control interface / policy daemon | 權限與安全限制需定義 |
| State Effecter PDR | 可設狀態，例如 reset、enable、mode | control method | 不可無限制暴露危險控制 |
| Entity Association PDR | 描述元件層級與關係 | inventory association | 需與 Redfish / service manual slot 名稱對齊 |
| PLDM Event | endpoint 主動上報事件 | Logging / EventLog / sensor update | 需處理 ack、sequence、去重 |


PDR 排查：

```bash
# 工具名稱依平台 image 而定
pldmtool base GetPLDMTypes 2>/dev/null || true
pldmtool base GetPLDMCommands 2>/dev/null || true
pldmtool platform GetPDR 2>/dev/null || true
journalctl -u pldmd -b --no-pager | grep -Ei 'PDR|terminus|sensor|effecter|event'
```

常見問題：

- PDR scale / unit 錯，造成 Redfish sensor 值不合理。
- PDR entity association 不完整，sensor 沒有掛到正確 inventory。
- Endpoint event enable 未設定，sensor 狀態只能靠 polling。
- Event receiver 未註冊或 ack flow 錯，endpoint 重複送 event。
- PDR repository change 事件後，BMC 未重新讀 PDR。

#### 20.8 PLDM FRU、BIOS 與 Firmware Update

PLDM FRU 可提供 endpoint inventory；PLDM BIOS 可支援 host firmware / BIOS attributes；PLDM Firmware Update 可支援標準化裝置更新。這些功能通常比 basic sensor 更牽涉產品政策、權限與安全。

PLDM FRU：

- 需定義 FRU record set 如何對映到 OpenBMC inventory object。
- 需區分 endpoint 自身 FRU 與 endpoint 管理的 downstream FRU。
- 若同一欄位也存在 IPMI FRU / PMBus MFR / Redfish，需定義優先順序。

PLDM BIOS：

- 需定義哪些 BIOS attributes 可讀 / 可寫。
- 需確認變更何時生效：立即、下次 host reboot、下次 AC cycle。
- 需保存 BIOS attribute pending / current / default 的差異。
- 需有權限、audit log 與 rollback policy。

PLDM Firmware Update：

- 需確認 endpoint 支援的 transfer size、component classification、activation method。
- 需定義 firmware image package、version、signature、component ID 與 rollback policy。
- 需處理 update 中斷、endpoint reset、BMC reset、host power state 變化。
- 需將 activation / progress / failure reason 對映到 OpenBMC software inventory、Redfish UpdateService 與 event log。

#### 20.9 SPDM 基本概念與安全流程

SPDM 用於 requester 與 responder 之間的安全協商、裝置認證、量測與安全 session。BMC 常作為 requester，對 NIC、GPU、CXL device、retimer、security component 等 endpoint 進行 attestation。

典型 SPDM 流程：

```text
GET_VERSION / VERSION
    ↓
GET_CAPABILITIES / CAPABILITIES
    ↓
NEGOTIATE_ALGORITHMS / ALGORITHMS
    ↓
GET_DIGESTS / DIGESTS
    ↓
GET_CERTIFICATE / CERTIFICATE
    ↓
CHALLENGE / CHALLENGE_AUTH
    ↓
GET_MEASUREMENTS / MEASUREMENTS
    ↓
可選：KEY_EXCHANGE / FINISH 建立 secured session
    ↓
可選：secured message carrying management traffic
```

SPDM porting 需要先定義：


| 項目 | 需要確認 | 備註 |
| --- | --- | --- |
| Requester / Responder | BMC、host、device 誰發起 SPDM | 多 requester 場景需協調 session |
| Transport binding | SPDM over MCTP、PCIe DOE、TCP、storage binding 等 | 本章聚焦 SPDM over MCTP |
| Version | 雙方支援 SPDM 版本 | 需與 libspdm / endpoint firmware 對齊 |
| Algorithms | hash、asym、DHE、AEAD、measurement hash | 安全政策需定義最低要求 |
| Certificate chain | slot、root CA、intermediate、device cert | 需有 trust anchor 與 provisioning 流程 |
| Measurements | measurement block、index、manifest、TCB value | 需定義 expected value 與驗證資料庫 |
| Session | 是否建立 secure session | 會影響 message size、timeout、key lifecycle |
| Policy | 認證失敗如何處理 | log only、degrade、block device、raise event |


#### 20.10 SPDM 信任鏈、量測與 policy

SPDM 是否有價值，取決於 trust anchor、certificate validation、measurement expected value 與 policy 是否完整。只送 GET_VERSION 不代表完成裝置安全驗證。

建議政策表：


| 檢查項目 | Pass 條件 | Fail 行為 | Log / Event |
| --- | --- | --- | --- |
| 版本支援 | endpoint 支援平台允許的 SPDM version | 標記 unsupported | Warning event |
| 演算法 | 符合最低 hash / asym / AEAD 要求 | 拒絕 attestation 或 downgrade warning | Security event |
| 憑證鏈 | 可追溯到信任錨且未過期 / revoked | Functional=false 或 security health warning | Critical / Warning |
| Challenge | signature 驗證通過 | 不信任 endpoint | Critical event |
| Measurements | measurement digest 與 expected value / allowlist 符合 | 依產品策略隔離或告警 | Security event + raw digest |
| Session | key exchange 成功，secured message 可收發 | fallback 或阻擋敏感 command | Warning event |


注意事項：

- 憑證與 measurement expected value 屬於安全資料，需有安全更新與回復機制。
- 若允許 firmware update 改變 measurement，update flow 必須同步更新 expected value 或 manifest。
- SPDM log 不應記錄 private key、session secret 或完整敏感資料。
- Attestation 結果需能對映到 inventory / Redfish Health / EventLog / security audit。

#### 20.11 OpenBMC 整合：D-Bus、Inventory、Redfish、Event

MCTP / PLDM / SPDM 的結果不應只停在 protocol tool output，應整合到平台狀態。


| 資料 | OpenBMC 對映 | 外部呈現 | 注意事項 |
| --- | --- | --- | --- |
| MCTP endpoint | D-Bus endpoint object / inventory association | Redfish OEM / inventory | endpoint remove 時需更新 |
| PLDM FRU | inventory Asset / FRU fields | Redfish Chassis / Assembly / Device | 需定義權威端 |
| PLDM sensor | D-Bus Sensor.Value / Availability / thresholds | Redfish Sensor / Thermal / Power | scale / unit / association 要正確 |
| PLDM event | phosphor-logging entry | SEL / Redfish EventLog / EventService | 需去重與 ack |
| PLDM FW update | software inventory / activation | Redfish UpdateService | 需 progress / failure reason |
| SPDM attestation | security status / inventory decorator / event | Redfish Health / Security event | 需保護敏感資料 |


#### 20.12 Build / Yocto / Kernel 設定重點

平台需確認 kernel、daemon、library、tool、D-Bus interface 與 service file 都包含在 image。

Build 端檢查：

```bash
# kernel config
bitbake -e virtual/kernel | grep '^S='
grep -R "CONFIG_MCTP" tmp/work/*/linux-*/build/.config 2>/dev/null || true

# package / recipe
bitbake -s | grep -Ei 'mctp|pldm|spdm|libmctp|libpldm|libspdm'
bitbake obmc-phosphor-image -g

# service file / package content
find tmp/work -path '*mctp*' -o -path '*pldm*' -o -path '*spdm*' | head -200
```

Target 端檢查：

```bash
systemctl list-units | grep -Ei 'mctp|pldm|spdm'
which mctp 2>/dev/null || true
which pldmtool 2>/dev/null || true
ls -l /usr/bin | grep -Ei 'mctp|pldm|spdm' || true
```

需保存的版本：

- kernel version 與 MCTP config。
- mctpd / pldmd / libpldm / libmctp / SPDM library 版本或 commit。
- endpoint firmware version。
- PLDM / MCTP / SPDM spec version 與 vendor compliance statement。
- Yocto layer / recipe commit。

#### 20.13 Target 端 log 收集套件

```bash
mkdir -p /tmp/mctp-pldm-spdm-debug
cat /etc/os-release > /tmp/mctp-pldm-spdm-debug/os-release.txt
uname -a > /tmp/mctp-pldm-spdm-debug/uname.txt
cat /proc/cmdline > /tmp/mctp-pldm-spdm-debug/proc-cmdline.txt

dmesg -T > /tmp/mctp-pldm-spdm-debug/dmesg.txt
journalctl -b --no-pager > /tmp/mctp-pldm-spdm-debug/journal.txt
systemctl --failed > /tmp/mctp-pldm-spdm-debug/systemctl-failed.txt 2>&1

# services
systemctl status mctpd --no-pager > /tmp/mctp-pldm-spdm-debug/mctpd-status.txt 2>&1 || true
systemctl status pldmd --no-pager > /tmp/mctp-pldm-spdm-debug/pldmd-status.txt 2>&1 || true
journalctl -u mctpd -b --no-pager > /tmp/mctp-pldm-spdm-debug/mctpd-journal.txt 2>&1 || true
journalctl -u pldmd -b --no-pager > /tmp/mctp-pldm-spdm-debug/pldmd-journal.txt 2>&1 || true

# D-Bus
busctl tree xyz.openbmc_project.ObjectMapper > /tmp/mctp-pldm-spdm-debug/objectmapper.txt 2>&1
busctl tree xyz.openbmc_project.MCTP > /tmp/mctp-pldm-spdm-debug/dbus-mctp.txt 2>&1 || true
busctl tree xyz.openbmc_project.PLDM > /tmp/mctp-pldm-spdm-debug/dbus-pldm.txt 2>&1 || true

# MCTP tools
mctp link > /tmp/mctp-pldm-spdm-debug/mctp-link.txt 2>&1 || true
mctp addr > /tmp/mctp-pldm-spdm-debug/mctp-addr.txt 2>&1 || true
mctp route > /tmp/mctp-pldm-spdm-debug/mctp-route.txt 2>&1 || true

# PLDM tools
pldmtool base GetPLDMTypes > /tmp/mctp-pldm-spdm-debug/pldm-types.txt 2>&1 || true
pldmtool base GetPLDMCommands > /tmp/mctp-pldm-spdm-debug/pldm-commands.txt 2>&1 || true
pldmtool platform GetPDR > /tmp/mctp-pldm-spdm-debug/pldm-pdr.txt 2>&1 || true

# physical hints
lspci -vv > /tmp/mctp-pldm-spdm-debug/lspci-vv.txt 2>&1 || true
i2cdetect -l > /tmp/mctp-pldm-spdm-debug/i2cdetect-l.txt 2>&1 || true
ls -l /sys/bus/i2c/devices > /tmp/mctp-pldm-spdm-debug/sys-bus-i2c.txt 2>&1 || true

tar czf /tmp/mctp-pldm-spdm-debug-$(date +%Y%m%d-%H%M%S).tar.gz -C /tmp mctp-pldm-spdm-debug
```

若有 SPDM tool 或 vendor attestation tool，需額外保存：

```bash
# 依平台工具調整
# spdmtool get-version > /tmp/mctp-pldm-spdm-debug/spdm-version.txt
# spdmtool get-capabilities > /tmp/mctp-pldm-spdm-debug/spdm-capabilities.txt
# spdmtool get-measurements > /tmp/mctp-pldm-spdm-debug/spdm-measurements.txt
```

#### 20.14 常見問題與排查入口


| 現象 | 可能方向 | 第一輪檢查 |
| --- | --- | --- |
| MCTP endpoint 掃不到 | physical link、binding driver、bus owner、endpoint power state | dmesg、mctpd journal、scope / lspci / i2cdetect |
| EID 重複或跳動 | 多個 bus owner、dynamic EID policy 不一致、endpoint reset | mctp route、mctpd D-Bus、power timeline |
| PLDM GetTypes timeout | MCTP route 錯、message type 不支援、endpoint busy | MCTP message type support、pldmd journal |
| PDR 讀取失敗 | terminus 未建立、PDR repository error、large transfer / MTU 問題 | pldmtool、PDR trace、MTU |
| PLDM sensor 值不合理 | PDR scale / unit / entity mapping 錯 | PDR dump、D-Bus sensor、raw value |
| PLDM event 重複 | event ack flow 錯、endpoint retry、BMC 未去重 | pldmd journal、event sequence、logging entries |
| PLDM FW update 中斷 | transfer size、timeout、endpoint reset、activation policy | update log、MCTP trace、endpoint FW log |
| SPDM negotiation fail | version / capability / algorithm mismatch | SPDM transcript、policy、library version |
| SPDM certificate fail | trust anchor、cert chain、time、slot id、revocation | cert dump、time sync、security policy |
| SPDM measurement mismatch | endpoint firmware 不同、manifest 未更新、expected value 錯 | measurement digest、FW version、manifest |
| Hot-plug 後 endpoint 沒回來 | route stale、discovery 沒重新跑、power state gating | mctpd signal、kernel hotplug、D-Bus endpoint |
| Redfish 沒看到 PLDM sensor | D-Bus association 缺、sensor mapping 未建立 | busctl、ObjectMapper、bmcweb journal |


#### 20.15 Bring-up 建議流程

- 建立 MCTP endpoint 表，列出 endpoint、binding、physical path、power state、owner、EID、UUID、message type。
- 先驗證 physical link，再驗證 MCTP discovery，不要直接從 PLDM timeout 判斷問題。
- 確認 bus owner 與 EID assignment policy，做 BMC reboot、endpoint reset、host power cycle 後確認 EID 穩定性。
- 對每個 endpoint 執行 MCTP Control discovery，保存 UUID、message type、MTU、route。
- 對支援 PLDM 的 endpoint 執行 Base discovery，保存 type / command support。
- 若支援 Platform，讀 PDR repository，建立 sensor / effecter / event mapping，驗證 D-Bus 與 Redfish。
- 若支援 FRU / BIOS / FW update，逐項驗證資料來源、權限、update 中斷回復與 event log。
- 若支援 SPDM，先跑 version / capability / algorithm，再跑 certificate / challenge / measurement，最後依需求測 secure session。
- 對所有安全結果建立 event / inventory / health mapping，不只保留 tool output。
- 做 hot-plug、endpoint reset、BMC reboot、host power state transition、bus fault、timeout、firmware update、attestation fail 測試。
- 保存 mctp-pldm-spdm-debug log、protocol trace、Redfish output、event log、版本與 endpoint firmware 資訊。

#### 20.16 當前平台 MCTP / PLDM / SPDM 實測表


| 項目 | 指令 / 來源 | 實測值 | 備註 |
| --- | --- | --- | --- |
| MCTP kernel config | kernel .config | [待填] | CONFIG_MCTP / binding driver |
| MCTP services | systemctl / journal | [待填] | mctpd / vendor daemon |
| Endpoint list | mctpd D-Bus / mctp tool | [待填] | EID / UUID / route |
| Transport bindings | schematic / lspci / i2c | [待填] | SMBus / PCIe / I3C |
| Bus owner policy | platform design | [待填] | BMC / host / bridge |
| Message type support | MCTP control | [待填] | PLDM / SPDM / vendor |
| PLDM terminus list | pldmd / pldmtool | [待填] | TID / endpoint mapping |
| PLDM command support | GetPLDMTypes / Commands | [待填] | Base / Platform / FRU / FWU |
| PDR repository | pldmtool platform GetPDR | [待填] | sensor / effecter count |
| PLDM sensor mapping | D-Bus / Redfish | [待填] | unit / scale / association |
| PLDM FRU mapping | inventory / Redfish | [待填] | 權威端 |
| PLDM FW update | update test | [待填] | progress / activation / rollback |
| SPDM version / capability | SPDM tool / log | [待填] | 版本與演算法 |
| SPDM certificate | cert chain validation | [待填] | trust anchor / slot |
| SPDM measurement | measurement digest | [待填] | expected value |
| Event / health mapping | EventLog / Redfish | [待填] | attestation / PLDM event |


#### 20.17 回查結果

本章已回查前後文並補齊下列銜接點：

- 第 5 章周邊匯流排已介紹 MCTP / PLDM / SPDM 所需 physical binding，本章補上 endpoint、EID、route、PLDM terminus 與 SPDM attestation 流程。
- 第 10 章 I2C / PMBus 已涵蓋 SMBus / I2C bring-up，本章補上 MCTP over SMBus / I2C 的 bus owner、EID 與多 endpoint 注意事項。
- 第 15 章 Inventory / FRU / Asset 已定義資料權威端，本章補上 PLDM FRU 與 endpoint inventory 對映。
- 第 16 章 Logging / Event / Telemetry 已定義事件與安全 log，本章補上 PLDM event、SPDM attestation fail、FW update fail 的 logging / health 對映。
- 第 18～19 章 Host communication 相關章節可引用本章的 host / BMC sideband、PCIe VDM、BIOS / firmware PLDM flow。
- 第 24 章 Security Baseline 可引用本章的 SPDM trust anchor、certificate、measurement、policy 與 audit log。
- 第 25 章 Firmware Update 可引用本章的 PLDM Firmware Update 流程、transfer size、activation 與 rollback 測試。

#### 20.18 驗收 Checklist

-  已建立所有 MCTP endpoint、binding、physical path、EID、UUID、message type 與 owner 表。
-  Physical link、binding driver、mctpd / vendor MCTP daemon 已驗證。
-  EID assignment、bus owner、route table、MTU、message type support 已記錄。
-  BMC reboot、endpoint reset、host power cycle 後，endpoint discovery 與 route 可恢復。
-  PLDM Base discovery、type / command support 已驗證。
-  PLDM PDR repository 可讀，sensor / effecter / event / entity association 對映正確。
-  PLDM sensor 已對映到 D-Bus / Redfish，scale、unit、availability、association 已驗證。
-  PLDM FRU / BIOS / Firmware Update 若平台支援，權限、event、rollback 與 update 中斷回復已測試。
-  SPDM version、capability、algorithm negotiation 已完成。
-  SPDM certificate chain、challenge、measurement 驗證與 policy 已定義。
-  SPDM fail / measurement mismatch / cert fail 會產生 security event，且不洩漏敏感資料。
-  Hot-plug、route stale、timeout、endpoint reset、bus fault、large transfer、event storm 已測試。
-  mctp-pldm-spdm-debug log、protocol trace、journal、Redfish、EventLog、endpoint firmware version 已保存。

#### 20.19 本章參考資料

- DMTF MCTP Base Specification DSP0236: [https://www.dmtf.org/sites/default/files/standards/documents/DSP0236_1.3.3.pdf](https://www.dmtf.org/sites/default/files/standards/documents/DSP0236_1.3.3.pdf)
- DMTF SPDM Specification DSP0274: [https://www.dmtf.org/standards/spdm](https://www.dmtf.org/standards/spdm)
- DMTF SPDM over MCTP Binding Specification DSP0275: [https://www.dmtf.org/sites/default/files/standards/documents/DSP0275_1.0.2.pdf](https://www.dmtf.org/sites/default/files/standards/documents/DSP0275_1.0.2.pdf)
- DMTF libspdm reference implementation: [https://github.com/DMTF/libspdm](https://github.com/DMTF/libspdm)
- OpenBMC MCTP / PLDM communication overview: [https://deepwiki.com/openbmc/docs/4.7-mctp-and-pldm-communication](https://deepwiki.com/openbmc/docs/4.7-mctp-and-pldm-communication)
- OpenBMC PLDM overview: [https://deepwiki.com/openbmc/pldm](https://deepwiki.com/openbmc/pldm)
- OpenBMC MCTP design note: [https://github.com/CodeConstruct/openbmc-docs/blob/master/designs/mctp/mctp.md](https://github.com/CodeConstruct/openbmc-docs/blob/master/designs/mctp/mctp.md)
