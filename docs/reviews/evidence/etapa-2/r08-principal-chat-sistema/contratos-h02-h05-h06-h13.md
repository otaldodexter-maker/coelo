---
source: R08-backlog; R07-varredura; decisoes R03-R07; ADR0012/0034; specs028/050; fontes abaixo
status: conciliacao-focal-sem-mudanca-de-contrato
generated_at: 2026-09-12
---

# Perfil e Chat — decisões existentes e questões residuais

Inspeção em 12/09/2026, base conjunta origin/dev `7cc6d4e7b`, incorporada
na branch G4 pelo merge `e989ed042`. Recorte de C0: H02/H05/H06/H13,
somente comparação de fontes; sem novos testes, fixtures ou mutações remotas.
App hospedeiro `apps/superadmin`. Inventário/rastreadores são escritos por C0.

| Gate / superfície → ação | Fonte e comportamento localizado | Decisão já aprovada aplicável | Ação remanescente |
| --- | --- | --- | --- |
| H02 / Coelo → Perfil → Editar → principal.profile-edit | Domínio contém ProfileAboutOfficialUpdateRequest. O editor compartilhado tem officialChanges e confirmProfileAboutOfficialUpdate, ambos sem consumidor produtivo localizado. O repository aceita officialUpdates, mas PrincipalProfileEditPage._save omite o argumento. A RPC save_profile_about suporta um conjunto limitado de contatos oficiais. | Sobre é salvo separadamente pelo caminho vigente. Spec050 aprova as quatro abas, mas não fornece seleção de campos/consentimento/resultado parcial para atualizar cadastro oficial a partir do Perfil. P35/P48 resolvem contexto/papel; não ligam essa operação. MFA já está fora do MVP pela ADR0034 D12 e migration230021; o texto AAL2 na baseline não cria nova decisão MFA. | Questão focal permanece: habilitar atualização explícita também no cadastro para quais campos/sujeitos e com qual resultado parcial, ou manter só Sobre no MVP? Não ligar o diálogo apenas porque existe e não anunciar dado oficial atualizado após salvar Sobre. |
| H05 / Chat → Conversa → recibos → chat.receipts | superadmin_chat_message_receipt conta participantes active/left_at null no momento da consulta, inclusive entradas posteriores à mensagem. Delivered/read usam o mesmo filtro. Não há corte joined_at contra created_at. | ADR0012 permite que nova professora autorizada leia o histórico e preserva autoria/contexto antigos. Isso decide acesso histórico, mas não decide quem entra no denominador do recibo. Spec028 exige projeção pelo servidor; não define destinatários históricos versus atuais. | Manter aceite MVP e contagem vigente. Pergunta focal: o denominador fica no conjunto atual ou no conjunto elegível na data de envio? Se mudar, definir também efeito da saída/reentrada nos três agregados. Não assumir que ler histórico equivale a ter recebido a mensagem original. |
| H06 / Chat → Conversa somente leitura → revogar mensagem → chat.revoke | UI administrativa desliga onEdit e onRevoke quando isReadOnly. RPC revoke valida contexto/capacidade/autor e soft-delete, sem condicionar a is_read_only/status active da conversa; edit recusa CHAT_READ_ONLY. | ADR0012 revoga operação quando a pessoa perde o vínculo; isso é distinto de uma conversa somente leitura para um ator ainda autorizado. A spec028 não afirma se readonly impede retirada da própria mensagem. | Pergunta focal permanece: readonly bloqueia apenas novas escritas/edição ou também retirada própria? Não ampliar UI nem restringir RPC por inferência; nenhuma prova de vazamento/incidente é derivada dessa diferença. |
| H13 / Coelo → Para Você → CTA de Comunicação → principal.for-you | PlatformNotice tem buttonLabel/linkLabel, sem destino URL no DTO. Adaptador passa label para cta. A rota resolve Agenda/Mensagens/Atividades por label; outros textos mostram indisponibilidade. Há cta_url no schema legado, que não basta para autorizar navegação. | Spec de Comunicações aprova CTA visual e destinos web/mobile/tablet/todos (dispositivo), não uma URL livre. Spec Para Você aprova item editorial e callback do preview. P35 permite contexto produtivo; não escolhe destino de CTA. | Questão focal permanece: definir destino tipado/autorizado por Comunicação, ou ratificar indisponibilidade no MVP. Não deduzir URL de label e não confundir destino de dispositivo com destino de navegação. Coordenação com mantenedor de Avisos/Comunicações necessária. |

## Fontes verificáveis

- `docs/reviews/etapa-2-operacao/next-round/R07-varredura-r01-r07.md:23`
  e `R08-backlog.md:98`: origem e primeiros gates.
- `R07-perguntas-ao-owner-20260912.md:27`: resíduos H não são decisões novas
  automaticamente; resolver pelas fontes e só conservar ambiguidades reais.
- `decisions/0012-contextual-experiences-and-conversation-history.md:82`:
  continuidade, nova professora e revogação de vínculo.
- `specs/028-superadmin-conversations-production.md:35`: dados/autorização.
- `specs/050-principal-ui-ux-closure.md:120`: quatro abas de Perfil.
- `packages/coelo_domain/lib/src/profile_about/profile_about.dart:446`:
  decisão modelada, sem ligação produtiva suficiente.
- `apps/superadmin/lib/features/profile_about/presentation/profile_about_editor.dart:130`
  e `:640`: detecção de diferenças e diálogo disponíveis, sem consumidor em lib.
- `apps/superadmin/lib/features/principal_profile/presentation/principal_profile_edit_page.dart:177`:
  save de Sobre e reload; não solicita officialUpdates.
- `apps/superadmin/lib/features/profile_about/data/supabase_profile_about_repository.dart:120`:
  parâmetro opcional e serialização p_official_updates.
- `packages/coelo_database/migrations/20260910000000_baseline_producao.sql:23760`:
  RPC save_profile_about; mapeia contatos instituição email/phone/mobile/website
  e unidade email/phone/mobile, retorna updated/failed por campo. Não mapear
  automaticamente nome, endereço ou todos os enums do domínio.
- `packages/coelo_database/migrations/20260910230021_mfa_fora_do_mvp_v1.sql:61`:
  helper MFA sob decisão vigente; não restaurar exigência histórica.
- `packages/coelo_database/migrations/20260910240200_superadmin_internal_chat_receipts_edit_revoke_v2.sql:109`
  e `:263`: agregados e revogação.
- `apps/superadmin/lib/features/chat/presentation/screens/superadmin_chat_page.dart:1093`:
  bloqueio de edit/revoke na UI readonly.
- `apps/superadmin/lib/features/notices/domain/platform_notice.dart:313`,
  `apps/superadmin/lib/features/notices/data/supabase_notice_repository.dart:281`,
  `apps/superadmin/lib/features/principal_for_you/data/principal_for_you_communications_adapter.dart:105`,
  `apps/superadmin/lib/features/principal_for_you/presentation/principal_for_you_route_page.dart:193`:
  contrato do label, projeção e resolução de ação.
- `docs/superpowers/specs/2026-08-05-superadmin-notices-mvp-design.md:42`
  e `2026-08-20-coelo-principal-for-you-preview-design.md:40`: limites dos destinos.

As referências encurtadas R0x acima referem-se ao diretório next-round.
Nenhuma busca em histórico ou projeção de conhecimento foi tratada como nova
aprovação. Projeções principal-profile, principal-for-you-preview,
principal-chat-integration e superadmin-notices-mvp foram cruzadas com fontes.

## Perguntas antigas que não precisam ser repetidas

- H03: as quatro abas já estão em PrincipalProfilePreviewPage e são injetadas
  pela rota produtiva. A classe antiga PrincipalProfileContentTabs não define
  uma quinta implementação necessária; sua área pertence à G6.
- P35/P48: ponte de contexto e separação Owner/operations já aprovadas/aplicadas;
  não usar essas perguntas como bloqueio genérico de Perfil/Para Você.
- Sobre legível por membros e UI própria de Chat já têm decisão anterior;
  não reabrir só porque projeções de conhecimento antigas dizem preview.
- P54: V-1 residual continua pós-MVP. H02/H05/H06/H13 não o reabrem.

Resultado: **nenhuma das quatro ambiguidades específicas foi encontrada como
respondida integralmente**. Preservar quatro perguntas focais, sem pedir de
novo as decisões adjacentes acima. Não mudar estados oficiais neste documento.

## Próximo gate executável proposto a C0

A leitura de PrincipalProfileEditPage revelou um problema independente de H02:
_save chama onSaved e anuncia sucesso depois de aguardar _load, embora _load
capture falha/negação ou descarte resposta obsoleta e não informe esse resultado.
Propor RED focal em principal_profile_edit_page_test.dart: save aceito seguido
de reload negado/indisponível, e troca de contexto durante reload. Corrigir só
se reproduzido, sem alterar cadastro oficial, schema, composição compartilhada,
referências visuais ou qualquer fixture real. Execução Flutter requer slot C0.

Memória: nenhuma regra nova aprovada; não há projeção durável a criar. Este
quadro é evidência de conciliação e proposta ao escritor central, não uma ADR.


Leitura real complementar (13h10 BRT): `profile-about-read-manifest.json` e
`profile_about_read_probe.py` registram get_profile_about200/result null nos
três sujeitos QA previamente autorizados (instituição, unidade e grupo), com
logout204 e nenhuma mutação. Não prova formato do resultado não vazio nem
inexistência absoluta de página, pois o reader também filtra estado/permissão.
A comparação estática revelou segundo gate focal: baseline21946 retorna objeto
plano, enquanto parseProfileAboutReadResponse espera page e trata plano como
null. G4 encaminhou a C0 para confirmar definição produtiva e preparar RED
fiel ao contrato, sem criar página real para contornar a falta de fixture.
