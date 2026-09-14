---
name: coelo-knowledge
description: Use when a Coelo task changes or explains product behavior, UX, domain rules, permissions, documentation, or reusable observable knowledge.
metadata:
  source: "AGENTS.md; docs/agent/source-of-truth.md; docs/knowledge/README.md"
  status: "active"
  generated_at: "2026-09-14"
---

# Memória de conhecimento Coelo

Esta skill é um procedimento curto para registrar conhecimento durável. Ela
não é um log de rodada, prompt, handoff, checkpoint, patch, screenshot ou
backup. O estado da execução fica em `docs/agent/current-state.md` e nos
rastreadores apontados por ele.

## Roteamento obrigatório

1. Leia `docs/agent/current-state.md`.
2. Use `docs/agent/source-of-truth.md` para decidir autoridade e conflitos.
3. Para fila e escopo, leia `docs/agent/backlog.md`.
4. Abra a fonte canônica específica: ADR, spec, PRD, arquitetura, dados,
   segurança ou design. Leia `docs/knowledge` como projeção, não como fonte.

Esta skill nunca deve carregar regras específicas de uma rodada. Quando uma
rodada fecha, leve apenas itens não terminais para o estado atual seguinte,
preservando IDs e atualizando a fonte canônica. Itens concluídos não retornam
por permanecerem em arquivos antigos.

## Status e ciclo de vida

`status` mede qualidade editorial: `draft`, `validated` ou `deprecated`.
`lifecycle` mede aplicabilidade: `current`, `future`, `historical` ou
`superseded`. `validated` não significa automaticamente vigente: a consulta
operacional exige as duas condições, `status=validated` e
`lifecycle=current`.

Use `-Lifecycle future`, `historical`, `superseded` ou `all` somente para
auditoria interna explicitamente solicitada. Nunca apresente projeção futura,
histórica ou superada como comportamento disponível. Confirme sempre a fonte
canônica e a autoridade mais recente.

## Gate de memória

- Atualize primeiro a fonte canônica aprovada; projete depois somente a regra
  durável, reutilizável e destinada à audiência correta.
- Se nada durável mudou, faça `no-op`; não crie artigo para registrar atividade.
- Separe `team`, `admin` e `users`; relacione artigos equivalentes por
  `knowledge_id` quando necessário.
- Recuse PII, CPF, dados de crianças, tenants reconhecíveis, mensagens, mídia,
  logs integrais, segredos, tokens e conversas brutas.
- Conflitos devem ser registrados em `docs/open-questions.md`, citando as
  fontes envolvidas; não resolva silenciosamente.

## Validação e consulta

Use os wrappers da própria skill a partir de qualquer diretório:

```powershell
& .agents/skills/coelo-knowledge/scripts/Test-CoeloKnowledge.ps1 -Root (Get-Location).Path
& .agents/skills/coelo-knowledge/scripts/Search-CoeloKnowledge.ps1 -Root (Get-Location).Path -Audience team -Query "termo" -Detailed
```

O validador exige frontmatter YAML tipado, datas reais, `surfaces` não vazias,
IDs únicos por audiência e `source` relativo existente fora da projeção.
Detecção de dados sensíveis é heurística e não substitui revisão humana.
PASS valida a estrutura; não certifica implementação, autorização, segurança
server-side nem atualidade da fonte.

Não instale dependências silenciosamente. Python 3.10+ e PyYAML são exigidos
pelos scripts; consulte `scripts/requirements.txt` se o runtime faltar.
