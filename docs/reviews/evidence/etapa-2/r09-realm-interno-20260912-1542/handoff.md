---
source: docs/reviews/etapa-2-operacao/comunicacao/coordenacao.json; docs/reviews/etapa-2-operacao/next-round/R09-backlog.md; docs/reviews/evidence/etapa-2/r08-estrutura/handoff.md; docs/reviews/evidence/etapa-2/r08-coordenacao/ciclo120.md
status: gate-inicial-revisado-sem-promocao
generated_at: 2026-09-12
---

# G5 — apoio BE à primeira fatia G1

Round `E2-R09-20260912-1542`, C0 único
`01a096ed-314b-7c13-a9e0-3e64649e66fc`, host `local`.
G5 `01a096ee-9b56-7a12-942a-932b1903458e` adotou a revisão C0 96.
Base inspecionada `7907453f0362665ab87fe8faaa4854f286904148`.

Objetivo: distinguir provas reaproveitáveis e primeiro gate BE de G1, sem
reescrever provedores verdes. Incluído: apps/superadmin → Estrutura → Turmas
→ Membros/Local e Avaliações → configuração/lançamento/diário/detalhe.
Fora: UI, auditoria ampla, outros apps, Etapa 3, aplicação/deploy e rastreadores.
Ordem: Turmas, cadeia Avaliações existente, próximo lote nominal C0.
Parada deste ciclo curto: entregar as lacunas documentadas; SQL/E2E não
liberados na revisão 96. Sem estimativa de execução remota antes da posse.

| action_id / consumidora | Evidência reaproveitável | Gate restante |
| --- | --- | --- |
| groups.members / G1 | Rastreador BE aponta leitura por superadmin_group_detail_v2 e escrita por superadmin_group_save; cliente contém ambos | Adicionar/remover vínculo sintético, reler e provar negativa de contexto. Nenhuma prova real suficiente localizada neste recorte para promover BE |
| groups.location / G1 | Correção do consumidor integrada por C0 na R08; ciclo120 registra teste focal 29 PASS/0 FAIL; rastreador referencia RPC atômico e bindings aplicados no lote10 | Local autorizado na unidade da turma, persistência/releitura e negativa real de hierarquia/contexto. Não repetir correção ou suíte verde sem delta |
| activities.assessment / G1 | assessments-api-execution-20260912.json prova configuração ativa v2, período aberto e releituras | Negativa real do contrato; UI segue separadamente com G1 |
| assessments.entry, assessments.gradebook / G1 | Mesmo JSON prova criação/releitura do diário draft v1 | Confirmar aluno sintético elegível na turma/atribuição; lançar nota no diário existente, reler e provar negativa. Payload students: [] da R08 não prova nota nem ausência atual de aluno |
| assessments.detail / G1 | Diário existente é recurso reaproveitável; handoff R08 explicita transições não executadas | Conferir leitura autorizada/negação do detalhe; transições só no recorte confirmado C0/G1, sem inventar RPC |

O termo “prova integrada” em handoff R08 de groups.location refere-se à base
de código/testes: ciclo120 e groups-location-preparacao.md mantêm rota real
pendente. Não há conflito de produto nem motivo para alterar open-questions.

Preservar configuração `833a89d8-466f-4ff4-8ab9-4ffb7f33a1cb`, período
`c4e38ada-e062-4466-a22d-88dca177fa30` e diário
`d2c945d8-3809-4d84-b836-2bc6da7c381d`. Esses estados são os medidos na R08,
não uma consulta atual. Não recriar a cadeia. O contrato de fixture existente
está em `docs/reviews/evidence/etapa-2/r08-estrutura/fixture-assessments-contract.md`.

Próximo gate proposto a C0/G1: usar a primeira visita autorizada a Turmas para
conferir vínculo e Local; G5 apoia a negativa BE quando houver posse/recurso.
Para Avaliações, conferir o aluno elegível antes de qualquer lançamento. Se
faltar fixture, atribuir nominalmente sua preparação e espelho a G5/G0; nenhum
lote novo ou alteração de função compartilhada foi assumido neste ciclo.

Novos testes de produto: 0; novos aceites FE/BE/E2E: 0; deltas de estado: nenhum.
Nenhum candidato SQL, fixture remota, segredo ou deploy novo. SQL56–59 não
reaplicados. Memória: no-op, sem regra de produto nova. C0 integra este handoff
e decide o próximo pacote; a falha do canal de mensagens não impede recebimento
pela branch própria.
