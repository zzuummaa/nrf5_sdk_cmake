cmake_minimum_required(VERSION 3.3)

project(ble_app_beacon C ASM)

include(CMake_nRF5x_settings.cmake)
include(CMake_nRF5x.cmake)

nRF5x_setup()
nRF5x_addBSP(null null null true)
#nRF5x_addAppTimer()
nRF5x_addAppButton()
nRF5x_addAppFreeRTOS()
set(BEACON_SOURCES ${SOURCE_FILES} "main.c")
nRF5x_addExecutable(beacon "${BEACON_SOURCES}")
