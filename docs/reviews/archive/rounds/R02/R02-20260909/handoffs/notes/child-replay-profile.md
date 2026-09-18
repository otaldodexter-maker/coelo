---
title: "D03 — perfil local ChildDirectoryEnvelope"
source: "assignment D00 r5; candidato 2173cbd0; Auth45; fonte canônica 20260827235500; evidências Pester deste turno"
status: "local-structure-verified-awaiting-d00-sha-review-and-sql-slot"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

Etapa 2 → apps/superadmin → Acompanhamento → Alunos / lista → students.list.
O perfil nominal materializa 49 SQL: 46 migrations canônicas (Auth45 + CHILD),
uma ponte local de envelope e os dois preflights herdados. A ponte vive somente
em replay/profiles/ChildDirectoryEnvelope; não é migration de produção.

Os três arquivos originais CHILD foram recuperados sem alteração em
14def90d3d2f7adbaf7289406183d3982a4580bf, com origem2173cbd0. A migration
continua fixada no SHA256 CRLF/UTF8
de1efeb5c3088560efaa02894ff58fa8e019cd0116271adf013f4d9923e92572.
Não foi trocado nenhum pin do preflight.

O resolver fixa descriptor, manifesto, target20260908051500, quantidade,
hashes, origem da ponte e ordem antes de CHILD. Rejeita alteração de bytes,
versão canônica em colisão e reparse nos caminhos. Os runners só recebem os
hunks de allowlist/dispatch/materialização autorizados; mutex, CLI, identidade,
marcador, cleanup e contagem global de dois preflights foram preservados.

Provas estruturais atuais, sem Docker ou SQL de produto:

- ChildDirectoryEnvelope.Tests.ps1: P10/F0/B0/S0/U0. Inclui materialização49,
  dispatch de Invoke até sentinel antes do mutex/Docker, target, seis variantes
  de drift, colisão de versão e reparse. XML
  C:/Users/adrie/AppData/Local/Temp/d03-child-directory-envelope-tests.xml,
  09/09 13:35:22, duração25.1676s, lido pelo parent.
- Prepare-SafeMigrationReplay.Tests.ps1 e
  Invoke-SafeLocalMigrationReplay.AgentMode.Tests.ps1: P6/F0/B0/S0/U0. XML
  C:/Users/adrie/AppData/Local/Temp/d03-runner-regression.xml. São testes de
  infraestrutura, não seis casos adicionais de CHILD.
- Verificação focal manual de casing do parâmetro aceito pelo ValidateSet:
  `childdirectoryenvelope` mantém49 SQL e uma ponte. Guard usa comparação
  case-insensitive consistente com ValidateSet/switch. O wrapper temporário
  encontrou erro de array no seu cleanup após o PASS; cleanup nominal corrigido
  removeu o único diretório próprio observado. Não era defeito do runner nem
  SQL; nenhum recurso residual desse caso. Não se repetiu o lote Pester.

Revisão independente do subagente students não encontrou novo bloqueante no
candidato/ponte para replay local. O TAP original possui35 assertivas e ainda
não foi executado nesta rodada. O gate estático original15 já passou; ambos são
provas distintas. A revisão identificou lacunas de cobertura de ACL pós-DDL,
adult/service, acentos, controle inválido de saída, concorrência real e reload.
O parent prepara complemento focal do TAP em commit separado; concorrência
exige plano/recurso nominal adicional, ainda não executado.

O replay FoundationOnly anterior falhou numa dependência de Chat antes de
CHILD e não será repetido. Este perfil precisa revisão do SHA concreto por
D00 e liberação da janela local após D02. Nenhum replay nominal CHILD, deploy
ou alteração de helper remoto foi realizado. Metadados e consumidores remotos
consultados somente leitura constam em backend-gates.md.

Complemento focal do TAP preparado após o perfil: dez assertivas novas,
total planejado45. Quatro de ACL efetiva/metadados (inclui ausência de grant
option a authenticated), duas de exclusão adult/service, duas de paginação
com acentos em C-order e duas de saída inválida C0/DEL sem dados parciais.
Fixtures restauradas antes dos casos de auditoria/revogação. Revisão
independente confirmou enums/constraints/contagens/restauros; a lacuna de
grant option/prokind/linguagem/retorno apontada foi corrigida no teste.
Gate estático15 revalidado após o complemento, PASS; não somar à execução
anterior. Nenhuma assertiva SQL das45 foi executada ainda, nem concorrência.

Corrigenda da causa Foundation recebida de D00 r7: audit14 estava presente;
a dependência ausente era chat_attachment_metadata, pois20260812000000 não
integra o manifesto. A falha anterior era mensagem genérica, não prova de
ausência de audit14. O perfil falho não será repetido.

## Primeiro replay nominal — resultado parcial e fixture corrigida

D00 r8 autorizou o perfil 9551be50 com TAP 5e21e132. TestPath absoluto
confirmado; TAP D03/D00 idênticos após CRLF→LF apenas. Hash normalizado CRLF
UTF8 AB757635C0DEB9F1FA9DBAE39A9523CC1ED888FC224984410292F4457B19450F.
Exec session64297 em 09/09 14:05–14:07 BRT, recurso próprio
supabase_db_coelo_safe_42818dc7073d43168455afcae071d.

As 49 migrations foram aplicadas, incluindo ponte e CHILD. O TAP aprovou
21 assertivas e parou no UPDATE sintético de revogação de membership:
`internal membership version mismatch`, linha121, guard Auth039. A fixture
histórica omitia o incremento obrigatório de version. Resultado de execução
exit1/no plan, sem assertiva CHILD falha e sem GREEN do lote.
Plano45: P21/F0/B24/S0/U0; as24 bloqueadas não foram alcançadas. Log stdout:
C:/Users/adrie/AppData/Local/Temp/d03-child-envelope-replay.log, SHA256
78E1322A9A5E00D3FF2197BDE62101C2F6C2CF3DA14A6DBA1E20AFD0520BF055.
O erro PostgreSQL detalhado está no transcript da session64297; o log stdout
registra21 PASS e encerramento sem plano, não contém todo stderr nativo.

Correção mínima no TAP: incrementar `version=version+1` ao revogar a membership
sintética. O guard, a migration e o perfil ficam intactos. A correção ainda
não foi reexecutada em SQL; exige nova janela coordenada após D02. Não somar
as21 provas parciais a um eventual rerun das mesmas assertivas.

Cleanup confirmado por consultas de container/volume/rede da identidade
própria e ausência do diretório temporário. Slot liberado a D02 às14:07 BRT.
Docker Desktop estava desligado e foi iniciado com janela oculta para a prova;
permanece disponível para outras frentes, sem banco D03 residual.

Conclusão FE/BE/E2E students.list permanece0/1 em cada camada. Memória de
produto: no-op; este documento preserva evidência operacional da rodada.
