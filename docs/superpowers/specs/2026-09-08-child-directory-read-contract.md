---
title: "CHILD-READ01 — contrato nominal do diretório infantil"
source: "direção técnica da coordenação em 2026-09-08; proposta fd8e3356; specs039/046; ADR0019 vigente"
status: "candidate-for-review-before-sql-or-wiring"
generated_at: "2026-09-08"
---

# Recorte

Uma linha por child_context institucional ativo, com IDs de pessoa e contexto
separados. Só diretório mínimo; detalhe046, sua bridge de primeiro caminho,
hierarquia completa, PII adicional, responsáveis, novos papéis, comandos,
assiduidade/E5 e cuidado/E4 permanecem fora. Sem SQL ou wiring nesta preparação.

## Autorização e seleção server-side propostas

Reutilizar people.read, identidade interna039, papel Owner e escopos
platform/institution. Aplicar política AAL vigente, sem restaurar AAL2 legado.
Não criar capability/grant. Preflight verifica schema, helpers e matriz nominal
de people.read e recusa drift; o vetor físico exato deve ser fechado com prova
de catálogo no pacote SQL, sem presumir configuração histórica como atual.

Selecionar somente contexto ativo, pessoa type=child não excluída e instituição
não excluída. A instituição é derivada de child_contexts e conferida contra o
escopo do ator antes de paginação. Filtro institucional opcional restringe
resultado, nunca concede autorização; escopo institution não aceita outro ID.
Unidade/grupo não participam da projeção nem são exigidos para uma criança ainda
sem alocação. Não deduzir ausência de vínculos a partir desta projeção mínima.

## Interface nominal candidata

`superadmin_child_context_directory_v2(p_institution_id uuid default null,
p_after_name text default null,p_after_context_id uuid default null,
p_limit integer default 20)` retorna envelope interno039.

IDs de cursor e nome são ambos nulos ou ambos presentes. Limite inteiro1–50.
Não há busca/filtros adicionais, offset ou total nesta fatia. UUIDs e parâmetros
são não confiáveis. Busca fica expressamente fora desta primeira fatia; o
diretório completo não será declarado concluído por este reader.
O orçamento de transporte candidato de p_after_name é 8192 bytes UTF-8,
reutilizando o teto de filtros do reader interno institucional
20260827235500_superadmin_internal_institution_list_filter.sql:166.
people.display_name é text sem teto cadastral na fundação; 8192 não é novo limite
de cadastro. O servidor valida octet_length antes de consultar. Se o cursor
de saída exceder o orçamento, falha segura, sem truncar nome, pular linha ou
fingir última página; suporte a esse caso exige revisão de transporte posterior.
Cursor adulterado só muda a posição dentro do conjunto já
autorizado: não resolver dados do cursor fora do escopo nem revelar sua existência.

Ordenar por `lower(people.display_name) COLLATE "C", child_contexts.id` e usar
predicado lexicográfico estrito maior que os dois valores do cursor. Buscar
limit+1 após autorização; retornar no máximo limit itens. next_cursor só existe
se há excedente e representa o último item retornado, nunca o item excedente.
Nome de cursor é exatamente o lower calculado pelo Postgres. Dart não recalcula
lower nem compara collation PostgreSQL. Reload sem cursor começa outra leitura.
Não prometer snapshot entre páginas: renomeações concorrentes podem reposicionar
linhas; revalidar sempre. Troca de contexto/filtro exige reinício do cursor.

## Shape exato

Sucesso: `{ok:true,data:{items:[...],next_cursor:null|{name,context_id}},error:null}`.
Item exato: `{context_id,person_id,person_name,institution_id,institution_name}`.
IDs são UUID; nomes são strings não vazias sem controles ou surrogate inválido.
Não truncar silenciosamente nomes existentes nem inventar novo limite cadastral.
Nenhum status constante, local_identifier, datas, Auth, unidade/grupo, responsável
ou total adicional é projetado. Cursor contém somente name/context_id; nome já
corresponde a item autorizado. Não colocar cursor em audit/logs/URL pública.

Erro exato039: ok=false,data=null,error={code,message,correlation_id,http_status}.
Cliente verifica context_id do cursor contra o último item, não equivalência
de lower(name) por Dart; o nome é opaco e calculado pelo servidor.
Cliente aceita só shape e tipos contratados, rejeita IDs duplicados, quantidade
acima do limite, instituição divergente do filtro e cursor fora da última linha.
Página vazia ou curta não pode fornecer next_cursor. Cursor idêntico ao de
entrada é recusado por falta de avanço;
isso compara apenas igualdade opaca, não ordenação/normalização do Postgres.
Não usar DTO como prova de autorização. Nome/cursor desconhecido não é copiado
para mensagens de erro.

## Segurança, auditoria e execução futura

SQL nominal futuro: SECURITY DEFINER, owner postgres, search_path vazio,
EXECUTE somente authenticated, helpers privados sem grants cliente. Identidade,
sessão, capacidade, escopo e catálogo revalidados em cada chamada, autorização
e projeção coerentes sob concorrência e após esperas. Sem OR com realm legado.
Auditar ação candidata child_context.directory, capability people.read, resultado
e correlação; sem nomes/cursor/payload. Falha de auditoria não retorna dados.
Negativas cross-scope/ID adulterado não enumeram tenants; sem auditoria fabricada
para sessão inválida. Não alterar policies/tabelas legadas nesta fatia.

## Testes e critério de parada

DTO/requests: defaults20, limites1/50 e negativos, cursor pareado, shape exato,
IDs únicos, mesma pessoa em dois contextos permitida, filtro institucional,
pagina vazia/curta/completa, cursor último item, erros seguros e imutabilidade.
SQL futuro: nomes iguais e UUID tie-break, case/acentos, limit+1, cursor forjado,
contexto A/B, platform/institution, criança sem unidade, tipo adulto/service,
contexto inativo, pessoa/instituição excluída, sessão/revogação/deny, concorrência,
auditoria/rollback, ACL e reload. Sem total ou PII além da allowlist.

Preparo termina com DTO/testes locais e revisão deste contrato. Gate seguinte é
aprovação nominal antes de qualquer SQL/wiring; não equivale a implementação do
diretório produtivo nem E2E. Rastreadores centrais permanecem com a coordenação.
Estimativa de preparo45–90min; ETA E2E depende de replay/integração autorizados.
O checkpoint03:20 exige entrega do ponto seguro então; a estimativa não autoriza
ultrapassá-lo sem o repasse solicitado.
