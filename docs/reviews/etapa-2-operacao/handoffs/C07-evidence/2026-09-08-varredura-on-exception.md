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
