---
title: "Cabeçalho global — troca do controlador de notificações"
source: "Lifecycle existente do shell e ActivityCenter; TDD e revisão read-only E2E3"
status: "local-green; notificações remotas e E2E abertos"
generated_at: "2026-09-08"
---

# Recorte e execução

Injeção de activityController no shell global Superadmin, sem alterar domínio
de notificações, logout, importação/exportação ou backend. Ordem: reproduzir
dependência congelada, corrigir ownership e executar regressão/review.
Critério local: shell acompanha dependência nova e descarta somente o que cria.

- Três REDs: externo A para B, externo para local e local para externo. O campo
  late final preservava o controlador inicial em todas as reconstruções.
- didUpdateWidget atualiza controlador e ownership juntos. Descarte do antigo
  local ocorre após o frame para ActivityCenter desligar listener/open-state.
  O shell nunca descarta externos, inclusive na desmontagem posterior.
- Testes com painel aberto verificam controlador/conteúdo atuais, descarte dos
  locais e que novas conclusões do controlador externo antigo continuam não
  lidas. Sem mudar a semântica existente de transferência do painel aberto.
- 101/101 app/shell e header_support_routing passaram. Analyzer dois arquivos,
  format, diff check, validador visual e revisão read-only sem bloqueantes.

# Limites

Fixtures usam atividades sintéticas existentes; nenhuma importação/exportação,
download ou notificação remota foi executada ou habilitada. Não prova conexão
Realtime, persistência, permissões ou E2E. Memória no-op: correção do lifecycle
existente. Coordenador recebe o delta para os rastreadores oficiais.
