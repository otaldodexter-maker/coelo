---
title: "D01 — pacote nominal v2: sessão password e razão de auditoria"
source: "D00 assignments r15-r16; migrations173000/173100; password-session-denial-audit-successor.md; password-session-remote-schema-readonly.md"
status: "ready-for-nominal-owner-review; local-46-reused-and-cli-2-pass; remote-not-authorized"
generated_at: "2026-09-09"
---

# D01-PASSWORD-SESSION-CONTEXT-20260909173100-v2

Projeto exato Supabase Coelo `evvbomzejfijozbtgvpt`, produção. Etapa2 → apps/superadmin → Auth → auth.login/auth.reset/contexto protegido. Substitui a proposta v1, que continha somente173000 e não qualificava a atomicidade entre DDL e histórico. Autorização de Git e reserva local D00 não autorizam aplicação remota.

## Arquivos e objetos exatos

Aplicar os dois arquivos nesta ordem, após materialização e revisão na base D00:

| Arquivo canônico em packages/coelo_database/migrations/ | SHA256 da preparação LF |
| --- | --- |
| 20260909173000_superadmin_password_session_context.sql | 0B52CBD9B189076333356A83F2AEA23CEA3038D3FDE1B867A0AEC24589FADD92 |
| 20260909173100_superadmin_password_session_denial_audit.sql | E53626A08CA558353BCBC3ADC217EC14974176288EFC18535275830DDD48F1A2 |

Fonte de173000:8500e44a06b22d02eed7c5348a6cde61299b1e24, integrada D00 como36e8e4c0b. Successor173100 e TAP atualizado:368c0add1312ee915622720d18cb3d968fbc73de. Checkout D00 pode materializar SQLCRLF; registrar o SHA256 dos bytes efetivamente implantáveis, conferindo equivalência LF. Nunca apresentar SHA de preparação como final autorizado.

Mutações nominais: substituir somente três funções e registrar exatamente as versões173000/173100 no histórico de migrations:

1. `app_private.require_superadmin_internal_context(text)`: após identidadeAuth e sessão validada, exigir AMRpassword da mesma sessão na tabela mantida pelo provedor. Retornar SESSION_INVALID se ausente.
2. `public.superadmin_auth_bootstrap_context()`: incluir SESSION_INVALID na allowlist de motivos auditados, preservando o motivo do envelope.
3. `public.superadmin_auth_resolve_institution_context(uuid)`: mesma inclusão exclusiva na allowlist.

Os dois wrappers não concedem contexto a recovery para identificá-lo em auditoria. O helper de auditoria revalida sessão e vínculo independentemente. Nenhuma tabelaAuth/AMR, usuário, senha, membership, configuraçãoSMTP/redirect/TTL ou RLS é alterada pelas migrations. Sessõesnão-password deixam de obter contexto interno; reset legítimo deve continuar disponível. AAL1/ADR0019 preservados. Os controles anteriores de usuário/realm/tenant/ownership/capability/revogação permanecem. O achado separado de AALausente/expiração pós-lock não integra esta correção.

## Pins e pre/postflight

MD5 abaixo é do prosrc normalizadoCRLF→LF, não de pg_get_functiondef:

| Função | Antes | Depois |
| --- | --- | --- |
| require_superadmin_internal_context |5cdb28081d40e15232ef50912edd8082 /4711chars|6b3f7d0a6b374786137ed62ae8cf1c18 /5250chars|
| superadmin_auth_bootstrap_context |cf411ecb47a0e3e42aeb4ee654f6b079 /1929chars|5db2c318fb52cb9014392727985bbc32 /1951chars|
| superadmin_auth_resolve_institution_context |e16a3b61cffba4230c7fb4235da9382d /2093chars|c3948273e90ca59235a1a5f226ec9641 /2115chars|

Preflight173100 exige o corpo posterior173000. Ownerpostgres/securitydefiner/search_pathvazio preservados; helperSTABLE semEXECUTEcliente, wrappersVOLATILE comEXECUTEauthenticated existente e semPUBLIC/anon/service_role. Pre/postconditions estão nos arquivos canônicos e qualquer drift interrompe. Cada arquivo preserva advisory lock Auth, lock_timeout5s e statement_timeout60s; a transacao e CLI batch por arquivo, sem BEGIN/COMMIT externos.

Leituras remotas somente de catálogo confirmaram os pins anteriores, owner e metadata em09/09; veja [recibo](r02-d01-20260909/password-session-remote-schema-readonly.md). Às15:52, leitura agregada do ledger confirmou116versões, máximo20260901200206 e zero colisão das duas versõesnominais, ambas posteriores ao máximo. Nenhum comandoCLIfoi usado nessa consulta. Revalidar na janela: leituras históricas não garantem ausência de drift futuro. Não consultar linhas de pessoas/tokens/sessões para fabricar provas.

## Gates e transporte

- Produto: D00 session78850, 36 TAP + 9 HTTP + 1 cold = 46 PASS, exit0/cleanupzero. Evidencia funcional reutilizada, sem novo runner e sem somar reruns. B4 e plano cliente permanecem evidencias separadas.
- Transporte: D00 session47872, CLI 2.116.0, dois gates PASS/exit0: falha deliberada do INSERT de ledger desfez DDL + ledger; controle positivo persistiu DDL + uma linha nominal. Cleanup externo e conferencia independente tool7b0e22: zero containers/volumes/networks proprios e TEMP ausente. [Manifesto final](r02-d01-20260909/cli-atomicity-final-manifest.json).
- D00 removeu exatamente quatro linhas canonicas: BEGIN/COMMIT externos dos dois arquivos. Comparacao normalizada contra HEAD confirmou todos os demais bytes identicos, incluindo guards, prosrc, SET LOCAL e advisory locks. A evidencia funcional e reutilizada por essa equivalencia; os dois gates sinteticos qualificam a forma do transporte CLI, sem alegar execucao local dos dois payloads finais pela CLI.
- O primeiro ensaio84568 falhou antes dos markers com diagnostico generico; nao conta como gate de atomicidade executado e sua causa SQL nao foi confirmada. V2 deixou de presumir ledger inicializado por reset vazio: bootstrap deliberadamente falho pela propria CLI, seguido de exigencia de ledger vazio, sem SQL manual de criacao/repair do historico.
- Executor existente e comandos concretos: [sequencia nominal de versionamento](r02-d01-20260909/password-session-versioning-qualification.md). Pacote pronto para revisao nominal do Owner; nao autorizado nem executado em producao. A execucao continua condicionada aos gates remotos de credencial preprovisionada, inventario/dry-run exatos, catalogo sem drift e janela serializada.
- Não usar apply_migrationMCP com timestamp implícito, SQLgenérico/execute_sql paraDDL, migrationrepair automático, upsert de histórico, espelho completo de migrations nem staging do replaylocal. Nenhuma dessas alternativas está autorizada por este documento.
- Inventário remoto e dry-run precisam corresponder exatamente aos dois arquivos, ambos posteriores ao máximo remoto, nenhuma migrationextra/seed/role/vault. Staging nominal novo sem .env/overrides/segredos copiados; CLI fixada2.116.0 e skip-vault. Qualificação deve testar falha do registro de histórico e demonstrar rollback de DDL+ledger por arquivo, com controle positivo, antes de promover o transporte.
- Antes de qualquer link/fetch/list/dry-run, exigir SUPABASE_DB_PASSWORD já provisionada em secretstore e caminho de conexão correspondente ao projeto exato. A CLI pode criar loginrole temporário ou remover networkbans no fallback sem senha; esse ramo está fora do pacote. Credencial ausente ou ramo não qualificado bloqueia antes desses comandos, mesmo os denominados leitura. Nenhuma credencial foi lida/sondada aqui.
- Owner deve nomear este pacotev2, projeto, SHAs finais e operação/transporte; D00 fixa janela, executor e escritor único. Autorização anterior da proposta v1 não seria autorização de uma mutação ou transporte ampliado.

A proposta independente [Auth persona/SMTP](2026-09-09-r02-d01-auth-remote-package.md) mantém sua autorização/mailbox pendentes. Este pacote não cria persona, envia email, altera contaOwner ou autoriza aquele executor. A pergunta de mailbox já foi feita; não foi repetida.

## Prova posterior e recuperação

A proposta CLI entrega atomicidade por arquivo, não pelos dois em conjunto. Se173000 aplicar e registrar mas173100 falhar, o primeiro pode permanecer aplicado. Registrar explicitamente esse estado parcial e preparar recuperação forward-only nominal; não apagar ledger nem compensar retirando o guardpassword.

Depois de COMMIT confirmado: conferir catálogo, metadata/ACL e histórico nominal das duas versões; registrar hashes e resultado sanitizado. Resposta ambígua exige reconciliação somenteleitura antes de qualquer retry. Não reparar histórico nem reaplicar automaticamente.

Prova funcional remota usa apenas persona nominalmente autorizada: password/refreshcontrolados, recovery/refresh/metadata negados, resetlegítimo, recoverypósPUT ainda semcontexto, logout/revogação e novo loginpassword. Coldstoragecliente mantém gate próprio. SMTP/redirect/reutilização/expiração reais dependem do cenário autorizado, não de mock.

Se houver regressão após commit, interromper promoção e preparar nova correção forward-only nominal, sem editar migrations aplicadas ou retirar o guardpassword como compensação. Sem provas remotas completas, BE0/4 e E2E0/4 permanecem; testes locais não certificam produção.

Responsável de integração/aplicação/serialização: D00. D01 entrega fonte, hashes, provas locais e proposta. Estado atual: nenhuma aplicação remota executada.

## Bytes finais para aprovacao nominal

- `20260909173000_superadmin_password_session_context.sql`: SHA256 RAW `2CB80D4B9AB49715E21DB515E15599F70A3DB9D2ED73669F4EE56F737156D5AC`; LF `0B52CBD9B189076333356A83F2AEA23CEA3038D3FDE1B867A0AEC24589FADD92`.
- `20260909173100_superadmin_password_session_denial_audit.sql`: SHA256 RAW `6AF9068FD98FE840AFAE1D5E496A2608CF9EC8B33B025082C43038E1D84AEC96`; LF `E53626A08CA558353BCBC3ADC217EC14974176288EFC18535275830DDD48F1A2`.

A aprovacao solicitavel e exclusivamente aplicar essas duas migrations, nessa ordem, em `evvbomzejfijozbtgvpt` pela CLI `supabase@2.116.0`, no staging nominal e sob os gates descritos. Nao abrange persona, SMTP, mailbox ou prova funcional remota ainda nao autorizada. Nenhuma aprovacao e inferida deste recibo.
