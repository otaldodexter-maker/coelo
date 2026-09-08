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
| Formulários / Editor / forms.create, forms.edit, forms.publish | Lifecycle e descarte inventariados | Crosswalk interno com Eng2/Coordenador; sem SQL | Isolamento e descarte locais corrigidos | Pendente | 50/50 comportamentais; 5 diferenças golden preexistentes abertas | Lifecycle ad2962da; descarte em evidência/commit |
| Medicação / Round-trip e ciclo / medication.create, medication.edit | MED-DEV01 inventariado | Não alterar política clínica | Snapshot/mapper DEV e replay corrigidos | Só memória DEV; produção bloqueada | 60/60, incluindo rotas; visual pendente | Review aprovado, evidência/commit |

## Passo atual por tela, responsável e backend

Este Markdown não substitui o indicador nativo de plano do Codex. A busca nas
ferramentas disponíveis nesta tarefa não encontrou API de atualização desse
indicador. O arquivo é aberto no painel direito como alternativa disponível.

| Tela / subtela / action_id | Passo atual | Backend efetivamente trabalhado | Responsável | Teste / evidência | Próximo gate |
| --- | --- | --- | --- | --- | --- |
| Formulários / Editor: contexto e modais / forms.create, forms.edit, forms.publish | 6/6 da fatia local; tela ainda aberta | Nenhum BD nesta fatia; sem RPC/Worker executado | Root; review_export_policy read-only | ad2962da; 42/42; analyzer 2 arquivos sem problemas | Integração produtiva continua pendente |
| Formulários / Editor: descartar / forms.create, forms.edit | 6/6 da fatia local | Nenhum BD nesta fatia | Root; review_export_policy read-only | 4e6f8dc5; 50/50; analyzer 2 arquivos | Tela permanece parcial |
| Medicação / round-trip DEV / medication.create, medication.edit | 6/6 da fatia local | Repositório em memória DEV; nenhum BD | Root; medication_roundtrip/review_export_policy read-only | 60/60; review aprovado; medication-dev-roundtrip.md | Commit; backend/visual/produção pendentes |
| Formulários / Diretório / forms.list | 3/6 local, não E2E | Reader chama somente novo RPC nominal public/app_private.superadmin_forms_directory_v2; nenhum SQL executado | Root; reviews read-only concluídos | 124/124; analyzer 11 arquivos; visual preexistente aberto; internal-directory-reader.md | SQL/pgTAP nominal e replay exclusivo Eng1 |
| Formulários / Exportar respostas / forms.responses.export | 2/6 aberto após fatia cliente | Nenhum BD nesta fatia; R2/Worker não executados | Root; integração depende E2E 3 | Commits c0729294 e ff06b26d; 29/29 dados | Backend nominal e XLSX real no R2 privado |
| Formulários / Responder / forms.respond | 2/6 aberto após fatia cliente | Nenhum BD nesta fatia | Root | Commit 8d2ab5a; 23/23 comportamentais | Contrato autorizado e composition root |

## Trabalho ativo e BD

- Root: F-READ01 SQL/pgTAP nominal preparado na origem em `21792181`, ainda não integrado nem executado no destino; revisão central reteve helper400 e expectativa MFA obsoleta. Imagens no editor e visibilidade condicional corrigidas localmente: 99/99 informados, analyzer 4 arquivos, review aprovado; goldens continuam abertos. Evidência `2026-09-07-image-config-and-conditional-response.md`.
- Editor: preservação de opções/condições carregadas corrigida; 106/106 na regressão ampliada, analyzer 2 arquivos e review aprovados. Evidência `2026-09-07-editor-branch-preservation.md`; não conclui criação visual de ramos nem backend.
- forms_next_slice: precondições e negativas SAI/SQL, análise read-only concluída.
- review_export_policy: reader aprovado após correção de offset; sem backend.
- medication_roundtrip: revisão UI/composição read-only, sem achado bloqueante.
- Engenheiro 2 (coordenação externa): crosswalk nominal de ator/DTO/RPC Forms;
  não é writer desta branch.

Próximo gate: SQL/pgTAP do reader interno nominal de Formulários. MED-DEV01
foi entregue em 17812624; commit não encerra a vertical.
Etapas 2/4 continuam abertas: planejar contrato não executa
SQL nem comprova autorização, persistência ou produção.

Os deltas oficiais por action_id são enviados ao Coordenador; os três
rastreadores centrais não são editados nesta branch. Corte de implementação
vigente: 2026-09-08 03:20 America/Sao_Paulo; commits não encerram a execução.
