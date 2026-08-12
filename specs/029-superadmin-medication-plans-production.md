---
title: "Planos de medicação produtivos"
source: "decisão do produto em 2026-08-12; specs/020-superadmin-health-care.md; docs/data/health-care-future-data-model.md; decisions/0020-backend-authorization-application-security.md; decisions/0023-medication-private-storage.md"
status: "approved-for-implementation-fail-closed"
generated_at: "2026-08-12"
---

# Planos de medicação produtivos

## Objetivo, precedência e gate

Transformar Planos de medicação em um fluxo produtivo, centrado em uma única
criança, para prescrição, agenda, execução e histórico auditável. Esta spec
substitui explicitamente os limites demonstrativos de
`specs/020-superadmin-health-care.md` somente para a família técnica de Planos
de medicação. Perfis de cuidado continuam regidos pela spec 020 até spec própria.

Schema, adapters e testes podem ser preparados, mas toda ativação com dados reais
permanece **fail-closed** enquanto `legal_basis_and_retention` estiver pendente
em `OQ-003` e `OQ-040`. Sem gate aprovado, comandos produtivos não recebem grant,
RPC pública ou fallback local; a UI apresenta indisponibilidade real.

## Escopo e fora de escopo

Inclui plano, medicamento, dose, unidade, via, periodicidade, horários, vigência,
prescrição, responsáveis, suspensão, ocorrências e auditoria de administração,
omissão, recusa e correção. Inclui foto opcional do medicamento e prescrição no
Supabase Storage privado conforme ADR 0023. Inclui importação e exportação por
jobs server-side versionados, com preview, validação, confirmação, progresso,
erros, resultado e autorização por objeto.

Não inclui herança entre crianças, diagnóstico, recomendação clínica, cálculo de
dose, substituição de prescrição, estoque, compra,
perfil público, descoberta ou execução por usuário sem vínculo profissional e
capability efetivos.

## Matriz aplica / não aplica / decisão

| Tema | Aplica? | Decisão |
| --- | --- | --- |
| Aparência | Parcial | Foto opcional e privada do medicamento, em proporção 1:1; sem avatar, capa, bio, emojis, destaques ou galeria por entitlement. |
| Herança | Não | Plano, agenda, execução e autorização nunca são herdados ou copiados automaticamente entre crianças. |
| Localização/contato | Não | O plano não cadastra endereço, telefone ou e-mail. O escopo institucional é resolvido por vínculos confiáveis. |
| Representante | Não | Não há representante institucional no plano. `responsável` é vínculo operacional próprio. |
| Admins | Não | O formulário não administra usuários ou perfis administrativos. |
| Profissionais | Sim | Somente profissionais com membership, vínculo com a criança e capability efetivos podem revisar ou executar ações permitidas. |
| Pessoas/perfis | Sim | Criança e adultos referenciam pessoas globais; responsáveis e profissionais são vínculos contextuais, nunca cópias de pessoa. |
| Tipos/subtipos | Parcial | Não existe tipo genérico de medicamento. Unidade de dose e via usam catálogos controlados; subtipo só nasce com taxonomia aprovada. `Outros` exige solicitação auditada, não texto que altere catálogo. |
| Status | Sim | Status de plano, ocorrência e evento de execução são domínios separados e nomeados abaixo. |
| Hierarquia | Sim | Tenant, instituição, unidade, turma e criança limitam autorização; hierarquia não herda conteúdo clínico. |
| Plano | Não | `Plano de medicação` não é plano comercial e não altera entitlement ou cobrança. |
| Import/export | Sim | Jobs server-side usam template versionado, preview, validação, confirmação, progresso, erros e resultado. Arquivos são privados e temporários; capability, MFA, escopo e ownership são revalidados em cada operação. |
| Mídia | Sim | Foto do medicamento e prescrição usam Supabase Storage privado, metadados no Postgres e entrega temporária autorizada. |
| Perfil público | Não | Nenhum dado, foto, prescrição ou histórico ganha URL ou perfil público. |
| Descoberta | Não | Não há busca pública, handle, indexação ou descoberta de criança/medicamento. |

## Modelo de domínio

### Plano e versão

O plano referencia uma criança imutável, medicamento, foto opcional, dose
decimal positiva, unidade de dose, via, vigência por datas civis, fuso IANA
explícito, dias da semana ISO (`1` segunda a `7` domingo), um ou mais horários
locais, prescrição opcional e responsáveis ativos.

- `child_id` é definido na criação e nunca atualizado. Na edição, “Trocar de
  criança” apenas navega para o plano selecionado ou inicia outro cadastro.
- `timezone` é obrigatório e guarda identificador IANA, sem offset fixo. Datas e
  horas são inputs distintos: data aceita somente data; hora aceita somente hora.
- `starts_on` é obrigatório; `ends_on` é opcional e não pode anteceder o início.
- Cada horário é único dentro da versão por dia da semana + hora local + fuso.
- Alterar medicamento, dose, unidade, via, vigência, fuso, periodicidade,
  horários ou prescrição cria versão; ocorrências passadas permanecem ligadas à
  versão que as originou.
- A frequência exibida deriva dos dias e horários persistidos, nunca de texto
  livre ou cálculo no Flutter.

Responsáveis são múltiplos, adicionados **um por vez**. O backend impede vínculo
ativo duplicado do mesmo responsável no mesmo plano; tentativas concorrentes
retornam conflito idempotente. Remover vínculo não apaga pessoa nem histórico.

### Plano, execução e status

- Plano: `rascunho`, `ativo`, `suspenso`, `encerrado`.
- Ocorrência agendada: `pendente`, `em_execucao`, `concluida`, `cancelada`.
- Resultado de execução: `administrada`, `omitida`, `recusada`.
- Correção não reescreve o evento original: cria evento corretivo que referencia
  o anterior, exige justificativa e registra valor anterior e efetivo.

Ativar exige versão válida, ao menos um horário, responsável e, quando a regra
institucional exigir, revisão profissional/prescrição válida. Suspender exige
motivo, ator e instante; impede novas execuções, preserva ocorrências e não pode
ser tratado como exclusão. Retomar cria evento auditado e revalida vigência,
permissões e versão.

Uma ocorrência é materializada/consultada no servidor a partir de data civil,
hora local e fuso IANA. Administração usa claim atômico, versão esperada e chave
de idempotência. Duas pessoas não concluem a mesma ocorrência; resposta obsoleta
falha deterministicamente sem “última escrita vence”.

## Autorização, RLS e consultas

O Flutter apenas coleta intenção. Toda leitura, criação, edição, suspensão,
retomada, execução, correção e acesso a arquivo recalcula `auth.uid()`, tenant,
instituição, unidade, turma, criança, membership, vínculo profissional/familiar,
capability, ownership, status e hierarquia no backend/banco.

- A consulta parte do conjunto autorizado e nunca busca ID global para filtrar
  depois. ID, UUID, slug, cursor, path e parent IDs do cliente são não confiáveis.
- Tabelas expostas usam RLS deny-by-default e policies separadas por operação;
  `UPDATE` exige `USING` e `WITH CHECK`. Grants são opt-in e least privilege.
- Views expostas usam `security_invoker`. Funções têm `EXECUTE` revogado de
  `PUBLIC`, `anon` e `authenticated`; gateways recebem somente o grant necessário.
- `SECURITY DEFINER`, se inevitável, fica em schema privado, `search_path` vazio,
  autentica/capacita dentro da função e tem testes explícitos de bypass.
- FKs/constraints compostas impedem cruzar criança, contexto e plano; uniques
  garantem responsável/horário/claim; índices cobrem FKs, filtros RLS, status,
  agenda e paginação por cursor. Não há N+1.
- Comandos sensíveis são transacionais, curtos, idempotentes e auditam before/
  after minimizado. Locks seguem ordem estável: plano, versão, ocorrência, claim.
- Membership ou capability revogada invalida nova requisição; cache/JWT antigo
  não autoriza ação sensível.

Capabilities mínimas e independentes: `medication_plans.read`,
`medication_plans.create`, `medication_plans.manage`,
`medication_plans.review`, `medication_administrations.execute`,
`medication_administrations.correct` e `medication_assets.read/manage`.
Superadmin não executa dose por ser Superadmin: também precisa do vínculo
profissional operacional exigido.

## Mídia privada

Foto e prescrição seguem ADR 0023. O backend emite intenção e path opaco gerado
no servidor; bucket é privado; Postgres guarda owner, child/context, tipo,
checksum, MIME validado, tamanho, estado e auditoria. O Flutter recebe somente
chave publicável e acesso curto após nova autorização.

- Foto: JPEG, PNG ou WebP; máximo 5 MiB; mínimo 320 × 320; SVG proibido.
- Prescrição: PDF, JPEG ou PNG; máximo 10 MiB; conteúdo ativo proibido.
- Extensão, MIME declarado, MIME real, assinatura, tamanho e relação de negócio
  são validados no servidor. Nome original nunca compõe path.
- Upsert não substitui evidência: nova versão de asset é criada. Remoção lógica,
  órfãos e remoção física dependem da política de retenção aprovada.
- URL pública/permanente, path previsível, service role e fallback R2/Storage
  demonstrativo são proibidos. URL assinada expirada exige nova autorização.

## UX e componentes

Criar e editar compartilham os mesmos inputs e anatomia aprovada de Instituições/
Unidades com `SuperadminFormFrame`, largura máxima 880 e footer canônico. Edição
trava a criança. O seletor “Trocar de criança” é navegação explícita e não altera
o registro atual.

O diretório mantém o card “Criar plano” alinhado e presente mesmo quando a lista
está vazia. Não há container único envolvendo todo o formulário. Seções coesas
reutilizáveis: agenda/periodicidade, dosagem e histórico de execução; APIs são
mínimas, tokenizadas, semânticas e cobertas por teste/golden quando compartilhadas.

Estados reais: loading, empty, no-results, failure, unauthorized e not-found.
Busca/filtros e paginação são server-side. Validar 375/768/1024/1440, 200%,
light/dark, teclado, foco, reduced motion e alvos de 48 px. Negativas usam tokens
vermelhos Coelo; nenhum Material cru, fixture visual ou fallback fake é permitido.

## Threat model e baseline ASVS

Baseline: OWASP ASVS 5.0.0 nível 2, elevando a nível 3 controles de autorização
contextual, dados infantis/de saúde, arquivos, auditoria, chaves e comandos de
alto impacto. O checklist deve registrar requisito completo e evidência; em
especial `v5.0.0-8.1.1`, `v5.0.0-8.1.2`, `v5.0.0-8.2.1`,
`v5.0.0-8.2.2`, `v5.0.0-8.2.3`, `v5.0.0-14.1.1`,
`v5.0.0-14.1.2`, `v5.0.0-14.2.4`, `v5.0.0-14.2.6`,
`v5.0.0-14.2.7` e `v5.0.0-14.2.8`.

| Ameaça | Controle verificável |
| --- | --- |
| IDOR/BOLA por IDs, parents, cursor ou arquivo trocado | Query dentro do conjunto autorizado, RLS/RPC, paths opacos e matriz negativa sem distinção indevida 403/404. |
| Profissional sem vínculo ou acesso revogado executa dose | Revalidação por requisição, capability + vínculo com criança + contexto e fail-closed. |
| Dupla administração, replay ou corrida de correção | Idempotência, claim único, versão esperada, lock/transação e auditoria imutável. |
| Manipulação de dose, horário, fuso ou status | Validação server-side, catálogos, ranges, transições e constraints. |
| Upload malicioso, path traversal ou prescrição de outro contexto | Intent server-side, MIME/assinatura/tamanho allowlist, path gerado e autorização por objeto. |
| Vazamento por URL, cache, log, analytics ou bundle | URL curta, no-store, payload mínimo, logs redigidos, secret scan e inspeção do build web. |
| XSS/URL ativa em nomes/observações/arquivos | Texto como texto, limites, protocolos allowlist; sem HTML, SVG ativo, eval ou WebView. |
| Alteração/apagamento de evidência | Eventos append-only, correções referenciais, before/after minimizado e retenção fail-closed. |

## TDD e evidências obrigatórias

RED/GREEN/refactor cobre domínio, widgets e SQL real. Antes de ativar:

- testes positivos e negativos por read/create/update/suspend/resume/execute/
  correct e asset read/upload/delete;
- matriz cross-tenant, cross-institution, cross-unit, cross-group e cross-child,
  inclusive parent/child trocados, deep link, cursor, path e chamada direta sem UI;
- papéis distintos, profissional sem capability, responsável duplicado, criança
  imutável, membership revogada, estado inválido e inexistente/fora do escopo;
- concorrência, replay, idempotência, versão obsoleta, horário repetido, datas,
  hora, dias ISO e fuso IANA;
- input malformado/excessivo, XSS, URL perigosa, MIME falso, SVG/conteúdo ativo,
  path traversal, arquivo estrangeiro e órfão;
- RLS/grants/policies por operação, views `security_invoker`, EXECUTE, advisors,
  plano de query/paginação e ausência de N+1;
- secret scan, ausência de chaves/PII em diff, logs, fixtures e build web;
- testes/goldens focados dos componentes e validador Coelo UI, format, analyze,
  testes relevantes, knowledge gate e build.

Nenhuma tabela, rota, RPC, Storage policy ou tela é liberada enquanto permitir
acesso fora do escopo, decisão no frontend, segredo exposto, input confiado ou
tratamento real antes do gate jurídico e de retenção.
