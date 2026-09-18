---
source: Owner e cinco anexos de Cardápios na conversa de 2026-09-13; decisions/0032-mvp-private-media-r2.md
status: backlog R12; sem implementação
generated_at: 2026-09-13
---

# R12 — Cardápios e modelos

Quinto bloco de R12-apontamentos-owner.md. Fora da implementação R11.
Host apps/superadmin > Cardápios; família administrativa, componentes canônicos
Coelo. Cinco anexos vistos na conversa, binários não exportados ao repositório.
Responsável: C0 R12 após abertura explícita. Nenhuma prova funcional nova.

| ID / anexo | Tela/subtela e action_ids | Requisito e primeiro gate |
|---|---|---|
| R12-34 / 1 | Criar/Editar modelo > Modelo > Refeição; meal-plans.model-create, meal-plans.model-edit; conferir reutilização em meal-plans.create/edit | Ao adicionar refeição, permitir definir nome; título do bloco reflete nome definido, não Refeição 1 como identificação permanente. Diferenciar nome da refeição, tipo e prato, sem perder campos existentes. Provar adicionar, renomear, duplicar, reordenar e reload. |
| R12-35 / 2 | Modelo > Aplicar por > Datas específicas; meal-plans.model-create, meal-plans.model-edit | Input com datas digitadas separadas por vírgula foge do padrão. Usar seletor canônico de datas específicas/múltiplas, exibindo claramente todas as selecionadas e permitindo remover seleção. Não confundir conjunto de datas com intervalo. |
| R12-36 / 3–4 | Novo/Editar cardápio > Período e recorrência > Publicação; meal-plans.create, meal-plans.edit, meal-plans.publish | Retirar Prioridade explícita do fluxo. Publicação programada é uma data e hora, não intervalo de datas nem campo que descarta a segunda data. Rótulo claro Data e hora da publicação. Conferir fuso, persistência do instante e visibilidade antes/depois do horário. |
| R12-37 / 3 | Período e recorrência > Datas excluídas; meal-plans.create, meal-plans.edit | Owner dispensa o campo Datas excluídas. Remover do formulário futuro; preservar dados históricos existentes e reconciliar regra de recorrência no contrato, sem apagar exceções antigas silenciosamente. |
| R12-38 / 5 | Novo cardápio > Cardápio > Anexar imagem; meal-plans.create, meal-plans.edit; publicação em meal-plans.publish | Imagem indisponível. Investigar conexão da UI com repository/Media Gateway e R2 privado; não basta habilitar botão. Provar selecionar, upload, vínculo persistido, visualização após reload e autorização. Imagem do prato também aparece indisponível no anexo 1: incluir verificação no modelo sem presumir causa comum. |

## Separações importantes

Período do cardápio indica a quais dias ele se aplica. Data/hora de publicação
indica quando fica visível. O pedido remove o intervalo indevido da publicação,
não o período de validade do cardápio. Não remover agendamento por interpretar
literalmente a expressão não precisa de data de início; o Owner explicitou que
quer data e hora em que o cardápio será publicado.

Retirar Prioridade explícita da UX não decide automaticamente como resolver
sobreposição de cardápios no backend. Conferir regra canônica de precedência;
se exigir decisão nova, registrar antes de mudar comportamento. Não eliminar
coluna ou sobrescrever valores históricos só para simplificar o formulário.
O mesmo vale para Datas excluídas em registros existentes.

Campo Nome da refeição ou prato já aparece no anexo 1. Verificar se pode ser
reutilizado para nomear o bloco ou se mistura entidades diferentes; não adicionar
campo duplicado sem necessidade. O título deve representar a refeição nomeada.

Mídia permanece privada conforme ADR 0032; usar R2 e catálogo/permissões no
Supabase. Manter descrição acessível. Nova tentativa não deve duplicar ativo ou
publicação. Indisponibilidade vista no anexo não diagnostica erro de Cloudflare;
reutilizar implementação e provas existentes antes de criar outro fluxo.

## FE / BE / E2E e handoff

FE: requisitos registrados, não implementados. BE: verificar nome/coleções,
datas, instante/fuso de publicação, recorrência/precedência e vínculo de mídia.
Nenhum defeito backend confirmado nesta captura. E2E: futura prova por rota normal,
salvar/reload, múltiplas datas e imagem real autorizada; programação mantém
conteúdo invisível antes do instante e visível depois, conforme escopo real.

R12-cardapios-delta.json contém deltas propostos, NÃO aplicados. Integrador C0
rebaseia notas atuais, aplica via apply-tracker-delta.cjs e incorpora ownerItems
no manifesto central. Três rastreadores ainda não atualizados por este pacote,
pois escritor central R11 está ativo. Preservar WIP, certificados e denominadores.
Sem build/runtime/deploy/SQL ou abertura R12 nesta captura.
