---
title: "Conversas produtivas do Superadmin"
source: "Plano aprovado pelo produto em 2026-08-11; AGENTS.md; ADR 0010"
status: approved
generated_at: 2026-08-11
---

# Conversas produtivas do Superadmin

## Objetivo e escopo

Substituir o protótipo local de Conversas por inbox, thread, mensagens, não
lidas e metadados de anexos autorizados. A página não inventa conversas: uma
inbox vazia continua utilizável e encaminha a pessoa à ação permitida.

O launcher usa a baseline Home/Central de Ajuda e
`foundation.compact-shell-header-chat`: círculo até 600 px, cápsula laranja
acima disso, badge semântico e posição fixa na safe area. O arraste livre não
faz parte da experiência produtiva.

### Reuso na superfície Coelo (Principal)

`Coelo (Principal)` é uma superfície do menu de `apps/superadmin`, não o
aplicativo `apps/principal`. Conforme a revisão aprovada em
`specs/050-principal-ui-ux-closure.md`, sua opção Chat possui UI própria e
retorno contextual, compartilhando o `ChatRepository` de Comunicação > Conversas.
A composição não importa widgets `SuperadminChat*` nem cria repository,
cache de domínio, contrato Supabase, modelo ou cópia de mensagens próprios.
Essa revisão substitui a orientação inicial de reutilizar `SuperadminChatPage`.
No `/dev`, ambas as entradas compartilham a mesma instância determinística da
sessão; em produção, ambas passam exclusivamente pelo adapter RPC autorizado.
Nenhum arquivo de `apps/principal`, `apps/admin` ou `apps/site` é dependência
desse consumo.

## Dados e autorização

- pessoa é global; participação, membership, capability e contexto efetivo
  delimitam tenant, instituição, unidade, grupo, atividade e criança;
- leitura, envio, leitura de recibos e refresh são RPCs autorizadas; o Flutter
  não consulta tabelas de chat diretamente;
- cursor, busca, filtro de não lidas e paginação são executados no servidor;
- envio requer chave de idempotência, valida contexto e registra auditoria;
- acesso negado e recurso inexistente não revelam a existência do recurso.

## Realtime e mídia

Realtime só pode transportar um sinal mínimo de atualização por canal privado.
O aplicativo refaz a consulta autorizada e descarta payload como fonte de
autoridade. Revogação de membership encerra canal e cache local.

Anexos operacionais usam R2 privado. Postgres guarda apenas metadados, estado e
auditoria. O Flutter nunca recebe credencial R2, URL permanente ou fallback de
Supabase Storage. Até o gateway R2 validado (MIME real, tamanho, checksum,
chave gerada no servidor, URL curta e auditoria) upload e download falham de
forma segura.

O consumidor de imagem aprovado em 2026-09-07 abre a visualização somente por
ação explícita. `ChatAttachment.assetId` identifica o ativo canônico;
`ChatAttachment.id` identifica o binding, e URL legada não serve de fallback.
`MediaReader` solicita preview temporário e `MediaSession` delimita o contexto
autorizado. Expiração, revogação ou troca de contexto descartam a visualização;
nova tentativa é explícita e reautoriza. Eviction do cache Flutter não equivale
a revogação server-side ou limpeza de cache HTTP. A interface opcional não
habilita transporte de produção nem dispensa os gates R2/Auth.

## UX e acessibilidade

- inbox, composer e thread têm loading, vazio, busca sem resultado, offline,
  falha e não autorizado;
- badge mostra `0`, `1`–`9` ou `9+` visualmente e anuncia o total real;
- picker de emoji suporta categorias, busca, recentes da sessão e atalhos de
  emoticons inseridos no cursor;
- anexos truncam nome com tooltip, expõem estado semântico e oferecem retry só
  quando autorizado;
- teclado, Escape, foco visível, reduced motion e alvos de 48 px são exigidos.

## Pendência contratual de paginação

O diretório deve reutilizar a paginação canônica de Instituições, mas o RPC
atual entrega somente cursor por linha e não informa uma contagem ou um
`has_more` inequívoco para representar o total de páginas. Até o contrato
backend fornecer esse dado de forma autorizada, a UI não inventa `Página X de
Y` nem reintroduz um paginador local paralelo. `chat.list` permanece parcial
nesse gate mesmo com a primeira página, busca e estados locais funcionais.

## Verificação obrigatória

Testes cobrem RPC/RLS por operação, IDOR/BOLA cross-tenant, paginação, filtros,
idempotência, input inválido, XSS/URL, mídia e ausência de segredos. Goldens
focados cobrem 375/768/1024/1440, claro/escuro e launcher hover/focus. Docker
ou ambiente Supabase equivalente é necessário para executar a validação SQL.
