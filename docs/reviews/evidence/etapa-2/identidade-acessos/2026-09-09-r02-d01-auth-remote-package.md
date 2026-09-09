---
title: "R02 D01 — pacote nominal de prova Auth"
source: "R02-20260909/prompts/D01.md; R02-20260909/CONTRATO.md; decisions/0019-superadmin-internal-identity.md; código Auth integrado"
status: "executable-nominal-candidate; offline-tests-pass; mutations-not-executed"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Pacote D01-AUTH-PROOF-R02-v1

Etapa 2 → apps/superadmin → Auth → Login, Recuperar senha, Redefinir senha,
Sair → `auth.login`, `auth.recover`, `auth.reset`, `auth.logout`.
Provedor: Supabase Auth/Postgres e SMTP configurado. Cloudflare não participa.
Nenhum envio, alteração de conta/senha ou configuração remota foi executado.
A qualificação MCP em transação READ ONLY foi executada em 2026-09-09;
não equivale à prova funcional Auth/SMTP.

## Alvo nominal confirmado e qualificação executável

O MCP Supabase `list_projects` identificou `coelo`, ref
`evvbomzejfijozbtgvpt`, região `sa-east-1`, estado `ACTIVE_HEALTHY`.
`get_project_url` confirmou `https://evvbomzejfijozbtgvpt.supabase.co`.
Origem do app: `https://superadmin.coelo.me`; callback nominal:
`https://superadmin.coelo.me/reset-password`.

O harness `packages/coelo_database/scripts/r02-d01-auth-proof.mjs` não precisa
de dependências. A partir da raiz da worktree:

```powershell
rtk proxy node packages/coelo_database/scripts/r02-d01-auth-proof.mjs --local
rtk proxy node --test packages/coelo_database/scripts/r02-d01-auth-proof.test.mjs
rtk proxy node packages/coelo_database/scripts/r02-d01-auth-proof.mjs --sql
```

Resultados em 2026-09-09: modo local PASS, confirma apenas allowlist no TOML;
6/6 testes Node PASS, 0 falhos/ignorados/bloqueados/não executados. O SQL emitido
foi executado pelo MCP `execute_sql` no projeto nominal, em `BEGIN READ ONLY`:
RPC de contexto, auth links, memberships e `auth.sessions` presentes; papel
`operations` pronto; **0 usuários e 0 sessões** com o marcador deste pacote.
O delta SQL de colisão confirmou `reserved_ids_free=true` para os três IDs
planejados. Somente seu teste focal foi repetido depois desse acréscimo (1 PASS,
incluído nos mesmos seis IDs; não somar sete testes).
O UUID Auth acrescentado ao preflight foi conferido livre em consulta própria
READ ONLY; o teste focal de colisão também cobre esse quarto ID.
Nenhuma linha pessoal, token, senha ou email foi selecionado. O ref no SQL é
rótulo nominal; a seleção de projeto do MCP vincula a conexão efetiva.

Modo adicional executado contra produção, somente GET:

```powershell
rtk proxy node packages/coelo_database/scripts/r02-d01-auth-proof.mjs --remote-readonly
```

Esse modo exige `R02_D01_PUBLISHABLE_KEY` provisionada no ambiente pelo executor
sem impressão. Rejeita chaves secretas e usa somente GET `/auth/v1/settings`,
origem/ref fixos, redirects recusados, sem cookies, prazo de 10 segundos,
saída por allowlist e erros sanitizados. Não solicita senha/JWT. Settings
públicos não expõem allowlist SMTP/redirect; não inferir esses gates da resposta.
Resultado real: `emailProviderEnabled=true`, `signupDisabled=true`.
A chave publishable ativa foi descoberta por MCP, mantida apenas no ambiente
do processo e não impressa nem gravada no pacote.
Sessões e contexto ficam explicitamente `not-exercised`: chamar o bootstrap
real pode gravar auditoria e pertence ao pacote funcional autorizado.

## Base e limites

Base disponibilizada por D00: `56eb3f19de23e364ea5f7e4f73a6fbd9a851e230`.
Usar o SHA final integrado e registrar a revisão efetivamente testada.
Preservar R06/R07/I017, recovery confinado, single-flight e AAL1 da ADR0019;
não adicionar MFA ou usuários de Admin/Principal ao recorte.

O adapter já envia recuperação com redirect e atualiza a senha usando o token
da sessão de recovery capturado antes do await. Depois chama `signOut()`.
O gotrue 2.26.0 instalado define seu escopo padrão como `local`: a prova deve
medir a sessão encerrada, sem afirmar revogação global de outras sessões.
JWT antigo precisa ser negado pelo contexto/comando sensível que consulta
`auth.sessions`; a ausência do token no navegador, isoladamente, não basta.

## Pré-condições nominais ainda não preenchidas

D00 precisa registrar autorização vigente para este pacote exato, SHA/build,
janela e executor. O projeto já está identificado acima. A autorização
de Git da R02 não supre isso. Exigir persona interna sintética existente ou
provisionamento separado autorizado, IDs privados correlacionados, mailbox
controlada autorizada e responsável pelo cleanup. Não usar conta/senha do Owner como persona da prova,
email de terceiro ou endereço `example.invalid` para entrega real.

Conferir de forma sanitizada o provedor SMTP, origem HTTPS efetiva, allowlist
do redirect `/reset-password`, fluxo Auth e validade do link. O código constrói
o redirect a partir da origem do app em
`apps/superadmin/lib/core/config/superadmin_auth_scope.dart`.
Mudança de configuração não está incluída implicitamente neste pacote de prova;
se necessária, propor delta exato antes de aplicá-la. Nenhum token, senha,
cookie, URL de recovery ou credencial SMTP entra em Git, log ou screenshot.

## Recursos existentes reutilizáveis

- `packages/coelo_database/scripts/e2-r01-auth-personas.ts` exporta preparação
  de personas e exige snapshot/projeto/ownership; **não é CLI remoto pronto**.
  Seu pacote `C01-AUTH-PERSONAS-v1` e emails `example.invalid` não autorizam
  personas ou entrega SMTP para esta prova. Não alterar o pacote antigo para
  contornar essas restrições.
- `e2-r01-auth-personas-private.ts`, `e2-r01-auth-personas-local-sql.ts` e
  `e2-r01-auth-personas-ban-proof.ts`, no mesmo diretório, são peças existentes
  de vínculo/qualificação. I021/bridge continua dependência conforme tracker;
  não alegar que a mera presença desses arquivos qualifica produção.
- `packages/coelo_database/supabase/tests/superadmin_internal_auth_context_test.sql`
  contém negativas do contexto para reaproveitamento em ambiente local.
- `apps/superadmin/test/features/auth/domain/coelo_auth_recovery_sdk_test.dart`
  exercita SDK instalado com HTTP simulado. O delta D01 adiciona negativas
  inválido/expirado/reutilizado: nenhuma sessão de recovery, senha recusada,
  zero PUT/logout. Reutilizado consome o mesmo hash em outro cliente da fixture
  antes da negativa; validade e expiração são respostas simuladas, não relógio
  nem token real do provedor. Execução e resultado pertencem ao runner D01.

Comando local existente, a partir de `apps/superadmin`, somente pelo runner
serializado e quando houver causa de execução:

```powershell
rtk proxy flutter test --no-pub test/features/auth/domain/coelo_auth_recovery_sdk_test.dart
```

O modo SQL é executável e somente leitura. Os modos locais não substituem
autorização, mailbox controlada ou o fluxo real na UI normal.

## Recursos novos e mutações exatas propostas

Plano reservado documentalmente: `52edcfbe-adec-4614-b9a5-a10bc543379d`.
Preflight não encontrou recursos deste pacote; não reutilizar usuário
por coincidência de email. Proposta nominal: **uma conta interna sintética
não-Owner**, sem instituições, papéis, permissões, migrations ou buckets novos.
D04/D00 continuam responsáveis pelos vínculos; D01 não altera seus scripts.

| Recurso | Valor nominal / escrita proposta, somente depois da autorização |
|---|---|
| `auth.users` | Criar somente UUID `8d7a34f8-6230-4f43-82c3-45743d62ab96` pelo Admin Auth API, email da mailbox ainda a informar pelo Owner, senha gerada no secret store, confirmação administrativa explícita, estado inicial banido por 876000h, metadata privada `coelo_e2_package=D01-AUTH-PROOF-R02-v1`, `coelo_e2_plan=52edcfbe-adec-4614-b9a5-a10bc543379d`, `coelo_e2_persona=auth-proof`. Exigir ID devolvido idêntico e ownership antes dos vínculos |
| `superadmin_internal_identities` | Inserir somente ID `71b183d9-5591-41e9-bfff-90460f2d2ab1`, com ator de provisionamento correlacionado no recibo |
| `superadmin_internal_auth_links` | Inserir ID `7bd71321-05c0-412a-8ac7-3a38df859c6b`, identity acima, auth ID devolvido, status `active`, version 1; exigir ausência de vínculo em `person_auth_links` |
| `superadmin_internal_memberships` | Inserir ID `bf7a4fbb-149d-4442-a221-bfef921383ee`, identity acima, papel `operations` ID `0da9b079-60db-406a-9721-d829a074b9cd`, scope `platform`, instituição NULL, status `active`, version 1 |
| Auth funcional | Logins da conta sintética, restauração/refresh, até dois envios de recovery (válido/reutilizado e expirado), uma alteração de senha, logout e auditorias inerentes; nenhuma mudança de TTL/config SMTP/global |
| Cleanup | Tentar banir a conta por 876000h uma vez pelo Admin Auth API; transação terminal dos IDs link/membership para `revoked`, com timestamp/version/ator e auditoria; **DELETE somente em `auth.sessions` do UUID Auth nominal, revalidando email+3markers**, com cascade dos refresh tokens/claims de sessão. Preservar identity, credencial banida, fatores MFA e auditoria histórica |

O papel existente foi lido por MCP: `operations`, `active`, alcance máximo
`platform`. Essa escolha integra a proposta para aprovação, não confere
autoridade remota. Antes de provisionar, reler catálogo, colisões dos IDs/email,
ausência cross-realm e estado do plano. Vínculos são transação serializada por
D00/D04 com resposta de COMMIT comprovada; somente depois habilitar o fluxo UI.
Não tentar escrever essas tabelas usando `service_role`, que não tem grants.

Cleanup exige ID Auth devolvido + três marcadores privados acima + IDs nominais,
em cada comando; não usar email isolado, listagem global ou seleção por prefixo.
Não deletar `auth.users` referenciado por auth link/auditoria. Falha parcial:
registrar o último recibo confirmado, banir/encerrar somente a conta pertencente
ao plano e revogar apenas linhas nominais que existam; não reprovisionar nem
reenviar automaticamente após resposta ambígua. Provar sessão/contexto negados
após cleanup. Esta proposta contém mutações nominais; ainda não foram executadas.

Única informação pessoal externa ainda necessária: mailbox controlada e
identidade de teste que o Owner autoriza para essa conta distinta do realm
Admin/Principal. A decisão deve autorizar nominalmente a lista acima. D00
completa SHA/janela/recibos e coordena o pacote; não pedir ao Owner que descubra
o projeto, desenhe os recursos ou prepare os comandos técnicos.

## Executor nominal preparado, sem execução de mutações

`packages/coelo_database/scripts/r02-d01-auth-proof-executor.mjs` materializa
provisionamento e cleanup. Sem parâmetros, ou com apenas `provision`/`cleanup`,
retorna o plano sanitizado **offline**, sem ler credenciais nem chamar rede:

```powershell
rtk proxy node packages/coelo_database/scripts/r02-d01-auth-proof-executor.mjs
rtk proxy node packages/coelo_database/scripts/r02-d01-auth-proof-executor.mjs cleanup
rtk proxy node --test packages/coelo_database/scripts/r02-d01-auth-proof-executor.test.mjs
```

Default offline executado; **16/16 testes Node únicos aprovados**, zero falhos,
bloqueados, ignorados ou não executados nesse plano do executor. São cenários
com transporte controlado, não replay SQL nem prova produtiva. Não repetem os
seis testes do preflight. SQL, branches e chamadas de produção permanecem
sujeitos à revisão D00/D04 e à execução nominal; não declarar qualificadas
as mutações pelo sucesso dos mocks.
Após revisão independente, somente sete casos afetados por cleanup/replay/SQL
foram executados (7 PASS); os oito restantes mantêm a prova anterior válida.
Não somar a execução inicial de 14 com o delta de sete.
Uma qualificação posterior de headers adicionou um caso focal aprovado,
incluído no total de 16; os demais 15 não foram repetidos.

Em leitura MCP real, o UUID Auth reservado estava livre; o tipo de contexto,
helper `require_superadmin_internal_context(text)` e assinatura exata de
`audit_append_superadmin_internal` estavam presentes. O papel nominal possuía
grant ativo `platform.read`. Nenhum ator/session ID real foi procurado ou
inventado para preparar o executor.

Comandos exatos preparados para **uso somente após autorização nominal**, nunca
executados nesta preparação:

```powershell
rtk proxy node packages/coelo_database/scripts/r02-d01-auth-proof-executor.mjs --execute provision
rtk proxy node packages/coelo_database/scripts/r02-d01-auth-proof-executor.mjs --execute cleanup
```

O executor recebe os campos abaixo exclusivamente do ambiente do processo,
provisionados pelo executor autorizado/secret store. Não colocar valores reais
em comandos, Git, stdout ou pedido em chat:

| Variável | Contrato |
|---|---|
| `R02_D01_PROJECT_REF` | Exatamente `evvbomzejfijozbtgvpt` |
| `R02_D01_API_ORIGIN` | Exatamente `https://evvbomzejfijozbtgvpt.supabase.co` |
| `R02_D01_APPROVAL` | `D01-AUTH-PROOF-R02-v1:52edcfbe-adec-4614-b9a5-a10bc543379d:provision` ou sufixo `cleanup`, conforme ação autorizada; não substitui autorização humana registrada |
| `R02_D01_MAILBOX` | Mailbox controlada que D00 já solicitou ao Owner; endereço normalizado e não domínio fictício |
| `R02_D01_SUPABASE_SECRET_KEY` | Chave de servidor `sb_secret_` do projeto, para Admin Auth; nunca chave publishable |
| `R02_D01_MANAGEMENT_TOKEN` | Credencial Management API com acesso ao projeto, para SQL; não presumida disponível |
| `R02_D01_ACTOR_ACCESS_TOKEN` | Sessão **já existente e válida** do Owner autorizador, somente validação; não muda sua senha, sessão ou conta |
| `R02_D01_SYNTHETIC_PASSWORD` | Senha de 32–128 caracteres provisionada no secret store para a nova conta; somente provisionamento |

Todos os destinos são fixos; redirects/cookies são recusados. Auth usa somente
os paths nominais `/user`, `/admin/users`, `/admin/users/{UUID}` e
nenhum endpoint de envio ou login/logout do Owner. SQL usa exclusivamente
`https://api.supabase.com/v1/projects/evvbomzejfijozbtgvpt/database/query`.
Erros e receipts não expõem mailbox, senha, tokens ou resposta crua do provedor.
Conforme [API keys / Known limitations](https://supabase.com/docs/guides/getting-started/api-keys#known-limitations),
o transporte Admin envia `sb_secret_` somente em `apikey`, nunca como Bearer JWT.
`Authorization: Bearer` é usado apenas para o JWT real no GET `/user` do ator e
para a credencial própria do Management API no domínio correspondente.

Antes da primeira mutação, `/user` verifica o token real do ator, e uma
transação READ ONLY aplica o helper canônico para confirmar Owner/platform e
sessão viva. Esta qualificação pertence ao executor explicitamente autorizado;
não foi executada remotamente na preparação. A transação de escrita repete
essa validação, checa ownership/cross-realm/catálogo e bloqueia colisões/drift.
Insere os três vínculos e auditoria atomicamente; somente o receipt final após
COMMIT e nova leitura autorizam desbanir a conta. Ausência de credencial do
ator bloqueia a execução, não é preenchida com claims fabricadas.

Cleanup verifica ownership e tenta banir o UUID nominal uma vez; mesmo quando
a resposta de ban é ambígua, segue com a transação terminal nominal, sem retry
do ban. Revoga vínculos e remove somente suas sessões de provedor com auditoria.
Não precisa de JWT sintético vivo: expiração/perda do token não impede conter
acesso. FKs reais foram lidas em 2026-09-09: `auth.refresh_tokens.session_id` e
`auth.mfa_amr_claims.session_id` têm cascade ao apagar a sessão; a lista nominal
inclui esses efeitos. Ban isolado não foi tratado como revogação de sessões.
A leitura final exige zero sessões,
credencial banida e vínculos revogados (ou ausentes no cleanup de criação
parcial). Não apaga usuário Auth/identity/auditoria e nunca revoga a sessão do Owner.
Se o ban não se confirmou, a revogação terminal ainda ocorre, mas a saída
permanece `CLEANUP_UNCONFIRMED`; não alegar cleanup completo nem tentar ban de novo
automaticamente. O caso perdido de COMMIT interrompe sem repetir a transação.

Resposta ambígua de criação/ativação/COMMIT interrompe **sem retry automático**,
sem ativação compensatória nem criação substituta. A próxima invocação explícita
reconcilia os IDs/marcadores e o estado observado; conta criada fica banida se
o COMMIT não foi confirmado. Cleanup parcial sem sessão pode banir a própria
credencial ainda sem vínculos. O tratamento de ban ambíguo segue a contenção
terminal descrita acima, sem fabricar login ou usar a sessão do Owner como
sessão sintética.

Fontes técnicas do transporte: [Management API SQL](https://supabase.com/docs/reference/api/v1-run-a-query)
e contrato existente `e2-r01-auth-personas.ts` (Admin create com UUID/ban e
transações privadas com Owner, auditoria, COMMIT). O helper R01 não foi importado
porque exige cinco personas institucionais e ampliaria esta proposta de uma
persona plataforma. Seus arquivos e o ownership D04 permanecem preservados.

O UUID customizado foi confirmado na fonte oficial
[Supabase Auth admin.go](https://raw.githubusercontent.com/supabase/auth/master/internal/api/admin.go):
`AdminUserParams.Id` é validado e atribuído na criação (`adminUserCreate`).
Isso não depende de o SDK Dart expor esse campo.
O transporte oficial [Supabase MCP api-platform.ts](https://raw.githubusercontent.com/supabase/mcp/main/packages/mcp-server-supabase/src/platform/api-platform.ts)
usa o mesmo POST Management `/database/query` e devolve `response.data` como
array de linhas. Pelo MCP real, o SQL `stateSql` gerado, dentro de READ ONLY
e com COMMIT final, retornou um array `[{receipt:{...}}]`; o envelope
`[{actor:{authorized:false}}]` também foi comprovado com literal falso e sem
sessão/ator real. Isso qualifica formato/SELECT; **não** prova o helper com
credencial viva nem COMMIT de mutação. O receipt após COMMIT de escrita e a
leitura final permanecem gates da execução nominal.

## Sequência e recibos exigidos

| Gate | Operação autorizada e aceite | Evidência sanitizada |
|---|---|---|
| A1 | Login normal da persona; senha inválida negada sem revelar cadastro; AAL1 aceito conforme contrato | SHA, rota, horário, estado UI e contexto interno |
| A2 | Manter sessão ligado/desligado; reload, restauração e expiração real | Estado esperado em cada cenário e leitura de contexto após restauração |
| R1 | Solicitar recuperação na UI; entregar email somente à mailbox autorizada; conferir destino normal `/reset-password` | Recibo de entrega sem conteúdo sensível; origem/path sem query/fragment |
| R2 | Link válido cria recovery e não libera shell/contexto produtivo | UI confinada, negativas de navegação e contexto |
| R3 | Link adulterado e link realmente expirado não permitem senha nem contexto | Resultado UI/provedor por caso; validade/horários sem token. Não reduzir TTL global para fabricar caso |
| R4 | Alterar senha da persona; mostrar sucesso somente após atualização e encerramento confirmado | Operação correlacionada, nova leitura; nenhum segredo |
| R5 | Reabrir link já consumido em sessão limpa; negar novo reset; voltar ao login | Negativa real e ausência de contexto produtivo |
| R6 | Senha anterior recusada; senha nova aceita; reload continua sob autorização interna | Resultado de login/contexto por tentativa |
| L1 | Logout pela UI; sessão encerrada; tentativa com sessão antiga negada no contexto/comando sensível; novo login permitido | Recibo Auth e negativa server-side correlacionados |
| C1 | Encerrar sessões de teste e executar somente cleanup nominal dos recursos criados pela prova | Ownership, recursos envolvidos, auditoria e confirmação; não remover trilha histórica |

Executar A/B e cross-realm com D04 somente se as personas/cenários já estiverem
autorizados; não criar perfis, vínculos ou fixtures remotas incidentalmente.
Não contar esse gate como aprovado com mocks ou teste SQL local.
Não repetir envio/reset automaticamente após resposta ambígua: confirmar estado
da própria persona, preservar auditoria e retomar somente passo necessário.

## Saída da prova e bloqueio

### Gate D00 de revalidação — correção local de 2026-09-09

O candidato 8847c974 foi corrigido antes da integração: `exp` permanece no
contrato; `/user` e contexto Owner são revalidados antes de create/ban/unban e
antes de enviar SQL mutante. O SQL revalida após todos os locks e antes de cada
DML/auditoria, usando também `clock_timestamp()` para prazo da sessão e JWT.
O helper canônico usa `now()` transacional; repeti-lo sozinho não detectaria
expiração durante espera. Falha de revalidação no cleanup fica fora do catch
que tolera resposta perdida do ban. Antes de unban, ownership, colisão, bindings,
role, cross-realm e sessões são lidos novamente. Falha interrompe sem compensação.

Prova Node atual: 36/36 PASS (30 executor + 6 preflight), 14 novos casos RED
resolvidos, sem rede. O recibo `r02-d01-20260909/remote-package-qualification.md`
identifica hash/revisão e separa os resultados históricos.

Gate local concorrente ainda **não executado: U=6/6**. Usar somente o runner e
base Auth nominal existentes após slot concedido por D00; não criar perfil
paralelo nem importar dados de produção. Para cada ação provision e cleanup:

1. Preparar exclusivamente fixtures locais do Owner e dos IDs nominais. Para
   provision, usuário sintético banido com bindings ausentes; para cleanup,
   vínculos ativos e sessões sintéticas. Capturar contagens e versões iniciais.
2. Conexão A mantém `FOR UPDATE` no usuário sintético; conexão B inicia o SQL
   exato gerado pelo executor, identificado por application_name local.
   Confirmar espera real em `pg_stat_activity`/`pg_locks` antes de prosseguir;
   timeout sem espera observada invalida o cenário.
3. Em conexão C, revogar a membership do Owner e confirmar commit; em cenários
   distintos, aguardar prazo `auth.sessions.not_after` ou `actor.exp` real passar.
   O prazo começa válido e vence enquanto B espera. Liberar A dentro do limite
   de lock_timeout; registrar relógio real, sem JWT/senha/claims em logs.
4. B deve negar. Conferir rollback integral: zero novas identidades/vínculos em
   provision; versões, status e sessões sintéticas inalterados em cleanup;
   nenhuma auditoria de sucesso da operação. Cleanup apenas das fixtures locais
   pelo protocolo do runner. Caso de espera não observado permanece U, não PASS.

Esses seis cenários provam negativas durante os locks já adquiridos; não provam
atomicidade global de autorização. Auth Admin e Management SQL são APIs
distintas. Uma revogação pode acontecer entre a última prova e POST/PUT; mudanças
de autorização não bloqueadas também podem ocorrer entre checks SQL. O executor
não fornece lease nem transação distribuída. Esse limite e os efeitos parciais
devem integrar a decisão nominal antes de qualquer `--execute` remoto.
Nenhuma autorização remota é inferida dos guards, testes ou disponibilidade de
credenciais; o pacote permanece preparado, com prova SQL e execução nominal abertas.

Registrar por action_id FE/BE/E2E e testes P/F/B/S/U, revisão, ambiente, horário,
resultado e cleanup. SMTP, token e senha reais permanecem bloqueados até
pré-condições preenchidas; provas locais não promovem BE `done` ou E2E.
Responsável por desbloqueio: D00 coordena pacote e autorização nominal;
executor D01 executa a prova no escopo concedido. Não há decisão de produto
nova a promover para Knowledge.

Referências oficiais consultadas em 2026-09-09:
[verificação OTP Dart](https://supabase.com/docs/reference/dart/auth-verifyotp) e
[códigos Auth](https://supabase.com/docs/guides/auth/debugging/error-codes).
O índice `https://supabase.com/changelog.md` foi solicitado, mas o leitor web
recusou seu content-type; isso não foi tratado como changelog verificado.
