@echo off
setlocal

set "PROJECT_DIR=%~dp0"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"

set "VERSION_FILE=%PROJECT_DIR%\.godot-version"
if not exist "%VERSION_FILE%" (
	echo [launch] Missing "%VERSION_FILE%"; cannot verify the pinned Godot version. 1>&2
	exit /b 1
)
set "GODOT_VERSION="
for /f "usebackq delims=" %%V in ("%VERSION_FILE%") do if not defined GODOT_VERSION set "GODOT_VERSION=%%V"
if not defined GODOT_VERSION (
	echo [launch] "%VERSION_FILE%" is empty. 1>&2
	exit /b 1
)

if defined WATCH_SETTINGS_PATH (
	set "SETTINGS_FILE=%WATCH_SETTINGS_PATH%"
) else (
	set "SETTINGS_FILE=%APPDATA%\WatchYongchang\renderer.cfg"
)

set "MODE=auto"
if defined WATCH_RENDERER set "MODE=%WATCH_RENDERER%"
if not defined WATCH_RENDERER if exist "%SETTINGS_FILE%" (
	for /f "tokens=2 delims==" %%M in ('findstr /b /c:"renderer_mode=" "%SETTINGS_FILE%" 2^>nul') do set "MODE=%%~M"
)
if /i not "%MODE%"=="auto" if /i not "%MODE%"=="vulkan" if /i not "%MODE%"=="opengl" set "MODE=auto"

set "VULKAN=0"
if exist "%SystemRoot%\System32\vulkan-1.dll" set "VULKAN=1"
if exist "%SystemRoot%\SysWOW64\vulkan-1.dll" set "VULKAN=1"
if "%VULKAN%"=="0" (
	where vulkaninfo.exe >nul 2>nul
	if not errorlevel 1 (
		vulkaninfo.exe --summary 2>nul | findstr /c:"deviceName" >nul
		if not errorlevel 1 set "VULKAN=1"
	)
)

set "TARGET=%MODE%"
if /i "%TARGET%"=="auto" (
	if "%VULKAN%"=="1" (
		set "TARGET=vulkan"
	) else (
		set "TARGET=opengl"
	)
)
if /i "%TARGET%"=="vulkan" if "%VULKAN%"=="0" (
	echo [launch] Vulkan requested but unavailable; falling back to OpenGL.
	set "TARGET=opengl"
)

set "GODOT="
if defined WATCH_GODOT if exist "%WATCH_GODOT%" set "GODOT=%WATCH_GODOT%"
if not defined GODOT if defined GDA_GODOT if exist "%GDA_GODOT%" set "GODOT=%GDA_GODOT%"
if not defined GODOT for %%G in (Godot_v%GODOT_VERSION%_win64_console.exe Godot_v%GODOT_VERSION%_win64.exe godot4.exe godot.exe) do if exist "%PROJECT_DIR%\%%G" if not defined GODOT set "GODOT=%PROJECT_DIR%\%%G"
if not defined GODOT for /f "delims=" %%G in ('where godot4.exe 2^>nul') do if not defined GODOT set "GODOT=%%G"
if not defined GODOT for /f "delims=" %%G in ('where godot.exe 2^>nul') do if not defined GODOT set "GODOT=%%G"
if not defined GODOT (
	echo [launch] Godot 4 was not found. Set WATCH_GODOT or GDA_GODOT, or add godot4.exe/godot.exe to PATH. 1>&2
	exit /b 127
)

set "GODOT_VERSION_PROBE=%GODOT%"
for %%P in ("%GODOT%") do set "GODOT_DIR=%%~dpP"
if exist "%GODOT_DIR%Godot_v%GODOT_VERSION%_win64_console.exe" set "GODOT_VERSION_PROBE=%GODOT_DIR%Godot_v%GODOT_VERSION%_win64_console.exe"
set "ACTUAL_GODOT_VERSION="
for /f "delims=" %%V in ('"%GODOT_VERSION_PROBE%" --version 2^>nul') do if not defined ACTUAL_GODOT_VERSION set "ACTUAL_GODOT_VERSION=%%V"
set "EXPECTED_PREFIX=%GODOT_VERSION:-=.%."
echo %ACTUAL_GODOT_VERSION% | findstr /b /l /c:"%EXPECTED_PREFIX%" >nul
if errorlevel 1 (
	echo [launch] Godot version mismatch: expected %GODOT_VERSION%, got %ACTUAL_GODOT_VERSION%. 1>&2
	if not "%WATCH_SKIP_GODOT_VERSION_CHECK%"=="1" (
		echo [launch] Install the pinned version or set WATCH_SKIP_GODOT_VERSION=1 for local experiments. 1>&2
		exit /b 1
	)
)

if /i "%TARGET%"=="vulkan" (
	set "METHOD=forward_plus"
	set "DRIVER=vulkan"
) else (
	set "METHOD=gl_compatibility"
	set "DRIVER=opengl3"
)

echo [launch] renderer=%TARGET% (mode=%MODE%)
pushd "%PROJECT_DIR%"
"%GODOT%" --path "%CD%" --rendering-method %METHOD% --rendering-driver %DRIVER% %*
set "EXIT_CODE=%ERRORLEVEL%"
popd
exit /b %EXIT_CODE%
