---
source: R12 C0 — R12-10 child-safety.list table diagnostic
status: blocked-by-golden-delta; owner review pending
generated_at: 2026-09-13
---

# R12-10 — tabela do diretório de Segurança da criança

Recorte: Etapa 2 → `apps/superadmin` → Segurança da criança → Diretório →
Tabela → `child-safety.list`.

Reprodução local no checkout `dev`, Windows:

- `flutter test test/features/safety/presentation/safety_pages_test.dart`:
  19 testes passaram antes do golden e o teste
  `directory golden matches approved institution-card anatomy` falhou;
- golden `goldens/child_safety_directory_light_1440.png`: diferença de
  0,34%, 4.857 pixels;
- nenhum golden foi regenerado e nenhum allowlist foi ampliado.

O failure não foi causado por alteração de código neste slice. A tabela usa
`CoeloAdminResizableTable`, com colunas canônicas, hover/seleção e paginação;
é necessário comparar a referência aprovada e a imagem de failure antes de
decidir se há correção de composição ou baseline divergente.

Próximo gate: revisar lado a lado o golden aprovado e a failure, identificar a
diferença de linha/célula/largura e só então corrigir ou obter decisão do Owner.
