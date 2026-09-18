---
source: "coordenacao.json r10 GOLDEN-REBASELINE-CRITERIO; git history/blame; renders inspected before regeneration"
status: "reconciled local reference; no new FE certificate"
generated_at: "2026-09-09"
---

# Formulario: reconciliacao nominal de tres referencias

`apps/superadmin -> Acessos -> Perfis/Modelos -> criar/editar ->
access-profiles.create,access-profiles.edit,access-models.create,access-models.edit`.

O F1 herdado pertencia ao teste `matches create mobile and permission editor
desktop`, com tres comparacoes. A referencia foi gravada em9ee3a7472
(06/08). O lote b285a6804 nao mudou esses renders: visual-comparison.json
registra identidade byte a byte entre sua base e a correcao funcional.

Regra coordenada permite rebaseline quando causa integrada e identificada,
render inspecionado antes e paths listados. Os tres requisitos foram conferidos:

| Diferenca observada | Causa integrada em d784462c1 |
| --- | --- |
| Limpar app/modulo e controles em cada tela; deslocamento da matriz | 8ac73c48c, bulk-select profile permissions, com teste funcional |
| Texto de revisao MFA passa a indicar gate formal do MVP | 9d3efce26, correcao da politica ADR0019; nenhum MFA novo |
| Busca na navegacao, espacamento e estado ativo da arvore | 7f918d72af, restructure navigation menu, com testes de navegacao |
| Marca Coelo/chevron e altura do cabecalho mobile | d9232a94d, finalize structures dev experience |
| Subtitulo mobile deixa de truncar e ocupa duas linhas | 057aad8f9, maxLines/overflow dependentes de compact |
| Fundo mobile usa surface | d8800300d, release instituicoes UI, Scaffold.backgroundColor |
| Botao de bug ausente sem callback real | ad558c6f9, guarda onBugReportSubmitted no header |

`git merge-base --is-ancestor <cada causa> d784462c1` retornou0 para as sete.
Nao foi atribuida a c4a7feff8 a quebra de linha: o blame focal identificou
057aad8f9 como causa exata. Nenhuma deriva escura sem origem foi absorvida.

O pai abriu cada par master/atual:375 claro, editor1440 escuro e revisao1440
escuro. Campos, acoes e texto ficaram legiveis; rodape preservado; nao houve
overflow observado. Antes de regenerar, os renders inspecionados ja estavam
publicados em current-visual/. Os PNGs regenerados sao byte-identicos a eles.
Paths e SHA256 completos em `golden-reconciliation.json`:

- apps/superadmin/test/features/access_profiles/presentation/goldens/access_profile_form_light_375.png
- apps/superadmin/test/features/access_profiles/presentation/goldens/access_profile_editor_dark_1440.png
- apps/superadmin/test/features/access_profiles/presentation/goldens/access_profile_review_dark_1440.png

Atualizacao restrita ao nome exato do teste; depois, comparador executado sem
--update-goldens. Logs `golden-update.txt` e `golden-reconciled-green.txt`.
O resultado substitui F1 anterior por P1 (tres imagens), sem somar o rerun:
formulario18P/0F; grupo396P/0F/120U, com preparacao7P separada.
Outros testes de golden do diretorio nao foram executados nem certificados.
Sem mudanca de codigo de produto ou nova certificacao FE/BE/E2E.
