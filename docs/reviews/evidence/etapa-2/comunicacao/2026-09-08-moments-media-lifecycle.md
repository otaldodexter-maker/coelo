---
title: "Momentos — negação do draft e cache decodificado"
source: "Recorte nominal do Coordenador após4132c0aa; TDD root e review read-only"
status: "local-green; not E2E"
generated_at: "2026-09-08"
---

# Lacunas reproduzidas e correções

Três REDs load/save/publish Unauthorized mantinham mídia/bytes/URL/legenda.
Controller agora substitui draft por estado vazio e mantém latch de negação
contra edição e comandos, inclusive callbacks indexados; somente load autorizado
libera. Testes incluem comando positivo após recuperação e zero comandos negados.

Quatro REDs de cache provaram entrada Flutter keepAlive remanescente após
contexto/dispose, para MemoryImage e NetworkImage. O componente captura provider
e faz eviction em substituição/dispose, preservando fit, semântica e aparência.
Oito testes finais incluem também substituição de mídia no mesmo widget e
negação do save, com cache previamente presente e pending/keepAlive/live vazios
após a transição. O fixture inicial decodifica imagem sintética4×4, sem HTTP.

# Verificação

- 79/79 feature publicação Momentos, incluindo goldens existentes; sem novos PNG.
- Analyzer do domínio e testes, format, diff e review independente sem P1/P2.
- Três testes novos de controller e oito de cache. Erros intermediários de
  extensão de classe final/ordem do fixture foram corrigidos nos testes e não
  classificados como falhas de produto.

# Limites e gate real

Não prova zeroização de cópias externas, cache HTTP/browser, download/decode
pendente ou purge aguardável pelo logout real. Eviction é assíncrona por widget;
MediaSession/Auth produtivos continuam integração nominal separada. Picker é
callback externo, não novo picker implementado aqui. Nenhum SQL/Scope/decoder/
entitlement/R2 real ou limite de Chat foi criado. Correção restaurativa sem
nova regra durável para projeção de conhecimento.
