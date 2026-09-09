---
source: "D00 review; D01 R16 versioning qualification; Supabase CLI v2.116.0 official source; canonical AMR package and 36e8e4c0b"
status: "read-only-review; transport-candidate-identified; current-payload-not-ledger-atomic; U46-35P1F"
generated_at: "2026-09-09"
---

# Revisão final do transporte AMR, atualização após D01 R16

O patch documental anterior `amr-package-review.patch` ainda passa em
`git apply --check` contra o documento canônico, mas não deve ser integrado
como pacote final: contém aprovação futura para um arquivo e MCP. A U46
informada por D00 está em 35 aprovados / 1 falho; D01 prepara
`20260909173100_superadmin_password_session_denial_audit.sql`, além da
`20260909173000_superadmin_password_session_context.sql`. A próxima proposta
precisa de identidade v2, dois arquivos/SHAs, objetos afetados e recibo atualizado.

## Transporte disponível e limite demonstrado

O help local offline da CLI fixada 2.116.0 confirma `db push --dry-run`,
`--skip-vault`, `--linked`, `--project-ref` e `--workdir`. A CLI global é
2.117.0 e não deve substituí-la implicitamente. O MCP disponível continua
sem parâmetro version; não serve para impor o timestamp local.

A proposta D01 de staging nominal novo com histórico aplicado obtido por
`migration fetch`, mais exclusivamente os dois arquivos aprovados, é um
caminho concreto para preservar versões. A CLI extrai versão e nome do
basename do arquivo. Exigir conjunto pendente exato de DOIS arquivos, ambos
posteriores ao máximo remoto, não apenas procurar seus nomes na saída.
Não usar include-all/roles/seed, replay coelo_safe ou espelho canônico completo.
A [referência oficial CLI](https://supabase.com/docs/reference/cli/supabase-db-push)
confirma o papel de push/fetch; a atomicidade exige examinar o executor.

**O payload atual BEGIN...COMMIT não é atômico com seu ledger pela CLI 2.116.0.**
Na [fonte oficial fixada](https://github.com/supabase/cli/blob/v2.116.0/apps/cli/src/legacy/shared/legacy-migration-apply.ts#L630),
linhas 630–634 derivam a versão; 697–701 detectam controle transacional autoral
e escolhem execução sequencial. Nesse caminho, 640–653 executam todos os
statements, inclusive COMMIT, e só 666–673 inserem a versão no ledger.
Existe intervalo real entre commit do helper e INSERT do histórico.

A alternativa mínima a qualificar localmente é preparar novas revisões dos
dois arquivos ainda não implantados, retirando somente os BEGIN/COMMIT de
nível superior e preservando os demais guards, SET LOCAL e advisory lock.
Sem controle transacional autoral, diretiva não transacional ou statements
incompatíveis, a CLI inclui o INSERT do ledger no mesmo batch da migration
(linhas 710–748 dessa fonte). O [driver fixado](https://github.com/supabase/cli/blob/v2.116.0/apps/cli/src/legacy/shared/legacy-db-connection.sql-pg.layer.ts#L297)
envia as operações antes de um único Sync. Essa é a base verificável para
atomicidade por arquivo; ainda falta o ensaio local discriminante abaixo.
Não retirar delimitadores apenas no staging: revisar fonte canônica, recalcular
os hashes RAW/LF e obter as provas do payload final. Nenhuma edição SQL foi
feita nesta revisão.

Dois arquivos são duas aplicações transacionais. O pacote inteiro não se
torna atômico: se 173000 aplicar e 173100 falhar, o primeiro pode permanecer
aplicado e registrado. O pacote deve prever esse estado parcial e recuperação
forward-only; não prometer rollback automático do primeiro arquivo. Se o
requisito for atomicidade conjunta dos dois, esse transporte/pacote não a
entrega e exige redesenho explícito, não concatenar SQL silenciosamente.

## Cuidado concreto com os comandos de leitura CLI

A [resolução oficial de conexão 2.116.0](https://github.com/supabase/cli/blob/v2.116.0/apps/cli/src/legacy/shared/legacy-db-config.layer.ts#L102)
pode criar login role temporário com `read_only:false` quando não recebe senha
do banco (102–116; 295–300). Nesse ramo, falhas repetidas podem remover network
bans (119–126; 157–161). Portanto nomes como fetch/list/dry-run não tornam
todo o caminho somente leitura.

Para manter o pacote sem criação de roles/unban, o caminho proposto precisa
exigir credencial de banco já provisionada em `SUPABASE_DB_PASSWORD`, proveniente
do secret store, antes de link/fetch/list/push; a senha nunca vai a argumento,
log ou evidência. O ambiente/staging deve corresponder ao projeto vinculado
exato; qualificar o ramo que usa essa senha, sem fallback para login role.
Se a credencial/caminho não estiver disponível, parar antes dos comandos; não
ampliar o pacote para criação de role ou desbloqueio de rede. A revisão não
leu credenciais nem sondou sua existência.

## Delta exigido no documento D01 antes de aprovação futura

1. Substituir “única migration/dry-run um arquivo” pelo inventário final
   nominal das versões 20260909173000 e 20260909173100, SHA RAW de cada payload,
   SHA LF/Git e commit integrado que contém ambos. Os hashes anteriores de
   173000 deixam de identificar payload final se seus delimitadores mudarem.
2. Fixar CLI 2.116.0/staging nominal como proposta de transporte; retirar a
   chamada MCP de mutação como caminho ativo. Preservar MCP de catálogo/histórico
   somente no escopo remoto futuramente autorizado.
3. Incluir pré-condição de credencial e ausência de fallback mutante, conjunto
   pendente exato de dois arquivos, `--skip-vault`, exclusividade D00 e
   verificação do staging sem `.env`, overrides, seeds, roles ou Vault copiados.
4. Registrar U46 atual 35P1F e correção em andamento; não reclassificar como
   sucesso. Vincular o novo recibo por base, hashes, universo e cleanup.
5. Após os gates, preparar a aprovação nominal do pacote v2, projeto
   `evvbomzejfijozbtgvpt`, dois hashes e janela preenchida. Nenhuma autorização
   existe ou é solicitada nesta revisão.
6. Manter pre/postflight de corpo/ACL/schema, ausência de colisão de ambas
   versões e reconciliação de resposta ambígua, incluindo aplicação parcial
   173000 registrada / 173100 ausente. Falha de preflight não é licença para
   repair, retry cego, retirar guard password ou alterar conta/mailbox.

## Prova local futura específica de atomicidade, sem execução agora

Quando o slot SQL for liberado, usar CLI 2.116.0 e banco descartável coelo_safe
validado. Qualificar um fixture sintético equivalente à forma final, com uma
DDL transacional identificável e falha deliberada somente no INSERT do ledger
do seu timestamp exclusivo. Exigir que DDL e linha de histórico estejam ambas
ausentes após a falha; um controle sem falha deve registrar versão nominal e
DDL juntas. Não instalar o mecanismo de falha em produção ou no replay de
outro executor. Essa prova verifica o acoplamento DDL/ledger e não se soma à
U46 de produto. Reusar o executor existente da CLI; não criar plataforma de
deploy paralela. Até lá, classificar atomicidade como inferida da fonte e
pendente de qualificação local.

Nada foi aplicado ao projeto Supabase, Docker ou banco local; nenhum staging
remoto foi criado, nenhum índice/tracker foi alterado. A pesquisa adicional
acessou apenas documentação e código oficiais públicos. O changelog Markdown
foi recusado pela ferramenta web por content-type; isso não foi apresentado
como changelog verificado. Knowledge: no-op, sem regra de produto nova.
