---
title: "R08 G5 — P51 criação de usuário interno pela API"
source: "gate nominal C0; internal-user-create v4 em produção; execução G5"
status: "criacao-e-reload-verdes-link-runtime-parcial"
generated_at: "2026-09-12T13:08:00-03:00"
---

# P51 — criação normal, link seguro e releitura

`apps/superadmin → Acessos → Usuários internos → Criar → internal-users.create`.

O C0 autorizou uma única identidade sintética R08. Antes da escrita, G5
conferiu a branch G2: não havia roteiro executado nem criação registrada. O
runner [internal-user-create-p51-smoke.py](internal-user-create-p51-smoke.py)
carrega credenciais privadas somente em memória, bloqueia se a busca exata já
tiver resultado e nunca imprime senha, JWT, action link, query ou token.

## Resultado concreto

- login normal do operador: passou;
- `superadmin_internal_user_create_authorize_v1`: passou, provando novamente
  `platform.member.update` e escopo de plataforma antes da criação;
- Edge Function `internal-user-create` v4: HTTP 200 e identidade criada;
- identidade interna: `0ddeebc0-ee10-4565-96e0-ef11cacfc734`;
- perfil mínimo global escolhido pelo servidor: `support`, 2 permissões;
- releitura nominal: detail passou; busca pelo e-mail exato devolveu total 1;
- credencial, membership e escopo: `active`, `active`, `platform`;
- logout local: HTTP 204;
- sintético preservado até o fim formal da Etapa 2; nenhuma limpeza executada.

## Link seguro: prova e limite honesto

A resposta trouxe `password_setup_link`, e a Edge v4 só a devolve depois de
validar HTTPS, origem do projeto, ausência de credenciais na authority e path
`/auth/v1/verify`. O código implantado passa o redirect canônico
`https://superadmin.coelo.me/reset-password` ao Auth Admin.

O primeiro verificador local terminou `password_setup_link_contract=false`
depois da criação porque tratou nomes de headers HTTP como case-sensitive;
`urllib` os entregou em minúsculas. Um OPTIONS read-only imediatamente depois
confirmou `Cache-Control: no-store`, CORS exato para 3014 e os quatro headers
permitidos. O runner foi corrigido para normalizar nomes de headers.

Como o action link não é armazenado e foi descartado da memória sem ser
impresso, não é possível repetir a verificação dinâmica do `redirect_to` sem
gerar outro link privilegiado. Assim, HTTPS/host/path são controles produtivos
executados pela função, `no-store`/CORS foram medidos remotamente e o redirect
exato está provado por fonte implantada + Deno 8/8 informado pelo C0/G2; a query
do link desta execução específica permanece **não observada**. Não criar um
segundo usuário para mascarar essa limitação.

O modo read-only `--verify-existing-id` passou depois: `existing_count=1`,
detail/list/reload verdes, perfil `support`, duas permissões, logout local 204.
