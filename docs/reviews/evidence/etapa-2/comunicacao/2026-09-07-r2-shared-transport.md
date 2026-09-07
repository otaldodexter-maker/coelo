---
title: "M02 — transporte R2 compartilhado com compatibilidade Momentos"
source: "reserva E2E3-M02 e extensão nominal index_test; transporte real Momentos; testes Deno; documentação oficial R2/AWS"
status: "local-green; no-deploy; not-e2e-complete"
generated_at: "2026-09-07"
---

# Recorte

Extração do signer/transporte de `moments-media/r2_s3.ts` para
`_shared/r2_s3.ts`. O wrapper real mantém MomentsR2Client, momentsR2Config,
tipos exportados, variáveis MOMENTS_R2_*, assinatura dos métodos, defaults
PUT 300s/GET 120s e códigos moments_r2_*.

Configuração validada tanto na factory quanto no construtor: HTTPS, ausência
de userinfo/query/fragment e bucket lexicalmente válido conforme regra legada.
Erros de URL são sanitizados, configuração copiada/congelada e ordenação da
query canônica é ASCII explícita. Não foi introduzida política de autorização,
seleção de bucket por domínio, MIME real ou path ADR neste transporte.

Não há mudança de index runtime, ambiente, bucket, path configurado, Functions
Forms, deploy, R2 remoto ou Supabase. A existência do wrapper legado não
autoriza novos consumidores a usar o bucket legado: mídia nova continua nos
três buckets privados aprovados, com autorização server-side da vertical.

## Evidências reproduzíveis

- RED: três testes legados verdes e seis novos falharam, pois factory e
  construtor aceitavam userinfo/query/fragment.
- GREEN focal: 21/21, incluindo dois vetores SigV4 GET/PUT independentes,
  key/TTL, escaping, configuração congelada, HEAD metadados/404/500,
  DELETE idempotente 404 e tradução assíncrona dos erros do wrapper.
- Suíte ampliada inicialmente 24 verdes/1 falha: teste estático procurava
  headers somente no arquivo antigo. Extensão nominal autorizou incluir a
  leitura do compartilhado, sem retirar qualquer assertion.
- GREEN ampliado final: 29/29 com
  `deno test --allow-read --config packages/coelo_database/supabase/functions/moments-media/deno.json packages/coelo_database/supabase/functions/moments-media packages/coelo_database/supabase/functions/_shared/r2_s3_test.ts`.
- `deno check` do consumidor index.ts e compartilhado passou usando o
  deno.json existente. Primeira execução sem config falhou por import alias;
  não houve instalação ou alteração de dependências para resolver isso.
- Lint dos cinco arquivos passou; formatter aplicado.
- Reviews independentes de transporte e compatibilidade aprovados no recorte.

Vetores com credenciais explicitamente sintéticas, calculados fora do signer
com Python stdlib hashlib/hmac e canonical request literal:

| Método | TTL | SHA256 canônico | Assinatura esperada |
| --- | --- | --- | --- |
| GET | 120 | b0653e7beb5014c5db2fb374f4370f6b70e4ae8523e6d49cd06b9a3760e5d1c5 | a657cee6c6df6a264414ed3e73d1e8f5a5325b9348a3553938360b2066618324 |
| PUT image/webp | 300 | 911da620d72c05368d174dd2d4a1a0f3e0dd669d639896b53f210613e4f90425 | 03d32940e93c433211c05ba2d0fbff18f358c2f07e4af8aaacec9e61394d0803 |

Referências: [R2 presigned URLs](https://developers.cloudflare.com/r2/api/s3/presigned-urls/),
[R2 S3 API](https://developers.cloudflare.com/r2/api/s3/api/) e
[AWS SigV4 canonical request](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_sigv-create-signed-request.html).

## Limites e próximos gates

O transporte não prova acesso R2 real, autorização, catálogo, processamento,
revogação ou expiração de dados. Redirects, host/base path/porta, falhas fetch,
MIME do PUT e interpretação lexical de content-length mantêm comportamento
legado e não foram ampliados nesta reserva. Novos consumidores precisam de
contratos próprios; nunca usar o signer como controle de acesso.

Gate de memória: no-op de produto; extração técnica documentada nesta evidência,
sem nova regra aprovada para usuário final.
