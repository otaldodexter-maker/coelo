---
title: Home Central de ajuda do Superadmin
source: plano aprovado pelo owner em 2026-07-27
status: approved
generated_at: 2026-07-27
---

# Home Central de ajuda do Superadmin

## Objetivo

Transformar a rota autenticada `/` na Home do Superadmin: uma Central de ajuda
conversacional para dúvidas sobre o Coelo. A experiência demonstra o fluxo sem
IA, API ou persistência.

## Navegação

- “Home” aparece no topo do menu global.
- Logo e texto “Superadmin” formam um controle com semântica “Ir para Home”.
- No menu recolhido, a logo preserva a ação.
- No drawer mobile, a ação fecha o drawer e abre a Home.
- A marca usa `onDestinationSelected('home')`; o shell não conhece o router.
- Estar na Home não recria desnecessariamente o estado.
- O botão de recolher o menu permanece independente.

## Experiência

- Título “Como podemos ajudar?”.
- Campo “Pergunte sobre o Coelo”.
- Três sugestões iniciais relacionadas ao sistema.
- Conversas e mensagens são imutáveis e vivem somente durante a sessão.
- Nova conversa, seleção e envio funcionam localmente.
- A primeira pergunta define o título da conversa.
- A resposta deixa explícito que a Central ainda é uma demonstração.
- `Enter` envia, `Shift+Enter` cria nova linha e conteúdo vazio não é enviado.
- No desktop, o painel de conversas pode ser recolhido para um rail de 88 px e
  expandido novamente sem perder o estado da sessão.
- A ação de envio usa o ícone padrão de Conversas, fica fora da caixa de texto,
  permanece neutra quando desabilitada e recebe o fundo primário Coelo quando
  houver conteúdo válido.

## Responsividade

- Abaixo de 600 px: histórico e conversa empilhados.
- De 600 a 839 px: rail compacto e conversa.
- A partir de 840 px: histórico de aproximadamente 320 px e conversa lado a
  lado.
- O conteúdo conversacional é limitado a aproximadamente 760 px.

## Design e acessibilidade

Usar Nunito Sans, tokens semânticos do Coelo, temas claro e escuro, foco
visível, alvos mínimos de 48 px, semântica para controles e suporte a texto
ampliado. A Central pode reutilizar fundamentos visuais do chat compartilhado,
mas permanece separada de `Comunicação > Conversas`.

## Fora de escopo

Busca, exclusão, renomeação, anexos, voz, IA real, Supabase, persistência, PDF
e pipeline RAG.
