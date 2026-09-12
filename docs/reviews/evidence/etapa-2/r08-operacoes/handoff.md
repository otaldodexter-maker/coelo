---
title: "Handoff R08 — Operações"
source: "R08-prompts.md; R08-backlog.md; spec 051; inspeção focal de código"
status: "em andamento"
generated_at: "2026-09-12"
---

# Recorte

Etapa 2 → `apps/superadmin` → Operações → Conta, Suporte, Catálogo, Planos,
Help Center e estados informativos de Auditoria/Importações.

## Checkpoint inicial

- Sessões e Suporte preservam a evidência E2E válida da R06. Uma nova
  revogação só será feita com o usuário sintético próprio e o slot Chrome.
- `plans.assign` permanece bloqueado por decisão: a spec 051 permite somente
  leitura de vínculos de instituição; não se confunde com SMTP P51 nem com
  arquivar/restaurar (`plans.activate`).
- A rota protegida `governanceCatalog` passa `localPreview: true`, impedindo o
  destino HTTPS configurado de ser usado. O teste RED já exige o fallback do
  destino real e exclusão do painel de preview; aguarda a fila Flutter do C0.
- Os dois goldens A de Help Center aguardam a mesma fila para comparação e
  regravação, sem promoção de estado por aprovação visual.

## Catálogo — correção focal

O teste de rota foi escrito antes da alteração e falhou como esperado: a rota
autenticada mostrava `catalog-local-preview`. A causa era a passagem indevida
de `localPreview: true` para `governanceCatalog`. A alteração removeu somente
esse argumento; a rota de desenvolvimento continua explicitamente em preview.

`flutter test test/app/router/catalog_routes_test.dart --concurrency=1`
terminou em **4/4 PASS** após a correção. O teste verifica que a rota protegida
não exibe preview e apresenta o fallback para a origem HTTPS configurada.
Isso não comprova que o host externo foi publicado; `catalog.publish` continua
com esse gate aberto.

## Help Center — dois A

Os arquivos `help_center_empty_light_1440.png` e
`help_center_empty_dark_375.png` foram comparados antes da regravação. A
comparação inicial falhou em 4,52% (light 1440) e 90,85% (dark 375). As imagens
de diferença mostram a atualização da shell/navegação e a composição mobile
vigente, não uma regra nova do Help Center. Ambos constam como **A** nominais
na decisão R07 do Owner, portanto somente esses dois PNGs foram regravados.

O mesmo teste focal passou após a regravação: **1/1 PASS**. Esta é prova de
aprovação visual; não promove Front-end, Back-end ou E2E.

## Revisão independente — Circular G6

Revisão somente leitura do SHA atual
`origin/work/etapa2-r08-publicacoes-agenda` `d48525b04` contra spec 037 e ADR
0034, decisão 20: o host produtivo ainda seleciona apenas o primeiro
`CircularMediaBlock` e esconde **Adicionar mídia** depois dele. Isso impede o
segundo bloco de mídia necessário a `texto → mídia → pergunta → texto → mídia`;
vários arquivos no mesmo bloco não corrigem a ordem entre blocos. A observação
anterior sobre prévia reduzida foi retirada: `_previewBlock` é iterativo neste
SHA e `_bodyText` não está presente. O limite agregado de 10.000 e os cards
ordenados de perguntas permanecem alinhados. O único achado foi corrigido junto
ao C0 para a G6; nenhum arquivo da frente foi editado.

## Revisão independente — Forms G3/G5

No candidato `444ac0246d7eadd62527990492f9797285594bec`, a FK
`media_bindings_item_id_fkey` é recriada como `ON DELETE RESTRICT DEFERRABLE`.
Em PostgreSQL, `RESTRICT` é verificado imediatamente; portanto o `SET
CONSTRAINTS ... DEFERRED` não permite apagar a árvore de itens durante o
replace. O `DELETE FROM form_sections` falha antes de reinserir o mesmo
`item_id`, bloqueando o caso de salvar texto depois da imagem. O achado foi
encaminhado ao C0. A revisão confirmou que o ID é limitado à mesma working
version e que `media_context` não vaza `object_key`, URL, ticket ou segredo.
Nenhum SQL foi executado ou editado.

O follow-up `28625efaf51755f9ba8d4c6c103fafc06a58b2df` corrige os dois pontos
originais: usa `NO ACTION DEFERRABLE` e passa a instituição real aos gates. A
revisão da composição identificou outro ponto antes do GREEN: `form_get_editor`
consulta o formulário antes da autorização e retorna `form unavailable` para
ID ausente, mas `forms.read required` para um formulário existente de outra
instituição. Como `public.form_get_editor` delega diretamente, o erro permite
enumerar existência cross-tenant. Foi pedido um erro externo uniforme e teste
negativo do editor. `item_id` continua limitado à mesma working version e
`media_context` permanece sem chave/URL/ticket.

## Gates externos

Chrome continua reservado a G0 e E2E/SQL não estão liberados. Nenhuma sessão
alheia foi afetada; nenhuma exportação, importação, job, parser ou arquivo novo
foi criado.

## Sessões da Conta — prova API condicionada

Com a credencial privada do QA (não registrada), foram abertas duas sessões
novas A/B e A chamou `superadmin_account_sessions_list_v1`: logins 200/200 e
listagem 200, porém com **3** sessões vivas. Como a condição autorizada exigia
exatamente A/B, `logout?scope=others` não foi chamado. A e B receberam somente
`logout?scope=local` (204/204); a sessão preexistente foi preservada. Não há
prova de revogação, token rejeitado ou reload nesta rodada.
