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

- Auditoria confirmou adapters e Edge Functions versionados para R2/Stream, publicação, expiração, remoção e autorização. Não foi duplicada implementação existente.
- Provas locais passaram; prova produtiva com objeto real, reload e negativa cross-tenant depende de ambiente autorizado.

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

## Bloqueios e separação de aceite

- A política solicitada impede aplicar SQL, Edge ou Cloudflare em produção sem autorização nominal do Owner/coordenadora. Nenhuma aplicação produtiva foi feita.
- O servidor `127.0.0.1:3017` e o Chrome CDP `9417` estavam indisponíveis (`Test-NetConnection`: `False/False`); não houve captura nem tentativa de contornar o método de seletor real.
- Não havia identidades QA/tenant e segredos de R2/Supabase autorizados para uma prova produtiva. Não foram usados, registrados ou commitados segredos, tokens, PII ou URLs privadas.
- As provas atuais são de contrato, static analysis, testes locais e mocks/injeções. Elas não devem ser apresentadas como prova produtiva de upload/read/reload/remove ou negativa cross-tenant.

## Sobra explícita para R15

1. Aplicar as duas migrations somente em espelho autorizado, após dump/manifesto e ordem de aplicação; executar os testes SQL R14, incluindo positivo, ownership, tenant e negativa cross-tenant.
2. Versionar/deployar as Edge Functions somente com autorização nominal e testar a rota real: upload, catálogo Postgres, PUT R2, finalize, read assinado, reload, remove, expiração, auditoria e negativa cross-tenant.
3. Repetir prova real de Chat Anexar pela rota `chat-media`, incluindo reload e negativa de outro tenant; conferir `asset_id` no envelope.
4. Repetir Agora/Momentos/Acontece contra R2/Stream real, com publicação, expiração, remoção e erro/escopo.
5. Executar QA CDP conforme `review-scope.md` quando `3017/9417` e as identidades autorizadas estiverem disponíveis.
6. Confirmar H10/H11 remotamente; manter autosave no MVP apenas se o aceite remoto continuar acima do limiar de 60%.
7. Só abrir Circular/Principal/gates quando cada item tiver `action_id`, contrato e prova definidos; não reivindicar `owner.r12-18`/`owner.r12-33` sem autorização.

## Estado ao handoff

- HEAD antes deste ajuste do handoff: `5535634632a5d6907a70fb587f37d5197f45c805`.
- Commits desta sessão: `7e6af350512988492fc8ac56c5e5ef1bfe09f200` (desenho), `4f2b31d73db0f385b7d9fc0e92a17da7db79ad7a` (plano), `dc64976ee1aef584b185890e5fbf9df903bc9b69` (Conta), `762dc148e61af21cfb33b66d4bdcceefcb0951cb` (Chat), `a7b66b5c5e97fdbe8cff7d2ab37d7f0314c97fdd` (teste de remoção), `5535634632a5d6907a70fb587f37d5197f45c805` (enum do catálogo).
- Este handoff é o único novo registro desta sessão. Handoffs de outras sessões não foram editados.
