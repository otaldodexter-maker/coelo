---
title: "Backend produtivo da Agenda institucional do Superadmin"
source: "decisions/0029-superadmin-agenda-backend-authorization.md; specs/006-comunicacao-agenda.md; docs/product/prd-master.md; docs/security/lgpd-security-media.md"
status: approved
generated_at: "2026-09-01"
---

# Backend produtivo da Agenda institucional do Superadmin

## Objetivo e problema

Persistir e autorizar a Agenda institucional já aprovada no Superadmin sem
sucesso falso, acesso cruzado ou dependência de fixtures em rotas produtivas.

## Escopo

- eventos, séries e exceções de recorrência;
- audiência por instituição, unidade, grupo, atividade e pessoa;
- perguntas curtas e Sim/Não, lembretes e modo de resposta;
- RSVP, ciência e autorização simples;
- solicitações e decisões de publicação;
- solicitações de responsáveis já previstas pela UI;
- histórico imutável de criação, edição, publicação, cancelamento, restauração,
  exclusão de rascunho e sobrescrita de conflito;
- leitura paginada por período e contexto;
- RPCs produtivas para o Superadmin.

## Fora de escopo

- telas ou rotas em Admin e Principal;
- entrega real por canal de notificação;
- autorização formal do domínio D14;
- upload de anexos até contrato próprio de Storage/R2;
- perguntas com upload, documento, saúde, biometria ou outro dado sensível.

## Entidades e dados

`agenda_events` guarda o agregado e exatamente um contexto principal.
`agenda_audiences`, `agenda_questions`, `agenda_reminders` e
`agenda_recurrence_exceptions` detalham o agregado. `agenda_responses` guarda
uma resposta por participante elegível. `agenda_publication_requests` e
`agenda_guardian_requests` preservam seus lifecycles. `agenda_history_receipts`
é append-only.

Todas as entidades institucionais carregam `institution_id`; FKs de contexto
devem provar que unidade, grupo e atividade pertencem à mesma instituição.

## Permissões e tenant

As capabilities são as sete definidas em `specs/006-comunicacao-agenda.md`.
Elas pertencem a Perfis e Permissões e são revalidadas pelo backend. Leitura
exige ator autenticado e capability efetiva no contexto. Escritas verificam
ator, ownership, tenant, lifecycle, versão otimista e idempotência. IDs e
filtros enviados pelo cliente nunca ampliam escopo.

Tabelas públicas usam RLS habilitada e forçada, sem grants diretos para `anon`
ou `authenticated`. O cliente executa apenas RPCs públicas específicas; funções
`SECURITY DEFINER` usam `search_path` vazio ou explícito mínimo e revogam
`EXECUTE` de `public`/`anon`.

## Estados e regras de UX

O contrato preserva os estados `draft`, `scheduled`, `published` e `canceled`.
Somente rascunho pode ser excluído. Publicado pode ser cancelado e restaurado.
Conflito comum avisa; reserva conflitante bloqueia, salvo capability de
sobrescrita e justificativa. Uma falha não altera o agregado.

Perguntas aceitam apenas `short_text` e `yes_no`, título entre 1 e 240
caracteres e não podem conter termos do catálogo server-side de dados sensíveis.

## Eventos, logs e notificações

Cada mutação grava recibo com request ID, ator, ação, recurso, instituição,
versão anterior/nova, justificativa minimizada e instante. Lembretes guardam
somente o momento relativo/customizado; canais permanecem fora do contrato.

## Critérios de aceite

- CRUD e lifecycle persistem após recarga.
- Repetição do mesmo request ID não duplica efeitos.
- Concorrência com versão desatualizada falha sem sobrescrever dados.
- Acesso cross-tenant e acesso direto por ID falham.
- `anon` não lê nem executa comandos.
- Policies, grants, FKs e índices passam nos testes SQL e advisors relevantes.
- Flutter produtivo não usa `AgendaPrototypeStore`.

## Testes exigidos

- SQL positivo e negativo por capability;
- matriz cross-tenant para leitura e escrita;
- lifecycle completo e transições inválidas;
- conflito de reserva com e sem sobrescrita;
- idempotência e versão otimista;
- validação de perguntas e minimização;
- teste Flutter de composição produtiva e reload.

## Riscos e perguntas abertas

A entrega por push/e-mail e retenção jurídica detalhada das respostas continuam
pendentes de contrato próprio. Até lá, o banco não armazena conteúdo sensível,
anexos ou payloads livres além dos campos explicitamente limitados.
