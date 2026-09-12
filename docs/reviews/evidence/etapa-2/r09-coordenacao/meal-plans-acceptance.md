---
source: C0 UI normal; G4 scopeRules contract; Supabase production and mirror
status: verified
generated_at: 2026-09-12
---

# Cardápios — ciclo produtivo

apps/superadmin -> Operação -> Cardápios -> diretório/assistente/publicação ->
meal-plans.list, meal-plans.create, meal-plans.edit, meal-plans.publish.

Após corrigir a entrada development-only (36ef3a43e), C0 abriu Cardápios
pelo menu normal. Aba Modelos mostrou o sintético R06 preservado; aba Cardápios
mostrou o sintético R08 arquivado preservado. Criar cardápio abriu assistente
com opções reais autorizadas. Selecionados QA R04 Cuidado (sintetico) e
Unidade QA R04; nenhuma turma disponível nesse seletor, sem inventar vínculo.

Criado QA R09 Cardapio sintetico 1542, público Alunos, período12–18/09/2026,
recorrência semanal Seg–Sex, uma refeição sintética sem imagem. Salvar rascunho
persistiu57ab05c3-32c6-44ae-b1d4-45180fbc9124. Menu Ações -> Editar -> reload
manteve nome, período e instituição/unidade. Alterados nome e refeição para
os sufixos editado; Enviar e publicar salvou, enviou e publicou. Diretório
mostrou Publicado; reload e seleção da aba Cardápios mantiveram nome/status.
Imagens meal-plan-created/created-reload/published/published-reload e
meal-plans-list comprovam a rota. Aba inicial volta a Modelos após retorno
ou reload, comportamento observado, sem alegar persistência da aba.

SQL produtivo confirmou name editado, status published, revision4,
tenant d0c40000-0000-4000-8000-000000000001 e scope_rules objeto com essa
instituição e unidade d0c40000-0000-4000-8000-000000000002.
Migration20260911130500_meal_plan_scope_rules_object_v1 consta uma vez no
ledger produtivo, conforme fila R08/lote55; nenhuma reaplicação.
Campos consultados period_start/end eram inexistentes no JSON e resultaram
null; não são as datas reais, que usam contrato startDate/endDate.

Consumidor normal independente meal-plan-consumer.py/.json:6PASS, incluindo
Auth/logout próprios. Anônimo401; get200 confirma versão4/publicado/nome;
conteúdo da refeição editada persistido; list200 contém o mesmo ID publicado.
Primeira execução do script falhou no import de arquivo com hífen antes de
qualquer HTTP; import corrigido, execução completa verde. Nenhuma sessão
injetada ou alteração da sessão do navegador.

Prova de RLS/capacidades: ampliado o teste existente scope_rules_object de9
para16 assertivas no espelho com rollback. Ator escopado B cria/lê o próprio
cardápio, mas RLS oculta A; get/edit/publish de A negados P0002 sem vazamento;
nome de A preservado. Primeira execução11PASS/3FAIL esperava42501; corrigida
expectativa para o contrato not-found P0002 e acrescentado controle positivo
do ator B. Final16PASS/0FAIL/0SKIP. Logs inicial/final preservados.
Paridade atual:40 corpos de funções (inclui has_platform_permission),4
policies de meal_plans e RLS forçado iguais em produção e espelho.
Arquivos meal-plan-parity.sql, meal-plan-remote-parity.json e resultado.
Não executada nova sessão Auth real tenant B; prova de tenant é pgTAP na
base equivalente, complementada por negativa anônima produtiva.

Navegação:25 testes únicos PASS, análise0issues, build release58,8s exit0.
Chrome22592/servidor48684/3014; ambas emulações false. Aviso CupertinoIcons
do dry-run preexistente permanece, sem falha de build. Não é deploy remoto.

Aceites: list BE/E2E; create/edit/publish FE/BE/E2E. FE list já verificado,
preservado sem contar novo; aprovação visual e cobertura SQL não crescem.
Sem imagem/anexo nessa fatia; não certificar upload de imagem. Sintético
publicado retido, sem criar modelo, chave, mídia ou vínculo artificial.
Memória: contratos existentes restaurados, sem regra durável nova.
