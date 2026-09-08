---
title: "Próxima fronteira — publicação e distribuição nominais"
source: "Spec Forms aprovada de 2026-08-13; conhecimento superadmin-forms-production; matriz F-AUTHOR01; fontes SQL efetivas inspecionadas"
status: "candidate-technical-boundary-awaiting-central-decision"
generated_at: "2026-09-08"
---

# Recorte e gates

Continuação do escopo original E2E 4 depois do cliente/contexto F-AUTHOR02.
Este documento é crosswalk read-only, não autoriza migration, rota, replay ou
produção. Reserva nominal e fronteira de coexistência pertencem ao Coordenador.
Publicação/distribuição não estão concluídas por 198 testes locais do editor.

Sequência candidata: fechar fronteira administrativa pós-publicação → comando
nominal de publish/versionamento e reader compatível → aplicações/audiência e
agendamentos nominais → ocorrências/eligibilidade → respostas/monitor/XLSX.
Responder continua identidade contextual elegível, não ator interno fabricado.
Tempo de implementação/replay depende do fechamento; não há ETA E2E confiável.

# Comportamento já aprovado

Publicar congela versão; edição posterior cria working version, sem mudar a
identidade ou agendamentos. Publicação seguinte atualiza somente ocorrências
futuras ainda não abertas. Abertas/concluídas mantêm a versão respondida. Modo
anônimo/identificado não muda após primeira publicação. Quick poll só publica
com intenção 1–280 após trim e exatamente uma pergunta respondível.

Distribuições são várias por formulário; público é recalculado no servidor,
com isolamento real, exclusões/deduplicação e perda de elegibilidade. Aplicações
e agendas não concedem autorização a partir de parâmetros do cliente.
Locais internos não são coordenadas livres; o fechamento de IDs fixos versus
catálogo dinâmico e histórico segue a decisão pendente própria.

# Impedimentos físicos confirmados

| Superfície | Estado atual | Fechamento necessário |
| --- | --- | --- |
| Guard legado F-AUTHOR01 | Protege somente draft interno nunca publicado | Publicar sai desse predicado. Decidir fronteira administrativa sem transformar autoria em regra permanente de audiência. |
| form_publish | Realm People, receipt People, updater People | Comando interno real, receipt/audit internos e updater XOR correto; não fabricar People nem reutilizar helper legado global. |
| Editor nominal 01/02 | Rejeita publicado e qualquer application/occurrence/job | Evolução forward-only do reader/contrato para estados publicados; DTO atual draft-only não pode ser ligado ao publish por cast permissivo. |
| Save nominal 01 | Só draft sem dependências; receipt reautoriza esse estado | Definir edição pós-publicação e replay de comando anterior sem quebrar snapshot/versão. Preservar receipt existente. |
| form_versions | Criador interno já suportado; trigger legado de imutabilidade não compara essa autoria nova | Working version nova com FK interna e XOR; evolução nominal do guard de proveniência, preservando limites e congelamento. |
| form_applications | created_by_person_id obrigatório | Autoria interna real em nova evolução nominal; regras de audiência não passam a ser internas por essa proveniência. |
| Aplicações/agendas legadas | Helpers/receipts People e guard por recurso; comando exige forms.manage_applications e helper G também forms.manage | Decidir explicitamente capabilities nominais; usar somente manage_applications não reproduz a conjunção legada. Nenhuma concessão implícita de forms.manage. |
| Workers/respondentes | Dependem de ocorrência, participação e elegibilidade | Provar caminho legitimamente elegível separado das portas administrativas; não revogar globalmente por app. |

O `form_publish` efetivo em F-AUTHOR01 escreve `updated_by_person_id` sem limpar
`updated_by_internal_identity_id`; ampliar seu alcance a recurso interno viola
XOR. O mesmo comando legado não é uma ponte para o ator interno.

O trigger `block_published_form_definition_mutation` em
`20260813155126_forms_security_performance_closure.sql` conhece somente
`created_by_person_id`, comparado com `<>`, e não compara a coluna interna
adicionada por 01. Transições permitidas de versão não podem ser tomadas como
prova de autoria imutável: o próximo pacote deve revisar ambas as colunas com
comparação null-safe e provar troca indevida negada. Não é uma nova porta
cliente aberta nesta fatia, que ainda não publica; nenhum helper foi alterado.

O helper G de distribuição referencia `form_record.deleted_at`, ausente no
modelo Forms inspecionado. Eng2 recomendou ao Coordenador uma corretiva nominal
mínima removendo só esse predicado, sem substituí-lo por status/archived_at.
Não foi executada ou aplicada por E2E 4. Teste negativo deve realmente alcançar
G; application inexistente aborta antes e não comprova a correção desse helper.

# Decisão central necessária, sem escolha silenciosa

Antes de qualquer publish nominal, fechar quais portas administrativas legadas
podem acessar um formulário publicado a partir do realm interno e sob qual
autorização real. São questões diferentes da audiência dos respondentes.

- Se coexistência administrativa for permitida, revisar todas as mutações,
  autoria/updater, receipts, projections e scopes para ambos os realms. Só
  deixar cair o guard ao mudar status não prova essa coexistência segura.
- Se houver cutover administrativo por recurso, usar fronteira nominal
  explicitamente aprovada, com cobertura de listagem/ID/receipt/clone/export/
  aplicações/agendas. Não impor veto permanente por autoria como atalho.
- Suspender grants globalmente não é isolamento por aplicativo e continua
  fora da autoridade desta frente.

Também fechar armazenamento/identidade dos receipts de publicação, sem alterar
silenciosamente o significado de `superadmin_internal_form_draft_receipts`.
Nomes como `superadmin_forms_publish_v2` são somente candidatos até reserva.
Capabilities novas no envelope do editor exigem avaliação efetiva no mesmo
ator/escopo; indisponibilidade do estágio não deve aparecer como grant falso.

# REDs exigidos para o próximo pacote aprovado

1. Ator publish-only e gestão/read separados; negativa de sessão/vínculo/escopo
   não vira fallback. AAL1/AAL2 conforme MVP sem nova exigência MFA.
2. Primeira publicação, republicação, quick polls incompletas, versão esperada
   divergente, repetição idempotente e replay após alteração subsequente.
3. Proveniência preservada, updater XOR e nova working version; imutabilidade
   de seções/itens/opções/condições publicados; modo de identidade bloqueado.
4. Ocorrências abertas/concluídas intactas; somente futuras elegíveis mudam de
   versão. Relatórios/detalhes continuam na versão respondida.
5. Reautorização após locks, expiração pelo relógio real, revogação/capacidade
   durante espera; audit fora do catch e rollback total em falha de append.
6. Matriz de coexistência após status published, inclusive receipts antigos,
   listagem paginada, operações indiretas, clone e export com zero respostas.
7. Distribuição/agendamento com pares form/institution/application reais;
   negativos atingem o guard pretendido, com controles positivos equivalentes.
8. Separação entre portas administrativas e responder elegível; prova A/B por
   ID e ausência de People artificial, alteração de worker ou grant global.

# Fontes

- `docs/superpowers/specs/2026-08-13-superadmin-forms-end-to-end-design.md`.
- `docs/knowledge/team/superadmin-forms-production.md`.
- `2026-09-07-authoring-coexistence-matrix.md` nesta pasta.
- `packages/coelo_database/migrations/20260908030000_superadmin_internal_form_drafts_v2.sql`.
- `packages/coelo_database/migrations/20260813155121_forms_commands_and_projections.sql`.
- `packages/coelo_database/migrations/20260813155116_forms_distribution_and_occurrences.sql`.
- `packages/coelo_database/migrations/20260813155126_forms_security_performance_closure.sql`.
- `packages/coelo_database/migrations/20260901194209_forms_distribution_target_authorization.sql`.

Nenhuma regra nova de produto ou projeção de conhecimento publicada. O contrato
pendente foi encaminhado ao Coordenador; trackers/ledger permanecem com ele.
