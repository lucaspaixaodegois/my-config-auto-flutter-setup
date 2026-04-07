<#
.SYNOPSIS
    Script de automação para configuração de ambiente Flutter no Windows.
    
.AUTHOR
    Lucas Paixão de Gois (https://github.com)
    
.LICENSE
    MIT License
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Host "Reabrindo como Administrador..." -ForegroundColor Yellow
    $psExe = (Get-Process -Id $PID).Path
    if (-not $psExe) { $psExe = "powershell.exe" }
    $wd = (Get-Location).Path
    $argsList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath` Bit")
    Start-Process -FilePath $psExe -Verb RunAs -WorkingDirectory $wd -ArgumentList ($argsList -join " ")
    exit
}

function Write-Info($msg) { Write-Host $msg -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host $msg -ForegroundColor Green }
function Write-Warn($msg) { Write-Host $msg -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host $msg -ForegroundColor Red }

function Ensure-Dir([string]$Path) {
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

function Command-Exists([string]$cmd) {
    [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
}

function Download-File([string]$Url, [string]$OutFile, [bool]$DryRun) {
    if ($DryRun) { Write-Info "[DRY-RUN] Download: $Url"; return }
    Write-Info "Downloading: $Url"
    Import-Module BitsTransfer
    Start-BitsTransfer -Source $Url -Destination $OutFile -Description "Baixando dependência..."
}

function Expand-Zip([string]$ZipPath, [string]$Destination, [bool]$DryRun) {
    if ($DryRun) { Write-Info "[DRY-RUN] Expand: $ZipPath"; return }
    Ensure-Dir $Destination
    Write-Info "Extraindo para $Destination..."
    Expand-Archive -Path $ZipPath -DestinationPath $Destination -Force
}

function Ask-Choice([string]$Title, [string[]]$Options) {
    Write-Host "`n$Title" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Options.Length; $i++) {
        Write-Host ("  {0}) {1}" -f ($i + 1), $Options[$i])
    }
    $ans = Read-Host "Escolha (1-$($Options.Length))"
    if ($ans -match "^\d+$") {
        $n = [int]$ans
        if ($n -ge 1 -and $n -le $Options.Length) { return $n }
    }
    throw "Escolha inválida."
}

function Set-MachineEnv([string]$name, [string]$value, [bool]$DryRun) {
    if ($DryRun) { Write-Info "[DRY-RUN] Set Env: $name = $value"; return }
    [Environment]::SetEnvironmentVariable($name, $value, [EnvironmentVariableTarget]::Machine)
    Set-Content -Path "env:$name" -Value $value 
    Write-Ok "Variável definida: $name"
}

function Add-ToMachinePath([string]$toAdd, [bool]$DryRun) {
    if ([string]::IsNullOrWhiteSpace($toAdd)) { return }
    $current = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $parts = $current.Split(';') | Where-Object { $_.Trim() -ne "" }
    if ($parts -contains $toAdd) { return }
    if ($DryRun) { Write-Info "[DRY-RUN] Add PATH: $toAdd"; return }
    $new = ($parts + $toAdd) -join ';'
    [Environment]::SetEnvironmentVariable("Path", $new, [EnvironmentVariableTarget]::Machine)
    $env:Path = $new + ";" + $env:Path
    Write-Ok "PATH atualizado: $toAdd"
}

function Ensure-Chocolatey([bool]$DryRun) {
    if (Command-Exists "choco") { Write-Ok "Chocolatey OK"; return }
    if ($DryRun) { Write-Info "[DRY-RUN] Instalar Chocolatey"; return }
    Write-Warn "Instalando Chocolatey..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $installScript = (New-Object System.Net.WebClient).DownloadString("https://chocolatey.org/install.ps1")
    Invoke-Expression $installScript
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}

try {
    $drive = (Read-Host "Qual drive usar? (ex: C, D, E)").Trim().ToUpper()
    if ($drive.Length -eq 1) { $drive = "${drive}:" }
    if (-not (Test-Path "$drive\")) { throw "Drive $drive não encontrado." }

    $mode = Ask-Choice "Selecione o modo de execução:" @(
        "DRY-RUN (Apenas simulação/verificação)", 
        "INSTALL/UPDATE (Executar alterações)"
    )
    $DryRun = ($mode -eq 1)

    $strategy = Ask-Choice "Estratégia de pacotes (Chocolatey):" @(
        "INSTALAR (Mais seguro, pula se já existir)", 
        "UPGRADE (Atualiza pacotes existentes ou instala se faltar)"
    )
    $chocoVerb = if ($strategy -eq 2) { "upgrade" } else { "install" }

    $layout = Ask-Choice "Local do Flutter:" @(
        "Raiz ($drive\flutter)", 
        "Tools ($drive\tools\flutter)"
    )

    $installEssentials = Ask-Choice "Escopo das ferramentas:" @(
        "Mínimo (Git + Java)", 
        "Full (Git + Java + FVM + 7Zip + Android Studio)"
    )

    $toolsRoot   = Join-Path $drive "tools"
    $flutterPath = if ($layout -eq 1) { Join-Path $drive "flutter" } else { Join-Path $toolsRoot "flutter" }
    $androidRoot = Join-Path $drive "Android\Sdk"
    $temp        = Join-Path $env:TEMP "dev-setup"

    if (-not $DryRun) { 
        Ensure-Dir $temp
        Ensure-Dir $toolsRoot 
        Ensure-Dir $androidRoot
    }

    Ensure-Chocolatey $DryRun
    $pkgs = @("git", "microsoft-openjdk")
    if ($installEssentials -eq 2) { $pkgs += @("7zip", "fvm", "androidstudio") }
    
    Write-Info "`n== Executando Chocolatey $chocoVerb =="
    foreach ($p in $pkgs) {
        if ($DryRun) { Write-Info "[DRY-RUN] choco $chocoVerb $p" }
        else { 
            Write-Info "Processando $p..."
            & choco $chocoVerb $p -y --no-progress | Out-Host
        }
    }

    Write-Info "`n== Verificando Flutter SDK =="
    $flutterBin = Join-Path $flutterPath "bin\flutter.bat"
    if (-not (Test-Path $flutterBin)) {
        $url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_stable.zip"
        $zip = Join-Path $temp "flutter.zip"
        Download-File $url $zip $DryRun
        Expand-Zip $zip (if ($layout -eq 1) { "$drive\" } else { $toolsRoot }) $DryRun
    } else {
        Write-Ok "Flutter já presente em $flutterPath."
        if ($chocoVerb -eq "upgrade" -and -not $DryRun) {
            Write-Info "Solicitando flutter upgrade..."
            & $flutterBin upgrade | Out-Host
        }
    }
    Set-MachineEnv "FLUTTER_HOME" $flutterPath $DryRun
    Add-ToMachinePath (Join-Path $flutterPath "bin") $DryRun

    Write-Info "`n== Verificando Android SDK Tools =="
    $sdkManager = Join-Path $androidRoot "cmdline-tools\latest\bin\sdkmanager.bat"
    if (-not (Test-Path $sdkManager)) {
        $url = "https://dl.google.com/android/repository/commandlinetools-win-8512546_latest.zip"
        $zip = Join-Path $temp "cmdline.zip"
        Download-File $url $zip $DryRun
        $tmpExtract = Join-Path $temp "cmd_tmp"
        Expand-Zip $zip $tmpExtract $DryRun
        if (-not $DryRun) {
            $destLatest = Join-Path $androidRoot "cmdline-tools\latest"
            if (-not (Test-Path (Join-Path $androidRoot "cmdline-tools"))) { New-Item -ItemType Directory -Path (Join-Path $androidRoot "cmdline-tools") | Out-Null }
            if (Test-Path $destLatest) { Remove-Item $destLatest -Recurse -Force }
            Move-Item (Join-Path $tmpExtract "cmdline-tools") $destLatest -Force
        }
    }

    if (-not $DryRun) {
        Write-Info "Gerenciando componentes Android SDK..."
        $yes = @("y") * 15
        $yes | & $sdkManager --licenses | Out-Null
        & $sdkManager "platform-tools" "platforms;android-34" "build-tools;34.0.0" | Out-Host
    }

    $javaPath = Join-Path $env:ProgramFiles "Microsoft\jdk-21"
    if (-not (Test-Path $javaPath)) {
        $javaPath = Get-Command java -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source | Split-Path | Split-Path
    }
    if ($javaPath) { Set-MachineEnv "JAVA_HOME" $javaPath $DryRun }

    Write-Ok "`n=== SETUP CONCLUÍDO ==="
    if (Command-Exists "flutter") { & flutter doctor -v }

} catch {
    Write-Err "`nERRO CRÍTICO: $($_.Exception.Message)"
} finally {
    Write-Host "`nPressione ENTER para sair..."
    Read-Host | Out-Null
}
