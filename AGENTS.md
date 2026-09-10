# Coelo Master Agent

Este arquivo e o contexto principal do projeto Coelo. Ele nao cria um agente por PRD; ele define como qualquer colaborador ou agente deve ler, decidir, documentar e implementar o projeto quando uma spec futura for aprovada.

## Visao Do Produto

Coelo e um superapp privado de rotina, comunicacao e cuidado entre instituicoes, familias, responsaveis e alunos. O produto centraliza comunicacao escolar/institucional, agenda, rotina, Acontece, Agora, Momentos, chat, notificacoes e contexto familiar com privacidade, confianca e clareza.

Coelo nao e um ERP completo, nao e rede social aberta, nao e substituto generico de WhatsApp e nao deve transformar cuidado infantil em feed publico. O produto deve preservar o melhor interesse da crianca, a relacao entre instituicao e familia, e a auditabilidade das acoes sensiveis.

## Prioridade Documental

1. Product Vision e PRD Master.
2. PRDs especializados: App, Admin, Superadmin, Auth Multi-tenant e Permissoes, LGPD/Seguranca/Midia, Modelo de Dados.
3. Arquitetura Macro, Mapa de Dominios, Design System e Historia da Marca.
4. ADRs aprovadas em `decisions/`.
5. Specs aprovadas em `specs/`.
6. README e notas auxiliares.

Quando houver conflito, nao resolva silenciosamente. Registre em `docs/open-questions.md`, cite os documentos envolvidos e marque a decisao necessaria.

## Arquitetura Esperada

O repositorio e um monorepo. O site publico fica em `apps/site` com Astro. As aplicacoes privadas ficam em Flutter: `apps/superadmin`, `apps/admin` e `apps/principal`. O nome `principal` substitui qualquer uso futuro de `family` ou `app familiar` em nomes de apps, pacotes, specs e contextos.

Subdominios planejados:

- `coelo.me` -> `apps/site`
- `superadmin.coelo.me` -> `apps/superadmin`
- `admin.coelo.me` -> `apps/admin`
- `app.coelo.me` -> `apps/principal`

`coelo.com.br` permanece como duvida/alias futuro ate decisao explicita.

## Multi-Tenancy, Papeis E Permissoes

O modelo do Coelo assume pessoa global e papel contextual. Uma pessoa pode ter multiplas relacoes com instituicoes, unidades, grupos, criancas e contextos. O isolamento deve ocorrer por `tenant_id`, `institution_id`, membership, papel, permissao familiar e policies/RLS quando aplicavel.

Regras globais:

- Nunca confiar apenas no cliente para autorizacao.
- Testar acesso cruzado entre tenants antes de liberar funcionalidades sensiveis.
- Separar identidade global de papel contextual.
- Nao usar metadados mutaveis pelo usuario como fonte de autorizacao.
- Suporte interno Coelo deve ser auditado e minimamente privilegiado.

## Seguranca, LGPD E Midia

`service_role` e qualquer segredo equivalente nunca podem aparecer no cliente,
em apps Flutter ou no site publico. Desde a decisao do Owner de 2026-09-03
(ADR 0032), toda midia nova do MVP usa Cloudflare R2 privado;
Postgres/Supabase guarda metadados, permissoes, vinculos, ownership e trilha de
auditoria. A ADR 0030 fica historica. R2 nao substitui o banco nem autoriza
bucket publico ou segredo no Front-end. Cloudflare Stream e somente uma copia
HOT privada e removivel: Agora pode usa-la por ate 24 horas; Momentos e
Acontece somente por necessidade medida; Chat nao exige Stream no MVP. O master
permanece no R2.

Todo recurso Supabase ou Cloudflare remoto do Coelo e producao; nao presumir
DEV ou homologacao. Desde a ADR 0034 (10/09/2026) o integrador tem
autorizacao permanente para aplicar migrations forward-only no Supabase de
producao quando o pgTAP local passou, a ordem serializada foi respeitada e o
backup por ponto no tempo esta ligado; nao pedir autorizacao por pacote. O que
ficar aberto vai para os rastreadores e o Owner revisa em ciclo semanal ou
quinzenal. Segredos, buckets e Workers do Cloudflare ainda exigem autorizacao
nominal. A topologia R2 privada usa
`coelo-media-prod`, `coelo-documents-prod` e `coelo-transient-prod`, com chaves
opacas versionadas por escopo, dominio, entidade, finalidade, ativo e rendicao.
Postgres e o catalogo autoritativo de ativos, variantes, usos e entregas.
Imagens e documentos seguem MIME real, bytes, dimensoes/pixels, checksum,
retencao e limites por finalidade da ADR 0032; PDF nunca usa Stream.
Superadmin, Admin e Principal consomem a mesma plataforma sem app no path; na
Etapa 2 somente Superadmin e conectado. O Site nao acessa midia privada e usa
assets estaticos no proprio build/CDN; publicacao dinamica futura exige fluxo e
bucket publico separados.

Importacao e exportacao reais ficam adiadas para depois do MVP. Os botoes
permanecem visiveis nas telas aplicaveis, com indisponibilidade honesta e sem
picker, parser, job, arquivo, RPC ou persistencia. A excecao e
`forms.responses.export`: o formulario exporta um arquivo XLSX com suas
respostas no MVP, sem configuracao adicional, armazenado no R2 privado com
reautorizacao server-side, expiracao e auditoria. Nao e uma exportacao por
resposta e nao inclui CSV, ZIP ou PDF. Exportacoes gerais do Superadmin e de
outros dominios continuam adiadas. No encerramento formal do MVP, perguntar ao
Owner se deseja implementar as demais acoes.

Dados pessoais, dados de criancas, CPF, midias, mensagens e logs devem respeitar LGPD, minimizacao, base legal, retencao definida, rastreabilidade e melhor interesse da crianca. Lacunas juridicas devem ficar abertas ate decisao formal.

Invariantes obrigatorias de seguranca:

- Regra de negocio, ownership, tenant, hierarquia e autorizacao sao validados no backend/RLS em toda leitura e escrita; o frontend apenas solicita e renderiza.
- IDs, rotas, filtros, claims e parametros enviados pelo cliente sao nao confiaveis. Toda operacao deve impedir IDOR/BOLA conferindo ator, recurso, tenant e escopo real.
- Tabelas expostas usam RLS deny-by-default. RPCs privilegiadas validam identidade, capacidade e, quando exigido, MFA; grants diretos desnecessarios permanecem revogados.
- Inputs sao validados e limitados no servidor com allowlists, tipos e constraints. Saidas web nao usam HTML/JavaScript inseguro e devem prevenir XSS.
- Rotas e respostas nao entregam dados antes da autorizacao. Ocultar botoes ou depender de permissoes do navegador nunca constitui controle de acesso.
- Nenhum segredo entra em Git, bundle, asset, log, URL ou frontend. O gitignore, exemplos de ambiente e o diff staged devem ser revisados antes de cada entrega sensivel.
- Revisoes de seguranca seguem OWASP ASVS para web/API e OWASP MASVS para clientes moveis, alem de testes cross-tenant e de acesso cruzado por ID.

## Design System

O Coelo usa Nunito Sans, laranja de marca `#D63C00`, grafite `#3F4549`, temas claro/escuro e tokens semanticos. Componentes devem seguir `docs/design/design-system.md`, preservar acessibilidade WCAG 2.2 AA quando aplicavel e manter alvos de toque adequados.

## Padroes De Implementacao Futura

- Cada implementacao nasce de uma spec pequena e aprovada.
- Apps privados Flutter devem compartilhar dominio, auth, API e tokens sem importar telas entre si.
- `principal` nao deve carregar componentes administrativos.
- `site` Astro fica separado dos apps Flutter.
- Contratos e dominio nao dependem de Flutter.
- Regras de banco, RLS e migrations futuras pertencem a `packages/coelo_database`.
- Comandos sensiveis devem passar por caminho server-side adequado, como Edge Functions/RPCs, com auditoria.

## Padroes De Documentacao

Todo Markdown derivado deve ter frontmatter com fonte, status e data de geracao. Documentos oficiais originais ficam preservados em `docs/source/originals/`. Decisoes persistentes ficam em ADRs. Perguntas abertas ficam em `docs/open-questions.md`.

## Como Criar Specs

Cada spec deve conter:

- objetivo e problema;
- escopo e fora de escopo;
- superficies afetadas;
- entidades e dados envolvidos;
- permissoes e regras de tenant;
- estados de UX;
- eventos, logs e notificacoes;
- criterios de aceite;
- testes exigidos;
- riscos e perguntas abertas.

## Como Evitar Retrabalho

Antes de criar algo novo, procurar primeiro em `docs/`, `specs/`, `decisions/` e `packages/`. Se uma regra ja existir em documento oficial, preserve-a. Se houver divergencia entre fonte oficial e decisao recente, registre o conflito e peca aprovacao antes de implementar.

## Revisoes Flutter E Supabase

Toda atividade de code review, revisao, auditoria, correcao profunda ou
verificacao de conclusao deve comecar listando as pendencias conhecidas e
confirmando o recorte antes de alterar codigo ou backend. O contrato inicial deve
registrar: objetivo, incluido, fora de escopo, ordem, criterio de parada,
evidencias esperadas e tempo estimado. O recorte pode ser todas as pendencias,
todas as telas, um macrotema, macrotema mais telas, telas especificas ou acoes
especificas. Concluir o recorte nunca autoriza declarar concluido o que ficou
fora dele.

Escolha a skill e os rastreadores conforme o pedido. Os caminhos historicos das
skills foram preservados para compatibilidade, mas os nomes abaixo sao
canonicos:

- **Coelo Front-end** (`coelo-frontend`): use
  `.agents/skills/coelo-flutter-review/SKILL.md` para Flutter/Dart nos apps
  privados e Astro no Site, sempre com recorte explicito por app; consulte
  `docs/reviews/coelo-flutter-pendencias.md` conforme a profundidade abaixo.
- **Coelo Back-end** (`coelo-backend`): use
  `.agents/skills/coelo-supabase/SKILL.md` para Supabase/Postgres e Cloudflare
  R2/Stream/Workers; consulte `docs/reviews/coelo-supabase-pendencias.md`
  conforme a profundidade abaixo.
- **Coelo Front-end + Back-end** (`coelo-frontend-backend`): use
  `.agents/skills/coelo-flutter-supabase-review/SKILL.md` quando a conclusao
  cruzar cliente e backend; cruze os tres rastreadores, terminando por
  `docs/reviews/coelo-flutter-integrado-supabase-pendencias.md`.

A profundidade segue
`.agents/skills/coelo-flutter-supabase-review/references/review-scope.md`:
auditoria ou conclusao ampla le integralmente os rastreadores das camadas;
correcao localizada le cabecalhos, acoes, dependencias e evidencias afetadas;
explicacao ou manutencao de skill/documentacao nao inicia auditoria do produto.
Reutilize leituras; dependencias de skills nao reiniciam em ciclo. O recorte
ja definido pelo usuario dispensa nova confirmacao ou pergunta de tempo.
Estime o delta real apos inspecao, sem faixas fixas por tela ou contagem de
acoes como substituto de horas. Seguranca e provas da conclusao permanecem.

Na Etapa 2, cada abertura, checkpoint e entrega identifica
`apps/superadmin -> menu -> tela -> subtela/estado -> action_id`.
Coelo (Principal) e menu do Superadmin; outros apps ficam fora do recorte.
Aplicar o contrato vigente em
`docs/superpowers/specs/2026-09-01-coelo-review-progress-metrics-design.md`:
separar avanco local, conclusao FE/BE/E2E e testes aprovados/falhos dos
executados, junto da cobertura do plano e bloqueados/ignorados/nao executados.
Percentuais usam IDs unicos, base, revisao, ambiente e data; historico nao vira
resultado atual. Relatar por tela/subtela e recorte, com geral conhecido datado.
Falta de mapeamento ou evidencia fica explicita. Retomadas fecham o primeiro
gate aberto do recorte, reutilizando implementacao e provas validas.
Regua do MVP (ADR 0034): uma acao conta como verificada quando a rota normal
abre, o CRUD persiste no Supabase real, o RLS nega outro tenant e o reload
mantem o estado. Provas exaustivas por acao (sessoes concorrentes, ID
adulterado por tela, auditoria com retry, golden por estado) ficam para a
revisao profunda de seguranca depois do MVP; nao bloqueiam o aceite.
Atualizar inventario e matrizes juntos ao mudar estados; validacao documental
nao certifica o app nem autoriza producao.

Chamar `coelo-frontend`, `coelo-backend` ou `coelo-frontend-backend` para
trabalhar no projeto tem modo padrao resolver pendencias: retomar o recorte ou
selecionar a proxima acao executavel da Etapa 2, corrigir localmente, testar e
registrar o aceite. Nao encerrar apenas com auditoria, plano ou percentuais
quando a correcao autorizada ainda puder prosseguir. Pedidos explicitos de
explicacao/review somente leitura e manutencao das skills mantem esse limite.
Pacote SQL verde em pgTAP local e aplicado em producao pelo integrador na
ordem da fila (ADR 0034); so Cloudflare ainda exige decisao nominal.
Continuar o trabalho independente enquanto isso. Seguir o ciclo de resolucao em review-scope.md.

Antes de retomar, localizar worktrees, base integrada, protocolo/fechamento da
rodada e handoff por revisao/data/SHA; o dev local pode estar desatualizado.
Nao retomar rodada encerrada automaticamente. Reutilizar referencias e provas
validas; materializar a base conjunta antes de verificar integracao. Respeitar
o escritor central vigente: executores propoem deltas no proprio handoff.
Alteracoes de skills devem chegar ao checkout de destino para valer ali;
nao sobrescrever instrucoes divergentes nem confundir commit/push com deploy.
Corrigir os pontos indicados pelo Owner nos anexos de cada tela/subtela e sua
integracao, preservando referencias aprovadas. Anexo salvo nao e correcao pronta.
Definir testes pertinentes aos aceites; depois de verdes, seguir ao proximo
gate. Repetir/ampliar somente com motivo material ou verificacao obrigatoria
na base integrada, sem somar reruns. Relatar falhas resolvidas/novas e aceite
alcancado; nao rodar lotes duplicados. Estimar o delta inspecionado e calibrar
pela execucao, sem horas fixas por tela ou estimativas historicas sem fundamento.
Em Cloudflare, descobrir o MCP/plugin instalado e seguir a skill do produto e
Wrangler quando aplicavel; disponibilidade de ferramenta nao prova acesso nem
substitui autorizacao nominal. Pacote autorizado segue ate implantacao e prova.

No fechamento que inclua integracao/publicacao, reconciliar commits, stash,
alteracoes locais e divergencia com o remoto. Skills e referencias precisam
estar na base entregue, nao somente na worktree do autor. Preservar e identificar
WIP retido antes de arquivar/remover uma worktree encerrada; arquivo historico
nao equivale a codigo integrado. Usar o checkout consolidado e criar isolamento
somente quando necessario, com destino e responsavel de integracao definidos.
Nao declarar entrega integrada enquanto commit/push autorizado continuar pendente.

Skills orientam o agente tanto no trabalho local quanto na entrega do app real.
A branch Git dev e a base atual de versionamento; nao e um ambiente de testes.
As regras das skills tambem valem para producao no escopo remoto autorizado.

`coelo-ui` permanece a autoridade visual em qualquer revisao de Front-end.
Distinguir app hospedeiro de familia visual: administrativo Superadmin orienta
Admin; Coelo (Principal) preserva suas composicoes aprovadas mesmo dentro do
Superadmin; Site tem composicao propria conforme spec aprovada.
Atualize
os rastreadores afetados no mesmo turno de cada correcao, regressao, bloqueio ou
mudanca de estimativa. Tela aberta, `fail-closed`, `local-green`, rota `/dev`,
mock ou teste isolado nunca deve ser declarada concluida ponta a ponta.

## Memoria De Conhecimento

Use `.agents/skills/coelo-knowledge/SKILL.md` sempre que uma tarefa Coelo
alterar ou explicar produto, dominio, permissoes, UX, documentacao ou
comportamento observavel.

Antes do trabalho, consulte a projecao em `docs/knowledge/` e suas fontes
canonicas. Ao terminar, execute o gate de memoria da skill: atualize primeiro a
fonte canonica, registre somente conhecimento duravel e aprovado para a
audiencia correta, valide o conteudo e relate o que foi capturado. Quando nada
reutilizavel mudar, nao crie arquivos apenas para registrar atividade.

@RTK.md
