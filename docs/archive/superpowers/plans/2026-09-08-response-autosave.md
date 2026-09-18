---
title: "Respostas — autosave na fila de confirmação"
source: "Prompt Owner E2E4 responder/autosave/enviar/editar; aprovação central explícita 2026-09-08; contrato fd602806"
status: "local-verified-integration-and-e2e-open"
generated_at: "2026-09-08"
---

# Contrato delimitado

Cliente de Respostas usando API existente, sem SQL, rota, realm, segredo anônimo
ou mídia. Debounce 800 ms de alterações efetivas, não da abertura/hidratação.
Rascunho incompleto pode salvar: required continua gate de revisão/envio.
Somente conteúdo draft editável, mesma fila request/receipt/expectedVersion de
fd602806; sem segundo comando enquanto aguarda confirmação. Revisão e envio
sempre explícitos; timer não concorre com revisão/envio. Edição posterior a um
save confirmado recebe outro debounce, sem falso Salvo.

Erro/conflito/confirmação incerta pausam automático; retry manual do mesmo
comando quando incerto. Dispose/troca de API/ocorrência/negação cancelam timer.
Callbacks retidos não podem gerar escrita no contexto seguinte. Estados reais:
alterado, salvando, salvo, falha/conflito; nenhum sucesso temporizado de DEV.

# Ordem

1. REDs de debounce, ausência em hidratação, incompletude e serialização.
2. Negativos de perda de confirmação, conflito, revisão/envio, contexto e
   callback retido; controles positivos equivalentes.
3. Implementação mínima reaproveitando fila, sem duplicar contrato backend.
4. Regressão Forms, analyzer, validator visual, review e evidência.

Estimativa local 35–55 min; checkpoint 03:20 BRT preservado. E2E, autorização
remota, segredo anônimo e mídia permanecem gates separados. Nenhuma alteração
clínica e nenhum tracker oficial: Coordenador mantém ledger e integração.
