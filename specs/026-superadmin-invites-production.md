---
title: "Convites produtivos no Superadmin"
source: "pedido aprovado pelo usuário em 2026-08-11; specs/021-people-identity-safe-foundation.md; decisions/0020-backend-authorization-application-security.md; contratos Coelo UI"
status: "approved"
generated_at: "2026-08-11"
---

# Convites produtivos no Superadmin

## Objetivo e problema

Substituir o protótipo local de Convites por um fluxo produtivo, persistente,
auditável e autorizado no backend. O diretório deve alinhar-se à tabela de
Instituições; a emissão deve usar o frame de Criar/Editar Instituição, resolver
contexto e perfil a partir de dados reais e oferecer somente e-mail e link
copiável.

## Matriz pré-código

| Tema | Aplica | Decisão |
| --- | --- | --- |
| Aparência | Sim | Instituições para diretório/tabela; Criar/Editar Instituição para formulário; Menu/Flyouts para ações; Popup de Bug para revogação. |
| Herança | Não | Convite referencia um escopo efetivo; não possui valor herdado ou override. |
| Localização/contato | Parcial | Contato existente pode identificar destinatário; Convites não edita endereço ou contato global. |
| Representante | Sim | É vínculo contextual de uma Pessoa global, nunca entidade duplicada. |
| Administradores/profissionais | Sim | São vínculos e perfis/capabilities compatíveis com o escopo selecionado. |
| Pessoas/perfis | Sim | Busca Pessoa global autorizada e perfis cadastrados aplicáveis à instituição/unidade/turma. |
| Tipos/subtipos | Não | Convite não cria taxonomia nem aceita `Outros`. |
| Status | Sim | Usar `Status do convite`: pendente, aceito, expirado e revogado. Falha pertence à entrega de e-mail; rascunho local não é registro emitido. |
| Hierarquia | Sim | Instituição, unidade e turma; cada nível deve pertencer ao pai autorizado. O realm interno Coelo permanece fora até decisão própria. |
| Plano | Não | Convite não altera plano nem entitlement. |
| Import/export | Não | Emissão individual nesta spec; não exibir Arquivos nem simular job. |
| Mídia | Não | Convite não recebe avatar/capa/upload; conflito Storage/R2 não é acionado. |
| Perfil público/descoberta | Não | Nenhuma publicação, descoberta, bio, destaque ou preview público. |

Avatar 320x320, capa 851x315, fotos por entitlement, `@` e mudança em 15 dias
permanecem fora de escopo porque Convites apenas referencia Pessoa/perfil e não
edita identidade.

## Escopo

- Diretório exclusivamente em tabela, com busca, filtros e paginação
  server-side, estados reais e ação persistente `Novo convite`.
- Entidade própria com alvo, instituição/unidade/turma, perfil, token somente em
  hash, expiração, status, emissor, contagem de envios e auditoria.
- Seleção pesquisável e hierárquica de contexto; filhos são carregados somente
  dentro do pai autorizado.
- Seleção pesquisável de perfil compatível com o contexto e o público.
- Destinatário por Pessoa global autorizada ou e-mail normalizado; vínculos de
  representante, administrador e profissional não duplicam Pessoa.
- Canais múltiplos: e-mail e link copiável. O link é devolvido uma vez após
  emissão/reenvio e nunca persiste em texto puro.
- Emitir, reenviar e revogar com idempotência, concorrência, auditoria e
  transições recalculadas no banco.
- Clique em expirado oferece detalhe e reenvio pelo flyout canônico; revogação
  continua vermelha e separada.

## Fora de escopo

SMS/celular, edição de convite emitido, importação/exportação em lote, cards,
toggle de visualização, mídia, perfil público, descoberta, plano, criação de
taxonomia, aceite do convite e entrega por provedor externo. A fila de entrega
registra e-mail pendente; worker/provedor é integração posterior e nunca gera
sucesso falso no Flutter.

## Entidades e dados

`invitations` preserva identidade existente e recebe canal de entrega,
idempotency key, versão, falha segura e metadados mínimos. Uma tabela privada de
comandos/entrega mantém replay e processamento sem expor token. Token bruto é
gerado pelo comando e retornado somente na resposta; o banco guarda SHA-256.

O alvo pode ser `target_person_id` ou contato normalizado em hash, nunca ambos
ausentes. `institution_id`, `unit_id` e `group_id` obedecem à hierarquia física.
`role_code` precisa existir, estar ativo e ser global ou pertencer à instituição
do convite. Reenvio invalida o token anterior, renova expiração e incrementa a
versão; revogação é terminal para aquele token.

## Permissões, tenant e segurança

Toda leitura e comando resolve `auth.uid()` para Pessoa e para a membership
global ativa que concede `platform.invites.read/manage`. Estas capabilities são
deliberadamente globais do Superadmin; não representam um papel institucional.
Mesmo para esse ator global, instituição, unidade, turma e perfil são validados
como uma hierarquia única antes da mutação. IDs do cliente nunca autorizam por si.
RLS é deny-by-default; DML direto fica revogado e comandos usam RPCs com grants
opt-in. Funções privilegiadas ficam em schema privado, `search_path` vazio,
autorização interna, transação curta e resposta sem oracle 403/404.

Emitir/reenviar/revogar exigem UUID de idempotência. Replay idêntico devolve o
mesmo registro seguro, mas nunca recompõe o token/link bruto; chave reutilizada
com payload diferente falha. Reenvio
e revogação bloqueiam a linha, reavaliam status/expiração/capability e registram
before/after. Nenhum `service_role`, segredo, token bruto, JWT, e-mail integral
ou PII entra em log, fixture, screenshot ou build Flutter.

## Threat model curto

- IDOR/BOLA por troca de convite, instituição, unidade, turma, Pessoa ou perfil:
  bloquear dentro da consulta autorizada e testar relações pai/filho trocadas.
- Replay/concorrência em emitir, reenviar e revogar: chave idempotente, lock de
  linha, versão e transições atômicas.
- Roubo de token: alta entropia, hash em repouso, exposição única, invalidação no
  reenvio/revogação e ausência em logs.
- Enumeração: mensagens e resultados não revelam existência fora do escopo.
- Injeção/XSS/CSV/path: allowlists, limites, parâmetros SQL e texto renderizado
  como texto; não há upload ou export nesta spec.
- Abuso: capability, AAL quando exigido, auditoria e fila apta a rate limiting
  server-side; Flutter não decide transição nem limite.

Baseline: OWASP ASVS L2; elevar a L3 autorização administrativa, auditoria,
tokens, chaves, ações de alto impacto e contextos com crianças/cuidado.

## UX, componentes e estados

O diretório usa `CoeloAdminListingToolbar`, filtros por constraints,
`CoeloAdminCreateAction.banner`, `CoeloAdminResizableTable`,
`CoeloAdminPagination`, `CoeloAdminFlyout` e `InviteStatusChip`. Busca/filtros
ficam à esquerda; não há Cards/Arquivos porque as operações correspondentes não
existem neste domínio.

O formulário usa `SuperadminFormStepNavigation`, frame canônico com rail 248 em
768/1024, gap `space6`, conteúdo máximo 880 e
`SuperadminFormActionFooter`. Destinatário, contexto e perfil são seções coesas
e reutilizáveis no nível da feature; controles compartilhados continuam em
`coelo_ui_admin`. Canais usam múltipla escolha com e-mail e link copiável. Após
concluir, uma superfície de resultado mostra o link uma única vez e oferece
copiar; falha de e-mail não é convertida em sucesso.

Estados obrigatórios: loading, empty, no-results, failure, unauthorized,
not-found, submitting, success parcial de canais e conflito/replay. Validar
375/768/1024/1440, 200%, light/dark, foco, teclado, toque de 48 px, semântica,
reduced motion, paginação compacta, rail e ausência de sobreposição com footer
ou chat.

## Eventos, logs e notificações

Auditar emissão, reenvio, revogação, replay, falha e aceite futuro com ator,
escopo, convite, estado anterior/posterior e idempotency key; minimizar contato
e nunca guardar token bruto. A fila de e-mail registra estado real `pending`,
`processing`, `sent` ou `failed`; o link copiável não inventa entrega.

## Critérios de aceite

- Nenhum `FakeInviteRepository`, fixture, catálogo hard-coded, contagem local,
  projeção por ID ou fallback demonstrativo participa de produção/router/UI.
- Contexto e perfil são pesquisáveis, carregados do backend e respeitam a
  hierarquia/capability real.
- Canal permite e-mail + link simultaneamente; SMS/celular inexiste.
- Reenvio de expirado é claro e canônico; revogação é negativa e confirmada.
- Filtros, paginação e métricas factuais são server-side, sem N+1.
- Replay, concorrência e chamadas diretas com IDs trocados falham fechados.
- Nenhuma tabela/view exposta fica sem RLS e nenhum segredo/token bruto chega ao
  cliente fora da resposta única do comando autorizado.

## Testes exigidos

pgTAP/SQL por operação e papel: positivo, anon, sem capability, membership
revogada, cross-tenant/instituição/unidade/turma/Pessoa/perfil, parent/child
trocados, leitura/listagem/detalhe, replay igual/diferente, concorrência,
expiração, reenvio, revogação, input inválido e grants/RLS.

Flutter: domínio e adapter, estados de repository/controller, router sem fake,
busca/filtros/paginação, contexto/perfil pesquisáveis, múltiplos canais,
resultado/cópia, flyout/reenvio/revogação, 403/404 não enumerável, URLs/texto
perigosos e ausência de segredo no build. Goldens focados cobrem tabela alinhada,
formulário 375/768/1024/1440, expirado com ações e confirmação de revogação.

## Riscos e perguntas abertas

O provedor de e-mail e o rate limiter distribuído não estão definidos. Esta
entrega registra outbox `pending/cancelled/sent/failed`, mas não afirma envio
externo; `processing` e lease pertencem ao contrato futuro do worker. Integrar o
worker exige um envelope recuperável protegido e decisão operacional posterior;
hashes sozinhos não permitem entrega. A URL pública de aceite também
depende do domínio final do app; a resposta usa a origem configurada
server-side, nunca valor enviado pelo Flutter.

Não há commit/push automático. Aplicação remota somente após reset, testes SQL,
advisors, query real, varredura de segredos e build web sem chave secreta.
