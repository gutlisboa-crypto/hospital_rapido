@echo off
setlocal

if "%~1"=="--version" (
    if /I "%UBS_PYTHON_TEST_SCENARIO%"=="invalid-alias" (
        echo Python was not found; run without arguments to install from the Microsoft Store. 1>&2
        exit /b 49
    )
    echo Python 3.11.9
    exit /b 0
)

if "%~1"=="-m" if "%~2"=="venv" (
    echo falha simulada ao criar o ambiente virtual 1>&2
    exit /b 55
)

echo operacao Python simulada nao suportada 1>&2
exit /b 56
