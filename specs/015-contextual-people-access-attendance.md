---
title: "Pessoas, Acessos Contextuais E Assiduidade"
source: "decisions/0015-contextual-people-authorizations-attendance.md; docs/superpowers/specs/2026-07-24-contextual-people-access-activities-attendance-design.md"
status: "implemented-database-foundation"
generated_at: "2026-07-24"
---

# Pessoas, Acessos Contextuais E Assiduidade

## Objetivo E Problema

Definir as rotinas de acesso entre instituicoes, unidades, grupos, atividades,
criancas, responsaveis e profissionais. O modelo deve suportar multi-papel,
escopos parciais, pessoas de confianca sem login, transferencias, chat
hierarquico e assiduidade sem misturar experiencias ou tenants.

## Escopo

- Pessoa global e experiencias familiar/profissional.
- Pre-cadastro adulto e solicitacao de vinculo institucional.
- Cadastro infantil hibrido com validacao institucional.
- Papeis padrao e personalizados.
- Escopos automaticos ou selecionados.
- Responsaveis por crianca e unidade/instituicao.
- Pessoas de confianca privadas e autorizacoes contextuais para emergencia,
  retirada e transporte.
- Transferencia entre unidades.
- Governanca, promocao e participacao em atividades.
- Chat por instituicao, unidade, grupo e atividade.
- Avisos familiares e registro oficial de presenca.
- Dashboards de assiduidade.

## Fora De Escopo

- Login infantil no MVP.
- Modelo comercial de responsaveis adicionais.
- Prazo juridico de retencao.
- Telas finais.
- Telas e navegacao dos apps.

## Superficies Afetadas

- Supabase/Postgres, Auth, RLS e Realtime.
- Admin e Principal.
- Superadmin para inspecao e auditoria.
- Chat, notificacoes e analytics.
- Agenda, rotina, midia, Now e Atividades como consumidores de contexto.

## Entidades E Dados Conceituais

### Identidade E Autorizacao

- `people` como identidade global de adulto ou crianca.
- Usuario Auth como credencial opcional; crianca nao possui credencial no MVP.
- Conta adulta global pode existir antes de qualquer vinculo institucional.
- Solicitacao de vinculo por busca exata, link ou QR, sempre pendente ate
  validacao institucional.
- Membership institucional.
- Catalogo de papeis e capacidades.
- Atribuicoes de papel por escopo.
- Overrides individuais allow/deny.
- Atribuicoes profissionais por crianca.
- Experiencias derivadas dos vinculos ativos.

### Familia

- Catalogo de relacoes familiares.
- Relacao global responsavel-crianca.
- Acesso contextual por crianca e escopo.
- Capacidades familiares.
- Convites por instituicao ou unidade.
- Contexto infantil pertencente a instituicao.
- Primeiro vinculo institucional da crianca em unidade.
- Alocacao posterior e opcional em turma.

`Outros` usa tipo catalogado e detalhe livre separado. Mais de uma pessoa pode
usar o mesmo tipo de relacao com a crianca.

O catalogo inicial inclui pai, mae, avo, ava, irmao, irma, padrasto, madrasta,
primo, prima, tio, tia e outros. O detalhe preserva a descricao informada para
analise futura sem alterar silenciosamente o catalogo.

### Pessoas De Confianca E Autorizacoes

- Fonte privada e reutilizavel do responsavel, sem acesso ao Coelo.
- CPF protegido, contato e foto opcional.
- Vinculo e detalhe.
- Autorizacao independente por instituicao, contexto infantil e unidade.
- Tipos de autorizacao, sem dependencia de turma.
- Validade, status, autor e suspensor.

### Transferencias

- Origem, destino, criancas, data e grupo sugerido.
- Estados pendente, aceito, rejeitado, correcao solicitada e cancelado.
- Decisao e motivo auditados.

### Atividades

- Origem institucional/unidade.
- Disponibilidade institucional/local.
- Politica opcional/obrigatoria/fixa.
- Unidades abrangidas.
- Participacao de turma inteira ou criancas selecionadas.
- Capacidades e bloqueios institucionais.

### Chat

- Conversa e equipe de atendimento por contexto.
- Participacao por pessoa e membership/experiencia.
- Criancas relacionadas.
- Snapshot de papel e contexto por mensagem.
- Caixa `Conversas` como consulta agregada, sem criar escopo de autorizacao
  compartilhado.

### Assiduidade

- Sessao de presenca de grupo ou atividade.
- Participantes esperados.
- Aviso do responsavel.
- Registro oficial.
- Motivo e detalhe.
- Justificativa e anexo.
- Revisao, desfazimento e auditoria.
- Lembretes e cards contextuais.

## Permissoes E Regras De Tenant

- Instituicao pode operar qualquer contexto do proprio tenant.
- Unidade opera somente o proprio escopo quando autorizada.
- Unidade nao concede acesso a unidade irma.
- Grupo e atividade nunca escapam da instituicao/unidade coerentes.
- Convite institucional e convite de unidade produzem escopos diferentes.
- Conta, e-mail e `@identificador` nao concedem acesso sem convite ou
  solicitacao aprovada.
- Solicitacao de vinculo pendente nao revela dados institucionais privados.
- Responsavel ve somente criancas e modulos autorizados.
- Profissional ve somente unidades, grupos, atividades ou criancas atribuidos.
- Allows de papeis se somam; deny individual explicito prevalece.
- Todas as mutacoes sensiveis usam caminho server-side/RLS e auditoria.

## Estados De UX

### Experiencias

- Contexto familiar ativo.
- Contexto profissional ativo.
- Nenhum contexto valido.
- Contexto revogado durante uso.
- Escopo completo ou selecionado.

### Convites E Responsaveis

- Conta global pre-cadastrada e ainda sem contexto.
- Pessoa nova.
- Pessoa existente encontrada sem revelar outro tenant.
- Convite pendente, aceito, expirado ou revogado.
- Solicitacao de vinculo pendente, em revisao, aprovada, rejeitada ou
  identificada como possivel duplicidade.
- Crianca validada e vinculada a unidade, ainda sem turma.
- Permissoes revisadas antes do envio.
- Acesso alterado ou suspenso.

### Pessoas De Confianca E Autorizacoes

- Lista visivel somente com capacidade.
- Pessoa de confianca reutilizavel em mais de uma crianca ou instituicao.
- Autorizacao ativa imediatamente.
- Autorizacao suspensa por seguranca apenas na unidade/contexto decidido.
- Autorizacao expirada ou removida.

### Caixa De Conversas

- `Todas` como visao inicial.
- `Instituicoes e unidades`, `Turmas` e `Atividades` como filtros opcionais.
- Filtro de crianca em nivel separado.
- Contexto revogado removido imediatamente dos resultados, sem ampliar acesso
  por filtro ou cache.

### Transferencia

- Pendente no destino.
- Correcao solicitada.
- Aceita.
- Rejeitada.
- Crianca aguardando alocacao.
- Resultado parcial em lote.

### Presenca

- Sem aviso.
- Presenca esperada informada.
- Ausencia informada pendente.
- Atraso ou saida antecipada informados.
- Registro oficial confirmado.
- Justificativa pendente, aceita ou rejeitada.
- Acao desfeita com historico.

## Eventos, Logs E Notificacoes

- `guardian_invited`
- `guardian_access_changed`
- `guardian_access_suspended`
- `guardian_link_requested`
- `guardian_link_reviewed`
- `child_context_validated`
- `trusted_person_created`
- `trusted_person_changed`
- `trusted_person_authorization_created`
- `trusted_person_authorization_changed`
- `trusted_person_authorization_suspended`
- `trusted_person_authorization_revoked`
- `child_transfer_requested`
- `child_transfer_decided`
- `professional_scope_changed`
- `activity_promoted`
- `activity_participation_changed`
- `attendance_notice_created`
- `attendance_record_confirmed`
- `attendance_record_changed`
- `attendance_record_reverted`

Push e notificacoes nao carregam CPF completo, anexos sensiveis ou detalhes
alem do necessario.

## Criterios De Aceite

- Responsavel/profissional alterna experiencia sem mistura.
- Adulto pre-cadastrado continua sem acesso ate convite ou solicitacao
  aprovada.
- Cadastro infantil iniciado por qualquer lado exige validacao institucional.
- Aprovacao cria vinculo com unidade mesmo quando a turma ainda nao foi
  definida.
- Um profissional acumula papeis e escopos diferentes.
- Unidade nao acessa unidade irma.
- Profissional por crianca nao ve o restante da turma.
- Convite com irmaos cria relacoes e capacidades independentes.
- Responsavel acompanha novos grupos/atividades dentro do escopo concedido.
- Responsavel sem capacidade nao descobre pessoas de confianca ou
  autorizacoes.
- Pessoa de confianca e reutilizada sem compartilhar autorizacao, status ou
  suspensao entre instituicoes/unidades.
- Autorizacao de retirada permanece valida apos troca de turma na mesma
  unidade.
- Transferencia exige aceite do destino.
- Atividade local e promovida sem duplicacao.
- Participacao de atividade aceita turma inteira ou selecao de criancas.
- Chat mostra autor, papel, escopo e criancas relacionadas.
- Caixa unica retorna conversas independentes autorizadas; filtros de tipo e
  crianca nao ampliam acesso.
- Equipe nao configurada nao le chat institucional/unidade.
- Aviso familiar aparece como pendencia.
- Aviso futuro gera lembrete D-1 para familia e equipe afetada.
- Pendencia nao vira oficial automaticamente.
- Somente `Gerenciar presenca` altera registro oficial.
- Dashboards separam registros oficiais de pendencias.
- Acesso cross-tenant e cross-unit falha.

## Testes Exigidos

- Pessoa responsavel e professora na mesma instituicao.
- Adulto pre-cadastrado sem acesso institucional.
- Convite para adulto existente por e-mail ou `@identificador`.
- Solicitacao de vinculo por busca exata, link e QR, pendente ate aprovacao.
- Revisao de possivel duplicidade sem merge automatico.
- Cadastro infantil iniciado pelo responsavel e pela instituicao.
- Crianca vinculada a unidade sem grupo e alocada posteriormente.
- Papeis aditivos com deny individual.
- Admin de unidade com todos os grupos versus grupos selecionados.
- Profissional de atividade sem acesso ao grupo geral.
- Profissional limitado a crianca.
- Convite institucional versus convite de unidade.
- Varios responsaveis com capacidades diferentes.
- Pessoa de confianca invisivel a responsavel sem capacidade e a outro tenant.
- Reutilizacao da mesma pessoa de confianca em criancas e instituicoes
  diferentes.
- Suspensao imediata e independente por unidade, sem alterar outra
  autorizacao.
- Transferencia aceita, rejeitada e parcial em lote.
- Promocao de atividade preservando ID e origem.
- Atividade com toda turma e com criancas selecionadas.
- Chat com nenhuma, uma e varias criancas.
- Caixa unica com filtros de tipo e crianca em niveis separados.
- Revogacao dinamica remove conversa e operacoes de caches, Realtime e
  consultas sem depender apenas de participante desativado.
- Troca de profissional preservando autoria e historico.
- Aviso de ausencia confirmado, corrigido e mantido pendente.
- Presenca de grupo diferente de presenca de atividade.
- RLS cross-tenant, cross-unit, cross-group, cross-activity e cross-child.

## Riscos E Decisoes Adiadas

- Matriz extensa de capacidades exige UX clara.
- Contexto ativo incorreto pode causar acao no papel errado.
- Documentos de justificativa exigem classificacao e acesso restrito.
- Retencao de chat e dados infantis depende de decisao juridica.
- Experiencia infantil futura depende de consentimento e LGPD.
- Modelo comercial de responsaveis nao integra esta spec.

## Implementacao Fisica Verificada Em 2026-07-24

A fundacao desta spec foi aplicada ao projeto Supabase `coelo`
(`evvbomzejfijozbtgvpt`). A autorizacao efetiva usa membership ativo, papeis e
permissoes, grants diretos, escopo contextual e
`institution_member_permission_overrides`; deny individual explicito
prevalece.

As estruturas principais implementadas sao:

- familia: `family_relationship_types`, `guardian_context_permission_grants`,
  `guardian_invitation_children`, `authorized_people` e
  `authorized_person_authorizations`;
- transferencia e notificacao: `child_unit_transfer_requests`,
  `child_unit_transfer_items`, `context_notification_events` e
  `context_notification_recipients`;
- atividade: `activity_capability_policies`,
  `activity_group_capability_settings` e `activity_group_participants`;
- chat: settings institucionais/de unidade, equipes, participantes,
  criancas relacionadas, snapshots de autoria e RPC transacional de criacao;
- assiduidade: catalogo, sessoes, participantes esperados, avisos, anexos,
  registros oficiais, revisoes e views agregadas `security_invoker`.

Todas as 30 tabelas novas expostas possuem RLS, policy, grants explicitos,
registro em `schema_tables`/`schema_columns` e nenhum grant para `anon`.
Comandos sensiveis usam RPCs server-side e auditoria. O aviso familiar de
presenca permanece pendente ate confirmacao profissional.

A fundacao fisica ainda precisa ser consolidada antes do consumo operacional:
a fonte privada reutilizavel da pessoa de confianca e a revogacao dinamica de
chat nao estao completas. Esta spec nao autoriza migration ou alteracao de RLS
sem plano tecnico aprovado.
