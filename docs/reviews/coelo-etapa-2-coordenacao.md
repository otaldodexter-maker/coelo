---
title: "Coelo — Coordenação da Etapa 2"
source: "Conversa Coordenar Etapa 2 do Coelo; seis conversas delegadas; docs/reviews/coelo-flutter-pendencias.md; docs/reviews/coelo-supabase-pendencias.md; docs/reviews/coelo-flutter-integrado-supabase-pendencias.md"
status: "active"
generated_at: "2026-09-01"
updated_at: "2026-09-01"
---

# Coelo — Coordenação da Etapa 2

## Finalidade

Este documento é o índice operacional da Etapa 2. Ele preserva propriedade,
proveniência, checkpoints e handoffs entre conversas. O recorte é exclusivo de
`apps/superadmin` e dos pacotes/backend indispensáveis ao Superadmin. Nenhuma
frente está autorizada a alterar `apps/admin`, `apps/site` ou `apps/principal`.
Não substitui os três rastreadores especializados e não promove `local-green`,
mock ou rota `/dev` para conclusão Flutter, Supabase ou ponta a ponta.

## Progresso estrito de referência

- Projeto estrito `done`: 0/229 unidades.
- Flutter `local-green`: 102/207 ações; Flutter `verified`: 0/207.
- Supabase `local-green`: 3/37 famílias; Supabase `done`: 0/37.
- Integração E2E: 0/202 ações.
- Tempo total usado e ETA geral: não calculáveis até os checkpoints finais das
  seis frentes e a confirmação do orçamento global de coordenação.

## Propriedade por frente

| Frente | Conversa | Propriedade exclusiva ou principal | Integrações compartilhadas |
| --- | --- | --- | --- |
| Comunicação | `01a05db6-b171-7a80-9e07-592e2e08dbe9` | Chat/Conversas, Convites e Comunicações/Avisos | Entrega o núcleo funcional de Chat à superfície Coelo (Principal) do Superadmin; recebe handoff histórico de Chat de Estruturas. |
| Operações | `01a05d88-3187-79a3-9443-218a0c5cb8ae` | Cardápios, Formulários, Agenda, Importações e Planos | Consome o shell Superadmin; não recria cabeçalho mobile. |
| Acessos e Saúde/Cuidado | `01a05d66-fdec-7f31-a4c3-fe7f7654e51b` | Pessoas, Usuários internos, Segurança da criança, Perfis/Modelos, Saúde e Medicação | Auth permanece transversal; não duplica Chat ou shell. |
| Auth | `01a05d37-a36d-7610-b9dc-f8259243ffcd` | Login, sessão, bootstrap, autorização transversal e produção Auth | Testes de rotas de outras features comprovam somente gates Auth. |
| Estruturas | `01a05d2b-d4e4-7a90-95a6-e9a401ab5836` | Instituições, Unidades, Turmas, Atividades, Avaliações e cabeçalho mobile global do Superadmin | Handoff de Chat para Comunicação; `SuperadminShell` é compartilhado por todas as telas Superadmin. |
| Coelo (Principal) | `01a05dce-96ed-7ca3-b3eb-e4701473510b` | Menu/superfícies Acontece, Para Você, Agora, Momentos, Perfil e Circulares dentro do Superadmin | Implementa o launcher e a superfície de Chat desse menu consumindo o núcleo de Comunicação; não altera `apps/principal`. |

## Contratos transversais

### Cabeçalho mobile do Superadmin

- Proprietário: Estruturas.
- Implementação compartilhada: `SuperadminShell`, com base no commit
  `d9232a94`.
- Abrangência: todo `apps/superadmin`.
- As outras frentes validam rotas representativas dentro do shell e registram
  incompatibilidades; não criam cabeçalhos locais concorrentes.
- O menu Coelo (Principal) permanece dentro de `apps/superadmin`; esta etapa não
  materializa nem altera o aplicativo `apps/principal`.

### Chat

- Comunicação mantém domínio, repository, backend, RLS, permissões e fluxo
  funcional compartilhável.
- Coelo (Principal) mantém somente a integração visual e a navegação dentro do
  menu homônimo do Superadmin.
- Estruturas não continua Chat; seu trabalho anterior deve chegar a
  Comunicação por checkpoint recuperável.
- Conclusão exige abrir, listar, enviar, negar acesso indevido, persistir e
  recarregar nos consumidores aplicáveis.

### Arquivos compartilhados e conflitos esperados

- `superadmin_router.dart`: Comunicação, Operações, Acessos, Auth e Estruturas.
- `superadmin_auth_scope.dart`: Auth, Acessos e Estruturas.
- testes de rotas de Chat: Comunicação, Auth e handoff histórico de Estruturas.
- navegação administrativa: Operações e Acessos.
- os três rastreadores: múltiplas frentes, sempre com atualização por
  `action_id`/checkpoint e reconciliação final pelo Coordenador.

## Snapshot recuperável das worktrees

Referência: 2026-09-01, após a redistribuição de Chat/Circulares.

| Frente | Branch | HEAD | Estado observado |
| --- | --- | --- | --- |
| Comunicação | `codex/finalizar-tela-comunicacao` | `393fc7ff` | Em andamento; Convites e Comunicações possuem alterações/testes/goldens não commitados. |
| Operações | `codex/finalizacao-telas-operacoes` | `7b8a4d02` | Em andamento; Formulários, Cardápios e rotas possuem alterações não commitadas. |
| Acessos e Saúde | `codex/accessos-ponta-a-ponta` | `056f29d2` | Em andamento; Perfis/Modelos e migration nova ainda não commitados. |
| Auth | `codex/auth-first-local-green` | `36ae7c86` | Worktree limpa no snapshot; produção permanece condicionada aos gates registrados pela frente. |
| Estruturas | `codex/estruturas-superadmin` | `560ce79c` | Rastreadores e migration de modelo por unidade ainda não commitados; `.artifacts` permanece fora de Git. |
| Coelo (Principal) | `codex/finalizar-telas-coelo-principal` | `6cb7aa53` | Worktree limpa no snapshot; recorte do menu Superadmin ampliado com Circulares e integração visual do Chat, sem tocar `apps/principal`. |

## Evidências e referências

- Evidência do inventário de pastas do Coordenador:
  `docs/reviews/evidence/etapa-2/coordenador/`.
- Comunicação preservou nove referências visuais no commit `f6d44af9`.
- Nenhuma referência temporária deve ser considerada preservada somente porque
  permanece no histórico da conversa; deve possuir arquivo estável e manifesto.

## Handoffs recebidos

### Auth-first — `36ae7c86`

- Worktree limpa e quatro commits preservados: `ac167623`, `70065ad3`,
  `db712f24` e `36ae7c86`.
- Quatro ações Auth não-MFA propostas como Flutter/backend `local-green`;
  integração continua `blocked-supabase`, MFA permanece `blocked-decision` e
  `fail-closed`.
- Evidências informadas: `coelo_auth` 21/21, foco Superadmin 57/57, replay
  Auth-only pgTAP 29/29 e lifecycle local real completo.
- Produção permaneceu sem mutação. O ledger produtivo não é compatível com uma
  aplicação segura do pacote atual; dump/replay compatível, migration única
  forward-only, URL/redirect e E2E continuam pendentes.
- Diffs dos três rastreadores estão preservados nos commits de documentação e
  aguardam reconciliação central com o código alcançável.

### Comunicações/Avisos — `ee8d3aff`

- `notices.list` permanece Flutter `local-green` e integração
  `blocked-supabase`; nenhuma promoção foi proposta.
- Evidências informadas: 37/37 testes focados, analyzer e validador visual
  verdes, 20 fixtures coerentes e 13 goldens revisados.
- Produção, RLS, permitido/negado, vínculo revogado, tenant A/B, persistência,
  reload, auditoria e E2E continuam abertos.
- Proposta de 45 linhas para os três rastreadores permanece não commitada na
  worktree de Comunicação e não deve ser descartada até captura central.

### Estruturas — `560ce79c`

- Commits preservados: `b0fb1293`, `d9232a94`, `0b20d76a` e `560ce79c`.
- Evidências informadas: analyzer completo sem problemas; 62 testes de
  Atividades/Chat, 18 de Auth/router, seis de adapters e 86 de shell/rotas
  estruturais passaram. Chat aparece somente como regressão/handoff histórico.
- Adapters de Unidades/Turmas não são CRUD produtivo concluído: os RPCs legados
  são people-based e o ator interno permanece bloqueado pela OQ-043.
- Migration e pgTAP de modelos por Unidade continuam não rastreados. O teste
  prevê 31 asserts, mas não houve replay Docker; estado correto é
  `in-progress/local-review`, nunca `local-green`.
- Diffs dos três rastreadores, spec e projeção de dataset estão preservados;
  `.artifacts` permanece fora da entrega. Ao reconciliar, corrigir a referência
  antiga de 12 para 31 asserts sem promover estado.

### Convites — worktree Comunicação em `ee8d3aff`

- Diretório/detalhe e fixtures `/dev` foram corrigidos localmente; importação e
  exportação permanecem placeholders explicitamente indisponíveis.
- Evidências informadas: 46 testes funcionais/responsivos, quatro goldens e 12
  testes de repository passaram; analyzer, validador visual e diff-check verdes.
- Flutter local do diretório/detalhe pode ser proposto como `local-green`, mas
  CRUD/RLS/remoto/E2E continuam abertos e Convites não está concluído ponta a
  ponta.
- `InviteFormPage` conserva overflow preexistente de 45 px em 375 px/200% e
  goldens divergentes; registrar como pendência Flutter explícita.
- Alterações e sete goldens permanecem sem commit na worktree compartilhada e
  não devem ser perdidos durante o checkpoint da frente Comunicação.

## Monitoramento e encerramento

- Automação horária ativa: `etapa-2-acompanhamento-hor-rio`.
- Cada frente deve enviar checkpoint diretamente ao Coordenador pelo menos uma
  vez por hora, além de reportar conclusão de unidade, bloqueio, regressão,
  mudança de ETA, commit e proximidade de limite/contexto.
- Escrita dos três rastreadores oficiais é centralizada no Coordenador. As
  frentes executoras entregam proposta estruturada por `action_id`/gate,
  evidência, estado, bloqueio e ETA; não criam novas edições concorrentes em
  `coelo-flutter-pendencias.md`, `coelo-supabase-pendencias.md` ou
  `coelo-flutter-integrado-supabase-pendencias.md`.
- Diffs de rastreadores já existentes em worktrees são preservados e tratados
  como propostas de handoff. O Coordenador valida contra código, testes e
  ambiente antes de incorporá-los à versão canônica.
- Cada relatório deve separar concluído, pendente, bloqueado, Flutter,
  Supabase, E2E, testes, commits, worktree e ETA.
- Conversa parada com recorte aberto recebe continuação no primeiro gate
  incompleto.
- Antes de consolidar: exigir checkpoint/commit, diff-check, varredura de
  segredos, rastreadores atualizados e lista de arquivos não rastreados.
- Depois de consolidar: executar regressão conjunta, conferir os três
  rastreadores, validar conhecimento, provar ancestralidade e só então remover
  worktrees/branches autorizadas.
