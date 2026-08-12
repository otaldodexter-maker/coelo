---
source: "specs/027-superadmin-audit-production.md; decisions/0020-backend-authorization-application-security.md; decisions/0021-operational-import-export-files.md"
status: "implementation-evidence"
generated_at: "2026-08-12"
---

# Evidência de segurança — Auditoria produtiva do Superadmin

## Superfícies e autorização

- `audit.audit_logs` permanece fora dos schemas expostos na Data API, com RLS forçada, sem policy de leitura direta e sem grants para `anon`/`authenticated`.
- Lista e detalhe passam por RPCs `SECURITY DEFINER` com `search_path` vazio, grants mínimos e revalidação de pessoa, vínculo, capability e escopo institucional.
- `audit.read` e `audit.export` são capabilities separadas. Export exige AAL2 no pedido e é reautorizado pelo worker antes de materializar o snapshot.
- Evento inexistente e evento fora do escopo retornam o mesmo `null` no detalhe. Lista e export filtram pelo conjunto de instituições autorizado, materializado uma vez por operação.

## Integridade e minimização

- UPDATE e DELETE falham no trigger append-only, inclusive para caminhos server-side usuais.
- Cada INSERT recebe posição alocada somente depois do advisory lock, hash SHA-256 e vínculo ao hash anterior. Valores de posição enviados pelo chamador são ignorados.
- Registros legados são sanitizados em repouso antes do recálculo da cadeia. Todo INSERT é minimizado pelo trigger e recebe `payload_contract_version = 1`, independentemente do valor enviado pelo chamador.
- Lista nunca retorna `before`/`after`. Detalhe aplica allowlist server-side; motivos livres são redigidos e somente códigos de motivo allowlisted permanecem.
- A verificação de integridade exige o hash do predecessor imediatamente anterior, além do digest do próprio registro.

## Export operacional

- O job idempotente usa `public.import_jobs`; limite de cinco pedidos por ator/hora é serializado por advisory lock do ator.
- O worker cria snapshot privado na interseção dos escopos atuais de `audit.read` e `audit.export`, limita 50 mil linhas/5 MiB, neutraliza fórmulas em CSV e XLSX e gera XLSX real via SheetJS. O artefato contém nomes/identificadores necessários e é classificado corretamente como PII.
- Claim atômico com token e lease impede dois workers de processarem o mesmo job; paginação, conclusão e falha exigem o claim, e falha tardia nunca rebaixa estado terminal.
- Artefatos usam caminho server-side `exports/audit/<job>/<uuid>.<formato>` no bucket privado `coelo-operations`, checksum SHA-256, retenção operacional de 24 horas e URL assinada por 300 segundos. Generate/status executam limpeza oportunística limitada e removem fisicamente o próprio artefato expirado; o job é então apagado em cascata com arquivo, snapshot PII e claim, tornando o estado expirado um `not-found` consistente, não um erro genérico.
- RPCs de worker são exclusivas de `service_role` por grant e também validam o claim server-side. Status, replay, conclusão e download revalidam ownership, AAL2 e cada linha do snapshot contra os escopos atuais de read/export. Toda URL assinada passa por uma única função Edge que chama a autorização user-owned imediatamente antes da assinatura.

## Verificação executada

- `npx -y deno test --allow-read artifact_test.ts`: 3 testes passaram (formula injection, XLSX real e gate único de URL assinada após autorização user-owned).
- `npx -y deno check index.ts`: passou sem erros.
- `supabase/tests/audit_production_test.sql`: 78 asserções pgTAP cobrem grants, append-only, sanitização em repouso, cadeia imediata, inputs hostis, ator histórico sem papel confiável, escopo institucional/unidade/turma/criança, deny específico, cursor cross-scope, reautorização e claim do worker, download após redução de escopo, expiração em cascata, rate limit, idempotência e retenção.
- `npx supabase --version`: CLI 2.113.0.
- `npx supabase status --workdir packages/coelo_database`: bloqueado porque Docker/Podman não está instalado no ambiente.
- `npx supabase test db --local ...` e `npx supabase db lint --local`: bloqueados com `ECONNREFUSED 127.0.0.1:54322` porque o runtime local não iniciou sem Docker/Podman.
- Consequentemente, pgTAP real, migration reset, EXPLAIN e Database Advisors não foram executados nesta estação. O teste `supabase/tests/audit_production_test.sql` fica como gate obrigatório em ambiente com runtime de containers antes de aplicar remotamente.

Os índices de cursor por instituição e ator foram adicionados. A confirmação por `EXPLAIN (ANALYZE, BUFFERS)` permanece no mesmo gate bloqueado pelo runtime local. A contagem exata foi preservada para o contrato de paginação.

Não há rotina de purge da trilha de auditoria: a retenção dos logs permanece indefinida até decisão jurídica. A expiração de 24 horas aplica-se somente ao arquivo operacional exportado, conforme ADR 0021. Uma limpeza oportunística limitada existe; um scheduler/lifecycle global continua pendente porque não é seguro inventar implantação ou segredo neste ambiente.
