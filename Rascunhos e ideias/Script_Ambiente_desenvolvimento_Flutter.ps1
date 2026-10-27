# ==========================================
# Script Unificado
# Combina funções de:
# 1. Verifica e instala Flutter, Java
# 2. Configura e instala Flutter, Dart, Java e Android SDK
# 3. Obtém todas as variáveis de ambiente
# ==========================================



# --- Funções de Verificação e Instalação ---
# Verifica e instala Flutter, Java, Dart e FVM

# Função para verificar se um comando existe
function CommandExists {
    param ($command)
    $exists = $false
    try {
        $output = & $command --version 2>$null
        if ($output) { $exists = $true }
    } catch {}
    return $exists
}

# Caminhos de instalação
$flutterPath = "C:\flutter"
$dartPath = "C:\tools\dart-sdk"
$fvmPath = "C:\tools\fvm"
$javaPath = "C:\Program Files\Microsoft\jdk-21.0.6"

# Verificando e instalando Flutter
if (-not (CommandExists "flutter")) {
    Write-Host "Flutter não encontrado. Baixando e instalando..."
    Invoke-WebRequest -Uri "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.29.0-stable.zip" -OutFile "flutter.zip"
    Expand-Archive -Path "flutter.zip" -DestinationPath "C:\"
    Remove-Item "flutter.zip"
    [System.Environment]::SetEnvironmentVariable("Path", "$flutterPath\bin;" + [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine), [System.EnvironmentVariableTarget]::Machine)
} else {
    Write-Host "Flutter já está instalado."
}

# Verificando e instalando Java
if (-not (CommandExists "java")) {
    Write-Host "Java não encontrado. Baixando e instalando OpenJDK 21..."
    Invoke-WebRequest -Uri "https://aka.ms/download-jdk/microsoft-jdk-21.0.6-windows-x64.zip" -OutFile "java.zip"
    Expand-Archive -Path "java.zip" -DestinationPath "C:\Program Files\Microsoft\"
    Remove-Item "java.zip"
    [System.Environment]::SetEnvironmentVariable("Path", "$javaPath\bin;" + [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine), [System.EnvironmentVariableTarget]::Machine)
} else {
    Write-Host "Java já está instalado."
}

# Verificando e instalando Dart
if (-not (CommandExists "dart")) {
    Write-Host "Dart não encontrado. Baixando e instalando..."
    Invoke-WebRequest -Uri "https://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-windows-x64-release.zip" -OutFile "dart.zip"
    Expand-Archive -Path "dart.zip" -DestinationPath "C:\tools"
    Remove-Item "dart.zip"
    [System.Environment]::SetEnvironmentVariable("Path", "$dartPath\bin;" + [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine), [System.EnvironmentVariableTarget]::Machine)
} else {
    Write-Host "Dart já está instalado."
}

# Verificando e instalando FVM
if (-not (CommandExists "fvm")) {
    Write-Host "FVM não encontrado. Instalando via Dart..."
    dart pub global activate fvm
    [System.Environment]::SetEnvironmentVariable("Path", "$env:APPDATA\Pub\Cache\bin;" + [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine), [System.EnvironmentVariableTarget]::Machine)
} else {
    Write-Host "FVM já está instalado."
}

# Finalizando
Write-Host "Configuração concluída! Reinicie o terminal para aplicar as alterações."


# --- Funções de Configuração e Instalação ---
# ===========================
# Configurar e instalar Flutter, Dart, Java e Android SDK
# ===========================

# Função para adicionar variáveis de ambiente
function Add-EnvVariable($name, $value) {
    [System.Environment]::SetEnvironmentVariable($name, $value, [System.EnvironmentVariableTarget]::Machine)
    Write-Host "Variável de ambiente $name definida como: $value" -ForegroundColor Green
}

Write-Host "Verificando e instalando Flutter, Dart, Java e Android SDK..." -ForegroundColor Cyan

# ===========================
# Verificar e instalar Flutter
# ===========================
Write-Host "`nFlutter Version:" -ForegroundColor Yellow
if (Get-Command flutter -ErrorAction SilentlyContinue) {
    flutter --version
}
else {
    Write-Host "Flutter não encontrado. Instalando..." -ForegroundColor Red
    Invoke-WebRequest -Uri "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.13.9-stable.zip" -OutFile "flutter.zip"
    Expand-Archive -Path "flutter.zip" -DestinationPath "C:\tools\"
    Add-EnvVariable "FLUTTER_HOME" "C:\tools\flutter"
    Add-EnvVariable "Path" "$env:Path;C:\tools\flutter\bin"
}

# ===========================
# Verificar e instalar Dart
# ===========================
Write-Host "`nDart Version:" -ForegroundColor Yellow
if (Get-Command dart -ErrorAction SilentlyContinue) {
    dart --version
}
else {
    Write-Host "Dart não encontrado. Instalando..." -ForegroundColor Red
    Invoke-WebRequest -Uri "https://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-windows-x64-release.zip" -OutFile "dart.zip"
    Expand-Archive -Path "dart.zip" -DestinationPath "C:\tools\"
    Add-EnvVariable "DART_HOME" "C:\tools\dart-sdk"
    Add-EnvVariable "Path" "$env:Path;C:\tools\dart-sdk\bin"
}

# ===========================
# Verificar e instalar Java
# ===========================
Write-Host "`nJava Version:" -ForegroundColor Yellow
if (Get-Command java -ErrorAction SilentlyContinue) {
    java -version
}
else {
    Write-Host "Java não encontrado. Instalando OpenJDK 17..." -ForegroundColor Red
    Invoke-WebRequest -Uri "https://download.java.net/java/GA/jdk17/0/GPL/openjdk-17_windows-x64_bin.zip" -OutFile "java.zip"
    Expand-Archive -Path "java.zip" -DestinationPath "C:\tools\java"
    Add-EnvVariable "JAVA_HOME" "C:\tools\java\jdk-17"
    Add-EnvVariable "Path" "$env:Path;C:\tools\java\jdk-17\bin"
}

# ===========================
# Verificar e instalar Android SDK
# ===========================
Write-Host "`nAndroid SDK Version:" -ForegroundColor Yellow
if (Test-Path "C:\Android\Sdk") {
    & "C:\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat" --list | Select-String "Installed"
}
else {
    Write-Host "Android SDK não encontrado. Instalando..." -ForegroundColor Red
    Invoke-WebRequest -Uri "https://dl.google.com/android/repository/commandlinetools-win-8512546_latest.zip" -OutFile "android-sdk.zip"
    Expand-Archive -Path "android-sdk.zip" -DestinationPath "C:\Android"
    Add-EnvVariable "ANDROID_HOME" "C:\Android\Sdk"
    Add-EnvVariable "ANDROID_SDK_ROOT" "C:\Android\Sdk"
    Add-EnvVariable "Path" "$env:Path;C:\Android\Sdk\cmdline-tools\latest\bin;C:\Android\Sdk\platform-tools"
}

# ===========================
# Verificar e instalar ADB
# ===========================
Write-Host "`nADB Version:" -ForegroundColor Yellow
if (Get-Command adb -ErrorAction SilentlyContinue) {
    adb version
}
else {
    Write-Host "ADB não encontrado. Instalando Android Platform Tools..." -ForegroundColor Red
    Invoke-WebRequest -Uri "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile "platform-tools.zip"
    Expand-Archive -Path "platform-tools.zip" -DestinationPath "C:\Android\Sdk"
    Add-EnvVariable "Path" "$env:Path;C:\Android\Sdk\platform-tools"
}

# ===========================
# Verificar e instalar Android NDK
# ===========================
Write-Host "`nAndroid NDK Version:" -ForegroundColor Yellow
if (Test-Path "C:\Android\Sdk\ndk") {
    ndk-build --version
}
else {
    Write-Host "Android NDK não encontrado. Instalando..." -ForegroundColor Red
    & "C:\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat" "ndk;21.4.7075529"
}

# ===========================
# Exibir variáveis de ambiente
# ===========================
Write-Host "`n=== Variáveis de Ambiente Configuradas ===" -ForegroundColor Cyan
$envVars = @("FLUTTER_HOME", "DART_HOME", "JAVA_HOME", "ANDROID_HOME", "ANDROID_SDK_ROOT")
foreach ($var in $envVars) {
    Write-Host "$var = " -NoNewline
    Write-Host ([System.Environment]::GetEnvironmentVariable($var, "Machine") -replace ";;", ";") -ForegroundColor Green
}

Write-Host "`nInstalação e configuração concluída! Reinicie o computador para aplicar as mudanças." -ForegroundColor Green

# --- Funções para Obter Variáveis de Ambiente ---
# ===========================
# Configurar e instalar Flutter, Dart, Java e Android SDK
# ===========================

# Função para adicionar variáveis de ambiente
function Add-EnvVariable($name, $value) {
    [System.Environment]::SetEnvironmentVariable($name, $value, [System.EnvironmentVariableTarget]::Machine)
    Write-Host "Variável de ambiente $name definida como: $value" -ForegroundColor Green
}

Write-Host "Verificando e instalando Flutter, Dart, Java e Android SDK..." -ForegroundColor Cyan

# ===========================
# Verificar e instalar Flutter
# ===========================
Write-Host "`nFlutter Version:" -ForegroundColor Yellow
if (Get-Command flutter -ErrorAction SilentlyContinue) {
    flutter --version
}
else {
    Write-Host "Flutter não encontrado. Instalando..." -ForegroundColor Red
    Invoke-WebRequest -Uri "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.13.9-stable.zip" -OutFile "flutter.zip"
    Expand-Archive -Path "flutter.zip" -DestinationPath "C:\tools\"
    Add-EnvVariable "FLUTTER_HOME" "C:\tools\flutter"
    Add-EnvVariable "Path" "$env:Path;C:\tools\flutter\bin"
}

# ===========================
# Verificar e instalar Dart
# ===========================
Write-Host "`nDart Version:" -ForegroundColor Yellow
if (Get-Command dart -ErrorAction SilentlyContinue) {
    dart --version
}
else {
    Write-Host "Dart não encontrado. Instalando..." -ForegroundColor Red
    Invoke-WebRequest -Uri "https://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-windows-x64-release.zip" -OutFile "dart.zip"
    Expand-Archive -Path "dart.zip" -DestinationPath "C:\tools\"
    Add-EnvVariable "DART_HOME" "C:\tools\dart-sdk"
    Add-EnvVariable "Path" "$env:Path;C:\tools\dart-sdk\bin"
}

# ===========================
# Verificar e instalar Java
# ===========================
Write-Host "`nJava Version:" -ForegroundColor Yellow
if (Get-Command java -ErrorAction SilentlyContinue) {
    java -version
}
else {
    Write-Host "Java não encontrado. Instalando OpenJDK 17..." -ForegroundColor Red
    Invoke-WebRequest -Uri "https://download.java.net/java/GA/jdk17/0/GPL/openjdk-17_windows-x64_bin.zip" -OutFile "java.zip"
    Expand-Archive -Path "java.zip" -DestinationPath "C:\tools\java"
    Add-EnvVariable "JAVA_HOME" "C:\tools\java\jdk-17"
    Add-EnvVariable "Path" "$env:Path;C:\tools\java\jdk-17\bin"
}

# ===========================
# Verificar e instalar Android SDK
# ===========================
Write-Host "`nAndroid SDK Version:" -ForegroundColor Yellow
if (Test-Path "C:\Android\Sdk") {
    & "C:\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat" --list | Select-String "Installed"
}
else {
    Write-Host "Android SDK não encontrado. Instalando..." -ForegroundColor Red
    Invoke-WebRequest -Uri "https://dl.google.com/android/repository/commandlinetools-win-8512546_latest.zip" -OutFile "android-sdk.zip"
    Expand-Archive -Path "android-sdk.zip" -DestinationPath "C:\Android"
    Add-EnvVariable "ANDROID_HOME" "C:\Android\Sdk"
    Add-EnvVariable "ANDROID_SDK_ROOT" "C:\Android\Sdk"
    Add-EnvVariable "Path" "$env:Path;C:\Android\Sdk\cmdline-tools\latest\bin;C:\Android\Sdk\platform-tools"
}

# ===========================
# Verificar e instalar ADB
# ===========================
Write-Host "`nADB Version:" -ForegroundColor Yellow
if (Get-Command adb -ErrorAction SilentlyContinue) {
    adb version
}
else {
    Write-Host "ADB não encontrado. Instalando Android Platform Tools..." -ForegroundColor Red
    Invoke-WebRequest -Uri "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile "platform-tools.zip"
    Expand-Archive -Path "platform-tools.zip" -DestinationPath "C:\Android\Sdk"
    Add-EnvVariable "Path" "$env:Path;C:\Android\Sdk\platform-tools"
}

# ===========================
# Verificar e instalar Android NDK
# ===========================
Write-Host "`nAndroid NDK Version:" -ForegroundColor Yellow
if (Test-Path "C:\Android\Sdk\ndk") {
    ndk-build --version
}
else {
    Write-Host "Android NDK não encontrado. Instalando..." -ForegroundColor Red
    & "C:\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat" "ndk;21.4.7075529"
}

# ===========================
# Exibir variáveis de ambiente
# ===========================
Write-Host "`n=== Variáveis de Ambiente Configuradas ===" -ForegroundColor Cyan
$envVars = @("FLUTTER_HOME", "DART_HOME", "JAVA_HOME", "ANDROID_HOME", "ANDROID_SDK_ROOT")
foreach ($var in $envVars) {
    Write-Host "$var = " -NoNewline
    Write-Host ([System.Environment]::GetEnvironmentVariable($var, "Machine") -replace ";;", ";") -ForegroundColor Green
}

Write-Host "`nInstalação e configuração concluída! Reinicie o computador para aplicar as mudanças." -ForegroundColor Green