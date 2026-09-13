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

## Checkpoint 03:37 BRT — origem da mídia

Build final 7c76190fa, JS SHA256 74fc8a59462fbe40523f5e00a7897e9a1a4d3c5afc0b7d4d05167564140a2445; build66,2s PASS, aviso conhecido de fonte CupertinoIcons. PNG sintético320x180 selecionado pelo picker nativo (CDP fileChooser); miniatura64x64 alinhada e prévia corretas em tema claro. save_happens_draft200, upload interrompido no preflight da Edge happens-media403 (PreflightMissingAllowOriginHeader). Diagnóstico: origem3016 não permitida, localhost3000 e127.0.0.1:3000 retornam OPTIONS200 com origem correta. Não ampliar allowlist; repetir na origem já autorizada com mesmo build. Rascunho sintético permanece no servidor, mídia local preservada em media-qa.png; não declarar publicação concluída. Prova visual anterior publisher-empty-desktop foi no tema escuro, corrigindo a descrição de branco daquele checkpoint. Consumo86%.

## Checkpoint 03:44 BRT — publicação e mobile

Na origem autorizada127.0.0.1:3000, o mesmo rascunho reapareceu com legenda/público persistidos. Picker PNG normal, save200, happens-media200, PUT R2 200, finalize200, publish_happens_post200; retorno ao feed e reload mantiveram foto e legenda. Provider Cloudflare R2 confirmado por host da requisição, sem salvar URL assinada. Post sintético a46f62d9-23b9-4b0a-bf27-35ea22e9c9e1 preservado; evidências publish-authorized-network.json e feed-reload-desktop.png. Não houve SQL/deploy remoto. CORS3016 era erro de ambiente, não defeito funcional do upload. Mobile375 revelou dois cabeçalhos: compact shell e contexto. Corrigido para somente cabeçalho Principal nas rotas hospedadas, mantendo acesso ao drawer pelo botão Coelo. Teste focal5PASS (primeira tentativa teve erro de compilação no texto do teste, resolvido); contexto1PASS. Launcher círculo48 acima do dock confirmado; prova final após rebuild pendente.
