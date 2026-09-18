---
title: "Rodada 3 — perguntas ao Owner em lote (10/09/2026, tarde)"
source: "comunicacao/coordenacao.json rev 1; JSONs dos grupos; leitura de producao em 10/09/2026 14:30"
status: "awaiting-owner"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# Perguntas ao Owner — Rodada 3

## Estado das respostas (atualizado 10/09/2026, noite)

| Pergunta | Resposta do Owner | Registro |
| --- | --- | --- |
| P1 backup por ponto no tempo | B: dump lógico por lote, PITR dispensado | ADR 0034 D8 |
| P2 token R2 | feito pelo Owner; secrets gravados; spike PASS | ADR 0034 D8/D11 |
| P3 CORS local | a: `http://localhost:3000`; outra origem só a pedido; upload de teste apagado | ADR 0034 D12 |
| P4 chaves publicáveis | sim; `.env.local` nos oito checkouts | ADR 0034 D8 |
| P5 Turmas sem filtro | sim, compor com filtro degradando | ADR 0034 D12 |
| P6 importar de Unidades | trocar pela indisponibilidade honesta | ADR 0034 D12 |
| P7 Cardápios e perfis | todos mexem mediante perfis e permissões, de plataforma ou de instituição | ADR 0034 D12 |
| P8 Criar grupo no Chat | fazer agora (depois do realm interno v2) | ADR 0034 D12 |
| P9 leitura de saúde por responsável | opção 1; pacote em produção | ADR 0034 D9 |
| P10 MFA em publicação | nada exige MFA no MVP | ADR 0034 D12 |
| P11 AAL2 em Pessoas | nada exige MFA no MVP | ADR 0034 D12 |
| P12 baseline | seguir recomendado; feito | ADR 0034 D8 |
| P13 `units.unit_type_id` | confirmado | ADR 0034 D12 |
| P14 senha do banco | feito pelo Owner | ADR 0034 D8 |
| P15 rodapé de medicação | b: ancorado, com espaço no fim para nada ficar escondido | ADR 0034 D12 |
| P16 Local em Formulários | sim; caso extra: bloquear com aviso | ADR 0034 D10/D12 |
| P17 sessão de teste | sim; `qa-r03@coelo.me` em produção | ADR 0034 D10 |
| P18 capacidades de Locais | sim; nove provisionadas | ADR 0034 D10 |
| P19 ao vivo no Agora | respondida 10/09 (noite) | Deixar preparado: o token de Stream já tem Read+Edit e cobre Live Inputs; nenhuma transmissão é criada até o Agora precisar. Sem custo até uso. |
| P20 token antigo com 25 permissões | respondida 10/09 (noite) | Apagar. O coordenador não consegue (MCP retorna 9109 em /user/tokens); o Owner apaga em Perfil → Tokens de API → menu ⋯ → Excluir. Pendência de segurança 1c na skill coelo-backend até ele confirmar. |
| P21 Access na frente do Superadmin | respondida 10/09 (noite) | Ligar depois do MVP. Cloudflare Access (Zero Trust, gratuito até 50 usuários) na frente de superadmin.coelo.me, lista de e-mails da equipe Coelo, código por e-mail; não bloqueia nada da Etapa 2. |
| HostGator: site, e-mail, blog | **aberta** (três perguntas) | — |

O texto original de cada pergunta segue abaixo, como histórico.

Responder em lista `Pn - decisão, observação`. Cada resposta entra na ADR 0034
e na skill correspondente no mesmo turno.

## P1 — Backup por ponto no tempo está desligado (bloqueia toda a fila SQL)

Produção responde `pitr_enabled: false`, `walg_enabled: true`, zero backups
físicos. A ADR 0034 exige PITR ligado para aplicar migrations. PITR é
complemento pago do plano Pro.

- (a) Ligar PITR agora (custo mensal; contraria o custo zero).
- (b) **Recomendado:** dispensar PITR até existir cliente real. Antes de cada
  lote SQL o coordenador tira um `supabase db dump` lógico (schema + dados,
  local, fora do Git) e registra o arquivo e o SHA no coordenacao.json. Não há
  dados pessoais reais no projeto.
- (c) Manter a exigência e não aplicar nada (a rodada fica só em local-green).

## P2 — Token R2 de escopo mínimo só pode nascer no painel

A sessão OAuth do MCP não pode criar tokens (`9109 Unauthorized`). Já existem
`FORMS_S3_*` nos secrets, mas não dá para conferir o escopo daquele token.

Pedido: criar em R2 > Manage R2 API Tokens um token **Object Read & Write**
restrito a `coelo-media-prod`, `coelo-documents-prod` e `coelo-transient-prod`
(sem DNS, billing ou Workers) e gravar nos secrets sem passar pelo chat:

```powershell
supabase secrets set --workdir packages/coelo_database `
  COELO_R2_ENDPOINT=https://2363eb1eadce9b73279d3c8ce46eb424.r2.cloudflarestorage.com `
  COELO_R2_REGION=auto `
  COELO_R2_ACCESS_KEY_ID=<colar aqui> `
  COELO_R2_SECRET_ACCESS_KEY=<colar aqui>
```

Depois avisar "P2 feito". O coordenador segue com deploy das três funções e o
spike. Alternativa: autorizar reutilizar o token de `FORMS_S3_*` copiando os
valores para `COELO_R2_*` (o coordenador não consegue ler os valores; só o
Owner). Recomendação: token novo, escopo mínimo.

## P3 — Origem CORS para desenvolvimento local

CORS restrito já aplicado com `https://superadmin.coelo.me`,
`https://admin.coelo.me` e `https://app.coelo.me`. Para testar upload pelo
navegador em `flutter run -d chrome` é preciso uma origem fixa.

- (a) **Recomendado:** adicionar `http://localhost:3000` e padronizar
  `flutter run -d chrome --web-port 3000`.
- (b) Não adicionar; provar upload só em produção.

## P4 — Chaves publicáveis para E2E dos grupos

O grupo estrutura não tem `COELO_SUPABASE_URL` nem
`COELO_SUPABASE_PUBLISHABLE_KEY` na máquina. São chaves publicáveis (seguras
no cliente). Autoriza o coordenador a gravá-las em um arquivo local ignorado
pelo Git (`apps/superadmin/.env.local`) para todas as frentes usarem?

## P5 — Diretório de Turmas sem filtro por unidade (estrutura)

Compor o repositório real de Turmas agora, com o filtro por instituição/unidade
degradando de forma honesta quando falhar, fecha `groups.list` sem esperar
nada. Recomendação do grupo e do coordenador: compor agora. (Nota: as RPCs de
Unidades já existem em produção; o filtro tende a funcionar.)

## P6 — Diálogo de importar de Unidades (estrutura)

Hoje abre seletor de arquivo e prévia de linhas, o que a regra de importação
adiada proíbe. Trocar pela indisponibilidade honesta de Instituições?
Recomendação: trocar.

## P7 — Owner de instituição e Cardápios (principal-chat-sistema)

`has_platform_permission` só enxerga membership de plataforma. Um Owner de
instituição nunca terá `meal_plans.manage`. Basta para o Superadmin no MVP;
quando o Admin entrar, nenhum administrador de instituição gerencia cardápios.
É a regra pretendida ou lacuna a corrigir depois? Recomendação: registrar como
lacuna pós-MVP, sem mudar agora.

## P8 — Criar grupo no Chat (principal-chat-sistema)

Exige criar conversa e membros pelo realm interno, que não tem RPC nenhuma.
É pacote próprio com regra de quem cria e quem entra. Entra no MVP ou fica
para depois? Recomendação: depois do MVP; Fixar e bandeiras já voltaram.

## P9 — Leitura de saúde por responsável familiar (formularios-cuidado-rotina)

O pacote de Perfis de cuidado nega `platform.read` a dado de saúde e exige
`health_care.read`/`medication.read`. Leitura por responsável familiar exigiria
uma capacidade de guardião que não existe. Criar agora ou deixar para o app
Principal? Recomendação: deixar para quando o Principal entrar.

## P11 — Pessoas exige AAL2 no banco, inclusive para listar (acessos-pessoas)

`app_private.assert_people_permission` exige AAL2 sem exceção nas cinco RPCs
de Pessoas; sem fator cadastrado o Supabase emite AAL1, então o diretório de
Pessoas não abre em produção. Perfis e Modelos só exigem AAL2 na escrita.

- (a) Escrever create/update de pessoa no realm interno v2 (AAL1 por herança).
- (b) Adiar o AAL2 dentro de `assert_people_permission`, como
  `20260901200206` fez para o realm interno.
- (c) **Recomendado pelo grupo e pelo coordenador:** `people.read` aceita
  AAL1; `people.create` e `people.update` continuam exigindo AAL2. Mesmo
  desenho de Perfis e Modelos, reversível numa linha. Combina com P10: uma
  migration única de fase MFA do MVP.

## P12 — Baseline do banco a partir de produção (acessos-pessoas, AP-D2)

O repositório não reconstrói produção (ledger para em 01/09, 51 versões sem
arquivo local, objetos órfãos como `app_private.unit_import_source_attestations`).
O grupo testou: o dump schema-only de produção aplica limpo num Postgres 17
(231 tabelas, 179 policies).

- (a) **Recomendado:** baseline nova. O dump schema-only vira a migration
  inicial e o catálogo de permissões vira seed versionado; a cadeia antiga
  fica arquivada como histórico. Todo pacote novo passa a ser provado sobre a
  baseline real.
- (b) Reconstruir as órfãs uma a uma (custo alto, sem fim visível).

## P13 — Forma canônica de `public.units` (estrutura, levantado por acessos-pessoas)

Produção tem `unit_type_id NOT NULL` e não tem `institution_type_id`. A
migration `20260831164937` (não aplicada) exige o contrário e levantaria em
produção. É modelagem de domínio: decidir antes da fila rodar. Recomendação
do coordenador: produção é a forma canônica (`unit_type_id`); a migration
`20260831164937` é corrigida ou retirada da fila.

## P14 — Incidente de segurança: `supabase db dump --dry-run` imprime credencial

O grupo acessos-pessoas relatou que a flag `--dry-run` imprimiu no console o
bloco de conexão do pooler de produção com `PGPASSWORD` do papel efêmero
`cli_login_postgres.<ref>`. Não foi usado, copiado nem persistido; ficou na
saída de ferramenta de uma conversa. Pedido: trocar a senha do banco do projeto
no painel (só o Owner pode) e não usar `--dry-run` em sessão de agente.

## P15 — `medication_form_mobile_light`: rodapé dentro do scroll ou ancorado? (formularios-cuidado-rotina)

A referência guardada (R) tem o rodapé dentro do scroll, com "Cancelar"
cortado no fim da tela. O render atual tem o rodapé ancorado, como a regra
RODAPÉ (Decisão 7) e o golden aprovado de Criar instituição em 375 px.

- (a) Rodapé de volta para dentro do scroll, como na referência.
- (b) **Recomendado:** rodapé ancorado como em Instituições, com respiro no
  fim do conteúdo para nenhuma linha de texto ficar fatiada; o golden é
  regravado depois. Até a resposta o golden fica divergente de propósito.

## P16 — Pergunta de Local em Formulários entra no MVP? (formularios-cuidado-rotina)

As duas políticas de Local (opções fixas na publicação; local revogado exige
local atual) já estão na spec, mas o tipo `location` não existe: a constraint
de `form_items.kind` em produção não o aceita e a própria spec lista
localização como fora do MVP. Decidir: trazer `location` para o MVP (novo tipo
de item, migration e cliente) ou manter `forms.location-question` e
`forms.location-answer` adiadas. Caso aberto se entrar: pergunta obrigatória
com local revogado e nenhuma alternativa válida na lista congelada.

## P17 — Sessão de teste em produção para a régua do MVP (todas as frentes)

Os pacotes já estão em produção, mas "rota normal abre, CRUD persiste, reload
mantém" exige uma sessão autenticada, e só existe o usuário do Owner. Opções:

- (a) **Recomendado:** autorizar a criação de um usuário sintético de
  Superadmin via Supabase Auth (por exemplo `qa+r03@coelo.me`), com senha
  gerada por quem testa e guardada só no ambiente daquela sessão, membership
  de Owner de plataforma, e remoção do usuário e dos dados sintéticos ao fim
  de cada verificação. Nenhuma credencial passa por chat.
- (b) O Owner faz as verificações no próprio app a partir de um roteiro por
  action_id que as frentes escrevem.
- (c) Sem sessão: as frentes registram só "função existe e nega anônimo" e
  nenhuma ação chega a `verified`.

## P18 — Capacidades de Locais não existem em produção (estrutura)

O seed de produção não tem nenhuma permissão `locations.*`. A cadeia de
Locais v2 exige nove: `locations.read`, `create`, `update`, `status`, `copy`,
`schedule`, `reservations.read`, `reservations.manage` e
`reservations.override` (confirmar conflito de reserva). Sem elas, mesmo com
o SQL aplicado toda ação de Locais nega. Decidir: provisionar as nove no
catálogo com concessão inicial só ao Owner, `requires_mfa=false` no MVP
(AAL1) e risco registrado, ou reduzir o conjunto. Recomendação: provisionar
as nove como está na cadeia, Owner-only, AAL1, e revisar na fase profunda.

## P19 — Transmissão ao vivo no Agora (Stream Live)

Você perguntou se dá para "deixar preparado" o ao vivo. O token do Stream já
cobre, mas ao vivo é funcionalidade nova: custo por minuto entregue e
armazenado e regra própria de privacidade para crianças. Decidir depois do
MVP, com métrica do piloto. Recomendação: não agora.

## P20 — Token antigo "Cloudflare Agent Token - 2026-09-03"

Token de usuário com 25 permissões sobre todas as contas e zonas. Muito mais
do que o Coelo usa. Revisar no painel (Meu perfil → Tokens de API): se ainda
for necessário, reduzir; senão, revogar. Só você pode.

## P21 — Cloudflare Access na frente do Superadmin (pensar depois)

Registrado a seu pedido em 10/09: colocar o Cloudflare Access (Zero Trust)
como barreira antes do login de `superadmin.coelo.me` e `admin.coelo.me`.
Gratuito até 50 usuários; exige lista de quem entra e token próprio. Decidir
quando o app for publicado no domínio. Também na skill `coelo-backend`.

## P10 — `requires_mfa` em capacidades de publicação (publicacoes-agenda)

Código histórico ainda pede AAL2 em algumas capacidades de publicação; o MVP é
AAL1. O coordenador propõe uma migration única que desliga a fase MFA no
contexto interno (mesmo padrão de `routine_mfa_phase_enforced()` do grupo
formularios), em vez de cada grupo mexer na sua. Confirma?
