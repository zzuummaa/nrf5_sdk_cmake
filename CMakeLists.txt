cmake_minimum_required(VERSION 3.3)

project(ble_app_beacon C ASM)

include(CMake_nRF5x_settings.cmake)
include(CMake_nRF5x.cmake)

include_directories(config)

nRF5x_setup()

nRF5x_addBSP(null null null false)
nRF5x_addAppLibraries(button)
nRF5x_addAppTimer(APP)

#nRF5x_addBSP(true null null false)
#nRF5x_addAppTimer(FREERTOS)
#nRF5x_addAppFreeRTOS()
#nRF5x_addAppBLE(ble_advertising ble_services/ble_bas ble_services/ble_hrs ble_services/ble_dis )
#nRF5x_addAppBLESources(LIBRARY device_manager SOURCES device_manager_peripheral.c)
#nRF5x_addAppLibraries(button fifo sensorsim trace)
#nRF5x_addAppLibrarySources(LIBRARY uart SOURCES retarget.c app_uart_fifo.c)
#nRF5x_addAppLibrarySources(LIBRARY util SOURCES app_error.c nrf_assert.c)
#nRF5x_addAppDriverNRF(delay clock common gpiote uart pstorage)

set(BEACON_SOURCES ${SOURCE_FILES} main.c)
nRF5x_addExecutable(beacon "${BEACON_SOURCES}")