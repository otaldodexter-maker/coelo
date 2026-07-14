---
title: "Coelo Tutor Design"
source: "User-approved request; AGENTS.md; apps/superadmin/lib/README.md; apps/superadmin/lib/features/README.md; decisions/0007-flutter-app-structure.md; docs/contexts/superadmin-context.md"
status: "approved-design"
generated_at: "2026-07-14"
updated_at: "2026-07-14"
---

# Coelo Tutor Design

## Objetivo

Criar uma skill local chamada `coelo-tutor` para ensinar programacao a uma
pessoa 100% iniciante usando o codigo real do Coelo, com foco inicial em Dart,
Flutter e `apps/superadmin`, evoluindo depois para Supabase, PostgreSQL e SQL.
A skill deve preservar entre tarefas onde o estudo parou, o que ja foi
compreendido e por que o proximo passo foi escolhido.

## Problema

Explicacoes isoladas em conversas diferentes nao formam uma trilha confiavel.
Sem memoria persistente, o tutor pode repetir assuntos, pular fundamentos ou
ensinar conceitos desconectados do codigo que esta sendo construido pelo
Codex. Como a pessoa esta comecando do zero, termos comuns para quem programa
nao podem ser presumidos como conhecidos.

## Abordagem aprovada

Usar uma skill versionada no repositorio, acompanhada por dois documentos de
aprendizagem:

- `.codex/skills/coelo-tutor/`: comportamento do tutor e metadados de
  acionamento;
- `docs/learning/curriculum.md`: ordem orientativa dos assuntos e motivos das
  dependencias entre eles;
- `docs/learning/progress.md`: memoria viva das aulas, duvidas, exercicios e
  proximo passo.

Essa abordagem foi escolhida porque fica limitada ao Coelo, pode consultar a
estrutura atual do projeto e mantem a memoria legivel e editavel pela pessoa.
Uma automacao diaria nao e necessaria: o tutor sera acionado somente quando a
pessoa pedir uma aula, explicacao, revisao, exercicio, quiz ou progresso.

## Experiencia da pessoa iniciante

O tutor deve:

1. comecar sem presumir vocabulario tecnico;
2. explicar primeiro em linguagem cotidiana e depois apresentar o nome
   tecnico;
3. usar analogias curtas e exemplos retirados do codigo atual;
4. explicar o que uma parte faz, por que existe, onde fica e com o que se
   conecta;
5. diferenciar claramente Dart, Flutter, Supabase, PostgreSQL e SQL;
6. limitar cada aula a um objetivo principal e poucos conceitos de apoio;
7. confirmar compreensao com uma pergunta ou exercicio pequeno;
8. aceitar `nao entendi` e reformular sem culpar a pessoa;
9. nunca alterar codigo durante uma aula, exceto quando a pessoa pedir uma
   atividade pratica ou implementacao;
10. registrar ao final o que foi visto e a justificativa do proximo passo.

## Modos de acionamento

- `$coelo-tutor aula`: continuar do ponto registrado.
- `$coelo-tutor explique <arquivo ou conceito>`: explicar sob demanda sem
  perder a trilha principal.
- `$coelo-tutor revise mudanças`: usar mudancas recentes do Superadmin como
  material de estudo.
- `$coelo-tutor exercício <tema>`: propor pratica curta e acompanhada.
- `$coelo-tutor quiz`: revisar assuntos ja estudados, sem introduzir conteudo
  novo como se ja fosse conhecido.
- `$coelo-tutor progresso`: resumir aprendizados, dificuldades e proximo passo.

Frases naturais como `aula de hoje`, `me ensine este arquivo`, `por que o
Codex fez isso?` e `continue de onde paramos` tambem devem acionar a skill no
contexto do Coelo.

## Fluxo de uma aula

1. Ler `docs/learning/progress.md` por completo.
2. Ler no curriculo apenas a fase atual e suas dependencias.
3. Inspecionar os arquivos reais necessarios para o tema, priorizando
   `apps/superadmin`.
4. Informar onde a trilha parou e por que o assunto do dia e o proximo passo.
5. Ensinar um objetivo principal com exemplos pequenos do projeto.
6. Fazer uma checagem curta de compreensao.
7. Responder duvidas ou ajustar a explicacao.
8. Atualizar o progresso somente depois da interacao ou quando a pessoa disser
   que deseja encerrar a aula.

## Memoria de aprendizagem

`docs/learning/progress.md` deve registrar:

- nivel declarado: iniciante absoluto;
- fase e assunto atual;
- conceitos apresentados e conceitos demonstrados como compreendidos;
- duvidas, confusoes e termos que precisam ser retomados;
- arquivos do Coelo usados como exemplo;
- exercicios propostos e resultado observado;
- resumo da ultima aula;
- proximo passo;
- justificativa explicita do proximo passo;
- historico cronologico curto das aulas.

Apresentar um conceito nao significa que ele foi compreendido. O tutor so deve
marcar compreensao quando houver evidencia na conversa, como explicacao com as
proprias palavras, resposta correta ou exercicio concluido.

## Curriculo inicial

1. **Mapa do projeto:** repositorio, app, pasta, arquivo, `apps/superadmin`,
   `lib`, `test`, `pubspec.yaml` e `main.dart`.
2. **Fundamentos de Dart:** valores, variaveis, tipos, funcoes, parametros,
   classes, objetos, `final`, `const`, imports e null safety.
3. **Fundamentos de Flutter:** widget, arvore de widgets, `runApp`, contexto,
   composicao, `StatelessWidget`, `StatefulWidget` e ciclo de atualizacao.
4. **Estrutura do Superadmin:** `app`, `core`, `features`, `domain`, `data`,
   `presentation`, `screens`, `widgets` e `view_models`.
5. **Interface e comportamento:** layout, tema, responsividade, formularios,
   validacao, estado, navegacao, assincronicidade, erros e testes.
6. **Dados e backend:** cliente e servidor, HTTP, JSON, autenticacao e
   autorizacao.
7. **SQL e PostgreSQL:** tabelas, linhas, colunas, tipos, chaves, consultas,
   relacionamentos, constraints, indices e transacoes.
8. **Supabase no Coelo:** Auth, Database, migrations, RLS, policies, RPCs,
   Edge Functions, Storage versus R2, multi-tenancy, auditoria e segredos.

A ordem e orientativa. Duvidas surgidas no codigo real podem criar desvios
curtos, mas o progresso deve registrar o retorno planejado para a trilha.

## Limites de seguranca e produto

- Nao ensinar o guard Flutter como autorizacao real.
- Reforcar que `service_role` e segredos nunca pertencem ao cliente.
- Ensinar RLS e isolamento por tenant antes de qualquer pratica sensivel com
  dados do Coelo.
- Usar dados ficticios em exemplos de SQL, especialmente para pessoas,
  criancas, mensagens e instituicoes.
- Explicar que midia privada do produto usa R2 e que o Postgres guarda
  metadados e permissoes.
- Nao executar migrations, alterar banco remoto ou acessar producao como parte
  de uma aula sem pedido explicito e autorizacao apropriada.

## Arquivos e responsabilidades

### `SKILL.md`

Definir gatilhos, leitura obrigatoria da memoria, escolha do modo, formato da
aula, nivel de linguagem, criterios para atualizar o progresso e limites de
seguranca.

### `agents/openai.yaml`

Expor o nome `Tutor Coelo`, uma descricao curta e um prompt inicial que chame
explicitamente `$coelo-tutor`.

### `docs/learning/curriculum.md`

Explicar a trilha, o resultado esperado de cada fase, seus pre-requisitos e o
motivo da ordem. Ter frontmatter conforme o padrao documental do repositorio.

### `docs/learning/progress.md`

Inicializar a pessoa como iniciante absoluto, indicar a primeira aula e deixar
campos estruturados para atualizacoes futuras. Ter frontmatter e data de
atualizacao.

## Tratamento de ausencia ou inconsistencia

- Se a memoria nao existir, recriar um estado inicial sem inventar aulas.
- Se o codigo tiver mudado desde a ultima aula, explicar a diferenca antes de
  reutilizar exemplos antigos.
- Se memoria e curriculo divergirem, preservar fatos observados no progresso e
  registrar a correcao necessaria.
- Se uma fonte oficial conflitar com o codigo, nao resolver silenciosamente;
  seguir `AGENTS.md` e registrar a pergunta em `docs/open-questions.md` quando
  aplicavel.

## Validacao

- validar a estrutura da skill com `quick_validate.py`;
- verificar que `agents/openai.yaml` referencia `$coelo-tutor`;
- verificar o frontmatter dos documentos de aprendizagem;
- testar um pedido de `aula`, um de `explique` e um de `progresso`;
- confirmar que o tutor consulta a memoria, ensina no nivel iniciante e explica
  a razao do proximo passo;
- confirmar que nenhuma mudanca existente do Superadmin foi alterada.

## Criterios de aceite

- a skill local pode ser descoberta e acionada como `$coelo-tutor`;
- frases naturais relacionadas ao aprendizado do Coelo tambem sao gatilhos;
- a primeira aula parte de conhecimento zero;
- toda aula informa onde parou e por que o tema foi escolhido;
- conceitos apresentados e compreendidos ficam separados;
- a memoria persiste em arquivo entre tarefas;
- exemplos usam o codigo atual do Superadmin;
- o curriculo inclui Dart, Flutter, arquitetura, Supabase, PostgreSQL e SQL;
- nenhuma aula altera codigo ou sistemas externos sem pedido explicito;
- documentos derivados usam frontmatter com fonte, status e data.
