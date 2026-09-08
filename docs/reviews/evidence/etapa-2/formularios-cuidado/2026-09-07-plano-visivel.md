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

- Root: F-READ01 SQL/pgTAP nominal preparado e revisado estaticamente em `21792181`; nenhum SQL executado. Imagens no editor e visibilidade condicional corrigidas localmente: 99/99, analyzer 4 arquivos, review aprovado; goldens continuam abertos. Evidência `2026-09-07-image-config-and-conditional-response.md`.
- F-READ01: reserva adicional do Coordenador aplicada somente ao novo reader para auditoria obrigatória conforme spec 039; funções volatile, sucesso/negativas tipados e falha de append aborta a RPC. Testes de auditoria preparados, não executados; revisão estática aprovada. Base nominal 50/51 e execução exclusivas Eng1. Limitação AAL ausente do helper existente explicitada, sem alteração de MFA/sharedhelper.
- Editor: preservação de opções/condições carregadas corrigida; 106/106 na regressão ampliada, analyzer 2 arquivos e review aprovados. Evidência `2026-09-07-editor-branch-preservation.md`; não conclui criação visual de ramos nem backend.
- Responder: descarte de valores ocultos, ancestrais e recibos corrigidos; regressão 113/113, analyzer 2 arquivos e review aprovados. Evidência `2026-09-07-response-hidden-branches.md`; persistência/E2E permanecem abertas.
- Editor: metadados e configuração carregados preservados; regressão 120/120, analyzer 2 arquivos e review aprovados. Evidência `2026-09-07-editor-loaded-metadata.md`; rascunho incompleto e integração permanecem abertos.
- Responder: obrigatoriedade de controles e valores vazios corrigida; regressão 127/127, analyzer 2 arquivos e review aprovados. Evidência `2026-09-07-response-required-values.md`; backend e visual ainda abertos.
- Editor: rascunho incompleto de Enquete rápida deixa de ser bloqueado pela completude de publicação; integridade e pré-publish preservados. 6 REDs demonstrados, regressão 137/137, analyzer e review aprovados. Evidência `2026-09-07-quick-poll-incomplete-draft.md`; bloqueio equivalente no SQL legado continua pendente, sem persistência E2E comprovada.
- forms_next_slice: precondições e negativas SAI/SQL, análise read-only concluída.
- Editor: ramo Se Sim entregue em `d32775d9`: payload, reload, cópias, preview e contagem; 14 novos testes, regressão151/151 e review aprovados. Goldens mantêm cinco diferenças conhecidas, sem atualização de imagens. Evidência `2026-09-07-editor-yes-no-branch-roundtrip.md`.
- Autoria interna: crosswalk `38041740` recebeu fechamento técnico central para reader manage OR read, save manage, receipt privado reautorizado e guard por recurso da população draft nunca publicada. Inventário efetivo de acessos legados em curso antes do pacote local `20260908030000`; execução SQL segue exclusiva Eng1.
- Autoria interna: matriz efetiva revisada e pacote local `20260908030000` com pgTAP preparado, não executado. Proteções de 19 corpos, XOR/FKs, receipt, audit e validação; revisão corrigiu explosão de caminhos e fixture last-owner. Evidência `2026-09-07-authoring-nominal-package.md`; falta review final de testes, manifesto/replay Eng1 e cliente nominal.
- Autoria interna: revisão final de testes aprovada; review central exigiu reautorização após waits e rejeição nominal de isolamento diferente de READ COMMITTED. Delta preparado com âncoras/escopo estáveis, instituição não excluída sob SHARE, testes de isolamento/soft-delete e protocolo real duas conexões. Reviews estáticos aprovados; nenhum SQL executado. Evidência `2026-09-07-authoring-lock-reauthorization.md`; novo hash deve preceder replay Eng1.
- Autoria interna: complemento central autorizado valida not_after da sessão original contra clock_timestamp após os locks, preservando NULL e Auth global. RED temporal sequencial e protocolo de expiração durante bloqueio preparados, revisão estática aprovada; nenhum SQL executado. Hashes atualizados na evidência nominal antes do replay.
- review_export_policy: reader aprovado após correção de offset; sem backend.
- Exportação XLSX: colisões de títulos/IDs/metadados corrigidas no gerador puro; três REDs e 14/14 GREEN, incluindo páginas esparsas e reabertura dos dois encoders. Cabeçalhos agora têm namespaces e ID da pergunta. Review aprovado; sem SQL, worker runtime ou R2. Evidência `2026-09-07-xlsx-column-identity.md`; não E2E.
- medication_roundtrip: revisão UI/composição read-only, sem achado bloqueante.
- Cuidado/Medicação: isolamento de controller/diretório e leituras de detalhe corrigido localmente; 10 REDs, 14 testes novos, regressão165/165 em16arquivos, analyzer4arquivos e validadorvisual limpos, reviewaprovado. Goldens0/4 permanecem abertos, sem atualização. Evidência `2026-09-08-care-read-context-isolation.md`; reload pós-mutação será tratado em fatia separada; backend/clínica/E2E continuam abertos.
- Engenheiro 2 (coordenação externa): crosswalk nominal de ator/DTO/RPC Forms;
  não é writer desta branch.

Próximo gate: replay exclusivo Eng1 do SQL/pgTAP nominal de Formulários;
pacote e dependências em `2026-09-07-internal-directory-sql-package.md`. MED-DEV01
foi entregue em 17812624; commit não encerra a vertical.
Etapas 2/4 continuam abertas: planejar contrato não executa
SQL nem comprova autorização, persistência ou produção.

Os deltas oficiais por action_id são enviados ao Coordenador; os três
rastreadores centrais não são editados nesta branch. Corte de implementação
vigente: 2026-09-08 03:20 America/Sao_Paulo; commits não encerram a execução.
