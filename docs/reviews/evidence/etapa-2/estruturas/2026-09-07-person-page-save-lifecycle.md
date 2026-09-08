---
title: "PERS-PAGE-LIFECYCLE02 — callbacks e contexto de formulário"
source: "specs/019-superadmin-people-directory.md"
status: "local-green-not-e2e"
generated_at: "2026-09-07"
---

# Resultado local

Guard síncrono impede `_save` duplicado antes do rebuild. Geração, identidade
do view model e snapshot de campos/patches impedem entregar receipt/erro antigo
após nova intenção. Troca de pessoa, versão original ou repository recria estado
e campos; respostas de opções antigas são ignoradas por geração. Dispose
continua sem callback, sem notificação tardia e sem erro mascarado.

Somente página, teste novo, plano e esta evidência. Nenhuma alteração de layout,
validação, entidades, router, backend ou autorização produtiva. Depende da
proteção do view model em `aa5029f6`.

## Verificação

- RED: quatro falhas reproduzidas — callback duplo, substituição de pessoa,
  substituição de repository e receipt depois de nova edição. Dois casos de
  dispose já estavam verdes antes da correção.
- GREEN focal final: 11/11, acrescentando retry, erro tardio, novo patch
  contextual e opções antigas em sucesso/erro. A contraprova de opções verifica
  também ausência do seletor que seria criado pelos dados obsoletos.
- Regressão: 61/61 em sete suítes de página/form/view model/lifecycle,
  edit route, arquivos e identity gate.
- Analyzer dos dois Dart alterados: zero issues; nenhum ignore novo.
- Validador visual exit 0; nenhum golden alterado.
- Dois gates de conhecimento PASS; memória no-op, invariantes locais
  restauradas sem política de produto nova.
- Review independente read-only (Nash): nenhum bloqueante. Nenhum teste
  Flutter concorrente foi executado pelo reviewer.

## Limites

Sucesso suprimido preserva a intenção posterior, mas não atualiza silenciosamente
`original.updatedAt` nem reconcilia patches. Reload/continuidade após sucesso
exigem pacote próprio, sem pressupor retry de escrita idempotente no backend
legado. Não é conclusão do formulário nem de Pessoas.

Zero Supabase/Cloudflare remoto, zero SQL/Docker e zero prova E2E. As rotas
produtivas bloqueadas permanecem bloqueadas. O coordenador atualiza os três
rastreadores; a vertical Estruturas, Pessoas e Locais continua aberta.
