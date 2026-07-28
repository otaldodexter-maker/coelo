---
title: "Refinamento visual de Perfil e Configurações do Superadmin"
source: "Feedback visual e aprovação do usuário em 2026-07-28; docs/superpowers/specs/2026-07-28-superadmin-profile-settings-design.md; docs/design/design-system.md"
status: "approved"
generated_at: "2026-07-28"
---

# Refinamento visual de Perfil e Configurações do Superadmin

## Objetivo

Refinar as telas já implementadas de Perfil e Configurações antes de avaliar a
promoção de seus padrões ao Coelo UI. Esta entrega permanece local ao
Superadmin e não cria API pública, componente de pacote ou token novo.

## Perfil

Em telas amplas, Dados pessoais ocupa a coluna esquerda. Meu acesso e Segurança
formam a coluna direita, e a base visual das duas colunas deve permanecer
alinhada. Em larguras compactas, os cartões passam para uma única coluna sem
ordem de foco inesperada ou rolagem horizontal.

Dados pessoais inclui nome, sobrenome, e-mail e celular. Os campos reutilizam os
controles compartilhados do formulário e os gaps semânticos já definidos pelo
Design System.

O rodapé do Perfil usa superfície neutra, borda sutil e duas extremidades:
Redefinir à esquerda e Salvar alterações à direita. Redefinir remove a foto,
restaura a sigla derivada do nome e sobrenome atuais e aplica a cor padrão do
avatar. A alteração permanece como rascunho até Salvar alterações.

## Diálogo de senha

Alterar senha usa o padrão de superfície neutra e apresenta no cabeçalho o
fechamento vermelho canônico, com alvo mínimo de 48 px, tooltip e semântica.
Fechar ou Cancelar descarta o rascunho.

Cancelar e Alterar senha dividem igualmente a largura útil do rodapé, separados
por `CoeloSpacing.space3`. Em mobile, a composição preserva largura útil, ordem
de foco e acesso às duas ações.

## Seletor de cor

Perfil e criação/edição de Instituições reutilizam uma única composição local ao
Superadmin para o seletor avançado de cor. A referência visual permanece o
seletor atual de Instituições:

- superfície neutra sem tint;
- área quadrada de saturação e valor;
- faixa contínua de matiz;
- amostras Atual e Nova;
- edição HSV, RGB e hexadecimal.

Cancelar e Usar cor dividem igualmente a largura útil com gap
`CoeloSpacing.space3`. Cancelar ou fechar não altera a cor do formulário; Usar
cor aplica o valor ao rascunho da tela de origem.

## Configurações

A linha Reduzir animações não usa faixa cinza, `surfaceContainer` decorativo ou
hover estrutural de linha. O cartão permanece em `colorScheme.surface`. O switch
mantém seus estados nativos e acessíveis, sem camada cinza adicional sobre o
conteúdo.

## Arquitetura

O seletor avançado é extraído para uma composição compartilhada dentro do app
Superadmin, sem exportação pelo Coelo UI. Perfil e Instituições passam a abrir
essa mesma composição. Os demais ajustes permanecem nas telas e modelos de
conta existentes.

O celular integra `AccountProfile` e o repositório local. Nenhuma persistência
remota, autorização nova ou dado sensível adicional é introduzido.

## Estados e acessibilidade

- Preservar rascunhos em erros de salvamento.
- Evitar ações duplicadas enquanto houver salvamento.
- Manter teclado, foco visível, semântica, tooltips e alvos mínimos.
- Respeitar texto a 200% e redução de movimento.
- Usar somente tokens semânticos nos temas claro e escuro.

## Testes e aceite

- Validar celular no modelo, controlador e formulário.
- Confirmar que Redefinir restaura foto, sigla e cor apenas no rascunho até o
  salvamento.
- Confirmar alinhamento das colunas em tela ampla e empilhamento em mobile.
- Verificar fechamento vermelho e ações 50/50 no diálogo de senha.
- Verificar ações 50/50 no seletor de cor aberto por Perfil e Instituições.
- Confirmar que Cancelar não aplica uma nova cor.
- Confirmar ausência da faixa cinza em Reduzir animações.
- Executar análise estática, testes direcionados e goldens proporcionais em
  375, 768, 1024 e 1440 px, incluindo mobile light e desktop dark.

## Fora de escopo

- Promoção imediata do seletor, rodapé ou diálogos ao Coelo UI.
- Supabase, R2, senha real, telefone verificado ou auditoria server-side.
- Novas preferências além das já aprovadas.

