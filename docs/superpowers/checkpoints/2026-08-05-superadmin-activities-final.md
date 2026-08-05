---
source: "Plano aprovado e checkpoint 2026-08-04-superadmin-activities-review-handoff.md"
status: "completed"
generated_at: "2026-08-05"
---

# Checkpoint final - Atividades do Superadmin

## Objetivo

Concluir o diretorio e o fluxo Criar/Editar Atividade, sem alterar outras telas, regra de negocio, persistencia ou Supabase.

## Escopo concluido

- Diretorio com tabs visuais de status, toggle Cards/Tabela, flyout Coelo e tabela responsiva.
- Wizard responsivo de quatro etapas com callbacks locais e sem persistencia.
- Categorias, imagem local, instituicao, unidades, locais, turmas e profissionais por turma.
- Permissoes Happens, Now, Moments e Chat inicialmente ativas.
- Edicao hidratada por draft de apresentacao, sem selecionar arbitrariamente a primeira unidade.
- ActivityFormDraft, atribuicoes e permissoes na camada de apresentacao.
- CoeloAdminToggleField acessivel usado nas permissoes da atividade.
- Microcopy ajustada para Simples/Opcional.
- Mobile e tablet preservam colorScheme.surface como base; cinza fica restrito a superficies secundarias funcionais.

## Decisoes preservadas

- Baselines: Criar/Editar Instituicao, diretorio de Instituicoes, tabs de Pessoas e flyout do Tour.
- Tabs de status sao somente visuais nesta entrega.
- Rascunho exige nome, instituicao e unidade; conclusao exige uma turma.
- Instituicao permanece fixa na edicao.
- Defaults de permissao nao representam autorizacao efetiva.
- Nenhuma operacao Supabase, migration ou schema foi criada ou alterada.
- Nenhuma outra tela foi ajustada.

## Verificacoes

- Atividades: 19 testes focados verdes.
- Coelo UI: 22 testes focados verdes.
- Analise focada de Atividades: sem issues.
- Analise focada de Coelo UI: sem issues.
- git diff --check nos caminhos da entrega: exit 0.
- Gate visual global bloqueado por cinco InkWell preexistentes em Imports, Comunicados e Suporte; nenhum pertence a Atividades e nenhum foi alterado ou allowlistado.

## Pendencias

Nenhuma pendencia funcional conhecida em Atividades neste escopo. Integracao real dos callbacks permanece fora de escopo.

## Retomada

Abrir primeiro apps/superadmin/lib/features/activities/presentation/activity_form_controller.dart e executar os testes focados de controller, pagina e diretorio de Atividades.
