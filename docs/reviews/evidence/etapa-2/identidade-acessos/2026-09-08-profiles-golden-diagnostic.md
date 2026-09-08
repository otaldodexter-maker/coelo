---
title: "Perfis — diagnóstico dos três testes golden vermelhos"
source: "Execução local em 99e427f3; goldens versionados; spec 018; referências coelo-ui; inspeção do código"
status: "visual-red; diagnosis-only; no-rebaseline"
generated_at: "2026-09-08"
---

## Execução

`flutter test --no-pub test/features/access_profiles/presentation/access_profile_golden_test.dart`:
0 PASS / 3 FAIL, exit 1. São três unidades de teste, não três imagens; a
primeira percorre cards/tabela em quatro larguras e dois temas. Os guards de
continuação de diálogo não são exercitados nesses snapshots.

Inspeção visual focal comparou os goldens versionados e os artefatos de falha
gerados para cards mobile/desktop, formulário mobile, hover Admin desktop e
editor desktop escuro. Os artefatos failures são somente diagnóstico, nunca
baseline aprovada. O último commit do golden cards light 1440 é 9ee3a747.

## Separação dos deltas observados

| Região | Diferença observada | Evidência / consequência |
|---|---|---|
| Diretório | Abas Perfis/Modelos e Arquivos ausentes no snapshot antigo | Spec 018 aditivo e commits 320a6f09/3969bfba; não remover funcionalidades posteriores para igualar imagem |
| Criar | Snapshot antigo exibe Criar; fixture atual não fornece onCreate | DirectoryPage só renderiza criação com callback (:610, :808); restaurar botão sem ação contrariaria o teste funcional |
| Editor | Seleção/limpeza por app, módulo e tela não aparece no snapshot antigo | Spec 018:219–222; form_page:768, :864, :1113; geometria nova não implica aprovação visual automática |
| Shell desktop | Busca de navegação, seleção do menu e ausência do ícone Bug | Superfície compartilhada; encaminhar aos owners de shell/DS, sem correção local nesta frente |
| Shell mobile | Cabeçalho Coelo substitui hamburger e subtítulo quebra linha | Compartilhado; não atribuir aos guards de formulário |
| Paginação mobile | Atual mostra controle compacto, antigo mostra tamanho e campo de página | DirectoryPage usa CoeloAdminPagination (:1043); componente possui ramo compacto (:101), sem variante local |
| Hover Admin | Realce tonal arredondado continua visível, mas a tela inteira mudou | Golden integral vermelho não comprova isoladamente regressão do hover |

Não foi identificado fundamento para um rebaseline automático. Os snapshots
misturam dependências compartilhadas, funcionalidades posteriores e mudança
de disponibilidade da fixture. Antes de alterar imagens, precisa reconciliar
baseline atual com os owners, separar fixture interativa com callbacks da
fixture informacional e verificar os estados exigidos pela matriz coelo-ui.
Isso não autoriza reativar CRUD produtivo.

## Verificações e limites

Regressão funcional anterior: 45/45 em páginas, continuação, detalhe e rotas.
Validador `dart run tool/validate_admin_visual_contracts.dart ../.. assets/admin-visual-contract-allowlist.json`,
a partir de apps/catalog: exit 0. Não prova aprovação visual.

Sem edição de UI, DS, shell, router ou masters; nenhuma ampliação de allowlist.
375/768/1024/1440 e temas foram percorridos pelo teste, mas a inspeção visual
manual foi focal, não uma aprovação completa de todas as imagens/estados.
Texto 200%, teclado/foco, browser real e produção permanecem gates próprios.
Gate de memória: no-op, nenhuma regra de produto foi alterada.
