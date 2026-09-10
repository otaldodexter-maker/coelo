---
fonte: medicao propria sobre a worktree e2-noturna-operacoes-sistema
status: medido
data: 2026-09-10
base: 017949f71
autor: executor operacoes-sistema (Claude)
---

# Classes procuradas e não encontradas

Este documento existe porque ausência de defeito só vale como informação se
estiver registrada com o método. Sem isto a próxima rodada repete a varredura, e
pior: alguém pode declarar uma dessas classes como risco aberto sem saber que ela
já foi medida e veio limpa.

Todas as medições abaixo são sobre `apps/superadmin` na base `017949f71`.

## Navegação por string literal — limpa

Uma rota escrita à mão em `go('/alguma-coisa')` que não corresponda a nenhuma
rota declarada é navegação morta, e nenhum teste de widget a encontra se ninguém
tocar naquele botão.

Medida: fora de `lib/app/router/`, o app inteiro contém exatamente quatro
literais de caminho — `'/'`, `'/reset-password'`, `'/dev'` e `'/dev/'`. Toda
navegação real usa as constantes de `SuperadminRoutes`. A classe não existe aqui,
e a razão é estrutural: as constantes são a única forma usada.

## Mapeamento de negação de autorização — limpo

Um repositório que capture `PostgrestException` e traduza tudo para
"indisponível" apaga a diferença entre negação de autorização e falha
transitória. Isso importa para a UX, porque "tente novamente" convida ao retry em
cima de um 403, e importa para auditoria.

Medida: 46 arquivos de `lib` tratam `PostgrestException`; 45 deles citam
explicitamente `42501` ou `PGRST301`. O único que não cita, `forms_backend_gateway.dart`,
**preserva `error.code`** dentro de `FormsBackendFailure` e entrega a decisão ao
chamador, o que é a mesma invariante por outro caminho. A classe está fechada em
46 de 46.

## Rota produtiva de mutação sem porta de capacidade — sem lacuna silenciosa

Esta é a classe que produziu um achado real nesta Etapa, quando `/attendance` e
`/imports` não tinham ramo no redirect. A pergunta agora é se sobrou alguma.

Medida: cruzei todas as constantes de rota com forma de mutação — `/new`,
`/edit`, `/duplicate`, `/manage`, `/respond`, `/entry`, `/closing`,
`/assessment-settings`, `/calls/` — contra `_isProductionMutationLocation`. Dez
rotas produtivas escapam do redirect, e todas as dez são as quatro famílias
excluídas **de propósito**: Formulários, Agenda, Perfis e Modelos de perfil.
Nenhuma outra. Não há lacuna silenciosa.

O que havia era silêncio documental: só Perfis tinha comentário explicando a
exclusão. Escrevi o de Agenda, medido na migration de produção de Agenda — o save
exige permissão para entrar, valida contexto e audiência, recusa `published` sem
`agenda.publish`, e antes de atualizar exige `agenda.edit_all` ou autoria mais
`agenda.edit_own` junto de `p_expected_revision`; o command exige
`agenda.cancel_restore`; e o override de reserva exige permissão própria mais MFA
aal2 e justificativa. Não escrevi o de Formulários, que está sob reserva de outra
frente.

## Oráculo de ocupação de reserva na Agenda — descartado

Suspeita levantada durante a leitura acima: em `superadmin_agenda_save`, a sonda
de conflito de reserva e a recusa de `published` rodam **antes** da checagem de
permissão de edição, então quem tem apenas `agenda.read` distinguiria, pelo
código de erro, se existe reserva conflitante num intervalo.

Descartada por medição: `assert_agenda_context` roda antes das duas e limita o
ator à instituição e ao contexto que ele já pode ler. A informação que o erro
revelaria já está disponível na listagem que aquela permissão concede. Não é
escalada de informação.

## `setState` após `await` sem checagem de `mounted` — sem achado no recorte

Varredura textual apontou 31 candidatos no recorte, e a inspeção derrubou todos
os que foram verificados: a maioria é callback sincrono próximo de um `await`, e
os caminhos de carga reais são exemplares. `plan_directory_page._load` confere
`mounted`, identidade do repositório e versão da carga nos três ramos, inclusive
no `on Object`. Grep não é medição nesta classe, e o custo de confirmar cada
candidato um a um não se paga contra o que ela rendeu.

## Contrato de chaves do payload — não decidível estaticamente

Tentei estender o contrato cliente-banco para o conteúdo do payload: uma chave
que o cliente envia e a função nunca lê seria campo salvo no vazio, e uma chave
que a função lê e o cliente nunca envia seria sobrescrita com padrão.

A comparação não fecha, e a razão é legítima: o cliente aninha objetos —
`address`, `branding`, `audience`, `recurrence` — e o SQL grava vários deles
**inteiros**, com `p_payload->'recurrence'`, sem ler as subchaves. Uma subchave
não lida por aquela função não está perdida; está armazenada. Separar os dois
casos exige seguir cada objeto até o caminho de leitura, campo por campo, e isso
não cabia na janela. Fica registrado como tentativa com o motivo do impedimento,
e não como classe limpa.

Um falso positivo vale registro para quem tentar de novo: `'guardianRequest'` não
é chave de payload, é valor de enum `AgendaItemOrigin`. Varredor que coleta
`'x':` indiscriminadamente confunde as duas coisas.

## Contrato de enums no app inteiro — uma divergência real, o resto limpo

Depois de fixar o contrato de enums da Agenda, estendi a varredura a todo o app com
um heurístico que foi o que fez o defeito aparecer: comparar **conjuntos quase
iguais**. Para cada coluna com lista de valores permitidos e cada enum do cliente,
calcular a interseção; sinalizar quando ela passa de 60% **e** há diferença nos dois
lados. Igualdade exata é contrato cumprido; diferença só do lado do cliente é
inofensiva; diferença nos dois lados é renome que chegou a uma ponta só.

Medida: **82 colunas com lista** contra **284 enums**. Três pares sinalizados, todos
em Cardápios:

| Par | Banco só | Cliente só | Veredito |
| --- | --- | --- | --- |
| `meal_plans.status` x `MealPlanStatus` | `closed` | `ended` | **defeito real**, corrigido em `cadc56a48` |
| `meal_plans.source_type` x `MealPlanScopeLevel` | `exception` | `activity` | par cruzado pelo varredor; cada coluna bate com o seu próprio enum |
| `meal_plan_scopes.scope_level` x `MealPlanSourceType` | `activity` | `exception` | idem, e o cliente conhecer `activity` a mais é a direção inofensiva |

Ou seja: um defeito real em todo o aplicativo, e ele estava no meu recorte. O
heurístico tem um falso positivo previsível — quando duas colunas e dois enums de um
mesmo domínio são quase iguais entre si, o cruzamento aparece nas duas direções —
e reconhecê-lo custa ler dois pares, não refazer a medição.

O que isto fecha para quem vier depois: não é preciso repetir esta varredura por
domínio. O que vale repetir é o **teste** de contrato quando uma migration nova
mexer em lista de valores permitidos, porque aí a pergunta volta a ser aberta.

## Reflow dos formulários de criação — limpo

16 rotas de criação, em 375 e 1440 pixels, a 100% e 200% de escala de texto: 64
casos, 64 PASS, zero exceção. Isto localiza os overflows medidos nesta rodada nas
telas de diretório e lista, e **não** nos formulários, o que dispensa essa
varredura para quem vier depois.
