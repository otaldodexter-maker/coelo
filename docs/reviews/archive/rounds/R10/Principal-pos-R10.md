---
source: Owner 13/09/2026; R10 fechamento; inventário vigente
status: encerrado parcialmente; pendências explícitas no corte
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

## Entrega por tela e subtela — recorte posterior à R10

Abertura registrada em aeb27341d às02:58:31 BRT de13/09/2026 (não inventar um T0 anterior ao registro). R10 permanece fechada. A tabela complementa o relatório completo de231ações; não apaga ressalvas históricas. C0 responde por implementação, integração e provas; Owner somente por H02/H13. Não iniciar nova rodada automaticamente.

| Tela/subtela | Avanço FE e prova | BE e primeiro gate restante | E2E / próximo passo C0 |
|---|---|---|---|
| Acontece / feed — acontece.feed | Host, cabeçalho único, títulos iguais, hover da marca, contexto no avatar e seleção múltipla; feed com PNG após reload. | Repository produtivo e R2 confirmados; contrato remoto preservado. | Provar combinações de papéis; preferência múltipla hoje não persiste no reload. Busca do dock continua sem callback, exige implementação própria. |
| Acontece / criar-publicar — acontece.create, acontece.publish | Card padrão, miniatura quadrada; picker PNG, legenda, público, salvar/publicar, retorno ao feed e reload realizados. | Edge/R2/RPC200 em origem3000;3016 rejeitada corretamente pelo CORS. | Antes de recertificar integralmente create, repetir negativa pertinente e múltiplos anexos/MP4. PNG publicado preservado. |
| Acontece / remover — acontece.remove | Aceite anterior preservado, sem nova mudança nesta ação. | Contrato de retirada preservado. | Não removido o post de evidência; reutilizar prova histórica válida, sem alegar teste novo. |
| Agora / visualizar — agora.view | Cabeçalho e título comum implementados. | Leitura produtiva existente; não foi repetida prova temporal. | Abrir Agora publicado pela rota normal e reler mídia/contexto no novo build. |
| Agora / criar-publicar — agora.create, agora.publish | Card padrão compartilhado; testes locais passaram. | Conferir fluxo próprio Edge now-media/R2 com origem autorizada. | Picker PNG/MP4, publicar, abrir viewer e reload. Não herda prova Acontece. |
| Agora / expirar — agora.expire | Sem nova alteração de UI. | Provar expiração do sintético já preparado pela janela/worker; não reaplicar SQL. | Ausência após expiração real e retenção conforme ADR0032. |
| Momentos / visualizar — momentos.view | Host/cabeçalho preservados pelo componente. | Contrato remoto existente. | Abrir coleção e viewer de imagem/vídeo no build atual, com reload e escopo autorizado. |
| Momentos / criar-publicar — momentos.create, momentos.publish | Card padrão compartilhado, testes locais passaram. | Provar fluxo próprio moments-media/R2; contexto continua singular. | PNG/MP4 no picker normal, publicar, abrir e recarregar. Bloqueio antigo de ferramenta não equivale a defeito do backend. |
| Momentos / remover — momentos.remove | Sem nova certificação. | Contrato de retirada existente. | Remover sintético pela UI, confirmar persistência e negativa pertinente. |
| Para você — principal.for-you | Destino do dock conectado, cabeçalho preservado e Ver como no avatar. | H13 CTA de comunicação permanece decisão Owner. | Validar atalhos próprios e contexto; múltipla seleção nesta tela não implementada. |
| Perfil/circulares — principal.profile-view | Rota do avatar conectada e identidade reage ao carregamento real. | Contratos existentes; sem mudança remota. | Conferir subtelas e links do perfil com reload; não confundir com dados oficiais de H02. |
| Editar perfil — principal.profile-edit | Host/cabeçalho compartilhados. | Sobre já tem correção local histórica; H02 segue decisão Owner. | Salvar Sobre pela UI e reler o mesmo perfil. |
| Circular / criar-editar-anexar — circulars.create, circulars.edit, circulars.attach | Card padrão também no compositor produtivo, mantendo ordem dos blocos. | Backend/R2 não alterados. | Prova visual própria e anexação produtiva/reload; anexo permanece sem aceite E2E novo. |
| Chat padrão do shell | Uma entrada: pílula desktop e círculo mobile acima do dock; ocultar temporariamente no seletor Ver como. | Backend de chat permanece o já integrado da R10. | Provar abrir conversa e MP4 pelo picker normal. Fotos inline/R2 foram entregues na R10, não testadas novamente aqui. |

Escopo restante transversal: múltipla seleção só Acontece; filtros em outros contratos continuam singulares. Verificar canPublish em perfis sem capacidade e contexto efetivo antes de ampliar aceite; autorização real permanece no servidor. Não declarar todos os menus concluídos.

Git: única worktree principal dev;27árvores encerradas arquivadas com ignorados e commits preservados,30refs históricas classificadas no manifesto. Referência histórica atrás/à frente não é trabalho perdido nem licença para reaplicar SQL. Checkout ativo deve terminar limpo e igual a origin/dev. Build servido localmente3000/3016; nenhum deploy público novo. Porta3016 serve UI, mas mídia precisa da origem3000 autorizada. Encerrar Chrome exclusivo9426 após a prova; manter build e servidor para retomada.

## Checkpoint visual final

Build279fd9de1: desktop claro confirmou pílula acima do dock, publicação mantida, contêiner e identidade; mobile confirmou cabeçalho único. Seletor múltiplo aplicou dois contextos reais e ocultou o launcher enquanto aberto. Inspeção visual detectou tonalização rosada/efeito de toque cinza do Material apesar do hover transparente: ajustados elevation0, superfície neutral0 no claro e highlight/splash transparentes no seletor. Teste de contexto1PASS. Screenshots anteriores context-white-multiple-final.png e context-mobile.png mostram o estado anterior e não são evidência de aprovação de cor. Prova da correção será identificada como neutral-accepted.

## Fechamento do recorte

Código final 01833e90b, build web PASS (65,2s), main.dart.js SHA256 c9c94dbe88812c7c8e1792dfdf0000efd425d747ae4ca96ae6587d5129607d97. Prova final em `context-neutral-light-accepted.png` (branco, dois contextos selecionados), `context-neutral-light-pressed.png` (sem efeito cinza após clique) e `mobile-light-final.png` (um cabeçalho, círculo acima do dock, PNG publicado preservado). `context-neutral-accepted.png` é a variante escura. Imagens anteriores são checkpoints de diagnóstico, não aprovação final. No contexto aberto o launcher desaparece; reaparece ao aplicar/cancelar. Drawer mobile abriu pelo botão Coelo. O feed mantém a publicação após reload e após nova compilação; mídia foi lida do Cloudflare R2 privado.

C0 fecha a fatia iniciada antes de atribuir novas correções, com margem do teto. Consumo real medido 86%; não estimado pela quantidade de mensagens. Abertura da extensão registrada às 02:58:31 BRT, execução desta extensão cerca de uma hora, abaixo da janela máxima. Nenhuma nova fatia delegada; nenhuma R11/Etapa 3. Chrome exclusivo 9426 encerrado, slot Flutter liberado, porta 3014 sem listener. Build/servidores locais 3000/3016, sessão sintética, fixture PNG, publicação e arquivos ignorados preservados para retomada. Não há WIP de código solto; pendências funcionais estão na tabela.

Os três rastreadores foram atualizados via apply-tracker-delta.cjs para 13 action_ids, validados em conjunto. Certificações históricas foram preservadas: a prova produtiva do PNG não promove automaticamente outros fluxos, nem substitui a negativa de escopo restante para recertificar create. O gate de memória validou a projeção team da ADR0037 e o gate de entrega da ADR0036. Gate Git/documental passou DOCUMENTED_PARTIAL após push, com uma worktree, sem stash, sem alterações locais e sem divergência ativa. O gate será repetido após este registro final.

Sete métricas do inventário permanecem as da R10: FE verified 177/231 (76,62%); FE local-green entre pendentes 13/54 (24,07%); aprovação visual formal 54/231 (23,38%); BE local-green entre pendentes 19/62 (30,65%); cobertura SQL 181/224 (80,80%); BE done 162/224 (72,32%); E2E 150/199 (75,38%). Nenhum denominador foi alterado e nenhum ganho foi atribuído à consolidação ou à mudança visual sem certificação completa. A aprovação visual formal pelo Owner não foi presumida durante sua ausência.

Primeiro gate de retomada: C0 recertifica acontece.create com a negativa real pertinente e múltiplos anexos/MP4 na origem 3000 já autorizada, reutilizando o post/fixtures, antes dos fluxos Agora/Momentos/Circular. Busca e demais contextos têm pendências próprias na tabela; H02/H13 permanecem com Owner. Entrega parcial do produto, consolidação encerrada e preservada.

Registro final UTC: 2026-09-13T06:52:43.456585+00:00
