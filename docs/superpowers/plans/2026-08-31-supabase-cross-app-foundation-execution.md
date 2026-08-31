---
title: "Execução da fundação Supabase cross-app"
source: "Prompt aprovado pelo Owner Coelo em 2026-08-31; decisions/0019-superadmin-internal-identity.md; specs/039-superadmin-internal-auth-session-context.md; inventário read-only de 2026-08-31"
status: "in-progress-gates-3-of-4"
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

As migrations forward-only `20260831130726_reconcile_permission_labels_after_replay.sql` e `20260831134407_harden_access_profile_capability_core.sql`, criadas pelo CLI 2.116.0, fecham o replay e o núcleo de capacidades. O segundo delta impede allow+deny ativos simultâneos por capability/escopo, qualifica o domínio Principal e reduz overrides antes da agregação JSON. Replay focado, dez arquivos pgTAP e 270 asserts passaram; Auth, instituições, unidade, grupo, pessoa e o núcleo de Access Profiles estão verdes. O lint global continua RED somente por erros históricos de Activity/Import-Export e pelo import de Access Profiles, todos fora do núcleo contratado; nenhum achado ficou sem classificação.

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
