---
title: "Regras de produto fixadas pelo Owner em 16/09/2026"
knowledge_id: "owner-decisions-r14-mesa"
source: "decisions/0041-owner-decisions-r14-mesa-20260916.md"
status: "validated"
lifecycle: "current"
generated_at: "2026-09-16"
updated_at: "2026-09-16"
audience: "team"
surfaces: [superadmin, attendance, daily-routine, child-safety, medication, institutions, error-pages, principal, forms, authorization]
visibility: "internal"
review_owner: "Coelo Owner"
---

# Regras de produto fixadas pelo Owner em 16/09/2026

Projeção das decisões de produto da ADR 0041. A ADR é a fonte; este artigo
resume o comportamento esperado para quem implementa ou revisa. Nenhuma regra
abaixo está certificada como implementada só por constar aqui.

## Arquivar modelos (Atividades e Rotina diária)

Arquivar é **inativar reversível**: o modelo sai da lista padrão, fica em
"Arquivados" e pode voltar. Quem pode editar o modelo pode arquivá-lo. Rotinas
e atividades já criadas a partir dele continuam válidas. Não há exclusão física.

## Histórico de Assiduidade

Nova tela **Acompanhamento › Assiduidade › Histórico**: tabela das chamadas
lançadas (data, turma/atividade, quem lançou, presentes/ausentes, situação),
filtros por instituição, unidade, turma e período, e abertura do detalhe. A
tela não edita. A aba "Lançamentos" deixa o diretório de Rotina diária.

## Rotina exibida na chamada

Uma chamada **aberta** mostra a rotina vigente da turma/atividade. Ao
**concluir**, a chamada grava um snapshot (rotina + versão) e o histórico
passa a exibir sempre esse snapshot, mesmo que a turma troque de rotina
depois. Reabrir para corrigir presença não altera o snapshot. Chamadas antigas
sem snapshot exibem a rotina vigente com a indicação "rotina atual (não
registrada na época)".

## Busca de pessoa autorizada (Segurança da criança)

Um único campo, resultado conforme se digita, tipo detectado pelo formato:
nome, @ e e-mail a partir de 3 caracteres; celular a partir de 4 dígitos; CPF
a partir de 6 dígitos — todos aceitos com ou sem máscara. A busca respeita o
escopo do ator, é auditada e limitada em taxa. O resultado é minimizado (nome,
iniciais, @, últimos 4 dígitos do celular); **CPF nunca é exibido**. Quando o
resultado é um responsável, aparecem embaixo as crianças **vinculadas** a ele
dentro do escopo, e um clique preenche criança + pessoa autorizada. O botão de
cadastrar pessoa só aparece depois que a busca não encontrou ninguém.

## Pessoa autorizada sem conta

Cadastro mínimo: nome, sobrenome, **CPF obrigatório** (chave de deduplicação),
tipo e número do documento com **imagem** (mídia privada em R2), celular e
e-mail. Essa pessoa não usa o app: fica autorizada apenas no contexto pedido
pelo responsável (por exemplo, retirar a criança naquela unidade) e visível só
para esse escopo. Pode vir a ter conta no futuro.

## Card de Segurança da criança

O card do diretório permanece como está (identificação/contexto, situação,
autorizações vigentes, pendências). Não existe campo "alerta/restrição".

## Notificações de Medicação

Ao criar ou editar um plano de medicação e a cada dose registrada, o **sino
in-app** notifica os administradores da unidade e os educadores da turma da
criança. Sem e-mail ou push no MVP.

## "Ver como" no Principal

Ao entrar em "Ver como", o cabeçalho troca avatar e nome para a pessoa vista.
Não há faixa fixa adicional.

## Instituições › Arquivos

O flyout permanece na tela; ao ser aberto informa que está em desenvolvimento.
Não há importação nem exportação em Instituições no MVP (a única exportação do
MVP é a de respostas de Formulários). Erro/retry e acesso negado de
Instituições continuam no MVP.

## Páginas de erro

403, 404, 409, 500, 503 e "Tentar novamente" são ações só de tela
(`flutter-only`): o aceite terminal é o comportamento do Flutter na rota real;
não há prova de backend própria.

## Autosave de Formulários

Sai do MVP e vai para V1. As regras de audiência (H10) continuam no MVP.

## Perfis de cuidado (spec para R15)

Alergias/restrições e orientações nascem vazias e crescem por "+ Adicionar";
o wizard separa Alimentos de Restrições e o tipo vem do passo, não de um
campo; cada registro tem nome escolhido de lista categorizada com busca e opção
"Outro"; registros podem ser reordenados; antes de Observações há o campo
"O que fazer se consumido?". O limite defensivo de 100 por coleção permanece.
