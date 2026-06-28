local system = require("lib/system")

local M = {}

local function cmd(content)
    return content:gsub("\n", "\r\n")
end

local function vcvars_default(version)
    if version == nil or version == "" then
        return ""
    end

    return string.format('if not defined VSBUILDTOOLS_VCVARS_VER set "VSBUILDTOOLS_VCVARS_VER=%s"\n', version)
end

local function vcvars_ver_arg()
    return [[set "VSBUILDTOOLS_VCVARS_VER_ARG="
if defined VSBUILDTOOLS_VCVARS_VER set "VSBUILDTOOLS_VCVARS_VER_ARG=-vcvars_ver=%VSBUILDTOOLS_VCVARS_VER%"
]]
end

function M.install(path, version, default_vcvars_ver)
    local bin = system.join_path(path, "bin")
    system.mkdir(bin)

    local defaults = vcvars_default(default_vcvars_ver)
    local version_text = tostring(version or "")

    system.write_file(system.join_path(bin, "vsdevcmd.cmd"), cmd([[@echo off
]] .. defaults .. [[if not defined VSBUILDTOOLS_ARCH set "VSBUILDTOOLS_ARCH=x64"
if not defined VSBUILDTOOLS_HOST_ARCH set "VSBUILDTOOLS_HOST_ARCH=x64"
call "%~dp0..\Common7\Tools\VsDevCmd.bat" -arch=%VSBUILDTOOLS_ARCH% -host_arch=%VSBUILDTOOLS_HOST_ARCH% %*
]]))

    system.write_file(system.join_path(bin, "vcvarsall.cmd"), cmd([[@echo off
]] .. defaults .. vcvars_ver_arg() .. [[if "%~1"=="" (
  if not defined VSBUILDTOOLS_ARCH set "VSBUILDTOOLS_ARCH=x64"
  call "%~dp0..\VC\Auxiliary\Build\vcvarsall.bat" %VSBUILDTOOLS_ARCH% %VSBUILDTOOLS_VCVARS_VER_ARG%
) else (
  call "%~dp0..\VC\Auxiliary\Build\vcvarsall.bat" %* %VSBUILDTOOLS_VCVARS_VER_ARG%
)
]]))

    system.write_file(system.join_path(bin, "vcvars64.cmd"), cmd([[@echo off
]] .. defaults .. vcvars_ver_arg() .. [[call "%~dp0..\VC\Auxiliary\Build\vcvarsall.bat" x64 %VSBUILDTOOLS_VCVARS_VER_ARG% %*
]]))

    system.write_file(system.join_path(bin, "vcvars32.cmd"), cmd([[@echo off
]] .. defaults .. vcvars_ver_arg() .. [[call "%~dp0..\VC\Auxiliary\Build\vcvarsall.bat" x86 %VSBUILDTOOLS_VCVARS_VER_ARG% %*
]]))

    system.write_file(system.join_path(bin, "vcvarsarm64.cmd"), cmd([[@echo off
]] .. defaults .. vcvars_ver_arg() .. [[call "%~dp0..\VC\Auxiliary\Build\vcvarsall.bat" arm64 %VSBUILDTOOLS_VCVARS_VER_ARG% %*
]]))

    system.write_file(system.join_path(bin, "vsbuildtools-run.cmd"), cmd([[@echo off
]] .. defaults .. vcvars_ver_arg() .. [[if "%~1"=="" (
  echo Usage: vsbuildtools-run ^<command^> [args...]
  exit /b 2
)
if not defined VSBUILDTOOLS_ARCH set "VSBUILDTOOLS_ARCH=x64"
call "%~dp0..\VC\Auxiliary\Build\vcvarsall.bat" %VSBUILDTOOLS_ARCH% %VSBUILDTOOLS_VCVARS_VER_ARG% >nul
if errorlevel 1 exit /b %errorlevel%
%*
exit /b %errorlevel%
]]))

    system.write_file(system.join_path(bin, "vsbuildtools-shell.cmd"), cmd([[@echo off
]] .. defaults .. vcvars_ver_arg() .. [[if not defined VSBUILDTOOLS_ARCH set "VSBUILDTOOLS_ARCH=x64"
cmd /k ""%~dp0..\VC\Auxiliary\Build\vcvarsall.bat" %VSBUILDTOOLS_ARCH% %VSBUILDTOOLS_VCVARS_VER_ARG%"
]]))

    system.write_file(system.join_path(bin, "vsbuildtools-cl.cmd"), cmd([[@echo off
]] .. defaults .. vcvars_ver_arg() .. [[if not defined VSBUILDTOOLS_ARCH set "VSBUILDTOOLS_ARCH=x64"
call "%~dp0..\VC\Auxiliary\Build\vcvarsall.bat" %VSBUILDTOOLS_ARCH% %VSBUILDTOOLS_VCVARS_VER_ARG% >nul
if errorlevel 1 exit /b %errorlevel%
cl.exe %*
exit /b %errorlevel%
]]))

    system.write_file(system.join_path(bin, "vsbuildtools-cmake.cmd"), cmd([[@echo off
]] .. defaults .. vcvars_ver_arg() .. [[if not defined VSBUILDTOOLS_ARCH set "VSBUILDTOOLS_ARCH=x64"
call "%~dp0..\VC\Auxiliary\Build\vcvarsall.bat" %VSBUILDTOOLS_ARCH% %VSBUILDTOOLS_VCVARS_VER_ARG% >nul
if errorlevel 1 exit /b %errorlevel%
cmake.exe %*
exit /b %errorlevel%
]]))

    system.write_file(system.join_path(bin, "vsbuildtools-msbuild.cmd"), cmd([[@echo off
]] .. defaults .. vcvars_ver_arg() .. [[if not defined VSBUILDTOOLS_ARCH set "VSBUILDTOOLS_ARCH=x64"
call "%~dp0..\VC\Auxiliary\Build\vcvarsall.bat" %VSBUILDTOOLS_ARCH% %VSBUILDTOOLS_VCVARS_VER_ARG% >nul
if errorlevel 1 exit /b %errorlevel%
msbuild.exe %*
exit /b %errorlevel%
]]))

    system.write_file(system.join_path(bin, "vsbuildtools-info.cmd"), cmd(string.format([[@echo off
%s%sif not defined VSBUILDTOOLS_ARCH set "VSBUILDTOOLS_ARCH=x64"
echo VSBUILDTOOLS_HOME=%%~dp0..
echo VSBUILDTOOLS_VERSION=%s
echo VSBUILDTOOLS_ARCH=%%VSBUILDTOOLS_ARCH%%
if defined VSBUILDTOOLS_VCVARS_VER echo VSBUILDTOOLS_VCVARS_VER=%%VSBUILDTOOLS_VCVARS_VER%%
if exist "%%~dp0..\VC\Auxiliary\Build\vcvarsall.bat" echo vcvarsall=present
if exist "%%~dp0..\Common7\Tools\VsDevCmd.bat" echo VsDevCmd=present
call "%%~dp0..\VC\Auxiliary\Build\vcvarsall.bat" %%VSBUILDTOOLS_ARCH%% %%VSBUILDTOOLS_VCVARS_VER_ARG%% >nul
if errorlevel 1 exit /b %%errorlevel%%
where cl
cl
]], defaults, vcvars_ver_arg(), version_text)))

    system.write_file(system.join_path(bin, "vsbuildtools-update.cmd"), cmd([[@echo off
setlocal
set "INSTALL_PATH=%~dp0.."
set "VS_INSTALLER=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vs_installer.exe"
if not exist "%VS_INSTALLER%" set "VS_INSTALLER=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\setup.exe"
if not exist "%VS_INSTALLER%" (
  echo Visual Studio Installer was not found.
  exit /b 1
)
"%VS_INSTALLER%" update --installPath "%INSTALL_PATH%" --quiet --norestart
set "CODE=%ERRORLEVEL%"
if "%CODE%"=="3010" exit /b 0
if "%CODE%"=="1641" exit /b 0
exit /b %CODE%
]]))

    system.write_file(system.join_path(bin, "vsbuildtools-uninstall.cmd"), cmd([[@echo off
setlocal
set "INSTALL_PATH=%~dp0.."
set "VS_INSTALLER=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vs_installer.exe"
if not exist "%VS_INSTALLER%" set "VS_INSTALLER=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\setup.exe"
if not exist "%VS_INSTALLER%" (
  echo Visual Studio Installer was not found.
  exit /b 1
)
"%VS_INSTALLER%" uninstall --installPath "%INSTALL_PATH%" --quiet --norestart
set "CODE=%ERRORLEVEL%"
if "%CODE%"=="3010" set "CODE=0"
if "%CODE%"=="1641" set "CODE=0"
if "%CODE%"=="0" (
  echo Visual Studio Build Tools uninstall complete.
  echo You may now run: mise uninstall vsbuildtools
)
exit /b %CODE%
]]))

    system.write_file(system.join_path(bin, "vsbuildtools-list.cmd"), cmd([[@echo off
setlocal
echo.
echo   Installed Visual Studio Build Tools instances
echo   ----------------------------------------------------
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist "%VSWHERE%" (
  "%VSWHERE%" -products Microsoft.VisualStudio.Product.BuildTools -format table
) else (
  echo   vswhere.exe not found
)
echo.
echo   WinGet Visual Studio Build Tools packages
echo   ----------------------------------------------------
where winget >nul 2>&1
if errorlevel 1 (
  echo   winget not found
) else (
  winget search --source winget --id Microsoft.VisualStudio --accept-source-agreements | findstr /R /C:"Microsoft\.VisualStudio.*BuildTools"
  winget search --source winget --id Microsoft.BuildTools2015 --accept-source-agreements | findstr /C:"Microsoft.BuildTools2015"
)
echo.
]]))
end

return M
