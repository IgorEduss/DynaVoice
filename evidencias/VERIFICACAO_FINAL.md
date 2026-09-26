# Verificação final - 25/09/2026

- Flutter analyze: No issues found.
- Flutter test: 16 testes aprovados.
- SQLite/Python: 23 verificações aprovadas; cinco consultas exportadas.
- Android: um cenário de integração aprovado; o contador interno inclui tearDownAll.
- APK debug do ponto de entrada lib/main.dart: compilado, instalado e aberto no emulador Pixel 8 / Android 14.
- PDF: 6 páginas A4; todas renderizadas com Poppler e inspecionadas visualmente. A segunda renderização ampliou código e imagens; as páginas alteradas foram novamente inspecionadas.
- Relatório editável: Markdown gerado a partir da mesma fonte do PDF.
- Capturas do teste: evidencias/telas/01_atendimento.png a 04_resultados.png.
- Captura da inicialização normal: evidencias/telas/05_apk_final.png.

Limites: teste interno Android, sem transcrição de voz real, sem validação de overlay entre aplicativos, compartilhamento externo, aparelho físico, segurança clínica ou desempenho. README e relatório registram esses limites. O SDK apresentou avisos de atualização futura de Gradle/AGP/Kotlin, mas a compilação terminou com êxito.
