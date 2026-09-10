---
fonte: "coordenacao.json r12 GOLDEN-REBASELINE-CRITERIO; censo E2-noturna-golden-census-20260909; commits nominais no manifest.json"
status: "local-green; publicacao pelo pai pendente"
data_geracao: "2026-09-09"
---

# Usuarios internos: reconciliacao focal de referencias

Recorte: apps/superadmin -> Acessos -> Usuarios internos -> diretorio cards/tabela, criar/editar, visualizar e acoes protegidas -> internal-users.list/create/edit/suspend. Familia administrativa: Instituicoes para diretorio; Criar/Editar Instituicao para formularios. Indice Coelo UI consultado para pattern.admin-directory e pattern.form-controls. Sem alteracao Dart, SQL, MFA, contratos, main/router ou componentes compartilhados.

Quatro testes conhecidos vermelhos no censo foram executados: RED 0P/4F; regeneracao 4P; comparator independente sem --update-goldens 4P/0F/0S. Contagem final unica: 4 testes, 23 PNGs; RED e regeneracao nao somam passes. Logs red.txt, update.txt e green.txt. O wrapper PowerShell da regeneracao terminou 1 por aviso RTK em stderr; o runner registrou All tests passed. O comparator utiliza exit LASTEXITCODE para registrar o codigo nativo.

Todos os 23 pares antes/atual foram abertos e inspecionados antes da regeneracao. Cada novo master coincide byte a byte com o render inspecionado (SHA256 no manifest). Os arquivos *-comparison.png exibem ambos os estados; *-before.png e *-inspected.png preservam os pixels originais. Nenhum arquivo de failures/ sera rastreado. Os masters anteriores vieram de d37b2ab825, 61636c33e3 e f546561d45; o manifest registra o commit por caminho.

## Causas concretas integradas

- c0823f598: FakePlatformUserRepository passa ao catalogo sintetico compartilhado; Ana Lima torna-se Ana Almeida, emprego/contatos/escopos/status e total paginado acompanham fixtures. Nao sao dados reais nem prova de leitura remota.
- 2c0dbe84b: Criar acesso interno desaparece quando onCreate e nulo. O harness nao fornece callback. Card/banner nao devem simular acao.
- 7000ff9f8: Arquivos entra na toolbar e provoca wrap conforme largura; importacao/exportacao continuam adiadas.
- bd476af8d: paginacao compacta torna-se anterior/resumo/proxima; widths maiores preservam controles completos e wrap devido ao total sintetico maior.
- a218f6cb4: entrada de nascimento usa seletor de data compartilhado e CPF recebe mascara. O CPF mostrado no formulario e fixture sintetica.
- d4374e399: footer de formulario compacto entra no scroll; o formulario desktop preserva rodape fixo. Nenhuma mudanca de comportamento foi introduzida aqui.
- 554f16c43: CoeloAdminInteractiveCard nao pinta hover quando onPressed e nulo. O teste chamado card_hover nao injeta onView; a ausencia atual de destaque e intencional. Isto NAO prova hover de card acionavel: essa lacuna permanece, sem fabricar callback no harness.
- d9232a94d: marca/chevron e altura do header compacto; 057aad8f9: subtitle compacto sem truncamento; d8800300d: superficie compacta canonica; 7f918d72a: busca e hierarquia do menu; ad558c6f9: bug indisponivel sem callback; 91d1ffbff: launcher ausente sem callback real.
- d27c307fc2, 320a6f09f e d019c109a: arvore normal de Acessos, remocao da entrada separada de Modelos e Usuarios internos normal. Afetam sobretudo o shell dos formularios; nao abrem escrita.

As 16 causas sao ancestrais de d784462c1 (checks no manifest). A inspecao encontrou anatomia, superficies, contraste e alinhamento preservados; nao houve deriva de tema sem causa identificada. No flyout Owner, suspender/revogar permanecem desabilitados, sem nova acao negativa disponivel.

## Limites e proximo passo

Avanco visual local apenas. Nenhuma promocao FE/BE/E2E; respostas de composicao produtiva continuam em composicao-produtiva.md. Escrita normal de Usuarios internos permanece bloqueada; MFA segue ADR0019 AAL1. O golden protegido Owner nao comprova autorizacao server-side nem comando em producao. Nao houve nova decisao duravel de produto, portanto nao ha nova projecao de conhecimento.

Pai: revisar manifest/logs e publicar somente estes 23 masters mais esta evidencia. Recursos locais encerrados ao entregar; nenhum servidor, Docker ou recurso remoto criado. WIP nominal preservado nesta pasta e nos masters listados. Nenhum commit/push feito pelo filho.

## Caminhos nominais

- `apps/superadmin/test/features/platform_users/presentation/goldens/platform_user_create_light_375.png`
- `apps/superadmin/test/features/platform_users/presentation/goldens/platform_user_detail_actions_open_dark_1440.png`
- `apps/superadmin/test/features/platform_users/presentation/goldens/platform_user_directory_card_hover_light_1440.png`
- `apps/superadmin/test/features/platform_users/presentation/goldens/platform_user_directory_cards_dark_1024.png`
- `apps/superadmin/test/features/platform_users/presentation/goldens/platform_user_directory_cards_dark_1440.png`
- `apps/superadmin/test/features/platform_users/presentation/goldens/platform_user_directory_cards_dark_375.png`
- `apps/superadmin/test/features/platform_users/presentation/goldens/platform_user_directory_cards_dark_768.png`
- `apps/superadmin/test/features/platform_users/presentation/goldens/platform_user_directory_cards_light_1024.png`
- `apps/superadmin/test/features/platform_users/presentation/goldens/platform_user_directory_cards_light_1440.png`
- `apps/superadmin/test/features/platform_users/presentation/goldens/platform_user_directory_cards_light_375.png`
- `apps/superadmin/test/features/platform_users/presentation/goldens/platform_user_directory_cards_light_768.png`
- `apps/superadmin/test/features/platform_users/presentation/goldens/platform_user_directory_filter_open_light_1440.png`
- `apps/superadmin/test/features/platform_users/presentation/goldens/platform_user_directory_table_dark_1024.png`
- `apps/superadmin/test/features/platform_users/presentation/goldens/platform_user_directory_table_dark_1440.png`
- `apps/superadmin/test/features/platform_users/presentation/goldens/platform_user_directory_table_dark_375.png`
- `apps/superadmin/test/features/platform_users/presentation/goldens/platform_user_directory_table_dark_768.png`
- `apps/superadmin/test/features/platform_users/presentation/goldens/platform_user_directory_table_light_1024.png`
- `apps/superadmin/test/features/platform_users/presentation/goldens/platform_user_directory_table_light_1440.png`
- `apps/superadmin/test/features/platform_users/presentation/goldens/platform_user_directory_table_light_375.png`
- `apps/superadmin/test/features/platform_users/presentation/goldens/platform_user_directory_table_light_768.png`
- `apps/superadmin/test/features/platform_users/presentation/goldens/platform_user_edit_dark_1440.png`
- `apps/superadmin/test/features/platform_users/presentation/goldens/platform_user_view_dark_1440.png`
- `apps/superadmin/test/features/platform_users/presentation/goldens/platform_user_view_light_375.png`
