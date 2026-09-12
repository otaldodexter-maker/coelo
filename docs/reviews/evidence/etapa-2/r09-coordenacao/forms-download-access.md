---
source: forms-download-access-probe.py; execucao C0 em producao; forms-answer-image-api-download-pass-20260912.log da R08
status: gates-parciais-verificados-sem-promocao
generated_at: 2026-09-12
---

# Download de imagem de resposta — acesso e TTL

Etapa2 -> apps/superadmin -> Formularios -> Resposta -> arquivo ->
`forms.resolve-file`. Base de codigo `7907453f0`; provedor produtivo
`form-media`, fixture retida da R08. Probe concluido em12/09/2026, por API
normal autenticada; nenhuma sessao injetada no navegador.

| Verificacao desta execucao | Resultado |
| --- | --- |
| Download sem Authorization | PASS HTTP401, sem URL assinada |
| Login API da identidade sintetica qa-r06-principal | PASS HTTP200 |
| Download de asset inexistente | PASS HTTP400 media_request_failed, sem URL |
| Download autorizado do asset retido | PASS HTTP200,68bytes, SHA256 abaixo, TTL60s |
| Mesmo link apos espera real65s | PASS HTTP403; nenhum link novo emitido no teste de expiracao |
| Logout da sessao propria scope=local | PASS HTTP204 |

SHA256 dos bytes: `431ced6916a2a21a156e38701afe55bbd7f88969fbbfc56d7fe099d47f265460`.
Asset `e47eb9e1-ee0c-4a7c-bbcd-9c6dfb4e8195` preservado; resposta
`bb1f3443-76a6-4049-b364-6215545625c8` e formulario inalterados pelo runner.
Nenhum prepare, PUT, finalize, save, discard, SQL ou deploy executado.
Nenhum segredo, objeto R2 ou chave criada. URLs e tokens ficaram em memoria.

Execucao final: seis verificacoes PASS, zero FAIL, zero ignoradas, exit0.
Primeira tentativa: passou o401 e abortou antes de confirmar login, com
AssertionError; status Auth nao foi coletado, causa indeterminada. A segunda
tentativa acrescentou diagnostico sanitizado do status e passou. Nao somar
o401 repetido nem omitir a tentativa abortada.

Reutilizada a prova R08 de persistencia/reabertura da resposta; nenhum novo
reload de UI foi executado. Negativa real entre tenants ainda nao demonstrada
por este runner. Expiracao do link nao comprova expiracao/exclusao do ativo.
BE permanece local-green; FE/E2E permanecem nos estados anteriores. Proximo
gate: G3/C0 conferir negativa de tenant/contrato e G3 provar download/reabertura
pela rota normal quando G0 liberar runtime. Memoria de produto: no-op.
