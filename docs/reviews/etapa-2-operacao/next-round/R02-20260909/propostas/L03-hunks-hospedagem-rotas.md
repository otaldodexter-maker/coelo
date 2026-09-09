---
title: "L03 — hunks de hospedagem das rotas Perfil e Para Você"
source: "Decisão final do Owner de 09/09/2026 sobre shell; L00 revisão 3; achado L03 e L01"
status: "proposto-nao-aplicado"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Hospedagem das rotas de L03 no ShellRoute

Formato equivalente a `propostas/L01-hunks-composicao.md`, para D00 montar o
movimento único com as três frentes na mão.

## Por que não saiu nesta branch

A decisão final do Owner de 09/09/2026 tem duas metades. A metade de viewer —
suspender apenas elementos internos concorrentes do Principal — está sendo
tratada por L01. A metade estrutural é o roteamento: enquanto a rota for um
`GoRoute` de topo declarado **antes** do `ShellRoute`, ela abre em tela cheia
fora do contêiner do hospedeiro, e nenhuma regra de viewer corrige isso.

Cheguei a aplicar o movimento apenas nas minhas três rotas e revertê-lo, porque
L01 trouxe a consequência decisiva: hospedar só uma frente faz o menu do
hospedeiro aparecer e desaparecer ao navegar entre telas irmãs — Perfil dentro
do shell e Momentos fora. Isso é regressão de navegação, pior do que a ausência
uniforme de hoje, que é pendência conhecida. O movimento precisa ser único e
ordenado por D00.

**Estado declarado:** as rotas Principal continuam fora do `ShellRoute`. É
pendência conhecida escalada a D00, não esquecimento de nenhuma frente.

## O que já está pronto nesta branch

A composição embutida existe e está commitada em `7ca7ee63a`. `PrincipalProfileRoutePage`
e `PrincipalForYouRoutePage` aceitam `embedded` e o repassam às páginas, que já
suprimem cabeçalho e dock próprios do Principal. Nada além disso é necessário do
lado das telas: o movimento é só de roteamento.

## Hunks propostos em `apps/superadmin/lib/app/router/superadmin_router.dart`

Três `GoRoute` inteiros saem da lista de topo e entram na lista `routes:` do
`ShellRoute`, sem alteração de path, name, guarda de contexto ou callbacks:

| Rota | Constante | Linhas na base `7ca7ee63a` |
| --- | --- | --- |
| `/principal-for-you` | `SuperadminRoutes.principalForYou` | 833–865 |
| `/principal-profile` | `SuperadminRoutes.principalProfile` | 874–906 |
| `/principal-profile/edit` | `SuperadminRoutes.principalProfileEdit` | 907–922 |

Dentro de cada bloco movido, uma linha nova:

- `PrincipalForYouRoutePage(` recebe `embedded: true,`
- `PrincipalProfileRoutePage(` recebe `embedded: true,`
- `PrincipalProfileEditPage` não precisa: a página já é um `Scaffold` com
  `AppBar` própria e o hospedeiro não duplica esse chrome. Confirmar visualmente
  no movimento único; se duplicar, a página ganha o mesmo parâmetro.

Ponto de inserção sugerido: imediatamente antes do `GoRoute` de
`SuperadminRoutes.login` dentro do `ShellRoute`, com comentário registrando a
decisão do Owner.

## O que o movimento não exige

`_usesPersistentShell` não precisa mudar: ele só exclui login, recuperação,
redefinição e `/dev/errors/`. `_destinationForLocation` já mapeia
`principal-profile` e `principal-for-you`, e `_navigateFromPersistentShell` já
navega para elas — a estrutura hospedada é a pretendida, não invenção.

## Custo de teste, medido por L01

A mudança inverte 17 asserções em 6 arquivos de `test/app/router/` que codificam
a regra antiga de ausência do shell nas rotas Principal. Esse custo é do
movimento único, não de um hunk localizado, e é parte do motivo de D00 ordená-lo.

Do meu lado, `test/app/router/principal_profile_for_you_production_routes_test.dart`
não assere ausência de shell: ele prova que as rotas reais montam a composição,
falham fechadas sem contexto autorizado e não renderizam fixture. Deve sobreviver
ao movimento sem edição; confirmar na execução conjunta.

## Verificação esperada depois do movimento

Abrir `/principal-profile` e `/principal-for-you` com contexto autorizado e
confirmar que o menu do hospedeiro permanece; navegar entre Perfil, Para Você e
as telas de L01 e confirmar que o menu não pisca; confirmar que o cabeçalho e o
dock próprios do Principal não aparecem duplicados; e reexecutar os 6 arquivos de
rota afetados mais o meu.
