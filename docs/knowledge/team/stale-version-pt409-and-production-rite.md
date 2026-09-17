---
title: Versão defasada sinaliza PT409 e o rito de produção por lote
knowledge_id: stale-version-pt409-and-production-rite
source: decisions/0042-r14-closure-r15-opening-20260916.md
status: validated
lifecycle: "current"
generated_at: 2026-09-17
updated_at: 2026-09-17
audience: team
surfaces: [supabase, database, edge-functions, superadmin, review]
visibility: internal
review_owner: Coelo Owner
---

# Versão defasada sinaliza PT409 e o rito de produção por lote

Regra durável fixada pelo Owner em 16/09/2026 (ADR 0042, E1; OQ-047) e
aplicada em produção em 17/09/2026 (lote 75): **nenhuma RPC do Coelo sinaliza
versão defasada ou conflito otimista com SQLSTATE `40001`**. O código é
`PT409`, com `detail` no padrão `<FAMÍLIA>_STALE_VERSION` ou o código já
existente da família (`SAI_CONCURRENT_CHANGE`, `CIRCULAR_CONFLICT`,
`NOTICE_CONFLICT`). O motivo é operacional: o PostgREST reexecuta `40001`
sem limite, e em 16/09 esses laços esgotaram o pool de conexões da produção
(504 `PGRST003`) por horas.

## O que muda para quem escreve backend

- Migration nova nunca recria função com `raise serialization_failure` nem
  `errcode = '40001'`; wrappers de envelope capturam `PT409` ao lado de `23505`.
- A negativa de versão defasada por PostgREST é segura em todas as famílias:
  esperado HTTP 409 `PT409` sem mutação. Um 504 nessa negativa é incidente.
- pgTAP por família prova caminho feliz intacto e versão defasada → `PT409`.

## O que muda para quem escreve Flutter

- Repositórios e mapeadores de erro tratam `PT409` junto de `40001` e
  `SAI_CONCURRENT_CHANGE`; sem isso a tela mostra o erro genérico em vez da
  mensagem de conflito com "Recarregar".

## Rito de produção por lote (R15)

1. Dump de schema novo da produção fora do Git, com SHA-256 registrado.
2. Espelho Docker próprio restaurado desse dump, com a ACL igual à produção e
   catálogos semeados; pgTAP verde.
3. Autorização nominal do Owner para o lote.
4. `supabase db query --linked -f` por migration, na ordem; `migration repair
   --status applied`; `migration list --linked` confirma o ledger.
5. Edge Functions por `supabase functions deploy` após teste local; versão e
   `verify_jwt` conferidos.
6. Lote numerado na ordem real de aplicação em
   `packages/coelo_database/migrations/ordem-de-aplicacao-producao.txt`, com
   dump, SHA, pgTAP e comandos.

Lotes de 17/09/2026: 75 (PT409 sistêmico), 76 (Chat com vários anexos por
mensagem, E3), 77 (leitor "Para você" do Principal, B9), 78 (busca de pessoa
autorizada B5, pessoa sem conta B6 e imagens de Cardápios em R2), 79 (projeção
`can_remove` do feed do Agora) e 80 (fixture da massa QA R15). Lotes 79 e 80 fecharam a
R15; a R16 (ADR 0043) segue o mesmo rito.

Edge Function chamada pelo pg_cron com bearer próprio usa `verify_jwt = false` e valida
o bearer no handler; com a verificação do gateway ligada o worker recebe 401 e o cron
"sucede" sem efeito (caso `form-media`, corrigido em 17/09, E14).

## Busca de pessoa e pessoa sem conta (ADR 0041 B5/B6)

A busca de pessoa autorizada exige mínimo de caracteres por tipo (nome/@/e-mail
3, celular 4 dígitos, CPF 6 dígitos), escopo do ator no servidor, auditoria,
limite de taxa e resultado minimizado; **CPF nunca aparece em resultado** e só
o número completo e válido é comparado, por HMAC. Pessoa sem conta tem CPF
obrigatório como chave de deduplicação, documento em R2 privado e fica
autorizada só no contexto pedido pelo responsável. Pessoa autorizada precisa
ser adulto com status `active`.
