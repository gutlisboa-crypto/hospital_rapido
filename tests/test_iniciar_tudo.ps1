$ErrorActionPreference = 'Stop'

$raizProjeto = Split-Path -Parent $PSScriptRoot
$iniciador = Join-Path $raizProjeto 'INICIAR_TUDO.bat'
$scriptIniciador = Join-Path $raizProjeto 'scripts\iniciar.ps1'
$flutterFalso = Join-Path $PSScriptRoot 'fixtures\fake_flutter.ps1'
$backendFalso = Join-Path $PSScriptRoot 'fixtures\fake_backend.ps1'

function Obter-PortaLivre {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    try { return ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port } finally { $listener.Stop() }
}

$portaBackendTeste = Obter-PortaLivre
$portaFrontendTeste = Obter-PortaLivre
while ($portaFrontendTeste -eq $portaBackendTeste) { $portaFrontendTeste = Obter-PortaLivre }

function Invocar-Iniciador {
    param([string]$Cenario = '', [string[]]$Argumentos = @())
    $cenarioAnterior = $env:UBS_LAUNCHER_TEST_SCENARIO
    $portaBackendAnterior = $env:UBS_LAUNCHER_TEST_BACKEND_PORT
    $portaFrontendAnterior = $env:UBS_LAUNCHER_TEST_FRONTEND_PORT
    $env:UBS_LAUNCHER_TEST_SCENARIO = $Cenario
    $env:UBS_LAUNCHER_TEST_BACKEND_PORT = "$portaBackendTeste"
    $env:UBS_LAUNCHER_TEST_FRONTEND_PORT = "$portaFrontendTeste"
    $preferenciaAnterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $saida = & $iniciador @Argumentos 2>&1 | Out-String
        $codigo = $LASTEXITCODE
        return [pscustomobject]@{ Codigo = $codigo; Saida = $saida }
    } finally {
        $ErrorActionPreference = $preferenciaAnterior
        $env:UBS_LAUNCHER_TEST_SCENARIO = $cenarioAnterior
        $env:UBS_LAUNCHER_TEST_BACKEND_PORT = $portaBackendAnterior
        $env:UBS_LAUNCHER_TEST_FRONTEND_PORT = $portaFrontendAnterior
    }
}

function Verificar-FalhaControlada {
    param(
        [string]$Nome,
        [string]$Cenario,
        [string]$MensagemEsperada,
        [int]$TimeoutSegundos = 5
    )
    $resultado = Invocar-Iniciador -Cenario $Cenario -Argumentos @(
        '-Dispositivo', 'chrome', '-ModoTesteInterno',
        '-FlutterTesteInterno', $flutterFalso,
        '-BackendTesteInterno', $backendFalso,
        '-PortaBackendTesteInterno', "$portaBackendTeste",
        '-PortaFrontendTesteInterno', "$portaFrontendTeste",
        '-TimeoutInicializacaoSegundos', "$TimeoutSegundos",
        '-EstabilidadeFrontendSegundos', '1', '-SemPausa'
    )
    if ($resultado.Codigo -eq 0) {
        throw "$Nome deveria falhar, mas retornou sucesso.`n$($resultado.Saida)"
    }
    if ($resultado.Saida -match 'Sistema iniciado com sucesso') {
        throw "$Nome exibiu falso positivo de inicialização.`n$($resultado.Saida)"
    }
    if ($resultado.Saida -notmatch $MensagemEsperada) {
        throw "$Nome não exibiu o diagnóstico esperado ($MensagemEsperada).`n$($resultado.Saida)"
    }
    if ($resultado.Saida -notmatch 'Logs desta inicializa') {
        throw "$Nome não informou/exibiu os logs da inicialização.`n$($resultado.Saida)"
    }
    Start-Sleep -Milliseconds 300
    foreach ($porta in $portaBackendTeste, $portaFrontendTeste) {
        if (Get-NetTCPConnection -LocalPort $porta -State Listen -ErrorAction SilentlyContinue) {
            throw "$Nome deixou um processo de teste criado pelo launcher ouvindo na porta $porta."
        }
    }
}

$primeira = Invocar-Iniciador -Argumentos @('-Validar', '-SemPausa')
if ($primeira.Codigo -ne 0) { throw "A validação oficial falhou.`n$($primeira.Saida)" }
if ($primeira.Saida -match 'Atualizando as depend.ncias do backend') {
    throw "O iniciador padrão não deve atualizar dependências em toda abertura.`n$($primeira.Saida)"
}
$segunda = Invocar-Iniciador -Argumentos @('-Validar', '-SemPausa')
if ($segunda.Codigo -ne 0) { throw "A segunda validação oficial falhou.`n$($segunda.Saida)" }
if ($segunda.Saida -match 'Sincronizando as depend.ncias do backend') {
    throw "O iniciador não deve reinstalar dependências que já estão sincronizadas.`n$($segunda.Saida)"
}

$atualizacaoCompleta = Invocar-Iniciador -Argumentos @('-AtualizarTudo', '-Validar', '-SemPausa')
if ($atualizacaoCompleta.Codigo -ne 0) {
    throw "A validação com atualização completa falhou.`n$($atualizacaoCompleta.Saida)"
}
if ($atualizacaoCompleta.Saida -notmatch 'Sincronizando as depend') {
    throw "A atualização completa não sincronizou as dependências do backend.`n$($atualizacaoCompleta.Saida)"
}
if ($atualizacaoCompleta.Saida -match '(?s)Requirement already satisfied:.*reconhecido') {
    throw "A saída do pip foi confundida com o caminho do Python.`n$($atualizacaoCompleta.Saida)"
}

$normal = Invocar-Iniciador -Argumentos @(
    '-Dispositivo', 'chrome', '-ModoTesteInterno',
    '-FlutterTesteInterno', $flutterFalso,
    '-BackendTesteInterno', $backendFalso,
    '-PortaBackendTesteInterno', "$portaBackendTeste",
    '-PortaFrontendTesteInterno', "$portaFrontendTeste",
    '-TimeoutInicializacaoSegundos', '5',
    '-EstabilidadeFrontendSegundos', '1',
    '-EncerrarAposValidacaoInterna', '-SemPausa'
)
if ($normal.Codigo -ne 0 -or $normal.Saida -notmatch 'Sistema iniciado com sucesso') {
    throw "O fluxo normal pelo INICIAR_TUDO.bat falhou.`n$($normal.Saida)"
}

Verificar-FalhaControlada -Nome 'Falha no flutter pub get' -Cenario 'pub-get-failure' -MensagemEsperada 'flutter pub get falhou'
Verificar-FalhaControlada -Nome 'Comando/dispositivo Flutter inválido' -Cenario 'invalid-command' -MensagemEsperada 'encerrado durante a inicializa'
Verificar-FalhaControlada -Nome 'Encerramento precoce do frontend' -Cenario 'early-exit' -MensagemEsperada 'encerrado durante a inicializa'
Verificar-FalhaControlada -Nome 'Timeout do frontend' -Cenario 'timeout' -MensagemEsperada 'Tempo limite de 2 segundos' -TimeoutSegundos 2
Verificar-FalhaControlada -Nome 'Falha do backend' -Cenario 'backend-failure' -MensagemEsperada 'backend FastAPI foi encerrado'

$dispositivoInvalido = Invocar-Iniciador -Argumentos @('-Dispositivo', 'inexistente', '-SemPausa')
if ($dispositivoInvalido.Codigo -eq 0 -or $dispositivoInvalido.Saida -match 'iniciado com sucesso') {
    throw "Um dispositivo inválido não foi rejeitado corretamente.`n$($dispositivoInvalido.Saida)"
}

$conteudoBatch = Get-Content -Raw $iniciador
foreach ($trecho in @(
    'if "%~1"==""',
    'scripts\iniciar.ps1" -AtualizarTudo',
    'passe -AtualizarTudo para obter o mesmo comportamento',
    'Atualizacao completa automatica',
    'if not exist "%~dp0scripts\iniciar.ps1"',
    'Inicializacao concluida pelo botao INICIAR_TUDO'
)) {
    if ($conteudoBatch -notmatch [regex]::Escape($trecho)) {
        throw "O botão não garante a atualização completa no duplo clique: $trecho"
    }
}

$conteudoPowerShell = Get-Content -Raw $scriptIniciador
$conteudoSeed = Get-Content -Raw (Join-Path $raizProjeto 'backend\app\core\demo_accounts.py')
$contasSeed = [regex]::Matches(
    $conteudoSeed,
    'DemoAccount\(\s*"(?<perfil>[^"]+)",\s*"[^"]+",\s*"(?<cpf>\d{11})",\s*"(?<senha>[^"]+)"'
)
$credenciaisOficiais = foreach ($perfil in @('admin', 'recepcao', 'enfermagem', 'medico', 'paciente')) {
    $conta = $contasSeed | Where-Object { $_.Groups['perfil'].Value -eq $perfil } | Select-Object -First 1
    if (-not $conta) {
        throw "Não foi possível consultar a conta fictícia oficial do perfil $perfil."
    }
    'CPF: {0}  Senha: {1}' -f $conta.Groups['cpf'].Value, $conta.Groups['senha'].Value
}
$trechosEsperados = @($credenciaisOficiais) + @(
    '.ubs_build_stamp', 'Testar-AplicativoAtualizado',
    '.ubs_requirements_stamp', 'Testar-DependenciasBackendAtualizadas',
    'RedirectStandardOutput', 'RedirectStandardError', 'Esperar-ProcessoECondicao'
)
foreach ($trecho in $trechosEsperados) {
    if ($conteudoPowerShell -notmatch [regex]::Escape($trecho)) {
        throw "O iniciador não contém o comportamento esperado: $trecho"
    }
}

Write-Host 'PASS: o launcher só anuncia sucesso após backend e frontend ficarem prontos.' -ForegroundColor Green
