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
