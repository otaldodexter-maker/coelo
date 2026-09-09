---
title: "C07 — varredura de `on Exception`: onde um Error escapa e o que ele quebra"
source: "leitura de código no baseline 4af42925 por dois subagentes somente-leitura com recortes disjuntos, revisada por C07 nos casos de maior gravidade, conferidos por mim na fonte; defeito original medido em c07_students_directory_test.dart; commit fdf0972d e sua mensagem; pedido operacional da C06 de 2026-09-08T19:42-03:00"
status: "evidence-survey"
generated_at: "2026-09-08T19:50:00-03:00"
timezone: "America/Sao_Paulo"
---

# Varredura — `on Exception` em Dart não captura `Error`

## Por que esta varredura existe

Ao escrever o aceite de Acompanhamento, três casos ficaram vermelhos por uma causa só: o view model
usa `on Exception`, que **não** captura `Error`. Um `TypeError` de decodificação escapa da carga, o
estado nunca sai de carregando, e a tela fica com o esqueleto para sempre.

O commit `fdf0972d` corrigiu exatamente isso em quatro view models de diretório, trocando
`on Exception` por `on Object`, com o comentário "a load that throws and leaves the spinner on screen
is a silent hang". A pergunta que ninguém tinha feito: **quantos outros consumidores do mesmo padrão
existem?**

Resposta: **65 ocorrências em 31 arquivos**, contra 97 já no formato correto. O código tem duas
gerações, e a correção anterior cobriu uma fração pequena da geração antiga.

## O achado que reenquadra o problema

**`fdf0972d` corrigiu os quatro caminhos menos alcançáveis e deixou de fora os mais expostos.**

Instituições, Unidades, Turmas e Pessoas estão hoje ligados a repositórios `Unavailable*` no
`createSuperadminAuthScope`. Já Atividades, Avaliações, Segurança da criança e os três compositores
do Principal estão ligados a repositórios Supabase **reais**, cheios de casts crus de decodificação
e sem normalização de erro — exatamente os que produzem `Error` em produção.

A justificativa do commit, "os controllers mais novos já capturam tudo", é verdadeira para perfis de
acesso, comunicados, saúde e importações, e **falsa** para atividades, avaliações, segurança e os
compositores.

## Contagem

| Veredito | Ocorrências | O que significa |
|---|---|---|
| Trava a tela | **22** em 10 arquivos | o `Error` escapa e a tela fica em carregando, ou um controle fica travado, sem retry |
| Vaza pela camada | **23** | o `Error` atravessa repositório ou gateway e chega cru a quem não o espera |
| Degrada | **29** | efeito menor: ação sem feedback, painel vazio sem explicação |
| Seguro | **5** | há proteção externa, ou o caminho não é de carga |
| Indeterminado | **2** | precisa leitura ou medição adicional |

Há sobreposição entre "trava" e "vaza" porque os dois recortes classificaram sob critérios
diferentes; a soma não deve ser lida como total de defeitos distintos.

**Não existe rede de segurança global.** Busca por `runZonedGuarded`, `FlutterError.onError`,
`PlatformDispatcher.instance.onError` e `ErrorWidget.builder` em `apps/superadmin/lib` e em
`packages/*/lib` retorna **zero** — conferi por mim. Todo `Error` que escapa vira erro assíncrono não
tratado, e no web em release isso é silêncio absoluto.

## Os quatro casos que verifiquei pessoalmente na fonte

Escolhi os de maior gravidade e li o código eu mesma, em vez de repassar leitura de subagente.

### 1. Sair não encerra a sessão — segurança

`apps/superadmin/lib/features/auth/domain/logout_action.dart:33`. O corpo é:

```
try {
  await auth.signOut();
  if (revisão inalterada) session.signOut();
  return const LogoutResult.success();
} on Exception {
  return const LogoutResult.failure(...);
}
```

Se `auth.signOut()` lançar um `Error`, ele escapa do bloco inteiro: **`session.signOut()` nunca
roda** e nenhum `LogoutResult` é devolvido. O usuário clica em Sair, a sessão local sobrevive, e nem
a falha é sinalizada. Como não há rede global, o erro assíncrono se perde.

### 2. Sessão autenticada sem autorização sobrevive — segurança

`apps/superadmin/lib/features/auth/domain/coelo_auth_login_action.dart:58`. No ramo em que o usuário
autentica no Supabase mas **não** tem autorização de Superadmin, o código tenta limpar a sessão:

```
try { await auth.signOut(); } on Exception { /* comentário */ }
if (revisão inalterada) session.signOut();
return const LoginResult.failure(...);
```

Um `Error` no `signOut` pula tanto o `session.signOut()` quanto o retorno de falha. O resultado é uma
sessão Supabase autenticada, sem autorização, viva localmente.

### 3. O app não sobe

`apps/superadmin/lib/main.dart` faz `final authScope = await createSuperadminAuthScope();` e só
então `runApp(...)`. A captura em `superadmin_auth_scope.dart` é `on Exception`. Um `Error` no
bootstrap — inicialização do Supabase, primeiro evento do stream de sessão, construção dos
repositórios — escapa antes do `runApp`, e o resultado é tela em branco, sem mensagem.

Ressalva: um dos subagentes marcou este caso como indeterminado por não ter lido o corpo inteiro do
`try`. Eu confirmei a estrutura de `main.dart` e o tipo da captura, não a existência de um caminho
concreto que lance `Error` ali.

### 4. Salvar pessoa com campo vazio não dá retorno nenhum

Este é o único do levantamento que **não** depende de payload malformado: o próprio código lança
`Error` como validação de rotina.

`person_form_view_model.dart:153` faz `return Future.error(ArgumentError('Identity fields are
required.'))` quando um dos campos de identidade está em branco. A página, em
`person_form_page.dart:488`, captura `on PersonDirectoryConflictException` e `on Exception`.
`ArgumentError` é `Error`. Logo, **nenhum aviso aparece**: nem snackbar, nem marcação de campo. O
botão parece morto.

Conferi também o portão do botão: em `person_form_page.dart:1101-1108`, o `onPressed` só depende de
`_viewModel.saving`. **Não há gate de identidade**, e não existe nenhum `validator:` no arquivo.

Ressalva honesta que faço contra a leitura mais alarmante: `_continue` (linha 433) **valida** os
campos de identidade antes de avançar de etapa, então o usuário não chega à última etapa com campos
vazios por esse caminho. O caminho alcançável é **limpar um campo depois de avançar** e então salvar.
Não medi isso; é leitura de código.

## Ordem de gravidade sugerida, por alcançabilidade

1. **`packages/coelo_auth/lib/src/supabase_coelo_auth_gateway.dart`**, linhas 79, 108 e 132. É o
   portão de autenticação, e o contrato declarado dos três métodos é "nunca lança": todos os ramos
   devolvem um resultado tipado com mensagem genérica. `on Exception` quebra exatamente essa promessa,
   que é a mesma que os aceites do projeto exigem sobre não vazar detalhe do backend. Pior em
   `updatePassword`, onde a ordem é trocar a senha e depois deslogar: um `Error` no segundo passo
   deixa a senha já alterada, o usuário sem confirmação e a sessão antiga viva. Como o pacote é
   plataforma para três apps, corrigir aqui protege Admin e Principal antes de existirem.
2. **Os dois de segurança de sessão** descritos acima.
3. **Atividades, Avaliações e Segurança da criança**, que estão ligados a repositórios reais com
   casts crus: matam o diretório de Atividades, o diário de Avaliações e o diretório de Segurança.
4. **Os três compositores do Principal**, onde um `Error` ao salvar ou publicar deixa a superfície
   sob `AbsorbPointer`, desabilitando até o botão Cancelar.
5. **Acompanhamento**, que é o único **medido**, e fica abaixo apenas porque hoje está ligado a um
   repositório `Unavailable`.

## Correção

A troca `on Exception` → `on Object` resolve a maioria, mantendo a cláusula por último. Três
ressalvas que os subagentes levantaram e que valem repetir:

1. **Em `student_tracking_view_model.dart` a troca sozinha não compila:** a assinatura
   `void _handleFailure(Exception error, int generation)` precisa passar a receber `Object`.
2. **Em `activity_directory_view_model.dart`, trocar só a linha 168, não a 181.** O `_capture` da
   181 devolve o erro como valor e o `_load` filtra com `whereType<Exception>()`. Se ele passasse a
   capturar `Object`, um `Error` viraria valor de retorno e o filtro deixaria de vê-lo — o erro seria
   tratado como sucesso. Hoje ele sobe pelo `Future.wait` e cai na captura certa.
3. **Onde o reset de estado está só no braço do catch**, trocar o tipo não basta: é preciso mover o
   reset para `finally`, senão a flag de carregando ou de salvando continua presa.

E uma checagem antes de aplicar em massa: se algum teste existente depende de `Error` propagando,
por exemplo com `throwsA(isA<StateError>())`, a troca o quebraria. Ninguém verificou isso.

## Limites honestos

1. **Quase tudo aqui é leitura, não medição.** A única prova de execução é a minha, em
   `student_tracking`, com três casos vermelhos. Todo o resto é análise de código.
2. **Verifiquei pessoalmente** os quatro casos da seção anterior, a ausência de rede global e a
   ausência de gate no botão salvar de Pessoas. Os demais vêm dos subagentes, que declararam quais
   arquivos leram por inteiro e quais leram por trechos.
3. **"O `Error` escapa" é afirmação sobre o código, não sobre a frequência.** Está provado que não há
   barreira de tipo no caminho. Não está provado que os clientes Supabase lançam `Error` na prática
   hoje, exceto no caso de Pessoas, onde é o próprio código do projeto que lança.
4. **A contagem de casts crus nos repositórios foi por busca, não por leitura de cada ocorrência.**
5. **Há sobreposição de cerca de 15 ocorrências** entre os dois recortes, em quatro arquivos de
   fronteira. A consolidação por arquivo está correta; a soma bruta de vereditos, não.
6. **Converter qualquer linha em fato medido é barato** e usa o padrão que já apliquei: injetar um
   repositório falso que lança `Error` e afirmar que a tela chega ao painel de falha com retry, e não
   ao esqueleto. Ofereço fazer isso para os casos que a C00 priorizar, dentro de reserva.

---

## Medição 1 — diretório de Atividades, 2026-09-08T20:50

Primeira linha da varredura convertida de leitura em **fato medido**, e escolhida por consequência:
está ligada a um repositório Supabase **real**, ao contrário dos quatro que `fdf0972d` corrigiu.

Prova em `repro/activity_directory_error_hang_test.dart`. Método fora da árvore, com cópia temporária
para executar e remoção depois; `analyze` limpo; worktree conferida limpa ao fim.

| Caso | Resultado | Medido |
|---|---|---|
| **Controle** — `Exception` comum em `fetchPage` | **verde** | o estado vai para falha, como esperado. Prova que o harness funciona e separa "o teste está errado" de "o código está errado" |
| `Error` de decodificação em `fetchPage` | **vermelho** | o estado permanece em `loading` |
| `Error` de decodificação em `fetchFilterOptions` | **vermelho** | o estado permanece em `loading` |
| Página montada com o repositório que lança `Error` | **vermelho** | a chave `activity-directory-loading` **continua encontrada** depois da falha: a tela fica no esqueleto, sem retry |

### Correção que a medição fez na minha própria formulação

Eu vinha dizendo, e a varredura também, que o carregamento "trava". **O mecanismo é mais preciso, e
importa para quem for corrigir:**

`_load` é `async`, então o `Error` que escapa do `try` vira o erro do `Future` devolvido por `load()`
— ou seja, no nível do view model a chamada **completa com erro**, não fica pendurada. O travamento
acontece na **UI**: `activity_directory_page.dart:175` dispara `load()` dentro de um
`addPostFrameCallback` e **descarta o Future**. O erro vira erro assíncrono sem tratador, o
`notifyListeners()` da linha 173 fica fora do `try` e não roda, o estado continua `loading` e a
página renderiza o esqueleto para sempre.

Consequência prática para o teste: **medir só por timeout daria falso verde**, porque `load()`
completa. A prova precisa afirmar o **estado final** e a **ausência do esqueleto**, que foi o que
este harness fez.

### O que a medição deliberadamente não afirma

Nada sobre a linha 181 (`_capture`), que devolve `Exception` como valor e deixa `Error` subir de
propósito. Se ela capturasse `Object`, um `Error` viraria valor de retorno, passaria pelo filtro
`whereType<Exception>()` e estouraria num cast adiante — trocaria um defeito por outro. O teste mede
só o contrato observável, então continua válido qualquer que seja a forma da correção.

### Estado da família após esta medição

Duas linhas medidas, das 22 que travam: Acompanhamento e Atividades. As demais continuam leitura.
Atividades vale mais que Acompanhamento na ordem de consequência, porque Acompanhamento está hoje
ligado a um repositório `Unavailable` e Atividades não.

---

## Medição 2 — Segurança da criança, 2026-09-08T20:53

Terceira linha da família convertida em fato medido. Prova em
`repro/child_safety_error_hang_test.dart`. Mesmo método: fora da árvore, cópia temporária para
executar, remoção, worktree conferida limpa. `analyze` limpo.

| Caso | Resultado | Medido |
|---|---|---|
| **Controle** — `Exception` comum | **verde** | vai para erro com mensagem, como esperado |
| `Error` de decodificação na carga | **vermelho** | `load()` **propaga** `_TypeError: type 'int' is not a subtype of type 'String' in type cast` em vez de virar estado |
| Falha anunciada e retry recupera | **vermelho** | mesma propagação; os ouvintes nunca recebem aviso de erro |
| Página montada | **vermelho** | `CircularProgressIndicator` **continua na árvore** depois da falha: esqueleto sem retry |

A tela presa esconde do operador o estado real das autorizações de retirada de uma criança.

## O achado colateral, que pode ser pior que o alvo

Verifiquei os dois pontos na fonte.

**O produtor concreto de `Error` está no decodificador de opções, não no de diretório.**
`child_safety_response_decoder.dart`, linhas 84 a 88, usa conversões **cruas** em quatro campos —
`internal_id`, `child_context_id`, `institution_id` e `unit_id`, todos `as String?` — enquanto o
**mesmo arquivo** tem ajudantes defensivos (`_string`, `_map`, `_list`, `_nullableString`) usados no
resto. Basta a consulta devolver um desses campos como número para sair `TypeError`.

**E o caminho que consome isso falha em silêncio.** `safety_pages.dart:1132`, no formulário de
autorização de retirada, faz:

```
try   { options = await controller.searchChildren(...) }
on Exception { error = 'Não foi possível buscar crianças.' }
finally      { searching = false }
```

Um `Error` atravessa o `on Exception`, mas o `finally` **desliga o indicador de busca assim mesmo**.
Resultado observável: o spinner some, a mensagem de erro **não** aparece, e a lista de opções fica
vazia ou com o conteúdo velho. **A busca "termina" fingindo que não encontrou ninguém.**

Isso é diferente, e em certo sentido pior, que a tela presa: presa é visivelmente quebrada; esta
parece funcionar e dá uma resposta errada plausível, num formulário que autoriza quem pode retirar
uma criança.

Registro também, a favor do código: `_loadInitialContext` (linha 887) captura corretamente o
`ChildSafetyNotFoundException` previsto. É só o `Error` que passa direto. E os decodificadores de
diretório e de registro **são defensivos**, sem cast cru — ali o `Error` só viria da pilha do cliente
Supabase, o que é plausível mas indireto.

**Correção mínima, nos três pontos:** trocar `on Exception` por `on Object`, mantendo antes as
capturas de exceção específica, em `child_safety_controller.dart:146`, `safety_pages.dart:887` e
`safety_pages.dart:1132`. E, na origem, trocar as quatro conversões cruas do decodificador pelos
ajudantes defensivos que o próprio arquivo já tem — isso elimina o produtor concreto, em vez de só
tratar o sintoma.

Não escrevi assertiva para os pontos 887 e 1132; são leitura verificada por mim na fonte, e caberiam
no mesmo arquivo se houver interesse em fechar o macrotema.

## Estado da família após esta medição

Três linhas medidas das 22 que travam: Acompanhamento, Atividades e Segurança da criança. As duas
últimas estão ligadas a repositórios reais. Restam Avaliações e os três compositores do Principal
como próximos candidatos por consequência.

---

## Medição 3 — a busca silenciosa do formulário de autorização de retirada, 2026-09-08T21:09

**Conclusão da medição de Segurança da criança que a `R01-C06-I012` mandou terminar com segurança.**
Esta é a última medição desta frente; nada novo foi aberto depois dela.

Prova em `repro/child_safety_silent_search_test.dart`, **9 casos: 3 verdes e 6 vermelhos**, `analyze`
limpo. Cobre **produtor e consumidor** do mesmo defeito.

### Consumidor — a tela

| Caso | Resultado | Estado medido |
|---|---|---|
| **Controle** com `Exception` comum | **verde** | a mensagem "Não foi possível buscar crianças." aparece. A tela já cumpre o contrato para `Exception` |
| Busca que lança `Error` | **vermelho** | `indicador desligado, mensagem de falha ausente, 0 opção(ões) na tela` |
| Busca que lança `Error` com resultado anterior na tela | **vermelho** | `indicador desligado, mensagem de falha ausente, 1 opção(ões) na tela` |
| **Vazio legítimo** | **verde** | sem mensagem de falha, sem cartão, sem indicador |

### O achado que é pior do que eu havia descrito

Eu vinha dizendo que a busca "termina fingindo que não encontrou ninguém". A medição mostra um
segundo sintoma, mais grave: **quando já havia um resultado na tela, ele permanece como se fosse a
resposta da busca nova.**

No caso medido, a operadora busca "Ana", encontra Ana, depois busca "Bia" e a segunda busca falha.
A tela continua mostrando **Ana**, sem indicador e sem mensagem de erro, como se Ana fosse o
resultado de "Bia". O teste confirma que a segunda consulta chegou ao repositório, então não é
cache: é falha engolida com resultado velho apresentado como atual.

Num formulário que autoriza **quem pode retirar uma criança**, isso deixa de ser um problema de
carregamento e passa a ser risco de o operador selecionar a criança errada.

O caso do vazio legítimo passar é o que dá força ao conjunto: prova que o defeito não é "vazio
some", e sim **falha vira vazio, ou pior, falha vira resultado errado**.

### Produtor — o decodificador

Os quatro campos com conversão crua lançam `TypeError` com payload numérico, **todos os quatro
medidos**: `internal_id`, `child_context_id`, `institution_id`, `unit_id`
(`child_safety_response_decoder.dart:84-88`). O controle com payload dentro do contrato passa.

Os campos **vizinhos, na mesma linha** — `institution_name` e `unit_name` — já usam os ajudantes
defensivos do próprio arquivo. Ou seja, a correção não precisa inventar nada: é aplicar aos quatro o
que os vizinhos já fazem.

### Agravante lido na tela, que explica por que o sintoma é silencioso

O passo inicial do formulário **não tem mensagem própria de "nenhum resultado"**: renderiza só o
campo de busca e o laço sobre as opções. Portanto **o único sinal que separa "falhou" de "não
encontrei" é exatamente a mensagem de erro que o defeito suprime.**

### Correção mínima

Nos três pontos de captura — `child_safety_controller.dart:146`, `safety_pages.dart:887` e
`safety_pages.dart:1132` — trocar `on Exception` por `on Object`, mantendo antes as capturas
específicas. E, na origem, trocar as quatro conversões cruas pelos ajudantes defensivos que o arquivo
já tem, o que elimina o produtor em vez de só tratar o sintoma.

### Nota de método que quase custou a prova

O `finally` de `_search` desliga o indicador **sem restaurar nada**, e é justamente ele que converte
uma falha em "busca concluída sem resultados". É a segunda vez nesta rodada que a existência de um
`finally` induz à conclusão errada. A regra que fica: ler o que há dentro, não que ele existe.

### Estado final da frente encerrada

Quatro medições entregues: Acompanhamento, Atividades, Segurança da criança (carga) e Segurança da
criança (busca silenciosa). As demais linhas da varredura permanecem **leitura**, e a frente está
**encerrada por decisão da C00**. Não abri nada depois desta.
