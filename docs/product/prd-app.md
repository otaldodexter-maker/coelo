---
title: "Coelo PRD App Oficial v1"
source_file: "Coelo PRD App Oficial v1.docx"
source_copy: "docs/source/originals/docx/Coelo PRD App Oficial v1.docx"
original_path: "C:/Users/adrie/Desktop/Coelo/PRD/Coelo PRD App Oficial v1.docx"
supplemental_source: "decisions/0015-contextual-people-authorizations-attendance.md; specs/015-contextual-people-access-attendance.md"
status: "derived-from-official-docx"
version: "v1"
generated_at: "2026-07-24"
---

<!-- Documento derivado de fonte oficial. Edite a fonte DOCX ou registre uma decisao antes de alterar conteudo normativo. -->
| Coluna 1 | COELO<br>PRD App Oficial v1<br>app.coelo.me + iOS/Android · Experiência diária |
| --- | --- |

Versão: v1.0 | Data: 21/06/2026 | Status: Draft para validação

| Flow, Now, Moments, rotina, chat e agenda em uma rede social privada, visual e governada pela instituição. |
| --- |

Simples como Airbnb Visual como Instagram Confiável como escola

Documento derivado do Product Vision Oficial v1 e do PRD Master Oficial v1 do Coelo.

# Sumário executivo do documento

| # | Seção |
| --- | --- |
| 1 | Capa e controle de versão |
| 2 | Resumo executivo |
| 3 | Objetivos e princípios |
| 4 | Públicos e contexto ativo |
| 5 | Escopo do MVP |
| 6 | Navegação |
| 7 | Flow |
| 8 | Now |
| 9 | Moments |
| 10 | Diário de rotina |
| 11 | Chat e canais |
| 12 | Agenda |
| 13 | Notificações |
| 14 | Perfil e portal do responsável |
| 15 | Fluxos principais |
| 16 | Requisitos funcionais |
| 17 | Regras de negócio |
| 18 | Eventos e analytics |
| 19 | Offline-tolerant |
| 20 | Segurança e privacidade |
| 21 | Requisitos não funcionais |
| 22 | Critérios de aceite |
| 23 | Riscos e mitigação |
| 24 | Decisões oficiais |
| 25 | Perguntas em aberto |
| 26 | Próximas specs |
| 27 | Fontes e referências |

# 1. Capa e controle de versão

| Campo | Valor |
| --- | --- |
| Documento | PRD App Oficial v1 — Coelo |
| Owner | Produto Coelo |
| Público interno | Produto, design, engenharia, dados, segurança, jurídico, operações e agentes de coding. |
| Status | Draft para revisão e versionamento. |
| Base interna | Product Vision Oficial v1; PRD Master Oficial v1; História da Logo e Marca Oficial v1; mapa competitivo e decisões do fundador. |
| Escopo | Aplicativo mobile e web de uso diário por responsáveis, professores, coordenadores, direção e equipe. |

| Versão | Data | Mudança | Responsável |
| --- | --- | --- | --- |
| v1.0 | 21/06/2026 | Criação do PRD específico alinhado ao PRD Master e às decisões oficiais do fundador. | Produto Coelo |
| v1.1 | A definir | Revisão após specs técnicas, protótipo e validação do piloto. | Produto + Engenharia |
| v2.0 | A definir | Atualização após piloto real e priorização da próxima fase. | Produto + Negócio |

# 2. Resumo executivo

O App é a experiência cotidiana do Coelo. Ele combina hábitos visuais de rede social com privacidade institucional: Flow para posts e comunicados, Now para conteúdos temporários, Moments para vídeos de até dois minutos, diário de rotina, chat contextual, agenda e portal do responsável.

O usuário é uma pessoa única e pode ter múltiplos papéis. O contexto ativo precisa separar claramente a experiência familiar da profissional. Conteúdos nunca são públicos: a visibilidade deriva de instituição, unidade, grupo, criança e permissões.

| Nomes oficiais v1<br>Flow = feed privado; Now = conteúdo temporário de 24 horas; Moments = vídeos privados de até 2 minutos. |
| --- |

# 3. Objetivos e princípios

| Princípio | Aplicação no App |
| --- | --- |
| Simplicidade radical | Entender a navegação no primeiro uso. |
| Visual antes de burocrático | Rotina, fotos e comunicados fáceis de consumir. |
| Privado por padrão | Sem descoberta pública, ranking ou busca aberta de crianças. |
| Contexto sempre claro | Mostrar instituição e papel ativo quando houver múltiplos vínculos. |
| Confiança acima de volume | Notificações úteis, histórico e confirmação de leitura. |
| Uso rápido pela equipe | Publicar rotina e conteúdo em poucos passos. |

# 4. Públicos e contexto ativo

| Usuário | Home ideal | Ações principais |
| --- | --- | --- |
| Responsável | Flow seguido + card das crianças + agenda do dia. | Ver rotina, confirmar leitura, reagir, responder agenda, conversar e ver Now/Moments. |
| Professor | Grupos do dia + atalhos de rotina + pendências. | Registrar rotina, publicar conteúdo autorizado, conversar com responsáveis vinculados. |
| Coordenador | Pendências por grupo/unidade + comunicados recentes. | Revisar rotina, comunicar, atender e supervisionar. |
| Direção | Resumo institucional e alertas. | Comunicar, acompanhar pendências e acessar o Admin quando necessário. |
| Equipe | Atalhos conforme função e contexto. | Executar apenas ações autorizadas. |

- Responsável que também é professor alterna contexto sem misturar dados ou ações.

- Contexto ativo inclui instituição e papel; unidade, grupo ou criança aparecem quando aplicável.

- Troca de contexto deve atualizar dados, permissões e navegação imediatamente.

# 5. Escopo do MVP

| Módulo | MVP | Resumo |
| --- | --- | --- |
| Login/contexto | Sim | Conta adulta global por e-mail ou celular, `@identificador` opcional e troca de contexto. Criança não possui login no MVP. |
| Flow | Sim | Posts, comunicados, mídia, confirmação de leitura e reações simples. |
| Now | Sim | Fotos/vídeos curtos com expiração padrão de 24h. |
| Moments | Sim | Vídeos privados de até 2 minutos. |
| Diário de rotina | Sim | Histórico da criança e registro rápido pela equipe. |
| Chat/canais | Sim | Atendimento contextual e chat interno; sem responsável–responsável. |
| Agenda | Sim | Eventos, lembretes, RSVP e autorização simples. |
| Notificações | Sim | Central in-app e push com payload mínimo. |
| Perfil/portal | Sim | Crianças, vínculos, preferências, termos e contexto. |
| Comentários | Não | Fora do MVP; reações simples entram. |

# 6. Navegação

| Destino principal | Conteúdo |
| --- | --- |
| Flow | Posts, comunicados, mídia e perfis seguidos. |
| Rotina | Diário e histórico por criança. |
| Conversas | Caixa única de conversas e canais autorizados, com filtros opcionais. |
| Agenda | Eventos, respostas e autorizações. |
| Perfil/Contexto | Conta, crianças, instituições, papel ativo, preferências e termos. |

Now deve aparecer como faixa visual no topo do Flow. Moments pode ser acessado por uma entrada própria dentro do Flow ou navegação definida no protótipo, sem alterar o significado funcional deste PRD.

# 7. Flow

| Requisito | Definição |
| --- | --- |
| Perfis privados | Instituição, unidade, grupo e perfis oficiais Coelo. |
| Seguidores automáticos | Derivados dos vínculos e regras de audiência. |
| Formatos | Texto, descrição, carrossel de até 10 fotos e vídeos curtos de até 30 segundos no MVP. |
| Comunicados | Podem exigir confirmação de leitura. |
| Menções | Criança pode ser referenciada somente dentro de audiência autorizada, sem depender de `@username` no MVP. |
| Reações | Simples no MVP. |
| Comentários | Desativados no MVP. |
| Conteúdo global | Avisos sistêmicos obrigatórios; dicas opcionais podem ser silenciadas. |
| Audiência | Post só aparece para usuário com vínculo e autorização. |

# 8. Now

| Aspecto | MVP/v1 |
| --- | --- |
| Duração | Expiração padrão de 24 horas. |
| Mídia | Fotos e vídeos curtos de até 30 segundos. |
| Audiência | Instituição, unidade, grupo, criança específica ou papel autorizado. |
| Consentimento | Respeitar autorização de imagem e regras da instituição. |
| Download | Bloqueado por padrão. |
| Histórico | Retenção interna/auditável ainda não definida. |
| Analytics | Visualização, alcance e abertura, com dados minimizados. |

# 9. Moments

| Aspecto | MVP/v1 |
| --- | --- |
| Formato | Vídeo privado com duração de até 2 minutos. |
| Publicação | Equipe autorizada, em perfil de instituição/unidade/grupo. |
| Audiência | Contextual e derivada dos vínculos. |
| Descoberta | Sem algoritmo público, viralização ou ranking social. |
| Interação | Reações simples; comentários desativados. |
| Mídia infantil | Consentimento e política de mídia obrigatórios. |
| Download | Bloqueado por padrão. |

# 10. Diário de rotina

| Categoria | Exemplos do MVP |
| --- | --- |
| Alimentação | Refeição, quantidade aproximada, aceitação e observações. |
| Sono | Dormiu, início/fim, qualidade e observações. |
| Higiene | Fralda/banheiro, trocas e observações. |
| Saúde | Sintomas observados, temperatura quando aplicável e ocorrência; medicação exige regra formal. |
| Humor | Linguagem não estigmatizante: calmo, animado, sensível, irritado, sonolento. |
| Atividades | Atividades, participação e mídia autorizada. |
| Ocorrências | Incidentes, bilhetes e encaminhamento. |

- Professor registra em lote por grupo e ajusta individualmente.

- Rascunho local evita perda de dados.

- Alterações após publicação ficam auditadas com autor, data e motivo.

- Responsável vê apenas rotina da criança autorizada.

# 11. Chat e canais

| Tipo | MVP | Regra |
| --- | --- | --- |
| Responsável ↔ instituição | Sim | Atendimento contextual por criança/unidade/grupo. |
| Professor ↔ responsável | Sim | Permitido quando houver vínculo com a criança. |
| Coordenação ↔ responsável | Sim | Canal oficial. |
| Canal por grupo | Sim | Conversa controlada; respostas podem ser restritas. |
| Canal por unidade | Sim | Comunicados e atendimento. |
| Chat interno equipe | Sim | Por unidade/grupo, com auditoria. |
| Responsável ↔ responsável | Não | Fora do MVP por privacidade e moderação. |

- Confirmação de envio/leitura.

- Anexos básicos: imagem e PDF; vídeo pode ser limitado conforme custo/moderação.

- Histórico e auditoria obrigatórios.

- Admin autorizado pode consultar conversas conforme grupos e escopos definidos.

- Exclusão é soft delete com registro de auditoria.

## 11.1 Caixa De Conversas

`Conversas` é uma única caixa de entrada visual. `Todas` é a visão padrão;
`Instituições e unidades`, `Turmas` e `Atividades` são filtros opcionais. O
filtro de criança pertence a um nível separado. Cada item continua sendo uma
conversa independente e contextual no banco; a agregação e os filtros nunca
criam um escopo compartilhado nem ampliam autorização.

Instituição, unidade, turma e atividade podem usar avatar circular na caixa. O
ponto de presença indica disponibilidade do serviço ou da equipe em contextos
coletivos, não a presença de todas as pessoas. O estado deve possuir texto e
semântica acessível, sem depender somente da cor. Publicação ativa de Now é
representada por um anel visual ao redor do avatar e não se confunde com
presença.

# 12. Agenda

| Funcionalidade | MVP/v1 |
| --- | --- |
| Eventos | Por instituição, unidade, grupo ou criança. |
| Lembretes | Push e e-mail opcional. |
| RSVP | Sim/Não/Talvez quando aplicável. |
| Autorização simples | Ciência ou autorização do responsável. |
| Recorrência | Simples no MVP ou v1.1, sem calendário excessivamente complexo. |
| Anexos | PDF/imagem opcional. |
| Calendário externo | Futuro. |

# 13. Notificações

| Tipo | Canal | Regra |
| --- | --- | --- |
| Comunicado importante | Push/in-app | Payload mínimo; abrir tela autenticada. |
| Nova rotina | Push/in-app | Agrupar para evitar excesso. |
| Chat | Push/in-app | Não revelar conteúdo sensível. |
| Agenda | Push/e-mail opcional | Lembrete configurável. |
| Aviso Coelo | In-app/push crítico | Segmentado e com vigência. |
| Convite | E-mail/celular | Link seguro e expiração. |

- Central de notificações in-app no MVP.

- Preferências por rotina, chat, agenda, comunicados e dicas Coelo.

- Mensagens de segurança e termos não dependem de opt-in de marketing.

# 14. Perfil e portal do responsável

| Área | Conteúdo |
| --- | --- |
| Minhas crianças | Cards com instituição, unidade, grupo e vínculo. |
| Rotina | Histórico, filtros, mídia e ocorrências. |
| Flow | Perfis seguidos e comunicados. |
| Agenda | Eventos, RSVP e autorizações. |
| Chat | Conversas por contexto. |
| Privacidade | Preferências, termos, consentimentos e solicitações. |
| Conta | E-mail, celular, `@identificador` adulto e alternância de contexto. |

# 15. Fluxos principais

| Fluxo | Passos | Critério de aceite |
| --- | --- | --- |
| Primeiro acesso | Abrir convite → autenticar → confirmar perfil → escolher contexto → onboarding. | Usuário vê apenas dados do contexto autorizado. |
| Pré-cadastro | Criar conta adulta global → verificar contato → localizar exatamente instituição/unidade por `@`, e-mail, link ou QR → solicitar vínculo. | Conta e solicitação pendente não concedem acesso institucional. |
| Cadastrar criança | Responsável inicia perfil infantil privado → apresenta referência à instituição → aguarda validação. | Instituição cria seu contexto e vincula primeiro à unidade; turma pode ser definida depois. |
| Trocar contexto | Abrir seletor → escolher instituição/papel → confirmar. | Feed, rotinas, chats e ações mudam sem mistura de dados. |
| Ler comunicado | Abrir Flow → acessar post → confirmar leitura quando exigido. | Recibo é registrado. |
| Registrar rotina | Selecionar grupo → aplicar template → ajustar crianças → revisar → publicar. | Responsáveis autorizados recebem apenas a rotina correspondente. |
| Conversar | Abrir chat contextual → enviar → acompanhar status. | Somente membros autorizados acessam. |
| Responder agenda | Abrir evento → escolher resposta/autorização → confirmar. | Resposta fica registrada por responsável e contexto. |

# 16. Requisitos funcionais

| ID | Área | Requisito |
| --- | --- | --- |
| APP-RF-001 | Contexto | Alternar instituição e papel sem misturar permissões. |
| APP-RF-002 | Flow | Exibir e publicar conteúdo privado conforme audiência. |
| APP-RF-003 | Comunicados | Confirmar leitura quando exigido. |
| APP-RF-004 | Reações | Permitir reações simples; não permitir comentários no MVP. |
| APP-RF-005 | Now | Publicar e visualizar conteúdo temporário. |
| APP-RF-006 | Moments | Publicar e visualizar vídeos privados de até 2 minutos. |
| APP-RF-007 | Rotina | Registrar em lote, ajustar, salvar rascunho e publicar. |
| APP-RF-008 | Chat | Conversas e canais autorizados com leitura e auditoria. |
| APP-RF-009 | Professor–responsável | Permitir conversa quando houver vínculo com a criança. |
| APP-RF-010 | Agenda | Responder RSVP e autorização simples. |
| APP-RF-011 | Notificações | Central in-app e push com conteúdo mínimo. |
| APP-RF-012 | Portal | Consolidar crianças, rotina, Flow, agenda e chat. |
| APP-RF-013 | Mídia | Bloquear download por padrão e usar acesso privado. |

# 17. Regras de negócio

- Não existe rede pública, busca aberta de crianças ou viralização.

- Audiência é determinada por vínculos e permissões, não apenas por follow visual.

- Flow permite reações simples e não permite comentários no MVP.

- Professor pode falar diretamente com responsável quando houver vínculo com a criança.

- Chat entre responsáveis fica fora do MVP.

- Download de mídia fica bloqueado por padrão; screenshot não pode ser tecnicamente impedido de forma absoluta e deve ser comunicado em política.

- Criança pode ser referenciada somente em contexto autorizado; `@username`
  infantil não é necessário no MVP.

- Responsável vê contextos da criança para os quais foi selecionado/autorizado.

# 18. Eventos e analytics

| Evento | Uso |
| --- | --- |
| user_signed_in | Adoção e segurança. |
| context_switched | UX multi-papel. |
| flow_post_viewed/reacted | Engajamento. |
| post_read_confirmed | Taxa de leitura. |
| now_viewed | Abertura. |
| moment_viewed/completed | Consumo de vídeo. |
| routine_started/published/edited | Tempo e qualidade operacional. |
| message_sent/read | Tempo de resposta. |
| agenda_responded | Aderência. |
| notification_opened | Efetividade. |

# 19. Offline-tolerant

| Área | MVP |
| --- | --- |
| Flow | Cache read-only dos últimos itens. |
| Rotina | Rascunho local e fila de envio. |
| Chat | Cache das últimas conversas; envio online ou fila curta com status. |
| Mídia | Compressão, retry e estado pendente. |
| Agenda | Cache dos próximos eventos. |
| Admin/Superadmin | Fora deste PRD; online-first. |

| Limite do MVP<br>O App será offline-tolerant, não full offline-first. Sincronização bidirecional complexa só será adotada se o piloto demonstrar necessidade. |
| --- |

# 20. Segurança e privacidade

- Payloads de push não expõem dados sensíveis.

- Mídia usa buckets privados e URLs assinadas/temporárias.

- RLS e autorização de Realtime protegem feed, chat e rotinas.

- Chaves secretas nunca ficam no cliente.

- Analytics evita nomes e dados desnecessários de crianças.

- Não existe busca pública ou diretório infantil. Código/QR privado,
  `child_context` ou eventual `@username` não concedem login nem acesso.

- Termos, consentimentos e papel jurídico aguardam validação no PRD LGPD.

# 21. Requisitos não funcionais

| Categoria | Requisito |
| --- | --- |
| Performance | Carregamento rápido em conexão móvel comum, thumbnails e paginação. |
| Usabilidade | Responsável entende o app no primeiro uso; professor registra rotina em poucos minutos. |
| Acessibilidade | Contraste, toque, labels e fontes legíveis. |
| Segurança | RLS, armazenamento privado, autorização contextual e auditoria. |
| Confiabilidade | Rascunhos, retry de mídia e estados de erro claros. |
| Manutenibilidade | Flutter em camadas, componentes compartilhados e testes. |
| Privacidade | Minimização de dados em telas, notificações e analytics. |

# 22. Critérios de aceite

- Responsável com filho em duas instituições troca contexto e vê apenas o selecionado.

- Professor que também é responsável alterna papel sem mistura de permissões.

- Usuário sem vínculo não acessa post, mídia, rotina, agenda ou chat por URL direta.

- Flow aceita reação simples e não apresenta campo de comentário.

- Now expira visualmente após 24 horas.

- Moments impede publicação acima de 2 minutos conforme validação definida na spec.

- Professor conversa com responsável somente quando existe vínculo válido.

- Rascunho de rotina é preservado durante falha de conexão.

- Mídia privada não possui URL pública permanente e download está bloqueado por padrão.

# 23. Riscos e mitigação

| Risco | Impacto | Mitigação |
| --- | --- | --- |
| App virar rede social aberta | Crítico | Sem descoberta pública, RLS e audiência contextual. |
| Notificações excessivas | Alto | Agrupamento, preferências e prioridade. |
| Chat virar WhatsApp caótico | Alto | Canais contextuais, sem responsável–responsável e políticas institucionais. |
| Mídia elevar custo | Médio/alto | Compressão, limites, thumbnails e política de retenção futura. |
| Professor não registrar rotina | Alto | Lote, templates e rascunho local. |
| Contexto confuso | Alto | Contexto ativo visível e testes multi-papel. |

# 24. Decisões oficiais

| Decisão | Valor oficial v1 |
| --- | --- |
| Feed | Flow. |
| Conteúdo temporário | Now, 24h. |
| Vídeo longo | Moments, até 2 minutos. |
| Interação | Reações simples; sem comentários. |
| Professor–responsável | Conversa direta quando houver vínculo com a criança. |
| Responsável–responsável | Fora do MVP. |
| Download de mídia | Bloqueado por padrão. |
| Navegação | Flow, Rotina, Conversas, Agenda e Perfil/Contexto. |
| Offline | Offline-tolerant; full offline-first futuro. |

# 25. Perguntas em aberto

- Entrada final de Moments na navegação.

- Quais reações simples estarão disponíveis?

- Qual limite de tamanho de arquivo por tipo de mídia?

- Quais tipos de rotina aparecem por segmento?

- Qual ferramenta de push será usada?

# 26. Próximas specs

- Functional Specs separadas para Flow, Now, Moments, Rotina, Chat e Agenda.

- Technical Spec de estado Flutter, cache, uploads e notificações.

- Technical Spec de Realtime e RLS por módulo.

- Test Plan multi-contexto, mídia e sincronização.

- Protótipo navegável do App por perfil.

# 27. Aditivo 2026-07-24 — Experiência Familiar E Profissional

A mesma conta pode alternar entre experiência familiar e profissional sem misturar permissões. A UI deve sempre mostrar em qual instituição, unidade, turma, atividade e papel a pessoa está atuando.

Na experiência familiar:

- o adulto pode criar conta global antes de qualquer instituição, mas conta,
  e-mail e `@identificador` não concedem acesso;
- o responsável pode localizar exatamente instituição/unidade por `@`, e-mail,
  link ou QR e solicitar vínculo, que permanece pendente até validação;
- o cadastro infantil é híbrido: responsável ou instituição inicia, a
  instituição valida e cria seu contexto, vincula primeiro à unidade e pode
  alocar turma depois;
- o responsável vê somente crianças e contextos autorizados;
- a permissão `Gerenciar pessoas autorizadas` controla a lista de emergência, retirada e transporte;
- pessoa de confiança é privada e reutilizável pelo responsável; cada uso cria
  autorização independente para criança, instituição e unidade, sem pertencer
  à turma;
- uma autorização criada fica ativa imediatamente, e suspensão institucional
  gera aviso imediato sem afetar autorizações de outra unidade ou tenant;
- o responsável pode informar ausência, presença esperada, atraso, saída antecipada ou período futuro, com motivo, texto e anexo;
- eventos futuros geram lembrete no dia anterior;
- o aviso aparece como pendência até revisão profissional, inclusive como card acionável no chat.

Na experiência profissional:

- atividades, turmas, crianças e conversas aparecem somente dentro dos assignments;
- quem possui `Gerenciar presença` pode confirmar, corrigir ou desfazer registros, sempre com auditoria;
- mensagens mostram a pessoa real, o papel contextual e as crianças relacionadas;
- professor restrito a atividade conversa somente com seus participantes.

Em `Conversas`, `Todas` agrega por padrão apenas as conversas autorizadas;
filtros opcionais de tipo e o filtro separado de criança apenas restringem a
lista. Revogação de vínculo remove imediatamente a conversa operacional,
inclusive de cache e Realtime.

Encerrado o vínculo da criança com a instituição, os módulos deixam de aparecer
e o histórico de conversa fica somente leitura conforme a política de retenção
quando aprovada.

# Fontes e referências

## Fontes internas

- Coelo — Product Vision Oficial v1.

- Coelo — PRD Master Oficial v1.

- Coelo — História da Logo e Marca Oficial v1.

- Mapa competitivo de apps de agenda e comunicação escolar no Brasil.

- Decisões do fundador registradas em 21/06/2026 para os seis PRDs.

## Fontes externas oficiais

- Supabase — Row Level Security: https://supabase.com/docs/guides/database/postgres/row-level-security

- Supabase — Auth: https://supabase.com/docs/guides/auth

- Supabase — Storage Access Control: https://supabase.com/docs/guides/storage/security/access-control

- Supabase — Realtime Authorization: https://supabase.com/docs/guides/realtime/authorization

- Supabase — Edge Functions e secrets: https://supabase.com/docs/guides/functions e https://supabase.com/docs/guides/functions/secrets

- Flutter — App architecture: https://docs.flutter.dev/app-architecture

- ANPD — Enunciado sobre dados de crianças e adolescentes: https://www.gov.br/anpd/pt-br/assuntos/noticias/anpd-divulga-enunciado-sobre-o-tratamento-de-dados-pessoais-de-criancas-e-adolescentes

- ANPD — Comunicação de incidentes de segurança: https://www.gov.br/anpd/pt-br/assuntos/comunicacao-de-incidentes-de-seguranca-cis

- OWASP — ASVS: https://owasp.org/www-project-application-security-verification-standard/

- OWASP — MASVS: https://mas.owasp.org/MASVS/

Acesso às fontes externas: 21/06/2026. As referências jurídicas não substituem revisão por profissional habilitado.
