---
title: "Pessoas, Acessos Contextuais E Assiduidade"
source: "decisions/0015-contextual-people-authorizations-attendance.md; docs/superpowers/specs/2026-07-24-contextual-people-access-activities-attendance-design.md"
status: "approved-for-documentation"
generated_at: "2026-07-24"
---

# Pessoas, Acessos Contextuais E Assiduidade

## Objetivo E Problema

Definir as rotinas de acesso entre instituicoes, unidades, grupos, atividades,
criancas, responsaveis e profissionais. O modelo deve suportar multi-papel,
escopos parciais, pessoas autorizadas sem login, transferencias, chat
hierarquico e assiduidade sem misturar experiencias ou tenants.

## Escopo

- Pessoa global e experiencias familiar/profissional.
- Papeis padrao e personalizados.
- Escopos automaticos ou selecionados.
- Responsaveis por crianca e unidade/instituicao.
- Pessoas autorizadas para emergencia, retirada e transporte.
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
- Nomes fisicos finais de tabelas e funcoes.
- Implementacao imediata no Supabase.

## Superficies Afetadas

- Supabase/Postgres, Auth, RLS e Realtime.
- Admin e Principal.
- Superadmin para inspecao e auditoria.
- Chat, notificacoes e analytics.
- Agenda, rotina, midia, Now e Atividades como consumidores de contexto.

## Entidades E Dados Conceituais

### Identidade E Autorizacao

- Pessoa global e Auth opcional.
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

`Outros` usa tipo catalogado e detalhe livre separado. Mais de uma pessoa pode
usar o mesmo tipo de relacao com a crianca.

O catalogo inicial inclui pai, mae, avo, ava, irmao, irma, padrasto, madrasta,
primo, prima, tio, tia e outros. O detalhe preserva a descricao informada para
analise futura sem alterar silenciosamente o catalogo.

### Pessoas Autorizadas

- Pessoa operacional sem acesso ao Coelo.
- CPF protegido, contato e foto opcional.
- Vinculo e detalhe.
- Tipos de autorizacao.
- Criancas e unidades abrangidas.
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

- Pessoa nova.
- Pessoa existente encontrada sem revelar outro tenant.
- Convite pendente, aceito, expirado ou revogado.
- Permissoes revisadas antes do envio.
- Acesso alterado ou suspenso.

### Pessoas Autorizadas

- Lista visivel somente com capacidade.
- Autorizacao ativa imediatamente.
- Autorizacao suspensa por seguranca.
- Autorizacao expirada ou removida.

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
- `authorized_person_created`
- `authorized_person_changed`
- `authorized_person_suspended`
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
- Um profissional acumula papeis e escopos diferentes.
- Unidade nao acessa unidade irma.
- Profissional por crianca nao ve o restante da turma.
- Convite com irmaos cria relacoes e capacidades independentes.
- Responsavel acompanha novos grupos/atividades dentro do escopo concedido.
- Responsavel sem capacidade nao descobre pessoas autorizadas.
- Transferencia exige aceite do destino.
- Atividade local e promovida sem duplicacao.
- Participacao de atividade aceita turma inteira ou selecao de criancas.
- Chat mostra autor, papel, escopo e criancas relacionadas.
- Equipe nao configurada nao le chat institucional/unidade.
- Aviso familiar aparece como pendencia.
- Aviso futuro gera lembrete D-1 para familia e equipe afetada.
- Pendencia nao vira oficial automaticamente.
- Somente `Gerenciar presenca` altera registro oficial.
- Dashboards separam registros oficiais de pendencias.
- Acesso cross-tenant e cross-unit falha.

## Testes Exigidos

- Pessoa responsavel e professora na mesma instituicao.
- Papeis aditivos com deny individual.
- Admin de unidade com todos os grupos versus grupos selecionados.
- Profissional de atividade sem acesso ao grupo geral.
- Profissional limitado a crianca.
- Convite institucional versus convite de unidade.
- Varios responsaveis com capacidades diferentes.
- Pessoa autorizada invisivel a responsavel sem capacidade.
- Suspensao imediata de pessoa autorizada.
- Transferencia aceita, rejeitada e parcial em lote.
- Promocao de atividade preservando ID e origem.
- Atividade com toda turma e com criancas selecionadas.
- Chat com nenhuma, uma e varias criancas.
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
