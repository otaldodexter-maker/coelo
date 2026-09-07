---
title: "Avisos — indisponibilidade honesta de imagem"
source: "ADR 0032; superadmin-communication-finish-design; testes locais e review independente"
status: "local-green; not-e2e-complete"
generated_at: "2026-09-07"
---

# Recorte e causa

Avisos, formulário de imagem legada e `notices.publish`, somente Superadmin.
Dois textos ainda atribuíam o bloqueio a uma decisão Supabase Storage × R2
pendente. A ADR 0032 já decidiu por R2 privado; a dependência real é o gateway
integrado. Foram alteradas somente essas mensagens, sem trocar classe da
exceção, código `NOTICE_MEDIA_BLOCKED`, bloqueio, layout, RPC ou ambiente.

## Evidências

- RED: três testes falharam pelas mensagens antigas, sem falha de compilação.
  Uma primeira seleção com `--plain-name` e expressão regular não selecionou
  testes; foi corrigida para `--name` antes da reprodução RED.
- GREEN: 19/19 nos arquivos de repository e página. Comprovam zero request
  na publicação de imagem bloqueada, mensagem local segura para o envelope
  do servidor e conversão explícita para texto com remoção do banner.
- Regressão: 106/106 testes de Avisos, excluídos os arquivos golden.
- Analyzer dos quatro arquivos: sem problemas. Formatter executado somente
  nesses arquivos. Validador visual e diff-check executados antes do commit.
- Review independente read-only `review_media_session`: sem achado acionável.

Nenhum SQL, upload, segredo, deploy ou escrita remota. Goldens preexistentes
continuam divergentes e não foram atualizados. O CRUD com mídia e a cadeia
real Superadmin → gateway → Supabase → R2 continuam pendentes.

Gate de memória: no-op; aplica uma decisão aprovada já refletida na fonte
canônica e na projeção, sem criar nova política de produto.
