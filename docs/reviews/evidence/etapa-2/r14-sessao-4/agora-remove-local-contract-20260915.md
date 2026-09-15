---
title: "Contrato local da negativa cross-tenant do Agora"
source: "ADR 0040; packages/coelo_database/supabase/tests/now_publication_removal_test.sql"
status: "validated"
lifecycle: "current"
generated_at: "2026-09-15"
updated_at: "2026-09-15"
audience: "team"
action_id: "agora.remove"
---

# Resultado

O contrato pgTAP de `agora.remove` foi ampliado de 15 para 19 assertions sem
alterar migrations, contadores ou MDs centrais.

As novas assertions verificam que:

- tenant/contexto e ator são resolvidos pelo `target.institution_id` no servidor;
- a autorização ocorre antes da mutação;
- publicação desconhecida ou inacessível usa negativa não enumerável;
- a negativa não depende de `institution_id` fornecido pelo cliente.

Este avanço é somente contrato local. A prova produtiva cross-tenant continua
bloqueada para R16 até existir uma fixture remota autorizada e verificável.
