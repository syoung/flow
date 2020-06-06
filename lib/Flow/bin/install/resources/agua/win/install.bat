@echo off

set apps=ActivePerl-5.18.4.1805-MSWin32-x86-64int-299195.msi mysql-installer-web-community-5.6.27.0.msi node-v4.2.1-x86.msi otp_win64_18.1.exe rabbitmq-server-3.5.6.exe

(
for %%a in (%apps%) do (
    call :installApp %%a
)
)

:installApp
    echo %1
    start /wait msiexec /q /package %1 /l*v %1.log
    if errorlevel 1 (
       echo Failure Reason Given is %errorlevel%
       exit /b %errorlevel%
    )
