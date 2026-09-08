---
title: "CHILD-READ01 — proposta documental da fundação Alunos/Crianças"
source: "specs/015-contextual-people-access-attendance.md; specs/039-superadmin-internal-auth-session-context.md; specs/046-superadmin-internal-person-detail-v2.md; migrations locais citadas; reserva documental da coordenação em 2026-09-08"
status: "proposal-requires-contract-review-no-implementation-authority"
generated_at: "2026-09-08"
---

# Objetivo e recorte proposto

Preparar listagem e detalhe estrutural de Alunos/Crianças no Superadmin interno,
separando pessoa global, contexto institucional e vínculos de unidade/turma.
Este documento não é spec aprovada, não define nomes finais de RPC nem concede
capability. Nenhuma SQL, rota, escrita ou execução remota foi introduzida.

Incluído para revisão: identidade mínima, contexto e hierarquia autorizada,
estados de leitura/reload e negativos de autorização. Fora: avaliações,
assiduidade, boletim, agenda e operações de E2E5; saúde/cuidado/segurança de
E2E4; contato/documentos/CPF/nascimento, responsáveis, permissões familiares,
convite, criação/edição, status, transferência ou revogação como comandos.
Esses últimos permanecem no escopo amplo original, mas precisam de fatias
próprias; não serão autorizados pela aprovação de um reader.

## Evidência local já existente

| Fonte | Fato comprovado por leitura local |
| --- | --- |
| 20260720180000_people_context_foundation.sql:155 | child_contexts possui id, child_person_id, institution_id, local_identifier, status e timestamps; único por pessoa/instituição. |
| Mesma migration:175 | child_unit_links relaciona contexto/unidade, status, aceite e revogação; único contexto/unidade. |
| Mesma migration:197 | child_group_links relaciona link-unidade/grupo, status e intervalo de validade. |
| 20260729141839_superadmin_people_directory.sql:14–55 | Cria historicamente people.read/create/update, people.memberships.manage e people.child_contexts.manage e grants Owner. Não prova matriz remota atual. |
| Spec046 | Reader interno existente é por person_id e capability people.read; contextos infantis são bridge flat do primeiro caminho válido, não todos os vínculos. |
| 20260825193123_final_review_student_tracking_read_fix.sql | Readers student_tracking_children/snapshot pertencem ao realm legado e agregam acompanhamento, não substituem o contrato estrutural interno. |
| 20260724152707_family_authorizations_and_transfers.sql:568 | decide_child_unit_transfer deriva current_person_id e autorização contextual do destino; não é comando interno039. |
| core/config/superadmin_auth_scope.dart:288/354 | studentTrackingRepository segue indisponível na composição atual. Fixture de desenvolvimento não é integração. |

Não foi encontrada criação nominal de students.read/children.read/
student_tracking.read nas fontes locais pesquisadas. A referência a
student_tracking.manage no reader legado é consumo, não prova de catálogo ou
grant. Essa ausência na pesquisa não é afirmação sobre produção: inventário
nominal de catálogo remoto seria um gate posterior, somente leitura.

## Decisões técnicas propostas, não aprovadas

1. Usar contexto institucional como unidade da linha/detalhe estrutural,
   mantendo child_person_id separado. Assim a mesma criança em A e B não vira
   uma linha global que mistura tenants. Alternativa é diretório por pessoa;
   sua semântica precisa ser decidida, pois spec046 cobre só detalhe por pessoa.
2. Considerar people.read como candidata de reutilização por já existir na
   spec046. Confirmar matriz/risco/papel efetivos e adequação à listagem antes
   do contrato; não criar students.read automaticamente nem usar uma capability
   manage como autorização genérica de leitura.
3. Projetar somente IDs e nomes minimizados de pessoa/contexto/instituição e
   caminhos válidos. Status cadastral e status de vínculo são diferentes.
   local_identifier, datas/aceite/autoria e responsáveis ficam excluídos até
   decisão explícita de necessidade. Não copiar todo o registro da tabela.
4. Se a tela precisar todos os caminhos, definir coleção hierárquica completa
   com ordenação e limites próprios. Não apresentar o primeiro caminho da
   bridge046 como totalidade nem alterar seu envelope para acomodar a nova tela.
5. Propor busca nominal limitada, ordenação determinística e paginação estável,
   mas somente após definir entidade da linha, limites e contrato de cursor.
   Contagem e filtros devem operar após autorização, nunca como oracle global.

## Invariantes a transportar para o novo contrato

- Resolver principal, auth link, membership e sessão pelo realm039 em toda
  chamada; não usar current_person_id, metadata mutável ou OR entre realms.
- Ler MFA conforme política vigente da ADR0019/aditivo de setembro, sem
  restaurar o gate AAL2 histórico da redação original046.
- Escopos internos platform/institution não se transformam em grants arbitrários
  de unidade enviados pelo cliente. Owner-only é referência da046, não concessão
  já aprovada para este novo reader.
- Conferir pessoa criança não excluída, contexto da instituição autorizada e
  cada igualdade contexto→instituição→unidade→grupo. FKs individuais não bastam.
- Spec046 permite contexto ativo, links de unidade pending/awaiting_allocation/
  active sem revoked_at e grupos ativos temporalmente válidos. Reutilização
  desses critérios exige confirmação da nova projeção; não ampliar estados
  para mostrar arquivo/histórico por conveniência da UI.
- Autorizar e projetar no mesmo contrato transacional, revalidando após esperas
  relevantes; revogação/movimentação não pode deixar PII raiz visível sem vínculo.
- Envelope seguro e allowlist, negativa indistinguível missing/cross-scope,
  auditoria minimizada sem nomes/payload/identificador infantil e sem dados antes
  da autorização. ACL mínima, helpers privados, sem grant direto novo em tabelas.

## Matriz de testes proposta

| Camada | Provas necessárias |
| --- | --- |
| Contrato físico | Schema e catálogo nominal; perfil de replay/proveniência; guard de drift sem reparação implícita. |
| Ator | Interno permitido; conta externa sem principal; sessão inválida/expirada; link/membership/capability/grant negado, suspenso ou revogado. |
| Hierarquia | Criança A/B; unidade irmã; grupo de outra instituição/unidade; contexto sem unidade e unidade sem turma; todos os caminhos versus bridge flat. |
| Não enumeração | UUID inexistente/adulterado/cross-scope; busca e total sem linhas alheias; sem contagem global ou identificador local no erro/audit. |
| Concorrência | Revogação e movimento durante leitura; espera efetiva e reautorização; reload após alteração sintética sem cache global. |
| DTO | Chaves/tipos estritos, IDs distintos, estados separados, rejeição de excesso/mistura de proprietário e ordenação/paginação consistente. |
| Flutter | Loading/empty/denied/unavailable/retry; troca de pessoa/contexto/sessão; descarte de resposta antiga e remoção de dados; teclado/toque/200%/temas. |
| Auditoria | Sucesso/negativa correlacionados e mínimos; falha de append não retorna dados; nenhuma autorização fabricada para ator inválido. |

## Gates e próximos passos

Primeiro revisar as cinco decisões candidatas, especialmente entidade da linha,
capability/matriz e cardinalidade dos caminhos. Depois produzir spec pequena e
contrato nominal aprovados, REDs locais, SQL/DTO/UI conforme reservas, replay
serializado e review independente. Integração/produção somente com lease e
pacote central. Não há prazo confiável de E2E antes desses gates; preparação
documental concluída, estimativa técnica deve ser recalculada com o recorte
aprovado. Nenhum action_id foi promovido; rastreadores pertencem à coordenação.

Gate de memória: nenhuma regra candidata promovida a conhecimento aprovado.
Este documento preserva evidência e perguntas técnicas, não um comportamento
novo de produto. A revisão readonly independente conferiu tabelas/capabilities
e limites da bridge046; o root conferiu as fontes antes de redigir.
