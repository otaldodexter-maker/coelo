---
title: "Rodada 8 — plano operacional e divisão de capacidade"
source: "R07-fechamento.md; R07-varredura-r01-r07.md; R08-backlog.md; ADR 0034; pedido do Owner de 12/09/2026"
status: "proposto; nao iniciado; executar somente quando o Owner abrir as conversas"
generated_at: "2026-09-12"
timezone: "America/Sao_Paulo"
---

# R08 — plano de implementação e verificação

> Para executores: usar a skill executing-plans no próprio recorte, com
> checkpoints; delegação somente se expressamente autorizada. Este documento
> prepara as conversas, não as inicia.

**Objetivo:** fechar gates reais restantes da Etapa 2 em apps/superadmin,
reutilizando o código integrado e as provas válidas de R01–R07.
**Arquitetura:** C0 é o único integrador e publicador. G0 cuida do ambiente;
G1–G7 entregam fatias por família; G8 corrige testes textuais em recorte
restrito. Um Chrome e um flutter test por vez na máquina inteira.
**Stack:** Flutter/Dart, Supabase/Postgres, Edge Functions/Deno, R2 privado,
Git/worktrees, rastreadores gerados por Node.

## Resultado esperado e limites

A R08 não é uma promessa de fechar tudo em quatro horas. O primeiro alvo é
um ambiente demonstradamente utilizável e entregas E2E publicadas no mesmo
ciclo. Nada de contar build, mock ou OPTIONS como CRUD real.
Apps Admin, Principal separado, Site e exportações gerais pós-MVP ficam fora.
Nenhuma decisão visual pendente é resolvida por regravar o golden.
Não reexecutar provas válidas de famílias intactas apenas para gerar números.

## Escolha de modelos — recomendação, não troca já executada

| Conversa | Modelo / esforço | Motivo e limite |
| --- | --- | --- |
| C0 Coordenação | GPT-6 Astra médio | integração, julgamento de provas, segurança e conflitos |
| G0 Ambiente e runtime | GPT-5.6 Sol médio | Docker/WSL/CDP, build e sessão; escalar ao Astra se a causa continuar ambígua |
| G1 Estrutura | GPT-5.6 Terra médio | fluxos existentes, fixtures e testes bem delimitados |
| G2 Acessos e Pessoas | GPT-5.6 Terra médio | CRUD/@/perfis; revisão C0 obrigatória na fronteira Auth |
| G3 Formulários/Cuidado/Rotina | GPT-5.6 Sol médio | mídia, reconstrução e regressão compartilhada |
| G4 Principal/Chat/Sistema | GPT-5.6 Sol médio | cliente + gateway/R2 e sessões reais |
| G5 Realm/segurança | GPT-5.6 Sol médio | SQL/RLS transversal; C0 Astra revisa antes de aplicar |
| G6 Publicações/Agenda | GPT-5.6 Sol médio | editor de blocos intercalados, anexo/resposta e conciliação do host |
| G7 Operações | GPT-5.6 Terra médio | recorte previsível de Conta/Suporte/Catálogo |
| G8 Suítes pré-existentes | GPT-5.3-Codex-Spark médio | testes textuais e censo; sem analisar/regravar imagens |

Economia maior: não abrir dez execuções pesadas simultâneas. C0 e G0 primeiro;
demais frentes só após recibo de ambiente mínimo. G8 pega janela de teste
separada, sem concorrer com provas do app. Luna fica como opção para
normalização documental ou mudança mecânica cujo resultado já esteja definido,
não como substituição geral da coordenação.

Spark é text-only e tem limites próprios. Na leitura de conta em 12/09
havia 0% usado nas janelas reportadas do Spark; disponibilidade muda.
Não há promessa de economia percentual: duração, tamanho do contexto e
retrabalho afetam o consumo. Usar velocidade Standard, evitando Fast para
economizar; a documentação informa multiplicador de 2,5x em Fast para
GPT-5.6 e Astra. Nenhuma configuração global foi alterada.

Fontes oficiais consultadas em 12/09:
[escolha de modelos](https://learn.chatgpt.com/docs/models),
[Spark e velocidade](https://learn.chatgpt.com/docs/agent-configuration/speed).
A alocação acima é recomendação do coordenador com base nos gates do Coelo.

## Sequência e relógio

- [ ] C0 registra T0 real, round novo e revisões recebidas; publica em dev.
- [ ] G0 verifica Docker sem reset destrutivo e confirma daemon/espelho.
  Em paralelo ao diagnóstico, prepara UM build QA, servidor e navegador.
- [ ] Antes de liberar E2E, G0 prova: rota de login carrega, comando ao
  navegador responde, login sintético funciona, uma leitura autorizada e
  reload mantêm a sessão. Publica comando/porta/SHA e captura sem segredo.
  Não usar somente HTTP 200 de index.html como prova do runtime.
- [ ] Se o Chrome não responder em duas tentativas materialmente distintas,
  G0 publica causa/primeiro gate; C0 permite trabalho local independente,
  mas não deixa sete frentes repetirem o mesmo diagnóstico.
- [ ] C0 publica fila exclusiva de Chrome e fila exclusiva de flutter test:
  dono, início real, expiração e liberação. Slots de 20–30 min, renovados
  por progresso concreto; nenhuma frente mata processo alheio.
- [ ] C0 cria heartbeat da própria tarefa a cada 10 min. A cada 20 min lê os oito JSONs de G1–G8 e o novo ambiente-runtime.json.
  A cada 30 min recebe feito/pendente/SHA, integra, aplica deltas e publica.
  Usar heartbeat do produto na tarefa quando a R08 for iniciada; não
  substituir por loop de espera sem trabalho nem deixar timer após o corte.
- [ ] T0+4h: revisão de 10 min; T0+4h10: congelar novos trabalhos;
  T0+4h30: fechar. Nenhuma aprovação tácita de produto; defaults já
  documentados seguem válidos e bloqueio afeta só a ação dependente.

## Pacotes por frente

### G0 — um ambiente comprovado, não oito diagnósticos repetidos

Arquivos: novo comunicacao/ambiente-runtime.json; scripts QA existentes em
apps/superadmin/test_driver; configuração pública ignorada por worktree.
Não editar router/composição/feature nem criar outro entrypoint.
Interface entregue: SHA do build, URL IPv4, porta CDP se aplicável,
identidade QA da frente, comando reproduzível e captura. Sem tokens/senhas.

- [ ] Medir docker version, WSL e processo que detém o runtime; preservar
  volumes/VHDX. Reinício do Windows só com ordem do Owner e trabalho salvo.
- [ ] Quando o daemon voltar, conferir supabase_db_coelo_baseline:57322.
  Reset apenas da baseline descartável identificada; nunca do projeto linked.
  Reaplicar ordem-de-aplicacao-producao.txt por psql se defasada.
- [ ] Copiar apenas a configuração pública necessária ao build, conferindo
  nomes de variáveis sem imprimir valores. QA_EMAIL/QA_PASSWORD ficam nos
  backups da frente e entram somente no processo/harness.
- [ ] Validar runtime real na origem 127.0.0.1:3014, já medida nos preflights.
  CORS de outras portas exige prova por Edge Function e bucket.
- [ ] Entregar liberação de ambiente ao C0 com evidência commitada.

### G1 — Estrutura e Avaliações

Arquivos: lib/features/{activities,assessments,groups,institutions,units,locations}
e testes correspondentes; candidato SQL só se indispensável.
Consome contratos dos lotes 51/54; fornece prova por IDs, não declaração global.

- [ ] Corrigir rodapé de Criar modelo de atividade conforme P15/P34, sem
  aceitar esse formulário como exceção no teste de adoção.
- [ ] activities.assessment: salvar/ativar configuração e criar período
  sintético pelo fluxo autorizado.
- [ ] assessments.entry/gradebook/close/reopen/detail: execução com aluno/turma
  sintéticos, reload e negativa de escopo.
- [ ] groups.members/location, institutions.status/files/error/access-denied,
  units.error/access-denied, activities.publish e institutions.locations-map:
  primeiro gate por ID em R08-backlog.md. Locations.detail-links é nome de
  superfície, não acrescentar ID ao denominador.
- [ ] P53=A e lista nominal recebidas: conferir e regravar somente os 45 PNGs A de G1; A+/R continuam com suas observações. Testes: test/features/activities, assessments, groups e
  demais famílias realmente alteradas + teste de adoção do rodapé.

### G2 — Acessos e Pessoas

Arquivos: features/people, students, access_profiles, invites, platform_users;
Edge Function internal-user-create sob autoria exclusiva de G2.
Consome versão 3 implantada, não pede novo deploy como pré-requisito genérico.

- [ ] people.create/edit e @ (incluindo cooldown/indisponibilidade), usando IDs
  canônicos; people.handle é requisito de edição, não nova ação.
- [ ] access-profiles.edit/assign/delete; access-models.edit/duplicate;
  internal-users.edit/suspend. Preservar hierarchy/Owner e tenant no servidor.
- [ ] internal-users.create pela tela + reload/negação. O fallback P51=B
  exige geração/entrega segura do link: confirmar implementação antes de
  afirmar que funciona; jamais pôr link/senha em JSON/evidência pública.
- [ ] invites.resend: produzir fixture expirada com pacote seguro/pgTAP,
  combinar com G5, não burlar validação manualmente.
- [ ] Corrigir expectativa de respiro 24→space10 apenas onde a regra vigente
  comprovar 40; golden só após comparação/autoridade visual.
  Testes: famílias tocadas, rotas de identidade e cors_test.ts da função.

### G3 — Assiduidade, arquivos de Formulários e Cuidado

Arquivos: features/attendance, forms, health_care, safety, daily_routine;
coelo_api para contrato de arquivos; autoria de form-media.
Exclusividade adicional: superadmin_form_frame.dart para o overflow medido,
coordenada com C0, sem outra frente editar esse composto simultaneamente.

- [ ] Recertificar attendance.mark/finish/correct na nova PublicationSurface.
  attendance.create não foi reconstruída; não reabrir por alias.
- [ ] Corrigir overflow real de medication_plan_ui_contract_test em 375/200%;
  preservar foco/toque e validar consumidores afetados do frame.
- [ ] Question-image: picker, prepare, PUT com upload_url/required_headers,
  finalize/resolve/expire/delete, arquivo privado e prova de erro/reload.
  Não confundir contrato já corrigido de resposta com cliente do editor pronto.
- [ ] forms.location-answer: eliminar somente gate de decisão já resolvida,
  provar contrato vigente e manter negativa de local/escopo.
- [ ] Testar attendance, forms, health_care; fechar delta por fatia. A chave
  COELO_FORMS_MEDIA_PROVIDER é ligada somente por C0 após backend/prova verde.

### G4 — Publicadores do Principal e Chat

Arquivos: features/principal_*, meal_plans, chat, errors; Edge Functions
happens-media/now-media/moments-media sob autoria exclusiva de G4.

- [ ] Publicar PNG sintético por acontece.create, agora.create/publish,
  momentos.create/publish e provar read/reload/remoção/expiração aplicável.
  Acontece publish está no aceite de create: não inventar acontece.publish.
- [ ] meal-plans.list/create/edit/publish: scopeRules já corrigido no lote55;
  provar tela em vez de reabrir o mesmo pacote.
- [ ] chat.create-group real; depois chat.attach cliente consumindo chat-media
  (função pertence a G5). Não criar outro gateway ou usar Storage novo.
- [ ] principal.profile-edit/for-you e errors.*: primeiro gate real por ID.
  V-1 residual fica pós-MVP pelo default P54; V-3 segue referência aprovada.
- [ ] Testar as famílias e rotas tocadas. R2 privado é master; Stream só
  quando exigido pela política, nunca por inferência em um teste de imagem.

### G5 — segurança e suporte SQL

Arquivos: packages/coelo_database/candidatos/realm-interno, suítes SQL e
scripts de prova; Edge Function chat-media sob autoria exclusiva de G5.
Não usar MCP Dart. Produção é só C0.

- [ ] Reexecutar ACL/RLS pós-lotes49–55 no espelho na ordem real: revisão
  estática R07 de 210500/211100 não substitui pgTAP dinâmico.
- [ ] Pacotes com função compartilhada testam a suíte da outra frente,
  especialmente internal_actor_scope_root_v1_test.
- [ ] Atender fixture de convite expirado/período após contrato com G2/G1.
- [ ] Conferir cron/worker de limpeza de mídia e guardas de autorização sem
  exportar segredos. Provar falha por tenant antes de propor done.
- [ ] Preparar script único de limpeza de sintéticos e validar no espelho;
  não aplicar antes do encerramento formal da Etapa 2.

### G6 — Circulares, Eventos e sino

Arquivos: features/circulars, agenda, principal_circulars, shell notifications;
autoria de circular-media. Preservar publicadores de G4.

- [ ] circulars.attach na origem3014 com v13 já implantada: prepare→PUT→
  finalize→save/publish→read/reload, com negativa e mídia privada.
- [ ] Preservar as provas R06 de circulars.create/edit e agenda.create/edit; recertificar apenas quando a mudança atual afetar o aceite.
- [ ] Primeiro conciliar compositor antigo de teste versus host produtivo; perguntas e mídias devem aparecer entre blocos de texto, conforme spec037 e ADR0034 Decisão20. Provar ordem no autor, preview e leitor.
- [ ] P50: resposta à Circular no Superadmin e resumo por hierarquia.
  Não confundir leitor do Principal já certificado com tela administrativa.
- [ ] Aplicar a lista nominal do composer: 1 A, 3 A+ e 6 R. Não regravar R; comparar o rodapé indicado. Resolver o limite 4.000/10.000 com as fontes sem alterar contrato silenciosamente.
- [ ] Sino do shell: leitura/marcação dos contratos existentes, sem RPC nova
  desnecessária; confirmar autorização/escopo. Testar circulars, agenda e
  principal_circulars, incluindo rotas tocadas.

### G7 — Operações e gates formais

Arquivos: features/account, support, plans, catalog, help_center, audit/imports
somente no aceite informativo vigente; testes correspondentes.

- [ ] Reutilizar Conta settings/theme já FEverified e client-only; não exigir
  Supabase para tema. Sessões: listar/revogar outras e reload com QA próprio.
- [ ] Suporte por status/cards/tabela, próximos IDs realmente abertos.
- [ ] Catálogo: validate/sync locais não são hosting. Conciliar destino e
  publicação com spec051 e ADR; não construir cobrança/ERP.
- [ ] plans.assign: verificar decisão da spec051 (não confundir com P51 SMTP).
- [ ] Help Center: classificar diferença de conteúdo dos dois goldens com
  baseline aprovada, não como ruído.
- [ ] audit.export e importações gerais continuam informativas pós-MVP;
  não fazer deploy de audit-export para “fechar” botão adiado.

### G8 — manutenção textual de testes

Arquivos permitidos: test/app, test/core/config, test/shared, lib/dev e
lib/core/config; comunicação só fase0.json. Nenhum delta de estado.
lib/dev ausente não autoriza estender o recorte produtivo por conta própria.

- [ ] Receber o censo integrado R07: 6727 PASS / 33 FAIL / 11 SKIP. Não reutilizar a previsão 6719/36/11.
- [ ] Corrigir expectativas obsoletas com contrato/commit que comprova a
  mudança, sem skip novo nem allowlist que esconda defeito real.
- [ ] Não regravar/analisar golden com Spark text-only: devolver imagem e
  teste para a frente dona/C0 com capacidade visual.
- [ ] Rodar recorte na janela autorizada; censo completo apenas uma vez no
  fechamento, por C0 ou G8 designado, com JSON relativo e contador conferido.

## Integração, evidências e encerramento

- [ ] Handoffs incluem feito, pendente, primeiro gate, SHA realmente publicado,
  testes separados por ambiente e origem, dados sintéticos e nomes de chaves.
- [ ] Deltas são arrays no schema do aplicador, action_id do inventário,
  evidence ARQUIVO commitado docs/..., revision string e horário real.
  Tela reconstruída perde somente suas certificações FE/E2E obsoletas.
- [ ] C0: merge por frente, analyze, testes tocados, apply-tracker-delta.cjs,
  validate-trackers.cjs; nenhum merge -s ours para fingir integração.
- [ ] SQL: próximo lote56; preflight da ordem real, dump, aplicação
  forward-only, ledger, mover candidato e ligar composição. Sem factory
  reset, db push em bloco ou ALTER TYPE ADD VALUE junto do uso.
- [ ] Gate coelo-knowledge, três rastreadores, inventário, perguntas e
  fechamento R08. Backup de ignorados/evidências antes de retirar worktrees;
  branches preservadas. Sem eliminar sintéticos antes do fim da Etapa2.
- [ ] Publicar HEAD:dev sem force e conferir remoto. Encerrar heartbeat R08.

## Estimativa do restante da Etapa 2

Estimativa de planejamento, não prazo garantido: **20–36 horas de janela
operacional**, aproximadamente **5–9 rodadas de 4 horas**, para o MVP ativo
com provas, integração e limpeza final. A R08 é a primeira dessas rodadas.
Não inclui ampliar exportações adiadas, MFA/Access pós-MVP ou revisão profunda
exaustiva; esses itens permanecem identificados, sem inflar o prazo do MVP.

Decomposição que fundamenta a faixa:

| Bloco restante | Janela estimada | Dependência |
| --- | --- | --- |
| Ambiente único estável + espelho | 1–3 h | Docker/WSL/CDP; reinício externo pode ampliar a espera |
| Cliente de mídia/Formulários/Chat, P50, Circular intercalada e ajustes reais | 6–12 h com frentes em paralelo | contratos existentes; conciliar host antes de codar |
| Provas de Estrutura/Acessos/Publicadores/Operações | 6–10 h de fila de navegador | um Chrome global; G2 estima 1–2h só para seu recorte |
| Integração SQL/código, regressões e encerramento | 3–5 h, em parte sobreposto | preflight, evidências, censo e limpeza |
| Margem para correções de integração | 4–6 h | já houve CORS/204 e certificados desatualizados |

Os blocos se sobrepõem; não se somam horas de cada agente como prazo de
relógio. A faixa é uma inferência do escopo inspecionado, com confiança
baixa a moderada. Recalibrar após G0 entregar runtime e G1/G2 fecharem
uma fatia real. A faixa foi ampliada após o complemento da G8 e a reconciliação de Circulares; é estimativa, não medição dessa implementação. Na R07, zero E2E novo e sessões interrompidas tornam inválido
extrapolar taxa de produção pelo número de testes/commits.

“Tudo” não significa 224 backends done: o denominador fixo inclui 22 ações
adiadas e três gates formais. O aceite do MVP exige fechar os 199 E2E ativos,
os aceites client-only aplicáveis e os gates formais, com adiamentos honestos.
Aprovação visual do Owner continua medição separada; não prometer 100% visual
sem a revisão dele.

## Complemento final do Owner e limites da R08

Usar R07-decisoes-owner-20260912.md: P53=A, rodapé do modelo no MVP,
64 A / 5 A+ (um inferido) / 6 R nominais. A aprovação autoriza a regravação
correspondente, não promove FE/BE/E2E. G6 usa Sol pelo acoplamento do editor.
Revisão histórica de credenciais e endurecimento amplo de segurança ficam
fora desta entrega, por ordem do Owner. G5 mantém suporte de ACL/RLS e
preflight dos pacotes novos; incidentes concretos são tratados no seu escopo.
