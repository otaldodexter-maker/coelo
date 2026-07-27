---
source: "User feedback supplied on 2026-07-27; apps/superadmin/lib/app/shell/superadmin_shell.dart; docs/design/design-system.md"
status: "approved-design"
generated_at: "2026-07-27"
---

# Superadmin sidebar: Home e movimento

## Objetivo

Fazer o menu lateral desktop do Superadmin iniciar na Home com a sidebar
expandida e as seções recolhidas, além de tornar a transição entre sidebar
expandida e recolhida contínua e suave.

## Escopo

- manter a sidebar desktop expandida no primeiro carregamento;
- exibir Home como destino ativo ao entrar pela rota Home;
- iniciar Estrutura recolhida na Home;
- abrir automaticamente somente a seção que contém o destino ativo;
- manter o cabeçalho Superadmin clicável como atalho para Home, sem hover
  laranja;
- sincronizar largura da sidebar, visibilidade dos textos e posição do botão de
  recolher/expandir em uma única progressão de animação;
- respeitar `MediaQuery.disableAnimations`.

## Fora de escopo

- alterar hierarquia, rótulos, ícones ou rotas do menu;
- alterar a navegação compacta por drawer;
- criar token, componente público ou API compartilhada;
- modificar o comportamento de hover dos demais itens de navegação.

## Composição e comportamento

A implementação permanece local em `SuperadminShell`. O estado expandido ou
recolhido continua controlado pela shell, mas a transição não troca duas árvores
completas do menu. Uma única árvore acompanha o progresso do
`AnimationController`; largura e botão usam o mesmo valor, enquanto detalhes
textuais desaparecem antes de o trilho atingir a largura mínima e reaparecem
depois que existe espaço suficiente.

Na Home, nenhuma seção nasce aberta. Em destinos internos, a seção que contém o
destino ativo nasce aberta. Interações posteriores do usuário continuam
controlando a expansão de cada seção.

O cabeçalho Superadmin preserva alvo, teclado, semântica e tooltip. Seu
`InkWell` não pinta `primaryContainer` em hover, foco ou clique.

## Acessibilidade

- preservar alvo mínimo de 48 px no botão de recolher/expandir;
- manter os rótulos semânticos `Recolher menu`, `Expandir menu` e
  `Ir para Home`;
- com animações desabilitadas, aplicar imediatamente o estado final;
- impedir overflow e conteúdo textual comprimido durante a transição.

## Critérios de aceite

1. Ao abrir a Home em desktop, a sidebar aparece expandida, Home está ativa e
   Estrutura está recolhida.
2. Ao abrir Instituições, Estrutura aparece expandida por conter o destino
   ativo.
3. Passar o mouse, focar ou pressionar o cabeçalho Superadmin não aplica fundo
   laranja.
4. Recolher e expandir usa uma única transição contínua, sem sobreposição de
   dois menus, salto do botão ou texto comprimido.
5. O estado final recolhido mantém apenas os ícones e os flyouts existentes.
6. `disableAnimations` mantém troca imediata e funcional.

## Testes exigidos

- widget test do estado inicial da Home e da abertura contextual de Estrutura;
- widget test do overlay transparente no cabeçalho Superadmin;
- widget test em progresso intermediário da animação, verificando largura e
  ausência de árvores duplicadas;
- testes focados existentes de navegação, teclado, drawer e reduced motion;
- análise estática dos arquivos afetados.

## Riscos

O arquivo da shell contém mudanças locais não relacionadas. A implementação
deve preservar essas mudanças e limitar o diff ao estado e à transição da
sidebar e aos testes correspondentes.

