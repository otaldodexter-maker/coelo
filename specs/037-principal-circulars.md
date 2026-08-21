---
title: "Circulares privadas e versionadas no Principal"
source: "PRDs App, Auth Multi-tenant, Permissões, LGPD/Segurança/Mídia e Modelo de Dados; referência visual aprovada em 2026-08-21"
status: approved
generated_at: "2026-08-21"
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

Por decisão explícita do Owner em 2026-08-21, Circulares usa o bucket privado
Supabase `coelo-circulars-private` conforme ADR 0027. A exceção é exclusiva de
Circulares e não altera Acontece, Agora ou Momentos.

Upload e leitura passam por Edge Function autenticada: intenção autorizada,
caminho opaco gerado no servidor, upload assinado, validação de extensão, MIME,
assinatura real, tamanho e checksum, finalização idempotente e URL de leitura de
120 segundos. O token nativo de upload assinado do Supabase expira em duas
horas; a UI não o persiste, o objeto usa chave opaca exclusiva e a finalização
server-side usa ticket adicional de dois minutos. Metadados, ownership, estado
e auditoria ficam no Postgres.

## UX e estados

Perfil usa as abas transparentes `Acontece | Momentos | Circulares | Sobre`,
com underline laranja e rolagem horizontal acessível. O card no Acontece mostra
identificação, título, trecho, contagens e estado de resposta, abrindo o detalhe.

O editor reutiliza a anatomia do Publicar no Acontece: 375 px usa fluxo vertical
e alternância de prévia; 768 px alterna quando as constraints não comportarem
dois painéis; 1024/1440 px usam editor central e prévia lateral. Só publicar ou
agendar usa laranja preenchido.

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
- testes Deno cobrem validação e gateway de Storage privado.
