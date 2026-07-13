---
title: "Superadmin Login Design"
source: "User-approved design; docs/design/design-system.md; docs/contexts/superadmin-context.md; docs/product/prd-superadmin.md; docs/security/auth-multitenant-permissions.md; docs/security/lgpd-security-media.md; decisions/0011-flutter-routing-performance.md"
status: "approved-design"
generated_at: "2026-07-13"
---

# Superadmin Login Design

## Objetivo

Implantar a tela de login do Superadmin como uma feature Flutter pequena,
testavel e preparada para autenticacao real futura. A entrega migra a
composicao do app para `MaterialApp.router`, protege a shell com redirect
centralizado e aplica o Design System Coelo sem incorporar credenciais,
segredos ou regras de autorizacao somente no cliente.

## Problema

O codigo atual declara `go_router` como padrao nos READMEs e na ADR 0011, mas
ainda usa `MaterialApp`, `initialRoute` e `routes`. O anexo de referencia
concentra estado, layout e comportamento em um unico arquivo, usa cores locais,
simula autenticacao com atraso e erro fixo e depende de componentes/assets que
nao existem no app atual.

## Escopo

- tela de login por e-mail e senha conforme a referencia visual aprovada;
- validacao local de campos;
- senha visivel ou oculta;
- preferencia "Manter sessao aberta" sem persistencia local nesta entrega;
- estados idle, loading, erro de campo e erro geral;
- callback assincrono injetavel para futura autenticacao;
- estado local minimo de sessao, sem tokens ou credenciais;
- arvore de rotas com `/login` publica e `/` protegida;
- shell bootstrap atual como destino estrutural pos-login;
- light/dark, responsividade, teclado, leitor de tela e texto ampliado;
- testes unitarios e de widget para os comportamentos da entrega.

## Fora de escopo

- integracao com Supabase Auth ou outro backend;
- persistencia de sessao, tokens ou credenciais;
- MFA, OTP, recuperacao real de senha e convite de Owner;
- autorizacao real, RLS, auditoria server-side ou analytics;
- componentes globais em `coelo_auth`, `coelo_ui_core` ou `coelo_ui_admin`;
- alteracao dos documentos oficiais derivados de DOCX.

## Arquitetura

### Feature de autenticacao

- `features/auth/domain/login_request.dart`: valor imutavel com e-mail, senha e
  preferencia de sessao.
- `features/auth/presentation/view_models/login_view_model.dart`: estado e
  comandos de apresentacao. Controla loading, erro geral, visibilidade da senha
  e preferencia de sessao; recebe o callback de login por construtor.
- `features/auth/presentation/screens/superadmin_login_screen.dart`: ciclo de
  vida dos controllers, `Form`, foco e composicao da pagina.
- `features/auth/presentation/widgets/`: card, cabecalho, campos, acao primaria,
  feedback e aviso de seguranca quando a extracao melhorar clareza e teste.

Os widgets permanecem locais porque os pacotes compartilhados de UI estao
reservados e exigem spec propria. Nenhuma abstracao global sera criada apenas
para esta tela.

### Sessao e roteamento

- `core/guards/superadmin_session.dart`: `ChangeNotifier` minimo que expoe
  somente `isAuthenticated`; nao armazena e-mail, senha, token ou permissao.
- `app/router/superadmin_routes.dart`: paths e names estaveis.
- `app/router/superadmin_router.dart`: fabrica/configuracao do `GoRouter`,
  refresh pela sessao e redirect centralizado.
- `app/superadmin_app.dart`: passa a usar `MaterialApp.router` com os temas
  oficiais.

Sem sessao, qualquer tentativa de acessar `/` redireciona para `/login`. Com
sessao, acessar `/login` redireciona para `/`. Esse guard melhora a UX e a
estrutura local, mas nao e tratado como autorizacao real.

## Fluxo de dados

1. A pessoa preenche e-mail, senha e a preferencia de sessao.
2. O `Form` valida os campos localmente.
3. O screen cria um `LoginRequest` e delega ao view model.
4. O view model entra em loading, limpa erro anterior e chama o callback.
5. No comportamento padrao sem backend, o callback retorna falha segura de
   indisponibilidade e a rota permanece em `/login`.
6. Em uma implementacao injetada bem-sucedida, a sessao local e marcada como
   autenticada e o router redireciona para a shell.
7. Excecoes do callback sao convertidas em mensagem generica; detalhes tecnicos
   e existencia de conta nao sao expostos.

## Estados e feedback

- **Idle:** campos e acoes habilitados.
- **Campos invalidos:** mensagem especifica abaixo do campo explicando a
  correcao.
- **Loading:** campos, checkbox, link e botao ficam indisponiveis; o botao
  preserva tamanho e mostra indicador com "Entrando...".
- **Erro geral:** bloco inline com icone, texto seguro e cores semanticas.
- **Senha:** alternancia acessivel entre mostrar e ocultar, com tooltip e
  semantica atualizados.
- **Manter sessao aberta:** apenas preferencia no request; nao grava dados.
- **Recuperacao:** feedback neutro informa indisponibilidade sem confirmar se
  uma conta existe.

## Layout e Design System

- `Scaffold` usa o background semantico do tema.
- O conteudo fica em `SafeArea`, `SingleChildScrollView`, `Center` e
  `ConstrainedBox` para suportar janelas compactas, baixas e desktop.
- Margens variam segundo os breakpoints Coelo; o formulario mantem uma coluna e
  largura funcional controlada.
- Cores vem de `ColorScheme`, `CoeloStatusColors` e extensions do tema.
- Espacamento, raios, tamanhos e movimento usam `CoeloSpacing`, `CoeloRadius`,
  `CoeloSize` e `CoeloMotion`.
- Nenhum HEX e declarado na feature.
- O simbolo oficial Coelo e empacotado como asset do app e recebe descricao
  semantica apropriada.
- Os componentes Material 3 tematizados sao preferidos a controles customizados
  de hover; estados de mouse, teclado, foco e disabled permanecem coerentes com
  o tema.

## Acessibilidade

- alvos interativos minimos de 48 dp;
- checkbox com label integralmente clicavel;
- labels persistentes, hints complementares e autofill apropriado;
- `TextInputAction.next` no e-mail e `done` na senha;
- submit por teclado na senha;
- tooltips para alternancia de visibilidade;
- erro comunicado por icone, texto e semantica, nunca apenas por cor;
- ordem de foco igual a ordem visual;
- scroll para evitar overflow com texto ampliado;
- contraste e temas derivados dos tokens oficiais.

## Seguranca, privacidade e auditoria

- nenhum segredo, `service_role`, chave privada ou credencial e adicionado;
- a senha permanece somente no controller durante a vida da tela e nao e
  registrada em logs;
- mensagens de falha nao enumeram contas;
- o callback e a futura integracao devem aplicar rate limit, MFA, sessao
  revogavel e auditoria server-side;
- a shell local protegida nao substitui RLS, RBAC, policies ou validacao de
  platform membership;
- MFA obrigatoria do Owner e os eventos `user_signed_in/failed` continuam
  pendentes da integracao real.

## Testes

O desenvolvimento segue TDD. Antes de cada comportamento de producao, um teste
deve falhar pela ausencia daquele comportamento.

- unitarios para o view model: estado inicial, alternancias, loading, sucesso,
  falha segura e excecao;
- widget tests para renderizacao, validacao, alternancia de senha, checkbox,
  loading, feedback geral, submit e recuperacao indisponivel;
- testes do router para redirects com e sem sessao;
- teste da composicao para confirmar `MaterialApp.router`, temas e rota inicial;
- teste em viewport compacta e com escala de texto ampliada sem overflow;
- `flutter test`, `dart analyze` e `dart format` como verificacao final.

## Riscos e mitigacoes

- **Confundir guard local com autorizacao:** documentar e testar que ele apenas
  representa sessao; autorizacao real permanece server-side.
- **Solidificar protocolo de auth ainda aberto:** manter callback injetavel e
  contrato de apresentacao, sem escolher Supabase, OTP ou persistencia.
- **Duplicar componentes compartilhados:** manter widgets locais e promover
  somente apos uma spec aprovada dos pacotes de UI.
- **Regredir alteracoes preexistentes do tema:** consumir o tema atual sem
  sobrescrever a modificacao ja presente em `coelo_theme.dart`.

## Divergencias e perguntas abertas

- README e ADR dizem que o Superadmin usa `MaterialApp.router`, enquanto o
  codigo executavel ainda usa rotas legadas. Esta entrega corrige o codigo para
  a decisao aceita, sem alterar a ADR.
- O protocolo final de login (senha/OTP por canal), MFA dos papeis alem do
  Owner, recuperacao e persistencia de sessao continuam abertos. A lacuna fica
  registrada como OQ-016 em `docs/open-questions.md`.

## Criterios de aceite

- `/login` e a rota inicial quando nao ha sessao;
- acesso direto a `/` sem sessao retorna ao login;
- sucesso injetado redireciona para a shell;
- os estados exigidos sao visiveis, acessiveis e testados;
- a feature nao contem HEX, segredos ou persistencia de credenciais;
- light/dark e layout compacto funcionam por tokens e constraints;
- a tela esta componentizada sem criar dependencias desnecessarias;
- analise estatica e testes do app concluem sem diagnosticos.
