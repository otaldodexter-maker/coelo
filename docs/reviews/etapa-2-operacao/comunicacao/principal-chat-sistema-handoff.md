---
title: "Handoff — grupo principal-chat-sistema, Rodada 4"
grupo: "principal-chat-sistema"
branch: "work/etapa2-r04-principal-chat-sistema"
generated_at: "2026-09-11"
status: "fechado na mini-revisão das 04:00 de 11/09 (retomada coelo-11 após o reinício de 00:27)"
---

# Handoff — principal-chat-sistema (R04)

Base: `origin/dev 836c63215`. Tudo está na branch publicada; o JSON do grupo
(revisão 12 em diante) é a fonte por `action_id`. Este handoff resume em meia
página.

## Feito nesta rodada (com prova)

**Pacote 1, em produção desde 22:24 (lote 9, aplicado pelo coordenador).**
Seis candidatos em `candidatos/principal-chat-sistema/`: fundação do Agora
(190300), hardening de audiência (190400), expiração (190500), Agora em R2
(190600), Acontece em R2 sobre `media_assets` (190700) e retirada do Acontece com
feed direto e misto expondo `can_withdraw` (190800). pgTAP no descartável:
8 arquivos, 194 casos, PASS. Depois disso, `load_now_draft`,
`expire_due_now_publications` e `withdraw_happens_post` existem em produção e
negam qa-r03 com 42501 (fail-closed).

**Pacote 2, pronto (190900).** Revoga EXECUTE de `anon` nas 199 funções
security definer de `public` e no privilégio padrão que fazia toda função nova
nascer com `anon`. pgTAP 7/7; suíte do grupo 9 arquivos, 201 PASS.

**Chat, ponta a ponta com a fixture sintética do realm-interno.** Criar grupo
(P8) na UI: diálogo com instituição, nome e membros do diretório de Pessoas,
repositório sobre `superadmin_chat_create_group_v2`, `CHAT_MEMBER_INVALID`
mapeado, cabeçalho com o botão também no estado vazio. Prova em produção pelas
mesmas RPCs do cliente: grupo criado, replay idempotente, inbox lista após
reload, membros, mensagem com recibo, negativas de tenant e de membro. Pela
tela real: inbox mostra o grupo, conversa abre com "Lida por 0 de 2", mensagem
enviada pela UI persiste e volta após reload (capturas 20 a 26).

**Cliente.** WIP da Fase 0 fechado (launcher "Mensagens" com contagem e
iniciais, círculo claro no mobile, ARQUIVO nos cards de Cardápios e Planos,
Duplicar de volta no menu do card); véu do Destaque em orange950 a 16%; D3 sem
"prévia" em 14 textos e no Catálogo; Agora envia mídia pelo envelope R2;
Momentos com a composição larga aprovada (moldura a partir de 840, aside a
partir de 1200, preto preenchendo a largura) e mídia inteira sobre o preto.
Goldens regravados após observação: launcher 5, Cardápios 5, Planos 8, Para
você 8, Chat 6, Momentos 11, Importações 1. `flutter analyze lib test`: sem
problemas. Erro 409: imagens candidatas e página lado a lado para o Owner.

**Rota real com `qa-r03@coelo.me`** (build de release em `127.0.0.1:3000`;
`localhost` resolve para outra frente em `[::1]`): login, shell, navegação,
reload com sessão, mobile 375 com Bug, Sair confirmado e reload sem sessão.
Capturas em `evidence/etapa-2/r04-principal-chat-sistema/rota-real/`.

## Aberto, com o primeiro gate

| Pendência | Primeiro gate |
| --- | --- |
| Cardápios, Acontece, Momentos, Agora, Para você, Perfil na rota real | P22 (coordenador): ponte de ator; hoje "Acesso não autorizado" / "não conseguimos validar seu contexto" |
| Criar grupo pela UI até o fim | P22: o diretório de Pessoas nega qa-r03; a RPC já está provada |
| Perfil: Acompanhar/Seguidores/Seguindo (R do Owner) | D1 (`follow_links`) do grupo acessos-pessoas, retido por AP-D1-AAL; FOTO: pergunta P-FOTO ao Owner |
| Galeria mobile do Acontece | redesenho "mais Instagram" ainda sem direção confirmada |
| Curtir/comentar no Acontece | não existem no banco; visíveis e inertes (D3) |
| Deploy de `happens-media` e `now-media` | coordenador (secrets `COELO_R2_*`) |
| Agendador da expiração do Agora | coordenador (pg_cron/worker) |
| Coletor de órfãos no R2 para Agora/Acontece | pós-MVP |
| Erro 409 como golden oficial | decisão do Owner (P26) |

## Achados que valem mais que os pacotes

1. `anon` executava 199 funções security definer de `public` por causa do
   privilégio padrão do Supabase; as migrations só revogavam de `PUBLIC`.
2. `supabase db reset` com as 45 migrations não reproduz produção em projeto
   novo (170100 exige o catálogo antes do seed); virou regra no README.
3. Presença do nome não prova o corpo: `list_visible_happens_feed` constava
   1/1, mas em produção não tinha retirada nem `can_withdraw`.
4. Na porta 3000 há duas frentes: `127.0.0.1` e `[::1]`. Capturas contra
   `localhost` podem ser de outro app.

## WIP não commitado

Nenhum. Projeto descartável `coelo_baseline_pcs` (portas 623xx) pode ser parado.

## Retomada 02:00-04:00 de 11/09 (coelo-11, depois do reinicio da maquina)

Fonte por `action_id`: JSON do grupo, revisoes 14 a 17, e
`evidence/etapa-2/r04-principal-chat-sistema/deltas-r04.json`.

**Fechado com prova.** Launcher/Decisao 7: a flag `showChatLauncher` da pagina
embutida chega ao shell hospedeiro; `SuperadminFormFrame` suprime o balao em
qualquer largura enquanto montado; Agora aberto, Momentos aberto e as tres telas
de publicar ficam sem balao pelo destino; Cardapios, Planos, Circulares e Avisos
passam a flag (7322260c5, 1e34eb9f4, dcfcb9e41; teste 12/12, suite do shell
124/124). Cardapios abre na rota real para `qa-r03` depois da ponte de ator e o
reload mantem (capturas 51 e 52 em `rota-real-r04b/`). O dialogo Criar grupo do
Chat carrega instituicao e pessoas de producao pelo diretorio (54 a 61, 67a).

**Aberto, com o primeiro gate.** As cinco telas do Principal falham porque
`public.list_my_principal_contexts` nao existe em producao (PostgREST PGRST202):
a historica 20260901161700 nunca chegou a baseline. Candidato entregue em
`candidatos/principal-chat-sistema/20260910191000_principal_runtime_contexts_baseline.sql`
(pgTAP existente no repositorio, nao rodado nesta retomada). Depois de aplicar,
`qa-r03` ainda precisa de `institution_membership` ativa para ter contexto
(P25, pergunta ao Owner). Criar grupo pela UI nao fechou (dialogo fechou sem
grupo novo, 67b/67c). CRUD de Cardapios pela UI e goldens das tres listas nao
foram tocados.

**Ambiente que funcionou.** `flutter build web --release -t test_driver/qa_main.dart
--dart-define-from-file=.env.local`, servido com fallback de SPA em
`127.0.0.1:3009`; Chrome com `--remote-debugging-port` e `--use-angle=swiftshader`;
login e `enter_text` pelo `qa_drive.dart`; cliques por CDP. Sem o `.env.local`
o app morre em `Supabase.instance` antes de registrar `$flutterDriver`.
