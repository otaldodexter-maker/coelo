---
source: Owner, artefato "Decisões do Owner" (claude.ai/code/artifact/1432ea84-6b86-4782-9c67-92689c5097ef) e chat de 14/09/2026; fila R13 (H02–H28, owner.r12-*), docs/open-questions.md, R07-perguntas-ao-owner-20260912.md
status: accepted
generated_at: 2026-09-14
lifecycle: "current"
---

# ADR0038 — Decisões do Owner sobre o backlog da Etapa 2 (14/09/2026)

Em 14/09/2026 o Owner respondeu, num artefato com opções e detalhe livre,
aos 37 pontos da Etapa 2 que estavam parados por decisão de produto,
ambiente ou UI/UX. As respostas foram lidas do banco do artefato e são
registradas aqui como fonte canônica. Cada linha aponta a pendência de
origem; os rastreadores, specs e skills passam a citar esta ADR.

Status desta ADR é decisão de regra e prioridade, não certificado de
implementação. Estados por `action_id` continuam nos três rastreadores.

## Produto e contrato

| Origem | Decisão | Efeito |
|---|---|---|
| R12-23 (spec 018) | **A — aprovar perfis profissionais para uso no Principal.** Owner: "professor que publica no app, auxiliar que só visualiza aquela turma, professor que publica mas não responde no chat, professor que não publica Momentos… N variações". | Revisar spec 018: Principal deixa de ser catálogo somente leitura. Perfis profissionais são atribuídos por vínculo e contexto (instituição/unidade/turma) e concedem capacidades finas por ação do Principal (publicar Momentos, publicar Agora, responder chat, ver turma). Principal não vira nível hierárquico; pessoa global mantém vários vínculos. Gestão no Superadmin > Acessos. |
| R12-33 / H19 (spec 020) | **A+B+C+D+E.** Responsáveis elegíveis: guardiões autorizados **e** equipe da unidade/turma no escopo. Notificar em novo plano, alteração e suspensão **e** lembrete no horário da dose. Só sino no app no MVP. | Seleção de responsável não concede `medication.record_evidence`. Lembrete: dois avisos, 30 e 15 min antes (adendo 14/09). |
| R12-02 (spec 021) | **A — modelos Coelo não se arquivam.** | Arquivar só em modelos da instituição/unidade; nos modelos de sistema o botão fica indisponível com explicação. Spec 021 preservada. |
| R12-18 (child-safety) | **B — nome, sobrenome e CPF obrigatórios** (confirmado no chat). RG, profissão, imagem/tipo de documento, celular e e-mail opcionais. | Pessoa global sem conta; dedupe global pelo HMAC do CPF (CPF nunca em claro; máscara para exibição). Autorização nasce pendente de revisão. |
| H15 / R07-PLANO (spec 051) | **B — `plans.assign` fora do MVP.** Owner: "Plano não terá no MVP, só na v1 ou v2". | Botão honestamente indisponível; `activate` = restaurar, não atribuir. |
| H05 (Chat) | **B — recibos contam participantes ativos atuais.** | Aceite MVP mantido; sem corte por `joined_at`. |
| H06 (Chat) | **A — revogar proibido no servidor em conversa somente leitura.** | `revoke_message_v2` passa a recusar `CHAT_READ_ONLY`; cliente já esconde. Histórico congelado quando o vínculo da criança termina. |
| H08 (Avisos) | **A — Duplicar no MVP.** | Duplicar cria rascunho "Cópia de …" com conteúdo/tipo/audiência; sem datas, sem recibos; auditoria registra origem. Vale para qualquer status, inclusive terminais. |
| H13 (Comunicação) | **B — CTA abre o detalhe do item relacionado.** | `PlatformNotice` ganha destino por tipo (circular → circular, convite → convite…); sem URL livre. |
| H10 / H11 (Formulários) | **A — preservar todas as regras de audiência + autosave do autor ligado.** | Editor lista regras e só edita/adiciona; host produtivo passa `authoringApi`. |
| H21 / R07-CIRC-LIMITE (spec 037) | **4.000 caracteres é o total da circular, somando os blocos de texto** (confirmado no adendo de 14/09, opção B). | Spec 037 passa de 10.000 para 4.000 total; a referência coelo-ui (142/4.000) já estava certa. Contador no compositor soma os blocos. |
| H17 (Cuidado, P23) | **A — só capacidade.** Owner: "e owner tem acesso a tudo". | Remover papel fixo owner/operations de `superadmin_unit_care_policy_set_v1`; criar capacidade própria `care_policies.manage` (nasce nos perfis de sistema Owner e Administrador da instituição). Owner de instituição/unidade continua com tudo no seu contexto (P23). |
| Local interno em Formulários (1) | **A — fixar os IDs das opções na publicação da versão.** | Local novo exige nova versão; resposta grava ID + snapshot. |
| Local interno em Formulários (2) | **A — revisão conserva o valor histórico.** | Campo mostra "local não disponível" sem obrigar troca; trocar só entre opções válidas. |
| Anexos por mensagem (Chat) | **C — até 10 por mensagem (por envio).** | Validação server-side no lote de `prepare`; limite por arquivo continua o da ADR 0032; sem teto por conversa. |
| Identidade da mídia do Chat (spec 028) | **B — migrar o envelope para `asset_id` agora.** | `chat-media` (RPC `authorize_read` + Edge Function) passa a devolver `asset_id` além de `attachment_id`; `attachment_id` continua a chave de autorização. Re-provar o E2E do chat após o pacote. |
| Conta — reader self | **A — aprovar.** | `platform.read` via principal interno (spec 039); campos nome, sobrenome, e-mail profissional, celular; estado explícito "cadastro ausente", sem criação automática. |
| Planos — principal 039 | **A — confirmar a transição nominal.** | Readers de Planos migram para o principal interno, somente leitura; writer legado intocado; `units_with_override` só com cálculo comprovado ou indisponibilidade explícita. |
| OQ-028 (Suporte) | **A — mapear:** Novo=`open`, Em andamento=`pending`, Aguardando solicitante=`pending`+flag, Concluído=`resolved`/`closed`; `expired`/`revoked` aparecem como Concluído com motivo. | Enum do banco preservado. |
| OQ-031 (Turmas) | **B — catálogo global Coelo**, com opção **Outros** + texto livre. Owner: "Faça uma busca e crie catálogos com tipo de instituição, unidades, turmas e atividades. Instituições podem ser híbridas, educacional, escolar, terapias e outras. Unidades: escolar, terapias, futebol, academia infantil, igreja… Podemos mudar o tipo delas sem problema." | Catálogos globais de tipo para instituição, unidade, turma e atividade, só o Owner altera; entidade pode mudar de tipo. Listas aprovadas no adendo de 14/09. |
| OQ-020 (Instituições) | **B — legenda informativa e clicável como filtro.** | Depende da taxonomia de status já vigente no diretório. |
| H02 (Principal > Sobre) | **A — conectar no MVP.** | `ProfileAboutOfficialUpdateRequest` ganha consumidor produtivo; pedido vai à instituição para aprovar. |

## Ambiente e segurança

| Origem | Decisão | Efeito |
|---|---|---|
| R12-51 / ADR 0034 D8 | **A — manter a Decisão 8.** | Regra vigente única: dump lógico local (fora do Git, SHA-256 registrado) antes de cada lote satisfaz o item 3 da Decisão 1 **até o primeiro cliente real ou a abertura da Etapa 3, o que vier antes**; a partir daí PITR obrigatório. O texto da R11 que exigia PITR fica superado. Fila SQL liberada. |
| P51 / R12-47 | **SMTP próprio aprovado, mas como pendência final do MVP.** Owner (adendo 14/09): "deixe isso como pendência final do MVP, para ajustar lá no fim, antes de entregar." | Até lá, link de definição de senha por canal seguro (B herdado). Provedor decidido no fechamento; credencial só no secret store (P30). Registros SPF/DKIM podem entrar na HostGator sem trocar nameservers. |
| R12-47 redirect | **A — adicionar localhost à allowlist do Auth.** | Sem custo; configurar pelo CLI/painel. |
| DNS coelo.me (1d) | **C — deixar para o deploy.** | Nameservers na HostGator ficam até a etapa de publicação. |
| Token Cloudflare amplo (1c) | **C — manter até o fim do MVP.** | Revisar no encerramento. |
| Senha do banco (item 2) | **C — no fim do MVP.** | Mantém a regra "sem `--dry-run` em sessão de agente". |
| Dados sintéticos (P25) | **A — manter até o fim da Etapa 2.** | Limpeza arquiva, não apaga. |
| Arrobas reservados | **B — no fechamento do MVP.** Owner: "será feito na Etapa 3". | Só `coelo` e `coelo.me` até lá. |

## UI / UX

| Origem | Decisão | Efeito |
|---|---|---|
| R12-10 golden 1440 | **Diferença irrelevante: é o cabeçalho global** (adendo 14/09, opção A). | Não mexer na tela de Segurança infantil; regravar a referência quando o cabeçalho estabilizar. |
| R07-CIRC-RODAPE | **Seguir a referência inteira** (adendo 14/09, opção A): shell/menu presente, rodapé em card contornado dentro do contêiner, contador 4.000 total, Opções com o toggle "Salvar como rascunho". | Os seis goldens web R são regravados após a correção do host; referência `aprovadas-20260911/circular-web-1440.png`. |
| R12-36/37 Cardápio | **C — Prioridade explícita e Datas excluídas saem do contrato** (adendo de 14/09, após ver o wizard). | Migration forward-only remove os dois campos; sobreposição de cardápios no mesmo dia/público passa a ser bloqueada ao salvar. Exceções históricas ficam preservadas no dump do lote. |
| H23 Avisos refresh | **A — manter a lista visível + barra fina de progresso.** Owner: "usar esse padrão para as demais". | Vira padrão de atualização de todos os diretórios/listas do Superadmin (coelo-ui). |
| H27 Para você / Momentos | **Saudação por hora do dia** (Bom dia/Boa tarde/Boa noite, nome quando houver) e **ponto laranja na aba Momentos do dock quando há momento não visto** (adendo 14/09). | Duas correções de UX no Principal; sem mudança de contrato. |
| R12-53 | **C — nenhum opcional; fechar a Etapa 2 sem `institutions.status`/`locations-map`.** | Retirar da fila da Etapa 2. |
| P54 avatar/Agora (V-1) | **Entra no MVP** (adendo 14/09, opção A): avatar do Perfil ganha anel em degradê laranja quando há Agora não visto e tocar abre o Agora daquele perfil. | V-1 volta ao escopo da Etapa 2 (Principal › Perfil + Agora). |

## Adendo de 14/09/2026 — respostas com imagem e texto

Artefato "Aprovações Visuais Coelo"
(claude.ai/code/artifact/3e2a113d-ca29-4d4f-9e1b-162bcc21a514), 11/11
respondidas. As linhas das tabelas acima já refletem estas respostas.

- **Lembrete de dose (R12-33):** dois avisos no sino, **30 min e 15 min antes** do horário.
- **Circular (H21):** 4.000 é o **total** da circular somando os blocos.
- **SMTP (P51):** pendência final do MVP; provedor decidido no fechamento.
- **Catálogos de tipo (OQ-031):** listas propostas **aprovadas como estão** ("depois melhoramos"):
  - Instituição: Escola (educação básica); Creche / educação infantil; Centro de terapias; Clube / escola esportiva; Escola de idiomas / cursos; Igreja / comunidade; Híbrida; Outros.
  - Unidade: Escolar; Educação infantil; Terapias; Esportes / futebol; Academia infantil; Idiomas / cursos; Igreja / comunidade; Outros.
  - Turma: Turma escolar (ano/série); Turma de educação infantil; Grupo de terapia; Atendimento individual; Turma esportiva; Turma de curso / oficina; Grupo de comunidade; Outros.
  - Atividade: Aula regular; Aula extracurricular; Sessão de terapia; Treino; Oficina / curso; Evento / passeio; Reforço / acompanhamento; Outros.
  - "Outros" sempre com texto livre; entidade pode mudar de tipo; catálogo entra por migration idempotente por `code`.
- **Visuais:** R12-10 irrelevante (cabeçalho global); Circular segue a referência inteira; Cardápio sai do contrato; Avisos mantém lista + barra fina (padrão para todas as listas); saudação por hora do dia; ponto laranja em Momentos; avatar/Agora no MVP.

Nenhum item continua aguardando o Owner nesta ADR.

## Consequências

- `docs/open-questions.md` marca como resolvidas as seções: Local interno em
  Formulários, anexos por mensagem, identidade de mídia do Chat, reader self
  da Conta, principal de Planos, R08 responsáveis de medicação, R12 decisões
  pendentes, R11/R12 PITR, R07-CIRC-LIMITE, R07-PLANO, OQ-020, OQ-028 e
  OQ-031 (parte de tipo).
- Specs a revisar por esta ADR: 018, 020, 021 (preservada), 028, 037, 039/051
  (Planos), notices-mvp-design (Duplicar), locais-mapas-agendamentos e
  forms-end-to-end (Local interno).
- A fila R13 continua a fonte operacional; esta ADR fecha o primeiro gate
  "decisão" dos itens acima e não promove estado por `action_id`.
