---
title: "Acontece — isolamento da galeria por contexto"
source: "Contrato existente de isolamento Coelo; testes locais e revisão read-only E2E3"
status: "fatia local-green; dez goldens de feed preexistentes e E2E abertos"
generated_at: "2026-09-08"
---

# Recorte

Galeria de Acontece dentro do Superadmin, sem mudar escopo original E2E3.
Corrigir permanência da rota e resgate de mídia antiga quando o feed muda de
repository/escopo ou é descartado. Fora: SQL, produção, decoder, cache global,
expiração, habilitação R2 e apps Admin/Principal/Site. Ordem: RED, correção,
regressão, comparação com baseline e revisão. Critério: isolamento local
demonstrado, sem declarar o domínio entregue E2E.

# Evidência

- Dois REDs reproduzidos: galeria antiga persistia após troca; troca antes da
  construção da galeria ainda resgatava mídia do repository anterior.
- A página possui sua DialogRoute, captura dependências e geração de abertura,
  invalida callbacks e remove somente sua rota após o frame. Dispose não
  remove outra rota sobreposta. Foco só retorna ao contexto vigente.
- Resgate da galeria começa após o frame e verifica mounted, geração e contexto
  antes e depois do await. A resposta tardia sintética image/png não cria uma
  Image/NetworkImage com a URL antiga no contexto novo. Isso é prova de widget,
  não prova HTTP nem de purge do cache.
- 33/33 testes funcionais da feature Principal Acontece passaram.
- 10/10 goldens da galeria passaram: claro/escuro em 375, 768, 1024 e 1440,
  texto 200% e estado de vídeo honestamente indisponível. Nenhum PNG alterado.
- A execução integral anterior ao reforço pós-await terminou 43 PASS / 10 FAIL.
  Os dez FAIL são composição do feed (oito tamanhos/temas, texto 200%, hover).
  A versão anterior fb241618 foi reproduzida em duas cópias diagnósticas locais
  contra os mesmos PNGs: 10 PASS de galeria / os mesmos 10 FAIL de feed.
  Exemplos: light375 0,63%/2122px, dark1440 3,82%/54961px e hover1440
  3,81%/54850px. As duas cópias foram removidas após a contraprova.
- Analyzer dos dois arquivos, format, validador visual e revisão independente
  read-only passaram. O achado de revalidação pós-await foi incorporado.

# Limites e memória

As divergências visuais do feed permanecem abertas; a suíte integral não está
verde. O transporte legado, URLs temporárias, expiração e cache não foram
substituídos pelo MediaSession neste delta. Não houve acesso a mídia privada,
mutação remota, publicação ou concessão de autorização. Memória no-op: restaura
isolamento já aprovado, sem nova regra de produto. Rastreador oficial permanece
sob escrita exclusiva do Coordenador, que recebe esta evidência no handoff.
