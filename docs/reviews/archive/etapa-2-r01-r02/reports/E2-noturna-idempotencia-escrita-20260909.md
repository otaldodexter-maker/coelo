---
title: "Intenção de escrita gerada dentro da camada de dados — varredura"
source: "execução própria do grupo operacoes-sistema sobre a base d784462c1"
status: "medição e encaminhamento; apenas o recorte operacoes-sistema foi corrigido"
generated_at: "2026-09-09"
group: "operacoes-sistema"
branch: "work/etapa2-noturna-operacoes-sistema"
---

# Intenção de escrita gerada dentro da camada de dados

## O defeito

Uma chave de idempotência serve para que a **repetição da mesma intenção** seja
reconhecida pelo servidor. Se ela nasce dentro do repositório, uma por chamada,
ela deixa de identificar a intenção e passa a identificar a tentativa: toda
repetição chega como um comando novo.

Em atualização o dano é limitado, porque `p_expected_revision` barra a segunda
escrita. Em **criação e publicação não há revisão esperada**, então um retry
depois de uma falha incerta — timeout, queda de rede, resposta perdida — executa
a operação uma segunda vez.

Isto foi encontrado primeiro em Cardápios, depois em Agenda, e a varredura mostra
que é uma **classe** e não dois casos.

## Já corrigido no recorte operacoes-sistema

| Onde | Commit |
| --- | --- |
| Cardápios: `publish` e `submitForReview` | `1ac657de6` |
| Agenda: `save`, `command` e `decide_publication` | `29fa6ff13` |

Em ambos a intenção passou a ser memorizada por comando e argumentos, reusada
enquanto o comando não confirma e descartada quando confirma. Mudar o rascunho,
ou autorizar um override, muda os argumentos e portanto é uma intenção nova.

## Encontrado fora do recorte, não tocado

Estes seguem gerando a intenção inline. A classificação é por RPC, e todos os
listados são **escrita**, não leitura.

| Arquivo | RPC | Grupo provável |
| --- | --- | --- |
| `attendance/data/supabase_attendance_repository.dart` | `superadmin_attendance_create_call` | alunos-rotina |
| idem | `superadmin_attendance_clear_presence_marks` | alunos-rotina |
| idem | `superadmin_attendance_set_participant` | alunos-rotina |
| idem | `superadmin_attendance_complete_call` | alunos-rotina |
| `units/data/supabase_unit_directory_repository.dart` | `create_unit_for_superadmin` (2 sítios) | estrutura |
| `groups/data/supabase_group_directory_repository.dart` | `superadmin_group_export_create` | estrutura |
| `principal_happens_publication/.../supabase_happens_publication_repository.dart` | `save_happens_draft` | publicacoes-midia |
| idem | `publish_happens_post` | publicacoes-midia |
| `principal_now_publication/.../supabase_now_publication_repository.dart` | `save_now_draft` | publicacoes-midia |
| idem | `publish_now` | publicacoes-midia |
| `principal_happens/.../supabase_principal_happens_feed_repository.dart` | `withdraw_happens_post` | publicacoes-midia |
| `principal_moments/.../supabase_principal_moments_feed_repository.dart` | `withdraw_moment` | publicacoes-midia |

Os mais sensíveis são `publish_happens_post`, `publish_now` e
`create_unit_for_superadmin`: publicação para famílias e criação sem revisão
esperada são exatamente os casos em que a repetição não tem o que a barre.

## Um caso limítrofe

`meal_plans/data/supabase_meal_plan_repository.dart` usa
`draft.requestId ?? _requestId()`. O chamador do assistente passa um
identificador estável, então o caminho normal está correto; o `??` é um recuo
silencioso para intenção nova caso algum chamador futuro esqueça de passá-la.
Não é defeito hoje, é um convite a um.

## O que NÃO foi feito

Nenhum arquivo fora de `agenda`, `plans` e `meal_plans` foi alterado. A lista é
para distribuição pela coordenação aos grupos donos. Também não afirmo que cada
RPC listada seja de fato não idempotente no servidor: algumas podem deduplicar
por conteúdo ou por checksum. O que está afirmado é que **o cliente perdeu a
capacidade de repetir a mesma intenção**, e essa é uma condição necessária para
a proteção funcionar de qualquer lado.
