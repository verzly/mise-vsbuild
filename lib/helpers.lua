local system = require("lib/system")

local M = {}

local function cmd(content)
    return content:gsub("\n", "\r\n")
end

function M.install(path, version)
    local bin = system.join_path(path, "bin")
    system.mkdir(bin)

    system.write_file(system.join_path(bin, "vsdevcmd.cmd"), cmd([[@echo off
call "%~dp0..\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64 %*
]]))

    system.write_file(system.join_path(bin, "vcvars64.cmd"), cmd([[@echo off
call "%~dp0..\VC\Auxiliary\Build\vcvars64.bat" %*
]]))

    system.write_file(system.join_path(bin, "vsbuild-run.cmd"), cmd([[@echo off
call "%~dp0..\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 exit /b %errorlevel%
%*
exit /b %errorlevel%
]]))

    system.write_file(system.join_path(bin, "vsbuild-shell.cmd"), cmd([[@echo off
cmd /k ""%~dp0..\VC\Auxiliary\Build\vcvars64.bat""
]]))

    system.write_file(system.join_path(bin, "vsbuild-cl.cmd"), cmd([[@echo off
call "%~dp0..\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 exit /b %errorlevel%
cl.exe %*
exit /b %errorlevel%
]]))

    system.write_file(system.join_path(bin, "vsbuild-cmake.cmd"), cmd([[@echo off
call "%~dp0..\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 exit /b %errorlevel%
cmake.exe %*
exit /b %errorlevel%
]]))

    system.write_file(system.join_path(bin, "vsbuild-info.cmd"), cmd(string.format([[@echo off
echo VSBUILD_HOME=%%~dp0..
echo VSBUILD_VERSION=%s
if exist "%%~dp0..\VC\Auxiliary\Build\vcvars64.bat" echo vcvars64=present
if exist "%%~dp0..\Common7\Tools\VsDevCmd.bat" echo VsDevCmd=present
call "%%~dp0..\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 exit /b %%errorlevel%%
where cl
cl
]], version)))

    system.write_file(system.join_path(bin, "vsbuild-update.cmd"), cmd([[@echo off
setlocal
set "INSTALL_PATH=%~dp0.."
set "VS_INSTALLER=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vs_installer.exe"
if not exist "%VS_INSTALLER%" (
  echo vs_installer.exe was not found.
  exit /b 1
)
"%VS_INSTALLER%" update --installPath "%INSTALL_PATH%" --quiet --norestart
set "CODE=%ERRORLEVEL%"
if "%CODE%"=="3010" exit /b 0
exit /b %CODE%
]]))

    system.write_file(system.join_path(bin, "vsbuild-uninstall.cmd"), cmd([[@echo off
setlocal
set "INSTALL_PATH=%~dp0.."
set "VS_INSTALLER=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vs_installer.exe"
if not exist "%VS_INSTALLER%" (
  echo vs_installer.exe was not found.
  exit /b 1
)
"%VS_INSTALLER%" uninstall --installPath "%INSTALL_PATH%" --quiet --norestart
set "CODE=%ERRORLEVEL%"
if "%CODE%"=="3010" set "CODE=0"
if "%CODE%"=="0" (
  echo Visual Studio Build Tools uninstall complete.
  echo You may now run: mise uninstall vsbuild
)
exit /b %CODE%
]]))

    system.write_file(system.join_path(bin, "vsbuild-list.cmd"), cmd([[@echo off
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
)
echo.
]]))
end

return M
