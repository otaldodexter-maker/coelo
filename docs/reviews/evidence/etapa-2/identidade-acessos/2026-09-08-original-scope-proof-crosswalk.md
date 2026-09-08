---
title: "E2E 1 — confronto único do escopo original com provas locais"
source: "Prompt operacional E2E 1; pedido nominal do Coordenador após 84a42e7b; rastreador integrado; código/testes da branch; reviews account_review e realm_audit"
status: "local-review; model-write-followup-reserved-and-corrected-locally"
generated_at: "2026-09-08"
---

## Corte e resultado

Base 84a42e7b, branch codex/e2e-identidade-acessos. Confronto estático único,
sem repetir suites, executar rede/SQL/Docker ou alterar produto. As provas
citadas são históricas e delimitadas nos respectivos MDs, não novas execuções.
Somente Superadmin; não assumir outras verticais. Rastreador oficial e
reservas permanecem sob o Coordenador. Nomes de arquivo abaixo ficam sob
`apps/superadmin/test/`, salvo indicação contrária.

Não foi encontrado novo defeito local demonstrado em Auth ou Usuários READ.
Foram encontradas duas hipóteses discriminantes de RED em writes de Modelos,
que ficaram fora da corretiva READ. Após este confronto, o Coordenador concedeu
reserva nominal do consumidor. Ambas foram reproduzidas e corrigidas no
follow-up `2026-09-08-models-write-envelopes.md`. A matriz abaixo preserva o
corte diagnóstico anterior; não significa habilitação ou prova produtiva.

| Ação do escopo | Prova local existente | Primeiro impedimento / próxima prova |
|---|---|---|
| auth.login | Login action e app/router/login_remount_sdk_test.dart: negação, single-flight e sessão vencedora | Auth N01/provedor: login e restauração reais com origem operacional comprovada |
| auth.recover / auth.reset | Recovery SDK, actions, view models e telas: negativo, processamento, callback e dispose | Link real entregue/consumido, senha persistida, reload; execução nominal Auth |
| auth.logout / account.logout | Logout action e navigation_environment_logout_test.dart: falha, sucesso e navegação limpa | Revogação no provedor, rejeição de token antigo e nova sessão/reload |
| account.sessions; revogação/troca de realm | superadmin_session_test.dart e superadmin_auth_scope_test.dart: revisão, bootstrap tardio, cache e recovery | Revogação server-side mantendo JWT nominal e observação pelo cliente; não equivale a sessão inexistente |
| auth.mfa / account.mfa / internal-users.mfa | Guards e erros tipados preservados; AAL1 vigente do MVP | Não implementar AAL2 pelo rastreador histórico; qualquer fluxo MFA adicional exige gate vigente e reserva |
| account.profile — ler/editar | account_routes_test.dart mantém 503; controller/tela locais cobrem erro/retry e troca de identidade | Capacidade self, contatos/projeção, ausência de cadastro e allowlist self-edit; proposta ce893afe não é wiring |
| account.profile — avatar | Testes locais de domínio/tela, crop e limpeza de draft | Hook/gateway E2E3, tickets privados, negação/purge e composição de Conta; Image.memory não prova R2 |
| account.settings / account.theme | Controllers/tela/composição: fila, ABA, erro/retry; 40d755b5 registrou SharedPreferences real após reload no browser | Regressão de destino sob sessão real; não inventar persistência Supabase para preferência local |
| internal-users.list e abertura do detalhe | Repository, directory/detail pages e rotas normais: capability, 401/403, cache antigo, retry, ID e troca de contexto; Users49 48 TAP | Runtime Users49 com seed/janela Eng1, depois produção e visual; candidato b6238e5a ainda não executado |
| internal-users.edit / internal-users.suspend | Contratos update/status e negativos em testes/fixture; rotas produtivas continuam somente READ | Reserva de composition root de mutação e prova persistida; não transformar catálogo READ em autorização de writes |
| internal-users.create e convites/replacement | Fake e rejeição no repository produtivo | Decisão OQ039 e pacote nominal; demonstração não equivale a Auth/convite real |
| access-profiles.list | 84a42e7b: contrato consumidor; Auth47: ACL-before-contract; revisão de sessão nas rotas | Escopo institution em revisão Eng2, corretiva nominal/ACL/contagem/replay e runtime |
| access-profiles.detail | Detalhe/rotas cobrem negação, stale e descarte de dados | Reader/helper legado e cadeia backend própria; list não corrige detail |
| access-profiles.create / edit / delete | Testes de formulário, encaminhamento e continuidade após dispose | Pacote interno de comandos/receipts; mesmo State e save em voo não estão comprovados; reserva necessária |
| access-profiles.assign | Domínio/SQL possuem atribuições; interface cliente não expõe comando assign/link/unlink | Contrato e ligação produtiva nominal; não inventar API/grants |
| Modelos — list/detail/catalog | Models50 38 TAP; READ envelope, epochs e rotas; sem grants extras | Runtime Models50 e catálogo domain-only pendente; READ não comprova CRUD |
| Modelos — create/update/duplicate | Teste atual usa receipt cru, não envelope SQL | Hipótese M-W01 abaixo, reserva consumer writes solicitada |
| Modelos — delete | Teste atual confere parâmetros, não negação envelopada | Hipótese M-W02 abaixo, reserva consumer writes solicitada |
| Capabilities/realm/anti-escalation e P0 RLS | Negativos Users/Models nominais, ACL Profiles RED, clientes fail-closed | Eng1 detém pacote três tabelas; demais grants/receipts/readers exigem fatia e replay, nunca habilitação em lote |

## Hipóteses novas, ainda não executadas

M-W01: `SupabaseAccessProfileRepository.createModel/updateModel/duplicateModel`
passam `_modelRpc` diretamente para `_modelFromReceipt`, que lê `model` no
topo (lib/features/access_profiles/data/supabase_access_profile_repository.dart
173–216 e 325–326). O wrapper SQL 20260901193000 chama
access_profile_model_call; a implementação 20260901170731:1069 retorna
`{ok:true,data:result,error:null}`. Um receipt válido envelopado deve resultar
no modelo; a leitura atual tende a TypeError por model null. Teste existente
supabase_access_profile_model_repository_test.dart:66 fornece payload cru.

M-W02: deleteModel apenas aguarda `_modelRpc` e ignora o corpo. O mesmo helper
SQL retorna envelope de erro, inclusive SAI_PERMISSION_DENIED, sob HTTP200.
Hipótese: Future termina com sucesso apesar da negação. RED nominal deve
exigir AccessProfileUnauthorizedException e ausência de sucesso no consumidor.
Essa constatação não prova exclusão indevida no banco: o problema é falso
sucesso no cliente. Concorrência SAI_CONCURRENT_CHANGE também precisa mapping
tipado, sem exibir mensagem técnica/crua do backend.

Reserva pedida: apenas consumidor create/update/duplicate/delete e seus testes,
sem SQL/grants/router/shell/import/export/Conta. Import/export geral permanece
pós-MVP; métodos/testes históricos não autorizam ativar essas ações.

## Limites e encaminhamento

Goldens Usuários/Perfis continuam vermelhos nas rodadas já registradas; suas
diferenças compartilhadas não autorizam rebaseline ou alteração do DS/cabeçalho.
Runtime atual prova reentrada de rota quando executado, não reinício do app;
fase membership-revoked termina antes da UI. Esses limites são provas faltantes,
não falhas locais reproduzidas neste confronto.

Reviews independentes: account_review para Auth/Conta/settings/mídia e
realm_audit para Perfis/Modelos. Root conferiu Users READ/composition e o
encadeamento estático SQL/cliente das hipóteses. Nenhuma ação promovida a
Front-end verified, Back-end done ou verified-e2e. Gate de memória no-op:
sem nova decisão de produto aprovada. O follow-up M-W01/02 registra o RED/GREEN
posterior; os demais impedimentos seguem seus executores/decisões.
