---
source: R12 C0 — R12-14 child-safety.child relationship labels
status: local-green; E2E pending
generated_at: 2026-09-13
---

# R12-14 — relação localizada

Recorte: Etapa 2 → `apps/superadmin` → Segurança da criança → Criança →
Autorizações → `child-safety.child`.

Valores de domínio como `mother`, `father`, `grandparent` e `other` agora são
convertidos somente na apresentação para `Mãe`, `Pai`, `Avó/Avô` e `Outro`.
Valores desconhecidos permanecem intactos como fallback; enums e persistência
não foram traduzidos no banco.

Prova local, Windows, checkout `dev`:

- regressão `relationship codes are localized in authorization cards`: 1 PASS;
- `flutter test test/features/safety/presentation/safety_pages_test.dart` foi
  executado no mesmo recorte; a única falha é o golden 1440px já documentado
  em R12-10.

Nenhum contrato, SQL, RPC ou RLS foi alterado. O aceite FE é local-green;
rota normal, locale suportado, reload e escopo permanecem pendentes de prova
integrada.

Próximo gate: confirmar o idioma suportado pela aplicação e provar os rótulos
na rota normal com dados autorizados.
