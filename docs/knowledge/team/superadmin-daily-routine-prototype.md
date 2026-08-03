---
title: Rotina diária no Superadmin
knowledge_id: superadmin-daily-routine-prototype
source: specs/021-superadmin-daily-routine-prototype.md
status: validated
generated_at: 2026-08-03
audience: team
surfaces: [superadmin, daily-routine]
visibility: internal
review_owner: Coelo Product
---

# Rotina diária no Superadmin

Modelos de rotina diária têm origem institucional ou de unidade. Atividade é somente alcance contextual dentro dos grupos selecionados, nunca uma origem independente.

Unidades podem manter a base, criar versão própria e acrescentar campos. Atualização opcional não sobrescreve a unidade. Mudança obrigatória preserva adicionais compatíveis, arquiva conflitos e gera notificação no sino compartilhado. Snapshots históricos continuam vinculados à versão efetivamente usada.

Valores iniciais são aplicados apenas a campos vazios. Aplicações em lote preservam exceções, salvo confirmação explícita para sobrescrever valores existentes. Owner escreve e demais atores permanecem em leitura.

`Como chegou?` é um sentimento opcional e sem valor inicial. Cinco opções principais aparecem diretamente e quatro ficam em `Ver mais`; emoji sempre acompanha rótulo textual, e `Não informado` é ausência de valor. O sentimento pode ser trocado ou limpo por participante, enquanto o lote exige escolha explícita e preserva exceções por padrão. Sugestões ficam pendentes em memória, separadas do catálogo aprovado e dos registros de participantes.
