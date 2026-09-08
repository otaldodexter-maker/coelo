---
title: "Acontece — negação de publicação e remoção de mídia"
source: "Contratos existentes do controller e happens-media/index.ts; TDD e revisão read-only E2E3"
status: "local-green; transporte legado e E2E abertos"
generated_at: "2026-09-08"
---

# Recorte

Acontece/publicação no menu Coelo (Principal) do Superadmin: resposta a negação
tipada, descarte do draft e autosave. Não alterar permissões, rota/composição,
Edge, SQL ou Storage/R2. Ordem: controller RED, adapter RED, correções, regressão
e review. Critério da fatia: testes locais verdes, sem promoção de E2E.

# Evidência

Correção de interpretação após revisão central: a classificação definitiva de
422/media_delete_denied descrita historicamente abaixo foi retirada. A Edge
agrupa qualquer erro de RPC nesse envelope; ele não prova negação. Somente
401/403 continuam tipados no adapter. O controller mantém purge quando recebe
negação tipada, sem alteração neste incremento.

Dois REDs confirmaram classificação e perda do draft; o novo teste atravessa
MockClient, adapter e controller, preservando legenda, audiência e mídia após
422 e permitindo nova remoção explicitamente solicitada com resposta 200.
Isso não equivale a provar idempotência ou persistência remota.
Regressão do incremento: 55/55 testes da feature incluindo goldens, analyzer
dos dois arquivos, format e diff check verdes; revisão read-only sem bloqueante.

- Seis REDs reproduzidos: negação tipada em load/save/prepare/finalize/publish
  retinha draft; remove entrava em failure e permitia rearme de autosave.
- `_denyAccess` descarta draft/mídias/audiência/data, desliga e cancela autosave,
  invalida geração e libera busy. `_canEdit` bloqueia callbacks antigos; testes
  avançam três segundos e comprovam ausência de save adicional.
- Remoção recebe catch específico. No adapter, três REDs HTTP via MockClient
  reproduziram FunctionException sem tipagem para 401/403 e 422 com
  `media_delete_denied`. Cinco testes verdes incluem controles 422
  `media_delete_failed` e 503: não classificados como autorização.
- A Edge existente foi lida integralmente; ela própria agrupa erros de RPC em
  `media_delete_denied`. O cliente respeita esse envelope, sem provar a causa
  individual. Não ampliar o mapeamento por substring ou status genérico.
  Essa interpretação inicial foi rejeitada pela revisão central e corrigida
  conforme o adendo acima; o envelope ambíguo agora permanece recuperável.
- 54/54 testes da feature de publicação, incluindo goldens existentes, GREEN.
  Destes, 20 controller e cinco adapter. Nenhum PNG alterado.
- Analyzer quatro arquivos, format, diff check, validador visual e review
  independente read-only sem bloqueantes.

# Limites

O adapter ainda contém transporte legado Supabase Storage; esta correção não
o habilita, converte ou apresenta como integração R2. Prepare/finalize possuem
erros legados ambíguos cujo contrato de transporte permanece aberto. Os seis
casos de controller injetam a exceção tipada; só remoção ganhou mapeamento HTTP
neste delta. Não houve upload, remoção de objeto, publicação ou mutation real.
Não comprova tenant/RLS/revogação remota nem E2E. Restaura contrato de isolamento
existente; memória no-op, sem nova política ou artigo de atividade.
