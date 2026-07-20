---
source: "pedido do usuario; codigo existente do Superadmin; docs/design/design-system.md; docs/security/auth-multitenant-permissions.md; documentacao oficial Supabase Auth"
status: "implementation-checkpoint-ui-only"
generated_at: "2026-07-17"
---

# Redefinicao de senha UI-only do Superadmin

## Objetivo e problema

Disponibilizar em `/reset-password` a interface de definicao de uma nova senha,
mantendo a experiencia visual e os componentes da autenticacao do Superadmin.
Esta entrega prepara a superficie para o callback de recuperacao, mas nao
altera Supabase, `coelo_auth`, envio de e-mail ou sessao.

## Escopo

- rota publica `/reset-password`, inicialmente no estado de link valido;
- estados de processamento, link valido, link invalido, loading, erro e sucesso;
- nova senha e confirmacao com obrigatoriedade, minimo de 8 caracteres e
  igualdade entre os campos;
- acao injetavel com resultado tipado e fallback que informa que a redefinicao
  ainda nao esta conectada;
- retorno para `/login`, temas claro/escuro, responsividade, autofill, teclado e
  alvos de toque existentes.

Ficam fora de escopo nesta entrega: `resetPasswordForEmail`, callback/deep link,
validacao de token, criacao ou restauracao de sessao de recuperacao,
`updateUser`, redirects Supabase, SMTP, notificacoes, auditoria e mudancas em
RLS ou multi-tenancy.

## Superficies, dados e permissoes

A mudanca fica em `apps/superadmin`, na feature `auth` e no router do app. A
unica informacao recebida pela acao de apresentacao e a nova senha; o fallback
nao persiste nem transmite esse valor. Nenhuma entidade de dominio, tenant,
papel ou permissao e criada. A autorizacao real do callback devera ser definida
quando a integracao Supabase for implementada.

## UX e componentes

A tela reutiliza `LoginCard`, `LoginHeader`, `LoginTextField`,
`LoginSubmitButton`, `LoginFeedback`, `LoginSecurityNotice` e
`LoginThemeToggleButton`. Cores, tipografia, raios, espacamentos e tamanhos vem
somente de `coelo_tokens` e do tema.

- Processando: comunica a validacao do link e bloqueia o formulario.
- Valido: exibe formulario, validacoes e retorno ao login.
- Loading: desabilita campos e evita envios concorrentes.
- Erro: apresenta mensagem segura em regiao semantica viva.
- Invalido: orienta solicitar outro link e oferece retorno ao login.
- Sucesso: confirma a atualizacao e oferece retorno ao login.

## Eventos, logs e notificacoes

Nao ha evento de produto, log de auditoria ou notificacao nesta entrega porque
nenhuma senha e realmente alterada. A futura integracao devera definir eventos
e auditoria sem registrar senha, token ou detalhe sensivel.

## Criterios de aceite e testes

- nenhum componente global, dependencia, asset, cor ou espacamento novo;
- fluxo de “Esqueci minha senha” existente preservado;
- fallback nunca simula sucesso nem usa atraso artificial;
- testes unitarios cobrem estado, visibilidade, loading, concorrencia, sucesso,
  falha segura e descarte durante a operacao;
- widget tests cobrem textos, validacoes, loading, erro, sucesso, estados do
  link, navegacao, semantica e 320x568 com texto a 200% em claro/escuro;
- router test cobre acesso publico direto e goldens cobrem o formulario em
  claro/escuro;
- `dart analyze`, `flutter test` e `flutter build web` devem concluir sem falha.

## Riscos e proxima integracao

A UI nao prova a validade de um link nem autoriza uma troca de senha. Antes de
produzir efeito real, o fluxo deve implementar solicitacao por e-mail, callback
verificado, sessao de recuperacao e atualizacao da senha, alem de configurar
redirects e SMTP. A referencia normativa permanece na documentacao oficial de
[redefinicao de senha](https://supabase.com/docs/guides/auth/passwords#resetting-a-password)
e de [Redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls).
