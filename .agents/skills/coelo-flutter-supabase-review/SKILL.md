---
name: coelo-flutter-supabase-review
description: Use when a Coelo review, audit, correction, implementation, or completion claim combines Flutter/Dart with Supabase, Auth, Postgres, RLS, RPCs, Edge Functions, Storage, migrations, remote persistence, or end-to-end screen behavior.
---

# Coelo Flutter + Supabase Review

Controle a conclusão ponta a ponta sem substituir as autoridades especializadas.

## Dependências obrigatórias

Em toda atividade, leia e aplique sempre:

1. `coelo-ui`, autoridade visual;
2. `rtk`, para todos os comandos de shell;
3. `ponytail`, em modo completo, para a menor correção segura da causa raiz;
4. `flutter-dart-code-review`, checklist técnico Flutter/Dart;
5. o plugin oficial Supabase disponível no ambiente;
6. `supabase`, orientação atual da plataforma;
7. `supabase-postgres-best-practices`, práticas de Postgres e desempenho.

Consulte também, sempre, `coelo-flutter-review` para o cliente e
`coelo-supabase` para o contrato Coelo de backend. Leia `AGENTS.md` e, nesta
ordem, os três rastreadores `coelo-flutter-pendencias.md`,
`coelo-supabase-pendencias.md` e
`coelo-flutter-integrado-supabase-pendencias.md`, em `docs/reviews/`. Use
`coelo-knowledge` quando aplicável.

## Começo obrigatório pelo orçamento

Se o usuário ainda não informou o tempo total, a primeira pergunta é:

> Quanto tempo total você quer investir nesta atividade?

Não comece correções antes da resposta. Se o tempo já foi informado, não
pergunte novamente. Depois, inventarie pendências Flutter, Supabase e integradas
e recalcule o tempo por risco, complexidade, dependências, ambiente e bloqueios.

| Nível cumulativo | Conteúdo | Referência inicial | Regra |
|---|---|---:|---|
| Básica | Ajuste local e de baixo risco, sem alegar fechamento de backend. | 30–90 min por ação simples | Nunca conclui ação integrada ou tela. |
| Intermediária | Básica + problemas principais, contrato existente e testes proporcionais. | 2–6 h por ação ou tela simples | MÍNIMO RECOMENDADO apenas para baixo/médio risco. |
| Avançada | Anteriores + ações aplicáveis, autorização, isolamento entre instituições e prova remota. | 1–2 dias por tela | Pode continuar parcial. |
| Completa | Todas as pendências, regressão e provas Flutter, Supabase e ponta a ponta. | 2–5 dias por tela | Único nível que pode sustentar conclusão integral. |

Autenticação, RLS (regras de acesso no banco), autorização, segurança, arquivos
privados e dados sensíveis nunca recebem recomendação Básica. As faixas são
referências e devem ser recalculadas depois do inventário.

## Progresso percentual obrigatório

Na abertura e em todo checkpoint, pausa ou encerramento, apresente o progresso
do recorte contratado e do backlog geral conhecido sem misturar os dois. Use as
unidades rastreáveis do inventário (`action_id` ou gate de conceito) e informe a
base do cálculo. Uma unidade só conta como concluída quando possui as evidências
Flutter, Supabase e integradas exigidas para o estado declarado; trabalho
parcial permanece no restante.

Use sempre este formato, com duas casas decimais e soma igual a `100,00%`:

```text
Progresso do recorte — Concluído: 21,43% (3/14 unidades)
Progresso do recorte — Restante: 78,57% (11/14 unidades)
Tempo usado no trabalho concluído: 50 h
Tempo estimado para finalizar o recorte: 2 dias 4 h 48 min
Progresso geral conhecido — Concluído: ...
Progresso geral conhecido — Restante: ...
Tempo estimado para finalizar o backlog geral: ...
Base do cálculo: action_ids/gates considerados, evidência e horário de referência.
```

Tempo usado é duração medida, nunca deduzida pelo percentual. ETA considera
dependências, testes, ambiente, autorizações e bloqueios e deve ser recalculado
quando o inventário mudar. Se faltarem dados confiáveis, escreva `não calculável
ainda`, liste o dado ausente e dê o próximo passo para torná-lo calculável; não
use zero, percentual aproximado ou falsa precisão.

## Contrato e confirmação

Antes de alterar código, banco ou remoto, apresente: pendências por lado e por
tela/subtela/ação; objetivo; incluído e fora do escopo; ordem; critério de
parada; evidências; nível recomendado; o que cabe no orçamento; o que continuará
pendente; e estimativa total. Aceite os recortes `todas as pendências`, `todas as
telas`, `macrotema`, `macrotema + X telas`, `X telas` ou `X ações específicas`.

Peça confirmação antes de corrigir. Review não autoriza correção; correção local
não autoriza migration, deploy ou alteração remota. Um pacote parcial não muda
ação ou tela para concluída. Nunca declare conclusão fora do recorte.

## Execução e checkpoint

Para cada `action_id`, rastreie `Flutter → estado → repository produtivo →
RPC/query/Edge → autorização/RLS → banco/Storage → resposta da UI`. Prove fluxo
permitido, negado, sessão ou vínculo revogado, acesso cruzado entre instituições,
recarga, persistência, auditoria e efeitos laterais aplicáveis. Mock, rota aberta,
golden, migration local ou testes isolados não bastam para conclusão integrada.

Sincronize os três rastreadores após cada correção, regressão, bloqueio ou nova
estimativa. No checkpoint, separe correções Flutter, correções Supabase e prova
ponta a ponta; explique números e siglas; informe pendências, bloqueios, próxima
ação e tempo restante.
