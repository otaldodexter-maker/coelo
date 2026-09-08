---
title: "M03 — limites de métricas de imagens no servidor"
source: "ADR0032; reserva nominal do Coordenador; testes Deno e review independente"
status: "local-green; not-decoder; not-e2e"
generated_at: "2026-09-07"
---

# Recorte e resultado

Dois módulos _shared reservados, sem I/O, dependência nova, configuração ou
provider. validateImageMetrics aplica classes avatar/logo/cover/photo/map,
source/master, às métricas medidas pelo decoder do servidor. Não recebe chave,
URL, credencial ou política livre do cliente. Limites inclusivos, crop de master
avatar/capa, mínimos de origem, MIME normalizado e SHA256 canônico. Comparação
por divisão evita multiplicação insegura de pixels; retorno é cópia congelada.

- RED: 14 falhas/5 passes com stub que recusava tudo, após corrigir um erro de
  tipagem no próprio teste (assertThrows precisava especificar Error).
- GREEN **19/19** módulo; ampliado **30/30** com transporte R2 compartilhado.
- Deno typecheck incluído, lint e formatter dos dois arquivos exit 0.
- Review review_media_session: sem bloqueante; comentário exige validar
  bytes/pixels originais HEIC/HEIF mesmo quando conversão anteceder a função.

Não é decoder, não calcula checksum, não remove EXIF/GPS, não valida animação,
não autoriza usuário nem verifica persistência. Não marca ativo ready. Flags ou
metadados fornecidos pelo cliente não podem alimentar esta fronteira como prova.
Rendições/variants precisam de perfis nominais próprios; não inventados aqui.

Próximos gates: decoder real, catálogo/session/RPC, reautorização, gateway,
fixtures sintéticas de bytes reais e produção sob lease. Zero mutation remota,
nenhum action_id promoted a done/verified-e2e. Memória no-op: regra aprovada já
documentada, sem nova política de produto.
