---
source: "D00 r23/r24/r26; LocationCatalogV2 21b0d9bbe; motor sucessor r24; TAP49"
status: "candidate-r24-fixed; static-pass; causal-sql-not-executed"
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

- Descriptor: `611fde347e1324b90c9d8af438ef062f2ec19aa25e74e330d0e11caec1401f85`.
- Resolver: `878d566ebbfc09c93331ae24ca9f486c95d16f970d6304aca5f19ea143d2d15c`.
- Fixture164959: `111b6e00b3e897ca2d96a36d6192c8149f2cc3cfbd1498f76338f261b84bd6aa`.
- TestePester: `fa5404b8a6a9ebd476dbdbef18b0f1c38470f833bc309040310a69d7497425c0`.
- Motor: `307cce229fea0314400f827efeff089c4ea0ed254bb22edcf79fdd6a32652b84`.

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

## Sucessor r24 — 15:46 BRT

Auditorias de sucesso agora participam da mesma subtransacao da reserva e
receipt. Apos todos os appends, revalida identidade/sessao, proprietario,
consumidor e override para create e assess confirmavel; clock final detecta
expiracao durante espera. Qualquer negativa reverte tambem auditoria de sucesso.
Auditoria de negativa recebe instituicao resolvida/autorizada, nunca LocalUUID.
Override grava reason_code nominal RESERVATION_CONFLICT_OVERRIDE, referencia
da reserva e estado minimizado; justificativa livre permanece somente na reserva.
TAP existente foi ajustado sem mudar plan49. Parser migration/TAP aceitou;
nao e execucao de funcao nem pgTAP.

Pai atualizado para a correcao central21b0d9bbe, recebida nesta branch como
624669525: fixture EOL comprovada, metadados/ACL e pinLF preservados.
Descriptor pai c46f836935e8f77125bca34f3ef643f4eeb477a9c4fb327479d43519e5da850b;
resolver pai23bc78dc67ba09c2c75f4ab8b131032db9f17b264d32c8278b2804567c9f3542.
Pester6/6 revalidado e materializacao64/Forms novamente PASS por alteracao
material dos pins; nao somar aos seis casos anteriores.

Prova causal com lock real na auditoria continua nao executada, harness
solicitado nominalmente ao D00. Revisao identificou risco residual de corrida
de exclusao da instituicao apos rollback liberar lock interno: auditoria de
negativa pode falhar por FK e RPC abortar. Nenhum efeito de sucesso persiste;
nao foi introduzido catch que esconda falha de integridade de auditoria.
