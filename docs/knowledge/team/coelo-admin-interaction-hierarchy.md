---
title: Hierarquia de interação administrativa Coelo
knowledge_id: coelo-admin-interaction-hierarchy
source: docs/design/design-system.md
status: validated
generated_at: 2026-07-29
audience: team
surfaces: [admin, superadmin, catalog]
visibility: internal
review_owner: Coelo Product
---

# Hierarquia de interação administrativa Coelo

Hover não é uma regra visual única. Toda superfície deve ser classificada antes
da implementação: ação primária, tonal, item discreto, linha contínua, card
interativo, ação negativa ou toggle segmentado. Cinza/HEX local e hover genérico
do Material não são padrões Coelo.

Ação primária usa botão laranja preenchido; `OutlinedButton` em `surface` com
contorno leve é secundário; `TextButton` em `surface` sem contorno é terciário.
Em rodapé de tela amplo, terciária/cancelar fica no extremo esquerdo e o grupo
de continuidade no direito. Em compacto, a primária ocupa a largura antes das
demais.

Em popup, largura não comunica prioridade: uma ação ocupa 100%; duas dividem
50/50; três dividem em terços, com gaps tokenizados. Quando constraints ou texto
ampliado não comportarem a linha, todas empilham em 100%; não existe quebra 2+1.

`X`, sair, desligar, encerrar, fechar, remover, deletar e excluir permanecem na
hierarquia `error`/`errorContainer` enquanto habilitados. Ícones, itens de menu
e botões negativos já são vermelhos em repouso e usam container vermelho no
hover/foco. Compartilhar a hierarquia visual não compartilha regras de
confirmação, autorização ou auditoria.

Flyouts usam `surface`, sem tint, borda, `radius.lg`, elevação e padding
tokenizado. Perfil e Configurações formam o grupo padrão; ações terminais ou
destrutivas ficam abaixo de divisor. O popup de Bug é a referência modal; Tour,
Perfil e Arquivos são referências de flyout.
