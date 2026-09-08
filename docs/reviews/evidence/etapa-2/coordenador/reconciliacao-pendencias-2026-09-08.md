---
title: "Reconciliação de pendências — Etapa 2 E2E"
source: "dev 19b8f574; inventario-etapa-2.json; tracker-corrections-2026-09-08.json; evidências nominais das matrizes"
status: "open — revisão documental, não certificação E2E"
generated_at: "2026-09-08"
updated_at: "2026-09-08"
---

# Reconciliação de pendências

Substitui o fechamento anterior para planejamento. As três matrizes foram
cruzadas por 219 action_ids em 38 famílias. Cada linha separa o feito e o
limite da prova, o que falta em cada camada e sua fonte. O histórico integral
foi preservado em `docs/reviews/archive/2026-09-08/`.

- [Front-end](../../../coelo-flutter-pendencias.md).
- [Back-end](../../../coelo-supabase-pendencias.md).
- [Ponta a ponta](../../../coelo-flutter-integrado-supabase-pendencias.md).
- [Inventário cruzado](../../../inventario-etapa-2.json).

## Correções materiais

| Área | Evidência já existente | Gate restante, sem refazer o concluído localmente |
|---|---|---|
| Usuários internos | Users49 48/48 pgTAP local e composição do reader | UI/HTTP, paginação/PII e pacote nominal; comandos separados |
| Modelos | ModelReadGreen50 38/38 local | Runtime/escopo/produção; não refazer reader |
| Perfis | Diagnóstico ACL 42501 no cursor privado | EXECUTE/visibilidade de definições no wrapper nominal |
| Unidades/Turmas/Pessoas | Readers de detalhe compostos e provas locais | Listas/escritas e prova produtiva separadas |
| Locais | Script de snapshot com assertions de nível superior | Executar diretamente em PowerShell, não via descoberta Pester; depois replay SQL nominal |
| Alunos | DTO/adapter/controller/pipeline locais | UI/DI e replay SQL nominal não comprovados |
| Atividades | Adapter 51c02b75 integrado; A01GREEN55 97/97 local | UI→HTTP→reload e pacote nominal; comandos/avaliação separados |
| Avaliações | Migration v2 20260901182838, commit 831fb5a8 | Comparar adapter/RPC com v2 e replay 039; não criar backend do zero |
| Agenda | Reader f8a04b3a/controller 4daeafb9 e backend be28f0c0 | Delta visual de ca4c82ab revertido por fe6f6b51; replay/composição. Entrega de notificações fora da spec 050 |
| Forms | Contexto/callbacks/autosave/branching integrados; FREAD51 117/117 local | F-AUTHOR01/02 e SQL candidato; checkpoint f84d1dd7 teve +101/-1 (102 casos), não 100/101 |
| Preflight Forms | Central +48/-23 versus autor 71/71 sob Pester 3.4.0 | Reconciliar runner antes de atribuir 23 defeitos ao script |
| Respostas/XLSX | Autosave e seções integrados | Fonte autorizada/persistência e um XLSX de todas as respostas no R2 privado |
| Mídia/Chat | Acontece 50473bd8 16/16; Momentos 79/79 e guards locais | Gateway M03, R2 privado, audiência, revogação e prova por ação |
| Cuidado | Lifecycle/dispose corrigidos e prova funcional local | Decisões clínicas específicas, quatro diferenças golden registradas e backend/E2E |
| Assiduidade/Rotina | Provas visuais/funcionais e filtro implementado | Cutover interno/DTO e gateway; proposta SQL não é replay executado |
| Planos/Cardápios | Spec 051 aprovada, backend/repository/form e versionamento | Conflito 051/039 e crosswalk activate/assign versus escopo aprovado; persistência/publicação |
| Auditoria/Suporte | Cursor/sessão e toolbar/paginação locais | Wrappers internos nominais e detail/reply/close conforme matriz |
| Conta/MFA | Preferências locais e AAL1 permitido pela ADR 0019 | Reload/restart para preferências, não tabela remota; MFA no encerramento formal |

As demais ações mantêm seus aceites específicos nas matrizes, com fontes
históricas explicitadas onde não houve nova comprovação. Circulares não tem
família/action_ids próprios no inventário histórico: mapear suas subtelas ao
escopo `principal_profile` e fontes aprovadas antes de declarar cobertura total.
Não inventar IDs nem incluir esse escopo em percentuais sem esse cruzamento.

## Percentual e limites da revisão

Não há percentual confiável de implementação completa. 104/219 local-green e
3/38 famílias backend eram classificações históricas, não medições atuais do
trabalho restante. O inventário não tem ações certificadas integralmente:
Front-end 0/219; backend 0/214 normativas (Shell não exige backend próprio);
E2E 0/189 ativas. Zero certificado não significa zero implementado.

O denominador anterior 192 incluía três ações MFA do gate formal. Outras 22
operações reais de import/export são pós-MVP; não foram marcadas concluídas.
A UI de indisponibilidade honesta continua sujeita a verificação.

Esta revisão não executou novo E2E, replay ou deploy. Não certifica todas as
linhas em runtime: corrige contradições documentais e registra o que ainda
precisa de prova. Supabase/Cloudflare remotos são produção; R2 privado é master.

## Retomada

Usar os [sete prompts corrigidos](prompts-retomada-etapa-2-2026-09-08.md).
Reestimar por delta, dependência e execução medida. A faixa anterior 36–60 h
não foi validada; não é compromisso. Checkpoints preservados não equivalem a
integração. Revalidar Git/worktrees ao retomar.

Validação estrutural: `node docs/reviews/validate-trackers.cjs`.
O gerador `reconcile-trackers.cjs` é uma migração pontual da base 19b8f574:
não o reexecutar sobre atualizações operacionais futuras.

Memória: nenhum comportamento novo de produto foi aprovado nesta revisão;
não criar projeção de conhecimento apenas para registrar atividade.
