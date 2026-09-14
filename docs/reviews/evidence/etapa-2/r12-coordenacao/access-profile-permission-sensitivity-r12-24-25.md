---
source: R12-perfis-permissoes-owner.md; access_profile_form_page.dart
status: local-green; rota normal e E2E pendentes
generated_at: 2026-09-14
---

# R12-24/25 — sensibilidade e matriz de permissões

Em `apps/superadmin > Acessos > Perfis e permissões > Criar/Editar > Permissões`,
a matriz compartilhada mantém as colunas alinhadas no desktop e muda para a
composição empilhada em telas estreitas. A semântica de `próprias` e `todas`
continua separada pelo `actionCode`; nenhuma validação ou proteção server-side
foi removida.

O marcador visual repetido `Crítico`/`MFA` foi retirado das células. Permissões
sensíveis agora expõem consequência em tooltip acessível por semântica, foco,
hover e acionamento por toque. O texto diferencia ação crítica, exigência de
MFA e trilha de auditoria no servidor.

TDD: o teste focal falhou antes da implementação (tooltip inexistente), passou
após a implementação; `access_profile_form_context_test.dart` focal 1/1 PASS
e `flutter analyze` do arquivo de produção PASS. FE local-green; backend
inalterado; E2E permanece pendente para rota normal, catálogo real, reload,
escopo e negativa cross-tenant.
