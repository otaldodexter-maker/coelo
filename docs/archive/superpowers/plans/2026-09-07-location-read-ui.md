---
title: "LOC-READUI01 — superfícies textuais isoladas"
source: "reserva da coordenação; design Locais 2026-09-02; LOC-DTO01 9430a78d"
status: "approved-local-preparation-not-e2e"
generated_at: "2026-09-07"
---

# Location Read UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: executing-plans inline; root é o único writer, revisores são readonly.

**Goal:** Preparar diretório e detalhe textual de Locais com leitura injetada e lifecycle seguro.

**Architecture:** Painéis de conteúdo isolados, ainda sem composição na rota/shell normal. Reader app-local indisponível por padrão; modelos de coelo_domain. Autorização continua exclusivamente server-side, bool de sessão é somente gate de renderização.

**Tech Stack:** Flutter/Dart, componentes Coelo existentes, flutter_test; sem dependências novas.

## Global Constraints

- Somente Superadmin/features/locations e testes/evidência nominais.
- Sem rota, DI, sidebar, RPC wire, criação, mapa, foto, agenda ou bindings.
- Nenhum placeholder afirma ausência de reservas/vínculos que não foram consultados.
- Proprietário explícito institution/unit; não inventar nome de instituição/unidade.
- Query suporta só busca, limit e offset do contrato; sem filtros/ordenações fictícios.
- Dados são apagados no reload, troca de contexto/sessão/reader; respostas antigas e dispose ignorados.
- Paginação não despacha offset >10000; janela limitada é informada, sem apresentar total truncado como total global.

## Arquivos nominais

Criar sob `apps/superadmin/lib/features/locations/`:

- `domain/location_catalog_reader.dart`: reader, query imutável e erros seguros locais.
- `presentation/location_directory_controller.dart`: busca/página e lifecycle.
- `presentation/location_detail_controller.dart`: detalhe/lifecycle.
- `presentation/location_directory_panel.dart`: toolbar, conteúdo, paginação.
- `presentation/location_detail_panel.dart`: dados textuais e Voltar/Recarregar.
- `presentation/location_read_widgets.dart`: composição privada de cards/tabela/estados/status, sem API pública de Design System.

Criar sob `apps/superadmin/test/features/locations/`:

- `location_read_fixtures.dart`: apenas fixtures de teste e reader controlado.
- `location_read_controllers_test.dart`: contratos de request e concorrência local.
- `location_read_panels_test.dart`: estados, teclado/toque, responsividade e sessão.
- `location_read_panels_golden_test.dart`: candidatos visuais delimitados abaixo.
- `goldens/location_*.png`: somente candidatos novos, sem substituir baselines.

Evidência: `docs/reviews/evidence/etapa-2/estruturas/2026-09-07-location-read-ui.md`.

## Baseline e matriz visual anterior ao código

Família principal: Instituições. Código real do diretório/cards/toolbar/tabela,
componentes canônicos, matriz e goldens cards light375, table dark1440, card hover
light1440 e status expandido light1440 consultados. Detalhe textual segue a
composição de leitura D01/Pessoas e anatomia neutra de cards de Instituições.
Legado tem controles locais; a nova fatia usa os componentes canônicos, sem
copiar MenuAnchor/InkWell local ou ampliar allowlist.

| Estado | Componente | Teste | Candidato nominal |
| --- | --- | --- | --- |
| Diretório cards/tabela | CoeloAdminInteractiveCard/ResizableTable | panels_test | directory_{cards,table}_{light,dark}_{375,1440} |
| Breakpoints intermediários | mesma composição | panels_test 768/1024 e texto200% | directory_cards_light_{768,1024} |
| Card hover/foco | InteractiveCard | teclado/mouse | directory_card_{hover,focus}_light_1440 |
| Status expandido/toque | ExpandableStatusIndicator | toque/reduced motion | directory_status_light_1440 |
| Busca foco/toggle | SearchField/ViewToggle | foco/Enter | directory_search_focus_light_1440; directory_table_light_1440 |
| Tabela hover/foco | ResizableTable | mouse/Enter | directory_row_{hover,focus}_light_1440 |
| Arquivos adiados | FileActions/Flyout | indisponibilidade honesta | directory_files_light_1440 |
| Paginação/menu | ListingPaginationFooter/Pagination | próxima/limite | directory_pagination_light_1440 |
| Loading/empty/no-results/denied/unavailable | StatePanel na superfície | lifecycle/retry | directory_{loading,empty,no_results,denied,unavailable}_light_375 |
| Detalhe light/dark | cards neutros + FormActionFooter | painel e retorno | detail_{light_375,dark_1440} |
| Detalhe loading/denied/unavailable/foco | mesmos componentes | sessão/teclado/retry | detail_{loading,denied,unavailable,focus}_light_375 |

Nomes acima recebem prefixo location_ e extensão .png. Estados adicionais
alcançáveis encontrados nos testes recebem candidato delimitado no mesmo teste,
nunca sobrescrevem golden aprovado. Reserva permite candidatos, não aprovação
visual final de produção. Base surface, padding space4/6/10 por breakpoint,
gaps space4/6, cards min216/coluna340 conforme referência; tabela row64/header56.

## Task 1: readers e controllers

Executado em2026-09-08:20 testes PASS; RED inicial de compilação, mais RED runtime
de redução do total paginado reproduzido e corrigido. Ver evidência nominal.

- [ ] Escrever testes para default indisponível, sessão ausente sem chamada, owner/ID divergente, loading limpa dados, respostas tardias, reader/contexto substituído, listener reentrante e dispose.
- [ ] Rodar `rtk proxy C:\src\flutter\bin\flutter.bat test test/features/locations/location_read_controllers_test.dart` no Superadmin e observar RED.
- [ ] Implementar contratos mínimos e controllers; validar scope/query antes de dispatch, snapshot reader/query antes de notify e geração após cada await.
- [ ] Rodar a suíte focal até GREEN.

## Task 2: painéis e validação visual

Preparo executado em2026-09-08:19 testes de painéis e20 casos golden PASS
(30 imagens candidatas inspecionadas). Analyzer nominal0 e memória2 PASS.
Checklist de aprovação visual integral permanece aberto: diagnóstico adicional
`directory_status_text200_diagnostic_light_375` confirma corte do texto no
componente compartilhado24px. Sem aprovação a11y/E2E. Mensagem normativa de
arquivos é “Disponível depois do MVP”.

- [ ] Escrever testes de lista/detalhe por owner, callback Abrir/Voltar, busca/paginação, estados, perda de sessão, revisão de contexto e descarte de callbacks.
- [ ] Observar RED antes de implementar painéis; reutilizar componentes indexados, sem criar tokens/variantes.
- [ ] Validar 375/768/1024/1440, light/dark, 200%, teclado/foco/toque, reduced motion, import/export adiados sem persistência.
- [ ] Gerar somente candidatos novos reservados, inspecionar todas as imagens e executar novamente sem update-goldens.
- [ ] Rodar analyzer nominal, gate visual e memória; revisão readonly e handoff de commit com primeiro gate E2E ainda aberto.

Estimativa local: 2–4 horas com matrizes e revisão; não inclui integração normal,
backend replay ou prova remota. O encerramento dessa fatia não encerra a tarefa
original nem os sete IDs de Locais.
