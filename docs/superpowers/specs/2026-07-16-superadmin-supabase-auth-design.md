---
source: "pedido do usuario; docs/security/environment-and-secrets.md; decisions/0004-auth-permissions.md; docs/superpowers/specs/2026-07-13-superadmin-login-design.md; documentacao oficial Supabase Flutter"
status: "approved-design"
generated_at: "2026-07-16"
---

# Login real do Superadmin com Supabase Auth

## Objetivo e problema

Conectar a tela atual de login do Superadmin ao Supabase Auth sem refazer a UI,
sem mover regras de autorizacao para o cliente e sem expor segredos. A entrega
deve autenticar com e-mail e senha, restaurar somente sessoes que a pessoa
escolheu manter abertas, refletir mudancas de auth no roteamento e oferecer
logout basico.

## Escopo

- inicializar `supabase_flutter` corretamente em web e mobile;
- ler apenas `COELO_SUPABASE_URL` e
  `COELO_SUPABASE_PUBLISHABLE_KEY` por `--dart-define`;
- manter fallback seguro quando um ou ambos os defines estiverem ausentes;
- encaminhar `keepSessionOpen` da apresentacao ao adapter de auth;
- persistir a sessao somente quando "Manter sessao aberta" estiver marcado;
- validar que `signInWithPassword` retornou usuario e sessao antes do sucesso;
- iniciar `SuperadminSession` a partir da sessao restaurada e espelhar
  `onAuthStateChange`;
- manter os redirects do `go_router` entre `/login` e `/`;
- adicionar logout basico na shell, sem alterar o design system;
- documentar a configuracao local sem versionar valores reais;
- cobrir o fluxo com testes automatizados e verificacao de build web.

## Fora de escopo

- autorizacao final de Superadmin, platform memberships, papeis e permissoes;
- MFA, convites, recuperacao de senha e politica final de sessao;
- RLS, migrations, Edge Functions ou backend inventado para esta tela;
- auditoria server-side e acesso a dados privados;
- alteracao ampla da shell ou refacao visual do login.

## Superficies afetadas

- `apps/superadmin/lib/main.dart` para composicao do auth scope;
- `apps/superadmin/lib/core/config` para configuracao client-safe;
- `apps/superadmin/lib/core/guards/superadmin_session.dart` para o espelho local;
- `apps/superadmin/lib/features/auth` para mapear a preferencia e o resultado;
- `apps/superadmin/lib/app/router` para preservar redirects reativos;
- `apps/superadmin/lib/app/shell` para expor logout basico;
- `packages/coelo_auth` para contrato, adapter Supabase e storage condicional;
- `.gitignore`, exemplos de ambiente e testes relacionados.

## Arquitetura

### Configuracao e bootstrap

`SuperadminAppConfig` continua sendo a unica fonte de configuracao de build do
app. `main.dart` garante o binding, avalia se os dois defines existem e somente
entao inicializa o Supabase. Falta de configuracao ou falha de inicializacao
produz um `UnavailableCoeloAuthGateway`, sem crash e sem credenciais alternativas.

O app usa exclusivamente a URL publica e a publishable key. `service_role`,
secret key e qualquer credencial de servidor permanecem proibidos no bundle.

### Adapter e persistencia seletiva

`CoeloAuthGateway.signInWithPassword` recebe a decisao de persistencia junto
dos dados de login. O adapter Supabase configura essa decisao antes de chamar
`signInWithPassword`.

Um `LocalStorage` condicional envolve `SharedPreferencesLocalStorage`, a
implementacao multiplataforma do `supabase_flutter 2.16.0`. Quando habilitado,
ele delega leitura e gravacao da sessao. Quando desabilitado, remove eventual
sessao persistida e ignora novas gravacoes, sem interferir na sessao em memoria.
Ao reiniciar, uma sessao previamente persistida pode ser restaurada normalmente.

Essa abordagem evita depender de callbacks de encerramento, que nao sao
confiaveis em navegador ou mobile, e evita manter dois clientes Supabase.

### Sessao, login e roteamento

Depois do login, o adapter considera sucesso somente se a resposta contiver
usuario e sessao. O `SuperadminSession` nasce com o estado de `currentSession`
e permanece ligado ao stream de auth. O login pode atualizar o espelho
imediatamente, enquanto o stream continua como fonte reativa para refresh,
restauracao e sign-out.

O `GoRouter` continua observando `SuperadminSession`: uma pessoa sem sessao e
direcionada para `/login`; uma pessoa autenticada que visite `/login` e
direcionada para `/`. Esse guard representa autenticacao local e nao substitui
autorizacao server-side, memberships ou RLS.

### Logout

A composicao injeta uma acao de logout na shell. Ela chama
`supabase.auth.signOut()` por meio de `CoeloAuthGateway`, limpa o estado local e
deixa o auth stream provocar o redirect para `/login`. Falhas recebem feedback
generico e nao expõem detalhes tecnicos ou tokens.

## Fluxos e estados

### Login com persistencia

1. A pessoa marca "Manter sessao aberta" e envia credenciais validas.
2. O adapter habilita o storage persistente.
3. Supabase retorna usuario e sessao.
4. A sessao e persistida e refletida em `SuperadminSession`.
5. O router abre a shell.
6. Em uma nova execucao, o bootstrap restaura a sessao e abre a shell.

### Login sem persistencia

1. A pessoa deixa o checkbox desmarcado e envia credenciais validas.
2. O adapter desabilita a persistencia e remove sessao persistida anterior.
3. Supabase retorna usuario e sessao apenas em memoria.
4. O router abre a shell durante a execucao atual.
5. Em uma nova execucao, nenhuma sessao e restaurada e `/login` permanece.

### Ambiente indisponivel ou credenciais invalidas

Sem os dois defines, o login retorna mensagem explicita de ambiente nao
configurado. Erros de autenticacao retornam mensagem generica para evitar
enumeracao de contas. Em ambos os casos, a rota permanece em `/login`.

## Dados, permissoes e seguranca

- a senha existe apenas no controller e na chamada de auth e nunca e logada;
- a publishable key e configuracao publica, nao uma credencial privilegiada;
- nenhum metadata mutavel do usuario concede acesso;
- a sessao autenticada nao concede automaticamente acesso de Superadmin;
- platform membership, MFA e autorizacao de comandos continuam server-side e
  bloqueiam a classificacao deste fluxo como autenticacao completa;
- logout remove a sessao persistida, mas access tokens ja emitidos podem viver
  ate o proprio vencimento; operacoes sensiveis futuras devem validar a sessao
  e a autorizacao no servidor.

## Configuracao local e Git

O repositorio mantem apenas exemplos vazios. Valores reais ficam em arquivo
local ignorado ou sao passados diretamente ao comando Flutter. O comando de
execucao usa somente:

```text
--dart-define=COELO_SUPABASE_URL=<url-publica>
--dart-define=COELO_SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

Sem valores reais, o localhost pode demonstrar e testar o fallback seguro, mas
nao pode comprovar um login ponta a ponta contra o projeto Supabase.

## Tratamento de erros

- falha no bootstrap: report tecnico via `FlutterError` e gateway indisponivel;
- falha de credencial ou rede no login: mensagem generica e sessao inalterada;
- resposta sem usuario ou sessao: falha generica;
- erro no auth stream: report tecnico sem derrubar a UI;
- falha no logout: feedback seguro e nenhuma afirmacao falsa de encerramento.

## Testes exigidos

- unitarios do storage condicional para leitura, gravacao, remocao e alternancia;
- unitarios do gateway para sucesso, resposta incompleta, erro seguro e logout;
- unitarios da acao de login para encaminhar `keepSessionOpen`;
- testes de sessao restaurada e mudancas do auth stream;
- testes do router para login, restauracao e logout;
- widget test do logout basico sem regressao visual desnecessaria;
- fallback sem defines;
- suites completas de `coelo_auth` e Superadmin;
- `dart analyze` nos dois pacotes;
- `flutter build web` com configuracao client-safe.

## Criterios de aceite

- credenciais validas geram uma sessao Supabase e abrem a shell;
- credenciais invalidas nao autenticam e mostram feedback seguro;
- sessao so sobrevive a reinicializacao quando o checkbox estava marcado;
- logout encerra a sessao atual e retorna ao login;
- ausencia de defines nao causa crash nem tenta usar segredo alternativo;
- web e mobile compartilham o mesmo bootstrap e contrato;
- `go_router`, `MaterialApp.router`, componentes e tokens atuais sao preservados;
- testes, analise e build web concluem sem falhas antes da entrega.

## Riscos e pendencias externas

- o teste ponta a ponta depende de URL, publishable key e usuario Auth validos;
- a persistencia local protege contra perda acidental de sessao, nao contra um
  dispositivo comprometido;
- a autenticacao completa ainda exige platform membership, autorizacao
  server-side, MFA conforme papel, RLS e auditoria;
- politica de duracao, inatividade, sessao unica e revogacao sera definida em
  spec propria antes de operacoes sensiveis de producao.
