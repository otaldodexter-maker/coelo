---
title: "Circulares privadas e versionadas no Principal"
source: "PRDs App, Auth Multi-tenant, Permissões, LGPD/Segurança/Mídia e Modelo de Dados; referência visual aprovada em 2026-08-21"
status: approved
generated_at: "2026-08-21"
updated_at: "2026-09-09"
---

# Circulares privadas e versionadas no Principal

## Objetivo e problema

Circulares são comunicações institucionais privadas, formais e mais extensas que
posts do Acontece. Devem reunir conteúdo, até quatro anexos e perguntas simples,
sem virar popup, formulário completo ou duplicação física de post.

## Escopo

- título obrigatório de até 120 caracteres e texto total de até 10.000;
- blocos ordenados de texto, mídia e pergunta;
- JPEG, PNG e WebP até 10 MiB, MP4 até 25 MiB e PDF até 5 MiB;
- até quatro arquivos, dez perguntas e duas a dez alternativas por pergunta;
- escolha única ou múltipla, pergunta obrigatória/opcional, ordenação,
  duplicação e exclusão;
- rascunho, agendamento, publicação, revisão, encerramento de respostas e
  exclusão lógica quando existir histórico;
- aba `Circulares` do Perfil, detalhe próprio e projeção autorizada no Acontece.

Ficam fora de escopo lógica condicional, pontuação, resposta dissertativa,
upload como resposta, matriz, ramificações e relatórios avançados.

## Domínio e dados

`circulars` é o agregado. O conteúdo fica em `circular_revisions`, com blocos,
perguntas e alternativas normalizados. Revisões publicadas são imutáveis; uma
correção cria nova revisão, preserva `published_at`, registra `revised_at` e
exige novas respostas. Respostas e suas revisões permanecem vinculadas à revisão
respondida e nunca compartilham tabela com comentários.

Políticas de unidade de resposta:

- `per_person`;
- `per_child_any_guardian`, compartilhada entre responsáveis autorizados;
- `per_child_each_guardian`;
- `per_staff_member`.

Prazo de resposta é opcional e o encerramento manual é auditado. Rascunho com
alguma resposta é parcial; envio completo é respondido. Concorrência usa versão
otimista e conflito não sobrescreve a resposta existente.

## Público, tenant e permissões

Audiências permitidas são famílias, responsáveis, estudantes e equipe nos
escopos instituição, unidade, turma/grupo e atividade. Toda operação valida no
backend ator, pessoa, membership ativo, tenant, instituição, hierarquia,
capacidade, audiência, vínculo familiar e estado.

Capacidades: `circulars.circulars.create`, `publish`, `read`, `respond` e
`manage`. Tabelas expostas usam RLS forçada e deny-by-default, sem mutação direta
do cliente. RPCs e projeções não revelam existência fora do escopo autorizado.

## Mídia privada

Pela decisão do Owner de 2026-09-03, registrada na ADR 0032, toda mídia nova
de Circulares usa a plataforma R2 privada comum do MVP. A exceção Supabase da
ADR 0027 está superada. Imagens e masters de vídeo pertencem a
`coelo-media-prod`, documentos como PDF a `coelo-documents-prod` e uploads ainda
não finalizados/quarentena a `coelo-transient-prod`, conforme a finalidade.
Nenhum desses buckets é público; Circulares não cria bucket próprio.

Upload e leitura passam pelo Media Gateway server-side, inicialmente Edge
Function Supabase. O gateway valida sessão, tenant, capacidade e audiência,
emite chave opaca segundo a hierarquia comum da ADR 0032 e presigned PUT/GET
curto, finaliza de forma idempotente, limpa órfãos e audita. A chave nunca
autoriza acesso. MIME real, bytes, dimensões/pixels quando aplicável, checksum
e limites por finalidade são validados no servidor. PDF também exige validação
de assinatura, estrutura, conteúdo ativo e malware; viewer e download são
reautorizados. O limite específico de PDF desta spec permanece em 5 MiB.

Postgres é o catálogo autoritativo de ativos, variantes, vínculos, ownership,
permissões, retenção e auditoria. O master permanece no R2; PDF nunca usa
Stream. Nenhuma credencial R2 ou `service_role` entra no cliente. Os prazos do
token de upload Supabase da regra anterior não definem o contrato R2: sua
entrega segue o gateway comum da ADR 0032, sem presumir TTL específico aqui.

## UX e estados

O diretório administrativo foi aprovado visualmente em 2026-08-31. Mobile usa
tile de criação seguido por cards compactos; tablet e desktop usam faixa de
criação seguida pela tabela canônica de Instituições. Não existe botão laranja
isolado no topo nem alternância manual de visualização. Busca, filtros, tabs,
status e paginação reutilizam os componentes e a geometria de Instituições. As
tabs são `Todas`, `Rascunhos`, `Agendadas`, `Publicadas` e `Encerradas`.

Perfil usa as abas transparentes `Acontece | Momentos | Circulares | Sobre`,
com underline laranja e rolagem horizontal acessível. O card no Acontece mostra
identificação, título, trecho, contagens e estado de resposta, abrindo o detalhe.
O contrato visual dessas duas projeções foi aprovado em 2026-08-31. No web, a
prévia de como a Circular aparece no Acontece não ocupa coluna lateral nem nasce
aberta: uma ação explícita abre a prévia em popup contextual, devolvendo a
largura principal ao Perfil. O popup usa superfície neutra, barreira, corpo
rolável e fechamento acessível conforme o contrato Coelo de overlays.
Esclarecimento do Owner de 09/09/2026: quando hospedado no Superadmin, o detalhe
preserva o shell/menu no web e no mobile e ocupa sua área de conteúdo, com
retorno contextual `‹ Circular`. A regra antiga de fullscreen sem cabeçalho
ou dock global não autoriza ocultar o shell do Superadmin no compacto; esta
restrição é específica desse hospedeiro. Fechar ou usar Escape devolve foco ao
gatilho e preserva o ponto de origem. Esta regra
não altera o preview lateral aprovado dos composers de publicação.

O editor pertence ao fluxo de publicação do Principal, ao lado de Publicar no
Acontece, Agora e Momentos; não reutiliza wizard administrativo do Superadmin.
Em 375 px usa fluxo vertical e prévia contextual; em 768 px preserva o formulário
linear; em 1024/1440 px usa editor central e prévia lateral. O desktop preserva
o shell canônico, o contêiner direito arredondado e seus insets. O rodapé segue
a geometria de Criar/Editar Instituição: cancelar no extremo esquerdo e ações de
continuidade/publicação no direito; no compacto, a primária vem primeiro em
largura total. Só publicar ou agendar usa laranja preenchido.

Estados exigidos: carregando, vazio, erro, offline, não autorizado, salvando,
salvo, falha, upload parcial, arquivo inválido, agendada, publicada, encerrada,
resposta parcial, respondida, conflito e limites excedidos.

## Critérios e testes

- Circular aparece uma vez no feed misto, ordenado por publicação efetiva;
- o limite SQL/Dart/UI do Acontece continua em 2.200 caracteres;
- perguntas, revisões e respostas preservam significado e auditoria;
- nenhuma mídia ou resposta possui acesso público;
- testes Dart cobrem domínio, codec, repositories, widgets e 375/768/1024/1440;
- pgTAP cobre constraints, grants, RLS, capacidades, idempotência, cross-tenant,
  cross-context e IDOR/BOLA;
- testes Deno cobrem validação, finalização idempotente e gateway R2 privado,
  incluindo negativas cross-tenant, IDOR, sessão revogada e entrega expirada.
