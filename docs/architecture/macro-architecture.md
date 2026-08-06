---
title: "Coelo Arquitetura Macro Oficial v1"
source_file: "Coelo Arquitetura Macro Oficial v1.docx"
source_copy: "docs/source/originals/docx/Coelo Arquitetura Macro Oficial v1.docx"
original_path: "C:/Users/adrie/Desktop/Coelo/Mapa de Dominios e Arquitetura/Coelo Arquitetura Macro Oficial v1.docx"
supplemental_source: "decisions/0015-contextual-people-authorizations-attendance.md; specs/015-contextual-people-access-attendance.md"
status: "derived-from-official-docx"
version: "v1"
generated_at: "2026-07-24"
---

<!-- Documento derivado de fonte oficial. Edite a fonte DOCX ou registre uma decisao antes de alterar conteudo normativo. -->
| Coluna 1 | COELO<br>Arquitetura Macro Oficial v1<br>C4 · monólito modular · Flutter · Supabase · Cloudflare · R2 |
| --- | --- |

Versão: v1.0 | Data: 21/06/2026 | Status: Draft oficial para validação técnica

| Visão da arquitetura<br>Construir o Coelo como uma plataforma multi-tenant segura, modular e simples de operar, capaz de validar o piloto rapidamente sem criar um “microserviço de estimação” antes da hora. |
| --- |

| Simples como Airbnb<br>Um monorepo, fronteiras claras e poucos componentes operacionais. | Visual como Instagram<br>Happens, Now e Moments compostos na experiência, independentes no domínio. | Confiável como escola<br>RLS, mídia privada, auditoria e privacidade infantil desde a fundação. |
| --- | --- | --- |

Documento derivado do Product Vision, PRD Master, PRDs especializados, Modelo de Dados Master, Design System, Mapa de Domínios e decisões validadas pelo fundador.

# Resumo executivo

A arquitetura macro do Coelo será um monólito modular em monorepo, com superfícies separadas para Site, App, Admin e Superadmin, backend principal no Supabase e Cloudflare como camada de borda e mídia. O objetivo é reduzir o tempo de entrega do piloto, manter isolamento multi-tenant verificável e preservar fronteiras que permitam evolução futura sem reescrever o produto inteiro.

A stack oficial v1 combina Flutter/Dart para App, Admin e Superadmin; Astro para o site institucional orientado a SEO; Supabase para Postgres, Auth, RLS, Realtime e Edge Functions; e Cloudflare para DNS, TLS, WAF, rate limiting, Pages e R2. A arquitetura não começa com microserviços: os bounded contexts permanecem independentes no código, nas tabelas que possuem e nos contratos que publicam, mas compartilham inicialmente o mesmo deploy e banco.

| Decisão técnica consolidada<br>O site coelo.me será feito em Astro e publicado no Cloudflare Pages. Toda mídia de produto — fotos, vídeos e anexos — ficará em bucket privado no Cloudflare R2 desde o MVP. O Supabase continuará como fonte oficial dos metadados, vínculos, permissões e auditoria da mídia. A complexidade adicional será contida por um Media Gateway único, responsável por autorização e URLs temporárias. |
| --- |

## Decisões validadas

| Tema | Decisão oficial v1 | Implicação |
| --- | --- | --- |
| Site institucional | Astro + Cloudflare Pages | HTML pré-renderizado, foco em SEO e conteúdo; Next.js fica fora do MVP. |
| Estrutura de código | GitHub monorepo heterogêneo | Flutter, Astro, Supabase e infraestrutura versionados no mesmo repositório com pipelines por caminho. |
| Ambientes | Local, Desenvolvimento, Homologação e Produção | Projetos Supabase separados para Dev, Stage e Prod; Supabase CLI local. |
| Mídia | Cloudflare R2 privado para toda mídia desde o MVP | Acesso somente por autorização e URLs pré-assinadas; metadados no Postgres. |
| Notificações | Provider-neutral | Contrato de notificação desacoplado; fornecedor será escolhido na Technical Spec. |
| Escala de referência | Piloto com 1 a 5 instituições e até 2.000 usuários cadastrados | Otimizar por aprendizado e segurança; medir concorrência real antes de superdimensionar. |
| Arquitetura de backend | Monólito modular | Sem microserviços iniciais; extração apenas por gatilhos técnicos ou operacionais comprovados. |
| Offline | Offline-tolerant | Cache, rascunho e retry; sincronização full offline somente após evidência do piloto. |

## O que esta arquitetura resolve

- Evita mistura de dados entre instituições por meio de contexto ativo, RLS, vínculos e testes automatizados de isolamento.

- Permite que Happens, Now, Moments e demais módulos evoluam e sejam liberados por plano sem duplicar a experiência do usuário.

- Mantém o MVP operável por uma equipe pequena, sem broker, Kubernetes ou dezenas de serviços para cuidar.

- Prepara mídia, auditoria, analytics, eventos e entitlements desde o início sem obrigar a entregar todas as interfaces agora.

- Cria uma base adequada para coding agents: specs pequenas, módulos com ownership, migrations versionadas e revisão humana obrigatória em segurança.

# Sumário executivo do documento

| # | Seção |
| --- | --- |
| 1 | Objetivo, escopo e princípios |
| 2 | Contexto do sistema |
| 3 | Containers e tecnologias |
| 4 | Arquitetura das aplicações |
| 5 | Monólito modular e monorepo |
| 6 | Backend, dados e eventos |
| 7 | Arquitetura de mídia no R2 |
| 8 | Realtime, notificações e offline-tolerant |
| 9 | Segurança, privacidade e LGPD |
| 10 | Ambientes, CI/CD e implantação |
| 11 | Observabilidade, analytics e operação |
| 12 | Dimensionamento do piloto e evolução |
| 13 | Requisitos não funcionais |
| 14 | Riscos e mitigação |
| 15 | Critérios de aceite e próximas specs |
| 16 | Fontes e referências |

## Controle de versão

| Versão | Data | Mudança | Responsável |
| --- | --- | --- | --- |
| v1.0 | 21/06/2026 | Criação da Arquitetura Macro com decisões de stack, C4, mídia, ambientes, segurança e evolução. | Produto + Engenharia Coelo |
| v1.1 | A definir | Revisão após Technical Specs, protótipo de RLS, spike de mídia R2 e pipeline inicial. | Produto + Engenharia |
| v2.0 | A definir | Atualização após piloto real e métricas de uso, custo, concorrência e operação. | Produto + Negócio |

# 1. Objetivo, escopo e princípios

## 1.1 Objetivo

Definir a visão técnica de alto nível do Coelo para orientar Functional Specs, Technical Specs, migrations, infraestrutura, CI/CD, testes, segurança, backlog e uso de coding agents. A arquitetura deve ser simples o bastante para chegar ao piloto e forte o bastante para impedir improvisos em dados infantis e multi-tenancy.

## 1.2 Escopo incluído

- Aplicações: coelo.me, app.coelo.me, admin.coelo.me, superadmin.coelo.me e apps iOS/Android.

- Backend: autenticação, banco, RLS, funções server-side, Realtime, eventos, auditoria e analytics.

- Mídia: upload, armazenamento privado, acesso temporário, metadados e ciclo de vida.

- Infraestrutura: Cloudflare, Supabase, GitHub, ambientes e pipeline de entrega.

- Princípios de segurança, privacidade, observabilidade, resiliência e evolução.

## 1.3 Fora do escopo desta versão

- DDL e migrations finais, nomes físicos definitivos e índices detalhados.

- Escolha definitiva do provedor de push, crash reporting ou produto de observabilidade.

- Políticas jurídicas finais, bases legais, DPA e prazos de retenção aprovados.

- Transcodificação avançada de vídeo, CDN de vídeo especializada e streaming adaptativo.

- SLA comercial, RPO e RTO contratuais; serão definidos conforme plano de infraestrutura e piloto.

## 1.4 Princípios arquiteturais

| Princípio | Aplicação no Coelo |
| --- | --- |
| Privado por padrão | Negar acesso até que vínculo, contexto, audiência e permissão sejam comprovados. |
| Pessoa global, papel contextual | Uma identidade pode participar de vários tenants; o papel nunca é uma coluna fixa da pessoa. |
| Fonte oficial única | Cada dado mestre possui um único bounded context autorizado a alterá-lo. |
| Composição sem fusão | Uma tela combina módulos, mas os módulos não compartilham tabelas de negócio por conveniência. |
| Monólito modular primeiro | Um deploy e um banco no MVP; microserviço somente quando houver dor mensurável. |
| Eventos sem broker prematuro | Outbox e processadores assíncronos simples antes de Kafka, RabbitMQ ou equivalentes. |
| Segredos no servidor | Service role, chaves R2 e credenciais de terceiros nunca entram no cliente. |
| Evolução guiada por dados | Escalar, extrair e contratar ferramentas após medir uso, latência, custo e operação. |

# 2. Contexto do sistema

O Coelo é o sistema central que conecta famílias, equipes de instituições e a operação interna da plataforma. O site institucional atrai e converte instituições, enquanto os ambientes autenticados executam a rotina diária e a governança. Serviços externos entram apenas como infraestrutura de entrega, notificação ou comunicação e nunca se tornam a fonte oficial dos vínculos e permissões.

Figura 1 — Diagrama C4 de contexto do sistema Coelo.

## 2.1 Atores e fronteiras de confiança

| Ator | Canal principal | Fronteira de acesso |
| --- | --- | --- |
| Família/responsável | App mobile/web | Somente crianças, instituições, grupos e conteúdos autorizados. |
| Professor/equipe | App mobile/web | Somente unidades, grupos e participantes vinculados ao papel ativo. |
| Direção/Admin | Admin web + App | Tenant e escopos delegados; permissões administrativas explícitas. |
| Equipe Coelo | Superadmin | Cargo interno, motivo de suporte, escopo e auditoria obrigatória; Owner Coelo e excecao privilegiada com MFA obrigatoria. |
| Visitante | coelo.me | Conteúdo público de marketing; nenhum dado autenticado ou infantil. |

| Regra de fronteira<br>App, Admin e Superadmin não são sistemas de dados independentes. São superfícies de experiência que consomem os mesmos contratos de domínio e as mesmas regras server-side. Nenhuma interface pode ampliar permissão por conta própria. |
| --- |

# 3. Containers e tecnologias

Os containers abaixo representam unidades executáveis ou serviços gerenciados. No MVP, o Coelo evita hospedar servidores próprios de longa duração. Flutter e Astro entregam as interfaces; Supabase concentra backend e dados; Cloudflare protege a borda e armazena mídia privada.

Figura 2 — Diagrama C4 de containers e integrações principais.

## 3.1 Catálogo de containers

| Container | Tecnologia | Responsabilidade |
| --- | --- | --- |
| Site institucional | Astro + Cloudflare Pages | SEO, páginas institucionais, blog, captação e documentação pública. |
| App Coelo | Flutter iOS/Android/Web | Experiência diária: Happens, Now, Moments, Rotina, Chat, Agenda e Perfil. |
| Admin | Flutter Web | Onboarding, estrutura, pessoas, vínculos, permissões, importação e operação. |
| Superadmin | Flutter Web | Primeira fatia operacional: tenants, planos manuais, usuarios internos, avisos/popups segmentados, suporte, auditoria e base para dashboard futuro. |
| Supabase Auth | Serviço gerenciado | Credenciais, sessões, recuperação, OTP/senha e identidade autenticada. |
| Postgres | Supabase Postgres | Fonte oficial de pessoas, contextos, conteúdo, vínculos, eventos e auditoria. |
| Edge Functions | Supabase Functions | Comandos sensíveis, webhooks, convites, media gateway e tarefas server-side. |
| Realtime | Supabase Realtime | Atualizações autorizadas de chat, feed e estados operacionais. |
| Mídia | Cloudflare R2 | Objetos privados de foto, vídeo, anexo, thumbnail e variantes. |
| Borda | Cloudflare | DNS, TLS, WAF, rate limiting, Turnstile, CDN e publicação web. |
| Automação | n8n | Fluxos administrativos não críticos e integrações futuras controladas. |

## 3.2 Por que Astro no site

O coelo.me é uma superfície de conteúdo e aquisição, não um painel autenticado. Astro foi escolhido porque prioriza páginas orientadas a conteúdo, gera HTML estático por padrão e permite adicionar JavaScript apenas onde houver interatividade. Isso reduz complexidade e favorece desempenho, indexação, sitemap e publicação em Cloudflare Pages. Next.js permanece como alternativa futura somente se o site passar a exigir uma aplicação full-stack dinâmica de maior profundidade.

# 4. Arquitetura das aplicações

## 4.1 Flutter: camadas e responsabilidades

App, Admin e Superadmin seguirão separação de responsabilidades inspirada na arquitetura recomendada pelo Flutter: UI com Views/ViewModels, camada de domínio para casos de uso complexos e camada de dados com repositories e services. O código será organizado por feature/bounded context, não por uma pasta global de “telas” e outra de “APIs”.

Para o Superadmin Completo v1, a ordem oficial de trabalho e banco primeiro, wireframe depois e Flutter por ultimo. A modelagem deve prever ativacao de instituicao, usuarios internos, avisos/popups segmentados, suporte auditado, auditoria e dados agregaveis para dashboard futuro antes da implementacao visual.

| Camada | Responsabilidade | Exemplos |
| --- | --- | --- |
| Presentation/UI | Renderizar estado, capturar intenção e exibir feedback. | Views, widgets, rotas, view models, estados de carregamento/erro. |
| Application | Orquestrar casos de uso e transações entre domínios. | Publicar Happens, registrar rotina em lote, aceitar convite, responder agenda. |
| Domain | Regras, políticas e linguagem do bounded context. | AudiencePolicy, ContextDecision, EntitlementCheck, RoutineRules. |
| Data | Fornecer fontes de verdade por interfaces. | Repositories, Supabase services, cache local, mappers e DTOs. |
| Infrastructure | SDKs e adaptadores externos. | Supabase, R2 media adapter, push adapter, analytics adapter. |

## 4.2 Navegação e contexto ativo

- A sessão identifica a pessoa; o contexto ativo identifica instituição, papel e escopo corrente.

- A troca de contexto invalida caches dependentes, atualiza permissões e recompõe a navegação.

- Deep links nunca concedem acesso: o backend recalcula autorização para o recurso solicitado.

- Feature entitlements alteram disponibilidade de módulos, mas não substituem RBAC/RLS.

- Responsável que também é professor alterna contexto sem misturar dados pessoais e profissionais.

## 4.3 Estratégia de estado e cache

A Technical Spec definirá a biblioteca concreta de estado. A arquitetura macro exige apenas contratos claros, estado imutável quando aplicável, cancelamento de requisições, paginação, cache por contexto e tratamento consistente de loading/error/empty. Dados privados não devem persistir localmente além do necessário e o logout deve limpar chaves, cache sensível e filas pendentes conforme política.

## 4.4 Site Astro

- SSG por padrão para páginas institucionais, blog e landing pages.

- Sitemap, canonical, Open Graph, dados estruturados e robots gerados no build.

- Formulários protegidos por Turnstile e processados por endpoint server-side controlado.

- Sem compartilhar sessão do App no MVP; links autenticados redirecionam para app.coelo.me ou lojas.

- Conteúdo editável por Git/Markdown no início; CMS somente quando a operação justificar.

# 5. Monólito modular e monorepo

O mapa de domínios define os limites; a arquitetura macro define como implementá-los. Cada bounded context possui código, migrations, contratos e testes próprios, mas roda inicialmente no mesmo backend e no mesmo banco. Isso combina velocidade de monólito com disciplina de arquitetura evolutiva.

Figura 3 — Camadas internas e independência dos bounded contexts.

## 5.1 Estrutura sugerida do monorepo

| Caminho | Conteúdo |
| --- | --- |
| apps/coelo_app | Flutter mobile/web para responsáveis e equipe. |
| apps/coelo_admin | Flutter Web da instituição. |
| apps/coelo_superadmin | Flutter Web da operação Coelo. |
| apps/coelo_site | Astro para coelo.me. |
| packages/design_system | Tokens, temas, componentes e acessibilidade compartilhados. |
| packages/core_* | Auth, contexto, rede, erros, observabilidade e utilitários estáveis. |
| packages/domain_* | Contextos: perfis, Happens, Now, Moments, Rotina, Chat, Agenda, Mídia, Atividades etc. |
| supabase/migrations | Migrations ordenadas e revisadas. |
| supabase/functions | Edge Functions por comando/capacidade. |
| supabase/tests | Testes SQL, RLS e isolamento. |
| infra/cloudflare | Configurações versionadas de Pages, Workers/R2 e proteção quando aplicável. |
| docs/specs | PRDs, Functional Specs, Technical Specs, ADRs e Test Plans. |

## 5.2 Regras de dependência

- Packages de domínio não dependem de widgets ou SDKs concretos.

- Um contexto não escreve diretamente na tabela pertencente a outro contexto.

- Contratos compartilhados contêm IDs, códigos, timestamps e eventos estáveis — não regras de negócio.

- Happens, Now e Moments compartilham perfis, audiência, mídia, engajamento e entitlements por contrato.

- Mudanças em RLS, Auth, consentimento e suporte exigem revisão humana mesmo quando geradas por IA.

## 5.3 Registro de decisões arquiteturais

Decisões com impacto duradouro serão registradas como ADRs curtos: contexto, decisão, alternativas, consequência, status e data. Exemplos iniciais: Astro para site, R2 para toda mídia, monólito modular, estratégia de outbox, provedor de push e política de contexto ativo.

# 6. Backend, dados e eventos

## 6.1 Postgres multi-tenant

O Coelo usará banco Postgres compartilhado entre tenants. Tabelas de negócio devem possuir institution_id direto ou um caminho determinístico e seguro até a instituição. Pessoas são globais; dados contextuais, memberships, permissões familiares e audiência determinam a visibilidade. RLS é a barreira obrigatória para dados expostos às aplicações.

A organizacao fisica inicial usa `public` como schema base do dominio operacional, `app_private` para funcoes/RPCs privilegiados, `audit` para evidencias e acoes sensiveis, e `analytics` para eventos minimizados, contadores e snapshots. `audit` e `analytics` nao recebem grants diretos para `anon` ou `authenticated`; acesso de interface deve passar por permissoes internas e caminhos server-side.

| Controle | Decisão |
| --- | --- |
| Identidade | people global + auth.users opcional + perfil e contatos verificados. |
| Tenancy | institutions, units, groups e child_contexts. |
| Autorização | memberships, vínculos familiares, permissões contextuais e funções de decisão. |
| Conteúdo | Owner por bounded context; audiência como referência explícita. |
| Integridade | FKs, constraints, estados e timestamps; front-end não é guardião de integridade. |
| Exclusão | Soft delete e histórico onde auditoria exigir; política final depende de retenção aprovada. |
| Segredos | CPF e identificadores adultos protegidos/normalizados conforme Technical Spec. |

## 6.2 RLS e autorização

- Deny by default em tabelas e canais expostos.

- Policies simples quando possível; funções SQL seguras e testadas para decisões complexas.

- Ações administrativas privilegiadas passam por Edge Function ou RPC controlada, nunca por service_role no cliente.

- Realtime aplica autorização compatível com a mesma lógica de contexto.

- Storage lógico e mídia R2 reutilizam a decisão de acesso do objeto de negócio, evitando uma política paralela.

## 6.3 Comandos, queries e Edge Functions

Leituras simples podem usar SDK Supabase com RLS. Comandos sensíveis, operações multi-tabela, geração de convites, alteração de permissões, suporte, URLs de mídia e integração com terceiros devem usar funções server-side. A função valida sessão, contexto, autorização, entitlement, idempotência e auditoria antes de persistir.

## 6.4 Eventos e outbox

O MVP não precisa de um broker dedicado. Eventos de domínio relevantes serão gravados em uma outbox transacional no mesmo commit da mudança de negócio. Processadores idempotentes entregam notificações, analytics, webhooks e automações. O histórico permite retry, investigação e futura migração para uma fila especializada sem mudar os produtores.

| Evento exemplo | Produtor | Consumidores |
| --- | --- | --- |
| institution_created | Tenancy/Administração | Convite, analytics, operação e onboarding. |
| post_published | Happens | Notificações, analytics e projeções de feed. |
| now_published | Now | Expiração, notificação opcional e analytics. |
| moment_ready | Moments/Mídia | Feed, notificação e métricas. |
| routine_recorded | Rotina | Portal do responsável, analytics e pendências. |
| permission_changed | Contexto/Autorização | Auditoria, invalidação de cache e alerta de segurança. |

# 7. Arquitetura de mídia no Cloudflare R2

| Decisão final<br>A opção C foi adotada: toda mídia do produto entra no Cloudflare R2 desde o MVP. A decisão é tecnicamente viável e evita operar dois storages, mas exige uma camada explícita de autorização, metadados e limpeza. Essa complexidade será concentrada no Media Gateway, não espalhada pelos módulos. |
| --- |

Figura 4 — Fluxo de upload e leitura de mídia privada.

## 7.1 Separação entre objeto e metadado

| Camada | Responsabilidade |
| --- | --- |
| R2 | Bytes do arquivo, variantes, thumbnails e objetos temporários. |
| Postgres | media_asset, owner, tenant, tipo, tamanho, checksum, status, classificação, consentimento e vínculos. |
| Media Gateway | Autorizar, assinar URLs, validar extensão/MIME, limite, expiração, idempotência e finalização. |
| Bounded context dono | Decidir se a mídia pode existir e quem pode associá-la a post, rotina, chat ou agenda. |

## 7.2 Regras obrigatórias

- Buckets privados; nenhuma URL pública permanente para conteúdo infantil.

- Upload direto ao R2 somente com URL pré-assinada de curta duração e chave de objeto definida pelo servidor.

- Leitura somente após autorização do recurso; URL GET temporária e sem credenciais expostas.

- Objetos nunca usam nome, CPF, username infantil ou dado sensível no caminho.

- Finalização confirma tamanho, hash, MIME e vínculo; uploads órfãos entram em rotina de limpeza.

- Download é bloqueado na experiência por padrão, sem prometer impedir captura de tela do dispositivo.

- Logs registram IDs e status, não o conteúdo da mídia.

## 7.3 Vídeo e Moments

R2 armazena objetos, mas não substitui uma plataforma de transcodificação. No MVP, Moments aceitará formatos/codecs definidos, duração máxima de dois minutos, compressão no cliente quando segura e criação de thumbnail/validação por processamento assíncrono simples. Streaming adaptativo, múltiplos renditions e transcodificação pesada serão avaliados apenas quando volume, compatibilidade ou experiência justificarem Cloudflare Stream ou pipeline especializado.

## 7.4 Falhas e consistência

| Falha | Tratamento |
| --- | --- |
| URL expirou | Cliente solicita nova autorização; não reutiliza assinatura antiga. |
| Upload concluído sem finalização | Job identifica objeto pendente e conclui ou remove após janela aprovada. |
| Metadado criado sem objeto | Status failed/pending e retry idempotente. |
| Usuário perdeu acesso | Novas URLs deixam de ser emitidas; objeto permanece conforme retenção. |
| Arquivo inválido | Quarentena/rejeição e auditoria; não publicar referência ativa. |

# 8. Realtime, notificações e offline-tolerant

## 8.1 Realtime

Supabase Realtime será usado de forma seletiva. Chat, recibos, estados de envio e atualizações relevantes podem assinar canais autorizados. Feed e agenda não precisam transformar toda leitura em streaming contínuo; paginação, refresh e eventos pontuais reduzem custo e complexidade.

| Uso | Estratégia MVP |
| --- | --- |
| Chat | Assinatura de conversas autorizadas, paginação de histórico e recibos. |
| Happens/Now/Moments | Atualização pontual por perfil/contexto; cache e paginação continuam principais. |
| Rotina | Atualizar portal após confirmação de registro; edição concorrente limitada. |
| Admin/Superadmin | Eventos operacionais seletivos, sem grids inteiros em tempo real. |

## 8.2 Notification Adapter

A arquitetura não amarra o domínio a FCM, APNs, OneSignal ou outro fornecedor. O módulo de notificações recebe um comando interno, resolve preferências, prioridade, template e audiência, e delega a um adapter. Tokens de dispositivo e resultados de entrega ficam protegidos. Push carrega texto mínimo e abre o conteúdo somente após autenticação.

- Interface estável: registerDevice, unregisterDevice, sendToUser, sendToAudience e processReceipt.

- Provider definido em Technical Spec após spike de Flutter, custo, operação e recursos.

- Mensagens críticas e transacionais são separadas de dicas opcionais.

- Retry usa idempotency key; falhas permanentes removem token inválido.

## 8.3 Offline-tolerant

| Módulo | Comportamento MVP |
| --- | --- |
| Happens/Agenda | Cache read-only de itens recentes e indicação de atualização. |
| Rotina | Rascunho local por criança/contexto e fila curta de envio. |
| Chat | Histórico recente em cache; envio offline pode ficar pendente com status visível. |
| Mídia | Compressão, retry e retomada quando suportada; status pending/failed. |
| Admin/Superadmin | Online-first; sem sincronização local complexa. |

| Limite consciente<br>Offline-tolerant não significa replicar o banco no celular. Full offline-first exige resolução de conflito, migração local, criptografia e sincronização bidirecional; somente entra após o piloto provar valor operacional. |
| --- |

# 9. Segurança, privacidade e LGPD

O Coelo combina dados infantis, rotina, imagens, comunicação e múltiplos tenants. A arquitetura deve ser tratada como risco moderado-alto/elevado. Segurança é uma propriedade transversal: identidade, banco, Realtime, mídia, suporte, notificações, analytics e CI/CD precisam aplicar minimização, autorização e auditabilidade.

## 9.1 Controles por camada

| Camada | Controles mínimos |
| --- | --- |
| Cliente | Secure storage para tokens, limpeza no logout, certificate/TLS padrão, sem secrets e sem service_role. |
| Borda | TLS, WAF, rate limiting, Turnstile, proteção de formulários e regras contra abuso. |
| Auth | Recuperação sem enumeration, reautenticação para ações sensíveis, MFA obrigatoria para Owner Coelo e MFA recomendado aos demais privilegiados. |
| Banco | RLS deny-by-default, FKs, funções seguras, testes de tenant leakage e migrations revisadas. |
| Mídia | R2 privado, URLs temporárias, consentimento, classificação e logs mínimos. |
| Suporte | Sessão identificada, motivo, tenant, escopo, início/fim e ações sensíveis auditadas. |
| CI/CD | Secrets por ambiente, aprovação de produção, SAST/dependency scan e testes de RLS. |

## 9.2 Matriz de autorização

A decisão de acesso considera, nesta ordem lógica: sessão válida, pessoa ativa, contexto ativo, membership/papel, vínculo com unidade/grupo/criança, audiência do recurso, consentimento ou restrição de mídia, entitlement do módulo e estado do objeto. UI oculta ações, mas a decisão final ocorre no banco ou backend.

## 9.3 Auditoria e dados mínimos

- Audit log registra ator, ação, objeto, tenant, contexto, resultado e timestamp.

- Analytics e audit logs são separados: analytics mede produto; auditoria prova ação sensível.

- Logs não copiam mensagem, rotina, imagem ou dado de saúde quando IDs e resumo bastarem.

- Solicitações de titular, incidentes, consentimentos e mudanças de permissão mantêm histórico verificável.

- A arquitetura não substitui parecer jurídico, DPA, RIPD/DPIA ou definição formal de controlador e operador.

## 9.4 Verificação

- Testes automatizados de RLS com usuários de tenants e papéis diferentes.

- Threat modeling antes do piloto e a cada módulo sensível.

- Checklist OWASP ASVS para web/API e MASVS para mobile.

- Teste de restauração de backup e simulação de revogação de chaves/sessões.

- Revisão humana obrigatória de policies, funções SECURITY DEFINER e qualquer uso de service role.

# 10. Ambientes, CI/CD e implantação

Figura 5 — Fluxo de código, ambientes e promoção até produção.

## 10.1 Ambientes oficiais

| Ambiente | Infraestrutura | Uso |
| --- | --- | --- |
| Local | Supabase CLI local + Flutter/Astro locais + mocks controlados | Desenvolvimento, migrations, seeds e testes rápidos. |
| Desenvolvimento | Supabase Dev + Cloudflare previews | Integração contínua e validação diária. |
| Homologação | Supabase Stage + domínios de homologação | QA, teste de release, migração e validação com dados fictícios. |
| Produção | Supabase Prod + Cloudflare + lojas | Dados reais, observabilidade, backup e acesso restrito. |

## 10.2 Estratégia de branches

| Branch | Destino | Regra |
| --- | --- | --- |
| feature/* | Preview/CI | PR obrigatório, lint, testes e revisão. |
| develop | Desenvolvimento | Integração contínua; migrations aplicadas em Dev. |
| release/* | Homologação | Release candidate; freeze e QA. |
| main | Produção | Merge aprovado e promoção manual. |
| hotfix/* | Homologação → Produção | Fluxo curto, testes obrigatórios e post-mortem se incidente. |

## 10.3 Pipeline mínimo

1. Detectar caminhos alterados e executar apenas jobs relevantes de Flutter, Astro, Supabase ou infraestrutura.

1. Formatar, lintar, analisar dependências e executar testes unitários.

1. Subir Supabase local/efêmero para migrations, seeds e testes de RLS.

1. Buildar Flutter web/mobile e Astro; verificar artefatos e variáveis obrigatórias.

1. Publicar previews em branches aplicáveis.

1. Promover migrations antes ou junto do código com estratégia backward-compatible.

1. Produção exige aprovação manual, registro da versão e plano de rollback.

## 10.4 Domínios e hospedagem

| Domínio | Tecnologia | Observação |
| --- | --- | --- |
| coelo.me | Astro em Cloudflare Pages | Público, SEO e marketing. |
| app.coelo.me | Flutter Web em Cloudflare Pages | Complemento web do App; apps nativos nas lojas. |
| admin.coelo.me | Flutter Web em Cloudflare Pages | Acesso autenticado da instituição. |
| superadmin.coelo.me | Flutter Web em Cloudflare Pages | Acesso interno com privilegios; MFA obrigatoria para Owner Coelo e recomendada para demais perfis privilegiados. |
| api/serviços | Supabase + Edge Functions | Endpoints gerenciados e funções server-side. |
| mídia | R2 privado | Sem domínio público direto para objetos infantis. |

# 11. Observabilidade, analytics e operação

## 11.1 Três trilhas separadas

| Trilha | Finalidade | Exemplos |
| --- | --- | --- |
| Logs técnicos | Diagnóstico de execução. | Erro de função, latência, retry, status de integração. |
| Audit logs | Evidência de ação sensível. | Permissão alterada, suporte aberto, mídia acessada, tenant suspenso. |
| Analytics events | Uso e produto. | Abertura de Happens, rotina registrada, agenda respondida, adoção por módulo. |

## 11.2 Correlação e privacidade

- Cada requisição/comando sensível recebe correlation_id e, quando aplicável, idempotency_key.

- Logs estruturados usam IDs técnicos; nomes e conteúdo infantil são omitidos por padrão.

- Métricas agregadas por tenant e módulo devem evitar perfilamento infantil desnecessário.

- Alertas iniciais cobrem falha de login, picos de erro, falha de função, fila/outbox atrasada e acesso negado anômalo.

## 11.3 Operação e suporte

| Capacidade | MVP |
| --- | --- |
| Health operacional | Status de integrações, contagem de erros e eventos pendentes. |
| Suporte | Sessões auditadas, sem impersonation invisível e sem compartilhamento de senha. |
| Feature flags/entitlements | Ativação por plano e tenant; validação no backend. |
| Jobs | Limpeza de uploads órfãos, expiração de Now, retries e manutenção de tokens. |
| Runbooks | Login indisponível, tenant leakage suspeito, mídia inacessível, fila parada e incidente. |

## 11.4 BI futuro

`analytics.analytics_events`, `analytics.notice_events`, `analytics.usage_counters` e `analytics.usage_snapshots` nascem no Postgres operacional com esquema mínimo e governado. Quando volume e perguntas analíticas justificarem, um pipeline incremental em Python poderá levar dados pseudonimizados a uma camada analítica/warehouse. O produto não fará consultas pesadas de BI diretamente no banco transacional.

# 12. Dimensionamento do piloto e evolução

## 12.1 Referência de capacidade

O cenário oficial é um piloto com 1 a 5 instituições e até 2.000 usuários cadastrados. Esse número não equivale a 2.000 usuários simultâneos. Antes do lançamento, o Coelo deve definir jornadas de carga realistas — abertura de feed, publicação, registro de rotina, chat e upload — e executar testes por perfil de uso. A arquitetura prioriza isolamento e observabilidade; capacidade será ajustada com métricas reais.

## 12.2 Estratégias de escala sem mudar a arquitetura

- Paginação por cursor, índices baseados em queries reais e projeções de leitura para feeds.

- Compressão, thumbnail, limites e lifecycle para reduzir custo de mídia.

- Processamento assíncrono por outbox para notificações, mídia e integrações.

- Cache de conteúdo público no Cloudflare e cache local controlado no App.

- Separação de queries administrativas pesadas e exportações em jobs.

- Rate limits por usuário, IP, tenant e tipo de operação sensível.

## 12.3 Gatilhos para extrair serviços

| Gatilho | Possível extração |
| --- | --- |
| Moments exige transcodificação e throughput próprios | Media/Video Service. |
| Chat precisa de disponibilidade e escala independentes | Chat Service. |
| Cobrança exige compliance e integrações específicas | Billing Service. |
| Notificações acumulam filas, provedores e regras complexas | Notification Service. |
| Contexto precisa de ciclo de deploy/equipe próprios | Serviço do bounded context correspondente. |
| Custo/risco comprovado cai com separação | Extração aprovada por ADR e métricas. |

## 12.4 Evolução por horizonte

| Horizonte | Arquitetura |
| --- | --- |
| MVP/Piloto | Monólito modular, Supabase, R2 privado, provider-neutral push, offline-tolerant e CI/CD completo. |
| Pós-piloto | Otimização por métricas, processamento de vídeo, observabilidade madura, automações e relatórios. |
| Próximas fases | Cobrança, matrícula, integrações/API, IA e warehouse conforme bounded contexts já mapeados. |
| Escala | Read models, filas especializadas, serviços extraídos e infraestrutura dedicada somente por necessidade. |

# 13. Requisitos não funcionais

| Categoria | Requisito macro v1 |
| --- | --- |
| Segurança | Zero tolerância a acesso cross-tenant; RLS e autorização server-side em toda superfície privada. |
| Privacidade | Minimização, mídia privada, payload mínimo, busca infantil restrita e consentimentos versionáveis. |
| Confiabilidade | Retry idempotente, rascunhos, estados claros, outbox e recuperação de falhas sem duplicidade. |
| Performance | Paginação, thumbnails, consultas indexáveis e carregamento progressivo em conexão móvel comum. |
| Disponibilidade | Dependência de serviços gerenciados com monitoramento, backup e runbooks proporcionais ao piloto. |
| Auditabilidade | Ações sensíveis atribuíveis a ator, contexto, objeto, resultado e timestamp. |
| Manutenibilidade | Monorepo, módulos por domínio, contratos versionados, ADRs e testes automatizados. |
| Acessibilidade | WCAG 2.2 AA como mínimo no Design System; teclado, foco, leitores e alvos adequados. |
| Portabilidade | Adapters para push, mídia e analytics reduzem acoplamento a fornecedores. |
| Escalabilidade | Escala vertical/gerenciada e otimizações antes de microserviços; extração por gatilhos. |
| Observabilidade | Logs estruturados, correlação, métricas e alertas sem conteúdo sensível desnecessário. |
| Qualidade de dados | FKs, constraints, deduplicação, importação com prévia e histórico de vínculos. |

## 13.1 Quality gates antes do piloto

- Suite de RLS e isolamento executada no CI e aprovada.

- Spike de mídia R2 validando upload, leitura autorizada, expiração e limpeza de órfãos.

- Threat model e checklist de segurança dos fluxos Auth, mídia, suporte e permissões.

- Restore de backup testado no ambiente de homologação.

- Builds reproduzíveis de Flutter, Astro e migrations por versão.

- Teste de carga com jornadas reais e orçamento de erro definido.

- Termos, bases legais, DPA e retenção revisados por responsável jurídico antes de dados reais.

# 14. Riscos e mitigação

| Risco | Nível | Mitigação arquitetural |
| --- | --- | --- |
| Vazamento entre tenants | Crítico | RLS deny-by-default, testes automatizados, funções seguras e auditoria. |
| Mídia privada exposta | Crítico | R2 privado, gateway, URLs curtas, caminhos opacos e nenhuma chave no cliente. |
| Permissão duplicada entre UI e backend | Crítico | Backend/RLS como fonte final; UI apenas representa a decisão. |
| R2 aumentar complexidade do MVP | Alto | Media Gateway único, spike inicial, SDK S3 e escopo de vídeo limitado. |
| Moments exigir transcodificação | Alto | Formatos controlados, compressão, job simples e gatilho para serviço especializado. |
| MVP virar microserviços precoces | Alto | Monólito modular oficial e ADR obrigatório para extração. |
| Monólito virar “massa única” | Alto | Ownership por contexto, packages separados, migrations e contratos. |
| Ambientes divergirem | Alto | Migrations/infra versionadas, seeds, pipeline e promoção controlada. |
| Notificações acoplarem fornecedor | Médio | Notification Adapter e modelo interno de mensagem. |
| Offline gerar conflito de dados | Médio | Offline-tolerant limitado, comandos idempotentes e conflito simples. |
| Custo de mídia crescer | Médio/alto | Compressão, limites, variantes, lifecycle e métricas por tenant/módulo. |
| Coding agent alterar segurança | Crítico | Revisão humana obrigatória e testes de regressão RLS/Auth/LGPD. |

## 14.1 Principais trade-offs assumidos

| Escolha | Ganho | Custo assumido |
| --- | --- | --- |
| Astro em vez de WordPress | Performance, versionamento e integração com CI/CD. | Conteúdo exige fluxo técnico/Git até existir CMS. |
| R2 para toda mídia | Um storage, controle explícito e preparação para volume. | Gateway, assinaturas, consistência e processamento próprios. |
| Supabase compartilhado | Velocidade, RLS, Auth e operação reduzida. | Exige disciplina forte de policies e modelagem multi-tenant. |
| Flutter para três superfícies | Design system e conhecimento compartilhados. | Web administrativa precisa atenção a acessibilidade e tabelas. |
| Monólito modular | Menor custo operacional e entrega rápida. | Fronteiras dependem de governança e testes, não de rede. |

# 15. Critérios de aceite e próximas specs

## 15.1 Critérios de aceite da arquitetura macro

- Todos os ambientes e superfícies possuem tecnologia, responsabilidade e domínio definidos.

- O site orientado a SEO está oficialmente separado das aplicações Flutter autenticadas.

- Happens, Now e Moments permanecem módulos independentes e compostos no App.

- R2 é o storage único de mídia e o Postgres é a fonte oficial dos metadados e permissões.

- Nenhum cliente contém service_role, chave R2 ou segredo de terceiro.

- RLS, autorização de Realtime, suporte e mídia possuem estratégia de teste e auditoria.

- O monorepo permite pipelines por caminho e promoção Dev → Homologação → Produção.

- Notificação é desacoplada do fornecedor e offline permanece tolerante, não full offline-first.

- Gatilhos de escala e extração estão documentados sem obrigar microserviços no MVP.

## 15.2 Próximas Technical Specs

1. Technical Spec do monorepo, workspaces, convenções, dependências e code ownership.

1. Technical Spec de Supabase: schemas/tabelas, migrations, RLS, funções, Realtime e outbox.

1. Technical Spec do Superadmin Completo v1: ativacao de instituicao, Owner/MFA, usuarios internos, avisos/popups, suporte, auditoria, eventos, contadores e snapshots.

1. Technical Spec do Media Gateway R2: chaves, CORS, URLs, finalização, variantes e limpeza.

1. Technical Spec de Auth e contexto ativo: sessão, recovery, MFA, convites e cache.

1. Technical Spec de Notification Adapter e spike de fornecedor.

1. Technical Spec de Flutter: estado, navegação, repositories, cache e offline queue.

1. Technical Spec de CI/CD, secrets, domínios, deploy e rollback.

1. Test Plan multi-tenant, mídia, permissões, suporte, carga e incidentes.

## 15.3 Spikes obrigatórios antes do desenvolvimento em escala

| Spike | Resultado esperado |
| --- | --- |
| RLS multi-papel | Provar pessoa global, dois tenants e troca de contexto sem vazamento. |
| Mídia R2 | Upload direto, URL GET temporária, revogação lógica, retry e órfãos. |
| Flutter Web | Validar tabelas, acessibilidade, rotas e performance de Admin/Superadmin. |
| Realtime Chat | Canal autorizado, paginação, reconexão e recibos. |
| CI migrations | Validar migration backward-compatible e rollback operacional. |

| Próxima entrega recomendada<br>Criar primeiro a fundacao de dados do Superadmin Completo v1: schema, RLS, Owner/MFA, ativacao de instituicao, auditoria, avisos/popups segmentados e eventos/contadores/snapshots. Depois: wireframe Figma em desktop/tablet/mobile -> componentes Flutter compartilhaveis -> telas do fluxo de ativacao -> demais fluxos do Superadmin. |
| --- |

# 16. Aditivo 2026-07-24 — Contextos, Chat E Assiduidade

## 16.1 Projecao De Experiencias

`people` permanece como raiz global. Experiencia familiar ou profissional e
uma projecao dos vinculos ativos da pessoa, nunca uma nova identidade. Toda
requisicao privada deve resolver:

1. pessoa autenticada;
2. instituicao;
3. experiencia/papel;
4. unidade, grupo, atividade ou crianca aplicavel;
5. capacidade efetiva;
6. restricoes explicitas.

Trocar experiencia recompõe navegacao, dados, realtime e caches. Uma negacao
individual explicita prevalece sobre allows herdados no mesmo escopo.

## 16.2 Dependencias Entre Dominios

```text
Identity
  -> Tenancy
    -> Family Authorization / Professional Authorization
      -> Activities
        -> Chat / Attendance / Agenda / Routine / Media

Comandos sensiveis -> Audit
Eventos operacionais -> Notifications / Analytics
```

Family Authorization separa responsaveis com acesso ao Coelo de pessoas
autorizadas apenas para emergencia, retirada ou transporte. Professional
Authorization suporta papeis acumulados, descendentes automaticos, selecoes
fixas e atribuicoes por crianca.

## 16.3 Attendance

Attendance/Assiduidade e um dominio transacional proprio. Ele guarda sessoes,
participantes esperados, avisos familiares, registros oficiais, motivos,
justificativas e revisoes. Grupo e atividade fornecem contexto, mas nao sao a
fonte do registro.

Chat pode exibir cards e respostas sobre presenca, sem se tornar a fonte
oficial. Notifications agenda lembretes e pendencias. Analytics consome apenas
eventos minimizados e agregados autorizados.

## 16.4 Fronteiras De Seguranca

- Tabelas expostas usam RLS por tenant e contexto.
- Operacoes compostas e sensiveis usam RPC/caminho server-side auditado.
- Revogacao invalida leitura, escrita, realtime, notificacoes e caches.
- Mensagens preservam snapshot de autor, papel e contexto.
- Anexos de justificativa e CPFs permanecem minimizados e privados.
- Unidade nunca amplia acesso para unidade irma.

# 17. Fontes e referências

## 16.1 Fontes internas

- Coelo — Product Vision Oficial v1.

- Coelo — PRD Master Oficial v1.

- Coelo — PRD App Oficial v1.

- Coelo — PRD LGPD, Segurança e Mídia Oficial v1.

- Coelo — PRD Auth, Multi-tenant e Permissões Oficial v1.

- Coelo — PRD Superadmin Oficial v1.

- Coelo — PRD Admin Oficial v1.

- Coelo — PRD Modelo de Dados Master Oficial v1.

- Coelo — Design System Oficial v1.

- Coelo — Mapa de Domínios Oficial v1.

- Mapa competitivo de apps de agenda e comunicação escolar no Brasil.

## 16.2 Fontes externas oficiais pesquisadas

| Fonte | URL |
| --- | --- |
| C4 Model — Diagrams | https://c4model.com/diagrams |
| Flutter — Guide to app architecture | https://docs.flutter.dev/app-architecture/guide |
| Astro — Why Astro? | https://docs.astro.build/en/concepts/why-astro/ |
| Astro — Sitemap | https://docs.astro.build/en/guides/integrations-guide/sitemap/ |
| Cloudflare Pages — Astro | https://developers.cloudflare.com/pages/framework-guides/deploy-an-astro-site/ |
| Cloudflare R2 — S3 API | https://developers.cloudflare.com/r2/api/s3/ |
| Cloudflare R2 — Presigned URLs | https://developers.cloudflare.com/r2/api/s3/presigned-urls/ |
| Supabase — Row Level Security | https://supabase.com/docs/guides/database/postgres/row-level-security |
| Supabase — Realtime Authorization | https://supabase.com/docs/guides/realtime/authorization |
| Supabase — Branching / environments | https://supabase.com/docs/guides/deployment/branching |
| Supabase — Edge Functions | https://supabase.com/docs/guides/functions |
| Firebase — Cloud Messaging for Flutter | https://firebase.google.com/docs/cloud-messaging/flutter/get-started |
| OWASP — ASVS | https://owasp.org/www-project-application-security-verification-standard/ |
| OWASP — MASVS | https://mas.owasp.org/MASVS/ |

## 16.3 Nota de atualização

Fontes externas consultadas em 21/06/2026. Serviços gerenciados, limites, preços, APIs e recomendações podem mudar. A Technical Spec deve verificar novamente a documentação oficial antes da implementação e registrar versões relevantes de SDKs e ferramentas.

## 16.4 Registro final das escolhas do fundador

| Pergunta | Resposta consolidada |
| --- | --- |
| Site e SEO | Opção B; arquitetura escolhe Astro para coelo.me. |
| Repositório e ambientes | Opção A; GitHub monorepo + Local, Dev, Homologação e Produção. |
| Mídia | Preferência por B e autorização para C se viável; arquitetura adota C com Media Gateway. |
| Push | Opção C; provedor desacoplado e decisão posterior. |
| Escala | Opção A; piloto com 1–5 instituições e até 2.000 usuários. |

FIM · COELO ARQUITETURA MACRO OFICIAL v1
