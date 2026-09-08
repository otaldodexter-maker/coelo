---
title: "Formulários — ramo Se Não preservado"
source: "Spec Forms 2026-08-13, Ramificações; reserva central em 2026-09-08; plano 2026-09-08-yes-no-false-branch.md"
status: "local-verified-integration-and-e2e-open"
generated_at: "2026-09-08"
---

# Resultado

Editor oferece seletor Sim/Não para próximo filho, com Sim inicial preservado.
Cada filho mantém condição booleana e rótulo próprios. Trocar seletor não
retargeta filhos. Hidratação simples contígua agora aceita false, sem alterar
ordem nem condições complexas. Cabeçalho do painel é Ramos por resposta;
Se Sim/Se Não identificam o gatilho real de cada filho, no mesmo painel/card.

# Verificação local

RED: seletor booleano não existia; criação não permitia escolher false.
Oito testes novos: save/reload com ambos os valores, toggle, cópia do pai,
cópia da seção, reorder, callbacks antigos após troca de contexto/dispose e
autosave com booleanos por filho. Seleção isolada não gera comando.

Regressão das mesmas nove suítes Forms registradas na evidência
`2026-09-08-choice-branch-roundtrip.md`: **273/273**, exit 0.
Analyze dos três arquivos Dart: sem problemas, exit 0. Validador visual
administrativo: exit 0, allowlist intacta. Diff check limpo.
Revisão read-only independente favorável: false explícito em criação,
hidratação e cópia; callbacks verificam geração/identidade. Root único writer.

# Limites e memória

Nenhum SQL, endpoint, rota, publicação ou contrato compartilhado alterado.
Sem goldens atualizados e sem execução produtiva. Backend, integração, mídia,
XLSX, locais internos e cuidado continuam no escopo original e com gates próprios.
Ramos carregados complexos preservados não equivalem a editor visual de grafos.
Implementa regra já aprovada; nenhuma decisão nova ou projeção de conhecimento
criada apenas para registrar atividade. Trackers/ledger oficiais são da coordenação.
