---
title: "Coelo PRD Auth Multi-tenant e Permissoes Oficial v1"
source_file: "Coelo PRD Auth Multi-tenant e Permissoes Oficial v1.docx"
source_copy: "docs/source/originals/docx/Coelo PRD Auth Multi-tenant e Permissoes Oficial v1.docx"
original_path: "C:/Users/adrie/Desktop/Coelo/PRD/Coelo PRD Auth Multi-tenant e Permissoes Oficial v1.docx"
supplemental_source: "decisions/0015-contextual-people-authorizations-attendance.md; specs/015-contextual-people-access-attendance.md"
status: "derived-from-official-docx"
version: "v1"
generated_at: "2026-07-24"
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

O MVP oferece login adulto por e-mail ou celular, conforme escolha do usuário,
além de `@identificador` global. CPF é obrigatório para adultos. Crianças são
identidades globais sem credencial no MVP; não precisam de e-mail, login ou
`@username`. Referências infantis privadas podem ser apresentadas por código ou
QR, sem busca pública ou indexação aberta.

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
| Auth | Sim | Credencial opcional para pessoas; e-mail ou celular adulto, senha e/ou OTP conforme fluxo final. Criança não possui Auth no MVP. |
| @username | Sim | Adultos, instituições e unidades. Identificador infantil fica adiado para a spec de experiência infantil. |
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
| Usuário Auth | Pessoa com credencial opcional e sessão ativa no Supabase Auth; criança não possui credencial no MVP. |
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
| Crianças | Não é necessário no MVP; eventual identificador integra a spec futura de experiência e login infantil. |
| Instituições/unidades/grupos | Username privado da rede, quando aplicável. |
| Busca pública | Não existe. |
| Indexação externa | Não permitida. |
| Edição | Adulto edita o próprio identificador conforme fluxo protegido; regra infantil fica adiada. |
| Menções | Somente em audiências e contextos autorizados; criança pode ser referenciada pelo contexto sem `@username`. |

| Proteção infantil<br>`people`, `child_contexts`, código/QR privado ou eventual `@username` infantil não ativam login nem visibilidade. A instituição valida o contexto antes de liberar qualquer dado. |
| --- |

# 8. CPF e deduplicação

- CPF é obrigatório para adultos no MVP.

- CPF não deve aparecer completo em buscas de correspondência entre tenants.

- E-mail e celular também participam do matching.

- A criança pode usar referência privada controlada; CPF infantil e
  `@username` não são obrigatórios no MVP.

- Possíveis correspondências exigem fluxo controlado de vinculação/convite, não cópia automática de dados.

- Merge de pessoas duplicadas é operação sensível e deve ficar restrito a fluxo específico.

# 9. Hierarquia multi-tenant

| Nível | Relacionamento | Uso de autorização |
| --- | --- | --- |
| Plataforma Coelo | Contém múltiplas instituições. | Somente equipe Coelo autorizada. |
| Instituição | Tenant principal. | Limite superior dos dados do cliente. |
| Unidade | Pertence à instituição. | Escopo operacional e de conteúdo. |
| Grupo | Pertence à unidade. | Turma/equipe/atendimento e perfil social. |
| Atividade | É definida na instituição, disponibilizada por unidade e acionada dentro do grupo. | Escopo funcional contextual, reutilizável na mesma instituição, com professores e permissões por turma. |
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
| activity_group_link | Define a atividade dentro da turma e os professores/permissões contextuais. |

- Qualquer quantidade de responsáveis é permitida tecnicamente.

- A arquitetura não limita tecnicamente a quantidade de responsáveis. Eventual
  regra comercial permanece adiada, sem cobrança ou bloqueio no MVP.

- Revogar acesso em uma instituição não remove a relação familiar global nem acessos válidos em outra instituição.

# 11. Papéis e permissões

| Papel | Escopo típico | Acesso |
| --- | --- | --- |
| Superadmin Coelo | Plataforma/tenants | Conforme cargo interno. |
| Diretor/Owner | Instituição | Configuração, pessoas, permissões e operação completa. |
| Admin autorizado | Instituição/unidade | Gestão delegada, inclusive permissões quando explicitamente autorizado. |
| Coordenador | Unidades/grupos | Supervisão e operação, sem poder automático de alterar permissões. |
| Professor | Grupos/Atividades | Rotina, conteúdo e chat com responsáveis vinculados, sempre no vínculo contextual da turma. |
| Equipe | Função/contexto | Ações limitadas. |
| Responsável | Criança/contextos autorizados | Rotina, Flow, agenda e chat. |
| Participante | Contexto específico | Opcional e restrito. |

- A instituição é proprietária de toda atividade, inclusive quando a criação se origina em uma unidade.

- A unidade ou usuário da unidade só pode criar atividade quando uma capacidade específica estiver habilitada na gestão do perfil.

- Na criação pela unidade, o vínculo com a instituição-mãe e com a unidade de origem é automático; a instituição pode editar, restringir ou desativar a atividade.

- Um ator restrito à unidade não recebe acesso automático a unidades irmãs nem a seus grupos.

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
| Criação | Instituição/unidade seleciona pessoa e papel/contexto; adulto também pode chegar por solicitação de vínculo. |
| Entrega | E-mail ou celular com link/código seguro. |
| Expiração | Obrigatória; prazo exato na Technical Spec. |
| Aceite | Usuário autentica ou cria credencial e confirma vínculo. |
| Pessoa existente | Convite liga a Auth/pessoa existente sem duplicar. |
| Reenvio | Controlado e com rate limit. |
| Revogação | Convite pendente pode ser cancelado. |

Conta, e-mail ou `@identificador` nunca concedem acesso por si mesmos. Adulto
pode criar conta global antes de qualquer instituição. Responsável autenticado
pode localizar exatamente instituição/unidade por `@`, e-mail, link ou QR e
solicitar vínculo; a solicitação continua sem acesso até validação
institucional.

# 14. Fluxos principais

| Fluxo | Passos | Critério de aceite |
| --- | --- | --- |
| Login | Escolher e-mail/celular → autenticar → carregar vínculos → escolher contexto. | A sessão não concede dados fora dos vínculos. |
| Pré-cadastro adulto | Criar conta global → verificar contato → permanecer sem contexto ou solicitar vínculo. | Conta sem vínculo não recebe dados institucionais. |
| Convite de adulto | Admin cadastra/busca → define papel → envia → adulto autentica → aceita. | Pessoa não é duplicada. |
| Solicitar vínculo | Responsável localiza exatamente instituição/unidade por `@`, e-mail, link ou QR → informa criança/relação → aguarda revisão. | Solicitação pendente não concede nem revela dados privados. |
| Vincular criança multi-instituição | Responsável ou instituição inicia → instituição revisa identidade/duplicidade → cria `child_context` e `child_unit_link` → grupo opcional. | Cada tenant vê apenas seu contexto; possível duplicidade não é mesclada automaticamente. |
| Autorizar responsável | Selecionar criança/contexto → selecionar responsáveis → conceder acessos. | Somente selecionados veem o contexto. |
| Trocar papel | Abrir seletor → escolher vínculo → atualizar sessão lógica. | Ações e dados mudam imediatamente. |
| Recuperar conta | Solicitar por e-mail/celular → verificar → redefinir/acessar. | Fluxo não enumera contas. |

# 15. Requisitos funcionais

| ID | Área | Requisito |
| --- | --- | --- |
| AU-RF-001 | Pessoa | Manter pessoa global independente de Auth. |
| AU-RF-002 | Login | Permitir e-mail ou celular conforme escolha. |
| AU-RF-003 | Identificador | Criar `@identificador` único para adultos, instituições e unidades; criança não depende dele no MVP. |
| AU-RF-004 | Referência infantil | Permitir código/QR privado sem conceder acesso ou expor diretório infantil. |
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

- Criança não pode ser exposta em APIs públicas de pesquisa; eventual
  identificador infantil futuro segue a mesma restrição.

# 20. Requisitos não funcionais

| Categoria | Requisito |
| --- | --- |
| Segurança | Deny-by-default, RLS e validação server-side. |
| Privacidade | Minimização, mascaramento e ausência de diretório infantil; referências privadas não concedem acesso. |
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

- Criança não é localizável em diretório ou busca pública.

- Responsável localiza exatamente instituição/unidade e inicia solicitação sem
  receber dados privados além do perfil institucional mínimo.

- A solicitação não concede acesso antes da validação institucional.

- A aprovação cria primeiro o vínculo criança–unidade; turma pode ser definida
  depois.

- Responsável não selecionado para um contexto não vê a criança naquela instituição.

- Tentativa de acesso cruzado por ID/URL é negada pela RLS.

- Service role não aparece em código cliente.

# 22. Riscos e mitigação

| Risco | Impacto | Mitigação |
| --- | --- | --- |
| Identificador infantil futuro | Crítico | Fora do MVP; spec própria, não indexação e validação institucional antes de qualquer uso. |
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
| @username crianças | Não necessário no MVP; decisão futura ligada à experiência e ao login infantil. |
| Pessoa | Global. |
| Auth | Credencial opcional; criança não possui no MVP. |
| Papel | Contextual. |
| Criança multi-instituição | Uma pessoa global com `child_context` pertencente a cada instituição, `child_unit_link` inicial e `child_group_link` opcional posterior. |
| Responsável | Acesso selecionado por contexto institucional. |
| Alterar permissões Admin | Owner/diretor e admins autorizados. |
| MFA | Ainda não definida como requisito do MVP. |

# 24. Perguntas em aberto

- Senha, OTP ou ambos em cada canal?

- Identificador e edição de perfil infantil permanecem adiados para a spec de
  experiência/login infantil; não fazem parte do onboarding do MVP.

- Quais flags de permissão familiar existirão no MVP?

- Qual política de bloqueio e recuperação para CPF já vinculado?

- MFA será obrigatória para Superadmin e direção antes do piloto?

# 25. Próximas specs

- Technical Spec do schema de people, identities, memberships e contextos.

- Technical Spec de policies RLS e funções auxiliares.

- Functional Spec de login, convite, recuperação e seletor de contexto.

- Threat model de eventual identificador infantil e deduplicação, se adotado
  pela spec futura de experiência/login infantil.

- Test Plan de dois tenants, multi-papel e vínculos familiares.

# 26. Aditivo 2026-06-23 - MFA do Owner Coelo

Este aditivo registra uma decisao especifica do Superadmin Completo v1: MFA e obrigatoria para o Owner Coelo no login e em acoes sensiveis. A criacao de novos Owners deve ocorrer por convite aceito + MFA configurada.

A obrigatoriedade de MFA para Operations, Support, Content, Auditor, Admin institucional, direcao e outros perfis privilegiados permanece em aberto e deve ser definida por papel e risco em Technical Spec propria.

Esta decisao atualiza parcialmente a pergunta aberta de MFA sem encerrar a politica geral de autenticacao reforcada.

# 27. Aditivo 2026-07-24 — Autorização Contextual

## 27.1 Identidade E Experiência

Uma pessoa pode ser simultaneamente responsável e profissional. A identidade é única, mas a experiência e a autorização são calculadas por contexto. O app deve separar claramente a atuação familiar da atuação profissional e nunca usar a experiência selecionada como única barreira de segurança.

Crianças não possuem login no MVP. O modelo deve permitir que a pessoa da criança receba identidade de autenticação no futuro sem recriar seus vínculos.

Adulto pode criar conta global antes de qualquer instituição, e instituição ou
unidade pode convidar conta nova ou existente. Conta, e-mail ou
`@identificador` não concedem acesso por si mesmos. Responsável autenticado
pode localizar exatamente instituição/unidade por `@`, e-mail, link ou QR e
solicitar vínculo; a solicitação fica sem acesso até validação institucional.

O cadastro infantil é híbrido. Responsável ou instituição inicia, a instituição
valida e cria seu `child_context`; a aprovação cria primeiro o
`child_unit_link`, e o `child_group_link` é opcional naquele momento.

## 27.2 Cálculo De Permissão

A decisão server-side deve avaliar:

`tenant ativo + membership ativo + papel/grant + escopo + vínculo contextual + ausência de negação explícita`

- Negação explícita da pessoa prevalece sobre concessões.
- Escopo descendente inclui somente filhos hierárquicos, nunca unidades irmãs.
- Professor vinculado apenas a uma atividade e turma não recebe acesso ao restante do grupo.
- Override de atividade não pode conceder acesso fora do vínculo que o contém.
- Vínculo direto com criança não amplia automaticamente o acesso às demais crianças do grupo.
- Toda operação sensível deve revalidar o contexto no banco, mesmo que a UI oculte a ação.

## 27.3 Responsáveis E Pessoas Autorizadas

- Instituição ou unidade emite convite de responsável com login, sem impedir
  pré-cadastro adulto ou solicitação de vínculo iniciada pelo responsável.
- Permissões familiares são definidas por responsável e criança, inicialmente permitidas e editáveis durante ou depois do convite.
- Apenas o responsável com `manage_authorized_people` pode consultar pessoas
  de confiança ou alterar autorizações daquela criança.
- Pessoa de confiança é um registro privado e reutilizável do responsável e
  não recebe sessão autenticada por esse vínculo.
- Cada uso da pessoa de confiança cria autorização independente por
  instituição, `child_context` e unidade; autorização de retirada não pertence
  à turma.
- Cadastrar autorização produz efeito imediato e notifica apenas o contexto
  institucional afetado.
- Instituição ou unidade pode suspender uma autorização por segurança,
  informando motivo e notificando os responsáveis autorizados, sem alterar
  status ou visibilidade em outra unidade ou tenant.

## 27.4 Profissionais

- Papéis padrão e customizados podem ter escopo institucional, de unidade, grupo, atividade ou criança.
- Um administrador de unidade pode ter todas as turmas ou somente seleção explícita.
- Pessoas que falam pela instituição, unidade, grupo ou atividade devem exibir a pessoa real e o papel contextual.
- Acesso à lista de crianças, responsáveis, pessoas de confiança ou
  autorizações exige permissão explícita; ausência de permissão significa
  ausência da lista.

## 27.5 RLS E Estado Atual

A fundação operacional foi aplicada ao projeto remoto em 2026-07-24. O helper
`app_private.has_context_permission(...)` combina membership ativo,
assignments/permissões, grants diretos, escopo e overrides individuais. Deny
explícito prevalece e escopo de unidade não alcança unidade irmã.

As 30 tabelas contextuais novas possuem RLS e policies por operação, grants
explícitos para `authenticated` e nenhum grant para `anon`. Comandos sensíveis
usam RPCs transacionais, funções privilegiadas em `app_private` com
`search_path = ''` e auditoria. Testes remotos cobrem deny individual,
isolamento de unidade/tenant, atividades, chat histórico e assiduidade.

A caixa `Conversas` deve ser apenas uma query agregada sobre registros
contextuais independentes. Filtros de tipo e criança nunca formam escopo
compartilhado nem ampliam RLS. Toda leitura e operação deve revalidar
dinamicamente membership, vínculo infantil, equipe e capacidade; ocultar ou
desativar participante no cliente não basta para revogar acesso.

A fundação aplicada ainda requer consolidação da fonte privada reutilizável da
pessoa de confiança e da revogação dinâmica de chat. Nenhuma migration ou
alteração de policy é autorizada por este aditivo sem plano técnico aprovado.

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
