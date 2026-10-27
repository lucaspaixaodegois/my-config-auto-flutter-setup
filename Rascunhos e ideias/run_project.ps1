# =====================================================
# Ambiente local do projeto Discograma Ruraltins
# Usa JDK 17 somente nesta sessão do terminal
# =====================================================

$env:JAVA_HOME = "C:\Program Files\Microsoft\jdk-17"
$env:ANDROID_HOME = "D:\Android\Sdk"
$env:ANDROID_SDK_ROOT = "D:\Android\Sdk"

$env:Path = "$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:ANDROID_HOME\cmdline-tools\latest\bin;$env:ANDROID_HOME\emulator;$env:Path"

Write-Host "JAVA_HOME = $env:JAVA_HOME"
java -version

Write-Host ""
Write-Host "ANDROID_HOME = $env:ANDROID_HOME"
adb version

Write-Host ""
Write-Host "Flutter Doctor:"
flutter doctor -v