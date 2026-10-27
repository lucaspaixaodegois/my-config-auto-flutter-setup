Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ==========================================
# Auto-elevate (abre como Administrador se necessário)
# ==========================================
function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Host "PowerShell não está como Administrador. Reabrindo como Admin..." -ForegroundColor Yellow

    $psExe = (Get-Process -Id $PID).Path
    if (-not $psExe) { $psExe = "powershell.exe" } # fallback

    $scriptPath = $PSCommandPath
    if (-not $scriptPath) {
        throw "Não consegui detectar o caminho do script (PSCommandPath vazio). Execute via arquivo .ps1."
    }

    $argsList = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$scriptPath`""
    )

    # Reabre elevado e encerra a sessão atual
    Start-Process -FilePath $psExe -Verb RunAs -ArgumentList ($argsList -join " ")
    exit
}

Write-Host "Executando como Administrador ✅" -ForegroundColor Green
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ============================================================
# Setup Dev Windows (Flutter/Dart/FVM/Java/Android SDK) + CHOCO
# - Pergunta unidade (C:, D:, etc.)
# - Modo: DRY-RUN (só verificar) OU instalar automaticamente
# - Layout: X:\flutter OU X:\tools\flutter
# - Usa Chocolatey como gerenciador de pacotes (git, java, fvm, androidstudio, etc.)
# - Android SDK (cmdline-tools/platform-tools) instalado no drive escolhido
# - Final: flutter doctor -v + “corrigir o que der” automaticamente
# ============================================================

function Write-Info($msg) { Write-Host $msg -ForegroundColor Cyan }
function Write-Ok($msg) { Write-Host $msg -ForegroundColor Green }
function Write-Warn($msg) { Write-Host $msg -ForegroundColor Yellow }
function Write-Err($msg) { Write-Host $msg -ForegroundColor Red }

function Ensure-Dir([string]$Path) {
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

function Command-Exists([string]$cmd) {
    [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
}

function Get-MachineEnv([string]$name) {
    [Environment]::GetEnvironmentVariable($name, [EnvironmentVariableTarget]::Machine)
}

function Set-MachineEnv([string]$name, [string]$value, [bool]$DryRun) {
    if ($DryRun) { Write-Info "[DRY-RUN] Set env Machine: $name = $value"; return }
    [Environment]::SetEnvironmentVariable($name, $value, [EnvironmentVariableTarget]::Machine)
    Write-Ok "Env (Machine) definido: $name = $value"
}

function Add-ToMachinePath([string]$toAdd, [bool]$DryRun) {
    if ([string]::IsNullOrWhiteSpace($toAdd)) { return }

    $current = Get-MachineEnv "Path"
    if (-not $current) { $current = "" }

    $parts = $current.Split(';') |
    Where-Object { $_ -and $_.Trim() -ne "" } |
    ForEach-Object { $_.Trim() }

    if ($parts -contains $toAdd) {
        Write-Ok "PATH já contém: $toAdd"
        return
    }

    if ($DryRun) { Write-Info "[DRY-RUN] Add PATH (Machine): $toAdd"; return }

    $new = ($parts + $toAdd) -join ';'
    [Environment]::SetEnvironmentVariable("Path", $new, [EnvironmentVariableTarget]::Machine)
    Write-Ok "Adicionado ao PATH (Machine): $toAdd"
}

function Download-File([string]$Url, [string]$OutFile, [bool]$DryRun) {
    if ($DryRun) { Write-Info "[DRY-RUN] Download: $Url -> $OutFile"; return }
    Write-Info "Baixando: $Url"
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
}

function Expand-Zip([string]$ZipPath, [string]$Destination, [bool]$DryRun) {
    if ($DryRun) { Write-Info "[DRY-RUN] Expand: $ZipPath -> $Destination"; return }
    Ensure-Dir $Destination
    Expand-Archive -Path $ZipPath -DestinationPath $Destination -Force
}

function Ask-Choice([string]$Title, [string[]]$Options) {
    Write-Host ""
    Write-Info $Title
    for ($i = 0; $i -lt $Options.Length; $i++) {
        Write-Host ("  {0}) {1}" -f ($i + 1), $Options[$i])
    }
    $ans = Read-Host "Escolha (1-$($Options.Length))"
    if (-not ($ans -match "^\d+$")) { throw "Entrada inválida." }
    $n = [int]$ans
    if ($n -lt 1 -or $n -gt $Options.Length) { throw "Escolha inválida." }
    return $n
}

function Ensure-Chocolatey([bool]$DryRun) {
    Write-Info "`n== Chocolatey =="
    if (Command-Exists "choco") {
        Write-Ok "Chocolatey já está instalado."
        return
    }

    Write-Warn "Chocolatey não encontrado."
    if ($DryRun) {
        Write-Info "[DRY-RUN] Instalaria Chocolatey via script oficial."
        return
    }

    # Instalação padrão (FOSS) via script oficial
    # Observação: requer internet e TLS 1.2+
    try {
        Write-Info "Instalando Chocolatey..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Set-ExecutionPolicy Bypass -Scope Process -Force
        $install = (New-Object System.Net.WebClient).DownloadString("https://chocolatey.org/install.ps1")
        Invoke-Expression $install

        if (-not (Command-Exists "choco")) {
            throw "Chocolatey não apareceu no PATH após instalação."
        }
        Write-Ok "Chocolatey instalado com sucesso."
    }
    catch {
        throw "Falha ao instalar Chocolatey: $($_.Exception.Message)"
    }
}

function Choco-Install([string]$PackageName, [bool]$DryRun, [string]$Params = "") {
    if (-not (Command-Exists "choco")) {
        throw "choco não encontrado. Execute Ensure-Chocolatey primeiro."
    }

    if ($DryRun) {
        Write-Info "[DRY-RUN] choco install $PackageName -y $Params"
        return
    }

    Write-Info "Instalando via choco: $PackageName"
    $args = @("install", $PackageName, "-y", "--no-progress")
    if ($Params -and $Params.Trim() -ne "") {
        # Params deve vir completo (ex: '--params="..."' ou '--version=...'), então vamos splittar com cuidado
        # Regra simples: passa como string única
        $args += $Params
    }
    & choco @args | Out-Host
}

function Choco-Upgrade([string]$PackageName, [bool]$DryRun) {
    if (-not (Command-Exists "choco")) { return }
    if ($DryRun) {
        Write-Info "[DRY-RUN] choco upgrade $PackageName -y"
        return
    }
    Write-Info "Atualizando via choco: $PackageName"
    & choco upgrade $PackageName -y --no-progress | Out-Host
}

function Find-JavaHomeFromMachine() {
    $jh = Get-MachineEnv "JAVA_HOME"
    if ($jh -and (Test-Path $jh)) { return $jh }

    # fallback: tenta localizar java.exe e subir pastas
    $javaCmd = Get-Command java -ErrorAction SilentlyContinue
    if ($javaCmd -and (Test-Path $javaCmd.Path)) {
        $bin = Split-Path $javaCmd.Path -Parent
        $home = Split-Path $bin -Parent
        if (Test-Path $home) { return $home }
    }
    return $null
}

# ------------------------------------------------------------
# 1) Unidade
# ------------------------------------------------------------
$drive = Read-Host "Qual unidade deseja verificar/instalar? (ex: C:, D:, E:)"
$drive = $drive.Trim().TrimEnd('\')
if ($drive.Length -eq 1) { $drive = "$drive:" }
if ($drive -notmatch "^[A-Za-z]:$") { throw "Unidade inválida. Use C: ou D: (sem barras)." }
if (-not (Test-Path "$drive\")) { throw "A unidade $drive não existe neste computador." }
Write-Ok "Unidade selecionada: $drive"

# ------------------------------------------------------------
# 2) Modo
# ------------------------------------------------------------
$mode = Ask-Choice "Selecione o modo:" @(
    "Só verificar (DRY-RUN) — não instala nem altera variáveis",
    "Verificar e INSTALAR automaticamente (recomendado)"
)
$DryRun = ($mode -eq 1)
if ($DryRun) { Write-Warn "Modo DRY-RUN ativado: nada será instalado/alterado." }

# ------------------------------------------------------------
# 3) Layout dos paths
# ------------------------------------------------------------
$layout = Ask-Choice "Selecione onde o Flutter deve ficar:" @(
    "Padrão RAIZ: X:\flutter",
    "Padrão TOOLS: X:\tools\flutter"
)

# ------------------------------------------------------------
# 4) Android Studio (via choco)
# ------------------------------------------------------------
$installStudio = Ask-Choice "Android Studio (opcional):" @(
    "Não instalar Android Studio",
    "Instalar Android Studio via Chocolatey (recomendado)"
)

# ------------------------------------------------------------
# 5) Pacotes via choco (essenciais)
# ------------------------------------------------------------
$installEssentials = Ask-Choice "Instalar/garantir dependências via Chocolatey:" @(
    "Somente o mínimo (git + Java 21)",
    "Completo (git + Java 21 + fvm + 7zip + androidstudio se escolhido)"
)

# ------------------------------------------------------------
# Paths conforme escolhas (Flutter/Dart/Android em drive escolhido)
# ------------------------------------------------------------
$toolsRoot = Join-Path $drive "\tools"
if ($layout -eq 1) { $flutterPath = Join-Path $drive "\flutter" }
else { $flutterPath = Join-Path $toolsRoot "flutter" }

$dartPath = Join-Path $toolsRoot "dart-sdk"
$androidRoot = Join-Path $drive "\Android\Sdk"

if (-not $DryRun) {
    Ensure-Dir $toolsRoot
    Ensure-Dir $flutterPath
    Ensure-Dir (Split-Path $androidRoot -Parent)
}

Write-Info "`n=== Paths configurados ==="
Write-Host "FLUTTER: $flutterPath"
Write-Host "DART:    $dartPath"
Write-Host "ANDROID: $androidRoot"
Write-Host ""

# ------------------------------------------------------------
# URLs (Flutter/Dart/Android cmdline-tools/platform-tools)
# ------------------------------------------------------------
$flutterZipUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.29.0-stable.zip"
$dartZipUrl = "https://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-windows-x64-release.zip"
$cmdToolsUrl = "https://dl.google.com/android/repository/commandlinetools-win-8512546_latest.zip"
$platToolsUrl = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"

# Android packages desejados (para “corrigir o que der”)
$androidApi = "34"
$androidBuildTools = "34.0.0"
$ndkId = "ndk;21.4.7075529"
$androidPackages = @(
    "platform-tools",
    "platforms;android-$androidApi",
    "build-tools;$androidBuildTools"
)

$temp = Join-Path $env:TEMP "dev-setup"
if (-not $DryRun) { Ensure-Dir $temp }

# ============================================================
# CHOCO: instalar/garantir pacotes
# ============================================================
Ensure-Chocolatey $DryRun

Write-Info "`n== Dependências via Chocolatey =="

# 7zip (ajuda em várias situações)
if ($installEssentials -eq 2) {
    Choco-Install "7zip" $DryRun
}

# Git (Flutter doctor reclama muito)
Choco-Install "git" $DryRun

# Java 21 (Microsoft OpenJDK)
# Observação: pacote "microsoft-openjdk" aponta para a versão mais recente disponível na major (pode mudar com o tempo).
# Se você quiser travar, use "--version=21.x.x".
Choco-Install "microsoft-openjdk" $DryRun

# FVM (opcional via choco)
if ($installEssentials -eq 2) {
    Choco-Install "fvm" $DryRun
}

# Android Studio (opcional via choco)
if ($installStudio -eq 2) {
    Choco-Install "AndroidStudio" $DryRun
}

# ============================================================
# Flutter (manual para respeitar drive escolhido)
# ============================================================
Write-Info "`n== Flutter (no drive escolhido) =="

if (-not (Command-Exists "flutter") -and -not (Test-Path (Join-Path $flutterPath "bin\flutter.bat"))) {
    Write-Warn "Flutter não encontrado."
    if (-not $DryRun) {
        $zip = Join-Path $temp "flutter.zip"
        Download-File $flutterZipUrl $zip $DryRun

        if ($layout -eq 1) {
            Expand-Zip $zip "$drive\" $DryRun
        }
        else {
            Expand-Zip $zip $toolsRoot $DryRun
        }
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
        Write-Ok "Flutter baixado e extraído."
    }
}
else {
    Write-Ok "Flutter já existe (comando ou pasta encontrada)."
}

Set-MachineEnv "FLUTTER_HOME" $flutterPath $DryRun
Add-ToMachinePath (Join-Path $flutterPath "bin") $DryRun

# ============================================================
# Dart SDK (manual para respeitar drive escolhido)
# ============================================================
Write-Info "`n== Dart SDK (no drive escolhido) =="

if (-not (Command-Exists "dart") -and -not (Test-Path (Join-Path $dartPath "bin\dart.exe"))) {
    Write-Warn "Dart não encontrado."
    if (-not $DryRun) {
        $zip = Join-Path $temp "dart.zip"
        Download-File $dartZipUrl $zip $DryRun
        Expand-Zip $zip $toolsRoot $DryRun
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
        Write-Ok "Dart SDK baixado e extraído."
    }
}
else {
    Write-Ok "Dart já existe (comando ou pasta encontrada)."
}

Set-MachineEnv "DART_HOME" $dartPath $DryRun
Add-ToMachinePath (Join-Path $dartPath "bin") $DryRun

# ============================================================
# Android SDK (cmdline-tools + platform-tools no drive escolhido)
# ============================================================
Write-Info "`n== Android SDK (no drive escolhido) =="

$cmdToolsLatest = Join-Path $androidRoot "cmdline-tools\latest\bin\sdkmanager.bat"
$platformTools = Join-Path $androidRoot "platform-tools\adb.exe"

if (-not $DryRun) { Ensure-Dir $androidRoot }

# cmdline-tools
if (-not (Test-Path $cmdToolsLatest)) {
    Write-Warn "cmdline-tools não encontrado."
    if (-not $DryRun) {
        $zip = Join-Path $temp "cmdline-tools.zip"
        Download-File $cmdToolsUrl $zip $DryRun

        $tmpExtract = Join-Path $temp "cmdline-tools-extract"
        if (Test-Path $tmpExtract) { Remove-Item $tmpExtract -Recurse -Force }
        Ensure-Dir $tmpExtract

        Expand-Zip $zip $tmpExtract $DryRun
        Remove-Item $zip -Force -ErrorAction SilentlyContinue

        $cmdToolsDir = Join-Path $androidRoot "cmdline-tools"
        Ensure-Dir $cmdToolsDir

        $source = Join-Path $tmpExtract "cmdline-tools"
        $latest = Join-Path $cmdToolsDir "latest"
        if (Test-Path $latest) { Remove-Item $latest -Recurse -Force }

        Move-Item $source $latest -Force
        Remove-Item $tmpExtract -Recurse -Force

        Write-Ok "cmdline-tools instalado."
    }
}
else {
    Write-Ok "cmdline-tools já está instalado."
}

# platform-tools (ADB)
if (-not (Test-Path $platformTools)) {
    Write-Warn "platform-tools (ADB) não encontrado."
    if (-not $DryRun) {
        $zip = Join-Path $temp "platform-tools.zip"
        Download-File $platToolsUrl $zip $DryRun
        Expand-Zip $zip $androidRoot $DryRun
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
        Write-Ok "platform-tools instalado."
    }
}
else {
    Write-Ok "platform-tools já está instalado."
}

# Variáveis Android
Set-MachineEnv "ANDROID_HOME" $androidRoot $DryRun
Set-MachineEnv "ANDROID_SDK_ROOT" $androidRoot $DryRun
Add-ToMachinePath (Join-Path $androidRoot "cmdline-tools\latest\bin") $DryRun
Add-ToMachinePath (Join-Path $androidRoot "platform-tools") $DryRun

# ============================================================
# Java (garantir JAVA_HOME a partir da instalação do choco)
# ============================================================
Write-Info "`n== JAVA_HOME =="

$javaHome = Find-JavaHomeFromMachine
if (-not $javaHome) {
    Write-Warn "JAVA_HOME não detectado automaticamente."
    if ($DryRun) {
        Write-Info "[DRY-RUN] Tentaria inferir JAVA_HOME via 'where java' e setar JAVA_HOME."
    }
    else {
        $javaCmd = Get-Command java -ErrorAction SilentlyContinue
        if ($javaCmd) {
            $bin = Split-Path $javaCmd.Path -Parent
            $home = Split-Path $bin -Parent
            if (Test-Path $home) {
                $javaHome = $home
            }
        }
        if ($javaHome) {
            Set-MachineEnv "JAVA_HOME" $javaHome $DryRun
            Add-ToMachinePath (Join-Path $javaHome "bin") $DryRun
        }
        else {
            Write-Warn "Não foi possível inferir JAVA_HOME. Você pode precisar definir manualmente."
        }
    }
}
else {
    Write-Ok "JAVA_HOME detectado: $javaHome"
    Set-MachineEnv "JAVA_HOME" $javaHome $DryRun
    Add-ToMachinePath (Join-Path $javaHome "bin") $DryRun
}

# ============================================================
# “Corrigir o que der” (Android SDK packages + licenças + NDK)
# ============================================================
Write-Info "`n== Auto-fix (o que der) =="

if (-not $DryRun) {
    if (Test-Path $cmdToolsLatest) {
        try {
            Write-Info "Aceitando licenças do Android SDK (se solicitar)..."
            & $cmdToolsLatest --licenses | Out-Null
            Write-Ok "Licenças processadas."
        }
        catch {
            Write-Warn "Licenças: pode exigir interação manual."
        }

        try {
            Write-Info "Instalando pacotes Android básicos: $($androidPackages -join ', ')"
            & $cmdToolsLatest $androidPackages | Out-Host
            Write-Ok "Pacotes Android básicos instalados/atualizados."
        }
        catch {
            Write-Warn "Falha ao instalar pacotes básicos via sdkmanager."
        }

        # NDK
        try {
            $ndkFolder = Join-Path $androidRoot "ndk"
            if (-not (Test-Path $ndkFolder)) {
                Write-Info "Instalando NDK ($ndkId)..."
                & $cmdToolsLatest $ndkId | Out-Host
                Write-Ok "NDK instalado (ou solicitado)."
            }
            else {
                Write-Ok "NDK já existe em: $ndkFolder"
            }
        }
        catch {
            Write-Warn "Falha ao instalar NDK via sdkmanager."
        }
    }
    else {
        Write-Warn "sdkmanager.bat não encontrado; não dá para auto-fixar Android SDK packages."
    }

    # Garantir git (flutter doctor reclama)
    if (-not (Command-Exists "git")) {
        Write-Warn "git ainda não está no PATH do terminal atual. (Reabra o terminal) — mas já foi instalado via choco."
    }
}
else {
    Write-Info "[DRY-RUN] (pularia) sdkmanager --licenses + instalação de packages/NDK"
}

# ============================================================
# Checagem final: flutter doctor -v
# ============================================================
Write-Info "`n== Checagem final: flutter doctor -v =="

if (Command-Exists "flutter") {
    try {
        & flutter doctor -v | Out-Host
    }
    catch {
        Write-Warn "flutter doctor falhou no terminal atual. Tente reabrir o PowerShell e rodar novamente."
    }
}
else {
    Write-Warn "flutter não está disponível no PATH do terminal atual. Reabra o PowerShell e rode: flutter doctor -v"
}

# ============================================================
# Resumo
# ============================================================
Write-Info "`n=== Resumo ==="
Write-Host ("Modo: {0}" -f ($(if ($DryRun) { "DRY-RUN" } else { "INSTALAR" }))) -ForegroundColor Yellow
Write-Host ("Unidade: {0}" -f $drive) -ForegroundColor Yellow
Write-Host ("Flutter em: {0}" -f $flutterPath) -ForegroundColor Yellow
Write-Host ("Android SDK em: {0}" -f $androidRoot) -ForegroundColor Yellow

Write-Info "`n=== Variáveis Machine configuradas ==="
$vars = @("FLUTTER_HOME", "DART_HOME", "JAVA_HOME", "ANDROID_HOME", "ANDROID_SDK_ROOT")
foreach ($v in $vars) {
    $val = Get-MachineEnv $v
    Write-Host ("{0} = {1}" -f $v, ($val ?? "")) -ForegroundColor Green
}

if ($DryRun) {
    Write-Ok "`nDRY-RUN concluído! Nada foi alterado."
}
else {
    Write-Ok "`nConcluído! Feche e reabra o PowerShell para o PATH/variáveis terem efeito no terminal atual."
    Write-Ok "Depois rode: flutter doctor -v"
}  
