# Revisao G7 — Momentos: retirada autoral

- Data: 2026-09-12
- Escopo: leitura do defeito medido pela G4 e do candidato G5 `b74e8c9f1` (`20260912140550_moments_withdraw_permission_v1.sql`).
- Fora do escopo: aplicacao SQL, producao, Flutter, alteracao de regras de produto e moderacao.

## Resultado estatico

O 403 reproduzido pela G4 e compativel com um grant ausente: o autor interno
Owner recebe o papel de sistema `institution_admin`, enquanto a capability
`moments.publications.remove` foi cadastrada depois do seed desse papel.

O candidato concede a capability somente a `institution_admin`. Esta e a
correcao minima para o ator medido; nao concede a `institution_reader`,
coordinator, teacher ou secretaria. A retirada continua sendo exclusivamente
autoral: `withdraw_moment` nao foi alterada e ainda reautoriza permissao,
instituicao, unidade/turma e `target.author_person_id = actor.person_id`.
Nao ha regra de moderacao neste pacote.

O hint `can_withdraw` passa a exigir autoria e a mesma capability/contexto da
RPC. Isso elimina a afordancia enganosa para um leitor ou ator fora de escopo;
o cliente segue sem decidir autorizacao.

## Condicao para prova no espelho

O pgTAP novo (4 casos) valida catalogo/grant, hint estrutural e ACL, mas nao
exerce as negativas comportamentais. Antes de promover o pacote, a prova focal
deve cobrir: autor admin no mesmo escopo; outro autor; leitor interno; e
instituicao/unidade/turma fora do escopo. Nos tres ultimos casos a retirada
deve ser negada e a publicacao deve permanecer inalterada.

## Veredito

Revisao estatica aprovada para o minimo de autorizacao. A certificacao depende
das negativas comportamentais no espelho e da execucao exclusiva do C0/G0.
