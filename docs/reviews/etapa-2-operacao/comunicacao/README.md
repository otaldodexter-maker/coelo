---
title: "Canal durável da rodada noturna 09→10/09/2026"
source: "docs/reviews/etapa-2-operacao/TRABALHO-ATUAL.md; coordenação Claude"
status: "active"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Comunicação da rodada

Raiz absoluta:
`C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/comunicacao/`

- `coordenacao.json` — escrito **somente** pelo coordenador Claude
  (sessão `coelo-73`). Contém base integrada, worktrees/branches verificados,
  ativações, reservas, bloqueios e o recibo nominal por revisão recebida.
- `<grupo>.json` — escrito **somente** pelo executor daquele grupo. Um arquivo
  por grupo, sobrescrito de forma atômica com o estado corrente. Não criar um
  Markdown por checkpoint e não editar o arquivo de outro grupo.

Grupos válidos: `estrutura`, `acessos-pessoas`, `publicacoes-midia`,
`chat-comunicacoes`, `perfil-para-voce`, `alunos-rotina`,
`formularios-cuidado`, `operacoes-sistema`.

## Campos mínimos de `<grupo>.json`

```json
{
  "grupo": "publicacoes-midia",
  "revision": 1,
  "updatedAt": "2026-09-09T19:00:00-03:00",
  "app": "Claude|Codex",
  "modelo": "modelo realmente ativo",
  "conversa": "nome/ID real da conversa",
  "worktree": "C:/Users/adrie/Documents/Coelo.worktrees/e2-noturna-<grupo>",
  "branch": "work/etapa2-noturna-<grupo>",
  "head": "sha",
  "upstream": "origin/work/etapa2-noturna-<grupo>",
  "divergencia": "0/0",
  "base": "d784462c168d22fdb7090b7de1ef7db554ad5107",
  "escopo": [{ "tela": "...", "subtela": "...", "action_ids": ["..."] }],
  "mudou": "o que mudou desde a revisão anterior",
  "criteriosFechados": ["..."],
  "testes": { "P": 0, "F": 0, "B": 0, "S": 0, "U": 0, "evidencia": "caminho" },
  "arquivosReservados": ["..."],
  "bloqueio": null,
  "proximoPasso": "ação exata",
  "wip": [{ "caminho": "...", "sha256": "..." }],
  "recursos": { "processos": [], "portas": [] },
  "filhos": []
}
```

Nenhum campo desconhecido vira zero: usar `null` ou
`"nao calculavel ainda"`.

## Regras de recebimento

Arquivo escrito **não** é mensagem recebida. O recibo durável é a entrada
correspondente em `receipts[]` de `coordenacao.json`, com grupo e revisão.
Não esperar ACK para trabalho independente já autorizado; mudança em arquivo
reservado depende de atribuição registrada.

Logs e evidências completas ficam na worktree/branch do executor. O JSON aponta
caminhos, commits e hashes — nunca copia logs, credenciais ou segredos.

## Cortes obrigatórios

| Responsável | Congelar | Pré-entrega | Entrega e parada |
| --- | --- | --- | --- |
| Codex (`estrutura`, `acessos-pessoas`) | 09/09 23:10 | 09/09 23:20 | 09/09 23:30 |
| Executores Claude | 10/09 04:40 | 10/09 04:50 | 10/09 05:00 |
