---
source: "Solicitação aprovada pelo usuário em 2026-07-28; docs/design/design-system.md; .agents/skills/coelo-ui/references/surface-interaction-contracts.md"
status: "approved"
generated_at: "2026-07-28"
---

# Ajustes finais de superfície em Perfil e Configurações

## Objetivo

Aplicar somente dois ajustes visuais no Superadmin:

1. alinhar o cabeçalho do diálogo **Alterar senha** ao popup canônico de reporte
   de bug;
2. remover integralmente o hover cinza da linha **Reduzir animações**.

## Composição aprovada

### Diálogo de senha

- Manter título e ação de fechar na mesma linha.
- Adicionar imediatamente abaixo um divisor de 1 px em
  `colorScheme.outlineVariant`, seguindo o popup de reporte de bug.
- Preservar campos, textos, ações, responsividade, semântica e comportamento
  existentes.

### Configurações

- Substituir a linha interativa integral por uma composição neutra de texto e
  `Switch`.
- A superfície da linha não terá hover, splash ou overlay.
- O `Switch` continuará acessível por mouse, toque, teclado e leitor de tela.
- Preservar textos, persistência da preferência e layout responsivo existentes.

## Fora de escopo

- Alterações em outros diálogos, cards ou configurações.
- Novos componentes públicos ou tokens.
- Mudanças em regras de conta, senha, tema ou acessibilidade.

## Verificação

- Teste do divisor no cabeçalho do diálogo.
- Teste de ausência de superfície interativa/hover na linha de acessibilidade.
- Regressão dos testes de Perfil e Configurações.
- Análise estática focada e inspeção visual no host local.
