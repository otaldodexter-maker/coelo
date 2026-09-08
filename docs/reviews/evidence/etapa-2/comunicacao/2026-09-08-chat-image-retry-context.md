---
title: "Chat — retry de imagem vinculado à geração de origem"
source: "TDD sobre SuperadminChatImageDialog e revisão read-only E2E3"
status: "local-green; mídia real e E2E abertos"
generated_at: "2026-09-08"
---

# Recorte

Callback de retry de leitura de imagem no Chat canônico. Sem alterar MediaReader,
sessão compartilhada, entitlement, Scope, backend, decoder ou M03.

# Reprodução e correção

- RED dispose: callback retido executava setState após desmontagem.
- RED context: callback da UI antiga iniciava uma segunda leitura no reader novo.
- RED double-retry: duas chamadas antes do frame geravam duas novas leituras.
- Callback agora captura a geração exibida; a primeira leitura incrementa a
  geração sincronicamente. Guard mounted antes de qualquer setState em _read.
- 55/55 testes do diálogo; 127/127 Chat sem goldens; 8/8 goldens do diálogo;
  analyzer2 sem issues, format/diff e validador visual passaram. Revisão estática
  independente sem bloqueantes. Nenhum PNG atualizado.

# Limites

Fixtures locais não comprovam HTTP privado, cache do navegador, autorização,
RLS, decoder ou upload/entrega R2. Sem operações remotas. Gates M03 e produção
continuam abertos sob coordenação. Memória no-op: correção de lifecycle existente.
