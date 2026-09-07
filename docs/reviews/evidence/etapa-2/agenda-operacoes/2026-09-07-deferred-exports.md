---
title: "E2E 5 — exportações informativas do MVP"
source: "AGENTS.md; ADR 0032; prompts-etapa-2-e2e.md Prompt 6; autorização do Coordenador em 2026-09-07"
status: "local-green-with-open-visual-gates"
generated_at: "2026-09-07"
---

# Recorte e resultado

Branch `codex/e2e-agenda-operacoes`, base
`1150ca30cb5fe414bf28b4aadabb3abcc85d4dec`.
Somente Superadmin, `audit.export` e `attendance.export`.
Objetivo: controles visíveis, acessíveis e informativos, sem exportação real.
Fora: mudanças de backend, produção, router/shell/design system e rastreadores.
Ordem: RED de Auditoria, correção, RED de Assiduidade, correção, regressão/review.
Critério deste pacote: demonstrar ausência de job/poll/download e registrar gates
abertos; não declarar concluída a vertical. Execução geral continua até o corte
de 08/09 às 03:20 BRT. Checkpoint às 19:22 BRT, cerca de 13 minutos desde retomada.

- Auditoria preserva CSV/XLSX no componente canônico `CoeloAdminFileActions`,
  mas remove o diálogo e todas as chamadas de geração/poll/download da UI.
  O parâmetro legado `openDownloadUrl` da página fica compatível e não é chamado.
- O controle informativo não depende da capability futura `audit.export`.
  Isso não altera autorização de leitura ou escrita no backend.
- Assiduidade recebe os mesmos controles no cabeçalho local, usando `Wrap`,
  tokens existentes e modo compacto por constraints.
- Ambos exibem `Disponível depois do MVP` pelo aviso compartilhado existente.
- Artefatos/repositories de exportação legados permanecem congelados fora deste
  fluxo. Nenhuma mutation remota, migration, arquivo exportado ou segredo.

## Evidência de testes

Comandos Flutter executados de `apps/superadmin`, com prefixo `rtk proxy`:

| Verificação | Resultado |
| --- | --- |
| `flutter test test/features/audit/audit_directory_page_test.dart --reporter expanded` antes da correção | RED: 12 passaram, 3 falharam nos requisitos novos |
| Mesmo arquivo após correção, `--no-pub` | 15/15 passaram |
| `flutter test --no-pub test/features/attendance/attendance_pages_test.dart --plain-name "dashboard exports are informative" --reporter expanded` antes da correção | RED: 4 falhas por ausência do controle |
| Mesmo comando após correção | 4/4 passaram |
| `flutter analyze --no-pub lib/features/audit lib/features/attendance test/features/audit test/features/attendance` | Sem problemas, exit 0 |
| `flutter test --no-pub test/features/audit test/features/attendance --reporter expanded` | 93 passaram, 4 falharam; não é suíte verde |

Asserções novas: zero solicitações/polls de exportação, zero abertura de URL,
mensagem correta, ausência de botão de geração; controle visível sem capability
de exportação. Assiduidade cobre 375/768/1024/1440, claro/escuro, texto 200% e alvo
mínimo. A 375/200%, o teste rola o conteúdo até o controle antes do toque.

Do package `coelo_ui_admin`, `flutter test
test/listing/coelo_admin_file_actions_test.dart
test/overlay/coelo_admin_flyout_test.dart --reporter expanded`: 10/10 passaram,
incluindo geometria, hover, semântica, texto 200% e retorno de foco com Escape.
A primeira tentativa com `--no-pub` não tinha resolução local de dependências;
nova execução com resolução normal passou, sem alteração de pubspec/lockfile.

De `apps/catalog`, `dart run tool/validate_admin_visual_contracts.dart ../..
assets/admin-visual-contract-allowlist.json`: exit 0. Nenhuma allowlist alterada.
`git diff --check`: exit 0.

## Gates abertos e deltas para o Coordenador

- `audit.export`: correção local demonstrada; não promover para `verified` ou
  E2E enquanto a regressão visual permanecer aberta. Goldens da matriz responsiva
  e dos estados empty/failure divergem; referências não foram atualizadas.
- `attendance.export`: correção local demonstrada; não promove a tela inteira.
  O golden de contexto da nova chamada a 375 px diverge e o teste
  `call flow adapts at Coelo breakpoints without overflow` acusa 11 px no rodapé
  a 375 px/texto 200%. A falha de CallPage também foi reproduzida com cópia
  temporária do teste original de HEAD; CallPage não foi alterada neste pacote.
  A cópia temporária foi removida após a confirmação, preservando o teste original.
- Back-end Supabase/Cloudflare: nenhum delta de conclusão; exportação real
  continua pós-MVP, e esses controles não exigem job/R2.
- E2E: nenhum teste real de produção/reload executado; zero promoção.
- Próximo pacote: contrato produtivo do diretório de Atividades v2 sob reserva
  local E2E5-A01; promoção remota depende de lease e harness/replay do Coordenador.

## Revisão e memória

Review independente read-only dos cinco arquivos: sem achados acionáveis.
Ressalva: testes locais novos usam toque; keyboard/foco são cobertos pelo
componente compartilhado, sem certificação de anúncio do aviso em leitor real.
Baseline escolhida: controles de arquivos de Instituições; golden aprovado
`institution_directory_files_hover_light_1440.png` inspecionado, sem alteração.
Nenhum componente/token/padrão novo.

Memória: `no-op`. A política durável já consta em AGENTS e na projeção
`docs/knowledge/team/mvp-storage-and-deferred-file-actions.md`; o pacote corrige
o wiring para obedecê-la e não cria nova decisão de produto.
