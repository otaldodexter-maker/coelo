---
title: "F-AUTHOR01 — crosswalk nominal de rascunhos internos"
source: "Reserva do Coordenador de 2026-09-07; spec 039; ADR 0019; spec Forms 2026-08-13:29-33; migrations canônicas inspecionadas"
status: "technical-boundary-approved-local-package-under-review"
generated_at: "2026-09-07"
---

# Recorte e ordem

Atualização: após `38041740`, o Coordenador fechou a fronteira técnica e reservou
`20260908030000_superadmin_internal_form_drafts_v2.sql` local. Reader usa manage
OU read explícitos; receipt mantém snapshot sanitizado original reautorizado;
coexistência é guard por recurso, sem revoke global. A matriz efetiva e os
ajustes de revisão estão em `2026-09-07-authoring-coexistence-matrix.md`.
As alternativas propostas abaixo registram a análise que precedeu esse
fechamento, não decisões ainda abertas. Nenhum SQL executado nesta frente.

Preparar criação/salvamento e leitura de rascunhos de Formulários no realm
interno do Superadmin, sem pessoa artificial. Primeiro fechar nomes e fronteira
de coexistência legada com o Coordenador; depois testes RED e SQL nominal; Eng1
executa exclusivamente o replay. Nenhum SQL ou remoto executado nesta proposta.
Estimativa de preparação após fechamento: 2–4 horas, excluindo fila de replay,
integração real e produção. Não constitui ETA da vertical integral.

Nesta fatia, rascunho nunca publicado; edição pós-publicação, publicar/distribuir,
responder, monitor, XLSX, imagens/locais e cuidado continuam no plano seguinte.
Não alterar Admin, Principal, Site, helpers Auth/MFA, gateway ou catálogo paralelo.

# Mapeamento físico e nominal proposto

| Existente | Impedimento | Evolução proposta para revisão |
| --- | --- | --- |
| `public.forms` | `created_by_person_id` e `updated_by_person_id` NOT NULL | Colunas `created_by_internal_identity_id` e `updated_by_internal_identity_id`, FK real interna; legadas tornam-se nullable com XOR separado para criador/atualizador. Preservar autoria histórica. |
| `public.form_versions` | Criador People obrigatório | `created_by_internal_identity_id` e XOR com criador legado; sem converter IDs entre realms. |
| Seções/itens/opções/condições | Grafo relacional existente e limites | Reutilizar mesmas tabelas, constraints e triggers; não criar segundo modelo Forms. |
| `app_private.form_command_receipts` | Recibo acoplado a pessoa e helpers com comparação nullable | Não inserir recibos internos nessa tabela nem alterar helper global; propor `app_private.superadmin_internal_form_draft_receipts`, deny-by-default, ENABLE/FORCE RLS, sem grants cliente. Precedente: recibos internos de edição institucional. |
| `form_replace_working_definition` | Chama validador publicável também no save | Novo helper privado nominal `superadmin_form_replace_draft_definition_v2(uuid,jsonb)`, estrutural, sem alterar o helper legado global. |
| `validate_form_definition` | Exige intenção/pergunta de quick poll | Novo `superadmin_form_validate_draft_definition_v2(uuid)` preserva integridade, opções, vínculos, ciclo/profundidade e limites; somente as três exigências de completude quick poll ficam para publicar. |
| `form_get_editor` | Guard People; override posterior inclui aplicações | Novo público/privado `superadmin_forms_editor_v2(uuid)` para definição de rascunho, `forms.read`, escopo real e audit. Não devolver aplicações/capacidades por inferência. |
| `form_save_draft` | Guard/recibo/autoria People | Novo público/privado `superadmin_forms_save_draft_v2(uuid,bigint,jsonb)`, `forms.manage`, ator/escopo reais, concorrência/idempotência, audit. |

O override efetivo `20260820152528` permite abrir editor com `forms.manage`
ou, alternativamente, `forms.read`, e só inclui aplicação com
`forms.manage_applications`. O reader nominal acima ainda precisa fechar essa
compatibilidade com o Coordenador; não declarar que `manage` concede `read`
nem ampliar qualquer grant por inferência.

Nomes são **propostos**, não recursos criados ou reserva unilateral. Número de
migration e manifesto pertencem ao Coordenador; nenhum timestamp foi inventado.

# Contrato da solicitação e resposta

Manter o grafo do DTO aprovado: tipo, identidade, unidade de resposta, título,
description, seções, itens, configuração, opções e condições. IDs enviados pelo
cliente identificam elementos da solicitação; nunca autorizam acesso a outra
versão, instituição ou recurso. Criação exige expected_version 0; edição exige
versão atual positiva, lock do recurso e pertença ao contexto autorizado.

Guard interno antes de casts/lookups. Identificador de instituição deve resolver
recurso real no escopo; não inferir instituição do cliente, papel familiar ou
criar People/AuthLink. AAL1/AAL2 seguem o MVP vigente. Nenhuma capability nova.

Validação server-side estrita de tipos/allowlists, tamanho e limites existentes;
nenhuma desativação de trigger. Título e integridade permanecem obrigatórios.
Intenção nula/em branco/281 caracteres, zero/duas perguntas ou só informação de
quick poll podem permanecer em rascunho, nunca publicados por essa operação.
Teto geral de description (4000) continua físico; não liberar payload arbitrário.

Resultado no envelope SAI, com definição sanitizada compatível com o cliente e
versão efetiva. Audit de sucesso/negativa fora da subtransação conforme F-READ;
sem conteúdo de perguntas/respostas, filtros, JWT ou PII no evento. Falha audit
aborta a operação inteira; ausência de AAL herda limitação explicitada no F-READ.

Recibos privados devem vincular request_id, identidade interna real, recurso e
instituição, hash e versão esperada; replay reautoriza sessão/capability/escopo
antes de consultar resultado. Não reutilizar request_id com payload/ator/escopo
diferente. A forma exata de resultado persistido deve ser fechada com o contrato:
snapshot sanitizado reproduz recibo original, mas duplica conteúdo de definição;
ack mínimo exige adaptação cliente/reload versionado para não tratar outra
versão como recibo original. Não escolher silenciosamente esse trade-off.

# Gate bloqueante de coexistência legada

XOR é proveniência, não autorização. Funções legadas SECURITY DEFINER com guard
People continuam capazes de ler/clonar um rascunho interno das mesmas tabelas.
Somente RLS ou revoke dos helpers privados não fecha esse caminho.

Portas administrativas identificadas: `form_list(jsonb)`,
`form_get_editor(uuid)`, `form_get_overview(uuid)` e comandos com assinatura
`(uuid,bigint,jsonb)`: `form_save_draft`, `form_publish`, `form_duplicate`,
`form_copy_or_move`, `form_archive_or_delete`, `form_request_export` e
`form_request_anonymous_participation_export`. Export pode criar job pelo ID
mesmo sem respostas. Distribuição/agenda e leitores operacionais devem entrar
no fechamento completo antes de promover o pacote.

O Coordenador precisa fechar uma das fronteiras técnicas: suspensão nominal dos
grants administrativos legados ou guards por recurso em seus corpos. REVOKE de
authenticated não é por app; afeta todos os consumidores. Não o executar por
inferência, nem usar autoria interna como regra permanente de audiência.

Preservar responder/participações, uploads e workers nesta reserva; autor interno
não transforma responsáveis elegíveis em atores internos. Não operar service_role.

# REDs e evidências exigidos após fechamento

- Ator interno sem People cria e relê draft, autoria/FKs internas verdadeiras.
- Seis incompletudes quick poll persistem no rascunho; integridade inválida não.
- Pré-publish/RPC legado não ganha bypass; nenhuma publicação por este pacote.
- Capacidade negada/revogada, A/B, instituição/ID adulterados, sessão inválida,
  People-only e falta de membership negados antes de dados/efeitos.
- IDs de outra versão não transferem ownership; opção de outra pergunta,
  condição inválida, ciclo e profundidade excedida revertem toda escrita.
- Concorrência de versão, replay igual, replay divergente, outro ator e revogação
  entre tentativas; nenhuma dupla versão/efeito, nem vazamento do recibo.
- Audit v2/v3, correlação e falha de append; nenhuma linha de negócio sobrevive
  à falha, nenhuma negativa de negócio sem evento obrigatório.
- Tentativa de extração/clone/export pela superfície legada fechada nominalmente.
- RLS/grants/definer/search_path e cadeia de dependências comprovados no runner.
- RPCs executadas como authenticated; TAP após RESET ROLE, sem grants de teste.

# Fontes físicas inspecionadas

- `20260813155005_forms_definition_and_capabilities.sql`: Forms/versions,
  constraints de conteúdo/configuração, validador e capabilities.
- `20260813155121_forms_commands_and_projections.sql`: recibos, guard,
  projeção, substituição do grafo, save/publish e portas públicas.
- `20260813155126_forms_security_performance_closure.sql`: imutabilidade,
  vínculo/tenant, deny-by-default das tabelas e separação workers.
- `20260828000500_superadmin_internal_institution_edit_core.sql`: precedente
  nominal de recibo interno, reautorização e replay.
- `20260820152528_forms_editor_application_capability_guard.sql`: override lido
  integralmente; editor distingue manage/read e restringe projeção de aplicação.

Gate de memória: proposta técnica ainda não aprovada; não publicar conhecimento
de produto como se já estivesse implementado. O Coordenador recebe o delta e
mantém os trackers oficiais. Não é entrega E2E nem redução do escopo original.
