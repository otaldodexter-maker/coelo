---
fonte: protocolo R08; instrução nominal C0 2026-09-12 14h22; manifests G4; origin/dev 593c6a57e
status: handoff-da-frente-para-revisao-C0
data_geracao: 2026-09-12
---

# G4 — entrega consolidada R08

Corte antecipado nominal: entrega das frentes até14h40 BRT; revisão14h40–14h50;
publicação e fechamento C0 até15h00. Substitui os cortes relativos anteriores,
preservando T0 histórico10h52m16. R09 é proposta; não foi iniciada.

Recorte: apps/superadmin → Coelo (Principal), Cardápios, Chat e erros. Autoria
happens-media/now-media/moments-media. principal_circulars permanece G6;
V-1 residual/P54 pós-MVP não foi expandido. Deploy, SQL, inventário e
rastreadores pertencem ao C0. Nenhum novo aceite UI/E2E é proposto nesta entrega.

## Código e integração

Fetch/check de ancestralidade em12/09,14h28: origin/dev593c6a57ebc6af51e08e20e603458ad8b4f5f00a
contém todos os sete commits de código abaixo. Não se confunde integração Git
com publicação do app; deploy segue C0.

| Commit | Entrega e prova local |
| --- | --- |
| 1d09cb3c8 | CORS Momentos/x-client-info;27DenoPASS; deployv10 atribuído C0 |
| e5e0797c7 | Cliente chat.attach usando attachment_id, prepare/PUT/finalize/read e retry;56PASS |
| fee190810 | PUT assinado sem redirect e headers/MIME coerentes em4adaptadores;28PASS |
| 9bee7eb26 | Anexos recebidos no Principal, contexto/purge e viewer compartilhado;101IDs com43PASS prévios+58focais finais, não execução única |
| 9863512b9 | Perfil confirma save somente após reload aceito; contrato Sobre plano/key/type;37PASS |
| b58cbaec9 | Parser confere subject_type/id; editor relê ao trocar roleCode/scopeKind;43PASS |
| 2f0aef225 | View descarta resposta tardia/troca de contexto; censo RPC aceita SQL quoted e exclui pgTAP no Windows;16+7PASS |

As suites se sobrepõem: não somar esses números. Logs RED históricos preservados
não são falhas atuais. Analyze focal verde em cada pacote. C0 reportou Perfil
integrado23PASS e analyze global0 no ciclo180. Não foram repetidos aqui.

Ainda fora da ancestralidade de dev no snapshot:00def54c7 (revisão G3/menu e
memória H25) e e14ae8b4d (fakeproof executor G1). Integram somente evidências,
script offline e JSON da frente. O commit deste handoff será informado no chat.

## Provas reais de API e limite do aceite

| Superfície → estado → action_id | Resultado atual e fonte | Não comprovado nesta rodada |
| --- | --- | --- |
| Coelo → Acontece → publicar/ler/retirar → acontece.create/publish/remove/feed |23checks PASS; PNG privado82bytes, hash/reload/TTL e retirada200; happens-api-proof.md | UI e ator real de outro tenant |
| Coelo → Agora → publicação/feed → agora.create/publish/view/expire |19checks PASS; PNG privado/reload/TTL; now-api-proof.md; scheduler H09 comprovado C0 | UI, outro tenant e expiração desta publicação após24h |
| Coelo → Momentos → publicar/retirar → momentos.create/publish/remove/view |Lote58 resolve retirada403; retirada200, reload ausente, outro consumidor403; moments-api-proof.md | UI e outro tenant; read200 pelo autor é contrato válido |
| Cardápios → assistente/lista → meal-plans.create/edit/publish/list |24checks PASS sobre lote55; plano1→5 arquivado, modeloexistentev2 preservado; meal-plan-api-proof.md | UI atual e novo CRUD de modelo nesta rodada |
| Chat → grupo/compositor → chat.create-group/attach |Grupo e PNG criados uma vez; continuação26checks PASS, hash/reload/replay sem novoPUT, TTL300s; chat-api-proof.md | UI e outro tenant |
| Coelo → Perfil → Sobre/editar → principal.profile-view/edit |Correções locais acima; leituraQA de3sujeitos200null; profile-contract-proof.md, profile-subject-proof.md, profile-consumers-review.md | Save/reload real por UI; null não prova ausência absoluta |
| Coelo → Para Você → principal.for-you |Contrato e backlog revisados; sem novo teste de UI | Novo aceite R08 |
| Erros →403/404/409/500/503/retry → errors.* |Mapa produtivo em errors-route-map.md e proposta deltas-errors-gates.json |409/500 sem disparador global normal; retry de Momentos é contextual, não prova página global |

As contagens de API são checks/operações, não IDs únicos de testes ou ações.
A falha histórica Chat27PASS/1FAIL esperava403 onde R2 sem assinatura retornou
400; continuação corrigiu o oráculo, sem recriar recursos. A falha histórica
Momentos8PASS/1FAIL esperava negar ao autor após retirada; leitura do outro
consumidor confirmou403. Não mascarar esses históricos nem contá-los novamente.
As contasQA disponíveis são Owner/platform; não equivalem a negativa cross-tenant.

## Runtime e próximo gate proposto para R09

G0 informou runtime14h23/PID14072/loginHTTP200 em b0e35cb76. Disponibilidade HTTP
não demonstra login interativo concluído nem CRUD pela UI. Nenhum Chrome,
Flutter test, servidor ou runner G4 permanece ativo. Não foi utilizado slot
sem concessão C0. Não há nova mutação remota neste fechamento.

1. C0/G0 confirmam build publicado/base integrada, login interativo suportado e
   concessão do Chrome único. A prova deve começar pela rota normal em
   apps/superadmin → Coelo → Acontece → publicação → acontece.create/publish.
   Se login continuar bloqueado, registrar esse gate e seguir tarefa independente
   nominal; não substituir resultado visual por API ou rota /dev.
2. Reutilizar os recursos do manifesto para leitura/reload; Acontece/Momentos já
   retirados não devem ser republicados silenciosamente. Novo PNG para comprovar
   o ciclo completo pela UI precisa do alvo/escopo nominal da próxima rodada.
   Depois, Agora/Momentos, Cardápios e Chat, na ordem do contrato G4.
3. Agora vence13/09/2026 às12h24m39 BRT. Na rodada autorizada após esse prazo,
   C0/G5 correlacionam cron, registro materializado de expiração/auditoria e
   ausência no feed. Um filtro de leitura ou URL expirada não prova execução
   agendada. Não acionar limpeza física de R2: o master segue retido.
4. Perfil: validar save e reload no contexto autorizado, incluindo erro sem
   confirmação de sucesso. H02/H05/H06/H13 aguardam decisão canônica, conforme
   contratos-h02-h05-h06-h13.md. Não expandir P54/V-1 nem principal_circulars.
5. Erros: C0 concilia action_id/fluxo contextual antes de exigir wiring global
   novo. deltas-errors-gates.json propõe esclarecimento, não promove estados.

## Revisões independentes entregues a C0

- Câmera G3: purge durante finalizeTree reproduzido/corrigido pelo autor;
  camera-review.md. Não certifica câmera física/R2/UI.
- H25 G3: overflow ordenado em coluna80/90 e regressão de pintura encontrados;
  fixf0e148a70 conserva goldens,37PASS atribuídos G3/C0; h25-review.md.
- Menu Perfil G3: minHeight48 no alvo;8PASS atribuídos G3, sem PNG novo;
  profile-menu-review.md. Não declara AA global.
- Executor Avaliações G1:3achados corrigidos; fonte final
  d59e17f62c47d1df810fae50269395f5a21d2fda; assessments-runner-review.md.
  assessments_runner_fakeproof.py + assessments-fake-green.json:
  2workflows PASS/native0, zero rede e credenciais reais. Resposta perdida,
  retomada/IDs/recibos preservados, auth falha sem complete, assignment divergente
  recusado e alvo único entre2assignments. As mutações do manifesto são
  simuladas. Não autoriza execução remota nem certifica backend/Avaliações.

## Dados, chaves, retenção e memória

retained-r08-resources.json é a lista exata dos recursos R08: Acontece/Momentos
retirados com masters privados preservados; Agora publicado aguardando prazo;
Chat mantém grupo/mensagem/anexo; Cardápio arquivadov5 e modelov2 intacto.
IDs e hash sintéticos constam ali e nos manifests por domínio. Sem DELETE,
limpeza, contaQA, segredo, bucket, Worker ou chave nova criada por G4.
Nenhuma URL assinada/token foi registrada. Artefatos ignorados de Python podem
permanecer como cache local; não são WIP de produto nem evidência entregue.

Não há alteração de contrato de produto nova para capturar. Memória H25 de
65f219550 está na base integrada e foi conferida contra Design System,
coelo-ui e projeção de conhecimento. Sem arquivo de memória só para atividade.

Worktree preservada. Sem stash ou código WIP G4 no snapshot; o commit/push deste
handoff fecha apenas documentos/JSON. Permanecemos disponíveis para ajustes
focais C0 até14h50, conforme marco nominal antecipado.
