---
title: "Navegador local — Acontece, Mensagens e gate de rota normal"
source: "Flutter web debug de ce03e063; navegador integrado; observação direta"
status: "local-smoke; fixtures; not E2E"
generated_at: "2026-09-08"
---

# Ambiente e resultado observado

`flutter run --no-pub -d web-server --web-hostname 127.0.0.1 --web-port 58343
--dart-define=COELO_APP_ENV=local`, sem configuração Supabase ou credencial.
Browser integrado, tema escuro observado, larguras1280 e375.

- `/dev/principal-happens` renderizou; títulos/ações dos painéis estavam em
  linha no desktop. Coluna ausente no compacto; sem overflow visual aparente.
- Reportar problema mostrou “O envio de problemas ainda não está disponível.”
- Mensagens levou a `/dev/conversations?from=principal`, tela canônica de Chat
  com fixtures; Voltar retornou ao Acontece.
- Em375, galeria abriu contextual fullscreen; Próxima mídia exibiu2de3 e imagem
  diferente; Escape retornou ao feed. Não foi alegada restauração de foco por
  essa interação de ponteiro.
- Navegação direta a `/principal-happens` terminou em `/login`, sem conteúdo
  de fixture na rota normal. Nenhuma credencial digitada e nenhuma escrita remota.
- Viewport restaurado e aba temporária fechada após inspeção.

# Limites

Esta prova é do runtime web local com assets sintéticos, não sessão de produção,
objeto R2, Stream, autorização backend, cache de mídia privado ou E2E.
Screenshots e árvore acessível foram inspecionados pelas ferramentas na tarefa;
nenhum PNG de referência promovido. Correção Chatclose posterior não foi
incluída nesse build; seus testes estão em evidência separada.
