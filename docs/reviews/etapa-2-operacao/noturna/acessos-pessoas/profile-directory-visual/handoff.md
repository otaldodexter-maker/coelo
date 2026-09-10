---
fonte: coordenacao.json r12, GOLDEN-REBASELINE-CRITERIO; censo noturno; histórico Git integrado
status: nominal-local-green; publicação pelo pai
data_geracao: 2026-09-09
---

## Recorte

apps/superadmin -> Perfis e permissões -> diretório Perfis -> cards/tabela -> 375/768/1024/1440px, claro/escuro. Somente `matches cards and responsive table at supported widths`, em `test/features/access_profiles/presentation/access_profile_golden_test.dart`: 1 ID de teste, 16 comparações PNG. Não foram repetidos hover/formulário verdes. Nenhuma edição Dart, shared, router, main, SQL, JSON central ou mutação Git.

## Critério e causas

Aplicado GOLDEN-REBASELINE-CRITERIO da coordenação r12: causa integrada específica, inspeção de cada render **antes** de substituí-lo, lista nominal de arquivos. A referência antiga é do commit 9ee3a7472 (2026-08-06). Cada um dos 16 pares foi aberto e inspecionado; os 32 PNGs de evidência estão nas subpastas correspondentes. `renders.json` lista cada caminho completo alterado, hashes antes/depois, largura, tema, modo e inspeção prévia. `causes.json` confere ancestralidade individual de todas as causas na base materializada.

| Causa integrada | Diferença explicada |
| --- | --- |
| 320a6f09f | Seletor Perfis/Modelos e Arquivos; espaço e distribuição da toolbar |
| 633a88ba5 | Card/banner Criar removido quando não há callback; cards restantes apenas informativos |
| 7f918d72a | Busca e seleção hierárquica da navegação, inclusive cores de seção/item em ambos os temas |
| ad558c6f9 | Bug report ausente sem callback de envio |
| a0be1abeb e 6c2d03450 | Alvo de status48px e medição dos cards sem IntrinsicHeight, com testes de geometria existentes |
| d8800300d | Scaffold compacto usa explicitamente colorScheme.surface, substituindo fundo padrão: branco no claro e surface escuro em375/768 |
| d9232a94d | AppBar compacto com marca Coelo/trigger em vez de hambúrguer e composição do cabeçalho |
| bd476af8d | CoeloAdminPagination compacto com setas/página; substitui Wrap com seletor e botões grandes em375 |

Não se inferiu autorização de rebaseline apenas do censo. Todas essas alterações são posteriores à referência antiga, já integradas, e não estão sendo redesenhadas neste lote. A paginação compacta observada pertence a CoeloAdminPagination (bd476af8d), não ao caminho opcional compactCurrentPage do wrapper de footer.

## Inspeção individual

| Largura | Cards claro | Tabela claro | Cards escuro | Tabela escuro |
| --- | --- | --- | --- | --- |
| 375 | inspecionado; criação ausente, Owner visível, footer compacto | inspecionado; duas linhas e scroll horizontal, footer compacto | inspecionado; mesmas mudanças, surface explícita | inspecionado; mesmas mudanças, surface explícita |
| 768 | inspecionado; dois cards, cabeçalho/toolbar novos | inspecionado; banner ausente, linhas estáveis | inspecionado; dois cards, surface explícita | inspecionado; mesmas linhas, surface explícita |
| 1024 | inspecionado; dois cards na primeira linha, sidebar atual | inspecionado; tabela deslocada sem banner | inspecionado; seleção hierárquica e status48 | inspecionado; seleção hierárquica, cores da tabela preservadas |
| 1440 | inspecionado; dois cards informativos e sidebar atual | inspecionado; tabela sem banner, footer preservado | inspecionado; mesmas mudanças, surface desktop preservada | inspecionado; mesmas mudanças, cores de tabela/footer preservadas |

Não foi identificada diferença visual sem causa nesses pares. Em375/768 a mudança do fundo escuro é explícita no shell; não foi classificada como deriva desconhecida do tema. As amostras de fundo antes/depois estão em renders.json. Recortes horizontais/truncamentos da tabela já pertencem ao viewport com scroll; não foram ocultados erros de layout.

## Prova e entrega

RED: 1 teste falho, 16 referências divergentes. Após substituir somente os16PNG pelo render individualmente inspecionado, o comparator focal passou em green.txt: P1/F0/B0/S0/U0, N1 único, 16/16 comparações PNG aprovadas, exit0. Contagens de teste e de imagem ficam separadas: o teste não representa 16 novos IDs. Não se somam tentativas RED/green.

`tracker_delta_proposto: []`: nenhuma ação FE/BE/E2E promovida. Este lote somente reconcilia a referência nominal do diretório. Hover e formulário têm entregas/provas próprias e não foram reexecutados.

Pai revisa e publica os16PNG listados em renders.json e esta evidência. Logs UTF8 sem BOM; sem processos, servidores, filhos ou recurso remoto próprio. Memória: aplicação do critério já vigente, sem decisão nova de produto ou projeção criada apenas por atividade.
