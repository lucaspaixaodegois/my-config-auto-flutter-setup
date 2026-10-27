# auditoria_flutter.ps1
# Script para gerar relatório de auditoria de compatibilidade Flutter

# Registrar início da execução
$startTime = Get-Date
Write-Host "⏳ Auditoria em processamento... aguarde a conclusão." -ForegroundColor Cyan

# Nome do arquivo de saída
$report = "auditoria_flutter.md"

# Inicializar/Limpar arquivo de relatório com cabeçalho
@"
# Auditoria de Compatibilidade Flutter

**Data:** $(Get-Date -Format "dd/MM/yyyy HH:mm")  
**Auditor:** $env:UserName  

## 📱 Identificação
### 🧭 Ambiente
"@ | Out-File $report -Encoding utf8

# Versões principais (Capturando o Output text explicitamente)
Write-Host "-> Verificando versões do Flutter e Dart..."
"#### Flutter" | Out-File $report -Append
& flutter --version | Out-File $report -Append

"#### Dart" | Out-File $report -Append
& dart --version | Out-File $report -Append

"#### Flutter Doctor" | Out-File $report -Append
& flutter doctor -v | Out-File $report -Append

# Dependências
Write-Host "-> Analisando dependências..."
"### 📦 Dependências" | Out-File $report -Append
& flutter pub outdated | Out-File $report -Append

# Análise e testes
Write-Host "-> Executando análise de código e testes..."
"### 🧠 Qualidade do Código" | Out-File $report -Append
& flutter analyze | Out-File $report -Append

"#### Testes Automatizados" | Out-File $report -Append
& flutter test | Out-File $report -Append

# FVM
Write-Host "-> Verificando FVM..."
"### 🧩 FVM" | Out-File $report -Append
if (Test-Path ".fvm") {
    "Configuração FVM detectada no projeto." | Out-File $report -Append
    Get-ChildItem -Path .fvm -Force | Out-String | Out-File $report -Append
} else {
    "FVM não utilizado neste projeto." | Out-File $report -Append
}

# Android
Write-Host "-> Analisando configurações nativas do Android..."
"### 🤖 Android" | Out-File $report -Append
if (Test-Path "android") {
    Push-Location android
    try {
        "#### Gradle Version" | Out-File ..$report -Append
        if (Get-Command "./gradlew" -ErrorAction SilentlyContinue) {
            & ./gradlew -v | Out-String | Out-File ..$report -Append
        } else {
            "Gradlew não encontrado ou sem permissão de execução." | Out-File ..$report -Append
        }
        
        "#### Configurações do SDK e Versões" | Out-File ..$report -Append
        Get-ChildItem -Recurse -Include *.gradle, *.kts, gradle-wrapper.properties, AndroidManifest.xml -ErrorAction SilentlyContinue | 
            Select-String "compileSdk|targetSdk|minSdk|com.android.tools.build:gradle|org.jetbrains.kotlin|kotlin_version|applicationId|namespace|ndkVersion" | 
            Select-Object -ExpandProperty Line | Out-File ..$report -Append
    } finally {
        Pop-Location
    }
} else {
    "Diretório Android não encontrado." | Out-File $report -Append
}

# Web e Desktop (Validação por existência de pastas em vez de Build real)
Write-Host "-> Verificando plataformas suportadas..."
"### 🌐 Web & 💻 Desktop Suportados" | Out-File $report -Append
$platforms = @("web", "windows", "linux", "macos")
foreach ($platform in $platforms) {
    if (Test-Path $platform) {
        "- ✅ Plataforma **$platform** está configurada no projeto." | Out-File $report -Append
    } else {
        "- ❌ Plataforma **$platform** NÃO está configurada." | Out-File $report -Append
    }
}

# Resumo final
@"

## 📊 Resultado Final


| Categoria | Status |
|------------|--------|
| Ambiente | |
| Dependências | |
| Android | |
| Web | |
| Desktop | |
| Testes | |
| **Saúde geral do projeto** | ✅ OK / ⚠️ Atenção / ❌ Bloqueio |
"@ | Out-File $report -Append

# Calcular tempo total de execução
$endTime = Get-Date
$duration = $endTime - $startTime
$minutes = [math]::Round($duration.TotalMinutes, 2)

# Adicionar tempo ao relatório
@"

## ⏱️ Tempo de Execução
**Início:** $($startTime.ToString("HH:mm:ss"))  
**Fim:** $($endTime.ToString("HH:mm:ss"))  
**Duração total:** $minutes minutos
"@ | Out-File $report -Append

# Mensagem final no terminal
Write-Host "`n✅ Auditoria concluída! Relatório gerado em: $report" -ForegroundColor Green
Write-Host "⏱️ Tempo total de execução: $minutes minutos" -ForegroundColor Yellow
