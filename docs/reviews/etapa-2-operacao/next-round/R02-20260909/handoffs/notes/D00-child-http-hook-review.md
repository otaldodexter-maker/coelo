---
source: "D00 delegated review; f43b2cf13effdf0a41196e316472ae56c9f99a34; 6a4c8bb9ceafaada2cf3df17815d37c813b6ee5e"
status: "offline-patch-reviewed-not-applied-no-sql-executed"
generated_at: "2026-09-09"
---

# CHILD HTTP: hook proposto e prova offline

Recorte: apps/superadmin -> Acompanhamento -> Alunos -> listagem -> students.list.
O patch adiciona somente RunChildDirectoryHttp, guard nominal exclusivo, TAP CHILD
unico, selecao dos servicos HTTP existentes e dispatch apos TAP. Nao habilita
RunAuthLifecycle, concorrencia, outro perfil, additions ou recursos remotos.

Diretorio TEMP real: C:/Users/adrie/AppData/Local/Temp/d00-child-http-review-9qh39z26/.

| Artefato | SHA256 raw |
| --- | --- |
| child-http-invoke.patch | 0B366A32DEF05F24D8AA878AA868B593BBE2C61BA0E2DC4F9FCB49CAEECF35FD |
| source.ps1 (copia LF) | 76C94874A93277545F2100DCB4D75C0B6D8A6A0BCEC285914904BBF52DF6DA01 |
| candidate.ps1 (copia LF) | 9C7F2F73EE488F0D931866A018B378EFF91C6A77D9E3D9C43CC1B08F5212BCA5 |
| red-final.log | 599E5A17B22A219C4B9794D5770A003F171AD32F28AF1F596BC83FFF1C1FCFD5 |
| green-final.log | ED9BD46AEDE5BC4DFD7FB142C28E9540475B3880923B11FAC3EAE676E97030F8 |

Teste exclusivo: packages/coelo_database/scripts/tests/ChildDirectoryHttpRunner.Tests.ps1,
parametro RunnerPath obrigatorio. Executa guards reais truncando antes do mutex;
substitui somente scriptRoot pela origem canonica, sem Docker/portas/escrita de projeto.
RED final: P0/F4; GREEN final: P4/F0/B0/S0/U0. Quatro IDs novos de infraestrutura,
nenhum credito HTTP/FE/BE/E2E. O primeiro green.log preserva P3/F1 causado pelo
seletor de teste que omitia else; teste corrigido e ambos lados rerodados.
Todos os logs foram capturados desde inicio, sem reconstruir output.

git apply --check do patch final passou na raiz. O primeiro patch LF exigia
ignore-space-change; o artefato final preserva EOL original nos contextos e passou
sem essa opcao. O wrapper raiz e index nao foram alterados por esta tarefa.

# Proposta nominal da composicao atomica

Nao criar perfil agora. Proximo gate proposto exclusivo:
packages/coelo_database/replay/profiles/ChildDirectoryAtomicPackageLocal/profile.json,
Resolve-ChildDirectoryAtomicPackageLocal.ps1 no mesmo diretorio, fixture exclusiva
packages/coelo_database/tests/fixtures/child_atomic_old_envelope_local.sql e harness
packages/coelo_database/scripts/Test-ChildDirectoryAtomicPackage.ps1.
Esses caminhos sao proposta de reserva, nao arquivos criados nem autorizacao SQL.

A selecao deve derivar a cadeia ChildDirectoryEnvelope ate imediatamente antes
do reader20260908051500, sem aplicar a ponte nova antecipadamente. A fixture local
opt-in materializara apenas o corpo antigo exato do envelope, apos conferir a
proveniencia e metadata. O pacote remoto integral deve ser aplicado uma vez sobre
essa base pre-reader, com ON_ERROR_STOP; o preflight exige ausencia do gateway.
Executar novamente sobre o reader instalado seria teste incorreto, nao idempotencia.

Provas focais propostas: sucesso atomico com catalogo/ACL/corpos esperados; falha
deliberada no preflight CHILD apos troca do helper, comprovando rollback do helper
e ausencia do gateway. Estado negativo em projeto/transaction isolado e nominal.
Reutilizar 45 TAP + 3 concorrencia dos corpos existentes; nao repetir por contagem.
O DO final adicional do pacote ainda nao foi executado.

Pacote6a4c8bb9: 22264bytes, SHA2561193649F37C15EAA964A7486B83014806BC76C70AB4BD04537908CB57EE198E6.
Comparacao offline confirmou ambas regioes iguais as fontes LF sem wrappers e
um BEGIN/COMMIT. ACL final rejeita grants adicionais e pins/metadados permanecem.
Antes de qualquer proposta de execucao remota, fechar transporte nominal,
identidade/versionamento no ledger supabase_migrations.schema_migrations e
procedimento NOTIFY/cache PostgREST. O arquivo em notes nao fornece esses passos.
Nenhum remoto, SQL, Docker ou aplicacao do pacote foi realizado nesta revisao.
