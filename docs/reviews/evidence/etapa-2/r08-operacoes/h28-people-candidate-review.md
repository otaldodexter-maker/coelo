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

Os commits G2 `71e45d3ad` e `1cbc1f6a0` acrescentaram o adapter, o mapeamento de opções e os campos de atividade no payload. Eles resolvem os itens 1--3 acima no código preparado, mas introduziram/retiveram um bloqueio de rollout: `createSuperadminAuthScope` instancia `contextFiltersAvailable: true`. Isso faz o cliente enviar os quatro argumentos novos enquanto a assinatura SQL produtiva antiga ainda vigora, contrariando o comentário de que o recurso ficaria desligado até a serialização e causando falha de assinatura PostgREST.

O commit documental `a5e3184e8` diz que o rollout está desligado, mas não muda essa instanciação. A evidência de configuração deve ser corrigida para `false` até uma confirmação central pós-lote, ou substituída por uma capability/versionamento remoto verificável. O conjunto A/B de pgTAP continua pendente de asserts executáveis.
