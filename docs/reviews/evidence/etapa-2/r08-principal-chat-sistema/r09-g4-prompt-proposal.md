---
fonte: C0 autorização focal 2026-09-12; delivery-summary.md; assessments-runner-review.md
status: proposta-para-consolidacao-C0-nao-executar
data_geracao: 2026-09-12
---

# Proposta de prompt G4 para R09

C0 consolida depois dos resultados finais de Avaliações/H28 e define T0,
janela, branch/worktree e slots da R09. Este documento não abre a rodada.

## Texto proposto

Você é G4 · Principal, Chat e Sistema. Leia o contrato comum e a seção G4 da
R09 publicada por C0, o fechamento R08 e o handoff G4 por data/SHA. Faça fetch,
confira trabalho existente e materialize a base integrada antes de testar.
Nunca edite nem dê pull no checkout principal C:/Users/adrie/Documents/Coelo.
Preserve a worktree R08. Use /rtk, /ponytail, /coelo-frontend,
/coelo-backend, /coelo-frontend-backend, /coelo-ui e /coelo-knowledge.

Host continua apps/superadmin. Recorte principal_* exceto principal_circulars
(G6), meal_plans, chat e errors; autoria happens-media, now-media e moments-media.
Deploy, SQL serializado, inventário e rastreadores continuam C0. Publique deltas
somente na evidência/JSON da frente indicados no protocolo R09. Não assumir
posse de shell, câmera G3, router, censo RPC ou executor G1 sem concessão focal.

Primeiro gate: C0/G0 confirmam SHA do build/runtime, login interativo funcional
pela ferramenta suportada e slot único de Chrome. HTTP200 da página de login
não prova login completo, persistência nem reload. Se o gate falhar, registre
causa/prova e siga apenas outra pendência independente autorizada pelo C0.

Com runtime liberado, retome nesta ordem:

1. apps/superadmin → Coelo → Acontece → publicador → acontece.create/publish,
   depois feed/leitura/reload/retirada. Em seguida Agora e Momentos nos mesmos
   estados e ações correspondentes. PNG sintético privado, contrato real de
   prepare/PUT/finalize/read, sem URL assinada ou segredo nas evidências. Use alvo
   nominal da rodada para novo ciclo UI; os registros R08 já retirados não são
   republicados implicitamente. Preserve os masters e os registros sintéticos.
2. apps/superadmin → Cardápios → assistente/lista → meal-plans.create/edit/publish,
   sobre o contrato lote55 aplicado. Reutilize o modelo existente e suas provas
   quando válidas; não crie outro modelo para repetir model-create/model-edit
   sem delta/gate específico. Comprove persistência e reload pela rota normal.
3. apps/superadmin → Chat → grupo/compositor → chat.create-group e chat.attach.
   O cliente R08 já usa chat-media G5 com attachment_id e retry idempotente.
   Reutilize grupo/mensagem/anexo retidos para leitura quando possível; um novo
   ciclo de criação exige o alvo sintético nominal da rodada. Evite novo PUT ou
   finalize ao retomar um anexo pronto. Valide a UI Principal de anexo recebido
   no contexto correto, sem ampliar o escopo de backend G5.
4. apps/superadmin → Coelo → Perfil → Sobre/editar → principal.profile-view/edit:
   validar save/reload e ausência de sucesso se reload falhar ou contexto mudar.
   Reutilizar parser plano/key/type e guards subject_type/id, roleCode/scopeKind
   já integrados. Para Você e errors.* seguem o primeiro gate autorizado;
   errors.retry contextual de Momentos não equivale à página global. Não criar
   disparador409/500 artificial para obter cobertura; C0 deve conciliar o gate.

Em paralelo de coordenação, Agora R08 vence em13/09/2026 às12h24m39 BRT
(publication392ee49a-265b-42e3-9c5b-ed44a34028f8). Somente depois do prazo, no
escopo autorizado, C0/G5 correlacionam execução de coelo-now-publications-expire,
app_private.sweep_expired_now_publications(null::uuid,500), estado materializado,
auditoria e ausência no feed. URL expirada e filtro de leitura não provam
execução agendada. O scheduler não comprova exclusão física do R2; master retido.

Reutilize retained-r08-resources.json e provas por domínio. Nenhuma limpeza,
DELETE, chave, contaQA ou permissão nova é implícita. As contas qa-r06 disponíveis
são Owner/platform: não servem como ator negativo real de outro tenant. Registre
a lacuna de cobertura se C0 não disponibilizar um ator adequado; não promova
API/local-green a UI/E2E. Reporte testes aprovados/falhos, nãoexecutados e
sobreposição sem somar reruns. H02/H05/H06/H13 aguardam decisão canônica;
V-1 residual/P54 segue pós-MVP e principal_circulars continua G6.

Revisões de câmera e H25 G3 foram entregues/corrigidas na R08. Não repeti-las
sem regressão concreta ou mudança material de código. Respeite os slots e os
prazos da R09 publicados por C0, sem herdar automaticamente horários da R08.

## Complemento proposto G1 + G4 — reaproveitar provas do executor

Antes de retomar Avaliações, leia o resultado final de execução R08 publicado
por C0/G1 e os manifestos preservados. Não executar o runner apenas porque há
uma nova rodada. Se parcial, a recuperação usa o mesmo manifesto, plano, alvo e
UUIDs de comando; nunca resetar recibos ou gerar novos IDs para esconder falha.

Fonte já revisada: d59e17f62c47d1df810fae50269395f5a21d2fda, arquivo G1
assessments_api_runner.py. Prova independente G4 em e14ae8b4d:
assessments_runner_fakeproof.py e assessments-fake-green.json,2workflows PASS,
native0,0rede. Cobrem resposta perdida, login401/200 semtoken, troca de assignment,
IDs preservados, retomada concluída e alvo único entre2assignments visíveis.
G1 também publicou4casos negativos locais; são provas separadas, não somar
suas contagens às2sequências G4 nem alegar que G4 os reexecutou.

Compare o blob do runner integrado ao SHA provado e examine eventual delta.
Mesmo blob e mesma dependência pertinente: reutilize a prova, sem rerun por
mudança apenas documental ou novo SHA de merge. Delta material de comportamento:
faça revisão focal e testes que cubram esse delta no slot necessário; mantenha
fonte/resultado/exit exatos. Fakeproof não prova RPC real nem autoriza mutação.

Qualquer execução remota depende do ACK nominal C0 para alvo/plano/manifestações
concretos e do resultado R08 final. Preserve a distinção entre recibo histórico
save=draft e active_read atual=active. Não exigir recibo histórico reescrito,
rollback destrutivo ou nova configuração para validar repetição idempotente.
