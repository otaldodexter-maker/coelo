---
source: "R08 G3; gate nominal H19 atribuído por C0; specs/020-superadmin-health-care.md; docs/superpowers/specs/2026-09-01-superadmin-access-health-care-finalization-design.md"
status: "local-green; contrato produtivo pendente de G5/C0; E2E não executado"
generated_at: "2026-09-12"
---

# H19 — responsáveis no formulário de medicação

Recorte: `apps/superadmin -> Saúde e Cuidado -> Planos de medicação -> criar/editar -> horários e responsáveis/revisão -> medication.create/medication.edit` (backlog H19). Base materializada: `origin/dev 2441725d5`, merge `5a421a7b9`. Não promove o estado de aceite produtivo.

## Correção local

Um ID selecionado que não aparece mais no catálogo fazia `firstWhere` lançar `StateError: Bad state: No element`, impedindo a abertura da etapa. O seletor agora mostra **Responsável indisponível**, preserva o ID no rascunho e permite remoção explícita. A revisão usa o mesmo rótulo; antes aplicava o fallback de criança a um responsável. Nenhum UUID é exibido e nenhum vínculo é criado ou removido silenciosamente.

Nome sintético longo, adição, remoção, revisão e entrega do rascunho foram exercitados em 375 px e texto a 200%. A gravação desse teste usa callback local; não representa persistência Supabase nem autorização do responsável.

## Contrato produtivo ausente

- A UI recebe `HealthMedicationPlanFormPage.responsibleOptions: List<HealthCareFormChoice>` (`id`, `label`) e devolve `HealthMedicationPlanFormDraft.responsibleIds: Set<String>`.
- `MedicationPlanSaveCommand` e `MedicationPlanDetail` não transportam responsáveis. `SupabaseMedicationPlanRepository` não serializa nem projeta esses IDs. `SupabaseMedicationPlanDraftSaver` ignora a seleção e `medicationPlanFormDraft` inicializa um conjunto vazio.
- O router produtivo não passa `responsibleOptions`. Preencher a lista sem contrato de escrita produziria uma escolha descartada no save/reload.
- Fontes aprovadas exigem a etapa horários/responsáveis, mas não permitem inferir que destinatário de política/notificação seja autorizado a administrar dose.

Candidato enviado a G5, para revisão após Momentos/lote 58 na fila C0: catálogo mínimo contextual por criança, identidade autoritativa da seleção, validação server-side do vínculo/escopo, persistência versionada e projeção no detalhe. Os nomes novos de DTO/RPC aguardam confirmação do backend. O router continua com C0 e não foi editado. H20 (imagem da dose) permanece independente; o contrato de evidência atual transporta resultado/motivo/nota, sem ativo de mídia.

## Verificação

Slot nominal C0 de até cinco minutos, liberado após execução; sem processo Flutter retido.

- RED: `05-h19-red.log`, 1 aprovado / 2 falhos esperados, reproduzindo ID ausente do catálogo.
- GREEN: `05-h19-tests.log`, **31 IDs únicos aprovados / 0 falhos**, três arquivos: `medication_responsible_selector_test.dart` (3 novos), `medication_plan_external_options_test.dart` (2), `medication_plan_ui_contract_test.dart` (26). Os 28 preexistentes são regressão e não devem ser somados aos pacotes anteriores como cobertura nova.
- Análise focal: `05-h19-analyze.log`.
- E2E executado: **0**; persistência, reload e negação de acesso dependem do contrato e runtime autorizados.

Gate de memória: correção de implementação e lacuna de contrato registradas nesta evidência. Não houve decisão nova de produto, papel, regra clínica ou conhecimento canônico a publicar. Escritor central permanece C0.
