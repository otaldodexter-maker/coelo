---
source: "specs/009-media-r2-spike.md"
status: "draft"
generated_at: "2026-06-22"
---

# Media R2 Evidence Log

## Environment

| Field | Value |
| --- | --- |
| Environment kind | local disposable spike |
| Media used | synthetic file only |
| Product apps touched | no |
| Production infrastructure touched | no |
| Disposable R2 credentials available | no |

## Evidence

| ID | Scenario | Result | Evidence | Date |
| --- | --- | --- | --- | --- |
| EV-001 | Upload authorization design | blocked | missing disposable R2 credentials; design in media-gateway-technical-spec.md | 2026-06-22 |
| EV-002 | Read authorization design | blocked | missing disposable R2 credentials; design in media-gateway-technical-spec.md | 2026-06-22 |
| EV-003 | Cross-tenant denial design | designed | media-gateway-technical-spec.md | 2026-06-22 |
| EV-004 | Expired URL behavior | blocked | missing disposable R2 credentials; design in media-gateway-technical-spec.md | 2026-06-22 |
| EV-005 | Orphan cleanup strategy | designed | media-gateway-technical-spec.md | 2026-06-22 |
| EV-006 | Secret scan | passed | tracked secret scan returned no matches; npm syntax check passed | 2026-06-22 |
| EV-007 | Upload autorizado (R2-T001) | passed | `packages/coelo_database/scripts/r2-spike-synthetic.ts` contra `coelo-transient-prod` real, PUT assinado HTTP 200, objeto sintético `spike/synthetic/<uuid>/evidence.txt` | 2026-09-10 |
| EV-008 | MIME divergente (R2-T002) | passed | PUT com `content-type` diferente do assinado → HTTP 403 | 2026-09-10 |
| EV-009 | Metadados conferem (R2-T003) | passed | HEAD devolve 37 bytes e `text/plain` | 2026-09-10 |
| EV-010 | Leitura autorizada (R2-T004) | passed | GET assinado HTTP 200, 37 bytes | 2026-09-10 |
| EV-011 | URL expirada (R2-T007) | passed | GET após 1 s de validade → HTTP 403 | 2026-09-10 |
| EV-012 | Limpeza do objeto sintético | passed | DELETE assinado; HEAD seguinte falha | 2026-09-10 |
| EV-013 | CORS restrito | applied | regra `coelo-apps-signed-put-get` nos três buckets (origens `superadmin`/`admin`/`app.coelo.me`, GET/PUT/HEAD) via API da conta em 10/09 14:35 | 2026-09-10 |
| EV-014 | Órfãos (R2-T008) | applied | lifecycle `coelo-transient-expire-7d` em `coelo-transient-prod` mais limpeza de pendentes/órfãos no catálogo (`circulars_media_private_r2_v1`, 30 min) | 2026-09-10 |
| EV-015 | Cross-tenant e membership revogada (R2-T005/T006) | provado no gateway | negativa fica nas RPCs `prepare_*`/`authorize_*` das Edge Functions e nos pgTAP (`circulars_media_private_r2_v1_test`, `forms_superadmin_media_read_r2_v1_test` 82/82, `private_media_catalog_r2_v1_test` 44/44 sobre a baseline); o R2 nunca decide autorização | 2026-09-10 |
| EV-016 | Secret scan após o token real | passed | `git grep` de chaves/assinaturas sem ocorrência; o token vive só nos secrets das Edge Functions | 2026-09-10 |

Ambiente de 10/09/2026: produção real (`coelo-transient-prod`), credencial
`coelo-edge-functions-r2` de escopo mínimo criada pelo Owner e gravada nos
secrets; `circular-media` implantada com o ramo R2. `happens-media`,
`now-media` e `moments-media` seguem sem implantação até as migrations que
apontam o `storage_provider` para R2 entrarem (grupo principal-chat-sistema).

## Verification Commands

```powershell
Test-Path -LiteralPath 'spikes\media-r2\.env'
git grep -n -E "X-Amz-Signature|sk-[A-Za-z0-9_-]{20,}|github_pat_|ghp_|SUPABASE_SERVICE_ROLE_KEY=.{12,}|R2_SECRET_ACCESS_KEY=.{24,}" -- ':!docs/**' ':!specs/**' ':!decisions/**' ':!spikes/media-r2/.env.example'
npm.cmd run check
```

Results:

- `.env` check returned `False`.
- Secret scan returned no matches.
- `npm.cmd run check` completed successfully.

## Decision Input

The ADR can move from proposed to accepted only if EV-001 through EV-006 are passing or have documented mitigations accepted by the project owner.
