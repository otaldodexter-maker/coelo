---
source: "pedido do usuario; codigo de referencia anexado; docs/design/design-system.md; docs/security/auth-multitenant-permissions.md; docs/superpowers/specs/2026-07-13-superadmin-login-design.md; docs/superpowers/specs/2026-07-16-superadmin-supabase-auth-design.md; documentacao oficial Supabase Flutter"
status: "implemented"
generated_at: "2026-07-16"
verified_at: "2026-07-17"
---

# Solicitacao de recuperacao de senha do Superadmin

## Objetivo e escopo

Adicionar ao Superadmin somente a etapa de solicitacao de recuperacao por
e-mail: formulario, envio pelo Supabase Auth, confirmacao neutra e reenvio. A
tela reutiliza o layout, os componentes locais e os tokens da autenticacao
existente, sem criar componentes globais ou dependencias.

## Fluxo e estados

1. A pessoa abre `/forgot-password` a partir do login.
2. O formulario valida e normaliza o e-mail.
3. A apresentacao delega a uma acao injetada, que usa `coelo_auth` para chamar
   `resetPasswordForEmail`.
4. Loading bloqueia novo envio concorrente e preserva o tamanho das acoes.
5. Sucesso mostra "Confira seu e-mail" e informa que as instrucoes serao
   enviadas somente se existir uma conta associada.
6. Reenvio usa o ultimo e-mail normalizado; falha de reenvio mantem a tela de
   sucesso e apresenta mensagem generica.

Erros nunca exibem detalhes do SDK nem confirmam a existencia da conta. Cores,
tipografia, espacamentos, raios e tamanhos sao obtidos exclusivamente do tema e
de `coelo_tokens`.

## Arquitetura

- `packages/coelo_auth` concentra o contrato e o adapter Supabase.
- `features/auth/domain` mapeia o resultado compartilhado para a acao do app.
- Um view model local controla loading, sucesso, erro e reenvio.
- O router mantem `/login` e `/forgot-password` publicos somente sem sessao.
- Os widgets de login existentes sao reutilizados e recebem apenas os textos
  variaveis necessarios.

## Fora de escopo e memoria futura

- rota ou tela para definir a nova senha;
- deep link e `redirectTo` explicito para recuperacao;
- chamada a `updateUser`, politica de senha, CAPTCHA ou cooldown local;
- MFA, OTP, auditoria server-side ou mudancas em RLS.

Enquanto a segunda etapa nao existir, o e-mail usa a `SITE_URL` configurada no
Supabase. A proxima entrega de recuperacao deve criar a rota publica de nova
senha, configurar o redirect permitido no Supabase e concluir o fluxo com
`updateUser`.

## Criterios de aceite e testes

- formulario e sucesso seguem o Design System Coelo em light, dark e compact;
- o e-mail e enviado e reenviado pelo gateway compartilhado;
- a interface nao enumera contas e nao declara cores ou espacamentos locais;
- login, router e sessao existentes nao sofrem regressao;
- gateway, acao, view model, tela e roteamento possuem testes automatizados;
- analise estatica, suites Flutter e build web concluem sem falhas.

## Implementacao concluida - 2026-07-17

Concluido:

- contrato e adapter de recuperacao no `coelo_auth`, usando
  `resetPasswordForEmail` e mensagens seguras;
- acao, view model, formulario, confirmacao neutra e reenvio;
- rota publica `/forgot-password`, redirects de sessao e navegacao pelo login;
- reutilizacao dos componentes locais e tokens, sem novas dependencias, cores
  ou espacamentos;
- registro da etapa futura na OQ-016;
- testes unitarios, de widget, router, acessibilidade, responsividade e dois
  goldens light;
- `flutter test` verde: 15 testes em `packages/coelo_auth` e 89 testes no
  workspace atual de `apps/superadmin`;
- `dart analyze` sem problemas nos dois projetos;
- `flutter build web` concluido em `apps/superadmin`, incluindo o dry run de
  Wasm;
- revisao independente aprovada sem achados criticos, importantes ou menores.

Verificacao final:

1. Suites completas executadas em `packages/coelo_auth` e `apps/superadmin`.
2. Analise estatica executada nos dois projetos.
3. Build web executado no estado final do codigo de producao.
4. Alteracoes paralelas e a edicao existente em `docs/learning/progress.md`
   foram mantidas intactas.

Nao ha implementacao funcional restante dentro do escopo de solicitacao,
sucesso e reenvio.

A tela de nova senha, deep link, redirect explicito e `updateUser` continuam
fora desta entrega e permanecem registrados para a proxima etapa.
