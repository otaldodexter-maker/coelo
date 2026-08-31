---
title: "Execução da fundação Supabase cross-app"
source: "Prompt aprovado pelo Owner Coelo em 2026-08-31; decisions/0019-superadmin-internal-identity.md; specs/039-superadmin-internal-auth-session-context.md; inventário read-only de 2026-08-31"
status: "local-green-consolidation-ready"
generated_at: "2026-08-31"
---

# Execução da fundação Supabase cross-app

## Contrato

- Orçamento: quatro dias focados; nível `Avançada`; modalidade `macrotema`.
- Incluído: migrations/mirror/ledger, Auth interno, sessão, identidade, hierarquia, memberships aprovadas, RLS, grants, auditoria, índices, pgTAP e rastreadores.
- Fora: `apps/**`, UI/UX, novos produtos Admin/Principal, MFA como nova feature, arquivos/mídia, Edge Functions novas e qualquer mutação remota sem autorização nominal.
- Parada: primeiro gate incompleto. O remoto permanece `blocked-environment` e read-only.

## Estado reutilizado

A migration canônica `20260827233000_superadmin_internal_auth_context.sql` e seus testes já materializam a spec 039 localmente. A execução não duplica schema: primeiro reconcilia e revalida esse contrato; migration nova só nasce após RED correto e pelo comando `supabase migration new` descoberto no CLI 2.116.0.

## Ordem TDD e comandos

1. Preparar e verificar o mirror com `Sync-SupabaseCliMigrations.ps1 -Mode Prepare/Verify`.
2. Executar replay descartável pelo wrapper `Invoke-SafeLocalMigrationReplay.ps1`, nunca pelo staging interno.
3. RED estrutural: executar `superadmin_internal_auth_context_test.sql` contra baseline anterior a `20260827233000`; deve falhar pela ausência das tabelas/helper/wrappers.
4. GREEN Auth: aplicar somente a migration Auth e executar 29 asserts pgTAP.
5. Regressão autorizadora: executar, em ordem, Auth, detalhe/lista/edit de Instituições, detalhe de Unidade, Grupo e Pessoa; exigir negativas sem sessão, AAL, lifecycle, capability/grant, tenant A/B, sibling e cross-app.
6. Verificar owners, `search_path=''`, EXECUTE, FORCE RLS, policies, default ACL, FKs e índices do delta.
7. Executar `git diff --check`, mirror SHA-256, secret scan e cleanup de Docker.
8. Atualizar fontes canônicas, rastreador Supabase e rastreador integrado sem promover Flutter/E2E.

## Estado executável atual

O Docker Desktop 4.86.0 foi reparado sem apagar imagens ou volumes: os diretórios de runtime com sockets AF_UNIX corrompidos foram movidos para backups e o daemon 29.7.2 voltou a responder. O replay integral reproduz dois drifts fora do recorte (`platform_permissions` sem labels/defaults e Import/Export removido). O perfil `-FoundationOnly` é fechado por manifesto SHA-256: aplica exatamente 51 migrations canônicas revisadas e dois preflights de replay, sem admitir migrations futuras ou mascarar o RED integral.

As migrations forward-only `20260831130726_reconcile_permission_labels_after_replay.sql` e `20260831134407_harden_access_profile_capability_core.sql`, criadas pelo CLI 2.116.0, fecham o replay e o núcleo de capacidades. O segundo delta impede allow+deny ativos simultâneos por capability/escopo, isola sibling units/groups, qualifica o domínio Principal e oferece gateways nominais com ACL efetiva. Replay focado, dez arquivos pgTAP e 278 asserts passaram; Auth, instituições, unidade, grupo, pessoa e o núcleo de Access Profiles estão verdes. O lint global continua RED somente por erros históricos de Activity/Import-Export e pelo import de Access Profiles, todos fora do núcleo contratado; nenhum achado ficou sem classificação.

## Evidência read-only de 2026-08-31

- Canônico/mirror temporário: 114/114 após `Prepare` e `Verify` com SHA-256 por arquivo; o cleanup preserva os 17 mirrors legados rastreados e remove somente staging ignorado.
- Ledger remoto: 103; última `20260821200000_profile_about_remote_context_compatibility`.
- Manifesto: 50 coincidências de versão/nome no ledger, sem prova de conteúdo remoto; 8 nomes lógicos em versões divergentes por lado; 54 locais sem nome remoto e 45 remotos sem nome local.
- Remoto: 180 tabelas públicas com RLS habilitada; 87 com FORCE RLS; 3 tabelas audit, sendo `audit.profile_about_commands` sem RLS.
- Funções públicas: 223; 205 SECURITY DEFINER; 156 SECURITY DEFINER executáveis por `authenticated`.
- Advisors: segurança 207 (50/156/1); desempenho 505 (128/377).
- Edge Functions: 10; `form-operations` e `circular-media` com `verify_jwt=false`, apenas classificadas.

## Próximo comando seguro

Repetir o gate focado com pgTAP e lint visível:

```powershell
& packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion 20260831134407 -FoundationOnly `
  -TestPath packages/coelo_database/supabase/tests/superadmin_internal_auth_context_test.sql `
  -RunLint
```

O pgTAP deve permanecer GREEN; o lint global permanece RED até os erros históricos serem reconciliados por pacote. Não usar o remoto como substituto.

## Fechamento local de 2026-08-31

Os quatro gates do macrotema foram executados localmente. O replay fechado aplica
51 migrations canônicas revisadas e dois preflights até `20260831134407`, roda
dez arquivos pgTAP com 278 asserts e remove os recursos Docker temporários. O
manifesto passou a calcular SHA-256 sobre texto UTF-8 normalizado em CRLF, de
modo que LF/CRLF da checkout não alteram a identidade lógica das migrations.
`Prepare` e `Verify` confirmaram 114/114 migrations canônicas/mirror.

O remoto `coelo` permanece `blocked-environment`, read-only e fora de
`remote-green`; não houve push, deploy, DDL/DML, alteração Auth ou migration
remota. O lint global continua vermelho apenas pelos erros históricos já
classificados de Activity/Import-Export, fora do núcleo contratado. O gate de
conhecimento foi `no-op`: nenhuma regra durável de produto nova nasceu deste
fechamento técnico.

## Retomada verificada de 2026-08-31 13:08 BRT

A execução foi retomada em worktree limpa
`codex/supabase-foundation-continuation`, criada de `dev` em `e0404638`. O
mirror precisou do passo documentado `Prepare` antes de `Verify`; ambos
confirmaram 114/114 arquivos. O wrapper RTK de PowerShell não disponibilizou
`Get-FileHash`, portanto o sync foi executado pelo cmdlet PowerShell nativo,
exceção registrada conforme `RTK.md`.

O replay descartável voltou a aplicar 51 migrations canônicas e dois
preflights até `20260831134407`. A prova focal Auth passou 29/29 e a regressão
completa passou dez arquivos pgTAP/278 asserts, com teardown sem container,
volume ou rede residual. O lint executou depois dos testes e repetiu quatro
erros históricos: dois `42702` em importação de Activity/Groups, um `42804` em
importação de Access Profiles e um `42703` no fluxo de file job. Esses objetos
continuam fora do recorte sem autorização para importar/exportar/arquivos; não
houve tentativa de corrigi-los por acidente.

O inventário oficial read-only confirmou projeto saudável, ledger 103, dez
Edge Functions, Advisors 207/505, 180 tabelas públicas com RLS e três tabelas
`audit`, uma sem RLS. O remoto continua sem classificação documental de
desenvolvimento/homologação/produção e não recebeu qualquer mutação.

## Continuação executada — guard de proveniência de hierarquia

O inventário remoto SELECT-only confirmou `units.unit_type_id -> unit_types`,
enquanto ADR 0016/spec 017 e o perfil local aprovado exigem
`units.institution_type_id -> institution_types`. Em vez de inferir uma
conversão, foi criado pelo CLI 2.116.0 o delta forward-only
`20260831164937_assert_unit_hierarchy_contract.sql`. O guard privado resultante
falha cedo com SQLSTATE `55000` se a cadeia apresentar coluna, catálogo, FK ou
índice incompatível; não expõe endpoint nem altera dados, RLS ou grants de
tabelas.

TDD: o teste novo falhou antes da migration pela ausência da função. Após a
implementação e a correção da inspeção de FK para usar catálogos, o mesmo teste
passou 7/7, incluindo o formato remoto divergente criado e revertido na própria
transação. O replay fechado agora aplica 52 migrations canônicas e dois
preflights até `20260831164937`; a regressão passou 11 arquivos/285 asserts.
`Prepare` e `Verify` confirmaram 115/115 migrations. O lint manteve os quatro
erros históricos já classificados de importação e arquivo; esses recursos
existentes foram preservados e apenas permanecem fora deste pacote.

Docker Desktop 4.86.0 voltou a operar com engine 29.7.2 após o reset realizado
na interface e a desativação do recurso opcional Docker AI que recriava o socket
AF_UNIX inválido. O replay terminou com zero recurso `coelo_safe_*` residual.
O remoto continua read-only, `blocked-environment`, sem `remote-green` ou
`done`; OQ-032 permanece aberta para a escolha canônica antes de qualquer
mutação remota.

## Continuação executada — Supabase Auth full-stack

O wrapper descartável ganhou o modo `-RunAuthLifecycle`, mantendo GoTrue,
PostgREST e Kong somente durante a prova. O primeiro RED revelou que o nome do
projeto Docker de 43 caracteres era truncado pelo Compose; a identidade foi
limitada a 40 caracteres para que criação, acesso e verificação de resíduos
usem o mesmo nome. O segundo RED confirmou corretamente que memberships
internas são append-only; a fixture passou a permanecer apenas no volume
efêmero, destruído pelo teardown.

O GREEN executou cadastro sintético, bootstrap do contexto interno, logout,
login por senha, novo bootstrap, refresh, bootstrap com token renovado, logout,
recusa do refresh e envelope `SAI_SESSION_INVALID` para o JWT revogado. Nenhum
token ou senha foi impresso e o wrapper confirmou zero container, volume, rede
ou diretório residual. A prova é `local-green`; o remoto não foi alterado.

O RED focal de Activities passou 62/70 e falhou em oito pontos. Parte pertence
a migrations de catálogo local-only excluídas intencionalmente do perfil; a
lacuna estrutural é que os comandos legados continuam people-based e não
aceitam a identidade interna da ADR 0019. O conflito foi registrado como
OQ-043; não houve adaptação silenciosa, pessoa sintética ou trabalho em
importação, exportação, arquivo, mídia ou Flutter.
