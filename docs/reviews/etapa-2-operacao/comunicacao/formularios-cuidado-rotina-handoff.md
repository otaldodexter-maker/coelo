---
title: "Handoff — grupo formularios-cuidado-rotina, Rodada 3"
source: "Execução do grupo em 2026-09-10; comunicacao/formularios-cuidado-rotina.json revisões 1 a 20"
status: "entregue"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# Handoff — formularios-cuidado-rotina

Recorte: 43 ações das famílias `forms_authoring`, `forms_responses`,
`forms_files`, `health_care`, `medication`, `students`, `attendance` e
`daily_routine`.

## O que estava lá quando abri

Quatro das oito famílias **não tinham backend nenhum**. O rastreador anterior
descrevia isso como "9 objetos `app_private` faltando", o que sugere um reparo
pequeno; era outra coisa. `daily_routine`, `health_care`, `medication` e
`student_tracking` nunca tiveram tabela, capacidade nem RPC. O que existia eram
migrations de *lint* fazendo `CREATE OR REPLACE` de funções sobre tabelas que
nenhuma migration criava, e repositórios `/dev` no cliente.

E Formulários, que tinha 24 migrations e 16 arquivos pgTAP, **não podia ser
aplicado**: a primeira migration da família é PL/pgSQL inválido.

## O que entreguei

Backend novo, tudo com pgTAP próprio e aplicado em produção (confirmado no
ledger remoto por `supabase migration list --linked`):

| Pacote | O que faz |
| --- | --- |
| `20260910010000` + `010100` + `010500` | Fundação, comportamento e contrato de cliente da Rotina diária: 13 tabelas, 16 capacidades, 8 RPCs, RLS deny-by-default com FORCE |
| `20260910010200` | Assiduidade: fecha a escalada de privilégio da OQ-040 e move a chave de idempotência para o banco (D11) |
| `20260910010300` + `010400` | Perfis de cuidado e Planos de medicação: 8 tabelas, 5 capacidades, 7 RPCs |
| `20260910220000` | Leitura pelo responsável autorizado (D9, opção 1) |
| `20260910220100` | Revoga o drift de privilégios que produção acumulou em Formulários |
| `20260910220200` | Alunos: vincular, transferir, editar e revogar |

Cliente: repositórios Supabase de Rotina, Perfis de cuidado, Planos de
medicação e Alunos; a troca dos quatro sítios de escrita de Assiduidade para a
chave do servidor; a tela mínima de Lançamentos (D7); a rota Testar por
capacidade (D6); e o alinhamento do wizard de cuidado ao padrão administrativo.

Duas chaves de composição, ambas nascidas desligadas porque o SQL ainda não
estava aplicado: `careAndRoutineBackendEnabled` e `studentLinkCommandsEnabled`.

## Provas

- **pgTAP: 1037 asserções, zero falhas**, em 24 arquivos, sobre a baseline real
  de produção mais a fila de Formulários. As medições anteriores (56, 90, 1001,
  1021) foram sobre um replay reconstruído da cadeia histórica; quando a
  baseline saiu, refiz tudo sobre ela, que é a base verdadeira.
- **Flutter: 225** nas suítes que escrevi ou alterei. `dart analyze lib` limpo.
- Nada disso é prova ponta a ponta. Nenhuma tela abriu contra produção.

## Achados que valem para outras frentes

1. **A cadeia canônica não replica do zero.** `module_label` é NOT NULL sem
   default desde `20260811215451`, e migrations posteriores inserem permissões
   sem passá-lo. Existe um remendo em `replay/` que só o script de replay
   injeta.
2. **O perfil `FoundationOnly` está quebrado**: o manifesto inclui
   `superadmin_internal_chat_v2`, cuja dependência `20260812000000` não está no
   manifesto. Quem tentar pgTAP local pelo caminho suportado falha *antes* das
   migrations do próprio pacote e lê como defeito próprio.
3. **Objetos referenciados e nunca criados não são só da minha família**:
   `app_private.unit_import_source_attestations`, em Importações, é o mesmo
   padrão.
4. **Dependência cruzada em Formulários**: as quatro migrations de autoria de
   08/09 falham sem duas migrations de Estrutura antes, porque exigem o
   envelope `SAI_INVALID_ARGUMENT`.
5. **Drift de privilégio em produção**: as tabelas expostas de Formulários
   tinham INSERT/UPDATE/DELETE/TRUNCATE para `anon` e `authenticated`. Estava
   inerte porque RLS está ligado e forçado com zero policies, mas a proteção
   inteira se apoiava na ausência de policy. O coordenador achou o mesmo padrão
   em 204 tabelas.
6. **Colisão de carimbo** entre grupos: `20260910120000` aparece duas vezes,
   entre meal_plans e circulares. Não é minha e não toquei.

## Erros meus, e como apareceram

- **Afirmei que Formulários nunca fora aplicado em lugar nenhum.** O
  diagnóstico do defeito estava certo; a conclusão sobre produção, errada.
  Produção tinha a função corrigida e o repositório é que divergira. Só
  apareceu quando a baseline de produção foi publicada. Realinhei o arquivo ao
  texto exato de produção, não à minha versão.
- **Meu primeiro digest de idempotência de Assiduidade não descrevia a
  chamada.** Duas chamadas diferentes do mesmo profissional teriam recebido a
  mesma chave, que é pior do que não ter chave. Quem pegou foram dois testes
  Dart que já provavam essa semântica no cliente: eu movi a chave para o banco
  e perdi a intenção no caminho.
- **Três carimbos meus colidiram** com pacotes de outros grupos. O coordenador
  apontou dois; conferindo a pasta inteira achei o terceiro.
- `min(uuid)`, `UNIQUE` com expressão, e wrappers `SECURITY INVOKER` sem
  alcance à função definer: três defeitos que só a execução revelou.

## O que fica aberto

| Item | Estado | Quem desbloqueia |
| --- | --- | --- |
| `medication_form_mobile_light` = R | Não aplicado | Owner. R desfaria a regra RODAPÉ nesta tela e a afastaria do golden aprovado de Criar instituição, que ancora o rodapé do mesmo jeito. Pergunta e proposta no JSON. |
| `forms.location-question` e `forms.location-answer` | Bloqueadas por escopo | Owner. A política está decidida e gravada na spec, mas o tipo `location` não existe e a própria spec lista localização como fora do MVP. |
| Caso obrigatório sem alternativa válida em Local | Aberto | Owner. A opção 2 obriga um local atual; nesse caso não existe nenhum. |
| Tela de gestão de aluno | Entregue, parcial | A rota deixou de abrir indisponível: mostra unidades, turmas e vigência, e oferece revogar com motivo. Vincular, transferir e editar têm comando, contrato e repositório provados, mas ainda não têm seletor de unidade e turma na tela — dependem de uma leitura de unidades e turmas do escopo que não é minha. |
| `forms_files` ponta a ponta | Espera Cloudflare | Coordenador. O pacote R2 é dele. |
| Ligar as duas chaves de composição | Precondição atendida | Coordenador. O SQL está em produção; pelo contrato quem liga é ele. |

## Próximo gate

Ligar as duas chaves de composição e provar a rota normal contra produção por
`action_id`: rota abre, CRUD persiste, reload mantém. Combinado com a
coordenação que eu escrevo só dado sintético meu e apago o que criar na mesma
sessão.

Parei às 17:10 por ordem do Owner e não retomo por conta própria.

## Base

Branch `work/etapa2-r03-formularios-cuidado-rotina`, rebaseada em `dev`
`347d4cf8a`. Sem WIP retido: tudo commitado e publicado.
