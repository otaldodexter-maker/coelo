---
source: G7 review of G2 candidate 2eebea3f4
status: blocked-before-serialization
generated_at: 2026-09-12T13:55:00-03:00
---

# H28 Pessoas — revisão do candidato

Revisei somente o candidato `2eebea3f4`, sem editar arquivos da G2 nem aplicar SQL. Há acertos estruturais: a seleção de instituição/unidade/turma/papel/atividade/localidade é feita por um único `exists` em `context_rows`, e `total_count` é calculado de `filtered` antes de `ranked/page_rows`.

O pacote não é certificável nem deve entrar na fila ainda.

1. O cliente atual não envia `p_activity_ids`, `p_state_codes`, `p_municipality_ids` ou `p_neighborhood_ids` à RPC. O repositório também ignora as quatro coleções novas de `superadmin_people_filter_options`; aplicar apenas o SQL mantém H28 inoperante.
2. `_options` só mapeia `institution_id` e `unit_id`. Ele não preserva `state_code` e `municipality_id`, necessários para a cascata UF → município → bairro existente no ViewModel.
3. O payload `memberships` do candidato continua sem `activity_id`/`activity_name`, embora o domínio Dart exponha esses campos. Não certificar a visão de atividade sem uma fonte real no payload e mapeamento correspondente.
4. O pgTAP executável valida assinatura/ACL e faz leitura com defaults, mas as regressões funcionais A/B estão apenas em comentário. Antes da serialização, a fixture deve provar: pessoa exclusivamente B invisível para A; violações `23514` de unidade/turma fora do contexto; pessoa A+B não satisfaz combinação de linhas distintas; atividade A inclui só profissional/criança participante vigentes e exclui B/revogado/removido; filtros compostos e `total_count` sem duplicação antes da página.

Conclusão: preservar o candidato como WIP de contrato. Completar backend, testes A/B reais e o encaminhamento/desserialização Flutter antes de revisão para lote SQL. Nenhuma alteração remota ou certificação E2E decorre desta leitura.

## Atualização do candidato

Os commits G2 `71e45d3ad` e `1cbc1f6a0` acrescentaram o adapter, o mapeamento de opções e os campos de atividade no payload. A leitura do SHA completo `1cbc1f6a0` também confirma `contextFiltersAvailable: false` em `createSuperadminAuthScope`; a observação anterior, baseada no diff parcial do SHA anterior, foi retirada. O rollout permanece corretamente desligado até a serialização.

O commit `ad317fde0` preserva `role_name` a partir da linha institucional original, inclusive para perfil global. O conjunto A/B de pgTAP continua pendente de asserts executáveis.

## Proposta de fixture e asserts funcionais A/B

Em banco local descartável, usar um ator permitido e UUIDs fixos de fixture sob o prefixo `00000000-0000-4000-8000-0000000000xx`: instituição A `...01`, instituição B `...02`, unidade A `...11`, unidade B `...12`, turma A `...21`, turma B `...22`, atividade A `...31`, atividade B `...32`, pessoa somente B `...41`, pessoa mista A+B `...42`, profissional A `...43` e criança A `...44`. Os inserts devem satisfazer as FKs reais e ser desfeitos com `rollback`.

Os asserts pgTAP devem executar a RPC (não inspecionar texto SQL):

1. `p_institution_ids=A` não retorna a pessoa somente B.
2. `p_institution_ids=A,p_unit_ids=B` e `p_institution_ids=A,p_group_ids=B` lançam `23514`.
3. A pessoa mista não aparece com instituição A + unidade/turma/papel pertencentes somente ao contexto B.
4. `p_activity_ids=A` inclui profissional A e criança A participante; não inclui entidade B nem assignment/link revogado/inativo nem participant removido.
5. atividade A + UF/município/bairro A + segmento compõem na mesma linha; uma localidade B não passa por ter outro vínculo A.
6. duas linhas de atividade/localidade da mesma pessoa geram um único item e `total_count=1` com `p_limit=8` e também com paginação posterior.

Acrescentar assert de `role_name` para papel global (`institution_id is null`) e confirmar que `activity_id/activity_name` chegam no objeto membership. A fixture não deve ser aplicada remotamente, nem criar identidade real.
