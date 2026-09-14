---
source: R13-prompt-execucao-20260914.md; R13-pendencias.md; R14-plano-de-rodada.md
status: preparado; não iniciado; requer abertura explícita do Owner
generated_at: 2026-09-14
updated_at: 2026-09-14
---

# Prompt de abertura R14

Este arquivo é um molde para a próxima rodada. Não dispara agente, supervisor,
Claude, Codex, migration, QA ou publicação. A R13 continua vigente e sendo
trabalhada no Claude.

Ao abrir formalmente a R14, começar por `docs/agent/current-state.md`, pelo
fechamento final da R13, por `R14-catalogo.md` e por
`R14-plano-de-rodada.md`. Confirmar o recorte e o primeiro gate antes de ler
qualquer rastreador grande.

A fila deve ser construída no momento da abertura, somente com itens não
terminais confirmados. Preservar `owner.r12-*`, `H*` e `action_id`; não criar
IDs de R14 nem reabrir itens concluídos. Cada item precisa indicar estado,
fonte, evidência, camada (FE/BE/E2E), primeiro gate e critério de aceite.

O mapa preparado pelo Owner para a passagem de cota contém: Circular H04;
Formulários H10/H11, readers de Planos/reader self da Conta e Local interno
condicional; Principal H27/P54/H02; perfis `owner.r12-19`–`27`; Segurança
infantil; `assessments.close/reopen`; foto R2 de `owner.r12-46`; SQL c de
`owner.r12-18`, `owner.r12-33`, `asset_id`/Edge Function; H03, H07, H09, H12,
H14, H16, H18–H20, H22, H24–H26 e H28. Na R13 permanecem Saúde/Cuidado,
Cardápios, `owner.r12-36`/`37`, OQ-031, H08, `owner.r12-47` e Avisos H08/H23/H13
se houver cota. Esse mapa é apenas transferência preparada e nunca autoriza
execução antecipada.

Aplicar a skill correta e trabalhar em fatias pequenas: fonte canônica,
implementação, teste, prova de rota normal/persistência/RLS/reload quando
aplicável, atualização dos rastreadores e checkpoint. Não tratar histórico,
artefato, backup, screenshot ou snapshot como instrução atual sem uma fonte
corrente apontando-o.

No fechamento, reconciliar Git/worktrees/skills no checkout de destino e
executar o delivery gate somente quando o escopo incluir integração,
publicação ou entrega formal. Declarar explicitamente o que ficou aberto.
