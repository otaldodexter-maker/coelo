---
source: "Solicitação aprovada para refatorar a criação e edição de instituições"
status: "approved"
generated_at: "2026-07-27"
---

# Formulário de instituição do Superadmin

## Objetivo

Alinhar a criação e edição de instituições ao Design System Coelo, ao catálogo
e aos controles já usados no login e na listagem de instituições.

## Composição aprovada

- `Identidade visual` é a primeira das seis etapas.
- O conteúdo e o rodapé usam margens e espaçamentos semânticos, com ações
  agrupadas e responsivas.
- Campos têm label persistente, ícone, hint quando útil, hover, foco, erro e
  preenchimento definidos pelo tema.
- Seleções simples usam superfície neutra e opções contínuas; seleção, hover e
  foco usam `primaryContainer` e conteúdo `primary`, sem dropdown cinza.
- A identidade visual reúne foto de perfil, nome de exibição, identificador
  institucional e cores.
- A foto aceita PNG, JPG ou WebP quadrado de até 2 MB para recorte circular.
- As cores podem ser digitadas em hexadecimal ou escolhidas por área de
  saturação/valor e controle de matiz.
- O seletor de cor avançado usa superfície neutra sem tint, área quadrada de
  saturação/valor, faixa contínua de matiz, amostras atual e nova e edição em
  HSV, RGB e hexadecimal.
- Cards de upload, prévia, conteúdo e rodapé usam `surface`; cinza não é usado
  como faixa decorativa ou fundo estrutural do formulário.
- A busca de CEP é uma ação contextual do próprio campo e pode preencher país,
  estado, cidade, bairro e logradouro quando o serviço responder.
- A informação sobre convite e ativação é a exceção semântica em
  `primaryContainer`, equivalente ao aviso do login.
- O plano não solicita justificativa. No diálogo de saída, continuar editando e
  sair sem salvar dividem a largura útil igualmente.
- Todo single-select abre com a largura exata do campo e não repete a seleção
  com check ou checkbox.

## Componentes oficiais e catálogo

- `CoeloFormTextField`, em `coelo_ui_core`, é o campo-base compartilhado pelo
  login e pelos formulários.
- `CoeloAdminSingleSelectField`, em `coelo_ui_admin`, é a seleção única de
  formulários administrativos.
- O catálogo registra os dois componentes e amplia `pattern.form-controls`
  com grid responsivo, gaps e rodapé.
- Upload de imagem e seletor de cor permanecem composições do padrão de
  formulário até existir um segundo consumidor que justifique API visual
  pública própria; suas regras de produto já são oficiais no Design System.

## Limites

Nesta etapa, a foto é uma prévia local. Persistência de mídia depende do fluxo
server-side e do spike de Cloudflare R2 exigido pela arquitetura. Não é criado
token novo: a composição usa somente a escala existente.

## Aceite e verificação

- criação e edição compartilham a mesma composição;
- light/dark e 375/768/1024/1440 não apresentam overflow;
- texto a 200% preserva operação;
- teclado, foco, semântica e alvos mínimos continuam disponíveis;
- testes focados e goldens protegem a composição.
