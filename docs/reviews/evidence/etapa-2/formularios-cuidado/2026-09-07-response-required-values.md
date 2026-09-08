---
title: "Formulários — obrigatoriedade em todos os controles visíveis"
source: "Spec Forms aprovada 2026-08-13:204; contrato de respostas tipadas; revisão e testes E2E4"
status: "local-behavior-verified-e2e-open"
generated_at: "2026-09-07"
---

# Recorte e resultado

O formulário nativo validava apenas campos com validator próprio; Sim/Não,
escolhas, escala e data vazios abriam a revisão mesmo sendo obrigatórios.
Agora a validação percorre todos os itens obrigatórios visíveis, excluindo
blocos informativos, além dos validators existentes. Texto só com espaços e
escolhas vazias carregadas não contam como resposta; false e zero continuam
válidos. Feedback usa a área de erro existente e desaparece na revisão válida.

Anexo obrigatório visível mantém o bloqueio honesto já existente. Salvar
rascunho incompleto não usa a validação de envio. Não altera backend, limites,
tipos compartilhados, autorização ou política de mídia.

# Evidências

- RED: cinco casos obrigatórios vazios abriram revisão indevidamente; mais dois
  casos de conteúdo carregado vazio reproduziram o problema.
- GREEN: sete testes novos; suíte específica do responder 30/30.
- Regressão final 127/127, exit 0: o mesmo comando de sete suítes documentado em
  `2026-09-07-editor-loaded-metadata.md`, reexecutado após este patch via RTK.
- Analyzer dos dois arquivos alterados: sem problemas, exit 0. Formatação e
  diff check aprovados; validador de contratos visuais exit 0, allowlist intacta.
- Review read-only aprovado. As provas usam doubles; não certificam backend/E2E.

Goldens não atualizados; gate visual permanece aberto. Gate de memória sem
decisão nova/projeção: aplicação de obrigatoriedade já aprovada. Nenhum action_id
promovido a done; persistência, mídia/XLSX, locais e cuidado continuam no escopo.
