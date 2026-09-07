---
title: "Unidades e Grupos — ações de arquivo pós-MVP"
source: "ADR 0031; prompts-etapa-2-e2e.md, Prompt 3; diff e testes locais"
status: "local-green; não verified-e2e"
generated_at: "2026-09-07"
---

# Recorte e resultado

Branch `codex/e2e-estruturas-pessoas-locais`, base
`1150ca30cb5fe414bf28b4aadabb3abcc85d4dec`.
IDs: `units.import`, `units.export`, `groups.import`, `groups.export`.
Somente diretórios de Unidades e Grupos do Superadmin.

O toolbar de Unidades usa agora `CoeloAdminFileActions` com os mesmos
ícones, rótulos, keys e comportamento compacto. Os três callbacks mostram
`Disponível depois do MVP`. Não instanciam `UnitFileActions`, abrem importador,
chamam gateway nem criam atividade demonstrativa. O widget legado e seus testes
permanecem congelados fora do wiring runtime para eventual trabalho pós-MVP.
Grupos mantém o componente existente e alinha a mensagem dos três callbacks.

## Evidências locais

- RED: 4 falhas esperadas (três cliques Unidades e mensagem de Grupos),
  todas por ausência da mensagem normativa; 1 outro teste selecionado passou.
- GREEN final: 38 testes dos dois arquivos de diretório passaram.
- Unidades: três ações, gateway presente/ausente, spy sem chamadas,
  atividades vazias, nenhum importador/picker ou anúncio de exportação.
- Grupos: três ações, aviso normativo e ausência de Dialog; regressão de
  ausência de sucesso demonstrativo preservada.
- Analyzer dos quatro arquivos alterados: nenhum problema.
- Validador de contratos visuais administrativo: exit 0.
- Review independente read-only: nenhum achado bloqueante; sugestão de
  exercitar CSV em Grupos incorporada antes do GREEN final.

Comandos, em `apps/superadmin`:

```text
rtk flutter test --no-pub test/features/units/presentation/unit_directory_page_test.dart test/features/groups/presentation/group_directory_page_test.dart
rtk flutter analyze --no-pub lib/features/units/presentation/widgets/unit_directory_toolbar.dart lib/features/groups/presentation/group_directory_page.dart test/features/units/presentation/unit_directory_page_test.dart test/features/groups/presentation/group_directory_page_test.dart
```

Validador em `apps/catalog`:

```text
rtk proxy C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe run tool/validate_admin_visual_contracts.dart ../.. assets/admin-visual-contract-allowlist.json
```

## Limites e handoff

Sem alteração de Supabase, Cloudflare, migration, router, shell, API compartilhada
ou trackers centrais. Sem lease nem chamada remota. Testes usam repositórios
locais sintéticos; não constituem execução no Superadmin produtivo, validação
visual completa ou conclusão dos diretórios. Primeiro gate aberto: comprovação
da composição produtiva e estados aplicáveis em ambiente real.

Delta solicitado ao Coordenador nos trackers: registrar correção local e
evidências destes quatro IDs, sem promovê-los em bloco para verified/done/E2E.
Outras ações de arquivo de formulário/pessoas permanecem fora deste pacote.

Gate de memória: nenhuma decisão nova; regra canônica já aprovada preservada.
Não criada projeção de conhecimento duplicada apenas para registrar atividade.
