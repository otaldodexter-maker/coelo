---
name: coelo-flutter-review
description: Use when starting or continuing a Coelo Flutter/Dart code review, revision, audit, correction, refactor, screen-completion check, or pending-work inventory. Applies to screens, subtelas, actions, architecture, tests, responsiveness and accessibility; use the integrated skill when Supabase completion is in scope.
---

# Coelo Flutter Review

Revise Flutter/Dart sem confundir rota aberta, aparência correta ou teste
isolado com tela concluída.

## Dependências obrigatórias

Em toda atividade, leia e aplique sempre estas cinco skills:

1. `coelo-ui`: autoridade visual, componentes, padrões e baselines;
2. `rtk`: forma obrigatória de executar comandos de shell;
3. `ponytail`: solução mínima que corrige a causa raiz, em modo completo;
4. `flutter-dart-code-review`: checklist técnico Flutter/Dart;
5. `flutter-build-responsive-layout`: adaptação real à largura disponível.

Leia também `AGENTS.md` e `docs/reviews/coelo-flutter-pendencias.md`
integralmente. Use `coelo-knowledge` quando houver conhecimento durável. Se o
pedido envolver persistência, Auth ou Supabase, use também
`coelo-flutter-supabase-review`.

Mesmo quando Supabase estiver fora do recorte, faça uma consulta breve a
`coelo-flutter-supabase-review` para identificar dependências integradas e
registrá-las como fora de escopo. Essa consulta não certifica nem altera backend.

## Começo obrigatório pelo orçamento

Se o usuário ainda não informou o tempo total, a primeira pergunta é:

> Quanto tempo total você quer investir nesta atividade?

Não comece correções antes da resposta. Se o tempo já foi informado, não
pergunte novamente. Depois, inventarie as pendências reais, recalcule o tempo
por risco, complexidade, dependências e bloqueios, e mostre o que cabe e o que
ficará pendente.

| Nível cumulativo | Conteúdo | Referência inicial | Regra |
|---|---|---:|---|
| Básica | Correção pequena, localizada e de baixo risco. | 30–90 min por ação simples | Nunca conclui uma tela. |
| Intermediária | Básica + problemas principais, contratos e testes proporcionais. | 2–6 h por ação ou tela simples | MÍNIMO RECOMENDADO. |
| Avançada | Anteriores + ações aplicáveis, arquitetura, estados, acessibilidade e regressões. | 1–2 dias por tela | Pode continuar parcial. |
| Completa | Todas as pendências aplicáveis, regressão e evidências finais. | 2–5 dias por tela | Único nível que pode sustentar conclusão integral. |

Auth, permissões, segurança e dados sensíveis nunca recebem recomendação
Básica. As faixas não são promessa: ajuste-as após o inventário.

## Contrato e confirmação

Antes de alterar código, apresente pendências gerais e por tela/subtela/ação;
objetivo; incluído e fora do escopo; ordem; critério de parada; evidências; nível
recomendado por unidade; estimativa total; o que cabe no orçamento; e o que
continuará pendente. Classifique o recorte como `todas as pendências`, `todas as
telas`, `macrotema`, `macrotema + X telas`, `X telas` ou `X ações específicas`.

Peça confirmação do pacote antes de corrigir. Review, auditoria ou diagnóstico
não autorizam correção. Nunca amplie o recorte nem declare concluído o que ficou
fora dele. Um nível parcial não muda a ação ou tela para concluída.

## Execução e checkpoint

Siga o rastreador e atualize cada `action_id`. Verifique listar, criar, detalhe,
editar, publicar/ativar, excluir/revogar, arquivos, erros/permissão e recarga
quando aplicáveis. Criar/Editar Instituição é a baseline administrativa;
Instituições é a baseline de diretórios, Cards e tabelas.

Atualize o Markdown após correção, regressão, bloqueio ou nova estimativa. No
checkpoint, informe pacote autorizado, posição, evidência em linguagem simples,
pendências dentro e fora do recorte, bloqueios, próxima ação e tempo restante.
Diferencie `atividade concluída`, `tela Flutter concluída` e `produto pendente`.
