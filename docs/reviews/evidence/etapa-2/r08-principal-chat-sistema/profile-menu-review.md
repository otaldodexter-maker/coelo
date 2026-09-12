---
fonte: C0; G3 ProfileSummary 1e0029e9e0a84e76a275da650d2eea538525573c
status: revisao-focal-concluida-fix-publicado
data_geracao: 2026-09-12
---

# Revisão G4 — alvo do menu do usuário no shell

C0 concedeu a G3 posse de superadmin_shell.dart e pediu revisão G4 sem runner.
Recorte: _ProfileSummary/InkWell, regressão dos diretórios de Perfis de cuidado
e Planos de medicação. Dois testes de guideline mediram242×44 e falharam;
G3 confirmou RED0PASS/2FAIL antes do patch. Não é aceite de CRUD.

O patch inspecionado envolve somente o conteúdo do InkWell com
ConstrainedBox(minHeight:CoeloSize.touchMin). Avatar continua36, padding
horizontal8/vertical4, Row centrado, borda e callbacks preservados. Não altera
perfil/identidade/papel ou navegação. O mínimo maior não reduz alvos vizinhos.

G4 apontou risco específico de ancoragem: o retângulo do trigger pode crescer
verticalmente embora avatar/texto permaneçam centrados. G3 executou os testes
existentes `keeps the compact profile menu subtly inset from the right edge`
e `opens the rounded profile menu below its trigger`:2PASS em
14-profile-menu-tests.log. Confere menu dentro da viewport375/768 e abaixo do
gatilho; não afirma igualdade pixel a pixel do popup aberto.

Nenhum achado concreto adicional. O hunk de formatter fora do recorte foi
removido por G3. A confirmação de pintura usa os goldens existentes, sem
rebaseline; G3 publicou8PASS/0FAIL (2guidelines reativados+4goldensCare+2menu), analyze0.
SHA1e0029e9e, nenhum PNG alterado. Não são oito testes novos nem aceite globalAA.
Nenhum arquivo do shell foi editado por G4 e nenhum Flutter/Chrome G4 executado.
