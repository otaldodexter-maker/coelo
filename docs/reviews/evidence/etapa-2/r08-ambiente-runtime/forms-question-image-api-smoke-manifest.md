---
title: "R08 G0 — Manifesto do smoke API de Formulários e question-image"
source: "Contratos produtivos form_save_draft, form_get_editor e form-media na base R08"
status: "executado-pass-fixture-preservada"
generated_at: "2026-09-12T12:23:00-03:00"
---

# Smoke API de Formulários e question-image

## Estado e autorização

Roteiro preparado a pedido do C0, sem execução remota. O script é fail-safe: sem `--execute` apenas informa `READY_NO_MUTATION`. Migration, deploy de Edge Function, backup, ledger e banco linked permanecem exclusivos do C0.

O smoke usa somente a API legítima, com JWT da identidade QA autorizada. Não usa Chrome, CDP, injeção de sessão, `service_role`, SQL direto ou leitura de tabelas. Credenciais vêm dos arquivos privados já autorizados, ficam em memória e não aparecem no output. JWT, `finalize_ticket`, chave de objeto e URLs assinadas também nunca são impressos.

## Preflight remoto somente leitura

Após o C0 confirmar o lote 57 em produção, `supabase functions list` confirmou `form-media` ativa, versão 16, `verify_jwt=true`, com hash de bundle `04f20933b533151264771cfb8ded418e0f11dbbeead057219e805a5bbda9f316`. Em seguida, `supabase functions download form-media --use-api` trouxe uma cópia temporária somente leitura da fonte implantada. A comparação byte a byte dos quatro arquivos de runtime foi igual à fonte local inspecionada:

- `index.ts`: `ab8e1193a5e1843c20ea0fcf20c2c8f74d90ccfb8e5bbb77076a708a49d78947`;
- `media_contract.ts`: `09c3605ef3b379ffcabe638d606899a350c943b56a4afb5981d9b39440ddb9ce`;
- `question_image.ts`: `6406cc226028a949b21c336440d5702ef616b579df22e712b8aecc70bc7956a0`;
- `_shared/r2_s3.ts`: `ba7c78395313945dd04dd23c7ce5e8f99e9d5e37b6cffaf148c9357adbbd5859`.

Isso prova que a Edge implantada contém o parser `question-image` e a sequência `authorize → HEAD → GET/hash/dimensões → finalize` revisada. G5 confirmou que seu delta adicional é somente de teste e que nenhum deploy Edge novo é necessário. A cópia temporária foi removida depois da comparação; nenhum arquivo remoto foi alterado.

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
7. Repetir a mesma action `finalize` no mesmo asset e exigir novamente HTTP 200, `ready`, 1×1 e o mesmo `asset_id`, provando a reconciliação real de resposta perdida sem duplicação.
8. Chamar `form-media` action `resolve`, baixar pela URL assinada e exigir HTTP 200, mesmo tamanho e mesmo SHA-256.
9. Repetir `form_get_editor` como reload API e exigir exatamente um binding do asset, status `ready`, mesmo `item_id`, MIME `image/png` e posição zero.
10. Preservar o formulário e o asset sintéticos, inclusive em falha, e publicar seus IDs no resultado para o fechamento formal da Etapa 2.
11. No bloco `finally`, encerrar somente a própria sessão Auth por `POST /auth/v1/logout?scope=local`.

O editor produtivo é deliberadamente usado aqui. `superadmin_forms_save_draft_v2` cria o realm de rascunho interno, enquanto a ponte `140546..140549` que expõe `media_context` e permite question-image sobre o formulário people-based foi definida para `form_save_draft`/`form_get_editor`. Misturar os dois realms não provaria o caminho consumido pelo editor normal.

## Critérios e paradas

- Pré-condições do C0: backup/lote 57 concluído; migrations `140546..140549` e Edge Function compatível presentes em produção; autorização nominal para a única fixture temporária.
- Parar imediatamente se auth, save, projeção do editor ou prepare negar o contexto; não tentar outra instituição.
- Não repetir `prepare` com payload diferente e o mesmo request ID.
- O segundo finalize é intencional e idêntico; deve reconciliar o mesmo asset `ready`, nunca criar outro.
- Em qualquer falha após o save, não apagar nem o formulário nem o asset; publicar os IDs sintéticos e encerrar apenas a própria sessão local.
- Falhas de rede são registradas somente como `network_error`; nenhuma exceção pode serializar uma URL assinada.
- PASS exige: auth 200, rascunho identificado persistido, PUT/finalize, leitura autorizada com hash igual, binding `ready` preservado no segundo editor e logout local confirmado.
- A fixture permanece para inspeção e só pode ser removida no fechamento formal da Etapa 2 pelo fluxo coordenado do C0.
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

## Resultado da execução autorizada

O C0 autorizou nominalmente uma única fixture às 12:33 BRT. A execução encerrou com exit `0` e todos os gates PASS: Auth `200`, save identificado `200`, editor inicial `200`, prepare `200`, PUT `200`, finalize `200`/`ready`/1×1, replay idêntico `200` no mesmo asset, resolve e GET `200` com 68 bytes e SHA-256 igual, editor recarregado `200` com único binding `ready`, e logout local `204`.

- formulário preservado: `f88005ab-af5e-4aa2-8cf7-f35de4ded376`;
- working version: `4adae123-1aad-4e1f-a2f4-b59d661bc3d4`;
- item: `b7ac860f-f23a-4b68-b320-d2098abc94e6`;
- asset preservado: `d25b8baa-efb5-4702-b5e6-ac3084610605`;
- recibo sanitizado: [forms-question-image-api-smoke-20260912.log](./forms-question-image-api-smoke-20260912.log).

Nenhum DELETE/cleanup foi chamado. O recibo não contém credencial, JWT, ticket, chave de objeto ou URL assinada.
