@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

REM Ensure that AK, SK, and Task ID are provided
IF "%~3"=="" (
    echo [WARN]  Usage: %0 ^<app_key^> ^<app_secret^> ^<task_id^>
    exit /b 1
)

set "app_key=%~1"
set "app_secret=%~2"
set "task_id=%~3"
set "force_download=%~4"
set "resign=%~5"

set "skip_get_url=0"

set "file_name=download-cache-%task_id%.txt"
IF EXIST %file_name% (
    FOR /F "delims=" %%G IN ('findstr /R /C:"http" "%file_name%"') DO (
    set "length=1"
    )
    IF !length! GTR 0 (
        echo [INFO]  Skip get url as the cache file exists
        set "skip_get_url=1"
    )
)

IF %force_download% EQU 1 (
    echo [INFO]  Force download initiated
    set "skip_get_url=0"
    )

IF !skip_get_url!==0 (
    echo [INFO]  Get the download URLs
    
    REM Get the access token
    FOR /F "delims=" %%G IN ('curl -s -X POST "https://app-gateway.realsee.cn/auth/access_token" -H "accept: application/json" -H "content-type: application/x-www-form-urlencoded" -d "app_key=^%app_key^%&app_secret=^%app_secret^%"') DO (
    set "response=%%G"
    )
    FOR /F "delims=" %%G IN ('echo !response! ^| findstr /R /C:"^"access_token^":.*," ^| findstr /R /C:"^:[^,]*" ^| findstr /R /C:"^[^:,]*"') DO (
    set "access_token=%%~G"
    )
    IF "!access_token!"=="" (
        echo [ERROR]  Failed to get access token
        exit /b 1
    )
    
    REM Get the task details
    FOR /F "delims=" %%G IN ('curl -s -X GET "https://app-gateway.realsee.cn/open/v3/shepherd/task/detail?task_id=^%task_id^%" -H "accept: application/json" -H "authorization: ^%access_token^%"') DO (
    set "detail=%%G"
    )
    
    REM Extract download URLs
    FOR /F "delims=" %%G IN ('echo !detail! ^| findstr /R /C:"^"^"url^":^"^"[^^"^"]*" ^| findstr /R /C:"[^$^"]*$"') DO (
    set "urls=%%G"
    )
    IF "!urls!"=="" (
        echo [ERROR]  Failed to get download URLs
        exit /b 1
    )

    REM Additional steps for resign
    REM Not Supported in Batch Script
    
    REM Clear the cache file
    echo [INFO]  Remove the cache file
    del /f %file_name%
    
    IF "!urls!"=="" (
        echo [ERROR]  The download URLs are empty
        exit /b 1
    )
    
    FOR %%G IN (!urls!) DO (
        echo %%G >> %file_name%
    )
) ELSE (
    FOR /F "delims=" %%G IN ('findstr /R /C:"http" "%file_name%"') DO (
    set "urls=%%G"
    )
)

IF NOT EXIST download (
 md download
)

REM Download files
FOR %%G IN (!urls!) DO (
    REM Extract filename from URL
    FOR /F "delims=" %%H IN ('echo %%G ^| findstr /R /C:"[^/]^.zip"') DO (
    set "filename=%%H"
    )
    echo [INFO]  File name is !filename!
    IF EXIST !filename! (
        echo [WARN]  Skip download as the file exists
        continue
    )
    
    set "target=./download/!filename!"
    
    IF EXIST "!target!.tmp" (
        echo [WARN]  Delete the tmp file first
        del /f "!target!.tmp"
    )
    
    echo [INFO]  Downloading !filename! to !target!.tmp
    curl -s -o "!target!.tmp" %%G
    
    echo [INFO]  Downloaded
