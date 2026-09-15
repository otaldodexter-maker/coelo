# R14 — handoff da Sessão 4 / Bloco E

Data: 2026-09-15  
Sessão: E  
Worktree: `C:\Users\adrie\Documents\Coelo.worktrees\r14-e`  
Branch: `r14/bloco-e`

## Base, leitura e limites

- Base solicitada e usada: `a85ac01c45dac2a615dab3fcffd64eaedcb9ff02`.
- `origin/dev` local estava em `ee179b1e1474...`; a divergência foi registrada e não foi substituída silenciosamente.
- Documentos lidos: `AGENTS.md`, `docs/agent/current-state.md`, `docs/agent/source-of-truth.md`, `docs/agent/backlog.md`, `docs/reviews/etapa-2-operacao/next-round/R14-pendencias.md`, ADR 0032, ADR 0039, `R14-execucao-paralela.md`, `docs/agent/review-workflow.md`, `review-scope.md` e os designs de Conta/Chat.
- Nenhum MD central da coordenadora foi alterado. Contadores não foram alterados.
- `owner.r12-18` e `owner.r12-33` não foram reivindicados.
- Fora do escopo preservado: Planos, `plans.assign`, Auth recovery/allowlist e duplicações de Cardápios, Avaliações, Perfis de acesso e reader self.

## Entregue localmente

### Conta A+ / owner.r12-46

- O layout aprovado já estava presente na base: “Meu acesso” permanece na coluna da mesma linha de “Dados pessoais”, com rolagem interna; a suíte de tela confirmou wide, compacto e 200%.
- `AccountAvatar` passou a carregar apenas a identidade opaca `photoAssetId`; bytes são hidratados somente após leitura autorizada.
- Novo migration versionado `20260915120000_account_avatar_private_r2_v1.sql`: evolução do catálogo `person_avatar_assets`, tenant, R2 privado, ticket de finalize, checksum/ownership, autorização de leitura/remoção, expiração e auditoria.
- Nova Edge Function `account-media`: prepare/upload assinado/finalize, leitura assinada, remoção, worker de expiração e CORS por allowlist; sem Supabase Storage/Stream público.
- Repositório Flutter executa prepare, PUT assinado, finalize, save, reload/leitura autorizada e remoção. Nenhuma URL privada é persistida no perfil.
- Commit: `dc64976ee1aef584b185890e5fbf9df903bc9b69` (`feat(account): close private avatar r2 flow`).

### Chat Anexar / owner.r12-52

- Migration versionado `20260915130000_chat_media_asset_binding_v1.sql` mantém `chat_attachment_metadata.id` como único catálogo/ownership e explicita esse valor como `asset_id` no envelope de thread.
- Edge `chat-media` retorna `asset_id` em prepare, read e finalize; a autorização continua no backend com tenant, conversa, ownership, auditoria e R2 privado existentes.
- Não houve mudança apenas de cliente: contrato SQL e gateway foram alterados e cobertos.
- Commit: `762dc148e61af21cfb33b66d4bdcceefcb0951cb` (`chat-asset-id`).

### Agora, Momentos e Acontece

- O contrato vigente das três superfícies usa R2 privado real; não há Stream no contrato ou worker desta fatia. A ausência de Stream fica registrada como gap de R15, sem afirmar aceite de Stream.
- Agora passou em produção por `now-media` v8: prepare, PUT R2, finalize, publish, feed com read ticket, read assinado, bytes conferidos e sweep de expiração (`expiry_sweep=true`). A remoção imediata não existe na RPC vigente; o ciclo material é expiração.
- Momentos passou em produção por `moments-media` v12: prepare, PUT R2, finalize, publish, feed, read assinado, bytes conferidos e `withdraw_moment` (`withdraw_status=200`).
- Acontece passou em produção por `happens-media` v7: prepare, PUT R2, finalize, publish, feed, read assinado, bytes conferidos e `withdraw_happens_post` (`withdraw_status=200`).

### H10/H11 e demais fatias

- H10/H11 preservam as regras de audiência existentes.
- Autosave permanece candidato ao MVP: a suíte authoring/contexto/audiência passou 228 testes, incluindo retries, isolamento de contexto, discard, publicação e regras de audiência. A confirmação remota ainda é necessária.
- Circular H04, Principal H27/P54/H02, páginas de erro e gates H03, H07, H09, H12, H14, H16, H18-H20, H22, H24-H26 e H28 não foram alterados sem `action_id`, contrato e prova definidos.

## Provas executadas

- Account Edge: `deno test --allow-read --no-check index_test.ts` — **2 passed**.
- Chat Edge: `deno test --allow-read --no-check index_test.ts` — **4 passed**.
- Account repository: teste focado — **5 passed**, incluindo remoção após reload.
- Account profile UI: teste focado — **24 passed**, incluindo alinhamento, compacto, 200%, rolagem/controles e estados de avatar.
- Chat Flutter (repository + upload): **52 passed**.
- Agora Flutter (repository/controller/page): **71 passed**.
- Momentos/Acontece Flutter (repository/controller/upload intent): **39 passed**.
- Agora/Momentos/Acontece Edge: **4/4 cada**.
- H10/H11 authoring/context/audience: **228 passed**.
- `dart analyze lib/features/account lib/features/chat`: **No issues found**.
- `git diff --check`: limpo antes dos commits.
- `supabase db lint --local --workdir packages/coelo_database --fail-on error`: sem erros no schema disponível; o banco local não contém as migrations R14 novas e, portanto, isso não é prova de aplicação dessas migrations.
- Espelho `supabase_db_coelo_mirror_r14`: dump schema-only salvo fora do Git em `C:\Users\adrie\Documents\Coelo-backups\r14-e-before-block-e.dump`; migrations Conta e Chat aplicadas em ordem, com `COMMIT`.
- Contratos pgTAP no espelho: Conta **13/13** e Chat **2/2**.
- Fluxo SQL sintético descartável, fora do Git, em `C:\Users\adrie\Documents\Coelo-backups\r14-e-avatar-behavior.sql`: **9/9**, cobrindo prepare, catálogo/tenant, finalize, read autorizado, negativas cross-tenant, remove e read após revogação; fixtures dentro de transação com `ROLLBACK`.
- Produção autorizada: dump pré-aplicação em `C:\Users\adrie\Documents\Coelo-backups\schema-producao-r14-e-before.sql`; migrations Account `20260915120000...` e Chat `20260915130000...` aplicadas pelo linked project; verificação confirmou catálogo, RLS/grants e finalize service-role-only.
- Prova produtiva Account: login QA, prepare, PUT de PNG sintético em R2, finalize, projeção de perfil em modo foto, read assinado, bytes iguais, reload, sete identidades QA de escopos não autorizados com `422`, remove e read posterior negado. Nenhum segredo, token, URL assinada ou dado pessoal foi impresso.
- Prova produtiva Chat: inbox real, prepare com `asset_id`, PUT R2, finalize, read assinado, bytes iguais, thread/reload com `asset_id` no envelope. As sete identidades QA disponíveis compartilham o mesmo fingerprint de escopo e receberam `200`; não há identidade QA de outro tenant para declarar negativa Chat. As duas mensagens sintéticas foram revogadas pela RPC (`2/2`).
- Prova produtiva Principal: fixture PNG criada pelas RPCs reais e retirada após leitura para Momentos e Acontece; Agora foi publicada e o sweep de expiração respondeu `200`. Os testes confirmaram read assinado e bytes iguais nas três superfícies.
- Edge Functions produtivas finais: `account-media` v1, `chat-media` v8, `now-media` v8, `moments-media` v12 e `happens-media` v7, todos apontando para este worktree.
- Rota real: `http://127.0.0.1:3017/login` carregou no Chrome isolado; árvore Flutter AX expôs os seletores reais de E-mail, Senha e Entrar. A porta `3017` estava em LISTEN. O CDP TCP `9417` não estava em LISTEN neste host, portanto não há prova por esse endpoint literal.

## Bloqueios e separação de aceite

- A autorização nominal foi concedida pelo usuário nesta sessão; SQL/migrations e Edge Functions foram aplicados somente no projeto vinculado autorizado, com dump prévio e sem alterar os MDs centrais.
- O servidor `127.0.0.1:3017` está em LISTEN e a rota `/login` foi verificada no Chrome isolado. O Chrome CDP TCP `9417` não está disponível neste host; a prova UI não deve ser descrita como execução pelo endpoint CDP literal.
- Não registrar nem commitar segredos, tokens, PII, mídia privada ou URLs assinadas. As provas produtivas usaram credenciais QA apenas em memória; saídas foram reduzidas a status/booleans. Scripts efêmeros ficaram fora do Git.
- Negativa cross-tenant produtiva está comprovada para a Conta (sete leituras negadas). O Chat não tem uma segunda identidade/tenant QA; todos os perfis disponíveis compartilham o mesmo escopo, então essa negativa específica continua pendente.
- Autosave H10/H11 tem 228 testes locais, mas aceite remoto acima de 60% ainda não foi executado; manter a decisão formal para R15/coordenadora.

## Sobra explícita para R15

1. Concluído nesta sessão: aplicar as duas migrations em espelho e produção autorizados, após dump/manifesto e ordem de aplicação; executar os testes SQL R14, incluindo positivo, ownership, tenant e negativa cross-tenant.
2. Confirmar no gate da coordenadora as migrations já aplicadas em produção e anexar o manifesto/dump externo; não reaplicar sem nova autorização.
3. Repetir prova real de Chat Anexar com uma identidade de outro tenant; conferir negativa produtiva além do contrato e do positivo já provado.
4. Integrar Stream somente quando existir contrato/Edge/segredo/fixture autorizados; as provas desta sessão são R2 privado.
5. Executar QA pelo CDP literal `9417` quando o endpoint estiver disponível; a rota `3017` já foi carregada por Chrome isolado.
6. Confirmar H10/H11 remotamente; manter autosave no MVP apenas se o aceite remoto continuar acima do limiar de 60%.
7. Só abrir Circular/Principal/gates quando cada item tiver `action_id`, contrato e prova definidos; não reivindicar `owner.r12-18`/`owner.r12-33` sem autorização.

## Estado ao handoff

- HEAD antes deste ajuste do handoff: `622d2fc5a16e19592a99d691ff045c01cd5fb05a`.
- Commits desta sessão incluem `7e6af350512988492fc8ac56c5e5ef1bfe09f200` (desenho), `4f2b31d73db0f385b7d9fc0e92a17da7db79ad7a` (plano), `dc64976ee1aef584b185890e5fbf9df903bc9b69` (Conta), `762dc148e61af21cfb33b66d4bdcceefcb0951cb` (Chat), `a7b66b5c5e97fdbe8cff7d2ab37d7f0314c97fdd` (teste de remoção), `5535634632a5d6907a70fb587f37d5197f45c805` (enum do catálogo), `9117da7ca2c14073f3bb5906e14cba69234fdb76` (handoff/prova), `e8096df191794696e9e381eead4b09bbd889a15d` (lock Edge) e `622d2fc5a16e19592a99d691ff045c01cd5fb05a` (normalização Now).
- Este handoff é o único novo registro desta sessão. Handoffs de outras sessões não foram editados.
