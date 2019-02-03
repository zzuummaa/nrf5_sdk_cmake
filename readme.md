# cmake-nRF5x

Cmake script for projects targeting Nordic Semiconductor nRF5x series devices using the GCC toolchain from ARM.

# Dependencies

The script makes use of the following tools:

- nRF51 Software Development Kit 10.0.0 - SoC specific drivers and libraries
- nRF5 Command Line Tools - contains util for merging hex files 
- ST-Link V2 - in-circuit debugger and programmer with SWD interface
- OpenOCD - open-source software tool for programming custom devices
- arm-non-eabi-gcc by ARM and the GCC Team - compiler toolchain for embedded (= bare metal) ARM chips

# Setup

1. Place the CMake_nRF5x.cmake into the root of your project

2. Search the SDK `example` directory for a `nrf_drv_config.h` and a linker script (normally named `<project_name>_gcc_<chip familly>.ld`) that fits your chip and project needs.

3. Copy the `nrf_drv_config.h` into the root of your project. Modify it as required for you project.

4. Copy the linker script into the root of your project. Rename it to just `gcc_<chip familly>.ld` For example:
	
	```
	gcc_nrf51.ld
	```
5. Create a new `CMakeLists.txt` file at the same level. Add the project standard cmake project header

	```cmake
	cmake_minimum_required(VERSION 3.6)
	project(your_project_name C ASM)
	```
	_Note_: you can add `CXX` between `C ASM` to add c++ support
	
6. Set your target chip family: `nRF51`

	```cmake
	set(NRF_TARGET "nrf51") 
	```

7. Set variables with paths to external dependencies:

	```cmake
	set(ARM_NONE_EABI_TOOLCHAIN_PATH "C:/Program Files (x86)/GNU Tools Arm Embedded/7 2018-q2-update")
    set(NRF5_SDK_PATH "C:/Users/Stephan/nRF51_SDK")
    set(MERGEHEX_PATH "C:/Program Files (x86)/Nordic Semiconductor/nrf5x/bin/mergehex")
	```
	
	_Optional_: You can put the above lines into a separate file (e.g. `CMake_nRF5x_settings.cmake`) and include it in the `CMakeLists.txt` file:

	```cmake 
	include("CMake_nRF5x_settings.cmake")
	```

8. Include this script so the "CMakeLists.txt" can use it

	```cmake
	include("CMake_nRF5x.cmake")
	```

9. Perform the base setup

	```cmake
	nRF5x_setup()
	```
	
10. Optionally add additional libraries:

	```cmake
	nRF5x_addAppFIFO()
	```
	_Note_: only the most common drivers and libraries are wrapped with cmake macros. If you need more, you can use `include_directories` and `list(APPEND SDK_SOURCE_FILES ...)` to add them. For example, in order to add the Bluetooth Battery Service:

	```cmake
	include_directories(
	        "${NRF5_SDK_PATH}/components/ble/ble_services/ble_bas"
	)
		
	list(APPEND SDK_SOURCE_FILES
	        "${NRF5_SDK_PATH}/components/ble/ble_services/ble_bas/ble_bas.c"
	        )
	```
	
11. Append you source files using `list(APPEND SOURCE_FILES ...)` and headers using `include_directories`. For example:

	```cmake
	include_directories(".")
	list(APPEND SOURCE_FILES "main.c")
	```

12. Finish setup by calling `nRF5x_addExecutable`

	```cmake
	nRF5x_addExecutable(${PROJECT_NAME} "${SOURCE_FILES}")
	```

# Build

After setup you can use cmake as usual:

1. Generate the actual build files (out-of-source builds are strongly recomended):

	```commandline
	cmake -H. -B"cmake-build" -G "Unix Makefiles"
	```

2. Build your app:

	```commandline
	cmake --build "cmake-build" --target <your project name>
	```

# Flash

In addition to the build target (named like your project) the script adds some support targets:

`FLASH_SOFTDEVICE` To flash a nRF softdevice to the SoC (typically done only once for each SoC)

```commandline
cmake --build "cmake-build" --target FLASH_SOFTDEVICE
```

`FLASH_<your project name>` To flash your application (note that hex writes in after-softdevice address)

```commandline
cmake --build "cmake-build" --target FLASH_<your project name>
```

`FLASH_ERASE` To flash softdevice and your application together

```commandline
cmake --build "cmake-build" --target FLASH_<your project name>_<softdevice_id>
```

# License

MIT for the `CMake_nRF5x.cmake` file. 

Please note that the nRF5x SDK by Nordic Semiconductor is covered by it's own license and shouldn't be re-distributed. 
