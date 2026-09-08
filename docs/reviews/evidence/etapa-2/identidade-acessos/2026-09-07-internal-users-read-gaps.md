---
title: "Usuários internos — gaps nominais do payload de leitura"
source: "Revisão estática root/realm_audit da migration 20260901210000; escopo original Identidade e Acessos"
status: "local-green-replay; production-and-e2e-pending"
generated_at: "2026-09-07"
updated_at: "2026-09-08"
---

## Contrato deste registro

Registro cronológico: os trechos de diagnóstico e espera abaixo preservam o
estado de sua coleta. O resultado vigente está no fechamento local a seguir.

## Fechamento local — Users49

Engenheiro 1 executou Auth45 + migration Users + corretiva `27a0c3bb` + dois
preflights (49 arquivos), preservando as fixtures de 45 e três asserts:
**48/48 pgTAP PASS, exit 0**. Evidência lida integralmente em
`docs/reviews/evidence/etapa-2/engenheiro-1/users49-green-2026-09-07.md`, commit
`36964bbb937b7ea4c77b3a4e2b1d6ffbd631dfcd`, branch do executor.

Execução `2026-09-08T02:53:50.8848955Z`, identidade local
`coelo_safe_970e4991ff92475c951caa4a551c2`; cleanup independente
`2026-09-08T02:55:41.7082440Z`: zero recursos próprios e staging ausente,
recursos históricos preservados. Hash LF da corretiva conferido na prova:
`1cddea65cd5394c727ae56d7c668a2a6e1a7783527c6703f49a9d04f4214e34a`.
Review independente do executor sem bloqueantes. Nenhuma execução Docker ou
SQL por esta frente. Não comprova produção, edição/convites, concorrência de
versão, toda a paginação ou integração visual/E2E.

## Diagnóstico inicial preservado

Somente evidência, separada da fixture nominal de 45 asserts. Não altera SQL,
RPC, grants, produção ou decisões de produto. Os achados foram enviados ao
Coordenador; nenhum teste RED destes dois casos foi executado nesta frente.

## Leitura minimizada incompleta

Em `packages/coelo_database/migrations/20260901210000_superadmin_internal_users_directory.sql`,
a projeção em linhas 131–133 mascara `identity.professional_email` quando
`p_include_sensitive=false`, mas a linha 178 inclui o mesmo endereço integral
em `invitation.email` incondicionalmente. A lista chama a projeção com `false`
(linha 369). Logo, o payload inteiro não preserva a minimização anunciada.

Critério para correção nominal: e-mail minimizado em todas as ramificações do
payload da lista; detalhe continua sujeito à autorização interna. O teste
deve verificar o JSON completo, não somente `professional_notes` ou um campo.

## Elegibilidade divergente entre lista e projeção

A CTE `filtered` (linhas 343–361) exige identidade, perfil e membership, mas
não auth-link. A projeção usa inner lateral join de auth-link (linhas 199–203).
Inferência do SQL: identidade com perfil/membership sem auth-link pode entrar
na paginação e no total, enquanto sua projeção retorna NULL, produzindo
`items:[null]`. Isso viola o formato de registros esperado pelo adapter Dart.

Critério para correção nominal: alinhar elegibilidade, total e paginação com
os requisitos da projeção, sem backfill ou criação de vínculo inventados.
O teste deve incluir registro parcial e comprovar ausência de itens nulos,
sem ocultar usuários completos permitidos ou introduzir vazamento de escopo.

## Fora destes dois achados

`invitation.status='accepted'` e `attempts=1` são derivados do auth-link na
projeção atual; isso não demonstra envio ou aceite de convite e não fecha
OQ-039. Versão de update/status e motivo de auditoria permanecem recortes
separados. Nenhum desses gaps autoriza habilitar mutações produtivas agora.

Não houve regra nova de produto para projetar em Knowledge. A fonte técnica
canônica permanece a migration, com eventual correção forward-only nominal.

## Corretiva nominal — 2026-09-08

O Coordenador informou RED real do teste minimizado: 1 PASS e 2 FAIL, sem
erro de ACL, com cleanup; Users45 permanece uma evidência separada. A execução
e a prova de teardown pertencem ao Engenheiro 1, não a esta frente.

Criada pelo CLI 2.116.0 e movida sem trocar o timestamp para a fonte canônica:
`packages/coelo_database/migrations/20260908021644_superadmin_internal_users_read_minimization.sql`.
SHA-256 UTF-8/LF: `1cddea65cd5394c727ae56d7c668a2a6e1a7783527c6703f49a9d04f4214e34a`.

Somente duas funções recebem CREATE OR REPLACE: projeção aplica a máscara
também em `invitation.email` quando não sensível; listagem exige existência de
auth-link antes de contar/paginar. Não filtra status do auth-link, preservando
usuários completos suspensos/revogados. O ramo sensível, as assinaturas, os
filtros, a ordenação, a auditoria, os envelopes e os ACLs existentes ficam
inalterados. Nenhuma migration histórica foi editada.

Revisão independente `account_review`: sem bloqueios estáticos, comparação
confirmou somente esses deltas. `git diff --check` passou. GREEN SQL ainda
pendente do replay serializado nominal; não houve SQL, Docker, DML, deploy ou
alteração remota nesta frente. Não representa E2E nem habilita edição/convites.
Gate de memória: no-op; restaura o contrato de minimização já existente.

## Pacote de teste separado e inventário remoto

Preparado `packages/coelo_database/supabase/tests/superadmin_internal_users_read_minimization_test.sql`,
com três asserts: precondição de leitura autorizada pelo Owner interno em AAL1;
consistência de itens/total diante de identidade sem auth-link; e ausência do
e-mail integral em qualquer ramificação do JSON da lista. A fixture é sintética
e transacional, com rollback. Não altera a fixture Users45 nem migrations.
Os dois negativos são RED esperado por inspeção, ainda não RED executado.
Replay permanece exclusivo do Engenheiro 1, sujeito ao pacote nominal coordenado.
Revisão independente `realm_audit`: sem bloqueante estático; `plan(3)` coerente.
O total esperado pressupõe baseline descartável sem outros perfis internos,
como Users45; este teste não deve ser executado contra produção.
Follow-up da revisão central: a RPC e a captura de `current_user` executam
sob `authenticated`; `RESET ROLE` ocorre antes dos três asserts pgTAP.
O primeiro assert verifica o ator capturado, sem grants novos para executar TAP.

Consulta somente de catálogo ao projeto `evvbomzejfijozbtgvpt`, em
`2026-09-08 00:57:09.136813+00`, retornou ausência (`to_regprocedure IS NULL`)
das cinco assinaturas: lista, detalhe, perfis, update e change_status de
usuários internos. Não foram chamadas RPCs nem lidos dados pessoais; não houve
escrita remota. Logo, testes locais de cliente não demonstram disponibilidade
produtiva desses contratos, e o gate E2E permanece aberto.
