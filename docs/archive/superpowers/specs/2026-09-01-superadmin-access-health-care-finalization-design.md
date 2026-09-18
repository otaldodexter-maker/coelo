---
title: "Finalização de Acessos e Saúde e Cuidado no Superadmin"
source: "Solicitação e decisões aprovadas pelo usuário em 2026-09-01; anexos 1–13; specs/018-profiles-permissions-superadmin.md; specs/019-superadmin-people-directory.md; specs/020-superadmin-health-care.md; specs/023-superadmin-internal-users-local-preview.md; specs/030-superadmin-child-safety-production.md; docs/product/prd-admin.md; docs/product/prd-app.md"
status: "approved-for-implementation"
generated_at: "2026-09-01"
supersedes: "As regras incompatíveis de catálogo somente leitura do Principal e de separação de navegação entre Perfis e Modelos em specs/018-profiles-permissions-superadmin.md"
---

# Finalização de Acessos e Saúde e Cuidado no Superadmin

## Objetivo

Finalizar ponta a ponta as superfícies de Pessoas, Segurança da criança,
Usuários internos, Perfis de acesso, Modelos de perfil, Perfis de cuidado e
Planos de medicação. A mesma composição visual atende `/dev` com dados locais
determinísticos e as rotas normais com Supabase, sem permitir que fixtures
alcancem produção.

O recorte possui orçamento de quatro horas. A validação deve ser proporcional
ao risco e concentrada nos contratos alterados, sem substituir evidência
integrada por mock, tela aberta, `local-green` ou teste isolado.

## Escopo

- corrigir os problemas visuais e de interação registrados nos anexos 1–13;
- alinhar diretórios, cards, tabelas, toolbars e paginação ao padrão de
  Instituições;
- alinhar criar e editar ao wizard de Instituições;
- oferecer Arquivos com Importar e Exportar nas sete listagens;
- fazer busca, filtros, seleção e paginação funcionarem em `/dev`;
- compartilhar a hierarquia fake de instituições, unidades e turmas com a
  entrega `Finalização de Telas Estruturas`;
- conectar as rotas normais a contratos reais Supabase;
- preservar RLS deny-by-default, autorização contextual e auditoria;
- consolidar Perfis e Modelos como duas visões de uma mesma área;
- registrar evidências e pendências nos três rastreadores de revisão.

## Fora de escopo

- reconstruir Admin ou Principal executáveis neste recorte;
- implementar importação ou exportação sem contrato de backend aprovado;
- simular sucesso de operação indisponível;
- decidir regras clínicas ou jurídicas de administração de medicamento que
  permaneçam formalmente abertas;
- alterar módulos não listados, exceto componentes compartilhados necessários
  ao padrão visual aprovado;
- criar outro dataset estrutural concorrente.

## Contrato visual compartilhado

Todas as listagens usam a composição de Instituições:

- busca funcional, filtros e alternância entre cards e tabela;
- criar no primeiro espaço à esquerda nos cards e acima da tabela, à esquerda;
- menu Arquivos com Importar e Exportar;
- tabela redimensionável compartilhada, sem tabela privada improvisada;
- seleção individual e seleção de todos os itens da página;
- cards e linhas com affordance e semântica de navegação;
- paginação numerada compartilhada no rodapé;
- loading, vazio inicial, nenhum resultado, erro, sem permissão e conteúdo;
- hover, foco, teclado, contraste e toque segundo o Design System.

Itens de Arquivos sem contrato funcional ficam desabilitados e explicam o
motivo. A interface nunca anuncia conclusão de uma operação que não ocorreu.

Criar e editar usam `SuperadminFormStepNavigation`, campos Coelo e
`SuperadminFormActionFooter`. A última etapa é Revisão; não existe detalhe
intermediário obrigatório antes de editar.

## Comportamento por superfície

### Pessoas

- cards e linhas abrem diretamente a edição;
- pessoa permanece global e seus papéis/vínculos permanecem contextuais;
- criança, responsável e equipe são visões do mesmo diretório, sem duplicação;
- criar/editar inclui identidade, contatos/endereço, vínculos e revisão;
- endereço apresenta mapa compacto sincronizado com CEP/endereço;
- ações: visualizar, criar, editar, gerenciar vínculos, convidar, importar e
  exportar.

### Segurança da criança

- o bloco Criar segurança possui a mesma largura e altura dos cards;
- a tabela não contém botão Cadastrar pessoa; a criação fica na faixa acima;
- cards e linhas abrem diretamente a edição da segurança;
- wizard: criança, pessoas autorizadas, validade/capacidades e revisão;
- aprovar, rejeitar, suspender e consultar evidências são ações distintas e
  auditadas;
- busca, filtros de status, seleção e paginação operam sobre todo o dataset.

### Usuários internos

- cards e linhas abrem diretamente a edição;
- wizard: identidade, contato/trabalho/endereço, perfil/alcance e revisão;
- endereço apresenta o mesmo mapa compacto;
- seletores de instituição e unidade possuem busca, selecionar todos e resumo;
- o alcance usa instituições e unidades reais do dataset estrutural;
- convite, suspensão, escopo e MFA permanecem ações distintas.

### Perfis de acesso e Modelos

Há um único destino de navegação, **Perfis de acesso**, com abas **Perfis** e
**Modelos**. Modelos são bases reutilizáveis para iniciar perfis e nunca são
atribuídos diretamente a pessoas.

O editor possui as etapas:

1. identificação;
2. aplicativos e permissões;
3. limite máximo de alcance;
4. pessoas vinculadas, somente na edição;
5. revisão e motivo de auditoria.

A matriz é dinâmica e ordenada por aplicativo, módulo, tela e ação. Ela oferece
seleção total por aplicativo, módulo e tela. Ações herdadas, indisponíveis ou
não delegáveis ficam bloqueadas e apresentam o motivo. Nenhuma permissão é
inferida pelo Flutter a partir de rótulos.

### Perfis de cuidado

- listagem, arquivos, seleção e paginação seguem Instituições;
- card e linha abrem diretamente a edição;
- wizard: criança, alergias/restrições, orientações e revisão;
- identidade da criança é bloqueada somente durante edição;
- dados sensíveis deixam explícita a audiência autorizada.

### Planos de medicação

- listagem, arquivos, seleção e paginação seguem Instituições;
- wizard: criança/medicamento, vigência, horários/responsáveis,
  documento/evidência e revisão;
- datas, horários e demais inputs usam componentes Coelo sem sobreposição;
- aprovar, administrar, suspender e registrar evidência não são sinônimos de
  editar e exigem contratos próprios;
- `/dev` não simula administração real de medicamento.

## Mapa compacto

Pessoas e Usuários internos recebem um mapa compacto com OpenStreetMap,
marcador e atribuição visível. Em `/dev`, as coordenadas são determinísticas.
Na rota real, o mapa acompanha o endereço resolvido. Falha de geocodificação
mantém o formulário utilizável e informa que a posição precisa ser ajustada;
nenhuma coordenada é inventada.

## Modelo de autorização aprovado

Perfis podem selecionar ações de Superadmin, Admin e Principal. Aplicativo e
alcance são eixos diferentes:

- **aplicativo** define onde a ação existe;
- **permissão** define o que pode ser feito na tela;
- **teto de alcance** define o nível máximo permitido;
- **atribuição** define instituições, unidades e demais contextos concretos.

A permissão efetiva exige:

`ação + aplicativo + vínculo ativo + alcance atribuído + tenant + ausência de deny`

Um perfil com capacidade Admin não cria sozinho vínculo institucional. Um
perfil com capacidade Principal não cria sozinho relação responsável–criança.
Superadmin pode administrar os catálogos dos aplicativos inferiores sem que
isso conceda acesso operacional fora dos vínculos atribuídos.

### Ações comuns

O catálogo oferece apenas ações reais da tela. O núcleo inclui Visualizar,
Criar, Editar, Alterar status, Excluir, Gerenciar vínculos, Importar e Exportar.
Ações específicas permanecem explícitas, como Aprovar segurança, Publicar,
Confirmar leitura, Reagir, Fechar avaliação, Corrigir chamada, Gerenciar
audiência, Administrar medicamento e Consultar auditoria.

Importar e Exportar existem no Admin e Superadmin nas telas de gestão em que
fazem sentido. Eles não são inventados para visualizadores ou conversas
individuais.

### Catálogo inicial por aplicativo

- **Superadmin:** Estrutura, avaliações, acompanhamento, Acessos, Saúde e
  Cuidado, operação, comunicação e governança;
- **Admin:** instituição, estrutura, atividades, pessoas, equipe, responsáveis,
  perfis, importações, conteúdo, rotina, agenda, conversas, saúde e segurança;
- **Principal:** Acontece, Agora, Momentos, rotina, conversas, agenda, crianças
  e segurança, perfil/contexto e notificações.

Novas telas publicam metadados server-side de módulo, tela, ação, risco, MFA e
delegabilidade. O editor passa a exibi-las sem receber listas hard-coded.

## Dataset `/dev`

O dataset usa os IDs estruturais fornecidos pela entrega de Estruturas:

- 12 instituições com suas unidades e turmas;
- 180 crianças;
- aproximadamente 270 responsáveis distintos e cerca de 300 vínculos;
- predominância de uma ou duas pessoas responsáveis por criança;
- somente nove crianças com três ou quatro responsáveis;
- 54 responsáveis com segundo perfil contextual, aproximadamente 20%;
- 42 integrantes de equipe institucional;
- 164 crianças com segurança configurada: 126 autorizadas, 18 aguardando
  aprovação, 11 em atenção e nove sem autorização;
- 16 crianças ainda sem cadastro de segurança;
- perfis de cuidado e planos de medicação em distribuição coerente, sem
  medicalizar artificialmente todo o conjunto.

Nomes, relações, endereços, vínculos, instituições, unidades e turmas devem ser
semanticamente coerentes. IDs locais são estáveis entre reinicializações.

## Fluxo de dados

Em `/dev`, repositories locais compartilham um catálogo determinístico e
executam busca, filtros, ordenação, seleção e paginação em memória. As rotas
normais usam repositories Supabase e filtros/paginação server-side. Fixtures e
clientes produtivos nunca são escolhidos pelo mesmo ramo implícito.

Mutações sensíveis usam RPCs auditadas com ator derivado da sessão,
idempotência, versão esperada, motivo e MFA quando exigido. IDs, tenant e escopo
recebidos do cliente são revalidados no banco.

## Segurança e RLS

- RLS deny-by-default em toda tabela exposta;
- nenhum grant direto desnecessário a `anon` ou `authenticated`;
- funções `SECURITY DEFINER` privadas ou públicas com gateway mínimo,
  `search_path` seguro e autoridade revalidada;
- leitura e escrita confinadas por tenant, instituição, unidade, turma,
  criança e vínculo real;
- deny explícito prevalece;
- último Owner recuperável, redução de escopo e realocação permanecem
  protegidos transacionalmente;
- dados de saúde, criança, evidência e auditoria usam projeções mínimas;
- `service_role`, secrets e metadata mutável não participam do cliente.

## Erros e concorrência

- busca nova invalida resposta antiga;
- mudança de filtro retorna à primeira página;
- página vazia após mutação recua para a página válida anterior;
- conflito de versão preserva o rascunho e oferece recarregar;
- falha parcial de importação/exportação nunca altera registros silenciosamente;
- falta de permissão falha fechada e não entrega dados antes da autorização;
- retry é oferecido somente para operações idempotentes.

## Verificação e evidências

A verificação é focada:

- contrato visual compartilhado e analyzer dos arquivos alterados;
- widget tests de busca, filtros, cards/tabela, criar à esquerda, seleção total,
  clique direto em editar e paginação;
- testes dos wizards e do mapa em larguras representativas;
- testes unitários do dataset e dos vínculos estruturais;
- testes SQL de CRUD, grants, RLS, anti-escalation e cross-tenant nas migrations
  alteradas;
- smoke integrado em `/dev` e em uma sessão real autorizada quando disponível;
- atualização dos rastreadores Flutter, Supabase e integrado no mesmo turno.

## Critérios de aceite

- as sete listagens seguem Instituições e possuem Arquivos e paginação;
- buscas retornam dados fake coerentes e respeitam filtros/página;
- criar aparece sempre à esquerda;
- cards e linhas editáveis abrem edição diretamente;
- seleção total atua sobre a página atual e informa claramente seu alcance;
- Pessoas e Usuários internos exibem mapa funcional onde há endereço;
- Perfis e Modelos compartilham a mesma área e o catálogo aprovado;
- Admin inclui Importar e Exportar nas telas de gestão aplicáveis;
- `/dev` utiliza apenas fixtures e produção utiliza apenas Supabase;
- CRUD real respeita RLS, tenant, vínculo, escopo e auditoria;
- nenhum item bloqueado é apresentado como concluído ponta a ponta.
