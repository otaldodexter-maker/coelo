---
title: "D01 — qualificação de versionamento para aplicação remota nominal"
source: "packages/coelo_database/README.md; packages/coelo_database/scripts/Sync-SupabaseCliMigrations.ps1; packages/coelo_database/scripts/New-MigrationRecoveryManifest.ps1; docs/reviews/2026-07-24-contextual-migration-history-reconciliation.md; Supabase CLI 2.116.0 --help"
status: "v2-command-proposal; final-payload-and-ledger-atomicity-pending; not-executed"
generated_at: "2026-09-09"
---

# Resultado

Há um caminho proposto para preservar as versões **20260909173000 e20260909173100** sem depender de
timestamp gerado pelo MCP: CLI oficial em diretório nominal isolado, contendo
somente a fotografia do histórico remoto já aplicado e as duas migrations
novas aprovadas. O dry run deve listar exatamente
`20260909173000_superadmin_password_session_context.sql` e `20260909173100_superadmin_password_session_denial_audit.sql` antes da aplicação.

Esta é uma proposta de transporte para
[D01-PASSWORD-SESSION-CONTEXT-20260909173100-v2](../2026-09-09-r02-d01-password-session-remote-package-v2.md),
não autorização de deploy. Não foi criado staging nem executado comando
remoto nesta qualificação; somente arquivos locais, ajuda CLI e documentação
oficial foram lidos. Hash final, campanha local, janela e autorização nominal
continuam sendo gates do pacote.

## Evidência do projeto e limites

- `packages/coelo_database/README.md:93` define `migrations/` como fonte
  canônica e espelho CLI por nome/SHA. Em `:303`, exige preservar o timestamp
  originalmente gerado, sem renomear a migration.
- O [recibo de reconciliação de julho](../../../../2026-07-24-contextual-migration-history-reconciliation.md)
  registra uma aplicação CLI de **uma** migration, após dry run único;
  `migration list` posterior mostrou versões locais/remotas iguais e novo
  dry run vazio. O repair anterior daquele episódio tinha escopo explícito
  para divergências já examinadas. Não é permissão genérica para repair D01.
- Não foi encontrada regra aprovada que permita aplicar por MCP e depois
  renomear a fonte canônica para o timestamp retornado. O contrato atual do
  MCP `apply_migration` oferece `name`, `project_id`, `query`, sem `version`.
- `Sync-SupabaseCliMigrations.ps1` espelha **todo** o diretório canônico.
  Não possui seleção nominal de uma migration; executar esse espelho completo
  contra produção pode incluir pendências alheias e não serve a este pacote.
- `Prepare-SafeMigrationReplay.ps1`/`Invoke-SafeLocalMigrationReplay.ps1`
  geram preflights/sintéticos locais. README `:298` proíbe usar aquele staging
  com comandos remotos. O novo diretório proposto abaixo não é esse replay.
- `New-MigrationRecoveryManifest.ps1` está fixado no snapshot de 27/08:
  103 versões, máximo `20260821200000`. Serve como evidência de controle por
  inventário/hash, não como fotografia vigente de setembro nem executor.

## Capacidades verificadas nesta sessão

Ajuda executada com `npx.cmd --offline supabase@2.116.0`: `db push --help`,
`migration list --help` e `migration fetch --help`, todos exit 0. Não houve
consulta a projeto nem download de nova versão. O binário global do host é
2.117.0; a proposta fixa a versão 2.116.0 já usada no projeto.

O help confirma `--workdir`, `--project-ref`, `--agent no`,
`--output-format text`; `db push` também oferece `--dry-run` e `--skip-vault`.
O último é relevante: sem ele, o próprio help avisa que push pode atualizar
Vault pela configuração antes das migrations. Não incluir `--include-all`,
`--include-roles` ou `--include-seed`.

`migration fetch` é a capacidade existente para materializar arquivos do
histórico remoto, evitando inventar versões, SQL vazio ou marcar pendências
como aplicadas. A [referência oficial CLI](https://supabase.com/docs/reference/cli/supabase-db-push)
documenta que push registra a migration no histórico após aplicação e pula
as já aplicadas; fetch obtém o histórico, enquanto repair altera esse histórico.
Os flags da proposta foram confirmados pelo help da versão fixada.

## Sequência nominal proposta

Tudo abaixo é **futuro**. A fase de leitura remota precisa da autorização
correspondente; a aplicação exige também Owner nominal e janela D00. D00
define um diretório novo e exclusivo em TEMP, fora do checkout/replay, e
atribui seu caminho absoluto a `$D01NominalWorkdir`. Validar ausência de
reparse points e impedir reutilização de diretório preexistente.
`$D01CanonicalMigrations` aponta para migrations/ no checkout consolidado; os dois SHA256 finais são aprovados nominalmente. Credenciais CLI vêm do secret store/ambiente de processo (`SUPABASE_ACCESS_TOKEN` e obrigatoriamente `SUPABASE_DB_PASSWORD`);
não entram em argumentos, logs, pacote ou pergunta ao Owner. A senha já provisionada é condição ANTES de link/fetch/list/dry-run: sem ela a CLI pode criar loginrole temporário ou remover networkbans no fallback. Esse ramo está proibido neste pacote; parar antes dos comandos, sem sondar ou imprimir credenciais.

1. Inicializar configuração local limpa e vincular o projeto exato. Não
   copiar `.env`, Vault, roles, seeds, funções ou configuração privada.

```powershell
rtk proxy npx.cmd --offline supabase@2.116.0 init --workdir $D01NominalWorkdir --agent no
rtk proxy npx.cmd --offline supabase@2.116.0 link --project-ref evvbomzejfijozbtgvpt --workdir $D01NominalWorkdir --agent no --output-format text
```

2. Fotografar somente o histórico aplicado no diretório vazio e conferir
   correspondência de versões/nomes, sem executar seus corpos:

```powershell
rtk proxy npx.cmd --offline supabase@2.116.0 migration fetch --linked --project-ref evvbomzejfijozbtgvpt --workdir $D01NominalWorkdir --agent no --output-format text
rtk proxy npx.cmd --offline supabase@2.116.0 migration list --linked --project-ref evvbomzejfijozbtgvpt --workdir $D01NominalWorkdir --agent no --output-format text
```

Exigir todas as versões remotas representadas uma vez, nenhuma pendência
local, ausência das versões20260909173000/20260909173100 e nomes nominais, e máximo remoto
anterior a essa versão. Guardar resumo de nomes/hash/counts. Corpos históricos
ficam somente no diretório temporário restrito, sem transcrever SQL/possíveis
literais em evidências ou transferi-los para a fonte canônica.

3. Copiar exclusivamente os dois arquivos D01 aprovados e verificar seus SHA256:

```powershell
$D01Names = @('20260909173000_superadmin_password_session_context.sql', '20260909173100_superadmin_password_session_denial_audit.sql')
foreach ($D01Name in $D01Names) {
  $D01TargetSql = Join-Path $D01NominalWorkdir ('supabase/migrations/' + $D01Name)
  if (Test-Path -LiteralPath $D01TargetSql) { throw 'Nominal destination collision' }
  Copy-Item -LiteralPath (Join-Path $D01CanonicalMigrations $D01Name) -Destination $D01TargetSql
  Get-FileHash -LiteralPath $D01TargetSql -Algorithm SHA256
}
rtk proxy npx.cmd --offline supabase@2.116.0 db push --dry-run --skip-vault --linked --project-ref evvbomzejfijozbtgvpt --workdir $D01NominalWorkdir --agent no --output-format text
```

Cada destino deve estar ausente antes da cópia. Conferir que o conjunto
pendente é exatamente os dois nomes em `$D01Names`,
não apenas que esse nome aparece na saída. Qualquer versão faltante, conflito,
arquivo extra, erro ou pedido de include-all/repair interrompe. Congelar o
inventário e SHA do staging; nenhum outro escritor atua entre dry run e apply.

4. Somente após gates do pacote e autorização nominal, aplicar nesse mesmo
   diretório/inventário, sem copiar mais arquivos:

```powershell
rtk proxy npx.cmd --offline supabase@2.116.0 db push --skip-vault --linked --project-ref evvbomzejfijozbtgvpt --workdir $D01NominalWorkdir --agent no --output-format text
```

A confirmação CLI deve continuar mostrando somente as duas migrations aprovadas.
O comando é nominal por construção do staging e confirmação do conjunto
pendente, não um push do checkout completo. A proposta revisa os delimitadores canônicos externos para permitir transaçãoCLIbatch por arquivo, preservando lock/hash/pre/postconditions. Não executar seu DDL por
`execute_sql`/SQL editor como alternativa.

5. Confirmar `migration list` e novo `db push --dry-run --skip-vault`, com os
   mesmos argumentos. Exigir versões **20260909173000/20260909173100** em LOCAL/REMOTE, nomes
   corretos, ausência de novas pendências e hashes/metadata/ACL dos três objetos
   previstos no pacote. Reconciliar o recibo no checkout canônico, que mantém
   o mesmo nome/version/bytes. Não promover outras pendências locais.

Em resposta ambígua, consultar histórico/catálogo antes de qualquer nova
tentativa. Falha ou drift não autorizam repair, renomeação, replay histórico
ou include-all; aplicar recuperação forward-only do pacote. O cleanup remove
somente o diretório TEMP próprio, depois de preservar recibos sanitizados e
validar novamente seu caminho absoluto; não tocar recursos Docker/alheios.

## O que ainda falta comprovar

Leitura agregada remota15:52 confirmou116versões e máximo20260901200206, sem colisão dos dois candidatos. Isso não substitui fotografia completa de staging nem prova acessibilidade CLI/credencial na janela. `fetch`, `link`, dry run e apply
acima não foram executados. O fluxo de fetch em diretório isolado é uma
proposta baseada em capacidade existente, não operação anterior certificada
do Coelo. D00 deve revisar/congelar esse staging e obter o dry run com conjunto exato de dois arquivos antes
de considerar o transporte qualificado para aplicar.

O bloqueio deixou de ser ausência de comando que preserve version: há CLI
com esse histórico verificável. Restam os dados e gates concretos acima,
sem necessidade de inventar approval, modificar migration antiga ou criar
novo executor de produção. Knowledge: no-op nesta qualificação documental.

## Gate material de atomicidade — atualização v2

A CLI2.116.0 executa arquivos com BEGIN/COMMIT próprios sequencialmente e insere ledger depois do COMMIT. Assim, os bytes atuais46PASS não são ledger-atômicos. A proposta revisa SOMENTE os delimitadores externos dos dois arquivos canônicos ainda não implantados, com novos hashes e prova. Nenhuma cópia de staging será transformada silenciosamente. [Proposta e fixture](transport-atomicity-proposal.md) registram a fonte oficial, patch não aplicado e dois gates locais pendentes; os26guards de ferramenta não provam atomicidade.

O caminho batch oferece atomicidade por arquivo segundo código, ainda a qualificar. O pacote inteiro não é atômico:173000 pode ficar aplicada/registrada se173100 falhar. Esse estado parcial exige reconciliação e próximo passo forward-only nominal, nunca repair ou retirada automática da proteção. Os comandos acima permanecem NÃO APTOS para execução remota até payloadfinal, provaCLIledger, revisão, hashesnominais e janela/autorização. Nenhum link/fetch/dry-run/apply foi executado nesta preparação.