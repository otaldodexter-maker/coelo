---
title: "Verificação pós-merge do grupo Claude — R02"
source: "Pedido de L00 em 09/09/2026; insumos de L01, L02 e L03; verificação própria de L03 contra origin/dev"
status: "checklist-para-D00"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# O que rodar depois de integrar L01, L02 e L03

Escrito para quem **não** acompanhou o dia. Se você está integrando três branches
Claude em `dev` e quer saber o que executar e o que cada falha significa, esta é
a sequência.

Autor: L03. Os itens de L01 e L02 vieram por L00 e estão marcados como
**relatados**; os de L03 e os fatos sobre `dev` foram **verificados por mim** no
código, e digo qual é qual em cada ponto.

## Estado das branches

| Frente | Branch | HEAD relatado | Verificado por mim |
| --- | --- | --- | --- |
| L01 Publicações | `codex/e2-r02-l01-publicacoes` | `251a7ec95` e anteriores (`8b83784e`, `e02b5f1b`, `9fe319159`, `aec0c4afe`, `eda75646`) | não |
| L02 Chat/Comunicações | `codex/e2-r02-l02-chat-comunicacoes` | `65e5c4b5b` e `6588f0d8` | não |
| L03 Perfil/Para Você | `codex/e2-r02-l03-perfil-para-voce` | `e35f33591` | sim |

Base comum das três: `56eb3f19d`. `origin/dev` estava em `d7ce6976b` quando
escrevi isto.

Dois commits de `dev` já tocam este território, **verificados por mim**:

- `f5e5d8dfc fix(superadmin): preserve the host across Principal routes` — moveu
  as rotas Principal para dentro do `ShellRoute`. **Movimento apenas
  estrutural**: em `dev`, `/principal-profile` e `/principal-for-you` continuam
  resolvendo para `_unavailableCompositionRootRoute`, e o router de lá não tem
  as composition roots, os parâmetros de repositório nem a rota
  `/principal-profile/edit`.
- `7271f4a39 feat(principal): filter Para Você by authorized audience scope` — é
  o `8c041ed50` de L03 levado a `dev`. Portanto `dev` carrega a **versão antiga**
  desse trabalho. Ver perigo (a).

## Os quatro perigos, e o teste que pega cada um

### (a) Reintroduzir o escopo de audiência opcional em Para Você

**Como acontece:** resolver os quatro conflitos de `principal_for_you` tomando o
lado de `dev`. Lá, `PrincipalForYouCommunicationsAdapter.highlights` e
`isEligible` recebem `scope` como parâmetro **opcional**; quando é nulo, o gate
de audiência é pulado inteiro e só status e vigência são aplicados.

**Por que importa:** um gate de autorização opcional está a um argumento
esquecido de ser desligado em silêncio. A branch de L03 tornou o parâmetro
obrigatório justamente por isso.

**O teste que pega:**
`apps/superadmin/test/features/principal_for_you/data/principal_for_you_communications_adapter_test.dart`,
caso `não há caminho que dispense a avaliação de audiência`. Ele assere que um
comunicado dirigido a outra instituição **não** é elegível. Na versão de `dev` o
mesmo caso afirmava o contrário — o teste protegia o buraco e foi invertido.

**Se falhar:** o merge tomou o lado errado nos quatro arquivos. Refazer com o
lado de L03.

### (b) Deixar `/principal-profile/edit` inalcançável

**Como acontece:** trazer a rota de edição sem trazer a declaração de capacidade
em `hasAuthoritativeMutationCapability`.

**Por que importa:** a rota termina em `/edit`, e `_isProductionMutationLocation`
classifica qualquer rota assim como mutação autoritativa. Sem capacidade
declarada, o `redirect` global manda **toda** visita para
`/errors/mutation-capability-unavailable`. A tela existe, persiste e tem provas
de widget — e não abre. Foi assim que o defeito passou despercebido a primeira
vez.

**O teste que pega:**
`apps/superadmin/test/app/router/principal_profile_for_you_production_routes_test.dart`,
os três casos `real /principal-profile/edit ...`: abre com Sobre autorizado, fica
fail-closed sem repositório, e negação mantém o salvar fora da tela.

**Se falhar o primeiro caso:** falta esta linha, antes do `return false` final do
predicado:

```dart
    if (location.startsWith(SuperadminRoutes.principalProfile)) {
      return profileAboutRepository != null;
    }
```

### (c) Launcher de Mensagens voltando à página administrativa

**Relatado por L02.** Existem três destinos `?from=principal` que hoje montam a
página administrativa de chat; a composição Principal própria de L02 substitui o
destino. Resolver o router por lado pode deixar os três apontando para o lugar
antigo.

**Testes indicados por L02:** `chat_routes_test.dart`,
`principal_chat_route_test.dart` e `chat_unread_badge_wiring_test.dart`.

**Observação de L03, verificada por mim:** dois desses destinos são meus — a ação
Mensagem do Perfil e o launcher do hub — e ambos apontam hoje para
`SuperadminRoutes.conversationsName` com `queryParameters: {'from': 'principal'}`.
Quando a rota de L02 existir na base integrada, **é uma linha em cada um dos dois
callbacks** no builder do Perfil e no do hub. Eu não fiz a troca porque a rota
não existe na minha base; não é esquecimento.

### (d) Apagar a porta de mídia de Momentos

**Relatado por L01.** Resolver `principal_moments_publication_route.dart` por
lado apaga a porta de mídia. O lote de publicação de Momentos de L01 é o que
pega. **Não verifiquei este ponto**: é fora do meu recorte e não tenho o arquivo
na minha base.

## Testes que documentam defeito e NÃO devem passar

Estes arquivos existem para **prender** defeitos conhecidos e não corrigidos.
Eles passam hoje porque asserem o comportamento defeituoso.

| Arquivo | Frente | O que prende |
| --- | --- | --- |
| `principal_happens_composition_gaps_test.dart` | L01 (relatado) | lacunas de composição do Acontece |
| `principal_now_real_route_test.dart` | L01 (relatado) | rota real do Agora |
| `principal_profile_edit_preview_affordance_test.dart` | L03 (verificado) | botão "Pré-visualizar" desabilitado abaixo de 1120 px |

**Verde inesperado nesses arquivos é suspeita, não sucesso.** Se um deles passar
depois de alguém ter *invertido* a asserção, ótimo — significa que a composição
foi ligada. Mas se passar sem que ninguém tenha ligado nada, o que aconteceu foi
que a asserção **foi relaxada** em vez de invertida, e o defeito voltou a ficar
invisível. Cada um dos três traz no cabeçalho a instrução de inverter, não
relaxar. Na dúvida, leia o cabeçalho antes de aceitar o verde.

## Ordem de verificação, do mais barato ao mais caro

1. **`flutter analyze lib test`** em `apps/superadmin`. Pega assinatura quebrada,
   parâmetro faltando e import perdido em segundos, que é a falha mais provável
   de um merge de router. Não siga para os testes com o analyze vermelho.
2. **Lotes de rota das três frentes.** São os que pegam os perigos (b) e (c) e
   são baratos:
   - `test/app/router/principal_profile_for_you_production_routes_test.dart` (L03, 11 provas)
   - `test/app/router/principal_real_route_test.dart` (tocado por `f5e5d8dfc`)
   - os arquivos de rota indicados por L02 em (c)
3. **Lotes de feature.** Pegam (a) e (d):
   - `test/features/principal_profile`, `test/features/principal_for_you`,
     `test/features/profile_about` (L03)
   - lotes de publicação e Momentos de L01
   - lotes de chat e notices de L02
4. **pgTAP por último.** Exige subir container Postgres. Nenhum pacote de banco
   desta rodada foi aplicado remotamente, então isto prova contrato, não produção.

## O que NÃO é regressão

Primeira execução pós-merge vai parecer catástrofe se você não souber disto.
Estas falhas **já existem na base** e não foram introduzidas pelo merge:

| Quantidade | Onde | Situação |
| --- | --- | --- |
| 10 | `principal_profile_preview_golden_test.dart` | golden drift pré-existente, verificado por L03 reproduzindo na worktree `e2-r02-d02-estrutura`, intocada, na mesma base |
| 23 | goldens de L01 | relatado por L01 |
| 12 | goldens de L02 | relatado por L02, que provou reverter lib e test na base limpa e as falhas permanecerem |
| ~191 | fora dos recortes Claude | **não revalidadas**: ninguém estabeleceu baseline para elas nesta rodada. Não são "pré-existentes" nem "do merge" — são desconhecidas, e devem ser relatadas assim |

Referência de L03 para comparação: na branch `codex/e2-r02-l03-perfil-para-voce`,
o conjunto `test/features/principal_profile` + `principal_for_you` +
`profile_about` + o lote de rota está em **P=225, F=10**, com as 10 sendo
exatamente as goldens acima. Se depois do merge esse conjunto tiver falha
diferente dessas 10, é achado do merge.

Nenhuma das três frentes regravou golden aprovado, e nenhuma deve regravar para
"limpar" a execução pós-merge. Deriva de golden é decisão visual do Owner e de
`coelo-ui`, não da integração.

## Anexo — varredura de capacidade no recorte de L03

L00 pediu para varrer o recorte atrás de outras rotas terminadas em `/new`,
`/edit` ou `/duplicate` que precisem de declaração de capacidade. Resultado da
varredura em `superadmin_routes.dart`, ignorando `/dev/`:

- `/principal-profile/edit` — **do meu recorte, já declarado** (perigo (b)).
- `/circulars/new` e `/circulars/:circularId/edit` — cobertos, o predicado já
  trata `location.startsWith('/circulars')`.
- `/profiles/...` e `/profile-models/...` — **isentos por desenho**:
  `_isProductionMutationLocation` os exclui explicitamente, com comentário
  dizendo que as RPCs de perfil de acesso revalidam ator, escopo, MFA e versão
  no servidor.
- `/health-care/profiles/new` e `/health-care/profiles/:childId/edit` —
  **candidatas, fora do meu recorte**. Não encontrei `startsWith('/health-care')`
  em `hasAuthoritativeMutationCapability`, o que as deixaria sempre
  redirecionadas pela guarda. **Não afirmo que seja defeito**: pode ser
  fechamento intencional do domínio de saúde. Fica como pergunta para quem
  responde por ele, não como achado.

Nenhuma outra rota do meu recorte precisa de declaração.
