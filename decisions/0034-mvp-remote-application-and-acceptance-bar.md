---
title: "Aplicação remota autorizada e régua de aceite do MVP"
source: "decisão do Owner Coelo em 2026-09-10; AGENTS.md; docs/superpowers/specs/2026-09-01-coelo-review-progress-metrics-design.md"
status: "approved"
generated_at: "2026-09-10"
---

# ADR 0034 — Aplicação remota autorizada e régua de aceite do MVP

## Contexto

Entre 08/09 e 10/09/2026 três rodadas de execução produziram treze pacotes SQL
revisados e verdes em pgTAP local, e nenhum chegou ao banco. A regra vigente
tratava todo recurso remoto como produção e exigia autorização nominal do Owner
por pacote; nenhuma autorização foi concedida, então Back-end e E2E ficaram em
zero por construção. O projeto Supabase `coelo` (`evvbomzejfijozbtbvpt`) ainda
não tem clientes reais. O Owner precisa mostrar o app funcional a um cliente em
duas semanas.

## Decisão 1 — autorização permanente de aplicação forward-only

O Owner autoriza de forma permanente que o integrador aplique migrations
forward-only no projeto Supabase de produção, sem pedido por pacote, quando:

1. o pgTAP local do pacote passou;
2. a ordem serializada da fila foi respeitada;
3. o backup por ponto no tempo do projeto está ligado;
4. o pacote não contém segredo, bucket público nem dado pessoal.

O que ficar aberto depois da aplicação (negativas remotas, reload, E2E) vai
para os rastreadores de Back-end e Front-end + Back-end. O Owner revisa em
ciclo semanal ou quinzenal; a pendência não retém o pacote. A mesma
autorização cobre ligar as chaves de composição do cliente
(`structureMutationsEnabled`, adapters `available: false`) assim que o SQL
correspondente estiver aplicado.

Segredos, buckets e Workers do Cloudflare continuam exigindo autorização
nominal até que o Owner estenda esta decisão a eles.

## Decisão 2 — régua de aceite do MVP

Uma ação da Etapa 2 conta como verificada no MVP quando:

1. a rota normal abre a tela sem fixture nem fail-closed;
2. o CRUD persiste no Supabase real;
3. o RLS nega outro tenant;
4. o reload mantém o estado.

RLS, hierarquia, capacidade e autorização no servidor continuam obrigatórios
dentro de cada migration e são provados uma vez por pacote em pgTAP. As provas
exaustivas por ação (duas sessões concorrentes com revogação durante espera, ID
adulterado tela por tela, auditoria com retry, golden por estado, tenant A/B
por ação) ficam para a fase de revisão profunda de segurança, depois do MVP.
Golden divergente não bloqueia `verified` no MVP; fica registrado.

## Decisão 3 — IDs de estado saem do percentual do MVP

IDs que representam estados de uma tela (recarregar, erro e retry, acesso
negado) e as importações/exportações adiadas permanecem no inventário, mas
não entram no denominador do MVP. Eles são conferidos junto com a tela a que
pertencem e voltam a contar na revisão profunda.

## Decisão 4 — pontos abertos respondidos pelo Owner em 10/09/2026

- Unidades: autorizada leitura de `pg_proc` em produção para conferir se as
  cinco RPCs do diretório existem fora do versionamento.
- Instituições: corrigir a confirmação de saída com alterações que aparece na
  hora errada.
- Tabela administrativa: implementar rolagem vertical no Design System
  (`coelo_ui_admin`), não limitar linhas na tela.
- Chip "Destaque": escurecer o fundo para atingir contraste AA e regravar os
  goldens afetados depois.
- Suporte e Conta / Perfil: construir a camada Supabase agora; não saem do MVP.
- Cardápios: enviar `p_expected_revision` ao apagar imagem.
- Avisos agendados: ligar `pg_cron` no projeto e implantar o worker de
  publicação.
- MFA: o MVP fica sem segundo fator (AAL1), conforme ADR 0019.
- Anexos de UI/UX passados às skills continuam como correções pendentes
  (cards e tabelas fora do padrão, diferenças no menu Coelo Principal); não
  são aprovação do render atual. Goldens só são regravados depois dessas
  correções.

## Consequências

- O replay local com Docker deixa de ser porta obrigatória; continua útil para
  o ciclo rápido de pgTAP.
- Tempo gasto em manifestos com hash, recibos e consolidações longas deve ser
  cortado; o Git é o recibo.
- As três skills de revisão e os três rastreadores permanecem como direção e
  registro do que falta.
