---
title: "LOC-REMOTE-SNAPSHOT01 — fechamento mínimo candidato"
source: "diagnóstico25cd74a9; snapshot remoto autorizado2026-09-08T05:28:22Z; reserva da coordenação; LOC6b0cbb30; review E5 somente leitura"
status: "candidate-static-only-final-review-pending-replay-not-executed"
generated_at: "2026-09-08"
---

# Recorte e resultado preparado

Corrigido somente o preflight de EOL do writer#6 e o padrão de fechamento
locations do helper#4 no candidato31000. Nenhuma execução SQL mutante local
ou remota, mudança em CHILD78e ou migration histórica. Três suítesLOC anteriores
e os bootstraps originais permanecem intactos.

## Delta no candidato

- #4 preserva pin remoto raw65fe6408f0f2c6b0c1c9d71a809f2d80. Padrão explícito
  do bloco locations remoto com ORNULL, pontos escapados e sem wildcard amplo;
  substituição continua somente `'locations','[]'::jsonb`. Gate exatamente1
  e pós-condição sem referência ao catálogo permanecem. Valida owner postgres,
  SECURITY DEFINER, stable e search_path vazio explicitamente. Compara prefixo/
  sufixo intactos e pin da definição de saída, antes e depois de CREATE OR REPLACE:
  raw `2486e539f723d3f61cd9f29984efcbb2` (LF diagnóstico
  `7462bb50ad167d5600713d9913dd8b17`).
- #6 é a única assinatura autorizada a comparar CRLF→LF contra
  3167d90039df952c9ae561f28486223c. Evidência remota/canônica confirmou corpo
  LF idêntico e metadata equivalente. Owner postgres também conferido nesse
  ramo; ACL continua exata. Sem trim/remoção de espaços ou hashes alternativos.
- Demais seis fingerprints continuam raw. Não mudou ORNULL de units/groups/
  professionals, não restaurou students e não mudou wrappers/grants/projeções
  fora de locations. Novos gatewaysLOC não usam esse helper para autorizar.

## Snapshot local nominal, não instalação remota

Fonte preparada:
`packages/coelo_database/tests/fixtures/location_form_options_remote_snapshot_local.sql`.
Contém a definição remota exata consultada, JSON-escaped para preservar bytes
mistos de EOL. Não há reconstrução manual de função ou acesso a registros.
O texto é código SQL de catálogo revisado, não dados de pessoas; o snapshot
bruto aparece aqui exclusivamente como fixture técnica autorizada, diferentemente
do relatório diagnóstico sanitizado25cd74a9. Nenhuma credencial incorporada.

O arquivo não está em migrations nem automaticamente incluído no harness.
Exige postgres e opt-in externo, dentro da mesma transação:
`coelo.local_replay=location-catalog-v2-remote-options-snapshot`.
Não autoconcede o opt-in. Preflight exige #4Auth47 raw70700ddc38d42df4fae75765b7ff2617
e LFb951e603ef34b7d26597356a16eb6d06, owner/SD/stable/config/ACL privados.
Antes de executar o snapshot, verifica seus hashes de definição raw65fe/LF516a.
Após, exige definição raw65fe, prosrc raw1f40c83ab7cbd772a9983a5e61138eb0,
prosrc LF08697eaa5c84dc2938b0c1ffaf6de056 e metadata/ACL preservados.
Qualquer diferença aborta a transação. Não muda privileges nem outros helpers.

## Provas locais obtidas

Guard `scripts/tests/Test-LocationRemoteSnapshot.Tests.ps1`:

- RED antes do patch e contra revisão exata6b0cbb30: remote pattern match0.
- Candidato corrigido: remote1/canonical0, sem wildcard amplo.
- JSON snapshot decodifica para bytes de MD5raw65fe/LF516a observados.
- Comparação após substituição comprova bytes restantes idênticos, demais ORs
  presentes, sem students ou referência public.activity_locations.
- Corpo canônico writer normalizado tem MD5ccfc509321ae6d21eafb4082c4e53e58,
  igual ao prosrcLF remoto; espaço extra não é aceito como EOL.
- Snapshot/padrão da nova suíteTAP são idênticos aos da fixture/candidato.
- Normalização é limitada à assinatura exata#6; o ramo restante usa hashraw.
- Guard adicional RED sem output pin → PASS com pin e metadata explícitos.

Esses checks são PowerShell/.NET, com tradução de POSIX-space para whitespace
no teste de expressão; **não são execução do regex PostgreSQL**.
Também passaram os17 guardsLOC existentes e15 guardsCHILD+pins, sem editarCHILD.

Preparada nova suíte
`supabase/tests/superadmin_location_remote_options_cutover_test.sql`, com
**18 assertions pgTAP não executadas**: snapshot raw, REDpatternoriginal0,
patterncorrigido1, canônico0, predicado adulterado0, duplicação2, definição
final exatamente igual ao snapshot menos locations, sem descoberta, sem students,
demais filtros preservados e metadata/ACL. Diagnóstico de definição executa no
search_pathpublic/pg_catalog; TAP tem extensions no path e roda como postgres.
Sete assertions adicionais comparam dados elegíveis equivalentes em duas
instituições, filtro NULL/A/B, antes e depois: unidades, grupos, profissionais e
locais são não vazios antes; todas as projeções não-location permanecem iguais;
locations fica vazio; a chave students continua AUSENTE, não restaurada como [].
Um Owner legado real, pessoa/auth/link/membership sintéticos, chama o wrapper
público como authenticated, sem mock de autorização ou novos grants de negócio.
Somente no teste transacional rollback, o corpo remoto integral é reinstalado
para capturar before e o corpo pós-cutover exato é restaurado para after. O hash
final comprova a restauração. Não representa migração de auth nem E2E interno.
Nomes sintéticos incluem ordinal para evitar empates de ordenação JSON.

Duas revisões independentes, incluindo recorteE5, não identificaram P1/P2 na
versão inicial. Re-review dos guards e fixture comportamental em andamento;
ambas somente leitura. Parsing/migrations/TAP/concorrência e
regressão real continuam pendentes. Gates de memória e diff/segredos executados
no fechamento; não promover estado para local-green ou E2E.

## Reserva proposta ao Eng1

Perfil anteriorLOC50 deve ser repinado; não reutilizar seu gate por inferência.
Composição proposta51 entradas:45canônicasAuth + envelope + candidato =47,
dois preflights herdados, um snapshot#4 e um bootstrap de capabilities.

Ordem dos efeitos: Auth+envelope → snapshot#4 com opt-in próprio → bootstrap
de capabilities com seu opt-in `location-catalog-v2` → candidato31000 → três
suítesLOC originais e nova suítecutover18. Os dois opt-ins são distintos.
Eng1 reserva a versão/posição nominal da derivação local do snapshot antes
de30959/31000. Se injetar SETLOCAL após BEGIN, registrar source/derived hashes
e provar que não mudou o JSON snapshot; não reescrever Base/canônicos.

Ordem factual dos gates no candidato6b: Auth47 falha primeiro no fingerprint#4;
com snapshot#4 instalado, o raw fingerprint#6 ainda falha antes de chegar ao
regex#4. Só após o ajuste nominal de EOL#6 o fechamento antigo#4 alcançaria
regex0. As contraprovas do guard estático e da suíteTAP isolam esse regex; não
se afirma que uma falha runtime tenha executado/provado todos os gates seguintes.
Eng1 deve conservar as evidências separadas e executar o candidato corrigido
somente após review e repin nominal. Somente o operador autorizado pode
declarar resultados de catálogo, identidade, ledger e cleanup. Nenhum passo
deste pacote autoriza alterar produção, ampliar outras opções ou restaurar
PII infantil. Produto foraLOC continua exigindo decisão/pacote separados.

Memória: fonte candidata atualizada primeiro; sem nova regra de produto para
projeção de usuários. Rastreadores centrais permanecem com a coordenação.
