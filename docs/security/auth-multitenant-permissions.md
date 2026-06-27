---
title: "Coelo PRD Auth Multi-tenant e Permissoes Oficial v1"
source_file: "Coelo PRD Auth Multi-tenant e Permissoes Oficial v1.docx"
source_copy: "docs/source/originals/docx/Coelo PRD Auth Multi-tenant e Permissoes Oficial v1.docx"
original_path: "C:/Users/adrie/Desktop/Coelo/PRD/Coelo PRD Auth Multi-tenant e Permissoes Oficial v1.docx"
status: "derived-from-official-docx"
version: "v1"
generated_at: "2026-06-22"
---

<!-- Documento derivado de fonte oficial. Edite a fonte DOCX ou registre uma decisao antes de alterar conteudo normativo. -->
| Coluna 1 | COELO<br>PRD Auth, Multi-tenant e Permissões Oficial v1<br>Identidade global · contexto ativo · RBAC + RLS |
| --- | --- |

Versão: v1.0 | Data: 21/06/2026 | Status: Draft para validação

| Pessoa é global. Papel, visibilidade e permissão são contextuais e sempre derivados de vínculos autorizados. |
| --- |

Simples como Airbnb Visual como Instagram Confiável como escola

Documento derivado do Product Vision Oficial v1 e do PRD Master Oficial v1 do Coelo.

# Sumário executivo do documento

| # | Seção |
| --- | --- |
| 1 | Capa e controle de versão |
| 2 | Resumo executivo |
| 3 | Princípios de identidade |
| 4 | Escopo do MVP |
| 5 | Pessoa, usuário e perfis |
| 6 | Login e recuperação |
| 7 | @username |
| 8 | CPF e deduplicação |
| 9 | Hierarquia multi-tenant |
| 10 | Vínculos familiares |
| 11 | Papéis e permissões |
| 12 | Contexto ativo |
| 13 | Convites |
| 14 | Fluxos principais |
| 15 | Requisitos funcionais |
| 16 | Regras de autorização |
| 17 | RLS e backend |
| 18 | Eventos e auditoria |
| 19 | Segurança |
| 20 | Requisitos não funcionais |
| 21 | Critérios de aceite |
| 22 | Riscos e mitigação |
| 23 | Decisões oficiais |
| 24 | Perguntas em aberto |
| 25 | Próximas specs |
| 26 | Fontes e referências |

# 1. Capa e controle de versão

| Campo | Valor |
| --- | --- |
| Documento | PRD Auth, Multi-tenant e Permissões Oficial v1 — Coelo |
| Owner | Produto + Engenharia Coelo |
| Público interno | Produto, design, engenharia, dados, segurança, jurídico, operações e agentes de coding. |
| Status | Draft para revisão e versionamento. |
| Base interna | Product Vision Oficial v1; PRD Master Oficial v1; História da Logo e Marca Oficial v1; mapa competitivo e decisões do fundador. |
| Escopo | Identidade, autenticação, deduplicação, usernames, hierarquia de tenants, vínculos, contexto ativo, RBAC e RLS. |

| Versão | Data | Mudança | Responsável |
| --- | --- | --- | --- |
| v1.0 | 21/06/2026 | Criação do PRD específico alinhado ao PRD Master e às decisões oficiais do fundador. | Produto Coelo |
| v1.1 | A definir | Revisão após specs técnicas, protótipo e validação do piloto. | Produto + Engenharia |
| v2.0 | A definir | Atualização após piloto real e priorização da próxima fase. | Produto + Negócio |

# 2. Resumo executivo

Este PRD define a fundação de acesso do Coelo. Uma pessoa possui identidade global, mas pode ter vários papéis e vínculos em diferentes instituições. O login não concede acesso por si só: a visibilidade é calculada a partir de memberships, vínculos familiares, contexto ativo e políticas RLS.

O MVP oferece login por e-mail ou celular, conforme escolha do usuário, além de @username. CPF é obrigatório para adultos. Crianças possuem @username global, porém a pesquisa é restrita a instituições autorizadas; não existe busca pública ou indexação aberta.

| Regra de ouro<br>Pessoa é global. Papel é contextual. Visibilidade deriva do vínculo ativo com instituição, unidade, grupo e criança. |
| --- |

# 3. Princípios de identidade

- Pessoa não é sinônimo de usuário: uma criança ou contato pode existir sem Auth.

- Uma pessoa não deve ser duplicada apenas porque pertence a duas instituições.

- Papel “professor” ou “responsável” só faz sentido com escopo e vínculo.

- Autorização deve ser aplicada no banco e backend, não apenas na interface.

- Busca e deduplicação entre tenants não podem revelar dados completos.

- Identificadores infantis são privados e não indexáveis publicamente.

# 4. Escopo do MVP

| Área | MVP | Definição |
| --- | --- | --- |
| Pessoa global | Sim | Cadastro unificado de adulto ou criança. |
| Auth | Sim | E-mail ou celular; senha e/ou OTP conforme fluxo final. |
| @username | Sim | Adultos e crianças; regras de pesquisa diferentes. |
| CPF adultos | Sim | Obrigatório para responsáveis e equipe. |
| Convites | Sim | Por link seguro com expiração e reenvio controlado. |
| Deduplicação | Sim | CPF, e-mail, celular e identificadores protegidos. |
| Multi-tenant | Sim | Instituição → unidade → grupo → criança/contexto. |
| Múltiplos papéis | Sim | Na mesma ou em diferentes instituições. |
| Contexto ativo | Sim | Instituição, papel e escopo atual. |
| RBAC + RLS | Sim | Permissão por papel e contexto. |
| MFA | A definir | Recomendado para perfis privilegiados; decisão operacional pendente. |

# 5. Pessoa, usuário e perfis

| Conceito | Definição |
| --- | --- |
| Pessoa | Registro global de identidade de adulto ou criança. |
| Usuário Auth | Pessoa com credencial e sessão ativa no Supabase Auth. |
| Perfil de usuário | Avatar, @username, preferências e status de conta. |
| Membership | Vínculo da pessoa com instituição/unidade/grupo e papel. |
| Registro contextual da criança | Dados da criança específicos de uma instituição. |
| Vínculo familiar | Relação entre responsável e criança. |
| Permissão familiar contextual | Define se o responsável pode ver a criança naquela instituição. |

# 6. Login e recuperação

| Caminho | Regra do MVP |
| --- | --- |
| E-mail | Usuário pode escolher login por e-mail. |
| Celular | Usuário pode escolher login por celular. |
| Senha/OTP | Supabase suporta ambos; a combinação final por tela será definida na Functional Spec. |
| @username | Identificador de perfil e busca controlada; não substitui sozinho a prova de posse do e-mail/celular. |
| Recuperação | Por e-mail ou celular, sem confirmar publicamente se a conta existe. |
| Troca de contato | Exige reautenticação e confirmação do novo contato. |
| Convite | Vincula a pessoa existente ou cria Auth para a pessoa cadastrada. |

# 7. @username

| Tipo | Regra |
| --- | --- |
| Adultos | Global e único, usado em perfil, menções e busca interna controlada. |
| Crianças | Global e único, pesquisável somente por instituições autorizadas. |
| Instituições/unidades/grupos | Username privado da rede, quando aplicável. |
| Busca pública | Não existe. |
| Indexação externa | Não permitida. |
| Edição | Responsável deve ter acesso fácil ao username da criança e poder solicitar/realizar edição conforme regra. |
| Menções | Somente em audiências e contextos autorizados. |

| Proteção infantil<br>A escolha por @username global infantil exige salvaguardas: nenhuma busca pública, resposta mínima em pesquisas, autorização institucional e validação de vínculo antes de revelar ou convidar a criança. |
| --- |

# 8. CPF e deduplicação

- CPF é obrigatório para adultos no MVP.

- CPF não deve aparecer completo em buscas de correspondência entre tenants.

- E-mail e celular também participam do matching.

- A criança pode usar identificadores próprios e @username; CPF infantil não foi definido como obrigatório.

- Possíveis correspondências exigem fluxo controlado de vinculação/convite, não cópia automática de dados.

- Merge de pessoas duplicadas é operação sensível e deve ficar restrito a fluxo específico.

# 9. Hierarquia multi-tenant

| Nível | Relacionamento | Uso de autorização |
| --- | --- | --- |
| Plataforma Coelo | Contém múltiplas instituições. | Somente equipe Coelo autorizada. |
| Instituição | Tenant principal. | Limite superior dos dados do cliente. |
| Unidade | Pertence à instituição. | Escopo operacional e de conteúdo. |
| Grupo | Pertence à unidade. | Turma/equipe/atendimento e perfil social. |
| Criança contextual | Pessoa global + instituição. | Rotina, responsáveis e dados locais. |
| Responsável contextual | Pessoa global + permissão para criança/contexto. | Acesso familiar. |
| Equipe contextual | Pessoa global + membership/papel. | Acesso profissional. |

# 10. Vínculos familiares

Uma criança pode estar ligada a duas instituições, unidades e grupos. O responsável vê naturalmente os contextos para os quais recebeu autorização. Durante o cadastro ou vínculo, a instituição seleciona quais responsáveis relacionados à criança podem visualizar aquele contexto.

| Objeto | Função |
| --- | --- |
| guardian_link | Registra a relação responsável–criança. |
| child_context | Registra a criança dentro de uma instituição. |
| guardian_context_permission | Autoriza o responsável a ver e agir naquele contexto institucional. |
| group_membership | Vincula a criança ao grupo/turma. |
| permission flags | Rotina, comunicados, agenda, chat e outras ações, conforme definição futura. |

- Mais de dois responsáveis são permitidos.

- A estrutura comercial fica preparada para adicional após dois responsáveis, sem cobrança ou bloqueio no MVP.

- Revogar acesso em uma instituição não remove a relação familiar global nem acessos válidos em outra instituição.

# 11. Papéis e permissões

| Papel | Escopo típico | Acesso |
| --- | --- | --- |
| Superadmin Coelo | Plataforma/tenants | Conforme cargo interno. |
| Diretor/Owner | Instituição | Configuração, pessoas, permissões e operação completa. |
| Admin autorizado | Instituição/unidade | Gestão delegada, inclusive permissões quando explicitamente autorizado. |
| Coordenador | Unidades/grupos | Supervisão e operação, sem poder automático de alterar permissões. |
| Professor | Grupos | Rotina, conteúdo e chat com responsáveis vinculados. |
| Equipe | Função/contexto | Ações limitadas. |
| Responsável | Criança/contextos autorizados | Rotina, Flow, agenda e chat. |
| Participante | Contexto específico | Opcional e restrito. |

| Modelo de autorização<br>RBAC define o que um papel pode fazer; o escopo contextual define onde; vínculos familiares e regras específicas definem sobre quem. |
| --- |

# 12. Contexto ativo

- Exibir instituição e papel atual.

- Permitir troca entre vínculos válidos.

- Unidade, grupo ou criança podem ser subcontextos.

- Toda consulta e comando deve validar o contexto no backend/RLS.

- Não confiar em institution_id enviado pelo cliente sem conferir membership.

- Troca de contexto gera evento de analytics e limpa/atualiza caches sensíveis.

# 13. Convites

| Etapa | Regra |
| --- | --- |
| Criação | Admin seleciona pessoa e papel/contexto. |
| Entrega | E-mail ou celular com link/código seguro. |
| Expiração | Obrigatória; prazo exato na Technical Spec. |
| Aceite | Usuário autentica ou cria credencial e confirma vínculo. |
| Pessoa existente | Convite liga a Auth/pessoa existente sem duplicar. |
| Reenvio | Controlado e com rate limit. |
| Revogação | Convite pendente pode ser cancelado. |

# 14. Fluxos principais

| Fluxo | Passos | Critério de aceite |
| --- | --- | --- |
| Login | Escolher e-mail/celular → autenticar → carregar vínculos → escolher contexto. | A sessão não concede dados fora dos vínculos. |
| Convite de adulto | Admin cadastra/busca → define papel → envia → adulto autentica → aceita. | Pessoa não é duplicada. |
| Vincular criança multi-instituição | Instituição busca username/identificador autorizado → cria child_context → vincula grupos e responsáveis. | Cada tenant vê apenas seu contexto. |
| Autorizar responsável | Selecionar criança/contexto → selecionar responsáveis → conceder acessos. | Somente selecionados veem o contexto. |
| Trocar papel | Abrir seletor → escolher vínculo → atualizar sessão lógica. | Ações e dados mudam imediatamente. |
| Recuperar conta | Solicitar por e-mail/celular → verificar → redefinir/acessar. | Fluxo não enumera contas. |

# 15. Requisitos funcionais

| ID | Área | Requisito |
| --- | --- | --- |
| AU-RF-001 | Pessoa | Manter pessoa global independente de Auth. |
| AU-RF-002 | Login | Permitir e-mail ou celular conforme escolha. |
| AU-RF-003 | Username | Criar @username único para adultos e crianças. |
| AU-RF-004 | Busca infantil | Restringir pesquisa de criança a instituições autorizadas. |
| AU-RF-005 | CPF | Exigir CPF de adultos. |
| AU-RF-006 | Deduplicação | Relacionar CPF, e-mail e celular sem revelar outro tenant. |
| AU-RF-007 | Convites | Criar, reenviar, expirar e revogar convites. |
| AU-RF-008 | Multi-papel | Permitir vários papéis por pessoa. |
| AU-RF-009 | Contexto | Alternar instituição/papel/escopo. |
| AU-RF-010 | Família | Autorizar responsáveis por contexto institucional. |
| AU-RF-011 | RBAC | Validar ação por papel. |
| AU-RF-012 | RLS | Validar acesso por tenant, vínculo e contexto. |
| AU-RF-013 | Auditoria | Registrar mudanças e acessos sensíveis. |

# 16. Regras de autorização

- Autenticação prova quem é o usuário; autorização decide o que ele pode acessar.

- Toda tabela tenant-data possui institution_id direto ou derivável por FK segura.

- Responsável acessa criança somente se existir guardian_context_permission ativo.

- Professor acessa criança somente por membership em grupo/unidade válido e permissão do papel.

- Owner/admin autorizado altera permissões; coordenador não recebe essa capacidade automaticamente.

- Acesso interno Coelo depende de platform membership/cargo.

- URLs, IDs e parâmetros fornecidos pelo cliente nunca substituem policies.

# 17. RLS e backend

| Camada | Regra |
| --- | --- |
| Postgres/RLS | Obrigatória em tabelas expostas; negar por padrão. |
| Storage | Policies equivalentes para objetos privados. |
| Realtime | Canais autorizados por RLS/policies. |
| Edge Functions | Operações com privilégio, convites e integrações. |
| Cliente Flutter | Usa chave publicável e JWT do usuário; nunca service role. |
| Service role/secret | Somente servidor/Edge Function e com escopo mínimo. |
| Testes | Seeds de ao menos dois tenants, múltiplos papéis e tentativas cruzadas. |

## 17.1 Schemas e superficie de acesso

A decisao tecnica inicial separa o banco em quatro schemas:

- `public`: dados operacionais acessiveis por apps somente com grants e RLS.
- `app_private`: funcoes, RPCs e helpers privilegiados; nao exposto.
- `audit`: logs e evidencias sensiveis; sem grants diretos para `anon` ou `authenticated`.
- `analytics`: eventos minimizados, contadores e snapshots; sem grants diretos para `anon` ou `authenticated`.

Admin institucional e App principal nao devem consultar `audit` ou `analytics` diretamente. Superadmin deve acessar esses dados por permissao interna (`audit.read` ou `analytics.read`) e, quando houver UI, preferencialmente por RPC/backend auditado.

# 18. Eventos e auditoria

| Evento | Uso |
| --- | --- |
| user_signed_in/failed | Segurança e adoção. |
| invite_created/accepted/revoked | Onboarding. |
| context_switched | UX e segurança. |
| username_changed | Identidade. |
| person_match_detected | Deduplicação. |
| membership_changed | Governança. |
| guardian_context_permission_changed | Acesso familiar. |
| permission_changed | Auditoria. |
| privileged_access_used | Acesso interno sensível. |

Eventos de uso e produto ficam em `analytics`; evidencias de acesso privilegiado e suporte ficam em `audit`. Nenhum dos dois schemas substitui dados transacionais de `public`.

# 19. Segurança

- Rate limits em login, OTP, convites e recuperação.

- Proteção contra enumeração de conta.

- Reautenticação para mudanças sensíveis.

- Sessões revogáveis e dispositivos/logins monitoráveis em fase apropriada.

- MFA para perfis privilegiados permanece recomendada, mas não foi decidida como requisito do MVP.

- CPF e contatos devem ser mascarados em telas de busca.

- Username infantil não pode ser exposto em APIs públicas de pesquisa.

# 20. Requisitos não funcionais

| Categoria | Requisito |
| --- | --- |
| Segurança | Deny-by-default, RLS e validação server-side. |
| Privacidade | Minimização, mascaramento e busca infantil restrita. |
| Performance | Carregar vínculos e contexto sem múltiplas consultas desnecessárias. |
| Confiabilidade | Convites idempotentes e sessões consistentes. |
| Auditabilidade | Ações de identidade e permissão rastreáveis. |
| Manutenibilidade | Policies versionadas e testes automatizados. |
| Usabilidade | Login simples, recuperação clara e seletor de contexto compreensível. |

# 21. Critérios de aceite

- Adulto entra por e-mail ou celular e acessa os mesmos vínculos.

- Cadastro de adulto sem CPF não é concluído.

- Pessoa com dois papéis alterna contexto sem mistura de dados.

- Criança vinculada a duas instituições mantém uma pessoa global e dois contextos isolados.

- Instituição não autorizada não localiza criança por username.

- Instituição autorizada localiza e inicia fluxo de vínculo sem receber dados além do necessário.

- Responsável não selecionado para um contexto não vê a criança naquela instituição.

- Tentativa de acesso cruzado por ID/URL é negada pela RLS.

- Service role não aparece em código cliente.

# 22. Riscos e mitigação

| Risco | Impacto | Mitigação |
| --- | --- | --- |
| Username infantil global | Crítico | Busca restrita, não indexação, resposta mínima e autorização. |
| CPF obrigatório aumentar atrito | Médio | Explicar finalidade, proteger e validar. |
| Duplicidade de pessoas | Alto | Matching, fluxo de vínculo e merge controlado. |
| RLS complexa | Crítico | Policies pequenas, funções auxiliares e testes multi-tenant. |
| Contexto ativo confuso | Alto | UX explícita e limpeza de cache. |
| Permissões acumuladas | Alto | Escopo explícito, revisão e auditoria. |

# 23. Decisões oficiais

| Decisão | Valor oficial v1 |
| --- | --- |
| Login | E-mail ou celular, conforme escolha do usuário. |
| @username | Parte da identidade. |
| CPF adultos | Obrigatório. |
| @username crianças | Global, pesquisável somente por instituições autorizadas. |
| Pessoa | Global. |
| Papel | Contextual. |
| Criança multi-instituição | Uma pessoa global com child_context por instituição. |
| Responsável | Acesso selecionado por contexto institucional. |
| Alterar permissões Admin | Owner/diretor e admins autorizados. |
| MFA | Ainda não definida como requisito do MVP. |

# 24. Perguntas em aberto

- Senha, OTP ou ambos em cada canal?

- Qual prova torna uma instituição “autorizada” a pesquisar username infantil?

- Quem aprova alteração de username da criança?

- Quais flags de permissão familiar existirão no MVP?

- Qual política de bloqueio e recuperação para CPF já vinculado?

- MFA será obrigatória para Superadmin e direção antes do piloto?

# 25. Próximas specs

- Technical Spec do schema de people, identities, memberships e contextos.

- Technical Spec de policies RLS e funções auxiliares.

- Functional Spec de login, convite, recuperação e seletor de contexto.

- Threat model de username infantil e deduplicação.

- Test Plan de dois tenants, multi-papel e vínculos familiares.

# 26. Aditivo 2026-06-23 - MFA do Owner Coelo

Este aditivo registra uma decisao especifica do Superadmin Completo v1: MFA e obrigatoria para o Owner Coelo no login e em acoes sensiveis. A criacao de novos Owners deve ocorrer por convite aceito + MFA configurada.

A obrigatoriedade de MFA para Operations, Support, Content, Auditor, Admin institucional, direcao e outros perfis privilegiados permanece em aberto e deve ser definida por papel e risco em Technical Spec propria.

Esta decisao atualiza parcialmente a pergunta aberta de MFA sem encerrar a politica geral de autenticacao reforcada.

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
