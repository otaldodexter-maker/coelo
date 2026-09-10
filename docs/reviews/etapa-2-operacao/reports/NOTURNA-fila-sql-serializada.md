---
title: "Fila SQL serializada da rodada noturna 09→10/09/2026"
source: "Coordenação e Integração — Claude; candidatos publicados pelos grupos"
status: "active"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Fila SQL serializada

Nenhum destes pacotes foi aplicado em ambiente algum. Todos são **candidatos
locais revisáveis**. O projeto Supabase `coelo` é produção e o Owner ficou
indisponível a partir das 18:26 de 09/09, portanto nenhuma autorização nominal
pôde ser concedida nesta rodada.

## Colisão encontrada na integração

Três grupos, trabalhando em worktrees isoladas, escolheram independentemente o
mesmo carimbo `20260909190000`, e o grupo de Chat escolheu carimbos
(`20260909130000`, `20260909140000`) anteriores a cinco migrations que já
existiam na base. Worktrees separadas não impedem colisão lógica: a ordem da
fila é global e pertence ao integrador.

Ordenação atribuída por **ordem real de integração em `dev`**, forward-only,
depois da cauda existente `20260909174500_d04_access_models_scope_filter.sql`.
O conteúdo dos arquivos não foi tocado — o SHA256 é idêntico antes e depois do
renome.

| Ordem | Arquivo (nome final) | Carimbo original | Grupo | SHA256 |
| ---: | --- | --- | --- | --- |
| 1 | `20260909190000_superadmin_internal_audit_read_v2.sql` | `20260908230039`, já corrigido pelo autor | operacoes-sistema | `3a141214…1729b2` |
| 2 | `20260909191000_superadmin_internal_chat_receipts_edit_revoke_v2.sql` | `20260909130000` | chat-comunicacoes | `9ef0b1e9…e32e77` |
| 3 | `20260909191100_superadmin_notice_metrics_by_generation_v1.sql` | `20260909140000` | chat-comunicacoes | `a3652244…43e279` |
| 4 | `20260909192000_superadmin_location_consumer_bindings_v2.sql` | `20260909190000` | estrutura | `4c08a29e…c82ddd` |
| 5 | `20260909193000_d04_child_safety_internal_reads.sql` | `20260909190000` | acessos-pessoas | `601e7819…d302d8` |
| 6 | `20260909200000_superadmin_activity_location_create_v2.sql` | inalterado | estrutura | — |

Além destes, o pacote nominal de Modelos (`AP-MODELS-NOMINAL-20260909-v1`,
acessos-pessoas) e o candidato `get_profile_about` (perfil-para-voce) existem
como planos em `packages/coelo_database/plans/`, sem carimbo de migration.

## Consequências registradas

- Manifests e handoffs dos grupos citam os carimbos **originais**. Esta tabela
  é o mapeamento autoritativo; o conteúdo verificado por hash é o mesmo.
- Renomear ordena a fila, mas **não** substitui o preflight contra o alvo real.
  Nenhum destes pacotes teve preflight executado contra produção.
- A verificação estática de pré-requisitos feita pelos autores permanece válida
  como evidência de revisão, não como prova de aplicabilidade.
