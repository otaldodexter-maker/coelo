---
source: "D00 r23; LocationCatalogV2 bbeaafa0a; motor a37109bf; TAP f443901f+2a66709f"
status: "review-ready; static-pass; sql-not-executed"
generated_at: "2026-09-09"
---

# Perfil nominal LocationReservationsV1

Target20260909165000. Cadeia64SQL=59canônicos+2preflights+3fixtures locais:
LocationCatalogV2 preservado, cinco migrations canônicas Activities até audit14,
bootstrapOwner-only das três capabilities e motor. Additional contém seis
arquivos relativos ao pai, não uma allowlist aberta. Resolver ordena por nome,
valida target, hashes, contagem, arquivo regular/ancestrais sem reparse e pai.

Comparação independente confirmou que os cinco canônicos Activities não
alteram activity_locations, seus sete helpers legados ou ACLs exigidos por LOC01.
A execução no banco ainda é necessária para provar compatibilidade real.
Nenhum helper audit foi copiado ou inventado como bridge.

Hashes CRLF/UTF-8 sem BOM:

- Descriptor: `9e8fc9e80d8526274bbf6a7e968fe80bb958f2d020ab7fab2d1ad6ec6cddf6b5`.
- Resolver: `943435beeb6fd4fc12899be39128bbfb676e82b87544b3b0ba9b5beec11f1f5f`.
- Fixture164959: `111b6e00b3e897ca2d96a36d6192c8149f2cc3cfbd1498f76338f261b84bd6aa`.
- TestePester: `fa5404b8a6a9ebd476dbdbef18b0f1c38470f833bc309040310a69d7497425c0`.
- Motor: `3e8c1782b753b4fd8861b29e002db0741f1f1f02a0bee73f562ca77fe79f743e`.

Pester exclusivo: **6/6PASS**, resolver direto exit0. Root executou a cópia
de revisão do Prepare com PSScriptRoot apontado ao pacote D02, sem mudar
wrappers: materializou64arquivos, conferiu fixtures LOC imediatamente antes
do cutover, audit14 presente, fixture164959 na posição63 e motor na64,
Forms derivado com hash herdado. Diretório temporário próprio removido.
Isso é preparação estática, **SQL0executado**.

`location-reservations-wrapper-hunks.patch` acrescenta exclusivamente
allowlist/dispatch do perfil, branch nominal59/6/3 e reaproveitamento do conversor
Forms. Nenhuma exceção de concorrência/adições/Auth foi ampliada.
Apply-check na raiz D00 passou sem aplicar. Fontes dos wrappers normalizadas:
Prepare`f5bb9aa4d956cadc4a79d47a4e5cd2b86c48eab0270cc01c200331cefa6f6273`,
Invoke`76c94874a93277545f2100dcb4d75c0b6d8a6a0bcec285914904bbf52df6da01`.
Materializar patch com LF do blob, sem sobrescrever wrappers inteiros ou
normalizar arquivos SQL silenciosamente.

Comando a revisar e executar somente em janela nominal concedida por D00:

```powershell
./scripts/Invoke-SafeLocalMigrationReplay.ps1 -TargetVersion 20260909165000 -NominalProfile LocationReservationsV1 -TestPath 'supabase/tests/superadmin_location_reservations_v2_test.sql'
```

TAP49=29puros+20integração; inclui também a negativa sem justificativa dentro
do caso override. Parser final104statements. Sem prova concorrente do motor,
sem consumidor Event/Form, sem integração atômica com saveGroup/Activity,
sem mídia ou aplicação remota. Não promover locations.schedule pelo perfil.
