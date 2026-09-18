---
source: "apps/superadmin/lib/app/shell/superadmin_shell.dart; apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart; specs/013-ui-packages-componentization.md"
status: "quick-review"
generated_at: "2026-07-20"
---

# Review Rapido: UI Superadmin E Componentizacao

## Achados

- P2: `SuperadminShell` ja e o contrato correto para rotas protegidas, mas ainda
  esta dentro de `apps/superadmin`. Manter assim por enquanto; extrair antes de
  uma segunda necessidade criaria pacote sem consumidor.
- P2: `institution_directory_page.dart` contem bons candidatos a componentes
  administrativos, especialmente filtros, tabela, status e paginacao. Ainda nao
  ha duplicacao suficiente para mover.
- P3: Existem textos com acentuacao corrompida em saidas lidas pelo terminal.
  Antes de mexer em microcopy, validar se e problema de encoding do console ou
  arquivo para nao gerar diff falso.

## Decisao

Criar a spec `013-ui-packages-componentization.md` e reservar
`coelo_ui_superadmin`. Nao mover codigo nesta etapa.

## Proxima Extracao Provavel

Quando a segunda tela administrativa nascer, os primeiros widgets a promover
devem ser:

- filtro multiselect administrativo;
- toolbar de listagem;
- chip de status;
- tabela administrativa responsiva;
- paginacao.
