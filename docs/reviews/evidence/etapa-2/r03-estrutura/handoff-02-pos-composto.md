---
title: "Handoff 2 — Estrutura: rebase no composto, achados e o que está retido"
source: "worktree e2-r03-estrutura, branch work/etapa2-r03-estrutura"
status: "entregue ao coordenador e ao Owner"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# Handoff 2 — grupo estrutura

**Base:** `origin/dev e21f5a391`, o composto da Fase 0 já cobrindo as quatro
famílias de diretório do recorte. **HEAD:** `edd5853c3`, publicado, árvore limpa,
sem WIP retido. Treze commits rebasearam sem um conflito: a Fase 0 mexeu nos
diretórios, eu nos formulários, no banco e nos testes.

# O que fechou

**Fila SQL.** Os três pacotes retidos desde a rodada anterior estão verdes em
pgTAP local: 109 asserções, `Result PASS`, zero recurso Docker residual, no
perfil `StructureLocationConsumersV1` que precisei escrever. Entrega em
`sql-package-handoff.json`.

**Defeitos corrigidos, quatro deles.** A confirmação de saída obsoleta de
Instituições, com prova causal. As mesmas guardas assíncronas em Unidades e na
assinatura de Instituições, como endurecimento declarado sem caso reprodutor. O
balão de chat que sumia do formulário de Atividades. E a exportação de Unidades,
que anunciava no sininho uma exportação bem-sucedida, com nome de arquivo, para
um arquivo que nunca existiu.

**Cobertura que faltava.** Instituições e Unidades eram as duas famílias de
Estrutura sem prova de que suas rotas de mutação caem na página honesta de
indisponível. Agora têm, nos dois sentidos.

# O que precisa de outra pessoa

| Item | De quem | Consequência de não acontecer |
| --- | --- | --- |
| Aplicar os três pacotes e ligar as chaves | coordenador | Quatro ações seguem fail-closed |
| **Inscrever `20260909210000` na fila** | coordenador | Quem seguir a fila pula o pacote de Turmas e o sintoma só aparece depois |
| Leitura de `pg_proc` das **treze** RPCs de Unidades | coordenador | `units.*` e metade de Turmas indecidíveis |
| Decisão RODAPÉ | Owner | Goldens de formulário de Turmas e Atividades não podem ser regravados |
| Decisão do diálogo de importar de Unidades | Owner | Tela segue contrariando a regra de import/export adiado |
| Decisão do diretório de Turmas sem filtro | Owner | `groups.list` espera Unidades sem precisar |
| Proposta de separar a chave de Estrutura por realm | coordenador e Owner | Cinco ações presas por uma razão que não se aplica a elas |
| `COELO_SUPABASE_URL` / `PUBLISHABLE_KEY` | Owner | Nenhuma ação passa da régua do MVP no meu lado |

# Um alerta sobre a rodada, não sobre o recorte

`comunicacao/coordenacao.json` continua na revisão 31, da rodada anterior. Quatro
grupos da Rodada 3 já publicaram — `acessos-pessoas`, `fase0`,
`principal-chat-sistema` e este — e nenhum recebeu ACK ou recibo. A conversa P1
de Coordenação e Integração aparentemente não foi aberta.

Isso não bloqueia o trabalho de cada frente, mas bloqueia tudo que só o
coordenador faz: aplicar SQL em produção, ligar as chaves de composição,
integrar as branches em `dev`, atualizar os três rastreadores e o inventário, e
levar as decisões ao Owner. Enquanto ela não abrir, o que está pronto fica
pronto e parado.
