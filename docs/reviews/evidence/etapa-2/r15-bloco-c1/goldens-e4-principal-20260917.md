---
title: "R15 Bloco C1 — regravação de goldens E4 (cabeçalho global) das suítes do Principal"
source: "ADR 0042 E4 (regravar suítes cujo isolatedDiff mostre só o cabeçalho, uma a uma, com registro); ADR 0041 C1; R15-handoff-bloco-c1.md"
status: "verified"
lifecycle: "current"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
audience: "team"
---

# Goldens E4 — `principal_for_you_preview_golden_test` e `principal_profile_preview_golden_test`

Worktree `r15-bloco-c1` (base `57162cee4`, já com as fatias E3/B9/Momentos); as duas suítes
falhavam na base antes de qualquer mudança desta sessão (worktree descartável em `57162cee4`,
registrado no handoff C1). Método: rodar as suítes, medir a caixa envolvente dos pixels
não transparentes de cada `*_isolatedDiff.png` (PIL) e regravar **só** as suítes cujo diff
está inteiro no canto superior direito do cabeçalho do Principal (iniciais do avatar).

## Diff isolado por caso (antes da regravação)

| Suíte | Casos | Caixa do diff (px, ×DPR) | Região |
|---|---|---|---|
| `principal_for_you_preview_golden_test` | light/dark × 375/768/1024/1440, `text_200_light_375`, `text_200_light_768`, `text_200_dark_1440`, `shortcut_hover_light_1440` (12) | `(322,25)-(351,38)` em 375; `(715,25)-(744,38)` em 768; `(971,25)-(1000,38)` em 1024; `(1387,25)-(1416,38)` em 1440 | só as iniciais do avatar (29×13 px) no cabeçalho |
| idem | `context_open_light_768` (DPR 3, 2304×3072) | `(2146,75)-(2230,114)` = `(715,25)-(743,38)` em 1× | cabeçalho |
| `principal_profile_preview_golden_test` | light/dark × 375/768/1024/1440, `editorial_light_375`, `moments_dark_1440`, `text_200_light_375`, `text_200_dark_1440` (12) | mesmas caixas por largura | cabeçalho |
| `notice_directory_golden_test` | 14 casos (`communication_directory_*`) | `(252,21)-(472,72)`, `(352,37)-(572,88)`, `(16,69)-(236,120)`; `text_200`: página inteira | **não é cabeçalho** — é o rótulo do filtro "Estado" (dropdown) e, em `text_200`, o layout inteiro; **não regravada** |

## Regravação

- `flutter test --update-goldens` nas duas suítes do Principal (25 referências) e nova execução
  sem `--update-goldens`: 25/25 verdes. Nenhum código de produção alterado.
- `notice_directory_golden_test` permanece como está: o diff não é de cabeçalho (E4 não cobre);
  fica registrado para quem cuida de Comunicações decidir (mudança de texto do filtro "Estado"
  em `v4_22`).
