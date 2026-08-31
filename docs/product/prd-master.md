---
title: "Coelo PRD Master v1"
source_file: "Coelo PRD Master v1.docx"
source_copy: "docs/source/originals/docx/Coelo PRD Master v1.docx"
original_path: "C:/Users/adrie/Desktop/Coelo/PRD/Coelo PRD Master v1.docx"
supplemental_source: "decisions/0015-contextual-people-authorizations-attendance.md; specs/015-contextual-people-access-attendance.md; decisions/0028-superadmin-agenda-product-surface.md; specs/006-comunicacao-agenda.md"
status: "derived-from-official-docx"
version: "v1"
generated_at: "2026-07-24"
---

<!-- Documento derivado de fonte oficial. Edite a fonte DOCX ou registre uma decisao antes de alterar conteudo normativo. -->
| Coluna 1 | COELO<br>PRD Master Oficial v1<br>coelo.me · Produto completo + MVP/v1 + roadmap |
| --- | --- |

Versão: v1.0 | Data: 20/06/2026 | Status: Draft executivo para validação

| Visão em uma frase<br>Coelo é o superapp simples, familiar e confiável que conecta instituições, famílias e equipes em torno da comunicação, rotina e acompanhamento infantil, com experiência inspirada em rede social privada. |
| --- |

| Simples como Airbnb | Visual como Instagram | Confiável como escola |
| --- | --- | --- |

Documento base para transformar a visão do Coelo em especificações, design, arquitetura, backlog e desenvolvimento com IA/coding agents. Este PRD foi construído a partir dos documentos internos do projeto Coelo e de pesquisa atualizada em fontes oficiais e confiáveis sobre PRD, SaaS multi-tenant, LGPD, Supabase, Flutter, offline-first, segurança, Cloudflare e ferramentas de Spec-Driven Development.

| Item | Decisão |
| --- | --- |
| Produto | Coelo - rede privada de cuidado e comunicação infantil. |
| Categoria | Superapp de comunicação e rotina infantil para instituições, famílias e equipes. |
| Escopo do documento | Produto completo, MVP/v1, roadmap v2/v3/futuro e base para sub-PRDs. |
| Stack recomendada | Flutter/Dart + Supabase/Postgres/Auth/RLS/Storage/Realtime/Edge Functions; Cloudflare como camada de borda. |
| Critério norteador | Privacidade infantil, simplicidade radical, multi-tenant seguro e uso diário real. |

# Sumário executivo do documento

| # | Seção |
| --- | --- |
| 1 | 1. Capa e controle de versão |
| 2 | 2. Resumo executivo |
| 3 | 3. Visão do produto |
| 4 | 4. Problema/dor |
| 5 | 5. Oportunidade de mercado |
| 6 | 6. Público-alvo |
| 7 | 7. Personas |
| 8 | 8. Jobs To Be Done |
| 9 | 9. Proposta de valor |
| 10 | 10. Princípios de produto |
| 11 | 11. Escopo do produto completo |
| 12 | 12. Escopo do MVP/v1 |
| 13 | 13. Fora de escopo do MVP |
| 14 | 14. Roadmap v1, v2, v3 e futuro |
| 15 | 15. Estrutura multi-tenant |
| 16 | 16. Ambientes/domínios |
| 17 | 17. Papéis, perfis e permissões |
| 18 | 18. Fluxos principais |
| 19 | 19. Módulos do produto |
| 20 | 20. Superadmin |
| 21 | 21. Admin |
| 22 | 22. App |
| 23 | 23. Site institucional |
| 24 | 24. Feed social privado |
| 25 | 25. Stories/Momentos |
| 26 | 26. Chat/Canais |
| 27 | 27. Agenda |
| 28 | 28. Diário de rotina |
| 29 | 29. Portal do responsável |
| 30 | 30. Notificações |
| 31 | 31. Identidade, login, @username e recuperação de conta |
| 32 | 32. Modelo conceitual de dados |
| 33 | 33. Eventos, logs, analytics e preparação para dashboards |
| 34 | 34. Segurança, LGPD e privacidade infantil |
| 35 | 35. Requisitos funcionais |
| 36 | 36. Requisitos não funcionais |
| 37 | 37. Critérios de aceite gerais |
| 38 | 38. Métricas de sucesso |
| 39 | 39. Riscos e mitigação |
| 40 | 40. Dependências técnicas |
| 41 | 41. Arquitetura recomendada |
| 42 | 42. Offline-first, SQLite e sincronização |
| 43 | 43. White label |
| 44 | 44. Estratégia para IA/coding agents e Spec-Driven Development |
| 45 | 45. Sub-PRDs recomendados |
| 46 | 46. Perguntas em aberto |
| 47 | 47. Decisões oficiais |
| 48 | 48. Próximos passos |
| 49 | 49. Fontes e referências pesquisadas |
| 50 | Anexos executivos |

# 1. Capa e controle de versão

| Campo | Valor |
| --- | --- |
| Documento | PRD Master Oficial v1 - Coelo |
| Owner | Fundador/Produto Coelo |
| Público interno | Produto, design, engenharia, dados, segurança, jurídico, operações e agentes de coding. |
| Status | Draft executivo para revisão e versionamento. |
| Base interna | Product Vision Oficial v1, História da Logo e Marca Oficial v1 e Mapa competitivo de apps de agenda e comunicação escolar no Brasil. |
| Base externa | Pesquisa web atualizada em fontes oficiais e referências reconhecidas; fontes no final. |

| Versão | Data | Mudança | Responsável |
| --- | --- | --- | --- |
| v1.0 | 20/06/2026 | Criação do PRD Master cobrindo produto completo, MVP/v1, roadmap e arquitetura recomendada. | Produto Coelo |
| v1.1 | A definir | Revisão após decisões de modelagem, protótipo técnico de RLS e validação do piloto. | Produto + Engenharia |
| v2.0 | A definir | Atualização após MVP em piloto real e priorização da próxima fase. | Produto + Negócio |

# 2. Resumo executivo

O Coelo nasce para resolver uma dor diária: famílias, instituições e equipes precisam acompanhar a rotina infantil em um ambiente organizado, visual, privado e confiável. O produto não deve nascer como ERP escolar completo, nem como um grupo de WhatsApp gourmet. A tese central é criar uma camada de relacionamento, rotina e comunicação com experiência social privada, mas governança institucional.

O MVP/v1 será forte: login unificado, estrutura multi-tenant, Superadmin, Admin, App mobile, feed privado, comunicados, confirmação de leitura, stories/momentos, chat completo, agenda, diário de rotina, portal do responsável, notificações e base de dados preparada para dashboards futuros.

A recomendação técnica é usar Flutter/Dart para Superadmin, Admin e App, com design system compartilhado, Supabase como backend principal e Cloudflare como camada de borda. O MVP deve ser offline-tolerant, com cache e fila local para ações críticas, mas não full offline-first em todo o sistema no primeiro release.

| Decisão de produto mais importante<br>O Coelo deve tratar identidade como pessoa única na plataforma e papéis como vínculos contextuais. A mesma pessoa pode ser professor em uma instituição, responsável em outra, coordenador em outra e pai/professor na mesma instituição, sempre com permissões isoladas por contexto. |
| --- |

# 3. Visão do produto

Ser a plataforma mais simples, humana e confiável para conectar instituições infantis, famílias e equipes em torno da rotina, comunicação e cuidado da criança.

| Dimensão | Definição Coelo |
| --- | --- |
| Visão | Plataforma simples, humana e confiável para rotina, comunicação e cuidado infantil. |
| Categoria | Superapp de comunicação e rotina infantil para instituições, famílias e equipes. |
| Posicionamento | Rede privada de cuidado e comunicação infantil para acompanhar a rotina da criança com clareza, segurança e leveza. |
| Promessa | Dar clareza para a família, praticidade para a equipe e confiança para a instituição. |
| Diferencial | Experiência visual e familiar, com governança multi-tenant e privacidade por padrão. |

# 4. Problema/dor

| Público | Dor principal | Resposta do Coelo |
| --- | --- | --- |
| Famílias/responsáveis | Pouca visibilidade da rotina, comunicados perdidos, ansiedade por falta de informação e dependência de canais informais. | Feed privado, diário de rotina, agenda, fotos, notificações claras, histórico e confirmação de leitura. |
| Instituições | Comunicação espalhada, falta de registro, baixa padronização, dependência de WhatsApp e dificuldade de demonstrar valor para famílias. | Canal institucional rastreável, permissões, relatórios futuros, histórico, templates e governança por unidade/grupo. |
| Professores/equipe | Retrabalho, muitos canais, pouco tempo para registrar rotina e ferramentas burocráticas. | Fluxos rápidos, preenchimento em lote, templates, mídia simples, rascunhos e experiência semelhante a apps conhecidos. |
| Direção/coordenação | Baixa visibilidade operacional sobre leitura, engajamento, rotinas pendentes e qualidade da comunicação. | Eventos de analytics desde o MVP e dashboards futuros preparados desde a modelagem. |

# 5. Oportunidade de mercado

A pesquisa competitiva interna e a verificação em fontes públicas recentes indicam convergência funcional entre apps de comunicação escolar: comunicados, confirmação de leitura, chat/canais, agenda/eventos, diário de rotina, fotos, autorizações, pagamentos, matrícula digital, dashboards e integrações. A oportunidade do Coelo é não disputar como ERP pesado no início, mas vencer por UX, implantação simples, modularidade e confiança.

| Leitura de mercado | Implicação para o Coelo |
| --- | --- |
| Communication-first é porta de entrada | Feed/comunicados, chat/canais, agenda e rotina devem ser o coração do MVP. |
| ERP/financeiro aumenta complexidade | Pagamentos, matrícula digital, financeiro e LMS ficam para próxima fase, sem travar o modelo de dados. |
| White label aparece em concorrentes | Preparar estrutura, mas evitar app dedicado no MVP para não virar novela mexicana com deploy em loja. |
| Confirmação de leitura e relatórios vendem para direção | Eventos e logs devem nascer desde o MVP, mesmo sem dashboard visual completo. |
| Rotina infantil é valor emocional | Diário de rotina completo deve ser diferencial real, especialmente para educação infantil, terapias e atividades extracurriculares. |

| Nota de honestidade<br>Este PRD não inventa TAM, market share ou receita do mercado. Onde não há fonte confiável pública, a recomendação fica qualitativa e baseada em benchmarks funcionais. |
| --- |

# 6. Público-alvo

O Coelo deve nascer amplo o suficiente para qualquer instituição que cuide, acompanhe ou atenda crianças e participantes, mas com recorte inicial operacional em escola infantil/escola dos filhos para validar uso real.

| Segmento | Aderência inicial | Observação de produto |
| --- | --- | --- |
| Escolas infantis | Muito alta | Dor forte em rotina, fotos, sono, alimentação, higiene e comunicação com família. |
| Escolas até 12 anos | Alta | Comunicados, agenda, autorizações, ocorrências e relacionamento família-instituição. |
| Cursos de idiomas | Média/alta | Agenda, comunicados, presença, evolução e atendimento aos responsáveis. |
| Escolinhas esportivas | Média/alta | Treinos, eventos, fotos, ocorrências e comunicação com responsáveis. |
| Terapias e clínicas infantis | Média | Demanda maior por sigilo e dados sensíveis; exige cuidado jurídico e de permissões. |
| Atividades extracurriculares | Média/alta | Grupos, agenda, comunicados, rotina e presença. |

# 7. Personas

| Persona | Objetivo | Dor | O que precisa amar |
| --- | --- | --- | --- |
| Diretor(a)/dono(a) | Profissionalizar comunicação e reduzir retrabalho. | Perda de controle, reclamações e baixa visibilidade. | Indicadores, organização, implantação simples e percepção de valor pelas famílias. |
| Coordenador(a) | Garantir rotina e comunicação por unidade/turma. | Cobranças manuais, mensagens espalhadas e baixa padronização. | Templates, supervisão, permissões e auditoria sem burocracia. |
| Professor(a)/equipe | Registrar rotina em poucos minutos. | Pouco tempo, retrabalho e medo de ferramenta complexa. | Fluxo rápido, lote por turma, mídia fácil e rascunhos. |
| Responsável | Acompanhar a rotina e confiar no cuidado. | Ansiedade, falta de clareza e comunicados perdidos. | Feed visual, diário da criança, agenda e notificações úteis. |
| Equipe Coelo | Gerenciar clientes, suporte, planos e saúde operacional. | Sem visão multi-tenant e risco de acesso indevido. | Superadmin com permissões, logs, avisos e dados confiáveis. |

# 8. Jobs To Be Done

| Quando... | Eu quero... | Para... |
| --- | --- | --- |
| sou responsável e meu filho está na instituição | ver de forma simples o que aconteceu no dia | sentir tranquilidade e confiança. |
| sou professor e preciso registrar a rotina | preencher rápido por turma e ajustar por criança | não perder tempo em tarefa repetitiva. |
| sou coordenador | acompanhar comunicações, ocorrências, rotinas pendentes e gestão da equipe | garantir padrão e evitar ruídos. |
| sou diretor | ter um canal oficial e dados de leitura/engajamento, gerir equipe e empresa | melhorar relacionamento e retenção das famílias. |
| sou equipe Coelo | ativar instituições e monitorar uso | escalar operação com segurança. |

# 9. Proposta de valor

| Para | Valor entregue |
| --- | --- |
| Famílias | Rotina clara, comunicação confiável, fotos/momentos e histórico da criança em ambiente privado. |
| Instituições | Canal oficial, menos WhatsApp, mais registro, mais profissionalismo e base para indicadores. |
| Equipe | Registro rápido, menos retrabalho e comunicação contextualizada por unidade/grupo/criança. |
| Coelo | SaaS B2B/B2B2C modular, escalável e com potencial de expansão para IA, pagamentos, matrícula e BI. |

# 10. Princípios de produto

- Simplicidade radical: qualquer responsável, professor ou diretor deve entender o essencial sem treinamento longo.

- Visual antes de burocrático: rotina infantil deve ser vista e compreendida, não enterrada em textos frios.

- Privado por padrão: nada de rede social aberta; tudo depende de vínculo, contexto e permissão.

- Confiança acima de volume: melhor poucas informações claras, auditáveis e úteis do que excesso de notificações.

- Multi-tenant consciente: a pessoa é única; o papel é contextual; a permissão é sempre por vínculo.

- Modularidade: comunicação e rotina primeiro; financeiro, matrícula, IA, LMS e ERP depois.

- Dados preparados desde cedo: eventos, logs e histórico nascem no MVP para viabilizar dashboard futuro.

- Proteção infantil como requisito de produto, não “pendência jurídica”.

# 11. Escopo do produto completo

| Camada | Escopo completo desejado |
| --- | --- |
| Identidade e acesso | Login unificado, recuperação por múltiplos caminhos, convites, deduplicação, papéis contextuais e @username com proteção infantil. A ideia é que todos os usuários tenho @username, pensando no futuro do crescimento da plataforma. A liberação para “seguir” será feita por link de convite e/ou código que expira. |
| Multi-tenant | Instituição, unidade, grupo/turma/perfil, criança/aluno/atendido, responsáveis, equipe e vínculos multi-contexto. |
| Comunicação social privada | Feed, comunicados, posts, mídia, confirmação de leitura, stories/momentos, comentários controlados, reações e perfis institucionais. |
| Chat/canais | Chat 1:1 contextual, canais por turma/unidade, atendimento responsável-instituição, chat interno e auditoria. |
| Rotina infantil | Diário de rotina, alimentação, sono, higiene, saúde, humor, atividades, ocorrências, presença (Assiduidade), pontualidade. |
| Agenda | Eventos, lembretes, autorizações, presença/RSVP, recorrências e integração futura. |
| Gestão | Superadmin, Admin, unidades, grupos, atividades, pessoas, permissões, templates, conteúdo global e configurações. |
| Dados e BI | Eventos, logs, auditoria, métricas operacionais, dashboards futuros e exportações. |
| Expansões | IA, pagamentos, matrícula digital, financeiro leve, integrações, white label, relatórios e módulos especializados. |

# 12. Escopo do MVP/v1

| Definição de MVP/v1<br>Neste PRD, v1 = MVP forte. O produto completo fica mapeado, mas o desenvolvimento inicial deve ser fatiado em marcos internos para não transformar o MVP em um “monstro de estimação”. |
| --- |

| Módulo | Entra no MVP/v1 | Observação |
| --- | --- | --- |
| Login unificado | Sim | E-mail/celular, convites, recuperação, pessoa única e contexto ativo. |
| Multi-tenant | Sim | Instituição > Unidade > Grupo/Perfil > Criança/Aluno/Atendido > Responsável, com vínculos flexíveis. |
| Superadmin | Sim | Gestão de clientes, status, planos, usuários internos, avisos e logs. |
| Admin | Sim | Unidades, grupos, atividades, pessoas, responsáveis, equipe (perfil), permissões, comunicados, agenda, rotina e chat. |
| App mobile | Sim | iOS/Android para responsáveis, professores, coordenadores, direção e equipe. |
| Feed/comunicados | Sim | Privado, contextual, com mídia e confirmação de leitura. |
| Stories/momentos | Sim | Diferencial visual, privado por perfil/unidade/grupo. |
| Chat completo | Sim | 1:1 contextual, canais, equipe, leitura, anexos básicos e auditoria. |
| Agenda | Sim | Eventos, lembretes, RSVP/autorização simples. |
| Diário de rotina | Sim | Completo para rotina infantil, com templates e registro rápido. |
| Notificações | Sim | Push, e-mail/SMS/WhatsApp apenas como expansão ou automação pontual. |
| Dados para dashboards | Sim | Eventos e tabelas desde o MVP; dashboard visual completo fica fora. |

# 13. Fora de escopo do MVP

| Fora do MVP | Motivo | Preparar como? |
| --- | --- | --- |
| Dashboard visual completo | Aumenta escopo; dados ainda serão validados. | Registrar eventos, logs e métricas desde o MVP. |
| Site institucional/SEO completo | Não é necessário para piloto real. | Reservar coelo.me e criar página simples futura. |
| Pagamentos | Exige operação financeira, conciliação e suporte. | Modelar planos/status sem cobrança automática. |
| Matrícula digital | Fluxo jurídico/contratual maior. | Preparar pessoa, responsável, assinatura e documentos futuros. |
| ERP/financeiro completo | Fora da tese inicial. | Integrar futuramente com ERPs, sem tentar substituir agora. |
| Gamificação completa | Pode distrair do cuidado e da rotina. | Registrar eventos úteis para badges futuros. |
| White label forte | Aumenta complexidade de loja, build e suporte. | Permitir branding leve e estrutura para expansão. |
| IA em produção crítica | Requer governança, moderação e privacidade. | Deixar prompts/copilotos como v2, nunca acesso direto a dados sensíveis sem controle. |

# 14. Roadmap v1, v2, v3 e futuro

| Horizonte | Objetivo | Entregas |
| --- | --- | --- |
| v1.0 - MVP piloto | Validar rotina, comunicação e confiança em instituição real. | Auth, multi-tenant, Superadmin, Admin, App, feed, stories, chat, agenda, diário, notificações e eventos. |
| v1.1 - Estabilização | Melhorar usabilidade, segurança e dados após piloto. | Importação, performance, logs, painéis operacionais simples, refinamentos de permissões, relatórios CSV e suporte. |
| v2 - Operação e monetização | Transformar em SaaS vendável. | Planos, pagamentos/assinatura, matrícula digital, IA assistiva, autorizações avançadas, integrações e branding leve pago. |
| v3 - Plataforma modular | Expandir segmentos e profundidade. | Dashboards completos, white label avançado, BI, APIs, integrações ERP, módulos por segmento, IA com governança. |
| Futuro | Ecossistema de cuidado infantil. | Marketplace de conteúdos/parceiros, automações, indicadores preditivos, serviços financeiros/contratuais e módulos especializados. |

# 15. Estrutura multi-tenant

A arquitetura deve suportar múltiplas instituições e múltiplos papéis por pessoa. A hierarquia base funciona, mas a nomenclatura deve evitar travar o produto em escola tradicional.

| Termo recomendado | Evitar/usar com cuidado | Motivo |
| --- | --- | --- |
| Instituição | Organização | Mais humano e aderente ao mercado; funciona para escola, curso, escolinha, terapia e entidade infantil. |
| Unidade | Filial apenas | Representa sede, campus, unidade física ou operação local. |
| Turma | Grupo na interface | Turma é o termo visível único; `group*` permanece como vocabulário técnico. |
| Perfil | Canal isolado | Unidades e turmas podem ter perfil social privado automaticamente. |
| Criança / Aluno / Atendido | Participante como termo de interface | Participante é técnico e genérico; usar label por segmento. No banco, pode ser person_context do tipo child/participant. |
| Responsável | Pai/mãe apenas | Inclui pai, mãe, avós, tutores, cuidadores autorizados e responsáveis legais. |
| Pessoa | Usuário para tudo | Pessoa existe mesmo sem login; usuário é pessoa com acesso/auth ativo. |

| Regra de ouro multi-tenant<br>Pessoa é global. Papel é contextual. Visibilidade é derivada do vínculo ativo com instituição, unidade, turma e criança/aluno/atendido. |
| --- |

- Uma pessoa pode estar em várias instituições.

- Uma pessoa pode ter vários papéis na mesma instituição: professor e responsável, por exemplo.

- Uma criança/aluno/atendido pode estar em múltiplos grupos e instituições, desde que os vínculos sejam explícitos e auditáveis.

- Responsáveis veem apenas contextos em que a criança/aluno/atendido vinculado está autorizada ou seguindo.

- Professores e coordenadores veem apenas grupos/unidades vinculados ao papel profissional naquele contexto.

- A tela deve ter seletor de contexto ativo: Instituição > papel atual > unidade/grupo/criança quando aplicável.

# 16. Ambientes/domínios

| Domínio | Papel | Prioridade |
| --- | --- | --- |
| coelo.me | Site institucional, SEO, landing page, planos, sobre nós, história da marca, conversão e conteúdo. | Futuro / não MVP completo |
| superadmin.coelo.me | Painel interno do Coelo para gestão de clientes, planos, usuários internos, avisos e auditoria. | MVP |
| admin.coelo.me | Painel da instituição para gestão de unidades, grupos, pessoas, permissões, comunicados, agenda e rotina. | MVP |
| app.coelo.me | Versão web do app, útil para acesso rápido e operação leve. | MVP se não atrasar; mobile é prioridade |
| Apps iOS/Android | Experiência diária de responsáveis, professores, coordenadores, direção e equipe. | MVP |

# 17. Papéis, perfis e permissões

Permissões devem ser RBAC + escopo de contexto. O papel “professor” sozinho não basta; é professor de qual instituição, unidade e grupo? O papel “responsável” não basta; é responsável por qual criança, com qual tipo de autorização?

| Papel | Escopo | Permissões principais |
| --- | --- | --- |
| Superadmin Owner | Plataforma Coelo | Tudo no Superadmin, gestão de usuários internos, planos, auditoria e configurações globais. |
| Superadmin Operações | Plataforma Coelo | Cadastrar/ativar instituições, suporte operacional e avisos segmentados. |
| Superadmin Conteúdo | Perfis globais Coelo | Publicar dicas e conteúdos globais sem acessar dados privados de crianças. |
| Diretor/Owner Instituição | Instituição inteira | Configurações, unidades, grupos, equipe, responsáveis, comunicados, agenda, relatórios e permissões. |
| Admin Instituição | Instituição/unidade | Gerenciar cadastros, vínculos, grupos, rotina, comunicados e canais conforme delegação. |
| Coordenador | Unidades/grupos | Supervisionar professores, rotinas, agenda, comunicados e atendimento. |
| Professor | Grupos/turmas | Registrar rotina, publicar momentos autorizados, responder canais e ver crianças vinculadas. |
| Equipe | Unidade/grupo/função | Acesso operacional limitado, ex.: secretaria, saúde, apoio, transporte. |
| Responsável | Criança(s) vinculada(s) | Ver rotina, feed, comunicados, agenda e chats relacionados à criança e aos perfis seguidos automaticamente. |
| Participante/Aluno | Contexto específico | Acesso opcional e restrito, somente quando fizer sentido por idade/segmento e autorização. |

| Ação | Superadmin | Diretor/Admin | Coordenador | Professor | Responsável |
| --- | --- | --- | --- | --- | --- |
| Criar instituição | Sim | Não | Não | Não | Não |
| Criar unidade/grupo | Suporte | Sim | Com permissão | Não | Não |
| Vincular responsável | Suporte | Sim | Com permissão | Solicitar/visualizar se permitido | Aceitar convite |
| Publicar comunicado unidade | Segmentado/global | Sim | Sim | Não ou com permissão | Não |
| Publicar rotina | Não | Auditar | Auditar/editar | Sim | Não |
| Ver rotina individual | Somente suporte autorizado | Sim | Sim | Crianças do grupo | Somente vínculo próprio |
| Chat com responsável | Suporte autorizado | Sim | Sim | Sim se responsável de criança vinculada | Sim, com instituição/equipe |
| Exportar dados | Com permissão alta | Com permissão alta | Não ou limitado | Não | Dados próprios mediante processo |

# 18. Fluxos principais

| Fluxo | Passos essenciais | Critério de aceite |
| --- | --- | --- |
| Ativação de instituição | Superadmin cria instituição, define plano/status, owner, unidade inicial e convite do admin. | Admin acessa apenas sua instituição e vê checklist de configuração. |
| Cadastro de unidade/grupo | Admin cria unidade, grupo/turma/perfil, configura seguidores automáticos e permissões. | Perfis da unidade/grupo são criados e usuários vinculados seguem automaticamente conforme regra. |
| Cadastro de pessoa | Admin busca por e-mail/celular/CPF opcional; cria pessoa; escolhe se terá acesso como usuário: sim/não. | Não duplica pessoa existente; cria vínculo contextual; convite só é enviado se usuário = sim. |
| Vínculo de criança e responsável | Admin cadastra criança/aluno/atendido, vincula responsáveis e define permissões. | Responsável vê apenas conteúdos vinculados à criança e aos grupos/unidades seguidos. |
| Publicação no feed | Equipe escolhe perfil, audiência, mídia, confirmação de leitura e agendamento. | Post aparece apenas para audiência autorizada e gera eventos de leitura. |
| Registro de rotina | Professor escolhe grupo, aplica template em lote, ajusta individualmente e publica. | Responsáveis recebem rotina individual; alterações ficam auditadas. |
| Chat/canal | Usuário abre conversa contextual; membros são derivados de vínculo e permissão. | Mensagem só trafega entre membros autorizados e gera leitura/histórico. |
| Recuperação de conta | Usuário recupera por e-mail/celular, com verificação e proteção contra enumeração. | Conta recuperada sem expor dados de crianças ou instituições indevidamente. |

# 19. Módulos do produto

| Módulo | MVP | Objetivo | Notas |
| --- | --- | --- | --- |
| Identidade/Auth | Sim | Login, convites, recuperação e contexto. | Base de toda permissão. |
| Multi-tenant/RBAC | Sim | Isolar instituições e papéis. | RLS obrigatório. |
| Superadmin | Sim | Operação Coelo. | Sem dashboard completo, mas com logs, já criar tabelas necessárias e ir salvando mesmo que ainda naõ tenha o dashboard para que se possa mensurar tudo no futuro. |
| Admin | Sim | Gestão institucional. | Painel web em Flutter. |
| App mobile | Sim | Uso diário. | Responsáveis/equipe. |
| Feed/comunicados | Sim | Canal oficial visual. | Leitura, mídia e reações, comentários para próxima versão, prever no banco de dados. |
| Stories/momentos | Sim | Engajamento visual. | Privado e com expiração. |
| Chat/canais | Sim | Atendimento e comunicação. | Auditoria e anexos básicos, possivel integração futura com outros canais externo via api, como whatsapp. |
| Agenda | Sim | Eventos e lembretes. | RSVP/autorização simples. |
| Diário de rotina | Sim | Acompanhamento infantil. | Registro rápido por grupo. |
| Notificações | Sim | Ativar hábito. | Push com payload mínimo. |
| Dashboards | Dados sim, UI não | Preparar BI. | Visual completo v2. |
| Site/SEO | Não | Aquisição. | Futuro. |
| Pagamentos/matrícula | Não | Monetização/ROI. | V2. |

# 20. Superadmin

O Superadmin é o sistema interno do Coelo. Ele precisa ser seguro, simples e auditável, porque concentra o controle de tenants, usuários internos e ações sensíveis.

| Funcionalidade | MVP | Detalhe |
| --- | --- | --- |
| Cadastro de instituições | Sim | Criar, editar, ativar, inativar, suspender e definir status operacional. |
| Planos/status | Sim | Plano manual, datas, limites e status; cobrança automática fica fora. |
| Usuários internos Coelo | Sim | Perfis de acesso: owner, operações, suporte, conteúdo, auditor. |
| Avisos globais/segmentados | Sim | Para todos, por instituição, unidade, papel ou contexto. Com prazo de exibição. |
| Perfis globais Coelo | Sim | Perfis oficiais para dicas e conteúdos; sem acesso a dados privados dos usuários. |
| Acompanhamento de uso | Básico | Contadores e eventos brutos; dashboard completo no futuro. |
| Auditoria/logs | Sim | Log de ações sensíveis, acessos administrativos e alterações de permissões. |
| Suporte impersonation | Não no MVP | Evitar risco; se necessário futuramente, exigir consentimento, janela temporária e log forte. |

# 21. Admin

O Admin é o painel da instituição. Ele deve permitir que o cliente configure sua operação sem depender do Coelo para cada ajuste.

| Área | Requisitos |
| --- | --- |
| Unidades | Criar/editar/inativar unidades, perfil da unidade, dados de contato, branding leve e regras de seguidores. |
| Grupos/turmas/perfis | Criar grupos com tipo, faixa etária/segmento, responsáveis/equipe vinculados, perfil social e permissões. |
| Pessoas | Cadastrar pessoa, deduplicar, vincular papéis, definir “usuário: sim/não”, enviar convite e recuperar vínculo. |
| Crianças/alunos/atendidos | Cadastro com dados mínimos, vínculos com responsáveis, grupos e instituições. |
| Responsáveis | Permissões por criança: ver rotina, receber comunicados, responder agenda, abrir chat, autorizar eventos. |
| Equipe | Professores, coordenadores, direção, secretaria e equipe de apoio com papéis contextuais. |
| Conteúdo | Comunicados, posts, stories/momentos, agenda, templates e rotina. |
| Chat/canais | Configurar canais, horários, membros, política de resposta e anexos. |
| Dados | Preparar eventos, exportação futura e relatórios simples. |

# 22. App

O App é a experiência diária do Coelo. Deve ser mobile-first, com visual familiar, navegação simples e foco em abrir com constância.

| Usuário | Home ideal | Principais ações |
| --- | --- | --- |
| Responsável | Feed dos perfis seguidos + card da criança + agenda do dia. | Ver rotina, confirmar leitura, responder agenda, conversar, ver momentos. |
| Professor | Grupos do dia + atalhos de rotina + pendências. | Registrar rotina, publicar momento, responder chat, ver agenda. |
| Coordenador | Pendências por grupo/unidade + comunicados recentes. | Revisar rotinas, comunicar, atender responsáveis, supervisionar equipe. |
| Direção | Visão resumida da instituição + alertas. | Comunicar, acompanhar uso, ver pendências e aprovar ações. |
| Aluno/participante | Somente se fizer sentido e com autorização. | Ver comunicados/agenda próprios, sem exposição social aberta. |

- Navegação recomendada MVP: Feed, Rotina, Chat, Agenda, Perfil/Contexto.

- Contexto ativo sempre visível quando houver múltiplas instituições ou papéis.

- Push não deve revelar dados sensíveis no payload; ex.: “Há uma nova atualização no Coelo”.

- Responsável que também é professor, coordenador ou outro cargo precisa alternar contexto de forma clara, sem misturar permissões.

- Para cada Grupo uma criança pode ter vários responsáveis, mas naturalmente pode ter dois, e caso tenha mais de 2, será cobrado um valor adicional por responsável.

# 23. Site institucional

O site não entra como prioridade do MVP, mas deve ser previsto para aquisição futura. Para SEO e performance, o site pode ser Next.js/React/HTML/CSS, separado dos apps Flutter, porque Flutter Web não é a melhor aposta para conteúdo indexável.

| Página futura | Objetivo |
| --- | --- |
| Home/landing | Explicar proposta, capturar leads e direcionar demonstração. |
| Sobre nós | Contar a história da marca, priorizando narrativa comercial da logo. |
| Planos | Apresentar faixas e módulos quando monetização estiver definida. |
| Segmentos | Páginas para escola infantil, escola, curso, esporte, terapia e atividades. |
| Blog/conteúdo | SEO, dicas para instituições e famílias, sempre com responsabilidade e sem publicidade infantil indevida. |
| Prova social | Cases, depoimentos e métricas após piloto. |

# 24. Feed social privado/Happens

O feed deve ser inspirado em Instagram/TikTok no visual e no hábito, mas não na lógica aberta de descoberta. Não existe busca pública de crianças, ranking social ou viralização. Podendo marcar a criança com seu @ e consequentemente o responsável.

Feed podendo ter carrossel (Até 10 fotos, em versão futuras aumentamos) com fotos e vídeos (até 30 segundos), descrição (em qualquer publicação) e escrita (como o X, twitter).

| Requisito | Definição |
| --- | --- |
| Perfis automáticos | Toda unidade e todo grupo/turma pode ter um perfil privado criado automaticamente. |
| Seguidores automáticos | Responsáveis e equipe seguem perfis aos quais estão vinculados; Superadmin/Admin podem ajustar conforme regra. |
| A audiência manda | Post só aparece se o usuário tiver vínculo autorizado e se o perfil/post permitir. |
| Comunicados oficiais | Podem exigir confirmação de leitura e gerar relatório. |
| Posts de rotina/momentos | Podem conter fotos/vídeos curtos, texto, anexos e tags de crianças visíveis apenas a responsáveis autorizados. |
| Comentários/reactions | Recomenda-se limitar no MVP: reações simples ou comentários desativáveis por instituição/perfil. |
| Conteúdo global Coelo | Perfis oficiais do Coelo podem ser auto-seguidos por padrão para dicas úteis; permitir silenciar/desativar conteúdos não obrigatórios. |

| Recomendação sobre “forçar seguir” perfis Coelo<br>Para avisos sistêmicos e segurança, o follow obrigatório faz sentido. Para conteúdo de dicas, recomendo auto-follow com opção de silenciar/ocultar, evitando sensação de publicidade imposta e preservando confiança. |
| --- |

# 25. Stories/Now

| Aspecto | MVP/v1 |
| --- | --- |
| Nome de produto | Now é mais seguro e institucional que “Stories”, mas pode usar linguagem visual familiar. |
| Duração | Expiração padrão de 24h; histórico interno/auditável conforme política de retenção. |
| Audiência | Unidade, grupo, criança específica ou segmentação por papel. |
| Mídia | Fotos e vídeos curtos (30 segundos); limite de tamanho e duração para controlar custo. |
| Privacidade | Sem compartilhamento público; downloads podem ser controlados por política da instituição. |
| Consentimento | Respeitar preferências de imagem por criança e regras da instituição. |
| Analytics | Visualizações, alcance, taxa de abertura e denúncias/ocultações. |

Obs: Na V1 pensar no Moments como se fosse um reels de vídeo de até 2 minutos.

# 26. Chat/Canais

Chat no MVP deve ser completo o suficiente para substituir parte do caos do WhatsApp, mas com limites institucionais. Não recomendo chat aberto entre responsáveis no MVP.

| Tipo de chat | MVP? | Regra |
| --- | --- | --- |
| Responsável ↔ instituição | Sim | Atendimento contextual por criança/unidade/grupo; pode ser atendido por coordenação/equipe. |
| Professor ↔ responsável | Sim, controlado | Somente quando permitido pela instituição e vinculado à criança/grupo. |
| Coordenação ↔ responsável | Sim | Canal oficial para dúvidas, ocorrências e alinhamentos. |
| Canal por turma/grupo | Sim | Comunicados e conversa controlada; respostas podem ser restritas. |
| Canal por unidade | Sim | Comunicados gerais e atendimento. |
| Chat interno equipe | Sim | Equipe da instituição por unidade/grupo, com auditoria. |
| Responsável ↔ responsável | Não | Risco de moderação, privacidade e ruído social. |

- MVP deve ter confirmação/leitura de mensagens.

- Anexos básicos: imagem e PDF; vídeo em chat pode ficar limitado ou v1.1 por custo e moderação.

- Histórico e auditoria são obrigatórios para canal institucional.

- Histórico e auditoria de conversas são obrigatórios para todas as mensagens enviadas, o admin, pode ver as conversas entre responsável e professores, instituição, coordenação. Além de poder modificar acesso a que grupos cada perfil pode ter acesso ao histórico, por exemplo, um coordenador tem acesso ao histórico da conversa de tais grupos.

- Excluir mensagem deve ser “soft delete” com registro de auditoria para administradores autorizados.

- Horário de atendimento e respostas automáticas podem entrar em v1.1/v2.

- Correção e escrita através de IA podem entrar em v1.1/v2.

# 27. Agenda

| Funcionalidade | MVP/v1 |
| --- | --- |
| Eventos por unidade/grupo/criança | Sim, com audiência e permissão. |
| Lembretes | Push e e-mail opcional. |
| Confirmação de presença | Sim, resposta Sim/Não/Talvez quando aplicável. |
| Autorização simples | Sim, para eventos que exigem ciência/autorização do responsável. |
| Recorrência | Simples no MVP ou v1.1; evitar complexidade de calendário completo inicialmente. |
| Anexos | PDF/imagem opcional. |
| Integração calendário externo | Futuro. |

# 28. Diário de rotina

O diário de rotina é um dos diferenciais centrais do Coelo. Para professor, precisa ser rápido. Para responsável, precisa ser claro, visual e confiável. Para instituição, precisa ser padronizado e auditável.

| Categoria | Campos/exemplos MVP |
| --- | --- |
| Alimentação | Refeição, quantidade aproximada, aceitação, observações, cardápio futuro. |
| Sono | Dormiu? horário início/fim, qualidade, observações. |
| Higiene | Fralda/banheiro, trocas, evacuação se aplicável, observações. |
| Saúde | Sintomas observados, medicação somente com regra formal, temperatura se aplicável, ocorrência. |
| Humor | Calmo, animado, sensível, irritado, sonolento; linguagem não estigmatizante. |
| Atividades | Atividades pedagógicas/recreativas, participação, fotos/mídia. |
| Ocorrências | Quedas leves, incidentes, bilhetes importantes, encaminhamento para coordenação. |
| Mídia | Fotos e vídeos curtos, respeitando autorização de imagem e audiência, está no feed (mural) . |
| Templates | Por instituição/unidade/grupo/faixa etária; preenchimento individual e em lote. |

| Critério de UX | Exigência |
| --- | --- |
| Tempo de preenchimento | Professor deve registrar rotina básica de um grupo em poucos minutos usando lote + ajustes individuais. |
| Rascunho | Não perder dados se app fechar ou internet cair; salvar localmente rascunhos. |
| Publicação | Permitir revisar antes de enviar para responsáveis. |
| Correção | Alterações pós-envio devem ficar registradas com autor, data e motivo. |
| Privacidade | Responsável vê somente rotina da criança vinculada e conteúdos coletivos permitidos. |

# 29. Portal do responsável

O Portal do responsável é a visão consolidada da família. Deve funcionar no app mobile e, se possível, em app.coelo.me.

| Área | Conteúdo |
| --- | --- |
| Minhas crianças | Cards por criança/aluno/atendido, instituição, unidade, grupo e status de vínculos. |
| Rotina | Histórico diário, filtros, mídia, ocorrências e observações. |
| Feed | Posts e comunicados dos perfis seguidos automaticamente. |
| Agenda | Eventos, autorizações, lembretes e presença/RSVP. |
| Chat | Conversas com instituição/equipe por contexto. |
| Documentos futuros | Autorizações, contratos, termos e comprovantes. |
| Privacidade | Preferências, termos aceitos, consentimentos e solicitações de dados. |

# 30. Notificações

| Tipo | Canal MVP | Regra |
| --- | --- | --- |
| Comunicado importante | Push | Payload mínimo; abrir tela autenticada para conteúdo. |
| Nova rotina publicada | Push | Agrupar notificações para evitar excesso. |
| Mensagem de chat | Push | Não expor dados sensíveis no texto do push. |
| Evento/agenda | Push/e-mail opcional | Lembrete configurável. |
| Aviso global Coelo | In-app/push quando crítico | Segmentado e com prazo de exibição. |
| Convite de acesso | E-mail/celular | Link seguro, expiração e reenvio controlado. |

- Criar central de notificações in-app desde o MVP.

- Adicionar preferências por tipo: rotina, chat, agenda, comunicados, dicas Coelo.

- Mensagens críticas de segurança/termos não devem depender de marketing opt-in.

- Push deve ter rate limit para evitar fadiga.

# 31. Identidade, login, @username e recuperação de conta

Identidade é uma das partes mais importantes do Coelo. O erro de modelagem aqui vira bug de permissão, duplicidade, suporte e risco de LGPD.

| Decisão | Recomendação |
| --- | --- |
| Pessoa x Usuário | Pessoa é o cadastro global. Usuário é uma pessoa com Auth ativo. Criança pode ser pessoa sem login. |
| Cadastro por Admin | Ao cadastrar responsável/equipe, perguntar: “Criar acesso como usuário agora? Sim/Não”. Se não, fica contato/vínculo sem login até convite futuro. |
| Deduplicação | Buscar por e-mail, celular, CPF opcional e outros identificadores; nunca exibir dados completos de outra instituição durante match. |
| Login | E-mail + senha/OTP e celular/OTP como caminhos principais; social login pode ficar para futuro. Caso seja fácil |
| Recuperação | E-mail, celular e suporte institucional com provas mínimas; sem expor se a conta existe. |
| @username adultos | Útil para perfis, responsáveis e equipe; facilita menções internas e busca controlada. |
| @username crianças | Não recomendar username público/global para crianças. Usar identificador interno/contextual e não pesquisável. |
| Perfis de unidade/grupo | Username único tipo @escola.unidade ou @turma-jardim-a, visível apenas dentro da rede privada. |

| Privacidade de username infantil<br>Para crianças/adolescentes, @username global pesquisável aumenta risco de exposição, rastreabilidade e uso indevido. A recomendação é manter identificadores contextuais, privados e não indexáveis. Mas o @username pode servir para outras instituição convidaram a criança. O responsável tem que ter fácil acesso ao @username e poder editar. |
| --- |

# 32. Modelo conceitual de dados

Modelo conceitual inicial. A modelagem física deve virar sub-PRD técnico + migration plan Supabase/Postgres com RLS e testes de tenant isolation.

| Entidade | Descrição | Chaves/observações |
| --- | --- | --- |
| people | Pessoa global: adulto, criança, equipe ou contato. | id, nome, data nasc. opcional, contatos, dedupe_hash. |
| auth.users | Usuário autenticado Supabase. | Vínculo 1:1 opcional com people. |
| user_profiles | Perfil de login/configurações. | username adulto, avatar, preferências, status. |
| institutions | Cliente/tenant principal. | institution_id obrigatório na maioria das tabelas. |
| units | Unidades da instituição. | unit_id, institution_id. |
| groups | Grupo/turma/perfil operacional. | group_id, unit_id, type: turma/equipe/atendimento/etc. |
| memberships | Vínculo pessoa-contexto-papel. | person_id, institution/unit/group, role, status, dates. |
| child_records | Dados contextuais da criança/aluno/atendido. | person_id + institution_id; dados mínimos e segmentados. |
| guardian_links | Relação responsável-criança. | guardian_person_id, child_person_id, permissions, legal/authorized. |
| social_profiles | Perfil feed de instituição/unidade/grupo/global. | profile_id, owner_context, username, visibility. |
| follows | Seguidores automáticos/manuais. | profile_id, person_id/user_id, reason, mute settings. |
| posts | Publicações feed/comunicados. | profile_id, author, type, body, status, requires_read. |
| post_audiences | Segmentação de posts. | contexto, role, group_id, child_id opcional. |
| media_assets | Fotos, vídeos, anexos. | bucket/path, owner, classification, retention. |
| stories | Momentos com expiração. | profile_id, media, expires_at, audience. |
| read_receipts/views | Leitura/visualização. | user_id/person_id, object_id, timestamp. |
| conversations | Chats/canais. | contexto, type, status, policy. |
| conversation_members | Membros autorizados. | conversation_id, person/user, role, permissions. |
| messages | Mensagens. | conversation_id, author, body, media, status. |
| agenda_events | Eventos e compromissos. | contexto, data, audience, rsvp/auth required. |
| routine_templates | Templates de diário. | institution/unit/group, schema de itens. |
| routine_entries | Registro de rotina. | child_id, group_id, date, author, status, audit. |
| notifications | Fila/estado de notificações. | recipient, type, object_id, status. |
| audit.audit_logs | Ações sensíveis. | actor, action, object, before/after summary, ip/device. |
| analytics.analytics_events | Eventos de produto. | event_name, actor/context, timestamp, properties minimizadas. |

- Todas as tabelas com dados de tenant devem ter institution_id direto ou derivável por FK segura.

- RLS não deve depender de “lembrar de filtrar no app”; a regra precisa estar no banco.

- Mídia deve ter classificação: pública interna, privada por grupo, privada por criança, sensível.

- Dados de saúde e rotina podem ser sensíveis ou de maior risco: minimizar, limitar acesso e auditar.

# 33. Eventos, logs, analytics e preparação para dashboards

Dashboard visual completo fica fora do MVP, mas a base de eventos não pode ficar para depois. Sem eventos desde o início, o Coelo vira um app bonito e cego.

| Evento | Quando dispara | Uso futuro |
| --- | --- | --- |
| user_signed_in | Login concluído. | Adoção, frequência, segurança. |
| context_switched | Usuário troca instituição/papel. | Complexidade multi-papel e UX. |
| post_created | Post/comunicado publicado. | Volume por unidade/grupo. |
| post_read_confirmed | Leitura confirmada. | Taxa de leitura e SLA. |
| story_viewed | Momento visualizado. | Engajamento visual. |
| message_sent/read | Chat enviado/lido. | Tempo de resposta e saúde de atendimento. |
| agenda_event_created/responded | Evento criado/respondido. | Aderência a agenda/autorização. |
| routine_entry_started/published/edited | Rotina rascunhada, publicada ou alterada. | Tempo de preenchimento, qualidade e auditoria. |
| media_uploaded | Upload de mídia. | Custo, performance e uso de storage. |
| permission_changed | Alteração de papel/permissão. | Auditoria e segurança. |
| guardian_link_created/updated | Vínculo responsável-criança. | Governança familiar. |
| notification_sent/opened | Notificação enviada/aberta. | Efetividade de push. |

| Dashboard futuro | Métricas preparadas no MVP |
| --- | --- |
| Superadmin | Instituições ativas, usuários ativos, posts, mensagens, rotinas, erros, storage, saúde operacional. |
| Admin/Direção | Taxa de leitura, responsáveis ativos, rotinas publicadas, pendências por turma, tempo de resposta, uso por equipe. |
| Coordenação | Rotinas atrasadas, grupos sem atualização, mensagens pendentes, ocorrências e engajamento. |
| Produto Coelo | Ativação, retenção semanal, feature adoption, funil de onboarding e motivos de churn. |

# 34. Segurança, LGPD e privacidade infantil

Como o Coelo trata dados de crianças/adolescentes, segurança e LGPD devem ser decisões de arquitetura. A LGPD exige melhor interesse da criança/adolescente no tratamento desses dados, e a ANPD interpreta que bases legais dos arts. 7º e 11 podem ser usadas desde que o melhor interesse prevaleça no caso concreto.

| Princípio/controle | Aplicação no Coelo |
| --- | --- |
| Melhor interesse | Todo tratamento de dados de crianças deve ter finalidade clara, proporcionalidade e benefício/necessidade demonstrável. |
| Minimização | Coletar o mínimo necessário para rotina, segurança e comunicação. Evitar dados sensíveis sem finalidade concreta. |
| Finalidade | Separar finalidades: cadastro, rotina, comunicação, segurança, suporte, analytics e marketing institucional. |
| Consentimento/responsável | Coletar consentimento específico/destacado quando aplicável; manter histórico de termos aceitos e revogações. |
| Controle de acesso | RBAC contextual + RLS + auditoria. Nunca confiar apenas em filtros no front-end. |
| Isolamento multi-tenant | institution_id + RLS em todas as tabelas de tenant; testes automatizados de vazamento entre instituições. |
| Mídia infantil | Buckets privados, URLs assinadas, expiração, controle de download quando aplicável, moderação e retenção. |
| Logs/auditoria | Registrar acesso administrativo, alteração de permissões, edição de rotina, vínculos e downloads sensíveis. |
| Retenção/exclusão | Políticas por tipo de dado; rotina e mídia com prazos; exclusão/anonymização conforme contrato e lei. |
| Incidentes | Plano de resposta, classificação, contenção, evidências, comunicação e registro. |
| Termos e políticas | Termos de uso, política de privacidade, DPA/contrato operador-controlador e política de imagem. |
| OWASP | Usar ASVS para web/API e MASVS para mobile como checklist de segurança. |

| Classificação de risco<br>Recomendação: tratar Coelo como produto de risco elevado/moderado-alto por envolver crianças, rotina, mídia e comunicação privada. Exigir RLS, auditoria, revisão jurídica e threat modeling antes de piloto. |
| --- |

- Service role do Supabase nunca deve ir para app mobile/web.

- Supabase publishable key pode ficar no cliente, mas todos os dados devem estar protegidos por RLS.

- Acesso de suporte do Coelo a dados de crianças deve ser minimizado, justificado e auditado.

- Analytics não deve usar dados desnecessários de crianças; preferir identificadores pseudonimizados e métricas agregadas.

- Conteúdo global Coelo não deve fazer publicidade infantil ou perfilamento comportamental de crianças.

# 35. Requisitos funcionais

| ID | Área | Requisito |
| --- | --- | --- |
| RF-001 | Autenticação | Permitir login/recuperação por e-mail e/ou celular, com convites e vínculo de pessoa global. |
| RF-002 | Contexto ativo | Permitir alternar instituição, papel, unidade/grupo quando a pessoa tiver múltiplos vínculos. |
| RF-003 | Superadmin | Cadastrar, editar, ativar/inativar instituições e gerenciar usuários internos do Coelo. |
| RF-004 | Admin | Cadastrar unidades, grupos, atividades, pessoas, crianças/alunos/atendidos, responsáveis e equipe. |
| RF-005 | Deduplicação | Buscar pessoa existente antes de criar novo cadastro, com proteção de privacidade entre tenants. |
| RF-006 | Vínculos | Permitir múltiplos vínculos por pessoa, por instituição, unidade, grupo e criança. |
| RF-007 | Perfis sociais | Criar perfis de unidade/grupo e seguidores automáticos por vínculo. |
| RF-008 | Feed | Publicar posts/comunicados com audiência, mídia e confirmação de leitura. |
| RF-009 | Stories/Momentos | Publicar momentos privados com expiração e audiência contextual. |
| RF-010 | Chat | Criar conversas/canais com membros autorizados, leitura, anexos básicos e auditoria. |
| RF-011 | Agenda | Criar eventos com audiência, lembrete, RSVP e autorização simples. |
| RF-012 | Diário de rotina | Registrar rotina individual e em lote por grupo, com templates, mídia e histórico. |
| RF-013 | Portal responsável | Exibir rotinas, feed, agenda, chat e dados da criança vinculada. |
| RF-014 | Notificações | Enviar push/in-app conforme evento, preferência e regras de privacidade. |
| RF-015 | Logs | Registrar ações sensíveis e eventos de uso para auditoria/dashboards futuros. |

# 36. Requisitos não funcionais

| Categoria | Requisito |
| --- | --- |
| Segurança | RLS obrigatória em tabelas tenant-data; testes automatizados de isolamento por tenant e papel. |
| Privacidade | Minimização, retenção, consentimentos, políticas de mídia e proteção de dados infantis. |
| Performance | Feed e rotina devem carregar rápido em conexão móvel comum; mídia com compressão e thumbnails. |
| Disponibilidade | MVP sem SLA enterprise, mas com backup, monitoramento e plano de incidente. |
| Escalabilidade | Modelagem multi-tenant compartilhada com institution_id; preparar migração para isolamento maior no futuro. |
| Auditabilidade | Ações sensíveis devem ser rastreáveis por ator, contexto, data e objeto. |
| Usabilidade | Professor deve conseguir registrar rotina sem treinamento longo; responsável deve entender app em primeiro uso. |
| Acessibilidade | Contraste, tamanho de toque, labels, fontes legíveis e navegação compatível com padrões mobile. |
| Manutenibilidade | Monorepo Flutter organizado, packages compartilhados, migrations versionadas e documentação para agents. |
| Observabilidade | Logs de erro, analytics, métricas de backend, storage e falhas de push/upload. |

# 37. Critérios de aceite gerais

- Usuário responsável com filho em duas instituições consegue alternar contexto e ver apenas conteúdos correspondentes.

- Professor que também é responsável na mesma instituição vê área profissional e familiar separadas por contexto/papel.

- Responsável sem vínculo com criança/grupo não consegue acessar post, rotina, mídia, chat ou agenda por URL direta.

- Superadmin sem permissão de auditoria não vê dados privados de crianças.

- Admin cadastra pessoa existente sem criar duplicidade e sem expor dados de outra instituição indevidamente.

- Post com confirmação de leitura gera recibos por usuário e relatório básico/exportável no futuro.

- Rotina publicada aparece somente para responsáveis autorizados daquela criança.

- Mensagem de chat só é visível para membros autorizados da conversa.

- Mídia privada não é pública por URL permanente.

- Todas as ações sensíveis geram audit log com ator, contexto, ação e timestamp.

- RLS possui testes automatizados com pelo menos dois tenants, múltiplos papéis e tentativa de acesso cruzado.

- O app continua preservando rascunho de rotina se a conexão cair durante preenchimento.

# 38. Métricas de sucesso

| Área | Métrica | Por que importa |
| --- | --- | --- |
| Negócio | Instituições piloto ativas e pagantes futuras | Valida disposição real de uso/pagamento. |
| Adoção | Responsáveis ativos semanalmente | Mostra se o app virou hábito. |
| Engajamento | Taxa de leitura de comunicados | Prova valor para direção e coordenação. |
| Operação | Tempo médio para registrar rotina | Mostra se professores conseguem alimentar sem dor. |
| Comunicação | Tempo de resposta no chat | Mede eficiência e qualidade de atendimento. |
| Conteúdo | Visualizações de momentos/feed | Mostra valor visual e hábito. |
| Retenção | Semanas consecutivas de uso por família | Mede recorrência real. |
| Segurança | Incidentes/vazamentos de permissão | Deve ser zero; métrica crítica. |
| Qualidade | Erros de upload/sync/notificação | Afeta confiança no app. |
| Satisfação | CSAT/NPS por perfil | Mede percepção de valor de famílias, equipe e direção. |

# 39. Riscos e mitigação

| Risco | Prob. | Impacto | Mitigação |
| --- | --- | --- | --- |
| MVP amplo demais atrasar entrega | Alta | Alto | Fatiar v1 em marcos internos: infra/auth, Superadmin/Admin, app comunicação, rotina, chat. |
| Vazamento entre tenants | Média | Crítico | RLS, testes automatizados, revisão de policies, logs e threat modeling. |
| Duplicidade de pessoas | Alta | Alto | Deduplicação por e-mail/celular/CPF opcional e fluxo de merge controlado. |
| Professor não alimentar rotina | Média | Alto | UX em lote, templates, rascunho local e pesquisa com professores no piloto. |
| Famílias ignorarem app | Média | Alto | Feed visual, notificações úteis, conteúdo institucional relevante e onboarding simples. |
| Custo de mídia subir | Média | Médio/alto | Compressão, limites, thumbnails, retenção e avaliação de R2/CDN. |
| Chat virar WhatsApp caótico | Média | Alto | Canais contextuais, horários, regras, sem grupos abertos de responsáveis no MVP. |
| LGPD/consentimento mal definido | Média | Crítico | Revisão jurídica, mapeamento de finalidades, termos, DPA e política de imagem. |
| Offline-first complexo demais | Média | Médio/alto | MVP offline-tolerant; full sync só se métrica do piloto justificar. |
| White label distrair produto | Média | Médio | Branding leve no MVP; app dedicado só para v3/enterprise. |

# 40. Dependências técnicas

| Dependência | Decisão/Recomendação |
| --- | --- |
| Supabase | Postgres, Auth, RLS, Storage, Realtime e Edge Functions como base inicial. |
| Flutter/Dart | Base para Superadmin, Admin e App; compartilhar design system e modelos. |
| Cloudflare | DNS, TLS, WAF/CDN, Turnstile e possível R2 para storage/CDN/archive em fase futura. |
| Push | FCM/APNs com abstração; OneSignal pode ser avaliado se acelerar sem ferir privacidade. |
| n8n | Automações periféricas: convites, notificações administrativas, integrações e rotinas não críticas. |
| Python | ETL, importação, BI, scripts de qualidade de dados e tarefas operacionais. |
| CI/CD | GitHub Actions, migrations Supabase, testes de RLS, build Flutter e revisão de PR. |
| Observabilidade | Sentry/alternativa, logs Supabase, métricas de Edge Functions, storage e notificações. |

# 41. Arquitetura recomendada

A arquitetura inicial deve privilegiar velocidade, segurança e aprendizado, sem fechar portas para escala. O Coelo é multi-tenant e lida com crianças; logo, simplicidade não pode significar improviso em permissões.

| Camada | Recomendação |
| --- | --- |
| Frontend | Flutter/Dart monorepo: app mobile, admin web, superadmin web e design system compartilhado. |
| Backend principal | Supabase: Postgres, Auth, RLS, Storage, Realtime e Edge Functions. |
| Banco | Postgres com schema versionado, RLS por tenant/papel/contexto, funções SQL para regras complexas. |
| Storage | Supabase Storage privado no MVP; Cloudflare R2 avaliado para mídia pesada, CDN, archive e custo de egress. |
| Realtime | Supabase Realtime para chat, feed e notificações internas com canais autorizados. |
| Edge Functions | Operações sensíveis: convites, notificações, webhooks, ações service_role e validações server-side. |
| Borda | Cloudflare para DNS, TLS, WAF, rate limiting, Turnstile e proteção de formulários. |
| Automação | n8n apenas para fluxos não críticos ou orquestrações administrativas. |
| Dados/BI | `analytics.analytics_events` + `audit.audit_logs` no MVP; pipeline Python/warehouse futuro. |

| Ordem de construção recomendada<br>A ordem Superadmin → Admin → App → Site faz sentido, mas antes dela crie a Fundação: modelagem, Auth, RLS, design system e seed de dados. Sem isso, os painéis ficam bonitos e perigosos. |
| --- |

1. Fundação técnica: Supabase, schema, RLS, Auth, design system e ambiente dev/stage/prod.

1. Superadmin mínimo: criar instituição, owner, planos/status, avisos e logs.

1. Admin: unidade, grupo, pessoas, vínculos, permissões e conteúdo.

1. App mobile: feed, rotina, chat, agenda, portal do responsável e notificações.

1. Site institucional: depois do piloto e com narrativa validada.

# 42. Offline-first, SQLite e sincronização: recomendação

| Recomendação clara<br>MVP: NÃO implementar offline-first completo. Implementar offline-tolerant com cache, rascunhos locais e fila de envio para diário de rotina/mídia. Full offline-first com SQLite sync bidirecional deve ser v1.1/v2 somente se o piloto provar necessidade. |
| --- |

| Área | MVP recomendado | Futuro se necessário |
| --- | --- | --- |
| Feed/comunicados | Cache local read-only dos últimos itens. | Sync seletivo por perfil/grupo. |
| Diário de rotina | Rascunho local + fila de envio + resolução simples de conflito. | SQLite/Drift ou PowerSync/Brick para sync robusto. |
| Chat | Cache das últimas conversas; envio exige conexão no MVP ou fila curta com status. | Offline send queue com reconciliação. |
| Mídia | Upload com retry, compressão e status pendente. | Upload em background com chunk/resume e CDN. |
| Agenda | Cache de eventos próximos. | Sync bidirecional/local-first se uso offline for alto. |
| Admin/Superadmin | Online-first. | Não priorizar offline. |

Quando evoluir para offline-first real: se professores registrarem rotina em locais com internet ruim, se houver falhas frequentes de envio, se o tempo de preenchimento for prejudicado por rede, ou se instituições alvo operarem em áreas com conectividade instável. PowerSync e Brick são opções relevantes porque integram Supabase/Postgres com banco local/SQLite, mas adicionam complexidade de sincronização, conflitos e custo operacional.

# 43. White label: MVP, v1 ou futuro

| Recomendação clara<br>MVP deve ter branding leve, não white label forte. White label forte com app dedicado deve ficar para v3/Enterprise, quando houver receita para bancar setup, store ops, homologação, suporte e versionamento. |
| --- |

| Nível | Descrição | Quando |
| --- | --- | --- |
| Sem white label | App Coelo com perfis das instituições. | MVP base. |
| Branding leve | Logo, capa, cor/acento, perfil verificado, nome da instituição e textos de onboarding. | MVP/v1 se não atrasar. |
| Branding comercial | Domínio/subdomínio, página pública da instituição, templates e relatórios com marca. | v2. |
| White label forte | App dedicado na loja, nome e ícone próprios, build/release por cliente. | v3/Enterprise, com setup e contrato robusto. |

# 44. Estratégia para IA/coding agents e Spec-Driven Development

O Coelo é um bom candidato para Spec-Driven Development porque envolve muitas regras de permissão, fluxos multi-tenant e requisitos de privacidade. Coding agents devem implementar specs pequenas, testáveis e versionadas, não “sair codando no freestyle”.

| Artefato | Saída esperada |
| --- | --- |
| PRD Master | Visão, escopo, regras e decisões oficiais. |
| Sub-PRD | Módulo específico com fluxos, requisitos, critérios e eventos. |
| Functional Spec | User stories, casos de borda, estados, erros e acceptance criteria. |
| Technical Spec | Schema, RLS, Edge Functions, storage, realtime, APIs, estado Flutter. |
| Task Plan | Tarefas pequenas para agent: migrations, telas, components, tests, fixtures. |
| Test Plan | Unit, widget, integration, RLS, tenant isolation, e2e e regressão. |
| Review Gate | Checklist humano: segurança, LGPD, RLS, UX e performance antes de merge. |

- Criar repositório com /docs/prd, /docs/specs, /docs/architecture, /supabase/migrations, /apps e /packages.

- Usar AGENTS.md/CLAUDE.md/CODEX.md com regras do projeto, comandos, padrões de commits e limites de segurança.

- Cada tarefa de agente deve ter contexto, arquivos-alvo, critérios de aceite e testes obrigatórios.

- Toda migration deve vir com teste de RLS e seed de dois tenants.

- Nenhum agente deve alterar policies, auth ou dados sensíveis sem revisão humana.

- Usar GitHub Spec Kit ou estrutura equivalente para transformar specs em planos e tarefas; Codex/Claude Code podem executar tarefas com PR review.

# 45. Sub-PRDs recomendados

| # | Sub-PRD | Prioridade | Motivo |
| --- | --- | --- | --- |
| 01 | Identidade, Auth, Pessoa Única e Contexto Ativo | Alta | Base de todo produto. |
| 02 | Multi-tenant, RBAC e RLS Supabase | Crítica | Segurança e isolamento. |
| 03 | Modelo de Dados Master | Crítica | Schema, FKs, eventos, logs e retenção. |
| 04 | Superadmin | Alta | Operação Coelo. |
| 05 | Admin Instituição | Alta | Onboarding e gestão do cliente. |
| 17 | Atividades Contextuais por Turma | Alta | Reutilização, criação institucional ou delegada à unidade, permissões e operação por turma dentro da mesma instituição. |
| 06 | Feed, Comunicados e Confirmação de Leitura | Alta | Valor inicial. |
| 07 | Stories/Momentos e Mídia Infantil | Alta | Diferencial visual e privacidade. |
| 08 | Chat/Canais | Alta | Comunicação bidirecional. |
| 09 | Agenda e Autorizações Simples | Alta | Rotina institucional. |
| 10 | Diário de Rotina | Crítica | Diferencial para infantil. |
| 11 | Notificações | Alta | Hábito e reengajamento. |
| 12 | LGPD, Segurança e Política de Mídia | Crítica | Proteção infantil. |
| 13 | Offline-tolerant/Offline-first Spike | Média/alta | Decisão técnica por dados. |
| 14 | Analytics, Eventos e Dashboards Futuros | Alta | BI e saúde operacional. |
| 15 | Design System Coelo Flutter | Alta | Velocidade e consistência. |
| 16 | Site Institucional e Marca | Média | Futuro comercial. |

# 46. Perguntas em aberto

- Qual será o primeiro segmento piloto exato: escola infantil, escola até 12 anos ou outro?

- Quais dados de criança são obrigatórios no cadastro inicial e quais serão opcionais?

- CPF será usado para deduplicação ou deve ficar fora do MVP?

- Responsáveis terão graus de permissão diferentes: legal, financeiro, retirada, visualização, emergência?

- Professor pode falar diretamente com responsável ou toda conversa passa pela coordenação?

- Comentários em posts entram no MVP ou ficam desativados por padrão?

- Instituição poderá impedir download de fotos/vídeos? Como comunicar limitação técnica de screenshot?

- Qual política de retenção de mídia e rotina será adotada no piloto?

- Qual nível de branding leve entra sem atrasar o MVP?

- Qual ferramenta de push será usada no MVP: FCM/APNs direto ou serviço de terceiros?

- Quais métricas serão suficientes para considerar o piloto validado?

- Quem será o encarregado/DPO e responsável por revisão jurídica de LGPD?

# 47. Decisões oficiais

| Decisão | Valor oficial v1 |
| --- | --- |
| Nome | Coelo |
| Domínio | coelo.me |
| Categoria | Superapp de comunicação e rotina infantil. |
| Posicionamento | Rede privada de cuidado e comunicação infantil para acompanhar a rotina da criança com clareza, segurança e leveza. |
| Produto não é | ERP pesado, rede social aberta, WhatsApp gourmet ou app burocrático. |
| Produto é | Rede privada de cuidado, comunicação e rotina com UX visual e governança institucional. |
| Público | Instituições que atendem crianças/participantes; piloto pode começar em escola infantil. |
| MVP/v1 | MVP forte com Superadmin, Admin, App, feed, stories, chat, agenda, diário, notificações e dados. |
| Stack | Flutter/Dart + Supabase + Cloudflare + n8n/Python quando fizer sentido. |
| Offline | Offline-tolerant no MVP; offline-first completo após validação. |
| White label | Branding leve no MVP/v1; white label forte futuro. |
| Marca | A narrativa comercial da logo é prioritária em vendas; camada familiar entra como profundidade. |

# 48. Próximos passos

1. Validar este PRD Master e registrar ajustes como v1.1.

1. Criar Sub-PRD 01: Identidade, Auth, Pessoa Única e Contexto Ativo.

1. Criar Sub-PRD 02: Multi-tenant, RBAC e RLS Supabase.

1. Criar schema conceitual + primeira migration Supabase com seed de dois tenants.

1. Prototipar RLS com casos: responsável multi-instituição, professor/responsável, coordenador multi-unidade e criança em múltiplos grupos.

1. Criar Design System Coelo em Flutter: cores, tipografia, componentes, cards, feed, rotina e forms.

1. Definir release plan v1 em marcos de 2 a 4 semanas.

1. Criar protótipo navegável das telas principais do Admin e App.
1. Criar Sub-PRD 03: Atividades Contextuais e permissões por turma.

1. Preparar política de privacidade, termos, consentimento de imagem e DPA com revisão jurídica.

1. Selecionar instituição piloto, mapear dados reais e criar roteiro de onboarding.

# 48.1 Aditivo 2026-07-24 — Modelo Contextual Integrado

O produto adota pessoa global e atuação contextual. A mesma pessoa pode ser responsável e profissional, com experiências separadas e permissões calculadas pelo vínculo ativo. Instituição, unidade, grupo, atividade e criança são contextos de autorização; atividade não cria novo nível rígido.

O MVP não oferece login à criança, mas preserva uma pessoa global que poderá receber acesso futuro. Responsáveis com login são convidados apenas por instituição ou unidade. Pessoas autorizadas para emergência, retirada ou transporte formam cadastro operacional sem acesso ao app.

Atividades pertencem à instituição, podem nascer locais em uma unidade e ser promovidas ao catálogo institucional sem duplicação. Seus módulos — conversa, assiduidade, agenda, rotina e mídia — continuam domínios próprios e são habilitados por políticas institucionais e configuração da unidade.

Assiduidade passa a ser domínio próprio. Avisos familiares podem antecipar ausência, presença esperada, atraso ou saída; profissionais autorizados transformam a pendência em registro oficial. O produto deve oferecer visão por criança, turma, unidade e instituição.

Transferências entre unidades exigem solicitação e aceite do destino. Ao terminar o vínculo institucional, o acesso operacional é removido; conversas históricas podem permanecer somente leitura conforme política de retenção.

# 48.2 Aditivo 2026-08-31 — Agenda institucional no Superadmin

Por decisão explícita do Owner registrada na ADR 0028, a Agenda produtiva do
recorte atual existe somente em `apps/superadmin`. As referências anteriores à
Agenda em Admin e App/Principal ficam preservadas como visão histórica ou
futura e não autorizam implementação produtiva nessas aplicações.

O contrato vigente é `specs/006-comunicacao-agenda.md`. A expansão para outra
aplicação exige nova decisão aprovada.

# 49. Fontes e referências pesquisadas

Fontes usadas para melhorar a qualidade do PRD. Elas não substituem validação jurídica, arquitetura detalhada ou pesquisa comercial primária.

| ID | Fonte interna | Uso no PRD |
| --- | --- | --- |
| I1 | Coelo - Product Vision Oficial v1 | Documento interno anexado ao projeto. |
| I2 | Coelo - História da Logo e Marca Oficial v1 | Documento interno anexado ao projeto. |
| I3 | Mapa competitivo de apps de agenda e comunicação escolar no Brasil | Documento interno anexado ao projeto. |

| ID | Fonte externa | URL |
| --- | --- | --- |
| R1 | Atlassian - How to create a product requirements document (PRD) | https://www.atlassian.com/agile/product-management/requirements |
| R2 | Atlassian - Product requirements template | https://www.atlassian.com/software/confluence/templates/product-requirements |
| R3 | Aha! - Product Requirements Documents: Best Practices for PMs | https://www.aha.io/roadmapping/guide/requirements-management/what-is-a-prd-%28product-requirements-document%29 |
| R4 | ProductPlan - Product Requirements Document glossary | https://www.productplan.com/glossary/product-requirements-document |
| R5 | Microsoft Learn - Multitenant SaaS patterns | https://learn.microsoft.com/en-us/azure/azure-sql/database/saas-tenancy-app-design-patterns |
| R6 | Microsoft Learn - Multitenancy and Azure SQL Database | https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/service/sql-database |
| R7 | AWS Prescriptive Guidance - Row-level security recommendations | https://docs.aws.amazon.com/prescriptive-guidance/latest/saas-multitenant-managed-postgresql/rls.html |
| R8 | Planalto - Lei Geral de Proteção de Dados Pessoais, Lei 13.709/2018 | https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/L13709compilado.htm |
| R9 | ANPD - Enunciado sobre dados de crianças e adolescentes | https://www.gov.br/anpd/pt-br/assuntos/noticias/anpd-divulga-enunciado-sobre-o-tratamento-de-dados-pessoais-de-criancas-e-adolescentes |
| R10 | Participa + Brasil/ANPD - Tratamento de dados pessoais de crianças e adolescentes | https://www.gov.br/participamaisbrasil/tscriancaeadolescente |
| R11 | Supabase Docs - Row Level Security | https://supabase.com/docs/guides/database/postgres/row-level-security |
| R12 | Supabase Docs - API keys/security considerations | https://supabase.com/docs/guides/getting-started/api-keys |
| R13 | Supabase - Product overview | https://supabase.com/ |
| R14 | Flutter - Build apps for any screen | https://flutter.dev/ |
| R15 | Dart - Multi-platform apps | https://dart.dev/multiplatform-apps |
| R16 | Flutter Docs - Offline-first support | https://docs.flutter.dev/app-architecture/design-patterns/offline-first |
| R17 | Supabase Blog - Offline-first Flutter apps with Brick | https://supabase.com/blog/offline-first-flutter-apps |
| R18 | PowerSync Docs - Supabase + PowerSync | https://docs.powersync.com/integrations/supabase/guide |
| R19 | Cloudflare R2 Docs - Overview | https://developers.cloudflare.com/r2/ |
| R20 | Cloudflare R2 Pricing | https://developers.cloudflare.com/r2/pricing/ |
| R21 | Cloudflare Workers | https://www.cloudflare.com/products/workers/ |
| R22 | OWASP ASVS | https://owasp.org/www-project-application-security-verification-standard/ |
| R23 | OWASP MASVS | https://mas.owasp.org/MASVS/ |
| R24 | GitHub Spec Kit repository | https://github.com/github/spec-kit |
| R25 | GitHub Blog - Spec-driven development with AI | https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/ |
| R26 | OpenAI Codex | https://openai.com/codex/ |
| R27 | OpenAI Codex IDE extension docs | https://developers.openai.com/codex/ide |
| R28 | Anthropic Docs - Claude Code overview | https://docs.anthropic.com/en/docs/claude-code/overview |
| R29 | Agenda Edu - SuperApp da Educação | https://agendaedu.com/ |
| R30 | ClassApp - agenda escolar online | https://www.classapp.com.br/ |
| R31 | Diário Escola - supersistema de gestão escolar | https://diarioescola.com.br/ |
| R32 | ClipEscola - Plataforma Digital Escolar | https://www.clipescola.com/ |
| R33 | Sponte - App de agenda escolar | https://www.sponte.com.br/app-de-agenda-escolar |
| R34 | Meu Arco - plataforma integrada | https://www.arcoeducacao.com.br/meu-arco |

# Anexo A - Resumo executivo de 10 linhas

1. Coelo é uma rede privada de cuidado e comunicação infantil para instituições, famílias e equipes.

2. O produto deve ser visual, simples e confiável, inspirado em rede social privada, mas sem abertura pública.

3. A arquitetura precisa ser multi-tenant desde o início: pessoa global, papéis contextuais e permissões por vínculo.

4. O MVP/v1 será forte e inclui Superadmin, Admin, App, feed, stories, chat, agenda, diário de rotina e notificações.

5. O produto não deve nascer como ERP escolar pesado; pagamentos, matrícula e financeiro ficam para fases futuras.

6. Flutter/Dart é recomendado para Superadmin, Admin e App, com Supabase como backend principal.

7. Supabase RLS, logs e auditoria são obrigatórios por envolver dados de crianças e comunicação privada.

8. O MVP deve ser offline-tolerant com cache, rascunhos e fila local; full offline-first fica para depois do piloto.

9. White label forte não deve entrar no MVP; branding leve pode entrar se não atrasar.

10. O desenvolvimento deve seguir Spec-Driven Development com sub-PRDs, specs técnicas, testes de RLS e revisão humana.

# Anexo B - MVP vs Próxima fase vs Depois

| Agora / MVP-v1 | Próxima fase / v2 | Depois / v3+ |
| --- | --- | --- |
| Login unificado; multi-tenant; Superadmin; Admin; app iOS/Android; perfis e permissões; instituições; unidades; grupos; pessoas; responsáveis; equipe; feed; comunicados; leitura; stories/momentos; chat; agenda; diário de rotina; portal do responsável; notificações; eventos/logs. | Dashboard operacional; importação avançada; IA assistiva; pagamentos/assinatura; matrícula digital; autorizações avançadas; integrações; relatórios; branding leve pago; melhorias offline se comprovadas. | ERP financeiro completo; LMS/diário pedagógico profundo; reconhecimento facial/controle de acesso; cantina; white label forte; app dedicado; BI avançado; marketplace; IA preditiva com governança. |

# Anexo C - Tabela de módulos

| Módulo | Prioridade | Owner sugerido | Resultado esperado |
| --- | --- | --- | --- |
| Auth/Identidade | Crítica | Produto + Engenharia | Pessoa única e acesso seguro. |
| Multi-tenant/RLS | Crítica | Engenharia + Segurança | Isolamento por instituição e papel. |
| Superadmin | Alta | Produto Coelo | Ativação e operação de clientes. |
| Admin | Alta | Produto + Cliente | Gestão institucional autônoma. |
| App | Alta | Produto + UX | Uso diário e recorrência. |
| Feed/comunicados | Alta | Produto | Comunicação oficial e leitura. |
| Momentos | Alta | Produto + UX | Engajamento visual privado. |
| Chat | Alta | Produto + Engenharia | Comunicação contextual rastreável. |
| Agenda | Alta | Produto | Eventos e autorizações. |
| Diário de rotina | Crítica | Produto + UX | Diferencial infantil. |
| Analytics/logs | Alta | Dados + Engenharia | Dashboards futuros e auditoria. |

# Anexo D - Tabela de entidades principais

| Entidade | Por que existe | Risco se modelar mal |
| --- | --- | --- |
| Pessoa | Evita duplicidade e permite múltiplos papéis. | Cadastros duplicados, suporte e vazamento. |
| Usuário | Permite login para pessoas habilitadas. | Crianças ou contatos ganham acesso indevido. |
| Instituição | Tenant principal. | Dados misturados. |
| Unidade | Estrutura física/operacional. | Comunicação sem contexto. |
| Grupo/Turma | Operação diária e audiência. | Responsáveis veem conteúdo errado. |
| Vínculo/Membership | Papel contextual. | Permissões erradas. |
| Responsável-Criança | Define quem vê o quê. | Privacidade infantil comprometida. |
| Perfil social | Base do feed privado. | Feed vira rede social sem governança. |
| Post/Momento/Mensagem | Comunicação e rotina. | Sem rastreabilidade. |
| Rotina | Acompanhamento infantil. | Perda de valor principal. |
| Audit log | Prova e segurança. | Sem investigação em incidentes. |

# Anexo E - Matriz de riscos resumida

| Risco | Nível | Dono | Mitigação |
| --- | --- | --- | --- |
| Tenant leakage | Crítico | Engenharia/Security | RLS + testes + review. |
| LGPD/mídia infantil | Crítico | Produto/Jurídico | Termos, consentimento, retenção e auditoria. |
| MVP grande | Alto | Produto | Fatiar em marcos internos. |
| Baixa adoção de professores | Alto | UX/Produto | Rotina em lote e rascunhos. |
| Custo de mídia | Médio/alto | Engenharia | Compressão, limites e R2 futuro. |
| Chat caótico | Alto | Produto | Canais e regras. |
| Duplicidade de pessoa | Alto | Dados/Produto | Deduplicação e merge. |

# Anexo F - Recomendações claras

| Tema | Recomendação final |
| --- | --- |
| SQLite/offline-first | Usar cache + rascunho + fila local no MVP. Não implementar offline-first completo até o piloto provar necessidade. Se necessário, avaliar Drift/SQLite, PowerSync ou Brick. |
| Flutter para Superadmin/Admin/App | Recomendado. Use Flutter/Dart para reaproveitar design system, modelos e aprendizado. Para SEO/site, usar stack web própria no futuro. |
| White label | Branding leve no MVP/v1; white label forte apenas v3/Enterprise com contrato e preço compatíveis. |
| Cloudflare | Usar desde cedo para DNS/TLS/WAF/rate limit/Turnstile. R2 é opção futura para mídia pesada/archive/CDN, não obrigação do MVP. |
| Coding agents | Usar com specs pequenas, testes, migrations versionadas e revisão humana obrigatória em RLS/Auth/LGPD. |

# Anexo G - Lista de sub-PRDs após o Master

- Identidade, Auth, Pessoa Única e Contexto Ativo

- Multi-tenant, RBAC e RLS Supabase

- Modelo de Dados Master

- Superadmin

- Admin Instituição

- Feed, Comunicados e Confirmação de Leitura

- Stories/Momentos e Mídia Infantil

- Chat/Canais

- Agenda e Autorizações Simples

- Diário de Rotina

- Notificações

- LGPD, Segurança e Política de Mídia

- Offline-tolerant/Offline-first Spike

- Analytics, Eventos e Dashboards Futuros

- Design System Coelo Flutter

- Site Institucional e Marca

Coelo · PRD Master v1 · Fim do documento
