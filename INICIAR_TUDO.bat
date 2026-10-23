@echo off
setlocal
set "SEM_PAUSA="
for %%A in (%*) do if /I "%%~A"=="-SemPausa" set "SEM_PAUSA=1"
chcp 65001 >nul
title UBS Rapida - Iniciador oficial
cd /d "%~dp0"

echo =====================================================
echo              UBS RAPIDA - INICIAR TUDO
echo =====================================================
echo.
echo Iniciador oficial do sistema.
echo Projeto: %CD%
echo Backend: http://127.0.0.1:8000/docs
echo Frontend: Flutter para Windows, Chrome ou Edge
echo Modos: padrao Windows ^| -Dispositivo chrome ^| -Dispositivo edge
echo.
echo O banco SQLite e os dados existentes serao preservados.
echo Segredos de configuracao nao serao exibidos.
echo O duplo clique atualiza dependencias e recompila o aplicativo antes de abrir.
echo Em uso avancado, passe -AtualizarTudo para obter o mesmo comportamento.
echo O primeiro inicio pode demorar durante a preparacao inicial.
echo.

if not exist "%~dp0scripts\iniciar.ps1" (
    echo [ERRO] O script interno de inicializacao nao foi encontrado.
    echo Esperado em: %~dp0scripts\iniciar.ps1
    if not defined SEM_PAUSA pause
    exit /b 2
)

if "%~1"=="" (
    echo [MODO] Atualizacao completa automatica.
    echo [AGUARDE] Verificando dependencias e preparando a versao mais recente...
    echo.
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\iniciar.ps1" -AtualizarTudo
) else (
    echo [MODO] Opcoes informadas: %*
    echo.
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\iniciar.ps1" %*
)
set "CODIGO_SAIDA=%ERRORLEVEL%"

if not "%CODIGO_SAIDA%"=="0" (
    echo.
    echo [ERRO] Nao foi possivel iniciar o UBS Rapida.
    echo Consulte a mensagem apresentada acima e tente novamente.
    if not defined SEM_PAUSA pause
    exit /b %CODIGO_SAIDA%
)

echo.
echo [OK] Inicializacao concluida pelo botao INICIAR_TUDO.
exit /b 0
