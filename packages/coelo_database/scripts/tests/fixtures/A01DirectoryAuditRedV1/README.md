---
source: git:d74a9bccdf70eabb8da2722fc27d420e5d0e05aa/packages/coelo_database/migrations/20260907222911_superadmin_activity_directory_v2_client_contract.sql
status: approved_historical_test_fixture
generated_at: 2026-09-08T02:52:59Z
---

# A01DirectoryAuditRed: fixture historica v1

Esta copia literal preserva o input v1 do replay historico RED55/97. O arquivo
mantem o nome e a versao originais; nao e uma migration adicional.

- Commit de evidencia: d74a9bccdf70eabb8da2722fc27d420e5d0e05aa.
- Blob Git v1: f9e3e99aea883c54a42aff7aae76a1ca96119e7b.
- SHA256 LF UTF-8: 6770c9bcbf5a3c3f6560021c0ca6e03d7bb1f12449878a2e98df64105cc04f92.
- SHA256 CRLF UTF-8 sem BOM: 77b248f6d60661ebf1fff941107b8fd148d9e2a19e9c27d1b4f45be01571847f.

O BeforeEach de A01DirectoryAuditRed.Tests.ps1 valida o hash v1 e copia este
arquivo somente para migrations dentro de TestDrive. O descriptor e o resolver
RED continuam fixados em v1 e rejeitam o input canonico v2 por hash.

O perfil A01DirectoryAuditGreen usa a v2 canonica do commit
96de811b8ce02333f302117e9ee8c4e7d5dc445d, blob
2472a89b61cd34e3be866d80b33a042f5456d6c8, SHA256 CRLF UTF-8
e72e11c5d0f8fd8d49bfe098a230530edb3d4070d80ca5b4ae04b61b72eb196f.
As duas versoes usam o timestamp 20260907222911; cada selecao contem apenas
uma delas e permanece com 53 migrations canonicas mais dois preflights.

Nenhum resolver de runtime consulta esta fixture. Um replay historico real
continua associado ao snapshot d74, enquanto os testes Pester preservam sua
reproducibilidade sem requerer novo replay SQL.
