---
source: "Solicitacao do fundador em 2026-07-29; specs/012-superadmin-mvp.md; docs/product/prd-master.md; packages/coelo_database/migrations/20260623191021_superadmin_foundation_v1.sql; Instituicoes como referencia visual aprovada"
status: "approved"
generated_at: "2026-07-29"
updated_at: "2026-08-03"
---

# Grupos (Turmas) no Superadmin

## Objetivo

Entregar a listagem, criacao e edicao local de grupos no Superadmin com a
mesma linguagem visual e os mesmos contratos de interacao aprovados para
Instituicoes. Grupo continua sendo a entidade canonica; `Turma` é seu termo
equivalente de apresentação no contexto escolar e nunca representa uma
entidade-pai ou outro nível da hierarquia.

## Escopo

- Listagem em cards e tabela, busca por nome, filtros de instituicao, unidade,
  tipo e status, ordenacao e paginacao sticky.
- Estados loading, vazio, sem resultados, falha e sem permissao.
- Criacao e edicao dos campos fisicos confirmados: instituicao, unidade, nome,
  `group_type` textual e `record_status`.
- Importacao e exportacao demonstrativas, sem arquivo, parser ou persistencia.
- Repositorio fake independente durante esta etapa.

Ficam fora do escopo professor, turno, ano letivo, faixa, modalidade,
capacidade, contatos, descricao, slug, participantes e demais dados nao
presentes em `public.groups`. Tambem ficam fora migrations, policies, RPCs,
tokens, variantes e APIs publicas.

## Dominio e autorizacao

Todo grupo pertence obrigatoriamente a uma unidade e a uma instituicao. Na
criacao, a unidade so pode ser escolhida dentro da instituicao selecionada. Na
edicao, instituicao e unidade permanecem somente leitura ate existir regra
aprovada para movimentacao hierarquica.

`group_type` permanece texto livre. O valor fisico `class` aparece como
`Turma`; novos valores digitados sao preservados e os filtros exibem apenas os
tipos presentes nos registros. Status usa `draft`, `active`, `inactive`,
`suspended` e `archived`; criacao inicia em `active`, conforme o default
fisico.

O Supabase atual possui somente leitura de grupos por `platform.read`. Criar e
editar permanecem locais; a UI nao infere autorizacao por metadata do cliente
e nao contorna RLS.

## Listagem

A toolbar ordena busca, Instituicoes, Unidades, Tipos, Status, alternancia de
visualizacao e Arquivos. Todos os filtros da listagem sao multi-select.
Unidades dependem das instituicoes selecionadas e selecoes invalidas sao
descartadas.

Cards preservam a geometria de Instituicoes e mostram somente nome, status,
instituicao, unidade e tipo. A tabela fixa Grupo e oferece Instituicao,
Unidade, Tipo e Status, com hover, foco, selecao, ordenacao, resize e scroll
horizontal.

Cards iniciam com 11 itens e opcoes 11/20/50/100; tabela inicia com 8 e opcoes
8/20/50/100. O footer sticky mede a propria altura e desloca o launcher.

Arquivos oferece `Importar grupos` e `Exportar grupos` como demonstracao
explicita no centro de atividades, sem alegar suporte produtivo.

## Formulario

O formulario usa uma unica secao responsiva: Instituicao e Unidade em
single-select, Nome e Tipo em campos textuais e Status em single-select. O
grid tem uma coluna no compacto e ate duas a partir do breakpoint medio.

Cancelar com alteracoes abre dialogo neutro compartilhado. Escape fecha o
dialogo, mantem a edicao e restaura foco. O rodape usa `surface`, nao cobre o
ultimo campo e mantem a acao primaria em largura util no compacto.

## Acessibilidade e verificacao

Validar 375, 768, 1024 e 1440 px, light e dark, texto a 200%, mouse, touch,
teclado, foco, Escape, semantica, reduced motion, scroll horizontal e ausencia
de sobreposicao entre conteudo, paginacao e launcher.

Testes seguem RED/GREEN. Goldens novos de Grupos sao inspecionados
visualmente; goldens de Instituicoes nao sao alterados.
