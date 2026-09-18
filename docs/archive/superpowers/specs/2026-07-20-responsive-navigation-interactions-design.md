---
title: "Responsive Navigation Interaction Refinement"
source: "User-approved Superadmin navigation hover, flyout and mobile brand refinements"
status: "approved"
generated_at: "2026-07-20"
---

# Interações responsivas da navegação

## Objetivo

Eliminar películas cinzas e transições cromáticas inconsistentes do menu Superadmin, posicionar o flyout recolhido ao lado do acionador e restaurar a marca oficial no drawer de mobile e tablet.

## Escopo

### Menu desktop recolhido

- Uma seção ativa permanece com o fundo laranja principal e ícone em `colorScheme.onPrimary`.
- O hover da seção ativa não clareia o fundo; usa o token Coelo de hover primário para um pequeno escurecimento.
- A sobreposição Material permanece transparente para não criar película cinza.
- O flyout abre à direita do acionador e fica alinhado verticalmente ao topo do ícone clicado, respeitando os limites da viewport.

### Flyout do menu recolhido

- Itens inativos usam fundo transparente em repouso e `colorScheme.primaryContainer` no hover ou foco.
- O destino ativo permanece identificado por texto e ícone em `colorScheme.primary` e fundo laranja suave.
- O hover do destino ativo reforça levemente o fundo laranja sem trocar para cinza.
- A sobreposição padrão do `MenuItemButton` é transparente.

### Menu desktop aberto

- Seções e destinos inativos usam uma versão com alpha zero da mesma cor laranja que será exibida no hover.
- A animação interpola somente a opacidade do laranja, eliminando o quadro intermediário cinza causado por `Colors.transparent`.
- Estados ativos preservam a identificação atual aprovada.

### Drawer de mobile e tablet

- O drawer reutiliza `_BrandHeader(collapsed: false)` no topo.
- A marca usa os SVGs oficiais e o tratamento circular existente, alternando automaticamente entre light e dark mode.
- O texto “Superadmin” aparece ao lado da marca.
- `_InsetDivider` separa o cabeçalho da navegação com o mesmo recuo do desktop.
- Perfil e ações do usuário permanecem fora do drawer.

## Fora de escopo

- Alterar rotas, hierarquia, rótulos ou disponibilidade das seções.
- Alterar o toggle de tema, cabeçalho da página ou menu do usuário.
- Alterar filtros, banco, Supabase ou assets de marca.
- Criar cores hexadecimais, tokens ou componentes paralelos.

## Componentes afetados

- `_NavigationSectionHeader`
- `_CollapsedNavigationSection`
- `_navigationMenuItemStyle`
- `_NavigationItem`
- Drawer responsivo em `SuperadminShell`
- Testes de widget de `SuperadminShell`

## Critérios de aceite

- Hover ativo do rail escurece levemente e nunca clareia.
- Flyout aparece à direita e alinhado ao acionador em viewport desktop.
- Hover do flyout e do menu aberto não apresenta película ou estágio cinza.
- Destino ativo do flyout permanece laranja em repouso e hover.
- Drawer em 375 px e em largura de tablet contém a marca oficial, “Superadmin”, divisor e navegação.
- Drawer não contém perfil do usuário.
- Testes validam estilos resolvidos, posição do flyout e presença da marca em light e dark mode.
