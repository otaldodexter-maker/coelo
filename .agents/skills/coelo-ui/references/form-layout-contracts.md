---
source: "docs/design/design-system.md; docs/superpowers/specs/2026-07-27-superadmin-institution-form-visual-refactor-design.md; docs/superpowers/specs/2026-07-13-superadmin-login-design.md"
status: "active"
generated_at: "2026-07-29"
---

# Contrato de formulários de cadastro e edição

Consulta obrigatória para formulário, cadastro, edição, input, campo, select,
upload, avatar, color picker, wizard, step form ou rodapé de ações. Instituições
no Superadmin é a referência canônica; autenticação é a referência do campo-base.

Essa escolha é automática para qualquer tela que crie ou edite uma entidade,
inclusive ao refatorar, corrigir ou acrescentar widget/seção a uma tela
existente. O domínio pode mudar conteúdo, quantidade de etapas e validações;
não muda sozinho a identidade visual aprovada.

Antes do código, abrir a implementação real de `InstitutionFormPage`,
`InstitutionFormNavigation`, `InstitutionFormSection`,
`SuperadminFormActionFooter`, os testes funcionais e os goldens
`institution_form_create_light_375.png` e
`institution_form_edit_dark_1440.png`. Reutilizar componentes compartilhados;
widgets específicos de Instituições servem como anatomia de referência e só
podem virar API genérica após proposta e aprovação.

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
- No Superadmin, reutilizar `SuperadminFormActionFooter`; não reconstruir o
  rodapé localmente nem trocar sua hierarquia por conveniência da feature.
- Ação primária usa botão laranja preenchido para o único compromisso dominante
  do contexto: salvar, criar, continuar, aplicar ou confirmar.
- Ação secundária usa `OutlinedButton`: fundo é a `surface` visível do tema
  (não branco literal), contorno leve e conteúdo semântico. Serve para anterior,
  voltar, cancelar relevante ou alternativa que precisa permanecer evidente.
- Ação terciária usa `TextButton`: a mesma `surface`, sem contorno, para
  cancelar discreto, limpar, editar, ver mais ou ação auxiliar. Não promovê-la a
  outlined apenas para preencher espaço.
- Ações negativas ignoram essa escala cromática e seguem
  `pattern.negative-actions`.
- Em medium ou maior, cancelar/terciária fica no extremo esquerdo; navegação,
  secundárias e a única primária ficam agrupadas no extremo direito. Em compact,
  a primária ocupa 100% e precede as demais.
- Diálogo administrativo usa `CoeloAdminDialogShell`. Uma ação ocupa toda a
  largura útil; duas ações dividem igualmente a largura com gap
  `CoeloSpacing.space3`; três dividem em terços. Se não couberem, todas empilham
  em 100%, sem quebra 2+1.
- Em mobile, a ação primária ocupa a largura útil e as demais ações continuam
  acessíveis sem cobrir conteúdo permanentemente.

## Verificação obrigatória

- Conferir 375, 768, 1024 e 1440 px; light e dark; texto a 200%; teclado, foco,
  semântica e reduced motion quando houver animação.
- Proteger no mínimo mobile light e desktop dark com golden.
- Comparar com Criar/Editar Instituição e autenticação. Se uma regra real do
  produto exigir composição ou identidade diferente, parar antes do código,
  apresentar ao usuário a diferença, a proposta visual, componentes, estados,
  tokens e impactos, e aguardar aprovação explícita. Sem aprovação, prevalece a
  baseline de Instituições; não criar variante, golden ou allowlist divergente.
- Em autenticação, `CoeloFormTextField` com label flutuante e hint complementar
  é a baseline aprovada, sem variante `auth`. Usar os goldens de login,
  recuperação e nova senha como evidência; nunca usar `failures/`.
- Atualizar contrato canônico, índice, catálogo, exemplo e testes quando uma
  decisão aprovada passar a ser reutilizável.
