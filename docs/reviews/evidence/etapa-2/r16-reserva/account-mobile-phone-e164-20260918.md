---
source: "Sessão RESERVA da R16 (Opus 5, coelo-8d), 18/09/2026; R16-prompt-reserva-20260918.md (Bloco 3, D5, lote 82 item b); owner.r12-46; dívida celular-mascara (ADR 0044); r15-bloco-a/account-profile-20260917.md"
status: evidence
lifecycle: current
generated_at: 2026-09-18
owner_items: "owner.r12-46 (parte Celular)"
action_ids: "account.profile"
---

# Conta › Celular em E.164 com máscara brasileira — prova na rota real (18/09/2026)

## 1. Contrato (D5 = E.164 + máscara)

- **Servidor** (`20260918130000_account_profile_mobile_phone_e164_v1`, lote 82 item b, 14:45:25 UTC):
  `app_private.normalize_mobile_phone_e164(text)` (pura, imutável, sem grants) aceita dígitos com ou sem máscara, com ou
  sem `+55`/`55`, e devolve `+55DDD9NNNNNNNN` (DDD 11–99 sem zero, nove dígitos iniciados por 9) ou NULL;
  `superadmin_account_profile_save_v2` (mesma assinatura e grants) grava o valor normalizado e responde
  **22023 `invalid_account_mobile_phone`** (`detail ACCOUNT_MOBILE_PHONE_E164_REQUIRED`) quando inválido — código da
  família, nunca 40001; a regra antiga "7 a 40 caracteres" cai. pgTAP `account_profile_mobile_phone_e164_v1_test`
  **22/22** no espelho fiel; `r14_account_self_reader_test` 6/6; `account_profile_service_person_email_v1_test` 3/3;
  `superadmin_account_profile_v1_test` 13/16 (9–11 são grants de tabela do espelho, pré-existentes e alheios).
- **Cliente** (`apps/superadmin`, commit `0d02b00a1`): campo Celular com `CoeloBrazilianPhoneInputFormatter`
  (`coelo_ui_core`, já usado em Instituições) — máscara `+55 (DD) 9NNNN-NNNN` na digitação, valor gravado exibido
  formatado, envio em E.164 (`toE164`), validação com mensagem "Informe um celular válido: +55 (DDD) 9XXXX-XXXX." e
  "Informe o celular."; repositório mapeia `invalid_account_mobile_phone` para "Celular inválido. Use o formato
  +55 (DDD) 9XXXX-XXXX.". Widget tests: máscara/exibição/envio E.164 e inválido bloqueado (novos), 2 expectativas
  existentes ajustadas; `flutter test test/features/account` verde exceto 8 goldens de `account_pages_golden_test`
  cujo `isolatedDiff` fica restrito ao campo Celular (parênteses da máscara) — **não regravados** (D7: goldens na
  Etapa 3).

## 2. Prova na rota real (produção, 3014, `qa-r06-operacoes`, build QA com o cliente novo)

| Passo | Resultado | Captura |
|---|---|---|
| Abrir Meu perfil (`/profile`) | valor gravado exibido com máscara `+55 (11) 91234-5678` | `account-01-celular-exibido-com-mascara.png` |
| Digitar só dígitos `21987654321` | campo mostra `+55 (21) 98765-4321` | `account-02-digitacao-mascara.png` |
| Salvar alterações → `superadmin_account_profile_get` | `mobile_phone = "+5521987654321"` (E.164 no servidor) | — |
| `reload` | campo relido como `+55 (21) 98765-4321` | `account-03-reload-e164-formatado.png` |
| Digitar fixo `1133334444` (`+55 (11) 3333-4444`) → Salvar | bloqueado no cliente: "Informe um celular válido: +55 (DDD) 9XXXX-XXXX."; servidor permanece `+5521987654321` | `account-04-invalido-bloqueado.png` |
| Servidor direto (PostgREST `superadmin_account_profile_save_v2`) com `"11 3333-4444"` e `"+1 202 555 0143"` | **400 `22023` `invalid_account_mobile_phone`** (`ACCOUNT_MOBILE_PHONE_E164_REQUIRED`), sem mutação | — |

**Resultado:** `celular-mascara` → concluído; parte Celular de `owner.r12-46` → concluída (r12-46 continua `deferred`
pelo layout A+ "Meu acesso", Etapa 3). Formato a registrar pela coordenadora na spec/ADR pertinente: **E.164 brasileiro
`+55DDD9NNNNNNNN` no servidor; máscara `+55 (DD) 9NNNN-NNNN` na exibição**. Nenhum `action_id` muda
(`account.profile` já `verified-e2e`).
