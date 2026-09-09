---
title: "R02 D03 — nota focal students.list"
source: "CONTRATO.md; prompts/D03.md; assignment D03 revisão 2; ADR 0015; spec 015; CHILD R01"
status: "local-green-awaiting-backend-and-e2e"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# `students.list`

Etapa 2 → `apps/superadmin` → Acompanhamento → Acompanhamento de alunos →
lista autorizada → `students.list`.

## Origem reutilizada e limite da fatia

A base R02 `56eb3f19de23e364ea5f7e4f73a6fbd9a851e230` preservava o DTO CHILD,
`SupabaseChildDirectoryReader` e `ChildDirectoryController`, porém não preservava
o painel nem sua composição na rota normal. O delta recupera a intenção dos
commits históricos `e4489224` e `2b8ae08a`, revalidada contra a base atual.

O contrato CHILD transporta somente `context_id`, `person_id`, `person_name`,
`institution_id`, `institution_name` e cursor opaco (`name`, `context_id`). Cada
página aceita 1–50 itens; o cliente usa 20. O painel mostra apenas nome e
instituição, sem inventar status, turma, unidade, avatar, total ou detalhe. Os
cards são informativos: usam a superfície canônica de Instituições com
`onPressed: null`, sem semântica falsa de botão. A paginação é somente para a
frente, exatamente como o cursor disponível.

A lista não possui busca nem total no contrato atual e, sozinha, não encerra
todo o diretório `students.list`. Esta é a fatia mínima que torna a página CHILD
autorizada visível sem remover o Acompanhamento existente. As abas Visão geral,
Assiduidade, Avaliações, Competências e Boletins continuam abaixo da lista e
preservam seus estados próprios.

## Segurança e estados

Sem reader injetado, a tela permanece como antes. Sem sessão, em revogação ou
troca de revisão, o controller elimina a página anterior e mostra negação. Uma
falha não se torna lista vazia. Os parâmetros e IDs continuam não confiáveis;
o frontend só renderiza a resposta e não concede autorização.

## Verificação local

O arquivo focal terminou com 5/5 testes aprovados. Ele cobre composição da lista,
ausência de regressão sem injeção, limpeza na revogação, wiring real da rota
`/students` com redirecionamento no sign out e layout a 375 px com texto a 200%.
O analyzer dos oito arquivos nominais não encontrou issues. O validador visual
global reportou somente `location_schedule_section.dart:292`, fora deste
ownership; nenhum arquivo de Alunos foi reportado.

## Gates abertos

O composition root agora entrega o `ChildDirectoryRead` do Supabase e a rota
normal `/students` invalida a lista com a revisão de autorização da sessão. A
consulta SELECT-only do executor D03/pai no projeto de produção
`coelo` confirmou que `public.superadmin_child_context_directory_v2` não existe.
Logo, não há Backend `done`, persistência/reload remoto nem E2E. O pacote CHILD
nominal e seu replay serializado pertencem ao coordenador.

`students.link`, `students.transfer`, `students.edit` e `students.revoke`
continuam fora desta fatia: ADR 0015/spec 015 definem o domínio conceitual, mas
o repositório não contém contrato técnico aprovado de comando, recibo, versão,
auditoria e negativas para essas quatro ações. A rota de gestão permanece
honestamente indisponível.

Conhecimento: `no-op`; nenhuma regra durável nova foi aprovada.

## Prova focal de troca autenticada A → B

O caso focal adicional autentica dois contextos institucionais distintos com o
papel `owner` e as permissões `platform.read` e `people.read`, coerentes com o
contrato CHILD. Depois de abrir uma paginação de A com o cursor
`('aluna a', context_id_A)`, a reautorização em B inicia nova leitura com
`institution_id: null` e cursor nulo, pois o backend deriva o escopo do ator.
A página de B permanece renderizada quando a resposta pendente de A chega.

O teste focal terminou com 1/1 caso aprovado e o analyzer do arquivo não
encontrou issues. A prova revisada usa `ensureVisible` para rolar a `ListView`
normal `student-tracking-scroll` até o controle e então executa um toque real no
`FilledButton`. O deslocamento inicial era uma limitação da viewport do harness,
não um defeito reproduzido no layout. O caso cobre o gesto, o request, a
invalidação e o descarte tardio nessa composição local; não certifica Backend,
persistência/reload remoto, E2E nem `students.list` completo.
