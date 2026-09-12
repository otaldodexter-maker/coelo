---
title: "R08 G0 — Manifesto do smoke API de Formulários e question-image"
source: "Contratos produtivos form_save_draft, form_get_editor e form-media na base R08"
status: "preparado-sem-mutacao"
generated_at: "2026-09-12T12:23:00-03:00"
---

# Smoke API de Formulários e question-image

## Estado e autorização

Roteiro preparado a pedido do C0, sem execução remota. O script é fail-safe: sem `--execute` apenas informa `READY_NO_MUTATION`. Migration, deploy de Edge Function, backup, ledger e banco linked permanecem exclusivos do C0.

O smoke usa somente a API legítima, com JWT da identidade QA autorizada. Não usa Chrome, CDP, injeção de sessão, `service_role`, SQL direto ou leitura de tabelas. Credenciais vêm dos arquivos privados já autorizados, ficam em memória e não aparecem no output. JWT, `finalize_ticket`, chave de objeto e URLs assinadas também nunca são impressos.

## Contexto e fixture propostos

- Instituição medida: `d0c40000-0000-4000-8000-000000000001`.
- Unidade medida, apenas para conferir o contexto: `d0c40000-0000-4000-8000-000000000002`.
- Grupo medido, apenas para conferir o contexto: `368a5cea-2bcf-4fa4-ad1f-18da58694551`.
- Formulário temporário: `kind=form`, `identity_mode=identified`, `response_unit=person`, título prefixado `QA R08`.
- Definição: uma seção e uma pergunta `short_text`; IDs de origem e `form_id` são UUIDs novos gerados pelo cliente.
- Imagem: PNG válido de 1×1 pixel, 68 bytes, SHA-256 calculado antes do prepare. Nenhum dado pessoal.

A fixture é institucional; unidade e grupo não entram no payload de autoria ou mídia. Eles são referências de contexto, não parâmetros inventados para RPCs que não os aceitam.

## Sequência nominal

1. Autenticar por `/auth/v1/token?grant_type=password` com a publishable key e a conta QA.
2. Criar o rascunho identificado por `public.form_save_draft(uuid,bigint,jsonb)`, exatamente como `SupabaseFormsApi.saveDraft`, com `expected_version=0`.
3. Ler por `public.form_get_editor(uuid)` e obter da projeção autorizada o `media_context.form_version_id` e o UUID real do item. Exigir `question_images=[]`.
4. Chamar `POST /functions/v1/form-media`, action `prepare`, purpose `question-image`, com `form_id`, `form_version_id`, `item_id`, MIME, bytes e SHA-256.
5. Fazer PUT dos bytes na URL assinada com os headers exigidos. URL e headers não entram no log.
6. Chamar `form-media` action `finalize`; exigir HTTP 200 e status `ready` com dimensões 1×1.
7. Chamar `form-media` action `resolve`, baixar pela URL assinada e exigir HTTP 200, mesmo tamanho e mesmo SHA-256.
8. Repetir `form_get_editor` como reload API e exigir exatamente um binding do asset, status `ready`, no item autorizado.
9. No bloco `finally`, chamar `form-media` action `delete` e depois `form_archive_or_delete` action `delete`. Publicar falha de cleanup com os IDs sintéticos se qualquer remoção não confirmar HTTP 200.

O editor produtivo é deliberadamente usado aqui. `superadmin_forms_save_draft_v2` cria o realm de rascunho interno, enquanto a ponte `140546..140549` que expõe `media_context` e permite question-image sobre o formulário people-based foi definida para `form_save_draft`/`form_get_editor`. Misturar os dois realms não provaria o caminho consumido pelo editor normal.

## Critérios e paradas

- Pré-condições do C0: backup/lote 57 concluído; migrations `140546..140549` e Edge Function compatível presentes em produção; autorização nominal para a única fixture temporária.
- Parar imediatamente se auth, save, projeção do editor ou prepare negar o contexto; não tentar outra instituição.
- Não repetir `prepare` com payload diferente e o mesmo request ID.
- Em qualquer falha após o save, executar somente a limpeza nominal no `finally` e publicar os IDs sintéticos para reconciliação.
- PASS exige: auth 200, rascunho identificado persistido, PUT/finalize, leitura autorizada com hash igual, binding `ready` preservado no segundo editor e cleanup confirmado.
- A repetição de `form_get_editor` prova persistência/reload por API, não substitui o gate visual de login/leitura/reload que segue bloqueado pela entrada de texto CUA.

## Comando preparado

Sem rede e sem mutação:

```powershell
rtk python docs/reviews/evidence/etapa-2/r08-ambiente-runtime/forms-question-image-api-smoke.py
```

Somente após liberação do C0:

```powershell
rtk python docs/reviews/evidence/etapa-2/r08-ambiente-runtime/forms-question-image-api-smoke.py --execute --institution-id d0c40000-0000-4000-8000-000000000001
```
