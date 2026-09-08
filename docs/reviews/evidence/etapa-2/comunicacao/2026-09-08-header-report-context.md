---
title: "Cabeçalho global — contexto do relato aberto"
source: "Isolamento existente Coelo; TDD e revisão read-only E2E3"
status: "local-green; envio backend e E2E abertos"
generated_at: "2026-09-08"
---

# Recorte e evidência

Relato do cabeçalho global no Superadmin. Não alterar suporte backend, emissão,
autorização, anexos, logout ou apps fora do escopo original. Ordem: reproduzir,
isolar lifecycle, regressão e review. Critério desta fatia: nenhuma entrega do
relato antigo depois da mudança de contexto, sem alegar envio real.

- Quatro REDs funcionais após corrigir o pump do próprio teste: mudança de tela,
  callback destinatário, desabilitação e dispose deixavam a DialogRoute aberta.
- UtilityActions agora mantém geração e propriedade da rota; captura callback
  no momento da abertura, invalida em mudança/dispose e remove somente sua rota.
  O formulário verifica mounted/contexto antes de ler campos ou fechar.
- Controles adicionais: reconstrução equivalente preserva texto e entrega um
  draft; dispose com outra rota sobreposta preserva essa outra rota.
- 98/98 testes de app/shell e header_support_routing passaram, incluindo os
  seis testes novos. Analyzer três arquivos, format, diff check, validador
  visual e revisão independente read-only sem bloqueantes.
- Temas capturados, focus traversal fechado e motion reduzido explicitados.
  Nenhuma imagem golden alterada. Matriz visual global histórica não promovida.

# Limites

Callback de suporte continua síncrono e com contrato de protótipo existente.
O feedback local não prova persistência, envio remoto, identidade do solicitante
ou anexos reais. Não habilita suporte em rotas sem dependência injetada. Nenhuma
mutação externa foi feita. Memória no-op: restaura isolamento aprovado, sem nova
regra de produto. Coordenador recebe o delta para os rastreadores oficiais.
