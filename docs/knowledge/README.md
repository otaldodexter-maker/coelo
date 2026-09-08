---
title: Governança da base de conhecimento Coelo
knowledge_id: knowledge-governance
source: AGENTS.md
status: validated
generated_at: 2026-07-27
audience: team
surfaces:
  - documentation
visibility: internal
review_owner: Coelo Owner
---

# Base de conhecimento Coelo

Esta pasta é uma projeção consultável das fontes canônicas do produto. Ela não
substitui PRDs, specs, ADRs, políticas de segurança nem autorização
server-side.

## Fluxo

1. Consultar esta pasta e as fontes canônicas antes do trabalho.
2. Atualizar primeiro a fonte canônica quando uma decisão aprovada estiver
   incompleta.
3. Projetar somente conhecimento durável, aprovado e reutilizável.
4. Separar artigos por audiência e validar o conteúdo com a skill
   `coelo-knowledge`.
5. Manter conflitos em `docs/open-questions.md`.

Não são permitidos conversas brutas, dados reais de crianças, tenants
reconhecíveis, CPF, mensagens, mídias, logs integrais, segredos ou hipóteses
apresentadas como fatos.

## Contrato de validação e busca — 2026-09-08

Cada artigo exige strings não vazias para `title`, `knowledge_id`, `source`,
`status`, `generated_at`, `audience`, `visibility` e `review_owner`; `surfaces`
é lista YAML não vazia de strings (inline ou bloco). Datas são datas reais em
YYYY-MM-DD, incluindo `updated_at` quando presente. Chaves YAML duplicadas são
inválidas. `knowledge_id` usa kebab-case e é único dentro de cada audiência;
a mesma identidade pode relacionar artigos de team, admin e users.

`source` é um caminho relativo com / para arquivo existente dentro do
repositório; não pode escapar por `..`, link simbólico ou apontar para
`docs/knowledge`. Existência não comprova aprovação: conferir status e conteúdo
na fonte canônica. Campos e texto continuam sujeitos à revisão humana.

A busca literal retorna `validated` por padrão, com opção explícita de status
para inspeção histórica/rascunhos e `-Detailed` para conferir fonte e audiência.
A pasta `users` corresponde a `audience: user`; a CLI aceita `user` e `users`.
A descoberta interna `all` não autoriza entregar orientação interna a usuários.
Falha de validação impede tratar a busca como evidência de conteúdo confiável.

Scripts exigem Python 3.10+ e PyYAML conforme requirements da skill, sem
instalação automática. A detecção de CPF/segredos/conversa é uma barreira
heurística e não substitui revisão de PII, aprovação e minimização. O termo
`service_role` em orientação segura é permitido; atribuir-lhe um valor não é.
