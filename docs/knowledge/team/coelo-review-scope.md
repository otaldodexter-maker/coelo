---
title: "Recorte e evidência das revisões Coelo"
knowledge_id: "coelo-review-scope"
source: "AGENTS.md"
status: "validated"
generated_at: "2026-09-08"
audience: "team"
surfaces: [documentation, frontend, backend, integration]
visibility: "internal"
review_owner: "Coelo Owner"
---

# Revisão proporcional ao recorte

Auditoria ou conclusão ampla exige leitura integral dos rastreadores das
camadas. Correção localizada usa cabeçalhos, ações, dependências e evidências
afetadas. Explicação ou manutenção de skill não inicia auditoria de produção.
Reutilizar leituras; dependências de skills não reiniciam em ciclo.

Preservar escopo e autorização já dados, sem exigir nova pergunta de tempo.
Estimar o delta real após inspecionar o existente, separando implementação,
verificação e espera externa. Número de ações não equivale a horas de trabalho.

Frontend, Backend e E2E têm provas próprias. Ausência de certificado não
comprova código ausente, e evidência local não comprova fluxo produtivo.
Atualizar rastreadores afetados quando seu estado mudar; correção de skill
não certifica ações do produto. Remoto continua produção com autorização nominal.
