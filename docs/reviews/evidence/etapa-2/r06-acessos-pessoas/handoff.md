---
title: "Handoff - grupo acessos-pessoas, Rodada 6"
round: "E2-R06-20260911"
base: "origin/dev ca60b096b na abertura; merge de fcdded416 (lote 49)"
branch: "work/etapa2-r06-acessos-pessoas"
status: "revisao de 10 minutos (T0+2h = 21:36)"
generated_at: "2026-09-11"
timezone: "America/Sao_Paulo"
---

# Handoff - acessos-pessoas (R06)

Recorte: people, access_profiles, access_models, invites, internal_users,
students (32 acoes; 11 em E2E na abertura). Canal oficial:
`docs/reviews/etapa-2-operacao/comunicacao/acessos-pessoas.json` (revisoes 138
a 141). Deltas por action_id: `deltas-r06.json` (18 entradas, ensaiadas com
`apply-tracker-delta.cjs` + `validate-trackers.cjs` PASS FE 147 / BE 132 /
E2E 114 e revertidas; o coordenador aplica). Capturas em `capturas/`.

## Como a prova foi feita

Build web de `test_driver/qa_main.dart` (ee35cce3a, `.env.local` copiado do
checkout principal) servido por `serve.py` em `127.0.0.1:3016`; um Chrome CDP
(porta 9416, SwiftShader, `--user-data-dir` proprio da frente). Login pelo
`qa_drive.dart login` com `QA_EMAIL`/`QA_PASSWORD` lidos do arquivo de
credencial. **Achados de metodo:** o `Input.dispatchMouseEvent` do CDP so e
reconhecido pelo Flutter web com `buttons: 1` no `mousePressed`; os comandos
do driver (`tap`, `enter_text`) funcionam chamados por `Runtime.evaluate`
sem esperar a resposta (o processo Dart do `qa_drive cmd` trava esperando);
`tap` por texto em menus com opcoes repetidas (E-mail) acerta o Text errado,
usar o clique por coordenada. pgTAP no descartavel `coelo_acessos_r06`
(portas 616xx; Storage ligado porque sete migrations dependem de
`storage.objects`; baseline + seed + as 141 migrations da ordem real incluindo
o lote 49 + os tres candidatos), encerrado no fechamento.

## Pacotes SQL (candidatos/acessos-pessoas, prontos para aplicar nesta ordem)

| Pacote | Prova |
| --- | --- |
| 20260911170500 internal_user_handles_v1 (P46 = A: @ do usuario interno pela pessoa de servico; a ponte 220400 da o @; RPC superadmin_internal_user_service_person_v1) | internal_user_handles_v1_test 12/12; person_handles 22/22; institution_people_handles 4/4; principal_context_handles 14/14 |
| 20260911170600 institution_system_model_delete_v1 (P45 = B: modelo de sistema de Admin excluido so pela hierarquia de plataforma) | institution_system_model_delete_v1_test 7/7; institution_profile_system_model_create 8/8 |
| 20260911170700 people_identity_lookup_v1 (people.create: resolvedor de identidade por e-mail/telefone/CPF/@/nome, sem gravar o valor) | people_identity_lookup_v1_test 11/11 |
| 20260911170800 internal_user_create_v1 (internal-users.create em dois tempos: authorize com o token do operador; for_worker so service_role) | internal_user_create_v1_test 9/9 |

## Cliente (commits 7f13ee42d, 316d1fd2c, 8b40c80cd, d58cc041a)

- `SupabasePersonIdentityRepository` ligado no `createSuperadminAuthScope`
  atras de `enablePersonHandles`: `people.create` deixa de ser fail-closed
  quando o 170700 estiver em producao (ate la, PGRST202 vira "indisponivel").
- Perfis (P45): modelo de sistema de Admin mostra Editar modelo, Excluir e
  Criar a partir deste modelo; modelo de plataforma continua somente leitura
  (teste novo em access_profile_system_models_test, 4/4).
- Usuarios internos (P46): detalhe mostra a secao Identificador (@) da pessoa
  de servico (`PlatformUserServicePersonResolver` + `PersonHandleSection`),
  oculta quando a RPC 170500 nao existe.
- Usuarios internos (create): `create` chama a Edge Function
  `internal-user-create`; rota `/internal-users/new` aberta para quem pode
  gerir; card Criar no diretorio (V-11); sem a funcao, indisponibilidade honesta.

## O que fechou na rota real (sessao qa-r06-acessos)

- invites.create/detail/revoke: convite emitido pela tela (a5496b70), detalhe
  com linha do tempo, revogacao confirmada; reload mantem.
- students.list/edit/transfer/revoke/link: vigencia, transferencia para a
  turma sintetica nova, revogacao e vinculo de volta pela tela; reload mantem.
- internal-users.list: os 8 internos reais; detalhe abre pelo card.

## Gates abertos

| Aberto | Primeiro gate |
| --- | --- |
| invites.resend pela UI | Reenviar so aparece para convite expirado (regra do v2); producao nao tem convite expirado: fixture sintetica com expires_at no passado (pacote) ou esperar 48 h |
| internal-users.edit/suspend pela UI | edit: diretorio lento na segunda carga (Chrome com 1,5 GB livres); suspend: suspender qualquer qa-r06 derruba a sessao de outra frente; precisa de um interno sobressalente |
| internal-users.create | cadeia pronta sem deploy: RPCs 170800 (pgTAP 9/9), Edge Function `internal-user-create` (deno check), cliente e rota `/internal-users/new` ligados; gate = deploy pelo coordenador + P51 (SMTP para definir a senha) |
| access-profiles.edit E2E, assign, delete; access-models.edit/duplicate pela UI | build com 0aeb9b729 existe (ee35cce3a); faltou tempo de Chrome; delete de modelo de sistema depende do 170600 em producao |
| people.create/edit pela UI | 170700 em producao + build novo com 7f13ee42d |
| @ na tela de Alunos | nao iniciado (o @ da crianca ja e editavel no detalhe de Pessoas; a tela de gerir aluno nao mostra o @) |
| V-11 (card Criar sempre presente em Perfis e Usuarios internos, sem dados de demonstracao) | nao iniciado nesta rodada; Usuarios internos hoje nao mostra o card Criar |

## Dados sinteticos desta rodada

- invitations a5496b70 (revoked, e-mail sintetico, instituicao 9f04...0010);
- groups 1a247741 "Turma QA R06 Transferencia" (unidade cce78909, instituicao
  d0c4...0001);
- vinculos da crianca d0c4...0003: transferida/revogada na Unidade QA R05
  Transferencia e vinculada de volta a Turma QA R04 Estrutura (368a5cea), sem
  data de fim (antes 2026-12-15).

## Chaves criadas

Nenhuma. Nenhum segredo, token ou valor de Vault foi criado nesta frente.
