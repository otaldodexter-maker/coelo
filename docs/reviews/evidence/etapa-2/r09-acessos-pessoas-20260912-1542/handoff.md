---
source: "R09-prompts; coordenacao r96; rastreadores; lote59-preflight; ciclo210-people-result"
status: "fila; prova UI pendente"
generated_at: "2026-09-12T16:06:43-03:00"
---

# R09 G2 ? Acessos e Pessoas

Round E2-R09-20260912-1542. Unico C0: `01a096ed-314b-7c13-a9e0-3e64649e66fc`, host local. G2: `01a096ed-ea61-7cb1-8ba0-b7f65dec4bf9`. ACK161 publicado em `40e9b1632`; checkpoint162 solicita vaga pelo JSON proprio. Sem posse de Chrome, Flutter test ou SQL. Checkout principal intocado.

Primeira fatia: apps/superadmin -> Pessoas -> criar/editar pessoa e @ -> `people.create`/`people.edit`; incluir filtros H28 de `people.list`. Familia administrativa. Objetivo: provar UI normal, persistencia, reload e autorizacao com sinteticos. Parada: primeiro corte C0 ou dependencia sem trabalho independente autorizado. ETA E2E depende do runtime medido e da vaga; nenhuma duracao inventada.

| Acao | Base conhecida | Prova restante |
| --- | --- | --- |
| people.create | FE local-green; BE done; resolvedor170700 integrado | Criar sintetico pela UI, @ conforme contrato, reler e reload; conferir negativa aplicavel |
| people.edit | FE local-green; BE done; update concorrente ja provado no backend | Editar sintetico e @ pela UI, disponibilidade/cooldown, persistencia e reload |
| people.list / H28 | Certificado historico preservado; SQL59 aplicado; flag true | Filtros contextuais e reload na UI integrada; nao contar aceite novo da listagem inteira |

H28: `../r08-coordenacao/lote59-preflight.json` confirma aplicacao, assinatura unica com17 argumentos e44 pgTAP/0falhas. `../r08-coordenacao/ciclo210-people-result.json` confirma19PASS/0FAIL/exit0. Fixture A/B de G5 teve rollback: nao presumir sua presenca em producao. Handoff antigo G2 dizia SQL/flag pendentes; fechamento C0 e prova posterior supersedem esse estado. Nao repetir migration nem suite verde.

Pedido C0 no JSON: confirmar ACK e informar vaga, runtime/base, transferencia nominal Chrome/PID/expiracao e contexto sintetico elegivel para H28. Depois de fechar Pessoas: perfis editar/atribuir/excluir, modelos editar/duplicar e convites executaveis. Sem modelos de sistema, pessoas reais, senha, SMTP presumido ou Etapa3.

Nenhum teste de produto executado neste checkpoint; nenhum delta FE/BE/E2E. Conhecimento: no-op, sem regra duravel nova. Nome pretendido da conversa: R09 ? G2 ? Acessos e Pessoas; ferramenta de renomear indisponivel.
