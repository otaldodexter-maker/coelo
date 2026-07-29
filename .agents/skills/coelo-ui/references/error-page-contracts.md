---
source: "docs/design/design-system.md; docs/superpowers/specs/2026-07-28-superadmin-error-pages-design.md"
status: "active"
generated_at: "2026-07-29"
---

# Contrato de páginas fullscreen de erro

Use este contrato para error page, fullscreen error, 403, 404, 500, 503, rota
não encontrada, acesso negado e indisponibilidade.

## Quando usar

- Página fullscreen: a falha interrompe toda a janela e não há superfície útil
  para preservar.
- `CoeloStatePanel`: loading, vazio, bloqueio ou erro dentro de uma superfície.
- 401 redireciona para autenticação; 429 permanece feedback contextual.

## Composição aprovada

- Tela limpa, sem shell, menu ou header.
- Fundo `colorScheme.primaryContainer`; conteúdo
  `colorScheme.onPrimaryContainer`. Não usar vermelho como fundo.
- Código, divisor e mensagem centralizados; uma única ação abaixo.
- 403: “Você não tem permissão para acessar esta área.” / “Voltar ao início”.
- 404: “Não encontramos a página que você procura.” / “Voltar ao início”.
- 500: “Não foi possível concluir esta ação.” / “Tentar novamente”.
- 503: “O Coelo está temporariamente indisponível.” / “Tentar novamente”.
- Destino ou retry são delegados ao app. Não inventar autorização no cliente.
- Não adicionar logo, ilustração ou ícone sem aprovação.

## Responsividade e acessibilidade

- Decidir por constraints com `LayoutBuilder`: linha em largura ampla; coluna
  em compact ou texto ampliado.
- Limitar a largura de leitura a 720 px e usar `SafeArea` com scroll vertical.
  Aplicar padding horizontal `space10` em amplo e `space4` em compact, com
  padding vertical `space8`.
- Anunciar `Erro {código}. {mensagem}` como um único grupo semântico.
- Preservar foco, teclado e alvo mínimo da ação.
- Validar 375/768/1024/1440, light/dark, texto a 200%, overflow e goldens.

Referência implementada: Superadmin. Admin e Principal exigem spec consumidora;
não compartilhar telas entre apps.
