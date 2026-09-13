---
source: Owner 13/09/2026; R10 fechamento; inventário vigente
status: em execução
generated_at: 2026-09-13
---

# Correções do Coelo (Principal) após consolidação

Base 87d465e2d, checkout único dev. Pedido explícito posterior à R10; não reabre a rodada nem inicia Etapa 3. Recorte apps/superadmin > Coelo (Principal): Acontece, Agora, Momentos, Para Você, Perfil e publicadores/subtelas. Reutilizar aceites e fechar primeiros gates executáveis do relatório R10-estado-por-tela. Fora: demais menus/apps e decisões nominais H02/H13 ainda abertas.

C0 possui Chrome headless CDP9426, build R10 preservado3016 e slot único flutter test/build. Nenhum auxiliar recebe nova fatia funcional neste corte de consumo. Parada: consumo medido, teto90% e margem para testes/publicação/MDs; priorizar fechar até88%. Estimativa será calibrada pela reprodução do primeiro defeito, sem promessa de concluir todas as ações.

Primeiro gate: reproduzir publicação pela rota normal com contexto real e mídia sintética; corrigir causa encontrada, provar persistência/reload e registrar por camada. Pendências conhecidas: Acontece create recertificação do compositor; Agora create/publish/view/expire; Momentos create/publish/view/remove; Para Você H13; Perfil Sobre save/reload, H02 dados oficiais permanece decisão.

## Checkpoint de implementação

Owner confirmou: contêiner Principal restaurado; um único launcher padrão, pílula desktop/círculo mobile acima do dock; seletor vazio de mídia igual ao card Criar instituição em todos os publicadores; miniaturas alinhadas; seletor Ver como branco sem hover cinza/seleção laranja e seleção múltipla; Ver como deve migrar para o avatar do cabeçalho superior direito, preservando o cabeçalho.

Reprodução real CDP9426/3016 com qa-r06-principal: Acontece tinha dois launchers, destinos do dock sem callback e filho bruto sem floating-content no host; publicador abriu pela rota normal. Teste RED confirmou frame ausente; correção local com 12 testes PASS (inclui posição do launcher375/1440). Card de criação extraído para core neutro com aliases administrativos, reutilizado em Acontece/Agora/Momentos/Circular. Miniaturas Acontece agora quadradas64. Testes de publicação75PASS/1FAIL: overflow375 texto200 no card de mídia novo, em correção. Nada deste delta certificado pela UI até atualizar build. Backend/SQL não alterados. Consumo medido85%.

Próximo gate C0: corrigir overflow, fechar cabeçalho/contexto e seleção múltipla com leitura autorizada real, verificar build único e rotas; publicar e sincronizar rastreadores.

## Checkpoint cabeçalho e contexto

ADR0037 captura os pedidos posteriores. Contêiner, launcher, navegação, card e overflow corrigidos localmente. Acontece/Agora com titleLarge comum. Cabeçalho compartilhado mostra identidade real e menu Ver como. Leitura múltipla do Acontece consulta cada escopo autorizado, deduplica e mantém paginação pelo cursor global; testes de ordenação/reload/negação passaram. Seleção múltipla nos demais feeds ainda não implementada, pois seus contratos permanecem singulares; não certificada nem simulada. 6 testes de contexto/rota PASS; 23 testes de composição/publicador Acontece PASS depois de resolver overflow. Agora/Momentos tiveram58 testes PASS na primeira execução. Nenhum SQL novo. Próximo: regressão do card compartilhado e Circular, análise, build e prova real dos anexos/correções.

## Checkpoint de prova e fechamento do build

Base 7c6b5607d; C0 mantém a única worktree dev e Chrome9426. Build 0663a0322 servido3016 (SHA JS 5c61315aada8fd2e3533dee988a4519b7a9a95510d740180ba9bdca69bfd73c9): rota normal abriu publicador com card branco, cabeçalho e avatar OD; feed com duas instituições selecionadas mostrou publicações existentes. Screenshots em evidence/etapa-2/principal-pos-r10. Avatar passa a observar carregamento assíncrono da conta. Estado vazio agora distingue contexto sem publicação de ausência de novidades. Circular produtiva também recebe o card, preservando inserção ordenada dos blocos. 25 testes focais PASS e analyze de três arquivos sem problemas. Consumo real86%; congeladas novas fatias, próximo gate: rebuild serial, prova mobile/desktop e registro final. Sem SQL ou deploy remoto novo. Não há aceite novo de CRUD/RLS nesta etapa.
