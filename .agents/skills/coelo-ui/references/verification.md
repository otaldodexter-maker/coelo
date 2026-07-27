---
source: "specs/013-ui-packages-componentization.md"
status: "active"
generated_at: "2026-07-24"
---

# Verificação de UI

Aplicar proporcionalmente ao risco:

- proteger o baseline antes de refatorar e comparar sem atualizar referências
  silenciosamente;
- formatar somente arquivos afetados;
- executar análise estática, testes focados, suíte relevante, widgets e
  goldens;
- verificar light/dark, 375/768/1024/1440 quando aplicável, texto a 200%,
  teclado, foco, semântica e reduced motion;
- buscar HEX, `Color(0x...)`, `TextStyle` e espaçamento/breakpoint local quando
  existir token semântico;
- validar imports e fronteiras;
- executar validadores do índice, catálogo e sincronização;
- revisar `git diff` e preservar mudanças não relacionadas.

Relatar: resultado, arquivos, componentes criados/promovidos/locais, diferença
visual, testes, pendências e decisão necessária.
