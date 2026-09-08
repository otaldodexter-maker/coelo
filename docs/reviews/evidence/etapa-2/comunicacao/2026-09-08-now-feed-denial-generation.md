---
title: "Agora — resgates por geração e limpeza na negação"
source: "Quatro REDs executados pelo root, revisão independente e testes locais"
status: "local-green; not E2E"
generated_at: "2026-09-08"
---

# Falhas reproduzidas

1. Negativa da mídia ainda era seguida por solicitação de áudio.
2. Resgate antigo negado durante refresh contaminava listagem nova autorizada,
   mantendo o painel de negação sem retry.
3. Negativa da listagem durante refresh retinha resposta privada e opções.
4. Substituir repository carregava a resposta privada de A no feed de B.

# Correção

Resgates, continuações e finalizers respeitam a geração do feed. Início do
carregamento limpa referências de itens/tickets e chaves em resolução.
Negativa de listagem ou mídia usa o mesmo tratamento: encerra geração,
interrompe progresso, fecha somente opções próprias, limpa resposta e referências
protegidas, mantém estado negado sem retry implícito. Troca de repository/scope
limpa também a resposta. Nenhuma regra nova de autorização ou produto.

# Provas locais

- Cinco testes adicionados: quatro reproduções acima e áudio negado com
  resposta/opções abertas. Teclado após negação não inicia novo resgate.
- 59/59 feature Agora incluindo goldens existentes; nenhuma imagem atualizada.
- Analyzer dois arquivos, format e diff check passaram. Revisão read-only
  verificou geração/finalizers e pediu a contraprova de negação da listagem,
  que foi reproduzida e corrigida pelo root.
- Contratos compartilhados reexecutados antes desta fatia:45/45 coelo_api/media,
  40/40 Deno de métricas de imagem/transportes R2. Lockfile gerado pelo teste
  do pacote foi removido; é regenerável e não continha trabalho preexistente.

# Limites

Futures controladas e adapters locais, sem HTTP real, R2, Stream, SQL, sessão
produtiva ou revogação server-side. Não substitui os gates M03/N01 nem prova
E2E. O smoke browser anterior antecede esta correção; não reclassificá-lo como
teste deste delta. Memória de produto sem nova regra durável aprovada.
