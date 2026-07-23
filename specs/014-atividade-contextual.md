---
title: "Atividade Contextual"
source: "conversa com usuario em 2026-07-23; docs/architecture/domain-map.md; docs/data/data-model.md; docs/security/auth-multitenant-permissions.md; docs/product/prd-admin.md; docs/product/prd-superadmin.md"
status: "approved-for-planning"
generated_at: "2026-07-23"
---

# Atividade Contextual

## Objetivo

Formalizar `Atividade` como um conceito de dominio independente dentro da estrutura institucional do Coelo. A atividade nao substitui o grupo/turma: ela especializa o que acontece dentro de uma turma, com reutilizacao entre turmas da mesma instituicao, permissao contextual por turma e professores vinculados por turma.

## Problema

A hierarquia atual resolve bem instituicao > unidade > grupo, mas nao representa com clareza recortes como biologia, capoeira, musica, reforco ou oficinas dentro de uma mesma turma. Sem um conceito proprio, o produto tende a misturar funcao, permissao e menu da turma inteira com a atuacao especifica de um professor.

## Escopo

- Criar e editar atividades com nome livre e descricao.
- Permitir criacao pela instituicao ou por uma unidade autorizada.
- Reutilizar a mesma atividade em varias turmas da mesma instituicao.
- Exigir vinculacao da atividade a pelo menos uma unidade na criacao, com possibilidade de adicionar outras depois.
- Permitir vinculacao da atividade a uma ou mais turmas.
- Permitir vinculacao de pessoas a atividade naquela turma, com papel e permissoes especificos, incluindo mais de um professor na mesma turma.
- Sugerir listas padrao de atividades na criacao de instituicao e unidade.
- Expor a atividade primeiro no Supabase, depois no menu do Superadmin/Admin e, por fim, nas telas.

## Fora de Escopo

- Criar um catalogo global compartilhado entre instituicoes.
- Permitir reutilizacao entre instituicoes diferentes.
- Transformar atividade em novo nivel rigido acima do grupo.
- Definir todas as telas finais agora.
- Fixar nomes fisicos finais da migration sem revisao tecnica.

## Superficies Afetadas

- Supabase/Postgres
- RLS e funcoes server-side
- Mapa de dominios
- Modelo de dados master
- PRD Master
- PRD Admin
- PRD Superadmin
- Menu do Superadmin e, depois, do Admin
- Futuras telas de gerenciamento de atividades

## Entidades E Dados

- `activity_definitions`: definicao da atividade por instituicao, com nome, descricao, status, origem da criacao e ator responsavel.
- `activity_unit_links`: disponibilidade obrigatoria da atividade por unidade na criacao, com expansao posterior.
- `activity_group_links`: vinculo da atividade com a turma.
- `activity_group_assignments`: pessoas vinculadas a atividade naquela turma.
- `activity_permission_profiles`: permissoes padrao e overrides por turma, herdando regras da instituicao e da unidade.
- `activity_suggestions`: sementes padrao sugeridas na criacao de instituicao ou unidade.

## Regras De Permissao E Tenant

- A atividade pertence sempre a uma instituicao.
- A instituicao ou uma unidade autorizada pode criar a atividade.
- Quando a unidade cria, o `institution_id` e herdado automaticamente da instituicao-mae e a unidade de origem se torna o primeiro vinculo obrigatorio.
- A instituicao mantem autoridade para editar, ampliar vinculos, restringir, arquivar ou desativar atividades criadas por suas unidades.
- Uma unidade ou usuario da unidade so pode criar atividade quando a capacidade especifica de criar/gerir atividades estiver habilitada na gestao do seu perfil.
- O ator com escopo apenas de unidade nao pode vincular a atividade a unidades irmas ou grupos fora de seu escopo sem permissao institucional adicional.
- A mesma atividade pode ser reutilizada somente em turmas da mesma instituicao.
- O acesso efetivo nasce do vinculo pessoa + atividade + turma + unidade + instituicao.
- Um professor pode ser responsavel por uma atividade em uma turma e nao ter o mesmo poder em outra.
- Uma mesma atividade pode ter mais de um professor na mesma turma.
- Permissoes padrao podem ser herdadas da instituicao e da unidade, mas a turma pode restringir ou complementar o escopo.
- Toda decisao final continua server-side/RLS.

## Estados De UX

- Lista de atividades da instituicao.
- Criacao institucional ou criacao pela unidade autorizada.
- Acao de criar indisponivel, com motivo visivel, quando o perfil da unidade nao possuir a capacidade exigida.
- Atividade criada, sem turma vinculada ainda.
- Atividade vinculada a pelo menos uma turma.
- Atividade com professor/papel definido na turma.
- Atividade sem professor vinculado em uma turma.
- Atividade desativada ou arquivada.
- Sugestao padrao visivel na criacao de instituicao/unidade.

## Eventos, Logs E Notificacoes

- `activity_created`
- `activity_created_by_unit`
- `activity_updated`
- `activity_linked_to_unit`
- `activity_linked_to_group`
- `activity_member_assigned`
- `activity_permission_changed`
- `activity_suggestion_seeded`

Registros sensiveis devem entrar em auditoria quando alterarem acesso, professor vinculado ou escopo de turma.

## Criterios De Aceite

- Uma atividade pode ser criada com nome e descricao livres.
- Uma unidade autorizada pode criar uma atividade, que nasce pertencendo a instituicao-mae e vinculada a unidade de origem.
- Uma unidade sem a capacidade especifica nao pode criar atividade.
- A instituicao pode ajustar uma atividade criada por qualquer unidade filha.
- A mesma atividade pode ser vinculada a multiplas turmas da mesma instituicao.
- A mesma atividade pode ter professores diferentes em turmas diferentes.
- Permissoes da atividade podem variar por turma sem quebrar a heranca institucional.
- A criacao de instituicao e unidade pode sugerir atividades padrao.
- O conceito aparece nos documentos oficiais e na sequencia de implementacao.

## Testes Exigidos

- Criar atividade com nome livre e descricao.
- Criar atividade como unidade autorizada e validar a heranca automatica da instituicao e o vinculo inicial com a unidade de origem.
- Negar a criacao por unidade ou usuario da unidade sem a capacidade especifica habilitada no perfil.
- Validar que a instituicao pode editar, restringir e desativar uma atividade criada pela unidade.
- Negar que um ator restrito a unidade vincule a atividade a unidade irma ou grupo fora do seu escopo.
- Vincular atividade a duas turmas da mesma instituicao, mantendo ao menos uma unidade obrigatoria no cadastro inicial.
- Garantir que a mesma atividade nao seja reutilizada em outra instituicao.
- Validar permissao de professor em uma turma e negar em outra.
- Validar dois ou mais professores vinculados a mesma atividade e turma.
- Validar heranca de permissao padrao da instituicao/unidade com override por turma.
- Validar seeds de sugestao na criacao de instituicao/unidade.

## Riscos E Perguntas Abertas

- Definir se a atividade tera pagina propria ou apenas subpagina dentro do grupo no MVP.
- Definir se o nome exibido para a turma devera ser "atividade" em todos os contextos ou se a UI podera usar termos mais amigaveis.
- Fechar o formato fisico dos grants por atividade sem abrir regra demais no cliente.
- Definir na Technical Spec o identificador fisico da capacidade de criar/gerir atividades exposta na gestao do perfil.
- Decidir quais tipos de sugestao padrao entram por tipo de instituicao.
