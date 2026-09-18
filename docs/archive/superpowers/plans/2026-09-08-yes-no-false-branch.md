---
source: "Spec Forms 2026-08-13, Ramificações; reserva explícita do Coordenador em 2026-09-08"
status: "approved-implementation-plan"
generated_at: "2026-09-08"
---

# Ramos Sim/Não completos no editor

Objetivo: permitir criar/reidratar Se Não, preservando o fluxo Se Sim existente.
Root único writer; reviewer read-only. Somente editor/testes/evidência locais.

Desenho aprovado: seletor canônico booleano para próximo filho, default Sim;
condição direta por filho conserva o booleano escolhido. Trocar seletor não
altera filhos. Hidratação conservadora aceita false somente na condição única
yesNo de ancestral contíguo, sem reordenar nem reescrever grafos complexos.
Cada filho exibe seu gatilho; mesmo painel e mesmas filas de autosave/cópia.

Alternativas: duplicar painel inteiro ou criar editor de grafo ampliaria a
fatia sem necessidade. Booleano explícito evita transformar false em ausência.

1. RED de criação/save/reload com false e true; seleção não retargeta filhos.
2. Ampliar seletor, mapper e hidratação no editor existente.
3. Testar cópia, condições complexas/ordem, callbacks retidos e autosave.
4. Regressão Forms, analyze, validador visual e revisão independente; evidência
   e commit para integração central. Estimativa 15–25 minutos.

Não modifica SQL, domínio compartilhado, endpoint, rota, publicação, audiência,
autorização ou clínica. Trabalho local não comprova persistência produtiva/E2E.
Self-review: segue fonte aprovada; limites/validação/backend continuam intactos.
