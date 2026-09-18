---
title: "Locais, mapas e agendamentos de espaços no Superadmin"
source: "Decisões do Owner em 2026-09-02; AGENTS.md; ADRs 0031 e 0032; specs aprovadas de Estruturas, Atividades, Agenda e Formulários"
status: "approved-design"
generated_at: "2026-09-02"
updated_at: "2026-09-03"
---

# Locais, mapas e agendamentos de espaços no Superadmin

## Objetivo e problema

Criar um catálogo reutilizável de locais para instituições e unidades, capaz de
atender Turmas, Atividades, Eventos e Formulários sem duplicar implementações
por módulo. O catálogo também sustenta um mapa visual simples, fotos opcionais,
visibilidade por público, vínculos reversos e reservas únicas ou recorrentes.

Esta spec registra o comportamento aprovado. Ela não autoriza iniciar a
implementação, alterar Supabase ou Cloudflare remotos ou promover qualquer gate
dos rastreadores.

## Escopo aprovado

- Instituições e unidades possuem catálogos independentes de locais.
- Uma instituição pode repassar um local a uma unidade. O repasse cria uma
  cópia independente, editável pela unidade sem alterar a origem; a proveniência
  da cópia é preservada para auditoria.
- Cada local é explicitamente `interno` ou `externo`.
- Local interno não exige endereço. Local externo exige endereço válido no
  cadastro; andar e demais complementos continuam livres e opcionais.
- Nome do local e andar são campos de texto livre, sujeitos a limites,
  normalização e validação server-side.
- A seção `Mapa e locais` aparece desde o cadastro inicial de instituição e
  unidade. Seu preenchimento, a imagem geral, os marcadores e as fotos dos
  locais são opcionais.
- O mapa é simples: uma imagem/planta geral por instituição ou unidade,
  marcadores clicáveis para os locais e foto opcional por local. Não há
  obrigação de cadastrar uma planta separada por andar.
- A visibilidade é configurada por local como `equipe`, `responsáveis`,
  `alunos` ou `todos`. `Todos` significa todos os públicos autenticados e
  autorizados daquele contexto, nunca acesso público à internet.
- Turmas, Atividades e Eventos podem selecionar um local catalogado ou informar
  um local pontual. Ao informar um local novo, a interface pergunta se ele deve
  ser salvo no catálogo da instituição ou unidade corrente.
- Local pontual permanece apenas no cadastro de origem. Somente local
  catalogado possui mapa/foto, vínculos reversos e agenda de disponibilidade.
- Turmas e Atividades com período, dias e horários recorrentes oferecem a opção
  explícita `Reservar este local nesses horários`. Quando selecionada, criam
  reservas recorrentes; quando desmarcada, o local é apenas informativo.
- Eventos usam o mesmo catálogo e a mesma agenda para reservas únicas ou
  recorrentes.
- A gestão da agenda define, separadamente por instituição ou unidade, a
  política de conflito: `bloquear` ou `alertar`.
- Na política `alertar`, somente ator com capability específica pode confirmar
  a sobreposição, com justificativa obrigatória e auditoria. Na política
  `bloquear`, a sobreposição impede a gravação.
- O detalhe do local apresenta seus vínculos com Turmas, Atividades, Eventos,
  Formulários e demais consumidores autorizados.
- Formulários recebem o tipo de pergunta `Local interno`, com escolha única ou
  múltipla. As opções são locais internos catalogados e visíveis ao público
  respondente; respostas persistem IDs estáveis e o snapshot textual necessário
  para preservar a versão do formulário.

## Fora de escopo

- Mapa cartográfico, navegação interna, geocodificação automática ou rotas.
- Planta obrigatória por andar, editor vetorial ou modelagem 3D.
- Tornar um local pontual reservável antes de salvá-lo no catálogo.
- Sincronizar automaticamente alterações entre o local original da instituição
  e a cópia independente da unidade.
- Bucket público, credencial R2 ou exposição de paths permanentes no Flutter.

## Superfícies e action_ids reservados

| Superfície | `action_id` | Comportamento pendente |
| --- | --- | --- |
| Instituição — criar/editar | `institutions.locations-map` | Exibir seção permanente, catálogo, mapa geral opcional, marcadores e visibilidade. |
| Unidade — criar/editar | `units.locations-map` | Manter catálogo e mapa independentes. |
| Unidade — locais | `units.copy-institution-location` | Copiar local da instituição, preservando proveniência sem sincronização posterior. |
| Locais — diretório | `locations.list` | Listar, filtrar e mostrar escopo, tipo, visibilidade e disponibilidade. |
| Local — criar/editar | `locations.create-edit` | Validar interno/externo, endereço obrigatório do externo, andar livre, foto e públicos. |
| Local — detalhe | `locations.detail-links` | Mostrar mapa/foto, dados, agenda e relações autorizadas. |
| Gestão de agendamento | `locations.schedule` | Reservas, recorrência, intervalos, conflitos e política bloquear/alertar. |
| Turma — criar/editar | `groups.location` | Local catalogado ou pontual e reserva recorrente opcional. |
| Atividade — criar/editar | `activities.location` | Local catalogado ou pontual e reserva recorrente opcional. |
| Evento — criar/editar | `agenda.location` | Local catalogado ou pontual, disponibilidade e reserva. |
| Formulário — editor | `forms.location-question` | Pergunta de local interno com escolha única ou múltipla. |
| Formulário — responder | `forms.location-answer` | Exibir somente opções autorizadas/visíveis e preservar snapshot da versão. |

Os doze IDs ficam reservados e abertos. Eles ainda não integram os denominadores
históricos até o inventário técnico reconciliar telas existentes, aliases e
possíveis ações já cobertas, evitando dupla contagem.

## Entidades e contratos conceituais

- `locations`: escopo proprietário (instituição ou unidade), tipo, nome, andar,
  endereço do externo, visibilidade, estado e proveniência opcional da cópia.
- `location_maps`: uma imagem geral opcional por proprietário e metadados de
  versão/auditoria.
- `location_map_markers`: posição normalizada do marcador, referência ao local
  e metadados de acessibilidade.
- `location_media`: metadados Postgres da imagem geral e da foto opcional;
  binários novos pertencem ao Cloudflare R2 privado conforme ADR 0032.
- `location_reservations`: início/fim, recorrência, intervalos, consumidor,
  estado, idempotência e autoria.
- `location_scheduling_policies`: política `bloquear` ou `alertar` por escopo.
- `location_bindings`: vínculo autorizado do local catalogado com o consumidor;
  usos pontuais preservam um snapshot local sem participar da agenda.

Os nomes físicos finais dependem de inventário e migration forward-only. O
domínio R2 canônico para a planta geral e a foto opcional é `locations`, já
incluído na allowlist da ADR 0032. Esta spec não autoriza criar tabelas ou
alterar o ledger.

## Permissões, tenant e segurança

- Toda leitura e escrita valida ator, capability, tenant, instituição/unidade,
  ownership do local e público de visibilidade.
- O servidor trata IDs, escopo, recorrência, horários, visibilidade, endereço,
  coordenadas de marcador e consumidor como entrada não confiável.
- Tabelas expostas usam RLS deny-by-default, grants mínimos e testes de
  IDOR/BOLA, tenant A/B, acesso revogado e recurso fora do escopo.
- Confirmação de conflito na política `alertar` exige capability própria,
  justificativa, versão/idempotência e evento de auditoria.
- Mapas e fotos usam Cloudflare R2 privado. O Media Gateway server-side valida
  sessão, tenant, capability, audiência, MIME, tamanho e checksum antes de
  emitir acesso temporário; bucket, chave de objeto e segredo não são expostos
  pelo contrato Flutter. Postgres/Supabase preserva metadados, ownership,
  retenção e auditoria sob RLS.
- A visibilidade controla tanto o diretório/detalhe quanto os marcadores do
  mapa e as opções oferecidas em Formulários.

## UX e estados

- Cobrir loading, vazio, erro, sem autorização, conflito, recurso revogado,
  imagem ausente e retry.
- Antes de salvar um local pontual no catálogo, mostrar o proprietário de
  destino de forma explícita: instituição ou unidade corrente.
- Conflitos mostram local, período conflitante e ação causadora sem revelar
  dados fora do escopo do ator.
- Teclado, foco, toque, texto a 200%, mobile/desktop e claro/escuro seguem o
  design system e WCAG 2.2 AA quando aplicável.

## Desenvolvimento local e produção

- `/dev` usa fixtures determinísticas próprias para instituições, unidades,
  locais internos/externos, mapas, visibilidades, vínculos e conflitos.
- Rotas produtivas usam exclusivamente repositories Supabase autorizados e
  falham fechadas quando o backend não estiver disponível.
- Dados fake nunca são fallback da rota produtiva e não entram no Supabase.
- A futura prova E2E precisa usar Superadmin real → repository → Supabase →
  autorização/RLS → Media Gateway → R2 privado → persistência/metadados →
  resposta → reload.

## Eventos, auditoria e efeitos

Registrar criação/edição/inativação, mudança de visibilidade, cópia para
unidade, upload/substituição/remoção de imagem, movimento de marcador, vínculo,
reserva, conflito, override, cancelamento e revogação. Notificações futuras não
podem antecipar confirmação quando a reserva falhar ou for bloqueada.

## Critérios de aceite e testes exigidos

- Catálogos de instituição e unidade permanecem independentes após a cópia.
- Externo sem endereço é negado; interno pode ser salvo sem endereço.
- Usuário vê somente locais, fotos, marcadores, vínculos e opções de formulário
  permitidos por tenant, capability e público.
- Reserva recorrente detecta sobreposição e respeita a política vigente.
- Override permitido exige capability e justificativa; negado/revogado falha
  sem persistir efeito parcial.
- Alterações persistem após reload; concorrência e retries são idempotentes.
- R2 privado, Media Gateway, URL temporária, expiração, revogação e cleanup são
  comprovados.
- `/dev` permanece fake/determinístico e separado da composição produtiva.
- Flutter verified, Supabase done e verified-e2e somente após evidência real de
  permitido/negado/revogado, tenant A/B, persistência, reload e auditoria.

## Ownership de implementação futura

- E2E 2 — Estruturas e Pessoas: instituição/unidade, catálogo, cópia, mapa,
  detalhe/vínculos e integração de Turmas.
- E2E 4 — Formulários, Respostas e Cuidado: pergunta e resposta de local interno.
- E2E 5 — Agenda, Eventos e Operações: Atividades, Eventos e motor/tela de
  reservas e conflitos.

Qualquer schema, migration, Media Gateway/R2, router ou componente compartilhado exige
reserva prévia com o Coordenador. O repasse desta spec não inicia trabalho.

## Riscos e decisão de prefixo

- OQ-045 foi encerrada com `locations` como domínio R2 canônico. Continuam
  obrigatórios inventário físico, retenção, Media Gateway, autorização,
  expiração e cleanup antes do upload real; não reutilizar outro domínio nem
  criar prefixo ad hoc.
