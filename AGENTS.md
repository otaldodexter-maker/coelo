# Coelo Master Agent

Este arquivo e o contexto principal do projeto Coelo. Ele nao cria um agente por PRD; ele define como qualquer colaborador ou agente deve ler, decidir, documentar e implementar o projeto quando uma spec futura for aprovada.

## Visao Do Produto

Coelo e um superapp privado de rotina, comunicacao e cuidado entre instituicoes, familias, responsaveis e alunos. O produto centraliza comunicacao escolar/institucional, agenda, rotina, Flow, Now, Moments, chat, notificacoes e contexto familiar com privacidade, confianca e clareza.

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

`service_role` e qualquer segredo equivalente nunca podem aparecer no cliente, em apps Flutter ou no site publico. Midia privada do produto deve usar Cloudflare R2 como destino unico desde o MVP, com Postgres/Supabase guardando metadados, permissoes, vinculos, ownership e trilha de auditoria. Antes da implementacao, deve existir spike tecnico de R2.

Dados pessoais, dados de criancas, CPF, midias, mensagens e logs devem respeitar LGPD, minimizacao, base legal, retencao definida, rastreabilidade e melhor interesse da crianca. Lacunas juridicas devem ficar abertas ate decisao formal.

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
