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

`service_role` e qualquer segredo equivalente nunca podem aparecer no cliente, em apps Flutter ou no site publico. Durante o MVP, fotos de perfil, identidade e conteudo operacional usam Supabase Storage privado. Cloudflare R2 fica somente como evolucao a ser perguntada ao Owner no encerramento formal do MVP e nao bloqueia a Etapa 2. Postgres/Supabase guarda metadados, permissoes, vinculos, ownership e trilha de auditoria. As ADRs 0030 e 0031 nao autorizam bucket publico nem segredo no Flutter.

Importacao e exportacao reais ficam adiadas para depois do MVP. Os botoes permanecem visiveis nas telas aplicaveis, com indisponibilidade honesta e sem picker, parser, job, arquivo, RPC ou persistencia. A excecao e `forms.export`: cada resposta individual de Formulario deve possuir exportacao real no MVP, sem configuracao adicional, usando CSV/XLSX e ZIP quando houver midia, com Supabase Storage privado, reautorizacao server-side, expiracao e auditoria. Exportacao consolidada de varias respostas continua adiada. No encerramento formal do MVP, perguntar ao Owner se deseja implementar as demais acoes.

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

Escolha a skill e os rastreadores conforme o pedido:

- Flutter/Dart: use `.agents/skills/coelo-flutter-review/SKILL.md` e leia
  integralmente `docs/reviews/coelo-flutter-pendencias.md`.
- Supabase/backend: use `.agents/skills/coelo-supabase/SKILL.md` e leia
  integralmente `docs/reviews/coelo-supabase-pendencias.md`.
- Flutter integrado ao Supabase ou conclusao ponta a ponta: use
  `.agents/skills/coelo-flutter-supabase-review/SKILL.md` e leia integralmente os
  tres rastreadores, terminando por
  `docs/reviews/coelo-flutter-integrado-supabase-pendencias.md`.

`coelo-ui` permanece a autoridade visual em qualquer revisao Flutter. Atualize
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
