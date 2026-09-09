---
source:
  - docs/reviews/etapa-2-operacao/next-round/R02-20260909/assignments/D03.md
  - docs/reviews/etapa-2-operacao/next-round/R02-20260909/handoffs/notes/auth-password-transport-review.md
  - docs/reviews/etapa-2-operacao/next-round/R02-20260909/handoffs/notes/child-remote-apply-migration.sql
  - packages/coelo_database/scripts/Prepare-SafeMigrationReplay.ps1
  - packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1
status: proposed-not-executed
generated_at: 2026-09-09
---

# Plano local do pacote CHILD antes da migration

## Recorte e estado

Este plano propõe uma prova local descartável do SQL transportável do pacote CHILD. Ele não executa banco, não autoriza produção e não certifica o transporte, o ledger ou a transação do Management API/MCP. O hook e o harness ainda precisam de reserva e revisão pelo escritor central antes da execução.

O artefato sob prova é `child-remote-apply-migration.sql`, em LF, UTF-8 sem BOM, sem `BEGIN`/`COMMIT` externos, SHA-256 `740057756FB2A7DFA5E8F2AB2D9908DF24968F2A3E78196A1FAA0D3B422C6C2C`, 22.280 bytes. Ele inclui o postflight de catálogo e `NOTIFY pgrst, 'reload schema'`. O candidato manual histórico com transação própria, SHA `1193649F37C15EAA964A7486B83014806BC76C70AB4BD04537908CB57EE198E6`, não entra nesta campanha.

## Base local exata

A preparação deve usar `-AuthOnly` com alvo `20260901200206`. A cadeia é o manifesto de fundação filtrado até `20260812001975`, seguido, na ordem, por `20260827214000`, `20260827233000`, `20260901124500` e `20260901200206`. A materialização local observada produziu exatamente 47 SQL (45 canônicos + 2 preflights), sem iniciar banco. O manifesto exclusivo child-package-auth-base.sha256 fixa nomes/ordem e SHA-256 de cada conteúdo normalizado LF/UTF-8; seu SHA-256 LF é 1B31D0AD0D825D9420CC862808F582F08C6CE0171208018F588C0A998A0E9F46. A raiz TEMP dessa preparação foi removida após validação do caminho absoluto. O harness deve rejeitar contagem, arquivo extra, reparse e hash divergentes antes de tocar o banco. Esse manifesto não altera a allowlist global.

Antes da fixture ou do pacote, o catálogo precisa confirmar:

- `app_private.superadmin_internal_error_envelope(text,uuid)` com corpo MD5 normalizado `b89d2dc22f032a1c3f155a77f0eaaf08` e os metadados/ACL antigos esperados;
- ausência de `public.superadmin_child_context_directory_v2(uuid,text,uuid,integer)`;
- metadados e ACL dos outros quatro helpers exatamente nos pins usados pelo preflight CHILD.

Não usar o perfil `ChildDirectoryEnvelope`: ele já injeta a ponte e a migration CHILD e, portanto, não representa o estado imediatamente anterior ao pacote.

## Ordem da campanha

Uma única base descartável serve aos dois cenários. O cenário negativo vem primeiro para exercer o novo postflight; sua fixture é removida antes do controle positivo.

### 1. Negativo de default ACL e rollback

Fora da transação do payload, criar exclusivamente o role `d03_child_package_acl_probe` como `NOLOGIN` e adicionar, para o owner `postgres` no schema `public`, um default privilege que conceda `EXECUTE` em funções futuras a esse role. A fixture não altera a ACL do helper já existente. Quando o pacote substituir o envelope e criar o gateway, o novo gateway herdará o grant inesperado.

Em uma única sessão `psql`, o harness deve abrir `BEGIN`, inserir byte a byte o payload cuja hash foi conferida e executá-lo com parada no primeiro erro. O preflight passa, a ponte troca o envelope e a migration cria o gateway; o DO postflight final deve então rejeitar a entrada extra produzida por `aclexplode`. O processo deve terminar não zero com a transação ainda aberta; o fechamento da conexão desfaz todas as escritas do payload.

Uma segunda conexão somente leitura confirma o rollback material:

1. envelope novamente no MD5 antigo `b89d2dc22f032a1c3f155a77f0eaaf08`;
2. gateway CHILD ausente.

Depois dessas confirmações, o cleanup restrito revoga somente o default privilege criado pela fixture e remove somente o role `d03_child_package_acl_probe`. Ele falha fechado se o role tiver login, memberships, ownership, grants ou dependências além da fixture nominal. Uma leitura final confirma que não resta default ACL nem role da fixture. Só então começa o controle positivo.

### 2. Controle positivo, commit e leitura persistida

Em nova sessão `psql`, o harness abre `BEGIN`, insere o mesmo payload verificado e o executa integralmente. Ainda dentro da transação, poucas consultas de catálogo confirmam:

1. envelope novo com MD5 normalizado `bfce7b85b8d5d43e93e5d3fba3a66dc8`;
2. gateway com `prosrc` MD5 normalizado `302916710017ece5fa029d9ea388e3f9` e exatamente owner mais `authenticated` com `EXECUTE`, sem grant option para não-owner;
3. metadados do gateway fixados pelo postflight: função, PL/pgSQL, volatile, `SECURITY DEFINER`, retorno `jsonb`, `proconfig` exatamente `search_path=""`, owner `postgres`, `search_path` vazio, `anon`/`service_role` negados.

O harness emite `COMMIT` explicitamente após o payload e seus checks. Uma conexão separada confirma o envelope novo, corpo/metadata/ACL do gateway e, portanto, o estado persistido. A base descartável passa a conter o CHILD; ela não pode ser reutilizada como pré-CHILD. O runner destrói integralmente seus próprios recursos no encerramento.

O `NOTIFY` só é entregue no commit positivo. Sem PostgREST previamente ativo e uma verificação HTTP, esse resultado não prova processamento da notificação nem atualização do cache.

## Hook e comando propostos

O runner atual não possui esse modo. O escritor central precisa reservar e revisar um hook opt-in, por exemplo `-RunChildDirectoryAtomicPackageLocal`, compatível somente com `-AuthOnly`, sem `-AdditionalMigration`, `-NominalProfile`, `-TestPath`, lifecycle, concorrência ou outros modos. O comando futuro seria:

```powershell
./packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion 20260901200206 `
  -AuthOnly `
  -RunChildDirectoryAtomicPackageLocal
```

O hook deve receber o caminho já validado do projeto temporário e reutilizar integralmente o mutex, marker de ownership, proteção contra reparse point e inventário final de containers, volumes, redes e diretório do runner. O harness não remove recursos compartilhados e não executa cleanup fora da raiz temporária identificada pelo runner.

Esta campanha tem dois cenários e poucos aceites únicos: preestado, falha do guard final, rollback negativo, cleanup da fixture, estado interno positivo e leitura persistida após commit. Ela não reexecuta nem soma os 45 TAP e os três casos de concorrência já registrados na base `f3e1f732f`.

## Limites de transporte, ledger e cache

O harness local lê o arquivo exato, confere SHA-256, LF, ausência de BOM e ausência de wrapper, e só então compõe um arquivo temporário `BEGIN; <payload>; checks; COMMIT;` para o positivo, com rollback por desconexão após erro no negativo para uma invocação local de `psql`. Essa composição prova o comportamento transacional do SQL e do guard. Ela não simula `apply_migration`, não grava `supabase_migrations` e não prova atomicidade entre statements e ledger no Management API.

O transporte remoto candidato continua sendo `apply_migration` com nome nominal `r02_d03_child_directory_envelope_read01`; sua execução e a reconciliação posterior de versão, nome e hash no ledger dependem de autorização remota e de evidência do endpoint. Não usar a prova local para fabricar ou reparar uma versão `20260908051500` no ledger.

A qualificação de cache fica em uma janela HTTP separada. Nela, o PostgREST deve estar ativo antes da aplicação CHILD; após o commit do pacote e o `NOTIFY`, a RPC precisa aparecer e responder sem reiniciar o serviço. Essa prova futura deve usar ator Owner autorizado, escopo nominal e nenhuma fixture de produção. Reiniciar PostgREST ocultaria exatamente o comportamento que precisa ser aceito. O plano local transacional acima não satisfaz esse gate.

## Evidência esperada

Preservar o transcript bruto e um manifesto com base/manifesto, hash e tamanho do payload, IDs dos dois cenários, resultado esperado/observado, código de saída e resultado do cleanup. Não imprimir payload, senha, token ou connection string. Até que o hook seja integrado e a campanha seja executada, todos esses aceites permanecem propostos e não executados.

## Candidato de harness revisado

`packages/coelo_database/scripts/Test-ChildRemotePackage.ps1`, SHA256 LF
09720F6A9424C1C48441BB755E48C3752989B590101EB53B4A6C75D0D4A3E511.
Dois revisores conferiram SQL negativo/positivo e guards locais; correção de
fronteira entre chamada de cleanup e atribuição foi revalidada pelo AST. Isso
não executou banco nem os seis aceites. O payload aceita somente normalização
CRLF/CR para LF antes de conferir o hash nominal; BOM é recusado. Stdin é enviado
em bytes UTF-8 e stdout/stderr são drenados sem bloquear. Fixture criada numa
transação, marcada como própria após sucesso; main/finally usam o mesmo guard
nominal de cleanup. Nenhum shared runner foi editado.

IDs emitidos apenas após o respectivo aceite: package.prestate,
package.default-acl-denied, package.negative-rollback, package.fixture-cleanup,
package.positive-metadata, package.persisted-after-commit. Atualmente P0/F0/B6/S0/U0,
com os seis bloqueados por hook/janela; não adicionar às provas45+3 anteriores.
## PATCH nominal Invoke — D00 r15

`child-package-invoke.patch` propõe RunChildRemotePackage restrito ao AuthOnly
20260901200206, sem adicionais/nominal/TestPath/lint/outros modos. DB-only;
cache dinâmico continua U. Não aplicar o antigo patch HTTP interrompido.

- Fonte canônica observada: HEAD61d3720c88c6b488ee5fdbefbb630b168035db0f; wrapper raw9E2A367DE74F0BDFF758B6029E58AF43669686F7A1BB3E9E16B9A23601364ED9 e LFCB2449D3F6F621B25CFE090D065A5CF9D1435180D7AA52781E51CF31ADCE0CC1.
- PATCH SHA256 LF651FACEB312B2597CCFFE56CD14F50F70AE281FB0DBF08D4A3665A4843EDD61D.
- Teste exclusivo child-package-invoke-tests.ps1 SHA2569492C015DF0FF7BC451EFE6E8360881E5CA52B288C9E42E5F84EC84104B4B19E, exige RunnerPath para candidato.
- Candidato TEMP d03-child-package-invoke-patched.ps1 SHA2563B3262AD774A3DD06D27A602106186FB88111558461F79F5976BD417FFC92BEF.
- Seis casos Pester estruturais reportados PASS em console, sem XML/log bruto preservado. Não foram repetidos apenas para gerar arquivo.
- git apply --check conferido por autor e pai contra a raiz atual, sem aplicação; D00 continua escritor/integrador do wrapper.

Os seis Pester verificam estrutura do modo, não executam os seis aceites SQL do
compositor. O snapshot da fonte tem modos que podem evoluir: D00 deve preservar
novos switches/hunks próprios ao integrar; este patch não substitui o wrapper.