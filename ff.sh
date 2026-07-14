bash <<'BASH'
set -euo pipefail

rename_item()
{
    local src="$1"
    local dst="$2"

    if [[ ! -e "$src" ]]; then
        printf 'SKIP: source not found: %s\n' "$src"
        return 0
    fi

    if [[ -e "$dst" ]]; then
        printf 'ERROR: destination already exists: %s\n' "$dst" >&2
        exit 1
    fi

    printf 'RENAME: %s\n     -> %s\n' "$src" "$dst"
    mv -- "$src" "$dst"
}

# ============================================================
# 1. Rename Markdown files
# ============================================================

# Part 1
rename_item \
    "01_第一部分_硬體底層抽象層/01_Boot_Flow_與_SoC_初始化.md" \
    "01_第一部分_硬體底層抽象層/01_boot_flow_and_soc_initialization.md"

rename_item \
    "01_第一部分_硬體底層抽象層/02_Flash_Partition_與儲存架構.md" \
    "01_第一部分_硬體底層抽象層/02_flash_partition_and_storage_architecture.md"

rename_item \
    "01_第一部分_硬體底層抽象層/03_Pinmux_GPIO_通用設計模式.md" \
    "01_第一部分_硬體底層抽象層/03_pinmux_gpio_common_design_patterns.md"

rename_item \
    "01_第一部分_硬體底層抽象層/04_Reset_Clock_Power_Domain.md" \
    "01_第一部分_硬體底層抽象層/04_reset_clock_and_power_domain.md"

rename_item \
    "01_第一部分_硬體底層抽象層/05_周邊匯流排通用知識.md" \
    "01_第一部分_硬體底層抽象層/05_peripheral_bus_fundamentals.md"

rename_item \
    "01_第一部分_硬體底層抽象層/06_CPLD_FPGA_Board_Glue_Logic.md" \
    "01_第一部分_硬體底層抽象層/06_cpld_fpga_board_glue_logic.md"

# Part 2
rename_item \
    "02_第二部分_BSP_Kernel_與_Device_Tree/07_Build_System_與_BSP_結構.md" \
    "02_第二部分_BSP_Kernel_與_Device_Tree/07_build_system_and_bsp_structure.md"

rename_item \
    "02_第二部分_BSP_Kernel_與_Device_Tree/08_Device_Tree_通用寫法與排查.md" \
    "02_第二部分_BSP_Kernel_與_Device_Tree/08_device_tree_common_patterns_and_troubleshooting.md"

rename_item \
    "02_第二部分_BSP_Kernel_與_Device_Tree/09_U-boot_And_Kernel_Driver_與核心服務.md" \
    "02_第二部分_BSP_Kernel_與_Device_Tree/09_u_boot_kernel_drivers_and_core_services.md"

# Part 3
rename_item \
    "03_第三部分_平台監控與控制/10_I2C_PMBus_Framework.md" \
    "03_第三部分_平台監控與控制/10_i2c_pmbus_framework.md"

rename_item \
    "03_第三部分_平台監控與控制/11_OpenBMC_常用_Project_與服務速查.md" \
    "03_第三部分_平台監控與控制/11_openbmc_common_projects_and_services_reference.md"

rename_item \
    "03_第三部分_平台監控與控制/12_Sensor_抽象層.md" \
    "03_第三部分_平台監控與控制/12_sensor_abstraction_layer.md"

rename_item \
    "03_第三部分_平台監控與控制/13_Fan_Control_與_Thermal_Policy.md" \
    "03_第三部分_平台監控與控制/13_fan_control_and_thermal_policy.md"

rename_item \
    "03_第三部分_平台監控與控制/14_Power_Control.md" \
    "03_第三部分_平台監控與控制/14_power_control.md"

rename_item \
    "03_第三部分_平台監控與控制/15_Inventory_FRU_Asset_資料模型.md" \
    "03_第三部分_平台監控與控制/15_inventory_fru_asset_data_model.md"

rename_item \
    "03_第三部分_平台監控與控制/16_Logging_Event_Telemetry.md" \
    "03_第三部分_平台監控與控制/16_logging_event_and_telemetry.md"

rename_item \
    "03_第三部分_平台監控與控制/17_Presence_Intrusion_GPIO_State_Sensor.md" \
    "03_第三部分_平台監控與控制/17_presence_intrusion_gpio_state_sensor.md"

# Part 4
rename_item \
    "04_第四部分_Host_Communication/18_KCS_BT_SSIF_eSPI.md" \
    "04_第四部分_Host_Communication/18_kcs_bt_ssif_espi.md"

rename_item \
    "04_第四部分_Host_Communication/19_BIOS_UEFI_與_BMC_互動.md" \
    "04_第四部分_Host_Communication/19_bios_uefi_and_bmc_interaction.md"

# Part 5
rename_item \
    "05_第五部分_管理介面與網路/20_MCTP_PLDM_SPDM.md" \
    "05_第五部分_管理介面與網路/20_mctp_pldm_spdm.md"

rename_item \
    "05_第五部分_管理介面與網路/21_IPMI_通用知識.md" \
    "05_第五部分_管理介面與網路/21_ipmi_fundamentals.md"

rename_item \
    "05_第五部分_管理介面與網路/22_Redfish_通用知識.md" \
    "05_第五部分_管理介面與網路/22_redfish_fundamentals.md"

rename_item \
    "05_第五部分_管理介面與網路/23_Network_Services.md" \
    "05_第五部分_管理介面與網路/23_network_services.md"

# Part 6
rename_item \
    "06_第六部分_安全與韌體維運/24_Security_Baseline.md" \
    "06_第六部分_安全與韌體維運/24_security_baseline.md"

rename_item \
    "06_第六部分_安全與韌體維運/25_Firmware_Update.md" \
    "06_第六部分_安全與韌體維運/25_firmware_update.md"

rename_item \
    "06_第六部分_安全與韌體維運/26_Secure_Recovery_RMA_Field_Service.md" \
    "06_第六部分_安全與韌體維運/26_secure_recovery_rma_and_field_service.md"

# Part 7
rename_item \
    "07_第七部分_除錯、效能與測試/27_Debug_Methodology.md" \
    "07_第七部分_除錯、效能與測試/27_debug_methodology.md"

rename_item \
    "07_第七部分_除錯、效能與測試/28_Debug_Toolkit.md" \
    "07_第七部分_除錯、效能與測試/28_debug_toolkit.md"

rename_item \
    "07_第七部分_除錯、效能與測試/29_各類_Sensor_共用除錯指令及附錄.md" \
    "07_第七部分_除錯、效能與測試/29_common_sensor_debug_commands_and_appendix.md"

rename_item \
    "07_第七部分_除錯、效能與測試/30_Performance_Resource_Boot_Time.md" \
    "07_第七部分_除錯、效能與測試/30_performance_resource_and_boot_time.md"

rename_item \
    "07_第七部分_除錯、效能與測試/31_通用測試矩陣.md" \
    "07_第七部分_除錯、效能與測試/31_general_test_matrix.md"

# Part 8
rename_item \
    "08_第八部分_工廠與生產/32_Manufacturing_Factory.md" \
    "08_第八部分_工廠與生產/32_manufacturing_and_factory.md"

rename_item \
    "08_第八部分_工廠與生產/33_Calibration_Board_Data_Provisioning.md" \
    "08_第八部分_工廠與生產/33_calibration_board_data_and_provisioning.md"

# Part 9
rename_item \
    "09_第九部分_平台差異筆記本/34_SoC_筆記標準填寫模板.md" \
    "09_第九部分_平台差異筆記本/34_soc_notes_template.md"

# Part 10
rename_item \
    "10_第十部分_附錄/A01_常用縮寫與名詞對照.md" \
    "10_第十部分_附錄/A01_common_abbreviations_and_terms.md"

rename_item \
    "10_第十部分_附錄/A02_常用指令速查.md" \
    "10_第十部分_附錄/A02_common_commands_reference.md"

rename_item \
    "10_第十部分_附錄/A03_Log_收集套件範本.md" \
    "10_第十部分_附錄/A03_log_collection_package_template.md"

rename_item \
    "10_第十部分_附錄/A04_Bring-up_與驗收_Checklist.md" \
    "10_第十部分_附錄/A04_bring_up_and_acceptance_checklist.md"

rename_item \
    "10_第十部分_附錄/A05_文件填寫範本.md" \
    "10_第十部分_附錄/A05_documentation_template.md"

# ============================================================
# 2. Rename chapter directories
# ============================================================

rename_item \
    "01_第一部分_硬體底層抽象層" \
    "01_part_1_hardware_abstraction_layer"

rename_item \
    "02_第二部分_BSP_Kernel_與_Device_Tree" \
    "02_part_2_bsp_kernel_and_device_tree"

rename_item \
    "03_第三部分_平台監控與控制" \
    "03_part_3_platform_monitoring_and_control"

rename_item \
    "04_第四部分_Host_Communication" \
    "04_part_4_host_communication"

rename_item \
    "05_第五部分_管理介面與網路" \
    "05_part_5_management_interfaces_and_networking"

rename_item \
    "06_第六部分_安全與韌體維運" \
    "06_part_6_security_and_firmware_maintenance"

rename_item \
    "07_第七部分_除錯、效能與測試" \
    "07_part_7_debugging_performance_and_testing"

rename_item \
    "08_第八部分_工廠與生產" \
    "08_part_8_manufacturing_and_production"

rename_item \
    "09_第九部分_平台差異筆記本" \
    "09_part_9_platform_specific_notes"

rename_item \
    "10_第十部分_附錄" \
    "10_part_10_appendices"

printf '\nRename completed successfully.\n'
printf 'Checking for remaining non-ASCII paths...\n\n'

non_ascii_paths="$(
    find . -path './.git' -prune -o -print |
        LC_ALL=C grep '[^ -~]' || true
)"

if [[ -n "$non_ascii_paths" ]]; then
    printf 'The following non-ASCII paths remain:\n%s\n' "$non_ascii_paths"
else
    printf 'All paths are ASCII.\n'
fi
BASH