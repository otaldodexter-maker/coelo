---
title: "Coelo PRD Admin Oficial v1"
source_file: "Coelo PRD Admin Oficial v1.docx"
source_copy: "docs/source/originals/docx/Coelo PRD Admin Oficial v1.docx"
original_path: "C:/Users/adrie/Desktop/Coelo/PRD/Coelo PRD Admin Oficial v1.docx"
supplemental_source: "decisions/0015-contextual-people-authorizations-attendance.md; specs/015-contextual-people-access-attendance.md"
status: "derived-from-official-docx"
version: "v1"
generated_at: "2026-07-24"
---

<!-- Documento derivado de fonte oficial. Edite a fonte DOCX ou registre uma decisao antes de alterar conteudo normativo. -->
| Coluna 1 | COELO<br>PRD Admin Oficial v1<br>admin.coelo.me · Gestão da instituição |
| --- | --- |

Versão: v1.0 | Data: 21/06/2026 | Status: Draft para validação

| O Admin configura unidades, grupos, pessoas, vínculos, permissões, importações e operação institucional do Coelo. |
| --- |

Simples como Airbnb Visual como Instagram Confiável como escola

Documento derivado do Product Vision Oficial v1 e do PRD Master Oficial v1 do Coelo.

# Sumário executivo do documento

| # | Seção |
| --- | --- |
| 1 | Capa e controle de versão |
| 2 | Resumo executivo |
| 3 | Objetivos e princípios |
| 4 | Escopo do MVP |
| 5 | Fora de escopo |
| 6 | Atores e permissões |
| 7 | Estrutura institucional |
| 8 | Importação CSV/XLSX |
| 9 | Cadastros e vínculos |
| 10 | Conteúdo e operação |
| 11 | Fluxos principais |
| 12 | Requisitos funcionais |
| 13 | Regras de negócio |
| 14 | Eventos e auditoria |
| 15 | Segurança e LGPD |
| 16 | Requisitos não funcionais |
| 17 | Critérios de aceite |
| 18 | Riscos e mitigação |
| 19 | Decisões oficiais |
| 20 | Perguntas em aberto |
| 21 | Próximas specs |
| 22 | Fontes e referências |

# 1. Capa e controle de versão

| Campo | Valor |
| --- | --- |
| Documento | PRD Admin Oficial v1 — Coelo |
| Owner | Produto Coelo + instituição cliente |
| Público interno | Produto, design, engenharia, dados, segurança, jurídico, operações e agentes de coding. |
| Status | Draft para revisão e versionamento. |
| Base interna | Product Vision Oficial v1; PRD Master Oficial v1; História da Logo e Marca Oficial v1; mapa competitivo e decisões do fundador. |
| Escopo | Painel da instituição para gestão de estrutura, pessoas, vínculos, permissões, importação em massa, conteúdo, rotina, agenda e canais. |

| Versão | Data | Mudança | Responsável |
| --- | --- | --- | --- |
| v1.0 | 21/06/2026 | Criação do PRD específico alinhado ao PRD Master e às decisões oficiais do fundador. | Produto Coelo |
| v1.1 | A definir | Revisão após specs técnicas, protótipo e validação do piloto. | Produto + Engenharia |
| v2.0 | A definir | Atualização após piloto real e priorização da próxima fase. | Produto + Negócio |

# 2. Resumo executivo

O Admin permite que a instituição configure e mantenha sua operação sem depender do Coelo para cada ajuste. O painel cobre unidades, grupos/turmas, participantes, responsáveis, equipe, perfis, permissões, importação de dados e configurações dos módulos usados no App.

A importação em massa entra no MVP por CSV e XLSX e deve abranger, conforme o arquivo e o mapeamento, unidades, grupos/turmas, participantes/crianças, responsáveis, equipe e vínculos. O processo precisa mostrar prévia, validações e erros antes de confirmar a gravação.

| Governança de permissões<br>Somente diretor/owner e admins explicitamente autorizados podem criar ou alterar permissões. Coordenadores podem receber acessos operacionais, mas não ganham esse poder automaticamente. |
| --- |

# 3. Objetivos e princípios

| Objetivo | Aplicação |
| --- | --- |
| Autonomia do cliente | Instituição administra sua própria estrutura e pessoas. |
| Onboarding rápido | Importação CSV/XLSX e criação guiada reduzem cadastro manual. |
| Pessoa única | Buscar e vincular pessoa existente antes de criar duplicidade. |
| Papéis contextuais | Permissões dependem de instituição, unidade, grupo e criança. |
| Operação simples | Fluxos conhecidos, templates e ações em lote. |
| Privacidade infantil | A instituição só vê e gerencia dados do próprio contexto. |

# 4. Escopo do MVP

| Área | MVP | Definição |
| --- | --- | --- |
| Instituição | Sim | Dados, configurações e branding leve. |
| Unidades | Sim | Criar, editar e inativar unidades e seus perfis sociais. |
| Grupos/turmas | Sim | Criar grupos, tipos, vínculos, perfis e regras de seguidores. |
| Atividades | Sim | Criar, editar e vincular atividades a pelo menos uma unidade e depois a grupos, com professores e permissões por turma. A unidade cria somente quando essa capacidade estiver habilitada em seu perfil. |
| Pessoas | Sim | Cadastrar, deduplicar, convidar e vincular papéis. |
| Participantes/crianças | Sim | Dados mínimos, contexto institucional, grupos e responsáveis. |
| Responsáveis | Sim | Vínculo, autorizações e visibilidade por criança/contexto. |
| Equipe | Sim | Direção, admins, coordenação, professores e apoio. |
| Permissões | Sim | Geridas por owner/diretor e admins autorizados. |
| Importação | Sim | CSV e XLSX para cadastros e vínculos aplicáveis. |
| Conteúdo | Sim | Happens, comunicados, Now, Moments, agenda e templates de rotina. |
| Chat/canais | Sim | Configuração de membros, acessos e políticas institucionais. |
| Dados básicos | Sim | Eventos, logs e exportações simples futuras/preparadas. |

# 5. Fora de escopo

| Fora do MVP | Motivo | Preparação |
| --- | --- | --- |
| ERP financeiro completo | Fora da tese inicial. | Preparar IDs e integrações futuras. |
| Matrícula digital e assinatura | Fluxo jurídico/contratual maior. | Manter pessoas, vínculos e documentos preparados. |
| Cobrança automática | V2. | Planos e status ficam no Superadmin. |
| Dashboard completo | Dados ainda em validação. | Registrar eventos e logs desde o MVP. |
| White label forte | Complexidade de apps dedicados. | Branding leve no Admin. |
| Importação sem revisão | Risco de duplicidade e vazamento. | Sempre usar prévia, validação e confirmação. |

# 6. Atores e permissões

| Papel | Escopo | Permissões principais |
| --- | --- | --- |
| Diretor/Owner | Instituição | Configurações, unidades, grupos, pessoas, permissões, conteúdo e dados. |
| Admin autorizado | Instituição/unidade | Gestão delegada, inclusive permissões quando autorizado. |
| Coordenador | Unidades/grupos | Supervisão de equipe, rotina, conteúdo, agenda e atendimento. |
| Professor | Grupos | Rotina, publicações autorizadas, agenda e chat com responsáveis vinculados. |
| Equipe de apoio | Função/contexto | Acesso operacional limitado conforme necessidade. |

| Ação | Owner/Diretor | Admin autorizado | Coordenador | Professor |
| --- | --- | --- | --- | --- |
| Criar unidade/grupo | Sim | Sim, se delegado | Não ou conforme operação | Não |
| Criar atividade | Sim | Sim, se a capacidade estiver habilitada no perfil | Com delegação explícita | Não |
| Cadastrar/importar pessoas | Sim | Sim | Com permissão operacional | Não |
| Alterar permissões | Sim | Sim, se autorizado | Não | Não |
| Vincular responsável | Sim | Sim | Com permissão | Solicitar/visualizar se permitido |
| Publicar comunicado | Sim | Sim | Sim | Conforme permissão |
| Auditar rotina | Sim | Sim | Sim | Próprio grupo |
| Configurar canal | Sim | Sim | Conforme permissão | Não |

# 7. Estrutura institucional

| Nível | Definição | Regra |
| --- | --- | --- |
| Instituição | Tenant principal. | Isolamento obrigatório em banco e aplicação. |
| Unidade | Sede, campus, filial ou operação local. | Pertence a uma instituição. |
| Grupo | Turma, equipe, atendimento ou outro agrupamento. | Pertence a uma unidade e pode gerar perfil social. |
| Pessoa | Cadastro global de adulto ou criança. | Pode ter múltiplos vínculos contextuais. |
| Criança/participante | Pessoa com registro contextual na instituição. | Pode estar em várias instituições, unidades e grupos. |
| Responsável | Pessoa adulta ligada à criança. | Visibilidade é concedida por contexto institucional. |
| Perfil social | Perfil privado da instituição, unidade ou grupo. | Seguidores derivados dos vínculos. |

# 8. Importação CSV/XLSX

A importação deve acelerar o onboarding sem permitir gravações cegas. O Admin seleciona o tipo de dados, envia o arquivo, mapeia colunas, revisa a prévia, corrige erros e confirma o processamento.

| Tipo importável | Campos/relacionamentos esperados | Observação |
| --- | --- | --- |
| Unidades | Nome, identificadores internos e dados institucionais aplicáveis. | Campos finais na spec técnica. |
| Grupos/turmas | Unidade, nome, tipo, período/faixa quando aplicável. | Evitar nomenclatura exclusivamente escolar no banco. |
| Atividades | Nome, descrição, instituição, unidade de origem, unidades vinculadas, grupos, professores e permissões por turma. | Reutilizável dentro da mesma instituição; criação pela unidade exige delegação. |
| Participantes/crianças | Nome, nascimento quando aplicável, referência privada e grupo opcional. | Dados mínimos; criança não depende de `@username` e o contexto pertence à instituição. |
| Responsáveis | Nome, CPF obrigatório, e-mail/celular, relação e permissões. | Criar ou vincular pessoa adulta existente. |
| Equipe | Nome, CPF obrigatório, contato, papel e escopo. | Convite pode ser enviado após validação. |
| Vínculos | Criança–responsável, pessoa–papel, grupo–pessoa. | Selecionar quais responsáveis podem ver cada contexto. |

| Etapa | Comportamento obrigatório |
| --- | --- |
| Upload | Aceitar CSV e XLSX dentro de limites definidos na Technical Spec. |
| Mapeamento | Associar colunas do arquivo aos campos do Coelo. |
| Prévia | Mostrar linhas válidas, avisos e erros antes da gravação. |
| Deduplicação | Buscar adultos por CPF e contatos; proteger dados de outros tenants. |
| Validação | Verificar obrigatórios, formatos, vínculos e referências. |
| Confirmação | Exigir confirmação explícita do usuário autorizado. |
| Resultado | Exibir criados, atualizados, ignorados e rejeitados, com relatório de erros. |
| Auditoria | Registrar arquivo, ator, instituição, tipo, resultado e timestamp sem expor conteúdo além do necessário. |

# 9. Cadastros e vínculos

## 9.1 Pessoas e acesso

- Ao cadastrar adulto, CPF é obrigatório; e-mail e/ou celular permitem convite e login.

- Adulto pode criar conta global antes de qualquer instituição; instituição ou
  unidade também pode convidar conta nova ou existente.

- Pessoa pode existir sem Auth ativo, e a credencial Auth continua opcional
  para a identidade global. Criança não possui credencial no MVP.

- Conta, e-mail ou `@identificador` não concedem acesso por si mesmos.

- Responsável autenticado pode localizar exatamente instituição/unidade por
  `@`, e-mail, link ou QR e solicitar vínculo; a solicitação permanece sem
  acesso até validação institucional.

- Antes de criar, o sistema busca possível correspondência sem revelar dados completos de outro tenant.

- A descoberta global por `@username` no MVP é restrita a adultos, instituições
  e unidades; regras detalhadas ficam no PRD Auth. A criança mantém identidade
  global privada, mas não exige `@username` nem login no MVP.

## 9.2 Criança, instituições e responsáveis

- A criança pode estar vinculada a duas ou mais instituições, unidades e grupos.

- Cadastro infantil é híbrido: responsável ou instituição inicia e a
  instituição valida identidade, relação e possível duplicidade sem merge
  automático.

- Cada instituição possui um registro contextual da criança, sem duplicar a
  pessoa global.

- A aprovação cria primeiro o vínculo criança–unidade. A turma é opcional
  naquele momento; sem turma, a criança fica aguardando alocação.

- A relação familiar pode existir globalmente, mas a visibilidade é concedida no contexto da instituição.

- No cadastro/vínculo, a instituição seleciona quais responsáveis poderão visualizar aquele contexto.

- A arquitetura aceita qualquer quantidade de responsáveis sem limite técnico;
  eventual regra comercial permanece adiada e não bloqueia nem cobra no MVP.

# 10. Conteúdo e operação

| Área | Configurações do Admin |
| --- | --- |
| Happens/comunicados | Perfis, audiência, confirmação de leitura, reações simples e comentários desativados no MVP. |
| Now | Quem publica, audiência, consentimento de imagem e expiração. |
| Moments | Vídeos de até 2 minutos, audiência e moderação institucional. |
| Agenda | Eventos, audiência, RSVP e autorização simples. |
| Diário de rotina | Templates por instituição/unidade/grupo, campos e permissões de publicação. |
| Chat/canais | Membros, grupos acessíveis, auditoria, professor–responsável vinculado e canais institucionais. |
| Notificações | Preferências institucionais e tipos obrigatórios. |
| Branding leve | Logo, capa, cor/acento, nome e textos de onboarding, se não atrasar o MVP. |

# 11. Fluxos principais

| Fluxo | Passos essenciais | Critério de aceite |
| --- | --- | --- |
| Onboarding | Acessar checklist → revisar instituição → criar/importar unidades e grupos → importar pessoas → revisar vínculos. | Instituição fica apta a convidar usuários e operar o App. |
| Revisar solicitação | Abrir fila → validar responsável, criança, relação e duplicidade → aprovar/rejeitar → definir unidade e turma opcional. | Aprovação cria contexto e vínculo criança–unidade; solicitação pendente não concede acesso. |
| Criar grupo | Selecionar unidade → definir nome/tipo → configurar equipe e perfil → salvar. | Grupo e perfil privado ficam vinculados ao tenant. |
| Importar base | Escolher tipo → upload CSV/XLSX → mapear → validar → confirmar → revisar resultado. | Nenhum registro com erro crítico é gravado silenciosamente. |
| Vincular responsáveis | Selecionar criança → buscar/cadastrar responsáveis → definir visibilidade por contexto. | Somente responsáveis autorizados veem o contexto. |
| Conceder permissão | Owner/admin autorizado seleciona pessoa → papel → escopo → confirma. | Nova permissão vale apenas no contexto definido e gera log. |
| Criar template de rotina | Selecionar contexto → configurar itens → salvar/publicar. | Professor do grupo visualiza o template correto. |

# 12. Requisitos funcionais

| ID | Área | Requisito |
| --- | --- | --- |
| AD-RF-001 | Instituição | Editar configurações e branding leve. |
| AD-RF-002 | Unidades | Criar, editar e inativar unidades. |
| AD-RF-003 | Grupos | Criar e manter grupos/turmas e perfis sociais. |
| AD-RF-004 | Pessoas | Cadastrar, buscar, deduplicar e convidar pessoas. |
| AD-RF-005 | Adultos | Exigir CPF no cadastro de responsáveis e equipe. |
| AD-RF-006 | Crianças | Criar registro contextual e vincular a múltiplos grupos. |
| AD-RF-007 | Responsáveis | Definir quais responsáveis podem visualizar cada contexto da criança. |
| AD-RF-008 | Permissões | Permitir alteração somente por owner/diretor e admins autorizados. |
| AD-RF-009 | Importação | Importar CSV/XLSX com mapeamento, prévia, validação e resultado. |
| AD-RF-010 | Conteúdo | Gerenciar Happens, comunicados, Now, Moments e agenda. |
| AD-RF-011 | Rotina | Gerenciar templates e permissões do diário. |
| AD-RF-012 | Chat | Configurar canais, membros e escopos de histórico. |
| AD-RF-013 | Auditoria | Registrar importações, vínculos, permissões e mudanças sensíveis. |
| AD-RF-014 | Atividades | Criar, editar, vincular e gerir atividades por turma com permissões contextuais; criação pela unidade depende de capacidade explícita no perfil. |

# 13. Regras de negócio

- Pessoa é global; papel e acesso são contextuais.

- CPF é obrigatório para adultos no MVP.

- Uma criança pode pertencer a múltiplas instituições, unidades e grupos.

- A instituição decide quais responsáveis vinculados podem ver seu contexto.

- Somente owner/diretor e admins autorizados alteram permissões.

- A atividade pertence sempre à instituição. Quando criada por uma unidade autorizada, herda a instituição-mãe, nasce vinculada à unidade de origem e continua ajustável pela instituição.

- Usuários com escopo apenas de unidade não podem vincular a atividade a unidades irmãs ou grupos externos ao seu escopo sem permissão institucional adicional.

- Importação nunca pode expor dados completos de pessoa pertencente a outro tenant durante deduplicação.

- Inativação preserva histórico e auditoria.

- Comentários ficam desativados no MVP; reações simples são permitidas.

- Limite ou cobrança por responsáveis permanece fora do MVP e depende de
  decisão comercial futura.

# 14. Eventos e auditoria

| Evento | Uso |
| --- | --- |
| unit_created/updated | Estrutura institucional. |
| group_created/updated | Grupos e perfis. |
| activity_created/updated | Definição e vínculo de atividades. |
| activity_created_by_unit | Criação delegada, instituição herdada e unidade de origem. |
| activity_group_linked | Atividade vinculada à turma. |
| activity_member_assigned | Professor ou coordenação vinculados à atividade na turma. |
| import_started/completed/failed | Onboarding e qualidade dos dados. |
| person_created/matched | Deduplicação. |
| guardian_context_permission_changed | Governança familiar. |
| membership_created/updated | Papéis e escopos. |
| permission_changed | Segurança. |
| routine_template_changed | Operação do diário. |
| channel_policy_changed | Governança de chat. |

# 15. Segurança e LGPD

- Isolamento por institution_id e RLS; filtros no front-end não são suficientes.

- Importações devem ser processadas em ambiente controlado e excluir arquivos temporários conforme política futura.

- Prévia e logs devem minimizar CPF, contatos e dados infantis.

- Permissões e vínculos familiares são ações sensíveis e auditáveis.

- Prazos de retenção ainda não estão definidos e devem permanecer marcados como pendentes.

- Download de mídia é bloqueado por padrão conforme PRD LGPD, Segurança e Mídia.

# 16. Requisitos não funcionais

| Categoria | Requisito |
| --- | --- |
| Usabilidade | Onboarding guiado, importação com prévia e mensagens de erro acionáveis. |
| Performance | Listagens paginadas; processamento assíncrono para arquivos maiores quando definido na spec. |
| Segurança | RLS, validação server-side e autorização contextual. |
| Auditabilidade | Mudanças de permissão, vínculo e importação rastreáveis. |
| Acessibilidade | Formulários, contraste, foco e labels adequados para web. |
| Manutenibilidade | Módulos Flutter compartilhados e contratos de dados versionados. |
| Qualidade de dados | Validações, relatório de erros e prevenção de duplicidade. |

# 17. Critérios de aceite

- Admin importa unidades, grupos, crianças, responsáveis, equipe e vínculos por CSV/XLSX com prévia.

- Arquivo com erro não grava linhas críticas silenciosamente.

- Adulto sem CPF não conclui cadastro no MVP.

- Criança vinculada a duas instituições possui contextos separados sem duplicar a pessoa global.

- Responsável não selecionado para uma instituição não vê o contexto daquela criança.

- Coordenador sem delegação não consegue alterar permissões.

- Admin autorizado consegue alterar permissão e a ação gera audit log.

- Usuários de um tenant não acessam listas ou arquivos de outro tenant.

# 18. Riscos e mitigação

| Risco | Impacto | Mitigação |
| --- | --- | --- |
| Importação gerar duplicidades | Alto | CPF obrigatório para adultos, prévia e matching protegido. |
| Arquivo malformado | Médio | Validação, relatório por linha e confirmação. |
| Permissões amplas | Crítico | Owner/admin autorizado, escopo explícito e auditoria. |
| Vínculo familiar incorreto | Crítico | Revisão, confirmação e histórico de alterações. |
| Admin virar ERP pesado | Alto | Manter foco em comunicação, rotina e governança. |
| Cadastro amplo atrasar MVP | Alto | Priorizar fluxo de onboarding e importação por blocos. |

# 19. Decisões oficiais

| Decisão | Valor oficial v1 |
| --- | --- |
| Importação | CSV e XLSX. |
| Escopo da importação | Unidades, grupos/turmas, participantes/crianças, responsáveis, equipe, vínculos e demais cadastros aplicáveis. |
| Alterar permissões | Somente diretor/owner e admins autorizados. |
| CPF de adultos | Obrigatório. |
| Criança multi-instituição | Pessoa global com contextos por instituição/unidade/grupo. |
| Visibilidade de responsáveis | Selecionada pela instituição em cada contexto. |
| Responsáveis adicionais | Sem limite técnico; eventual regra comercial permanece adiada e sem cobrança no MVP. |
| Comentários | Fora do MVP; reações simples entram. |

# 20. Perguntas em aberto

- Quais layouts de planilha serão oferecidos como modelos oficiais?

- Quais campos mínimos por tipo de importação?

- A importação poderá atualizar registros existentes ou somente criar/vincular?

- Quais permissões operacionais poderão ser delegadas a coordenadores?

- Qual nível exato de branding leve entra no MVP?

# 21. Próximas specs

- Functional Spec: onboarding da instituição.

- Functional Spec: importação CSV/XLSX por entidade.

- Technical Spec: parser, staging, validação, deduplicação e rollback.

- Technical Spec: permissões do Admin e policies RLS.

- Functional/Technical Spec: atividades contextuais por turma.

- Test Plan: importação, isolamento e vínculos familiares.

# 22. Aditivo 2026-07-24 — Gestão Contextual

O Admin deve permitir:

- cadastrar profissionais com papéis padrão ou customizados, escopo automático de descendentes ou seleção explícita e eventual vínculo com crianças específicas;
- convidar responsáveis novos ou pre-cadastrados para uma ou várias crianças,
  definindo vínculo e permissões por criança durante o convite e permitindo
  edição posterior;
- revisar solicitações iniciadas pelo responsável por busca exata, link ou QR,
  inclusive possível duplicidade, sem liberar dados antes da aprovação;
- validar cadastro infantil iniciado por qualquer lado, criar o contexto da
  instituição e vincular primeiro à unidade, deixando turma opcional;
- consultar a pessoa de confiança privada apresentada pelo responsável somente
  no contexto da autorização e suspender autorizações de emergência, retirada
  ou transporte por instituição, criança e unidade, sempre com motivo,
  auditoria e notificação;
- manter cada suspensão independente: autorização de retirada não pertence à
  turma e decisão em uma unidade/tenant não altera outra;
- solicitar transferência de crianças entre unidades, aceitar no destino, processar lote e manter estado aguardando alocação quando não houver turma;
- criar atividades institucionais ou locais, promover atividade local sem duplicá-la, definir participação e governar capacidades;
- configurar chats por instituição, unidade, grupo e atividade e equipes
  responsáveis; a caixa única `Conversas` é somente agregação visual de
  conversas contextuais independentes;
- administrar presença, pendências familiares, correções auditadas e painéis de assiduidade.

Listas e ações devem desaparecer quando o profissional não possuir permissão. Um administrador da unidade pode enxergar todas as turmas ou apenas as selecionadas; unidade irmã nunca é herdada.

# Fontes e referências

## Fontes internas

- Coelo — Product Vision Oficial v1.

- Coelo — PRD Master Oficial v1.

- Coelo — História da Logo e Marca Oficial v1.

- Mapa competitivo de apps de agenda e comunicação escolar no Brasil.

- Decisões do fundador registradas em 21/06/2026 para os seis PRDs.

## Fontes externas oficiais

- Supabase — Row Level Security: https://supabase.com/docs/guides/database/postgres/row-level-security

- Supabase — Auth: https://supabase.com/docs/guides/auth

- Supabase — Storage Access Control: https://supabase.com/docs/guides/storage/security/access-control

- Supabase — Realtime Authorization: https://supabase.com/docs/guides/realtime/authorization

- Supabase — Edge Functions e secrets: https://supabase.com/docs/guides/functions e https://supabase.com/docs/guides/functions/secrets

- Flutter — App architecture: https://docs.flutter.dev/app-architecture

- ANPD — Enunciado sobre dados de crianças e adolescentes: https://www.gov.br/anpd/pt-br/assuntos/noticias/anpd-divulga-enunciado-sobre-o-tratamento-de-dados-pessoais-de-criancas-e-adolescentes

- ANPD — Comunicação de incidentes de segurança: https://www.gov.br/anpd/pt-br/assuntos/comunicacao-de-incidentes-de-seguranca-cis

- OWASP — ASVS: https://owasp.org/www-project-application-security-verification-standard/

- OWASP — MASVS: https://mas.owasp.org/MASVS/

Acesso às fontes externas: 21/06/2026. As referências jurídicas não substituem revisão por profissional habilitado.
