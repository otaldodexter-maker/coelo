---
source: "Sessão A da R15 (Fable 5.1), 17/09/2026; R15-pendencias.md (ordem 3); owner.r12-46; ADR 0032 (mídia privada R2); modelo r14-sessao-1/circulars-attach-20260915.md (upload via CDP)"
status: evidence
generated_at: 2026-09-17
---

# Conta › Meu perfil (`account.profile`; owner.r12-46) — rota real, 17/09/2026

Mesmo ambiente das fatias anteriores (produção, build QA de `r15/bloco-a` em `900608be9`, `127.0.0.1:3014`,
CDP 9414, tema claro, viewport 1424×1125), sessão `qa-r06-acessos@coelo.me` (Owner de plataforma). Rota
`/profile` ("Meu perfil"). Upload pelo seletor nativo real interceptado por CDP
(`Page.setInterceptFileChooserDialog` + `DOM.setFileInputFiles`, `cdp_filechooser.dart`) com um PNG real
64×64 (7.850 bytes) gerado no scratchpad; Edge Function `account-media` (`prepare` → PUT presignado R2 →
`finalize`), origem `http://127.0.0.1:3014` liberada (preflight 200). Readback e negativas por PostgREST /
Edge com a mesma identidade (script no scratchpad; saída mascarada). Capturas em `capturas/account-*.png`.

| action_id | Rota normal | CRUD em produção | Reload | Negativa |
|---|---|---|---|---|
| account.profile | `/profile` (00): "Dados pessoais" e, **na mesma linha**, "Meu acesso" com busca e rolagem interna (A+ da aprovação de 14/09 já vigente; "Segurança" abaixo) → "Escolher foto" → seletor nativo real → diálogo "Ajustar foto" com zoom/arraste (01) → Aplicar → prévia com a imagem real, botões "Trocar foto"/"Remover foto" → Celular `123` → "Salvar alterações" → campo em erro "Use entre 7 e 40 caracteres." e nada enviado (02) → Celular `+55 11 98888-0001` → Salvar → banner "Perfil atualizado.", **avatar global do cabeçalho troca para a foto** (03). Depois: "Remover foto", Sigla `QR`, Salvar → "Perfil atualizado.", avatar do cabeçalho volta a sigla "QR" (06). | `account-media prepare/finalize` → asset `e2a00029-7893-4c28-bc4f-ce29f2ab5bc8` (R2 privado), `superadmin_account_profile_save_v2` → `superadmin_account_profile_get`: `avatar.mode photo`, `asset_id e2a00029…`, `mobile_phone` (17 caracteres), `initials OC`, `background_color #FFF1EB`; `account-media read` do próprio asset → 200 com `signed_url`. Após remover: `superadmin_account_profile_get` com `avatar.mode initials`, `initials QR`, sem `asset_id`; `account-media remove` executado pelo cliente no save. | Carga completa de `/profile`: foto e celular relidos (04). **Nova sessão** (storage limpo, novo login): cabeçalho e `/profile` mostram a foto vinda do R2 (05). Após remover: recarga mostra sigla QR e sem foto (07). | `account-media read`/`remove` com `asset_id` alheio/inexistente → `422 {"error":"account_avatar_read_denied"}` / `{"error":"account_avatar_remove_denied"}` (sem vazamento de URL; HTTP 422 em vez de 403 — resíduo de mapeamento); `read` do asset removido → ver linha abaixo. Celular inválido bloqueado no cliente antes de qualquer chamada. |

Readback após a remoção: `superadmin_account_profile_get` → `avatar.mode initials`, `initials QR`, `background_color #FFF1EB`, celular com 17 caracteres; `account-media read` do asset removido `e2a00029…` → `422 account_avatar_read_denied` (a URL assinada deixa de existir depois do `remove`).

## owner.r12-46 — o que ficou provado e o que resta

- Provado na rota real: foto real via R2 privado (upload, leitura assinada, remoção), avatar global do cabeçalho
  atualizado pela confirmação do servidor (banner "Perfil atualizado." só após o `save_v2`; o celular inválido
  não gera aparência de sucesso), reload, troca de sessão, sigla e cor exibidas, celular inválido × válido,
  layout A+ ("Meu acesso" na mesma linha de "Dados pessoais" com rolagem interna).
- Resíduo (não fecha o item por completo): o Celular não tem **máscara/formatação de entrada nem
  normalização** — o cliente só valida comprimento (7–40 caracteres) e o servidor grava o texto como digitado
  (`+55 11 98888-0001` com 17 caracteres). O Owner pediu máscara + normalização; fica como pendência de FE/BE
  (decisão de formato E.164 × exibição) sem action_id novo.
- A cor da sigla foi aberta no diálogo "Cor da sigla" (HSV/RGB/hex, `#FFF1EB` atual); a troca por digitação do
  hex não foi aplicada pela automação (o campo hex exige confirmação por foco/Enter) — mantida a cor atual,
  já provada na R13 (lote 63).
- O avatar do cabeçalho, logo após um login novo, aparece vazio por ~1 s até a leitura assinada do R2 terminar
  (Home em 05 antes de `/profile`); depois mostra a foto.
