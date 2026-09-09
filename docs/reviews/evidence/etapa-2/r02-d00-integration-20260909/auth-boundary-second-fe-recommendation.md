---
source: "auth-boundary-second-replay.log; manifest-auth-boundary-second-integrated.json; coelo_auth_recovery_cold_reload_test.dart"
status: "recommendation-for-D00-focal-FE-acceptance"
generated_at: "2026-09-09"
---

O gate cold cobre explicitamente a reabertura da rota `/reset-password`: descarta SDK/scope, recria ambos com credencial recovery retida após purge permanentemente falho, monta SuperadminApp e navega para a rota. Exige uma chamada real de bootstrap, ausência de autenticação/contexto produtivo, permanência na rota, negativa SAI_SESSION_INVALID, logout confirmado e sessão SDK vazia, mesmo com a credencial ainda no storage.

O log contém PASS do gate composto. O hook só o emite após child exit 0 e marcador fixo produzido depois dessas asserções. Os nove gates HTTP e 36 TAP também passaram na mesma base local corrigida.

Recomendação: D00 pode fechar o gate focal FE de reabertura segura após falha persistente de purge usando esta composição e as provas FE anteriores válidas. Não promover automaticamente toda a ação auth.reset: revisar os demais aceites e preservar os gates de browser/produção que exigem evidência própria.

Limite: é reinicialização de SDK/scope em teste Flutter com SharedPreferences simulado e transporte/backend local reais. Não é reinício de processo do app nem reload observado no navegador. Nenhuma certificação BE remota ou E2E produtiva decorre desta prova; nada foi alterado nos rastreadores por esta recomendação.
