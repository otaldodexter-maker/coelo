---
source: "R08 prompts/contrato comum/G3; commits e evidências da worktree G3; integração C0 ciclo150; manifesto API G0; revisão focal G4"
status: "em execução; handoff parcial atualizado antes do corte"
generated_at: "2026-09-12"
---

# R08 G3 — Formulários, Cuidado e Rotina

Worktree preservada: `C:/Users/adrie/Documents/Coelo.worktrees/e2-r08-formularios-cuidado-rotina`. Branch `work/etapa2-r08-formularios-cuidado-rotina`. Base conjunta atual: `origin/dev 7d2b66a3e`, incorporada por merge `8fead7905`, sem rebase/force e sem editar/puxar o checkout principal. C0 é o integrador e escritor dos rastreadores. Não houve deploy, migration, cleanup ou criação de fixture remota por G3.

T0 `10:52:16 BRT`; execução até `14:52:16`; handoff final até `15:02:16`; ajustes até `15:22:16`. Este documento ainda é parcial: captura Foto local-green e a rodada continua nos próximos gates autorizados.

## Entregas publicadas

| Caminho no Superadmin / ação | Resultado desta rodada | Evidência |
| --- | --- | --- |
| Assiduidade → Chamada → lançar/concluir/corrigir → `attendance.mark/finish/correct` | Título compacto/retorno corrigidos, controllers reconciliados, goldens atuais e regressão local. BE anterior preservado. **Nova tela ainda sem recertificação UI real.** | `01-frame-attendance.md` |
| Saúde e Cuidado → Planos de medicação → editar → `medication.edit` | Frame/footer 375/200 corrigido sob posse nominal C0; sem overflow nos testes do recorte. | `01-frame-attendance.md` |
| Formulários → editor/agendamento → H10/H11 | Audiência múltipla/exclusão preservada; autosave produtivo, versão, retry e alterações durante envio tratados. | `02-audiencia-autosave.md` |
| Formulários → imagens de pergunta e resposta → `forms.upload/resolve-file` | Upload privado com URL/headers do gateway, confirmação, reconciliação, cancelamento e leitor com TTL/purge. Pergunta e resposta são subaceites distintos. | `03-form-media.md` |
| Formulários → limites de seleção e respostas opcionais → H12/H26 | Controles min/max e validação; pergunta opcional não respondível pode ser omitida; valor legado inválido exige remoção explícita. | `04-h12-h26.md` |
| Medicação → horários/responsáveis/revisão → H19 | ID ausente do catálogo não quebra a tela nem expõe UUID. Nome longo 375/200 e entrega do draft verificados localmente. Contrato produtivo de responsável ainda depende de decisão/BE. | `05-h19-responsaveis.md` |
| Formulários → Galeria → confirmar upload de resposta → `forms.upload` | Envelope R2 fresh/replay compatível com Flutter, usando tamanho medido. Review G5 aprovado; C0 informou deploy v17. | `06-answer-finalize.md` |
| Formulários → resposta anônima → responder/editar/mídia | Guarda local particionada projeto/conta, segredo32bytes antes do RPC, open/save/submit/edit e mídia anônima; wiring entregue a C0/G6. | `07-anonymous-edit.md` |
| Formulários → Foto → `forms.upload` | Captura web real implementada; lifecycle/bytes tardios/375×600 e200% verificados localmente com port sintético, limite1 preservado. Navegador/câmera física ainda não exercitados. | `08-camera-result.md` |
| Formulários → diretório → tabela → H25 | Alça48 com alvo separado de ordenar; largura fixa sem alça. Pintura aprovada preservada após regressão detectada na integração. Residual de sort estreito em Suporte não certificado. | `10-h25-inspecao.md`, `12-h25-paint.md` |
| Formulários / Cuidado / Medicação → diretórios → acessibilidade | Guideline completo de Formulários reativado após PASS. Dois de Cuidado reproduziram alvo44 do shell; posse C0 para mínimo48,8PASS e goldens preservados. | `13-directory-accessibility.md`, `14-care-accessibility.md` |

## Commits

- `7bc243cdb`: frame e chamada.
- `0d6024076`: H10/H11.
- `7ba5077f9`: consumidor de mídia.
- `42e10d0cb` + `851c6cc95`: H12/H26 e provas.
- `03d7c4127` + `0b05e95f2`: H19 UI e logs.
- `dfe013cc5` + `f0c7269fd`: envelope answer-image e review de medida real.
- `72e6e6f22` + `8344cb98a`: edição anônima e conciliação do timeout inicial.
- `8b9e784e5`: merge da base C0 ciclo120.
- `d3d3d5d63`: captura Foto, 182 testes aprovados no pacote.
- `a7b081674`: merge da base C0 ciclo150.
- `725155ec0` + `d4c71277d`: purge de câmera durante descarte da tela, revisão G4 reproduzida e corrigida; 9 testes aprovados, um novo, sem somar os oito anteriores. Evidência `09-camera-purge.md` e logs.
- `54c892ebc` + `f0e148a70`: H25 e preservação da pintura após regressão integrada; followup21tabela+16goldens aprovados sem regravar PNG.
- `0c92198a0`: delta de memória proposto para aplicação C0, fonte antes de projeção, sem nova ADR.
- `17d4f2233`: reativa guideline completo de Formulários,1PASS/analyze0.
- `1e0029e9e`: alvo mínimo48 do menu de usuário,2RED→8PASS, dois casos reativados, semPNG.
- `8fead7905`: merge ciclo180, remoto sincronizado. Memória aplicada por C0 em `65f219550` efetivamente lida, fontes e projeções presentes nesta base.

Todos os commits acima foram enviados à branch remota. O SHA final deste handoff será informado no fechamento, sem usar um SHA do próprio arquivo como certificação circular.

## Testes e limites da conclusão

Resultados locais por pacote: 142 frame/chamada; 216 H10/H11; 376 mídia; 273 H12/H26; 31 H19; 53 Deno answer-image; 293 anônimo; 182 câmera. **Não somar:** há sobreposição expressa nos relatórios. Pacote anônimo tem18 casos novos; H19 tem3; câmera tem11. O restante é regressão/reexecução. Falhas iniciais e suas correções estão nos logs; o timeout do primeiro teste do store foi conciliado como falha antes da interrupção, e o resultado final é293PASS/0FAIL.

E2E UI executado por G3: **0**. Build, testes isolados, API smoke e tela aberta não certificam a rota completa. A recertificação `attendance.mark/finish/correct` não reutiliza automaticamente os certificados antigos.

Evidência externa reutilizável, efetivamente lida: manifesto G0 `../r08-ambiente-runtime/forms-question-image-api-smoke-manifest.md`. Question-image teve save/prepare/PUT/finalize/replay/resolve/GET e reload do binding PASS via API, fixture preservada. Não inclui a resposta Foto/Galeria, negação cross-tenant real, exclusão/expiração remota nem uso pela UI Flutter. C0 implantou lote57 e depois form-media v17; implantação não é prova da ação inteira.

Atualização externa posterior efetivamente lida por SHA `893a3e2a3`: G0 `forms-answer-image-api-v20-20260912.log`, medido13:50BRT, form-media v20. Resposta identificada Foto: preflight/open, prepare, PUT68bytes, finalize/replay e save draft PASS via API. Autorizar download falhou400 `media_request_failed`; GET e reopen não executados. Logout local204; fixture preservada sem cleanup. Isso avança upload/persistência de resposta separadamente de question-image e não certifica download, reload, câmera física ou UI. Investigação é C0/G5/G0; G3 não repetiu o smoke.

## Pendências e próximo gate

1. Captura Foto local-green: integrar/build e provar no navegador pelo runtime G0/C0. Mantém Foto1; não amplia cardinalidade por fonte antiga. Propostas focais em `deltas.json`, sem aplicação direta ao inventário.
2. `forms.location-answer`: precisa ocorrência nova com Local publicado, resposta/reload e negativo no runtime. Decisão ADR9/12 já resolvida; não reabrir pergunta ao Owner. Provas locais anteriores permanecem contexto, não prova atual remota.
3. `attendance.mark/finish/correct`: nova tela ainda depende do runtime G0 para rota normal/persistência/reload/negação.
4. Mídia: prova real de answer-image identificada/anônima, expiração e exclusão continua com G0/C0. Fixtures preservadas; G3 não fará DELETE/cleanup.
5. H19: C0 registrou pergunta ao Owner sobre elegibilidade dos responsáveis; G5 aguarda contrato nominal. Não criar schema ou converter destinatário de política em autoridade de dose por inferência.
6. H20: imagem da dose tem campo `media_asset_id` no RPC, mas não tem fluxo de gateway/cliente. Aceite textual de `medication.evidence` permanece separado e preservado.
7. H25: followup visual deve acompanhar pacote inicial. Colunas80/90 em Suporte ficam com sort32/42 após alça48; C0 aceitou registrar o residual sem ampliar larguras fora do recorte. Não certifica AA global.
8. Gate memória: proposta `11-memory-delta.md` aplicada por C0 em `65f219550`, fonte e projeção efetivamente conferidas nesta worktree após merge. Validação local anterior64artigos; ferramenta12PASS/0FAIL/1SKIP do host. Nenhuma nova ADR inventada. A correção do menu aplica token mínimo já canônico, sem nova regra de produto.

## Recursos e memória

Chrome/runtime: G0, nenhum Chrome G3. Flutter: somente por slots C0, nenhum processo persistente. SQL/produção: C0/G0/G5. Router/authscope/app: C0/G6 para a composição anônima; não editados por G3. Frame/publication surface tiveram posse nominal confirmada para o pacote focal e não recebem alterações adicionais nesta fatia.

Propostas de conhecimento durável estão nos relatórios: mudanças de implementação não criam novas regras de produto. C0 publica a projeção canônica depois da integração. Nenhum segredo, JWT, ticket, URL assinada ou dado pessoal real consta nas evidências G3. Worktree não será removida.
