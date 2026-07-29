---
source: "docs/design/design-system.md; docs/superpowers/specs/2026-07-27-superadmin-institution-form-visual-refactor-design.md"
status: "active"
generated_at: "2026-07-27"
---

# Contrato de formulários de cadastro e edição

Consulta obrigatória para formulário, cadastro, edição, input, campo, select,
upload, avatar, color picker, wizard, step form ou rodapé de ações. Instituições
no Superadmin é a referência canônica; autenticação é a referência do campo-base.

## Composição

- Usar `colorScheme.surface` no conteúdo, cards auxiliares e rodapé. Não criar
  faixas cinzas ou `surfaceContainer` decorativo sem função semântica.
- Organizar a página em título e descrição, grupos relacionados, campos e
  rodapé. Em fluxo por etapas, informar etapa atual e permitir retorno sem
  perder dados.
- Usar `CoeloFormTextField`; não recriar decoração, hover ou foco localmente.
- Grid amplo: até duas colunas, gap horizontal `CoeloSpacing.space3` (12 px),
  gap vertical `CoeloSpacing.space4` (16 px) e
  `CoeloSpacing.space5` (20 px) entre grupos. Compacto: uma coluna.
- Na identidade institucional, os grupos de cores de marca e texto usam três
  colunas no desktop e colapsam responsivamente sem alterar a ordem ou o foco.
- Espaçamento deve vir de token ou referência aprovada. Número visual local sem
  justificativa bloqueia a conclusão.

## Campos e seleções

- Label é persistente; placeholder complementa, nunca substitui. Ícone deve
  representar o significado do campo, evitando repetição genérica.
- Ação contextual pertence ao campo quando atua sobre seu valor, como
  `Buscar CEP`; deve ter tooltip, semântica e alvo mínimo.
- Single-select reutiliza `CoeloAdminSingleSelectField`, abre 4 px abaixo na
  largura exata do campo, mostra no máximo seis opções, reduz a altura ao
  espaço inferior e não usa check ou checkbox redundante.
- Estados mínimos: enabled, hover, focus, error e disabled. Preservar teclado,
  autofill, ordem de foco e mensagem de erro associada.

## Conteúdo especializado

- Avatar institucional: arquivo 1:1 em PNG, JPG ou WebP, máximo de 2 MB, com
  prévia circular. Persistência privada segue o fluxo server-side de mídia.
- Seletor de cor avançado: superfície neutra sem tint, área quadrada de
  saturação/valor, faixa contínua de matiz, amostras atual e nova e edição HSV,
  RGB e hexadecimal.
- Bio com limite conta grafemas. Um ícone com tooltip e semântica abre a paleta
  compacta de emojis, inserindo a escolha no cursor sem substituir o teclado do
  sistema.
- Avatar opcional do administrador é configurado no cadastro e na edição: usa o
  recorte circular padrão de perfil, confirmação `Cancelar`/`Aplicar` em 50/50
  e reset por ícone circular com tooltip, semântica e alvo mínimo.
- Para perfis contextuais ligados, nomear a direção da sincronização: `Copiar
  dados do representante` (representante → administrador) e `Copiar dados para
  o representante` (administrador → representante).
- `primaryContainer` pode destacar uma mensagem informativa aprovada, como
  convite e ativação; não é fundo estrutural do formulário ou de popup.

## Rodapé e confirmação

- Rodapé usa `surface`, borda sutil e padding semântico; não é uma faixa cinza.
- A ação primária fica visualmente dominante. Voltar e cancelar preservam a
  hierarquia e não competem com salvar ou continuar.
- Diálogo administrativo usa `CoeloAdminDialogShell`. Uma ação ocupa toda a
  largura útil; duas ações dividem igualmente a largura com gap
  `CoeloSpacing.space3`.
- Em mobile, a ação primária ocupa a largura útil e as demais ações continuam
  acessíveis sem cobrir conteúdo permanentemente.

## Verificação obrigatória

- Conferir 375, 768, 1024 e 1440 px; light e dark; texto a 200%; teclado, foco,
  semântica e reduced motion quando houver animação.
- Proteger no mínimo mobile light e desktop dark com golden.
- Comparar com Instituições e autenticação. Se a composição divergir, explicar
  qual regra de produto exige a diferença.
- Atualizar contrato canônico, índice, catálogo, exemplo e testes quando uma
  decisão aprovada passar a ser reutilizável.
