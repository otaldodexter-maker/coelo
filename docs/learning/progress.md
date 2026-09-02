---
title: "Progresso de Aprendizagem do Coelo"
source: "Interacoes do usuario com a skill coelo-tutor"
status: "active-learning-memory"
generated_at: "2026-07-14"
updated_at: "2026-09-02"
---

# Progresso de Aprendizagem do Coelo

## Perfil

- Nivel declarado: iniciante absoluto.
- Contexto: aprende enquanto constroi `apps/superadmin` com o Codex.
- Preferencia: entender o que foi feito, por que, onde fica e como se conecta.
- Ritmo: um objetivo principal por aula, com exemplos pequenos.

## Ponto atual

- Fase: 1 - Mapa do projeto.
- Assunto: como o Superadmin comeca - `lib` e `main.dart`.
- Estado: Aula 02 avancada em Dart e Flutter; estudo em andamento.

## Apresentados

- Repositorio como pasta principal do projeto Coelo.
- `apps/superadmin` como pasta do aplicativo privado Superadmin.
- `lib` como raiz do codigo Dart/Flutter do Superadmin.
- Arquivo como documento individual dentro de uma pasta.
- `main.dart` como ponto inicial da execucao do aplicativo.
- Caminho inicial: repositorio -> `apps/superadmin` -> `lib` -> `main.dart`.
- `import` como a instrucao que traz bibliotecas e arquivos para uso.
- `main()` como a funcao que inicia a execucao do app.
- `usePathUrlStrategy()` como ajuste para usar URLs com caminho no web.
- `runApp()` como a chamada que entrega o widget raiz para o Flutter.
- `SuperadminApp` como o widget raiz para a interface do Superadmin.
- `StatefulWidget` como um widget que pode guardar estado.
- `build()` como o metodo que descreve o que aparece na tela.
- `MaterialApp.router` como a base do app com navegacao por rotas.
- `theme`, `darkTheme` e `themeMode` como as regras visuais principais.
- `routerConfig` como a ligacao do app com o roteador.
- Dart como a linguagem do codigo.
- Flutter como o framework que monta a interface.
- Widget como a peca visual que o Flutter desenha.
- `class` como a forma de definir um tipo novo em Dart.
- `State` como a memoria viva de um widget.
- Smoke e smoke humano como verificações rápidas automatizada e manual.
- SMTP/recovery real como o envio e recebimento efetivo de recuperação de senha.
- Revogação como retirada de acesso que deve valer também após recarregar.
- `fail-closed` como acesso bloqueado com segurança quando a autorização ou o backend não pode confirmar permissão.
- Gateway e adapter local como fronteiras entre a tela e a fonte de dados, usadas para testar e trocar a implementação sem misturar regras no widget.
- Replay como reaplicar migrations em ordem num ambiente limpo para conferir se o banco pode ser reconstruído.
- Tenant A/B como teste de isolamento entre duas instituições fictícias.
- Persistência, reload e E2E como salvar no backend, recarregar o app e comprovar o fluxo inteiro.

## Compreendidos com evidencia

- `lib` e a pasta onde fica o codigo Dart/Flutter do Superadmin.
- O arquivo que inicia o Superadmin e `apps/superadmin/lib/main.dart`.
- `main.dart` e o ponto que faz o app comecar a executar.
- `build()` e o metodo que descreve a interface que aparece na tela.
- `class` e uma construcao de Dart.
- `StatefulWidget` e um widget do Flutter.

## Evidencias pendentes

- Explicar com palavras proprias o que `main()` faz em `apps/superadmin/lib/main.dart`.
- Explicar para que `runApp()` serve nesse arquivo.
- Explicar por que `SuperadminApp` e um `StatefulWidget` neste projeto.
- Distinguir melhor a casca web de entrada do app e o que o Flutter monta de fato.
- Distinguir com clareza Dart, Flutter, widget e classe no `SuperadminApp`.
- Explicar a diferença entre smoke automático e smoke humano.
- Explicar por que Tenant A/B e revogação precisam ser testados juntos.
- Explicar, com palavras próprias, a cadeia persistência → reload → E2E.

## Retomar

- Nenhuma duvida registrada ainda.

## Arquivos estudados

- `apps/superadmin/lib/main.dart`.
- `apps/superadmin/lib/README.md`.
- `apps/superadmin/pubspec.yaml` (somente para confirmar a identidade do app).
- `apps/superadmin/lib/app/superadmin_app.dart` (somente para confirmar para onde `main.dart` entrega a montagem do app).

## Exercicios

- Nenhum exercicio realizado ainda.

## Ultima interacao

- Aula 00 apresentou o mapa minimo do Superadmin e seu ponto de entrada real.
- O usuario confirmou `lib` como pasta do codigo Dart/Flutter e apontou `main.dart` como o arquivo de entrada.
- Aula de hoje avancou para Dart e Flutter usando `SuperadminApp` como exemplo real.
- O usuario confirmou que `class` e Dart e `StatefulWidget` e Flutter.
- Em 2026-09-02, foram apresentados termos de validação da Etapa 2: smoke,
  SMTP/recovery, revogação, fail-closed, gateways/adapters, replay, Tenant A/B,
  persistência, reload e E2E. Evidência de compreensão ainda pendente.

## Proximo passo

- Quando voltar, seguir `SuperadminApp` ate o `build()` e entender como ele monta o `MaterialApp.router`.
- Motivo: depois de achar o ponto de entrada, o proximo passo e entender a primeira tela/base visual do app.

## Historico

- 2026-07-15 - Aula de hoje avancou em `main.dart`: `import`, `main()`, `usePathUrlStrategy()`, `runApp()` e `SuperadminApp`. Estudo pausado por agora.
- 2026-09-02 - Glossário da Etapa 2 apresentado a pedido do usuário, usando gateways e replay reais do Coelo. Checagem pendente.
- 2026-07-15 - O usuario pediu para incluir Git e GitHub na trilha do tutor.
- 2026-07-15 - Aula 00 apresentada: repositorio, pastas, arquivo, `lib`, `main.dart` e caminho inicial do Superadmin. Checagem pendente.
- 2026-07-15 - Aula 00 checada: `lib` confirmado como pasta do codigo Dart/Flutter e `main.dart` confirmado como arquivo de entrada.
- 2026-07-14 - Memoria inicial criada. Nenhuma compreensao foi presumida.
