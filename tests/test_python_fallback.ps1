$ErrorActionPreference = 'Stop'

$raizProjeto = Split-Path -Parent $PSScriptRoot
$iniciador = Join-Path $raizProjeto 'INICIAR_TUDO.bat'
$pythonReal = (Get-Command python -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$pyReal = (Get-Command py -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$pythonFalso = Join-Path $PSScriptRoot 'fixtures\fake_python.cmd'
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
$pastaTeste = Join-Path $raizProjeto ('.test-tmp\python-fallback-{0}' -f [guid]::NewGuid().ToString('N'))
$pastaTesteCompleta = [System.IO.Path]::GetFullPath($pastaTeste)
$raizCompleta = [System.IO.Path]::GetFullPath($raizProjeto).TrimEnd('\') + '\'
if (-not $pastaTesteCompleta.StartsWith($raizCompleta, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Pasta temporária fora do projeto: $pastaTesteCompleta"
}
New-Item -ItemType Directory -Path $pastaTesteCompleta -Force | Out-Null

function Invocar-CenarioPython {
    param(
        [string]$Nome,
        [string]$PastaAmbiente,
        [string]$PythonSistema = '',
        [string]$PySistema = '',
        [string]$Cenario = '',
        [switch]$PularDependencias,
        [switch]$FalharDependencias,
        [switch]$FluxoCompleto
    )
    $cenarioAnterior = $env:UBS_PYTHON_TEST_SCENARIO
    $portaBackendAnterior = $env:UBS_LAUNCHER_TEST_BACKEND_PORT
    $portaFrontendAnterior = $env:UBS_LAUNCHER_TEST_FRONTEND_PORT
    $env:UBS_PYTHON_TEST_SCENARIO = $Cenario
    $env:UBS_LAUNCHER_TEST_BACKEND_PORT = "$portaBackendTeste"
    $env:UBS_LAUNCHER_TEST_FRONTEND_PORT = "$portaFrontendTeste"
    $argumentos = @(
        '-ModoTestePythonInterno',
        '-PastaAmbienteTesteInterno', $PastaAmbiente,
        '-SemPausa'
    )
    if (-not $FluxoCompleto) {
        $argumentos += '-SomentePrepararPythonTesteInterno'
    } else {
        $argumentos += @(
            '-ModoTesteInterno', '-Dispositivo', 'chrome',
            '-FlutterTesteInterno', $flutterFalso,
            '-BackendTesteInterno', $backendFalso,
            '-PortaBackendTesteInterno', "$portaBackendTeste",
            '-PortaFrontendTesteInterno', "$portaFrontendTeste",
            '-TimeoutInicializacaoSegundos', '5',
            '-TimeoutBackendSegundos', '5',
            '-EstabilidadeFrontendSegundos', '1',
            '-EncerrarAposValidacaoInterna'
        )
    }
    if ($PythonSistema) { $argumentos += @('-PythonSistemaTesteInterno', $PythonSistema) }
    if ($PySistema) { $argumentos += @('-PySistemaTesteInterno', $PySistema) }
    if ($PularDependencias) { $argumentos += '-PularDependenciasPythonTesteInterno' }
    if ($FalharDependencias) { $argumentos += '-SimularFalhaInstalacaoTesteInterno' }
    $preferenciaAnterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $saida = & $iniciador @argumentos 2>&1 | Out-String
        return [pscustomobject]@{
            Nome = $Nome
            Codigo = $LASTEXITCODE
            Saida = $saida
        }
    } finally {
        $ErrorActionPreference = $preferenciaAnterior
        $env:UBS_PYTHON_TEST_SCENARIO = $cenarioAnterior
        $env:UBS_LAUNCHER_TEST_BACKEND_PORT = $portaBackendAnterior
        $env:UBS_LAUNCHER_TEST_FRONTEND_PORT = $portaFrontendAnterior
    }
}

function Exigir-Sucesso {
    param($Resultado, [string[]]$Padroes)
    if ($Resultado.Codigo -ne 0) {
        throw "$($Resultado.Nome) falhou com código $($Resultado.Codigo).`n$($Resultado.Saida)"
    }
    foreach ($padrao in $Padroes) {
        if ($Resultado.Saida -notmatch $padrao) {
            throw "$($Resultado.Nome) não exibiu '$padrao'.`n$($Resultado.Saida)"
        }
    }
}

function Exigir-Falha {
    param($Resultado, [string]$Padrao)
    if ($Resultado.Codigo -eq 0) {
        throw "$($Resultado.Nome) deveria falhar.`n$($Resultado.Saida)"
    }
    if ($Resultado.Saida -match 'Sistema iniciado com sucesso') {
        throw "$($Resultado.Nome) exibiu falso sucesso.`n$($Resultado.Saida)"
    }
    if ($Resultado.Saida -notmatch $Padrao) {
        throw "$($Resultado.Nome) não exibiu '$Padrao'.`n$($Resultado.Saida)"
    }
}

try {
    $ambientePython = Join-Path $pastaTesteCompleta 'com-python'
    $pythonFuncionando = Invocar-CenarioPython -Nome 'python funcionando' `
        -PastaAmbiente $ambientePython -PythonSistema $pythonReal `
        -PularDependencias
    Exigir-Sucesso $pythonFuncionando @(
        'Python encontrado pelo comando: python',
        'Ambiente virtual criado e validado'
    )
    if (-not (Test-Path -LiteralPath (Join-Path $ambientePython 'Scripts\python.exe'))) {
        throw 'O cenário com python não criou o executável interno.'
    }

    $ambienteExistente = Invocar-CenarioPython -Nome 'ambiente existente' `
        -PastaAmbiente $ambientePython -PularDependencias
    Exigir-Sucesso $ambienteExistente @(
        'Ambiente virtual encontrado e validado'
    )
    if ($ambienteExistente.Saida -match 'Criando o ambiente virtual') {
        throw 'O ambiente virtual válido foi recriado indevidamente.'
    }

    $ambientePy = Join-Path $pastaTesteCompleta 'somente-py'
    $fallbackPy = Invocar-CenarioPython -Nome 'fallback py -3' `
        -PastaAmbiente $ambientePy -PySistema $pyReal -PularDependencias
    Exigir-Sucesso $fallbackPy @(
        'comando python',
        'Python encontrado pelo comando: py -3',
        'Ambiente virtual criado e validado'
    )

    $ambientePyCompleto = Join-Path $pastaTesteCompleta 'somente-py-completo'
    $fallbackCompleto = Invocar-CenarioPython -Nome 'fallback py -3 completo' `
        -PastaAmbiente $ambientePyCompleto -PySistema $pyReal `
        -PularDependencias -FluxoCompleto
    Exigir-Sucesso $fallbackCompleto @(
        'Python encontrado pelo comando: py -3',
        'Backend iniciado e respondendo',
        'Frontend Flutter dispon',
        'Sistema iniciado com sucesso'
    )

    $ambienteAlias = Join-Path $pastaTesteCompleta 'alias-invalido'
    $aliasInvalido = Invocar-CenarioPython -Nome 'alias inválido' `
        -PastaAmbiente $ambienteAlias -PythonSistema $pythonFalso `
        -PySistema $pyReal -Cenario 'invalid-alias' -PularDependencias
    Exigir-Sucesso $aliasInvalido @(
        'comando python',
        'Python encontrado pelo comando: py -3'
    )

    $ambienteCorrompido = Join-Path $pastaTesteCompleta 'corrompido'
    New-Item -ItemType Directory -Path (Join-Path $ambienteCorrompido 'Scripts') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $ambienteCorrompido 'Scripts\python.exe') `
        -Value 'executável inválido para teste' -Encoding ASCII
    $reparado = Invocar-CenarioPython -Nome 'ambiente corrompido' `
        -PastaAmbiente $ambienteCorrompido -PythonSistema $pythonReal `
        -PularDependencias
    Exigir-Sucesso $reparado @(
        'ambiente virtual existente',
        'Ambiente virtual criado e validado'
    )
    if (Get-ChildItem -LiteralPath $pastaTesteCompleta -Directory -Filter 'venv_corrompido_*') {
        throw 'A recuperação deixou uma cópia temporária do ambiente corrompido.'
    }

    $inexistente = Join-Path $pastaTesteCompleta 'nao-existe.exe'
    $nenhum = Invocar-CenarioPython -Nome 'nenhum Python' `
        -PastaAmbiente (Join-Path $pastaTesteCompleta 'sem-python')
    Exigir-Falha $nenhum 'Python 3 foi encontrada'

    $criacaoFalha = Invocar-CenarioPython -Nome 'falha na criação' `
        -PastaAmbiente (Join-Path $pastaTesteCompleta 'criacao-falha') `
        -PythonSistema $pythonFalso -Cenario 'create-failure'
    Exigir-Falha $criacaoFalha 'ambiente virtual falhou usando python'

    $dependenciasFalham = Invocar-CenarioPython -Nome 'falha nas dependências' `
        -PastaAmbiente $ambientePython -FalharDependencias
    Exigir-Falha $dependenciasFalham 'backend falhou'

    Write-Host 'PASS: seleção python -> py -3, ambiente virtual e falhas foram validados.' -ForegroundColor Green
} finally {
    if (Test-Path -LiteralPath $pastaTesteCompleta) {
        Remove-Item -LiteralPath $pastaTesteCompleta -Recurse -Force
    }
}
