---
title: "E2E 4 — plano visível por tela"
source: "Coordenador; pedido direto do Owner de passos e máximo de subagentes"
status: "in-progress"
generated_at: "2026-09-07"
---

# Limites

Somente Superadmin e dependências. Root é o único writer. Subagentes são
read-only em recortes separados. Nenhum BD remoto foi consultado ou alterado
nos pacotes abaixo; nenhum SQL executado. Não há lease de produção nesta frente.
Passos locais concluídos não significam tela ou E2E concluído.

## Seis marcos por tela

1. Contrato e inventário.
2. Backend, segurança e negativas.
3. Cliente e estados.
4. Integração real, persistência e reload.
5. Regressão, visual e negativas.
6. Review, evidências e commit.

| Tela / subtela / action_id | 1 | 2 | 3 | 4 | 5 | 6 |
| --- | --- | --- | --- | --- | --- | --- |
| Formulários / Exportar respostas / forms.responses.export | Recorte definido | Backend nominal pendente; SQL legado não bloqueado por adapter | Adapter e resolver locais corrigidos | Pendente XLSX/R2 real | 29/29 dados; não E2E | c0729294 + ff06b26d, reviews locais |
| Formulários / Responder / forms.respond | Lifecycle inventariado | Ator/contrato pendentes | Isolamento A/B local corrigido | Router autorizado e remoto pendentes | 23/23 comportamentais; golden DEV preexistente falha | 8d2ab5a, review local |
| Medicação / Criar e editar / medication.create, medication.edit | MED-STALE inventariado | Decisões produtivas abertas | Recibos/replay/source locais corrigidos | Bloqueado por decisão | 54/54 regressão; 4 goldens preexistentes falham | 8e336868, review local |
| Formulários / Editor / forms.create, forms.edit, forms.publish | Lifecycle inventariado | Crosswalk interno com Eng2/Coordenador; sem SQL | Geração, limpeza e modais isolados localmente | Pendente | 42/42 comportamentais; 5 diferenças golden também no baseline | Review local aprovado; evidência e commit em preparação |
| Medicação / Round-trip e ciclo / medication.edit | Subagente read-only | Não alterar política clínica | Ainda não implementado | Produção bloqueada | RED recomendado em análise | Pendente |

## Passo atual por tela, responsável e backend

Este Markdown não substitui o indicador nativo de plano do Codex. A busca nas
ferramentas disponíveis nesta tarefa não encontrou API de atualização desse
indicador. O arquivo é aberto no painel direito como alternativa disponível.

| Tela / subtela / action_id | Passo atual | Backend efetivamente trabalhado | Responsável | Teste / evidência | Próximo gate |
| --- | --- | --- | --- | --- | --- |
| Formulários / Editor: contexto e modais / forms.create, forms.edit, forms.publish | 6/6 da fatia local; tela ainda aberta | Nenhum BD nesta fatia; sem RPC/Worker executado | Root; review_export_policy read-only | 42/42; analyzer 2 arquivos sem problemas; review aprovado | Evidência e commit; integração produtiva continua pendente |
| Formulários / Editor: descartar / forms.edit | 1/6 | Nenhum BD nesta fatia | Root; forms_next_slice analisa RED read-only | Descarte atual restaura fixture; teste ainda não escrito | RED contra última definição autorizada |
| Medicação / round-trip DEV / medication.create, medication.edit | 1/6 | Repositório em memória DEV; nenhum BD | Root; medication_roundtrip analisa contrato read-only | Mapeamento e perdas inventariados | RED; preservar dados sem criar regra clínica |
| Formulários / Diretório / forms.list | 1/6 | Apenas leitura de código: app_private.form_list(jsonb), public.form_list(jsonb); nenhum SQL executado | Root; análise forms_next_slice concluída | Escopo SAI e cursor inventariados | Reserva nominal antes de migration; prova local |
| Formulários / Exportar respostas / forms.responses.export | 2/6 aberto após fatia cliente | Nenhum BD nesta fatia; R2/Worker não executados | Root; integração depende E2E 3 | Commits c0729294 e ff06b26d; 29/29 dados | Backend nominal e XLSX real no R2 privado |
| Formulários / Responder / forms.respond | 2/6 aberto após fatia cliente | Nenhum BD nesta fatia | Root | Commit 8d2ab5a; 23/23 comportamentais | Contrato autorizado e composition root |

## Trabalho ativo e BD

- Root: Editor, contexto/API/formId/load/save. Camada Flutter; BD nenhum neste
  passo. Não alterar router/API compartilhada sem reserva.
- forms_next_slice: casos RED de descarte produtivo e baseline; análise read-only.
- review_export_policy: revisão final do lifecycle aprovada; sem backend.
- medication_roundtrip: schedules e identidade no mapper DEV e fontes de ciclo;
  análise read-only, nenhum BD.
- Engenheiro 2 (coordenação externa): crosswalk nominal de ator/DTO/RPC Forms;
  não é writer desta branch.

Próximo gate: evidência/commit do lifecycle e RED de descarte do Editor.
Etapas 2/4 continuam abertas: planejar contrato não executa
SQL nem comprova autorização, persistência ou produção.

Os deltas oficiais por action_id são enviados ao Coordenador; os três
rastreadores centrais não são editados nesta branch. Corte de implementação
vigente: 2026-09-08 03:20 America/Sao_Paulo; commits não encerram a execução.
