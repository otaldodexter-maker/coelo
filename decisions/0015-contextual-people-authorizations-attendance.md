---
title: "Pessoas Contextuais, Autorizacoes Operacionais E Assiduidade"
source: "docs/superpowers/specs/2026-07-24-contextual-people-access-activities-attendance-design.md; validacao do usuario em 2026-07-24"
status: "Accepted"
generated_at: "2026-07-24"
---

# Pessoas Contextuais, Autorizacoes Operacionais E Assiduidade

## Contexto

Uma pessoa pode ser responsavel e profissional, acumular papeis em varios
escopos e participar de instituicoes diferentes. Criancas podem frequentar
varias unidades, grupos e atividades. Uma arvore rigida de perfis ou uma
permissao unica por usuario nao representa essas combinacoes com seguranca.

O Coelo tambem precisa separar responsaveis que usam o aplicativo de pessoas
autorizadas apenas para emergencia, retirada ou transporte. Presenca,
ausencia, atraso e saida antecipada exigem fluxo proprio, sem transformar o
chat na fonte oficial do registro.

## Decisao

### Identidade E Experiencias

- Pessoa e global e pode existir sem Auth.
- Crianca nao possui login no MVP, mas a estrutura fica preparada para perfil
  e experiencia infantil futura.
- Experiencias familiar e profissional sao separadas.
- Uma unica credencial pode alternar experiencias autorizadas.
- Cada acao preserva pessoa, papel, escopo e sujeito representado.

### Hierarquia E Autorizacao

- Instituicao e o tenant.
- Unidade pertence a instituicao.
- Grupo pertence obrigatoriamente a unidade.
- Atividade pertence a instituicao, mesmo quando criada por unidade.
- Escopos podem abranger descendentes atuais e futuros ou somente selecoes
  explicitas.
- Allows de papeis ativos sao aditivos.
- Restricao individual explicita prevalece no proprio escopo.
- Profissional pode ser limitado a unidade, grupo, atividade ou criancas
  especificas.

### Familia

- Relacao familiar global e separada do acesso institucional.
- Somente instituicao ou unidade convida responsavel.
- Convite institucional pode abranger o tenant; convite de unidade fica
  restrito a unidade e seus descendentes.
- Um convite pode conter varias criancas, com relacao e capacidades separadas.
- Capacidades familiares nascem habilitadas e podem ser alteradas no convite
  ou posteriormente.
- Responsavel acompanha automaticamente os vinculos da crianca dentro do
  escopo concedido.
- Nao existe regra comercial de limite de responsaveis nesta decisao.

### Pessoas Autorizadas

- Pessoa autorizada para emergencia, retirada ou transporte nao recebe acesso
  ao aplicativo.
- Autorizacao e ligada a crianca, unidade, tipo, validade e ator.
- Responsavel com capacidade especifica pode criar autorizacao com efeito
  imediato.
- Instituicao ou unidade pode suspender por seguranca, com motivo e auditoria.
- Somente responsaveis com a capacidade visualizam lista e notificacoes
  detalhadas.

### Transferencias

- Unidade de origem pode solicitar transferencia para outra unidade do tenant.
- Destino aceita, rejeita ou solicita correcao.
- Aceite encerra e cria vinculos de forma transacional.
- Sem grupo, a crianca fica aguardando alocacao.
- Acesso institucional acompanha; acesso local e autorizacoes operacionais nao
  migram silenciosamente.

### Atividades

- Origem, disponibilidade e politica institucional sao dimensoes separadas.
- Atividade local pode ser promovida a padrao institucional sem duplicacao.
- Politica pode ser opcional, obrigatoria ou fixa.
- Atividade fixa possui configuracoes bloqueadas pela instituicao.
- Participacao pode abranger toda a turma ou criancas selecionadas.
- Presenca, rotina, agenda, midia, Now e chat sao capacidades configuraveis e
  continuam pertencendo aos seus dominios.

### Chat

- Chat pode ter contexto de instituicao, unidade, grupo ou atividade.
- A instituicao pode oferecer chat institucional, chat da unidade ou ambos; em
  operacao com uma unica unidade, pode unificar os canais ou desabilitar o
  canal da unidade.
- Mensagem mostra a pessoa real que respondeu, seu papel e o contexto.
- Responsavel pode tratar de nenhuma, uma ou varias criancas.
- Equipes de atendimento determinam quem recebe chats institucionais e de
  unidade.
- Professor de atividade conversa apenas com responsaveis dos participantes.
- Historico preserva autoria e permanece institucional quando profissionais
  mudam.

### Presenca E Assiduidade

- Presenca geral e presenca de atividade sao registros separados.
- Aviso do responsavel e intencao; registro profissional e oficial.
- Ausencia informada preenche a lista como pendente.
- Pendencia nao vira oficial automaticamente.
- Somente capacidade `Gerenciar presenca` permite confirmar ou corrigir.
- Motivos usam catalogo institucional extensivel e `Outro + detalhe`.
- Avisos futuros de ausencia, atraso ou saida antecipada geram lembrete D-1
  para responsaveis e profissionais afetados.
- Chat pode exibir card e resposta, mas nao substitui o dominio de presenca.
- Dashboards oficiais e pendencias usam indicadores separados.

## Consequencias

- O modelo atual do Supabase e uma fundacao parcial e precisara de migrations
  pequenas para pessoas autorizadas, transferencias, atribuicoes por crianca,
  participacao em atividade, governanca de atividade, chat contextual e
  assiduidade.
- Policies do Admin e Principal devem ser desenhadas por capacidade e escopo.
- Navegacao e cache precisam recompor a experiencia ativa.
- Notificacoes devem minimizar dados sensiveis.
- Auditoria deve preservar antes/depois, ator, sujeito e contexto.

## Fora De Escopo

- Cobranca ou limite comercial de responsaveis.
- Prazo juridico de retencao.
- Login infantil no MVP.
- Nomes fisicos finais das novas tabelas.
- Autorizacao para executar migrations sem plano tecnico aprovado.
