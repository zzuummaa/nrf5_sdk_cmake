cmake_minimum_required(VERSION 3.6)

# check if all the necessary toolchain SDK and tools paths have been provided.
if (NOT ARM_NONE_EABI_TOOLCHAIN_PATH)
    message(FATAL_ERROR "The path to the arm-none-eabi-gcc toolchain (ARM_NONE_EABI_TOOLCHAIN_PATH) must be set.")
endif ()
message(STATUS "ARM toolchain path: ${ARM_NONE_EABI_TOOLCHAIN_PATH}")

if (NOT NRF5_SDK_PATH)
    message(FATAL_ERROR "The path to the nRF5 SDK (NRF5_SDK_PATH) must be set.")
endif()
message(STATUS "NRF5 SDK path: ${NRF5_SDK_PATH}")

if (NOT MERGEHEX_PATH)
    message(FATAL_ERROR "The path to the mergehex util (MERGEHEX_PATH) must be set.")
endif()
message(STATUS "mergehex path: ${MERGEHEX_PATH}")

if (NOT OPENOCD_PATH)
    message(FATAL_ERROR "The path to the openocd (OPENOCD_PATH) must be set.")
endif()
message(STATUS "openocd path: ${OPENOCD_PATH}")

# check if the nRF target has been set
if (NRF_TARGET MATCHES "nrf51")
elseif (NRF_TARGET MATCHES "nrf52")
    message(FATAL_ERROR "nRF52 not supported yet")
elseif (NOT NRF_TARGET)
    message(FATAL_ERROR "nRF target must be defined")
else ()
    message(FATAL_ERROR "Only nRF51 and rRF52 boards are supported right now")
endif ()

if (SOFTDEVICE MATCHES "s110")
    set(WRITE_IMAGE_OFFSET "0x18000")
elseif (SOFTDEVICE MATCHES "s130")
    set(WRITE_IMAGE_OFFSET "0x1c000")
elseif (NOT NRF_TARGET)
    message(FATAL_ERROR "software device must be defined (SOFTDEVICE variable)")
else ()
    message(FATAL_ERROR "Only s110 and s130 software devices supported")
endif()

macro(nRF5x_setup)
    # fix on macOS: prevent cmake from adding implicit parameters to Xcode
    set(CMAKE_OSX_SYSROOT "../..")
    set(CMAKE_OSX_DEPLOYMENT_TARGET "")

    # language standard/version settings
    set(CMAKE_C_STANDARD 99)
    set(CMAKE_CXX_STANDARD 98)

    # configure cmake to use the arm-none-eabi-gcc
    set(CMAKE_C_COMPILER "${ARM_NONE_EABI_TOOLCHAIN_PATH}/bin/arm-none-eabi-gcc")
    set(CMAKE_CXX_COMPILER "${ARM_NONE_EABI_TOOLCHAIN_PATH}/bin/arm-none-eabi-c++")
    set(CMAKE_ASM_COMPILER "${ARM_NONE_EABI_TOOLCHAIN_PATH}/bin/arm-none-eabi-gcc")

    include_directories(
            "${NRF5_SDK_PATH}/components/softdevice/common/softdevice_handler"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/softdevice/common/softdevice_handler/softdevice_handler.c"
            )

    # CPU specyfic settings
    if (NRF_TARGET MATCHES "nrf51")
        # nRF51 (nRF51-DK => PCA10028)

        set(NRF5_LINKER_SCRIPT "${CMAKE_SOURCE_DIR}/gcc_nrf51.ld")
        set(CPU_FLAGS "-mcpu=cortex-m0 -mfloat-abi=soft")
        add_definitions(-DBOARD_PCA10028 -DNRF51 -DNRF51422 -DS130)
        add_definitions(-DSWI_DISABLE0 -DNRF_SD_BLE_API_VERSION=2 -DBLE_STACK_SUPPORT_REQD)
        include_directories(
                "${NRF5_SDK_PATH}/components/softdevice/s130/headers"
        )
        list(APPEND SDK_SOURCE_FILES
                "${NRF5_SDK_PATH}/components/toolchain/system_nrf51.c"
                "${NRF5_SDK_PATH}/components/toolchain/gcc/gcc_startup_nrf51.S"
                )
        set(SOFTDEVICE_PATH "${NRF5_SDK_PATH}/components/softdevice/s130/hex/s130_nrf51_1.0.0_softdevice.hex")
        set(SOFTDEVICE_POSTFIX "${SOFTDEVICE}")
    elseif (NRF_TARGET MATCHES "nrf52")
        # nRF52 (nRF52-DK => PCA10040)

        set(NRF5_LINKER_SCRIPT "${CMAKE_SOURCE_DIR}/gcc_nrf52.ld")
        set(CPU_FLAGS "-mcpu=cortex-m4 -mfloat-abi=hard -mfpu=fpv4-sp-d16")
        add_definitions(-DNRF52 -DNRF52832 -DNRF52_PAN_64 -DNRF52_PAN_12 -DNRF52_PAN_58 -DNRF52_PAN_54 -DNRF52_PAN_31 -DNRF52_PAN_51 -DNRF52_PAN_36 -DNRF52_PAN_15 -DNRF52_PAN_20 -DNRF52_PAN_55 -DBOARD_PCA10040)
        add_definitions(-DSOFTDEVICE_PRESENT -DS132 -DBLE_STACK_SUPPORT_REQD -DNRF_SD_BLE_API_VERSION=3)
        include_directories(
                "${NRF5_SDK_PATH}/components/softdevice/s132/headers"
                "${NRF5_SDK_PATH}/components/softdevice/s132/headers/nrf52"
        )
        list(APPEND SDK_SOURCE_FILES
                "${NRF5_SDK_PATH}/components/toolchain/system_nrf52.c"
                "${NRF5_SDK_PATH}/components/toolchain/gcc/gcc_startup_nrf52.S"
                )
        set(SOFTDEVICE_PATH "${NRF5_SDK_PATH}/components/softdevice/s132/hex/s132_nrf52_3.0.0_softdevice.hex")
        set(SOFTDEVICE_POSTFIX "s132")
    endif ()


    if (DEBUG_ENABLE)
        set(OPTIMITHATION_FLAGS "-Wall -Werror -O0 -g3")
    else()
        set(OPTIMITHATION_FLAGS "-Wall -Werror -O3 -g3")
    endif()
    set(COMMON_FLAGS "-MP -MD -mthumb -mabi=aapcs ${OPTIMITHATION_FLAGS} -ffunction-sections -fdata-sections -fno-strict-aliasing -fno-builtin --short-enums ${CPU_FLAGS}")


    # compiler/assambler/linker flags
    set(CMAKE_C_FLAGS "${COMMON_FLAGS}")
    set(CMAKE_CXX_FLAGS "${COMMON_FLAGS}")
    set(CMAKE_ASM_FLAGS "-MP -MD -std=c99 -x assembler-with-cpp")
    set(CMAKE_EXE_LINKER_FLAGS "-mthumb -mabi=aapcs -std=gnu++98 -std=c99 -L ${NRF5_SDK_PATH}/components/toolchain/gcc ${CPU_FLAGS} -Wl,--gc-sections --specs=nano.specs -lc -lnosys")
    # note: we must override the default cmake linker flags so that CMAKE_C_FLAGS are not added implicitly
    set(CMAKE_C_LINK_EXECUTABLE "${CMAKE_C_COMPILER} <LINK_FLAGS> <OBJECTS> -o <TARGET>")
    set(CMAKE_CXX_LINK_EXECUTABLE "${CMAKE_C_COMPILER} <LINK_FLAGS> <OBJECTS> -lstdc++ -o <TARGET>")

    include_directories(".")

    # basic board definitions and drivers
    include_directories(
            "${NRF5_SDK_PATH}/components/device"
            "${NRF5_SDK_PATH}/components/libraries/util"
            "${NRF5_SDK_PATH}/components/drivers_nrf/hal"
            "${NRF5_SDK_PATH}/components/drivers_nrf/common"
            "${NRF5_SDK_PATH}/components/drivers_nrf/delay"
            "${NRF5_SDK_PATH}/components/drivers_nrf/uart"
            "${NRF5_SDK_PATH}/components/drivers_nrf/clock"
            "${NRF5_SDK_PATH}/components/drivers_nrf/rtc"
            "${NRF5_SDK_PATH}/components/drivers_nrf/gpiote"
            "${NRF5_SDK_PATH}/components/drivers_nrf/config"
    )

    # toolchain specyfic
    include_directories(
            "${NRF5_SDK_PATH}/components/toolchain/"
            "${NRF5_SDK_PATH}/components/toolchain/gcc"
            "${NRF5_SDK_PATH}/components/toolchain/cmsis/include"
    )

    # log
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/log"
            "${NRF5_SDK_PATH}/components/libraries/log/src"
            "${NRF5_SDK_PATH}/components/libraries/timer"
    )

    # Segger RTT
    include_directories(
            "${NRF5_SDK_PATH}/external/segger_rtt/"
    )

    # basic board support and drivers
    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/drivers_nrf/common/nrf_drv_common.c"
            "${NRF5_SDK_PATH}/components/drivers_nrf/clock/nrf_drv_clock.c"
            "${NRF5_SDK_PATH}/components/drivers_nrf/uart/nrf_drv_uart.c"
            "${NRF5_SDK_PATH}/components/drivers_nrf/gpiote/nrf_drv_gpiote.c"
            "${NRF5_SDK_PATH}/components/drivers_nrf/delay/nrf_delay.c"
            )

    # drivers and utils
    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/util/nrf_assert.c"
            "${NRF5_SDK_PATH}/components/libraries/util/app_error.c"
#            "${NRF5_SDK_PATH}/components/libraries/util/app_util_platform.c"
#            "${NRF5_SDK_PATH}/components/libraries/util/sdk_mapped_flags.c"
            )

    # Segger RTT
#    list(APPEND SDK_SOURCE_FILES
#            "${NRF5_SDK_PATH}/components/drivers_ext/segger_rtt/RTT_Syscalls_GCC.c"
#            "${NRF5_SDK_PATH}/components/drivers_ext/segger_rtt/SEGGER_RTT.c"
#            "${NRF5_SDK_PATH}/components/drivers_ext/segger_rtt/SEGGER_RTT_printf.c"
#            )

    # Common Bluetooth Low Energy files
    include_directories(
            "${NRF5_SDK_PATH}/components/ble"
            "${NRF5_SDK_PATH}/components/ble/common"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/ble/common/ble_advdata.c"
            "${NRF5_SDK_PATH}/components/ble/common/ble_conn_params.c"
            "${NRF5_SDK_PATH}/components/ble/common/ble_conn_state.c"
            "${NRF5_SDK_PATH}/components/ble/common/ble_srv_common.c"
            )

    # adds target for erasing and flashing the board with a softdevice
    add_custom_target(FLASH_SOFTDEVICE ALL
            COMMAND ${OPENOCD_PATH} -f interface/stlink.cfg -f target/nrf51.cfg -c init -c \"reset halt\" -c \"nrf51 mass_erase 0\" -c \"flash write_image ${SOFTDEVICE_PATH}\" -c reset -c exit
            )

endmacro(nRF5x_setup)

# adds a target for comiling and flashing an executable
macro(nRF5x_addExecutable EXECUTABLE_NAME SOURCE_FILES)
    # executable
    add_executable(${EXECUTABLE_NAME} ${SDK_SOURCE_FILES} ${SOURCE_FILES})
    set_target_properties(${EXECUTABLE_NAME} PROPERTIES SUFFIX ".out")
    set_target_properties(${EXECUTABLE_NAME} PROPERTIES LINK_FLAGS "-Wl,-Map=${EXECUTABLE_NAME}.map -T\"${NRF5_LINKER_SCRIPT}\"")

    # additional POST BUILD setps to create the .bin and .hex files
    add_custom_command(TARGET ${EXECUTABLE_NAME}
            POST_BUILD
            COMMAND ${ARM_NONE_EABI_TOOLCHAIN_PATH}/bin/arm-none-eabi-size ${EXECUTABLE_NAME}.out
            COMMAND ${ARM_NONE_EABI_TOOLCHAIN_PATH}/bin/arm-none-eabi-objcopy -O binary ${EXECUTABLE_NAME}.out "${EXECUTABLE_NAME}.bin"
            COMMAND ${ARM_NONE_EABI_TOOLCHAIN_PATH}/bin/arm-none-eabi-objcopy -O ihex ${EXECUTABLE_NAME}.out "${EXECUTABLE_NAME}.hex"
            COMMENT "post build steps for ${EXECUTABLE_NAME}")

    # custom target for flashing the board
    add_custom_target(FLASH_${EXECUTABLE_NAME} ALL
            COMMAND ${OPENOCD_PATH} -f interface/stlink.cfg -f target/nrf51.cfg -c init -c \"reset halt\" -c \"flash write_image ${EXECUTABLE_NAME}.hex ${WRITE_IMAGE_OFFSET}\" -c reset -c exit
            DEPENDS ${EXECUTABLE_NAME}
            COMMENT "flashing ${EXECUTABLE_NAME}.hex"
            )

    add_custom_target("${EXECUTABLE_NAME}_${SOFTDEVICE_POSTFIX}" ALL
            COMMAND "${MERGEHEX_PATH}" -m "${SOFTDEVICE_PATH}" "${EXECUTABLE_NAME}.hex" -o "${EXECUTABLE_NAME}_${SOFTDEVICE_POSTFIX}.hex"
            DEPENDS ${EXECUTABLE_NAME}
            COMMENT "merging ${EXECUTABLE_NAME}.hex and softdevice"
            )

    add_custom_target(FLASH_${EXECUTABLE_NAME}_${SOFTDEVICE_POSTFIX} ALL
            COMMAND ${OPENOCD_PATH} -f interface/stlink.cfg -f target/nrf51.cfg -c init -c \"reset halt\" -c "nrf51 mass_erase 0" -c \"flash write_image ${EXECUTABLE_NAME}_${SOFTDEVICE_POSTFIX}.hex\" -c reset -c exit
            DEPENDS "${EXECUTABLE_NAME}_${SOFTDEVICE_POSTFIX}"
            COMMENT "flashing ${EXECUTABLE_NAME}_${SOFTDEVICE_POSTFIX}"
            )
endmacro()

# adds app-level scheduler library
macro(nRF5x_addAppScheduler)
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/scheduler"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/scheduler/app_scheduler.c"
            "${NRF5_SDK_PATH}/components/softdevice/common/softdevice_handler/softdevice_handler_appsh.c"
            )

endmacro(nRF5x_addAppScheduler)

# adds app-level FIFO libraries
macro(nRF5x_addAppFIFO)
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/fifo"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/fifo/app_fifo.c"
            )

endmacro(nRF5x_addAppFIFO)

# adds app-level Timer libraries
macro(nRF5x_addAppTimer)
    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/timer/app_timer.c"
            )
endmacro(nRF5x_addAppTimer)

# adds app-level UART libraries
macro(nRF5x_addAppUART)
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/uart"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/uart/app_uart_fifo.c"
            )

endmacro(nRF5x_addAppUART)

# adds app-level Button library
macro(nRF5x_addAppButton)
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/button"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/button/app_button.c"
            )

endmacro(nRF5x_addAppButton)

# adds BSP (board support package) library
macro(nRF5x_addBSP WITH_BLE_BTN WITH_ANT_BTN WITH_NFC)
    include_directories(
            "${NRF5_SDK_PATH}/examples/bsp"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/examples/bsp/bsp.c"
            )

    if (${WITH_BLE_BTN})
        list(APPEND SDK_SOURCE_FILES
                "${NRF5_SDK_PATH}/components/libraries/bsp/bsp_btn_ble.c"
                )
    endif ()

    if (${WITH_ANT_BTN})
        list(APPEND SDK_SOURCE_FILES
                "${NRF5_SDK_PATH}/components/libraries/bsp/bsp_btn_ant.c"
                )
    endif ()

    if (${WITH_NFC})
        list(APPEND SDK_SOURCE_FILES
                "${NRF5_SDK_PATH}/components/libraries/bsp/bsp_nfc.c"
                )
    endif ()

endmacro(nRF5x_addBSP)

# adds Bluetooth Low Energy GATT support library
macro(nRF5x_addBLEGATT)
    include_directories(
            "${NRF5_SDK_PATH}/components/ble/nrf_ble_gatt"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/ble/nrf_ble_gatt/nrf_ble_gatt.c"
            )

endmacro(nRF5x_addBLEGATT)

# adds Bluetooth Low Energy advertising support library
macro(nRF5x_addBLEAdvertising)
    include_directories(
            "${NRF5_SDK_PATH}/components/ble/ble_advertising"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/ble/ble_advertising/ble_advertising.c"
            )

endmacro(nRF5x_addBLEAdvertising)

# adds Bluetooth Low Energy advertising support library
macro(nRF5x_addBLEPeerManager)
    include_directories(
            "${NRF5_SDK_PATH}/components/ble/peer_manager"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/ble/peer_manager/gatt_cache_manager.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/gatts_cache_manager.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/id_manager.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/peer_data.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/peer_data_storage.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/peer_database.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/peer_id.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/peer_manager.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/pm_buffer.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/pm_mutex.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/security_dispatcher.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/security_manager.c"
            )

endmacro(nRF5x_addBLEPeerManager)

# adds app-level FDS (flash data storage) library
macro(nRF5x_addAppFDS)
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/fds"
            "${NRF5_SDK_PATH}/components/libraries/fstorage"
            "${NRF5_SDK_PATH}/components/libraries/experimental_section_vars"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/fds/fds.c"
            "${NRF5_SDK_PATH}/components/libraries/fstorage/fstorage.c"
            )

endmacro(nRF5x_addAppFDS)
