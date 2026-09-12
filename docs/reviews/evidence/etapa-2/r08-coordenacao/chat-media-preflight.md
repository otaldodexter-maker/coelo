---
title: "R08 C0 — Chat: integração e preflight remoto"
source: "G5 ebb227212; Deno na base integrada; Supabase CLI; OPTIONS remoto"
status: "implantado; fluxo de anexos pela tela pendente"
generated_at: "2026-09-12T11:09:10-03:00"
---

# Chat: integração e preflight

Pacote G5 `ebb227212` integrado por merge real. Na base integrada, o comando
`rtk proxy deno test --allow-env --allow-read`, no diretório
`packages/coelo_database/supabase/functions/chat-media`, encerrou com código 0:
6 PASS, 0 FAIL (179 ms de execução dos testes). O aviso de dependência
`punycode` foi preservado; nenhuma ferramenta global foi reconfigurada.

Deploy C0 via `supabase functions deploy chat-media --project-ref
evvbomzejfijozbtgvpt --workdir packages/coelo_database --use-api`, código 0.
Consulta posterior confirmou **chat-media v4 ACTIVE**, atualização remota
`1789222117758`, com `verify_jwt=false` preservado do contrato anterior.

OPTIONS medido em 12/09/2026 às 11:09:10 BRT, solicitando POST e os cabeçalhos
`authorization,apikey,content-type,x-client-info`:

| Origem | HTTP | Access-Control-Allow-Origin |
| --- | --- | --- |
| http://127.0.0.1:3014 | 200 | mesma origem |
| https://superadmin.coelo.me | 200 | mesma origem |
| https://untrusted.example | 403 | ausente |

As respostas incluem `x-client-info` na allowlist. Esta prova cobre o
preflight; upload, autorização do vínculo, leitura privada e reload pela
tela continuam pendentes de G4/runtime. Nenhuma promoção FE/BE/E2E.
Nenhum usuário, chave, bucket ou objeto sintético criado por este deploy.
