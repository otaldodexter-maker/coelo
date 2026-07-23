---
title: "Addendum de Atividade Contextual"
source: "conversa com usuario em 2026-07-23; docs/architecture/domain-map.md; docs/data/data-model.md; docs/product/prd-master.md"
status: "planning-addendum"
generated_at: "2026-07-23"
---

# Addendum De Atividade Contextual

`Atividade` e um dominio proprio do Coelo para recortes funcionais dentro do grupo/turma.

## Regras Oficiais

- A atividade pertence sempre a instituicao e pode ser criada pela instituicao ou por unidade autorizada.
- Quando criada pela unidade, herda automaticamente a instituicao-mae, registra a unidade de origem e nasce vinculada a ela.
- A instituicao mantem autoridade para ajustar, ampliar, restringir, arquivar ou desativar a atividade criada pela unidade.
- A unidade ou usuario da unidade so cria atividade quando a capacidade especifica estiver habilitada na gestao do perfil.
- A mesma atividade pode ser reutilizada em varias turmas da mesma instituicao.
- A turma continua sendo o centro de operacao; a atividade especializa o contexto.
- Professores e coordenadores podem ser vinculados por turma, com permissoes contextuais.
- Instituicao e unidade podem sugerir atividades padrao na criacao.
- A implementacao deve começar pelo Supabase, depois menu e, por fim, tela.

## Relacionamento Com O Mapa

- Tenancy continua sendo a hierarquia institucional.
- Atividade contextual fica como dominio complementar entre Tenancy e Contexto/Autorizacao.
- O dominio deve aparecer no banco, nas permissoes, no menu e nas futuras telas.
