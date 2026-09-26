param([string]$DeviceId = "emulator-5554")
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao resolver dependências.' }
    flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'Análise estática falhou.' }
    flutter test --reporter expanded
    if ($LASTEXITCODE -ne 0) { throw 'Testes automatizados falharam.' }
    flutter drive -d $DeviceId --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart
    if ($LASTEXITCODE -ne 0) { throw 'Teste Android falhou.' }
} finally { Pop-Location }
