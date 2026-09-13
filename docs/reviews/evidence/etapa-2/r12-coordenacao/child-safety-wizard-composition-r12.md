---
source: R12 C0 — R12-13 child-safety.create/edit wizard
status: local-green; visual/E2E pending
generated_at: 2026-09-13
---

# R12-13 — composição do wizard de Segurança da criança

Recorte: Etapa 2 → `apps/superadmin` → Segurança da criança → Criar/Editar →
Criança/Pessoa autorizada → `child-safety.create`, `child-safety.edit`.

O wizard usa `SuperadminFormFrame` com navegação de etapas, um painel de
conteúdo por etapa, grupos de campos e rodapé canônico. A composição atual não
apresenta uma moldura redundante adicional no conteúdo; os estados de criação,
edição, erro, bloqueio de salto, cancelamento e reload de save permanecem
preservados. Nenhuma refatoração visual foi necessária neste gate.

Prova local, Windows, checkout `dev`:

- `flutter test test/features/safety/presentation/safety_pages_test.dart`:
  os testes funcionais do wizard passam, incluindo busca, seleção, edição,
  deep-link, permissões e recuperação;
- a falha golden do diretório em 1440px é a divergência registrada em R12-10,
  não uma nova falha do wizard.

Nenhum contrato, SQL, RPC ou RLS foi alterado. O item permanece aberto para
aprovação visual e prova integrada de create/edit, escopo e reload.

Próximo gate: comparar a composição com a referência aprovada e executar o
wizard pela rota normal com ator e criança autorizados.
