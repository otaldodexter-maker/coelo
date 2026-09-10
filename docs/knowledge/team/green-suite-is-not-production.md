---
title: "Suíte verde não prova que a tela existe em produção"
knowledge_id: "green-suite-is-not-production"
source: "docs/reviews/etapa-2-operacao/reports/E2-noturna-composicao-producao-20260909.md"
status: "draft"
generated_at: "2026-09-09"
updated_at: "2026-09-09"
audience: "team"
surfaces: [documentation, frontend, integration]
visibility: "internal"
review_owner: "Coelo Owner"
---

# Suíte verde não prova que a tela existe em produção

Antes de tratar uma ação como exercitada, é preciso perguntar se `main.dart`
compõe aquele caminho. Três perguntas, nesta ordem:

1. A dependência é injetada na composição de produção?
2. O router monta a página na rota produtiva, ou devolve bloqueio?
3. Existe implementação de produção do repositório, e não apenas a interface?

O caso que originou esta regra: Suporte tem dezenas de testes verdes e **nenhuma
camada de dados** — a feature só tem `domain` e `presentation`, e a tela roda
sobre um controlador de protótipo com dados em memória. Em produção a rota nem
abre, porque nenhum ponto de composição injeta o controlador e o router devolve
indisponibilidade. Uma suíte verde ali mede um protótipo.

O mesmo vale dentro de uma única família. Em Minha conta, Configurações e Tema
têm caminho produtivo com persistência local real; Perfil só existe em
`/dev/profile` com repositório em memória, sem implementação de produção; e
Sessões não tem tela alguma. Tratar a família como bloco esconde três estados
diferentes.

Consequência para o rastreador: ausência de implementação não é verificação
pendente. Quando o estado disponível não distingue os dois, a frase do registro
precisa dizer o que falta com todas as letras, porque o estado sozinho não
carrega essa informação.

Um sintoma relacionado, observado três vezes no mesmo dia: **teste com nome
tranquilizador cobrindo menos do que o nome sugere**. Uma matriz responsiva que
só usa viewports altos, um caso de 200% que cobre outra superfície, um golden
cujo arquivo de referência nunca existiu. O nome do teste não é evidência; o que
ele renderiza é.
