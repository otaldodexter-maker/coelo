---
title: "Segurança infantil e Medicação: notificações à hierarquia e políticas macro da unidade"
source: "Resposta do Owner à P32 (docs/reviews/etapa-2-operacao/next-round/R04-perguntas-ao-owner-20260911.md, 11/09/2026); ADR 0034 Decisão 15; pacotes 20260910171800..172100 (decisão pelo Superadmin); specs/018 e specs/020; AGENTS.md"
status: "draft-for-owner-review; nao implementado"
generated_at: "2026-09-11"
author: "frente R05 · Formulários, Cuidado e Rotina"
---

# Segurança infantil e Medicação: notificações e políticas macro

## Objetivo e problema

Hoje uma autorização de retirada (Segurança infantil) é cadastrada e decidida
pelo Superadmin com auditoria (P32 opção B, pacote 171800). O Owner definiu a
regra alvo: quando um **responsável** cadastra ou retira alguém da segurança da
criança, a unidade e toda a hierarquia da criança são avisadas no sino, e a
unidade ou instituição escolhe, numa **tela de políticas macro**, se essa
alteração precisa de aceite para valer. O mesmo conceito vale para Medicação,
incluindo a opção de a unidade **não acompanhar medicação**.

Esta spec fixa o contrato mínimo para o MVP+1. Não altera o comportamento do
Superadmin (B continua valendo).

## Escopo

- Notificações no sino (`notifications`) para alterações feitas por
  responsáveis em Segurança infantil e em Medicação.
- Tabela de políticas macro por instituição, com sobrescrita por unidade,
  começando por duas famílias: `child_safety` e `medication`.
- Aplicação da política no servidor: a alteração nasce `pending` ou `active`
  conforme a política; o aceite é um comando auditado.
- Primeira tela de "Políticas da unidade" no Superadmin (leitura e edição
  pelo Owner/Admin da instituição e da unidade, conforme P23).

## Fora de escopo

- Notificação push/e-mail (só sino no MVP+1).
- Políticas de outras famílias (Agenda, Acontece, Cardápios): a tela nasce
  com as duas famílias e cresce depois.
- App Principal (a UI do responsável fica na Etapa 3); aqui só o contrato de
  servidor que o Principal vai consumir.

## Superfícies afetadas

- `apps/superadmin`: Estrutura → Unidades → Políticas (nova subtela);
  Segurança infantil (badge "aguardando aceite" e ação Aceitar/Recusar);
  Saúde e Cuidado → Medicação (mesmo badge e ação; aviso "esta unidade não
  acompanha medicação").
- `packages/coelo_database`: tabelas, RPCs e triggers abaixo.

## Entidades e dados

`public.unit_policies`
- `id uuid`, `institution_id uuid not null`, `unit_id uuid null` (nulo = padrão
  da instituição), `family text check (family in ('child_safety','medication'))`,
- `acceptance_mode text check in ('none','all','inclusion_only','exclusion_only')`
  (default `all` para `child_safety`, `none` para `medication`),
- `tracking_enabled boolean not null default true` (só faz sentido em
  `medication`: `false` = a unidade não acompanha medicação),
- `version bigint`, `updated_by_person_id`, `updated_at`; unicidade
  `(institution_id, coalesce(unit_id, institution_id), family)`.
- Resolução: política da unidade > política da instituição > default.

`public.notifications` (existente; conferir contrato) recebe linhas por
destinatário com `kind in ('child_safety.changed','child_safety.pending',
'medication.changed','medication.pending')`, `object_type`, `object_id`,
`child_context_id`, `actor_person_id`, `requires_action boolean`.

Autorizações (`child_safety_pickup_authorizations`) e planos
(`medication_plans`) ganham `acceptance_status text` (`not_required`,
`pending`, `accepted`, `rejected`) e `accepted_by_person_id/at`. Nenhuma
coluna existente muda de significado.

## Permissões e regras de tenant

- Políticas: ler com `institutions.read` no contexto; editar com o papel de
  Owner/Admin da instituição ou da unidade (P23) ou `platform.manage` no
  Superadmin. RLS por `institution_id`/`unit_id`; deny-by-default; FORCE.
- Notificações: só o destinatário lê a própria linha (policy por
  `recipient_person_id = current_person_id()`); escrita só por função
  `security definer` do pacote.
- Aceite: quem tem `child_safety.manage` (ou `medication.manage`) no contexto
  da criança; o comando registra `audit.audit_logs` com `before/after`.
- Alteração feita pelo Superadmin (B) não gera pendência de aceite (ele já
  decide), mas gera as notificações à hierarquia e aos demais responsáveis.

## Regras de comportamento

1. Ao **incluir** ou **retirar** pessoa autorizada (ou criar/alterar plano de
   medicação) por um responsável:
   - resolver a política; se `tracking_enabled=false` em `medication`, o
     comando é recusado com `MEDICATION_NOT_TRACKED` (mensagem honesta);
   - decidir `acceptance_status`: `all` → `pending`; `inclusion_only` →
     `pending` só para inclusão; `exclusion_only` → `pending` só para
     retirada; `none` → `not_required` (vale de imediato);
   - notificar: unidade (Owner/Admin/Secretaria via perfis), hierarquia da
     criança (pessoas com vínculo profissional ativo na turma, na unidade e
     na instituição: professores, coordenação, direção) e os **demais
     responsáveis** da criança; `requires_action=true` para quem pode aceitar.
2. **Aceitar** move para `accepted` (autorização vira `active`; plano vira
   `approved`); **Recusar** move para `rejected` e notifica o responsável que
   pediu. Ambos auditados.
3. Enquanto `pending`, a autorização não libera retirada e o plano não
   permite registro de dose (fail-closed).
4. Mudar a política não altera pendências já abertas.

## Estados de UX (Superadmin)

- Políticas: carregando; padrão herdado (mostra "herdado da instituição");
  editado; salvo; erro de permissão ("Só o Owner/Admin desta unidade altera").
- Segurança infantil/Medicação: badge "Aguardando aceite" na lista e no
  detalhe; ações Aceitar/Recusar com confirmação e motivo opcional; estado
  "Unidade não acompanha medicação" com card Criar visível e inerte
  (mensagem honesta), mantendo busca/filtros/abas (regra do estado vazio).

## Eventos, logs e notificações

- `audit.audit_logs`: `unit_policies.update`, `child_safety.acceptance`,
  `medication.acceptance`, com `institution_id` e `child_context_id`.
- Notificações listadas acima; leitura marca `read_at`.

## Critérios de aceite

- pgTAP: política resolvida por unidade > instituição > default; cada modo
  gera `pending`/`not_required` conforme a tabela; destinatários corretos
  (hierarquia e outros responsáveis, nunca de outro tenant); aceite exige
  capacidade e audita; `tracking_enabled=false` recusa criar plano.
- Rota real: editar política da unidade sintética, cadastrar autorização
  como responsável (usuário sintético do Principal, a criar), ver a
  notificação e o badge no Superadmin, aceitar, reload mantém.

## Testes exigidos

- pgTAP do pacote (fixture com instituição, unidade, turma, criança, dois
  responsáveis, professor, coordenação; sessão de responsável e de Owner).
- Widget tests da tela de Políticas e do badge/aceite.

## Riscos e perguntas abertas

- Quem é "unidade" para fins de notificação: proposta = pessoas com perfil
  de Owner/Admin/Secretaria na unidade. Confirmar com o Owner.
- Base legal para notificar outros responsáveis sobre alteração de retirada:
  registrar em `docs/open-questions.md` (LGPD, melhor interesse da criança).
- Medicação "não acompanhada": esconder o menu ou manter com aviso? Proposta
  = manter com aviso (regra do estado vazio).
- Tamanho: um pacote SQL (faixa 2026091122xxxx) e uma subtela; não cabe na
  R05 além desta spec. Pacote de notificações do realm-interno (item 6 da G5)
  pode absorver a tabela de políticas se chegar primeiro.
