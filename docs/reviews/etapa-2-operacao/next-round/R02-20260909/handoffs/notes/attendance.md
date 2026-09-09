---
title: "R02 D03 — nota de Assiduidade"
source: "prompts/D03.md; CONTRATO.md; specs/020-superadmin-attendance-prototype.md; execução local D03"
status: "local-green-partial; awaiting-central-commit"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Assiduidade — `attendance.correct`

Base observada: `56eb3f19de23e364ea5f7e4f73a6fbd9a851e230`, branch
`codex/e2-r02-d03-acompanhamento`. Runtime identificado como GPT-5; a variante
Sol e o esforço médio solicitados não são expostos independentemente a este
subagente.

## Delta local

O diálogo global de correção usava sempre `call.participants.first`, impedindo
corrigir qualquer outro aluno. O fluxo agora exige seleção explícita no
`CoeloAdminSingleSelectField`, atualiza o estado proposto conforme o aluno e
envia o `participantId` selecionado. Participante, estado, motivo e cancelamento
ficam bloqueados durante o comando assíncrono para não mostrar uma intenção
diferente da enviada.

Arquivos do delta:

- `apps/superadmin/lib/features/attendance/attendance_pages.dart`
- `apps/superadmin/test/features/attendance/attendance_pages_test.dart`

## Provas locais

- RED inicial: `correction applies to the participant selected in the dialog`
  falhou com `Bad state: No element`, pois não havia seletor de participante.
- Regressão nominal `--name correction`: 6/6 casos únicos aprovados, 0 falhos.
- Análise estática dos dois arquivos: 0 issues.
- Houve uma falha do próprio teste ao tipar `TextFormField` como `TextField`;
  o harness foi corrigido e o cenário passou. Não é falha de produto.
- Uma execução completa anterior à adição do segundo caso teve 47/47 aprovados;
  não foi somada à regressão nominal nem repetida sem causa.

Logs preservados em TEMP:

- `C:/Users/adrie/AppData/Local/Temp/d03-attendance-correction-regression.log`
  — SHA-256 `12F45D76D1DD930B2F9ECB72FF278BF9C2004592A6E84AE5094EB708EDF55C2A`.
- `C:/Users/adrie/AppData/Local/Temp/d03-attendance-correction-analyze.log`
  — SHA-256 `B4548AE78BCFDA50BBDDC6FD522603C3EA55DA9C95D039FE129F6F2A3FBA2E40`.
- `C:/Users/adrie/AppData/Local/Temp/d03-attendance-correction-focals.log`
  — SHA-256 `E82C5F73DAA57BAAB283FD86FF1BBC87CE6B63D67E8147F5E1B366E96A7C1B66`.
- `C:/Users/adrie/AppData/Local/Temp/d03-attendance-correction-lock-rerun.log`
  — SHA-256 `D8AD279EAE6E0BB302BBCFB88F6E989E51604F5BA98912E9EAAE89AC6AB0822E`.

## Limite do aceite

Avanço local FE de `attendance.correct`; BE e E2E continuam abertos. OQ-040 e
`specs/048-superadmin-internal-attendance-call-detail-v2-draft.md` ainda
bloqueiam capability interna, matriz/AAL, escopo, DTO infantil e cutover. Não
houve restauração de RPC legada, migração, acesso remoto ou alteração de
rastreador global.

Gate de conhecimento: `no-op`; o delta corrige a implementação de uma regra já
registrada, sem criar nova regra durável.

## Dashboard — `attendance.dashboard`

O dashboard capturava `DateTime.now()` diretamente e seus testes também
dependiam do relógio real, embora o rastreador exija clock determinístico. O
widget agora aceita `today` opcional, normalizado como data civil; sem valor,
preserva o comportamento produtivo baseado no dia atual. O teste fixa
09/09/2026 e comprova período inicial em 01/09/2026, fim em 09/09/2026 e os
limites `lastDate`/`currentDate` do seletor.

- RED: compilação recusou o parâmetro `today` ausente, como esperado.
- GREEN focal: 1/1 aprovado; análise dos dois arquivos: 0 issues.
- Log RED `C:/Users/adrie/AppData/Local/Temp/d03-attendance-dashboard-clock-red.log`
  — SHA-256 `3BE7555B5B59491D8E10BB1E93A69DDBEFD8DA74668FB387518410C8A9E7397B`.
- Log GREEN `C:/Users/adrie/AppData/Local/Temp/d03-attendance-dashboard-clock-green.log`
  — SHA-256 `495125FD1A726F989AA48211C0813A2874DC9C8C110A6C89B5E1FEC48AD6CAEC`.
- Log analyze `C:/Users/adrie/AppData/Local/Temp/d03-attendance-dashboard-clock-analyze.log`
  — SHA-256 `5E13AC301D0BC7E12517ECB893607A1D8CE43B63A1CFA058135326C121FBBD6D`.

Este é avanço FE local. Backend, remoto e E2E do dashboard permanecem abertos
pelos mesmos limites de OQ-040/spec 048 e pela migration local-only registrada.

## Validação do motivo — `attendance.correct`

O comando de correção ignorava silenciosamente a submissão quando o motivo
continha somente espaços. O diálogo agora apresenta `Motivo obrigatório` pelo
`errorText` do campo, permanece aberto, conserva o texto e limpa o erro quando
o usuário digita um motivo válido. O teste interage com a abertura e o botão
reais, comprova que nenhuma revisão foi criada no erro e conclui o mesmo rascunho
com sucesso.

- RED válido: 0/1 aprovado; a mensagem obrigatória estava ausente.
- GREEN focal: 1/1 aprovado.
- Regressão nominal `--name correction`: 7/7 casos únicos aprovados, 0 falhos.
- Análise estática dos dois arquivos: 0 issues.
- Uma tentativa RED anterior foi descartada porque a opção do popup estava fora
  da viewport e o toque não ocorreu; ela não conta como evidência do produto.
- Log RED `C:/Users/adrie/AppData/Local/Temp/d03-attendance-correction-required-reason-red-valid.log`
  — SHA-256 `A218E1BDD96D6283A1344D5F0D9726517A66493F175238C5E2CB8027F1C33109`.
- Log GREEN `C:/Users/adrie/AppData/Local/Temp/d03-attendance-correction-required-reason-green.log`
  — SHA-256 `2EB194482235DD7DD4571C3BC3973AA793BFEE2DD6D4CE697482F0EE5043D69A`.
- Log da regressão `C:/Users/adrie/AppData/Local/Temp/d03-attendance-correction-required-reason-regression.log`
  — SHA-256 `BA9B573F82EE6EB11F682F9F330795B8EDAA97020054D5C6F6E54B8D82112071`.
- Log do analyzer `C:/Users/adrie/AppData/Local/Temp/d03-attendance-correction-required-reason-analyze.log`
  — SHA-256 `14CA337A541222740667AEAC33AB48BC7391A898BE62649C81998AA6E0D9F7D4`.

Esse delta cobre a validação local do formulário. Persistência real,
autorização backend e E2E continuam submetidas aos bloqueios já registrados.
