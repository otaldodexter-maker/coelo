---
source: "docs/product/prd-superadmin.md; docs/product/prd-master.md; docs/design/design-system.md; decisions/0014-contextual-activities-and-delegated-unit-creation.md; decisions/0020-backend-authorization-application-security.md; decisions/0021-operational-import-export-files.md; decisions/0022-superadmin-activities-and-identity-storage.md; specs/025-superadmin-daily-routine-models-applications-launches.md; aprovacoes do Owner Coelo em 2026-08-13"
status: "approved-design"
generated_at: "2026-08-13"
---

# Formulários e enquetes do Superadmin — desenho ponta a ponta

## Objetivo e problema

Entregar em `apps/superadmin` um módulo produtivo de Formulários, integrado ao
Supabase de ponta a ponta, para criar, distribuir, agendar, responder,
acompanhar e exportar formulários e enquetes rápidas dentro da hierarquia
Coelo. A experiência deve aceitar responsáveis, funcionários, professores,
atividades, turmas, unidades, instituições, pessoas específicas e perfis sem
confiar no cliente para resolver autorização ou audiência.

O módulo não é um protótipo local. A entrega inclui banco, RLS, RPCs, jobs,
Storage privado, Flutter real, auditoria, testes e estados operacionais. Admin
e Principal receberão implementações próprias em specs futuras; nenhuma tela
desses apps muda agora.

## Decisões centrais

- O módulo se chama **Formulários**.
- `Formulário` e `Enquete rápida` são tipos do mesmo domínio.
- Enquete rápida usa o mesmo motor, com uma intenção curta e uma pergunta
  principal, sem criar outro backend.
- Na implementação, a intenção da Enquete rápida é `description`: obrigatória
  após trim e limitada a 280 caracteres. Uma versão publicável contém exatamente
  um item de pergunta (nunca `information`). Rascunhos podem permanecer
  incompletos para preservar autosave e edição concorrente; o bloqueio é aplicado
  no pré-publish e no RPC de publicação.
- O diretório nasce em **Tabela**; Cards permanece disponível pelo toggle
  canônico.
- Um formulário possui identidade estável; versões técnicas são transparentes
  para o usuário.
- O mesmo formulário pode ter várias distribuições e vários agendamentos.
- O modelo de dados é híbrido relacional: relações e campos consultáveis em
  colunas/tabelas; `jsonb` somente para configurações variáveis.
- Não se cria tabela por formulário e não se persiste formulário/resposta como
  um único documento JSON.
- Respostas e mídia usam Supabase no MVP; migração futura para R2 preserva os
  IDs e contratos do domínio.
- Não existe MFA nesta entrega.

## Escopo por aplicação

### Superadmin nesta entrega

- Diretório, criação, edição, publicação e ciclo de vida.
- Construtor completo de seções, perguntas e ramificações.
- Distribuições, audiência dinâmica, agendamentos e lembretes.
- Prévia e teste não contabilizado.
- Experiência real de resposta para o próprio usuário elegível.
- Acompanhamento por hierarquia e pessoas.
- Diretório, detalhe e exportação de respostas.
- Operações excepcionais do Owner para participação anônima.

### Admin e Principal

- Nenhuma UI é implementada agora.
- O banco nasce preparado para Principal como respondente principal e Admin
  como gestor/respondente quando elegível.
- Apps privados compartilham domínio, auth, API e tokens, mas nunca importam
  telas entre si.
- `principal` nunca importa `coelo_ui_admin`.

## Arquitetura de informação

### Diretório

O item Formulários leva ao diretório table-first. A toolbar segue
Instituições: busca, filtros por tipo, situação, instituição, unidade, público
e período, toggle Cards/Tabela e ações autorizadas. Não existe painel lateral
de filtros.

Colunas mínimas da tabela:

- nome;
- tipo;
- instituição e unidade de origem quando houver;
- quantidade de distribuições/públicos;
- quantidade de agendamentos;
- período vigente;
- total de respostas;
- situação;
- atualização;
- ações.

Situações de diretório: rascunho, programado, ativo, encerrado e arquivado.
`FormStatus` continua sendo o ciclo de vida persistido (`draft`, `published`,
`archived`); a situação é uma projeção server-side sem coluna própria. A
projeção prioriza arquivado, rascunho, ocorrência em janela aberta (ativo),
ocorrência futura (programado) e encerrado nos demais publicados. Ocorrências
canceladas não tornam o formulário ativo ou programado. Quando coexistirem,
ativo prevalece sobre programado.
Ações: abrir, editar, testar, acompanhar, respostas, duplicar, copiar/mover,
arquivar e excluir quando permitido.

### Visão geral

Clicar no formulário abre página operacional com situação, versão vigente,
públicos, próximos agendamentos, elegíveis, respondeu, não respondeu e atalhos
para Editar, Testar, Acompanhar e Respostas. Cada destino tem URL própria; não
se usam abas decorativas para misturar contextos diferentes.

### Wizard lateral

Criar/Editar Instituição é a baseline. As etapas são:

1. Identificação.
2. Estrutura.
3. Aplicações/Distribuições.
4. Regras de resposta.
5. Agendamentos.
6. Revisão.

Wide e medium usam navegação lateral; compacto usa resumo acessível da mesma
hierarquia. O rodapé reutiliza `SuperadminFormActionFooter`.

## Construtor

### Seções e itens

- Cada seção é uma página da experiência de resposta.
- Seção possui título, orientação opcional, ordem e ações.
- Perguntas e blocos usam cards Coelo; apenas o item ativo fica expandido.
- Seções e itens podem ser duplicados, excluídos e reordenados.
- Drag-and-drop possui alternativas Mover para cima, Mover para baixo e Mover
  para seção por teclado e toque.
- Pergunta condicionada permanece no ramo; sair do ramo exige ação explícita.
- O formulário pode ter até 20 seções, 200 perguntas/blocos e 50 opções por
  pergunta, por versão.

### Catálogo fechado

Texto e número:

- texto curto;
- número inteiro;
- número decimal;
- dinheiro;
- data.

Escolhas:

- Sim/Não;
- escolha única;
- múltipla escolha;
- escala 1–5 ou 1–10.

Mídia:

- Foto, capturada pela câmera;
- Galeria, escolhida no dispositivo.

Estrutura:

- bloco informativo sem resposta, com título, orientação, separação visual e
  imagem de apoio opcional.

Texto longo, áudio, vídeo, documento, assinatura e localização não pertencem a
esta entrega.

### Configuração

Todos os itens aceitam título/pergunta, orientação e imagem de apoio quando
aplicável. Perguntas aceitam obrigatoriedade.

- Texto curto: tamanho máximo.
- Inteiro, decimal e dinheiro: mínimo/máximo opcionais.
- Data: data mínima/máxima opcionais.
- Escolha única: 2–50 opções.
- Múltipla escolha: 2–50 opções e mínimo/máximo de seleções.
- Escala: 1–5 ou 1–10 e rótulos opcionais nas extremidades.
- Foto/Galeria: mínimo/máximo entre 1 e 5 imagens.
- Bloco informativo não é obrigatório e não gera resposta.

### Ramificações

Somente Sim/Não, escolha única e múltipla escolha podem abrir ramos. Cada opção
pode revelar perguntas extras. Múltipla escolha reúne os ramos de todas as
opções marcadas. Profundidade máxima: quatro níveis. O backend impede ciclos,
referências inválidas e profundidade excedida. Quando uma alteração oculta um
ramo, seus valores deixam o envio e os resultados.

### Salvamento e prévia

Rascunho salva automaticamente com estados Salvando, Salvo e Falha ao salvar,
além de ação explícita Salvar rascunho. Comandos usam `expected_version`; conflito
nunca sobrescreve silenciosamente. Publicação é sempre explícita.

Pré-visualizar usa painel complementar apenas quando houver largura sem
comprimir o editor; em espaços menores abre página própria. Testar executa o
fluxo completo, inclusive rascunho, ramificação, mídia, revisão e confirmação,
mas não entra em resultados.

## Experiência de resposta

- Uma seção por página, com progresso textual e visual.
- Validação considera apenas perguntas obrigatórias visíveis.
- Rascunho salvo no backend.
- Revisão e confirmação explícitas antes do envio.
- A distribuição escolhe envio definitivo ou editável até o encerramento.
- Superadmin/Admin respondem como o próprio usuário e somente se elegíveis.
- Testar e Responder são ações diferentes.
- Foto usa câmera; Galeria usa conteúdo existente; ambas permitem no máximo
  cinco imagens por pergunta.

Em formulário anônimo, a interface usa exatamente a redação aprovada:

> **Suas respostas são anônimas e ninguém saberá que foi você que respondeu**

## Distribuições e audiência

Uma Distribuição é a representação de produto de `form_applications`. Ela
reúne público, unidade de resposta, obrigatoriedade, agendamentos, lembretes e
situação. Um formulário aceita várias distribuições.

### Hierarquia e relações

Cada distribuição pode selecionar:

- instituição;
- uma ou várias unidades;
- uma ou várias turmas;
- uma ou várias atividades;
- responsáveis/pais das crianças da hierarquia;
- professores vinculados a turma/atividade;
- funcionários;
- perfis;
- pessoas específicas.

Seleção aceita IDs explícitos ou todos os resultados de filtros autorizados,
com exclusões explícitas e resumo de revisão. O servidor recalcula tudo; IDs e
filtros do Flutter não concedem escopo.

### Audiência dinâmica

Durante ocorrência ativa, nova pessoa elegível recebe o formulário e entra nos
lembretes, preservando o prazo original. Quem perde o vínculo deixa de poder
responder. Respostas existentes permanecem. Participações distinguem Elegível,
Respondeu, Não respondeu e Perdeu elegibilidade. Eventos de vínculo fazem
atualização incremental; reconciliação periódica corrige eventos perdidos.

### Unidade da resposta

- Uma por pessoa.
- Uma por criança/contexto familiar: um responsável autorizado conclui para o
  contexto e os demais veem a conclusão.

Funcionários e professores respondem por pessoa.

### Sobreposição

Regras da mesma distribuição são deduplicadas por sujeito. Uma ocorrência não
cria duas participações para a mesma pessoa/contexto. Ocorrências realmente
distintas podem receber respostas distintas. Sobreposição acidental de janela
e público é avisada; equivalências que duplicariam a mesma ocorrência ficam
bloqueadas.

## Agendamentos e lembretes

Cada distribuição aceita vários agendamentos:

- único;
- diário a cada N dias;
- semanal a cada N semanas e dias escolhidos;
- mensal a cada N meses, por dia ou último dia do mês.

Encerramento por data, quantidade de ocorrências ou sem término. Não existe
recorrência anual. Cada ocorrência possui janela, fuso IANA, versão congelada,
participações e resultados próprios.

Lembretes podem ocorrer na abertura, antes do encerramento e a cada N dias.
Usam notificação interna e push, nunca e-mail. Param após resposta ou perda de
elegibilidade e usam chave idempotente.

## Calendário range Coelo

O controle nasce como variante aprovada do calendário canônico:

- dois meses consecutivos lado a lado em espaço amplo;
- um mês por vez no compacto;
- início, preenchimento do intervalo e término semânticos;
- hoje contornado e indisponibilidade legível;
- navegação mês/ano e atalhos contextuais;
- teclado, toque, foco, 48 px e texto a 200%;
- nunca `showDateRangePicker`.

A referência externa aprova somente a composição de dois meses. O padrão deve
ser registrado no índice/catálogo e possuir previews/testes/goldens antes de
ser consumido pela feature.

## Ciclo de vida e versionamento transparente

- Novo formulário nasce rascunho.
- Publicar congela versão imutável.
- Editar conteúdo publicado cria silenciosamente uma versão de trabalho.
- A identidade e os agendamentos do formulário permanecem.
- Ocorrências abertas ou concluídas nunca mudam de versão.
- Ocorrências futuras ainda não abertas passam à nova versão publicada.
- Relatórios preservam a versão respondida.
- Versão com histórico pode ser arquivada, nunca apagada.

Duplicar cria novo rascunho sem respostas. Copiar leva estrutura e,
opcionalmente, distribuições, nunca histórico. Rascunho nunca publicado pode
ser movido entre unidades/instituições. Transferência entre instituições é
exclusiva do Superadmin. Publicado, agendado ou respondido cria cópia como
rascunho no destino e preserva o original.

Exclusão definitiva vale somente para rascunho nunca publicado, sem
agendamento ou respostas. Demais registros apenas arquivam.

## Acompanhamento

Página contextualiza formulário, distribuição, ocorrência/período, filtros e
atualização. Cards resumem elegíveis, respondeu, não respondeu, perdeu
elegibilidade, participação e prazo; tabela permanece principal.

### Hierarquia

Drill-down pela hierarquia realmente usada: instituição → unidade → turma →
atividade → perfil. A projeção é materializada por ocorrência e exposta somente
pela RPC autorizada com cursor opaco; um `scope_id` precisa pertencer ao próprio
formulário e tenant antes de abrir o próximo nível. Colunas: nível, elegíveis,
respondeu, não respondeu, perdeu elegibilidade, participação e situação.

### Pessoas

Lista somente pessoa, perfil, contexto aplicável e Respondeu/Não respondeu.
Não exibe conteúdo nem horário individual. Em anônimos, usuários comuns veem
apenas agregados. O `platform_owner` usa a ação separada Consultar participação
anônima, informa motivo e gera auditoria.

## Respostas

O diretório usa uma linha por envio: ID, formulário/versão,
distribuição/ocorrência, pessoa quando identificada, contexto, situação,
enviado em, atualizado em e Visualizar resposta. Usa cursor; conteúdo só é
carregado no detalhe.

O detalhe preserva a versão e ordem originais. Anônimos não exibem pessoa,
participação, ID comum ou ordenação/horário que facilite correlação.

## Exportações

`forms.responses.export` é a única exportação funcional do MVP. Cada formulário
nasce, sem toggle ou configuração adicional, com a ação de gerar **um arquivo
XLSX contendo suas respostas**. A ação fica no contexto do formulário e do
diretório de respostas para quem possuir a capability; não existe exportação de
uma resposta isolada.

O job é server-side, idempotente, auditado e privado. Revalida ator,
capability, tenant, formulário, versões, distribuições/ocorrências e escopo das
respostas. O artefato fica no Cloudflare R2 privado sob `exports/...`, e o
download exige ticket/URL temporária após nova autorização. CSV, ZIP, PDF,
exportação por resposta e demais exportações do Superadmin ficam pós-MVP.

### Formato tabular

- Metadados/referências-mãe primeiro.
- Uma coluna por pergunta na ordem do formulário.
- Tipos permanecem tipados.
- Uma única coluna por pergunta Foto/Galeria.
- Cada mídia é hyperlink `Ver mídia` para rota protegida Coelo; a rota reautoriza
  e só então gera URL temporária do R2.
- Nunca inserir URL assinada permanente no arquivo.
- Incluir ID da resposta, ID da ocorrência, ID do item, Pergunta expandida e
  versão.

O workbook pode usar abas auxiliares para valores multivalorados e mídias,
preservando IDs e referências à linha da resposta sem produto cartesiano falso.
O contrato físico das abas deve ser versionado e testado antes do cutover.

### Mídia no XLSX

O XLSX não incorpora binários nem gera ZIP. Registra links protegidos por IDs
opacos; cada clique reautoriza e emite acesso temporário. Em respostas anônimas,
nomes, abas, IDs e caminhos não podem permitir correlação com pessoas.
Artefatos de exportação expiram e recebem cleanup; originais seguem sua política
de retenção própria.

### Participação anônima

Consulta nominal permanece exclusiva do `platform_owner`, com motivo e
auditoria. A exportação real de participação anônima fica pós-MVP; seu botão,
quando presente, informa a indisponibilidade. Nenhuma consulta contém respostas,
ID da resposta, horário exato ou chave comum com o conteúdo anônimo.

## Modelo de dados aprovado

### Definição

- `forms`
- `form_versions`
- `form_sections`
- `form_items`
- `form_question_options`
- `form_question_conditions`
- `form_item_assets`

`form_items` unifica ordem de perguntas e blocos. `config_jsonb` guarda somente
configuração tipada por RPC/constraint; hierarquia e campos de consulta ficam
relacionais.

### Distribuição

- `form_applications`
- `form_audience_rules`
- `form_schedules`
- `form_schedule_reminders`
- `form_occurrences`
- `form_participations`
- `form_participation_responders`

### Coleta

- `form_responses`
- `form_answers`
- `form_answer_options`
- `form_answer_assets`
- `form_response_revisions`

Respostas simples usam colunas tipadas: texto, inteiro, decimal, dinheiro em
unidade mínima, data, booleano e avaliação. Opções e mídias usam linhas
relacionadas; não há um JSON de respostas gigante.

### Operação

- métricas de ocorrência;
- métricas por escopo;
- recibos idempotentes;
- outbox/reuso do domínio de notificações;
- jobs operacionais e auditoria existentes.

## Anonimato técnico

Em identificado, resposta referencia participação/pessoa. Em anônimo,
participação guarda elegibilidade e Respondeu/Não respondeu, mas resposta não
possui `person_id`, `participation_id` ou chave comum. Envio atualiza participação
e cria conteúdo desacoplado na mesma transação, sem colocar ambos no mesmo
evento de auditoria.

Edição anônima usa segredo opaco retornado ao dispositivo; somente hash fica
na resposta. O segredo não usa identidade, não entra em logs e permite editar
até o encerramento. Se for perdido, a edição não pode ser recuperada. A UI
explica que a edição anônima permanece naquele dispositivo.

O modo identificado/anônimo fica imutável após a primeira publicação.

## Cloudflare R2 no MVP

Formulários usam Cloudflare R2 privado para imagens de apoio, Foto, Galeria e
artefatos XLSX. Supabase/Postgres guarda provider, object key opaca, MIME,
tamanho, checksum, status, ownership, retenção e vínculos sob RLS. O caminho é
emitido pelo Media Gateway; extensão, MIME real, tamanho, checksum e ownership
são validados. Limite inicial: cinco imagens por pergunta, 10 MB por imagem,
JPEG/PNG/WebP. Não há URL pública nem segredo no cliente.

Upload abandonado e artefato expirado recebem cleanup. Resposta e mídia
original seguem retenção própria. A ADR 0032 é canônica e supersede qualquer
menção histórica de Supabase Storage nesta spec.

## Permissões e autorização

Capabilities:

- `forms.read`
- `forms.manage`
- `forms.publish`
- `forms.manage_applications`
- `forms.monitor`
- `forms.responses.read`
- `forms.responses.export`
- `forms.transfer_cross_institution`
- `forms.anonymous_participation.read`
- `forms.anonymous_participation.export` (catálogo preservado, execução real
  adiada para depois do MVP)
- `forms.respond`

Transferência cross-institution exige papel de plataforma Superadmin e
capability. Participação anônima nominal é exclusiva do `platform_owner`.
Responder exige elegibilidade. Não existe MFA.

Toda tabela exposta usa RLS habilitada e forçada. Escrita direta do cliente é
revogada. RPCs validam ator, capability, tenant, hierarquia, ownership,
request-id, versão e inputs. Grants são mínimos/explicitos. Funções
privilegiadas usam `search_path = ''`, não dependem de `user_metadata` e nunca
expõem `service_role`.

O contrato é backend-first: capabilities recebidas ou inferidas pelo Flutter
servem somente para compor a interface. Cada consulta, comando, download e job
revalida a capability efetiva no backend; ocultar uma ação na tela nunca
autoriza nem substitui RLS/RPC. `FormMediaResolver` recebe apenas `asset_id` e,
quando anônimo, o segredo opaco de edição; ele solicita uma URL assinada curta
pela rota `form-media`, que reautoriza o acesso antes de revelar o ticket. O
resolver nunca persiste URL permanente nem acessa Storage diretamente.

## Comandos e consultas

Comandos compostos cobrem criar/salvar, publicar, duplicar/copiar/mover,
arquivar, salvar distribuição/agendamento, reconciliar participantes, gerar
ocorrência/lembrete, abrir/salvar/enviar/editar resposta, preparar/finalizar
upload e solicitar exportação. Todos recebem `request_id`; mutações concorrentes
recebem `expected_version`.

Consultas devolvem projeções específicas para diretório, editor, visão geral,
acompanhamento, pessoas, respostas, detalhe e jobs. Flutter não monta joins nem
faz N+1.

## Desempenho

- Índices compostos seguem filtros reais de instituição, status, data e cursor.
- Todas as FKs e colunas RLS recebem índices necessários.
- Índices parciais cobrem versão de trabalho, ocorrências programadas/ativas,
  pendências e jobs disponíveis.
- Diretórios/respostas usam cursor, nunca paginação profunda com `OFFSET`.
- Perguntas, respostas e mídias carregam sob demanda.
- JSON não participa de filtros críticos.
- Métricas de ocorrência e escopo são atualizadas transacionalmente e podem ser
  reconstruídas por reconciliação.
- Geração de ocorrência/jobs usa chave idempotente, claim/lease e
  `FOR UPDATE SKIP LOCKED`.
- Transações não mantêm locks enquanto chamam serviços externos.
- Exportação é streaming e não acumula o dataset no Flutter.
- Particionamento só entra com evidência de necessidade.

Validar consultas críticas com dados representativos e
`EXPLAIN (ANALYZE, BUFFERS)`, advisors Supabase e teste de cursor profundo.

## UI e acessibilidade

Baselines obrigatórias:

- Instituições para diretório, tabela, cards, toolbar, estados e paginação.
- Criar/Editar Instituição para wizard, campos, navegação e rodapé.
- Rotina Diária para ordenação/condições, sem importar widgets de domínio
  inadequados.
- Avisos para audiência dinâmica, sem acoplamento de feature.
- Calendário Coelo para a nova variante range.

Componentes compartilhados prevalecem. Não usar `DataTable`,
`PopupMenuButton`, `MenuAnchor`, dropdown/radio/checkbox Material cru,
`showDatePicker` ou `showDateRangePicker` dentro da feature. Filtros ficam na
toolbar; as referências externas não aprovam paleta, tipografia ou overlay.

Validar 375, 768, 1024 e 1440 px, light/dark, texto a 200%, foco, teclado,
mouse, toque, 48 px, reduced motion e contraste WCAG 2.2 AA. Previews Flutter
cobrem novos componentes/estados.

## Estados de UX

- Diretórios: loading, conteúdo, vazio, sem resultados, erro/retry e sem acesso.
- Formulário: inicial, alterado, salvando, salvo, conflito, erro por etapa,
  publicado e falha sem perder dados.
- Resposta: não iniciada, rascunho, validando, enviando, enviada, editável,
  encerrada, inelegível e erro recuperável.
- Jobs: aguardando, processando, concluído, expirado, dividido em partes e
  falhou.
- Mídia: escolhida, preparando, enviando, pronta, falhou, órfã e indisponível.

## Eventos, logs e notificações

Auditar criação, edição, publicação, distribuição, duplicação/cópia/movimento,
arquivamento/exclusão, acesso/export de participação anônima, export/download,
upload/finalização/descarte e edição identificada. Auditoria guarda resumos,
nunca resposta/foto integral.

Notificações reutilizam o domínio existente e outbox. A intenção possui chave
idempotente; falha de push não anuncia sucesso. Retry tem limite/backoff.

## Testes exigidos

### Banco/Supabase

- schema, constraints, tipos, limites, ciclos e profundidade;
- RLS, grants, cross-tenant e BOLA/IDOR;
- capabilities e Owner-only;
- versionamento, publicação e agendamentos preservados;
- audiência dinâmica, elegibilidade e deduplicação;
- pessoa/contexto familiar;
- concorrência de envio/ocorrência/job;
- separação identificada/anônima;
- Storage privado, path, MIME, tamanho e ownership;
- exportação, streaming, expiração e neutralização de fórmulas;
- paginação, índices e planos de consulta.

### Flutter

- domínio, validação, serialização e estados;
- diretório, wizard e salvamento;
- todos os tipos de item;
- drag/teclado/toque e movimento entre seções;
- ramificações;
- público, recorrência e lembretes;
- calendário range;
- teste e resposta real;
- edição identificada/anônima;
- acompanhamento e respostas;
- exportações, foco, semântica e estados de erro.

### Integração

1. Criar → estruturar → distribuir → agendar → publicar.
2. Gerar ocorrência → resolver elegíveis → lembrar.
3. Responder → acompanhar → detalhar → exportar.
4. Rascunho → editar → enviar.
5. Alterar publicado sem reagendar.
6. Anônimo → responder → agregado → operação excepcional do Owner.
7. Upload R2 → resposta → visualizador protegido → XLSX com links protegidos.
8. Entrar/sair da hierarquia durante ocorrência ativa.
9. Duplicar, copiar e mover.
10. Arquivar e impedir exclusão com histórico.

Goldens mínimos: diretório mobile light/desktop dark, construtor mobile
light/desktop dark, ramo expandido, calendário range, experiência de resposta,
acompanhamento e respostas. Executar validador visual do catálogo, analyze,
testes Flutter, pgTAP, Edge Functions/workers, advisors, secret scan, diff final
e gate de conhecimento.

## Critérios de aceite

1. Nenhum fluxo de produção depende de fake ou sucesso local.
2. Um mesmo formulário mantém identidade/agendamentos após edição publicada.
3. Ocorrências abertas preservam estrutura histórica.
4. Audiência dinâmica recebe novos elegíveis e remove autorização obsoleta.
5. Respostas identificadas e anônimas respeitam contratos distintos.
6. Somente Owner consulta participação nominal anônima, com motivo; exportação
   real desse relatório permanece pós-MVP.
7. Uma tabela nova não é criada por formulário.
8. Diretórios e respostas paginam por cursor e carregam detalhes sob demanda.
9. Exportação reproduz colunas por pergunta e linhas expandidas conforme o XLSX
   de referência.
10. Hyperlink de mídia reautoriza no Coelo e não expõe URL permanente.
11. R2 é privado; Supabase preserva metadados, autorização e auditoria.
12. UI respeita baselines, responsividade, acessibilidade e estados Coelo.
13. Admin e Principal não recebem alterações nesta entrega.

## Fora de escopo

- recorrência anual;
- e-mail;
- texto longo;
- áudio, vídeo, documento, assinatura e localização;
- exportação CSV, ZIP, PDF ou de resposta individual;
- MFA;
- retenção automática de respostas/mídias originais;
- UI no Admin e Principal;
- BI/gráficos avançados;
- edição colaborativa simultânea.

## Riscos e decisões canônicas necessárias

- Fechar contrato versionado das abas XLSX, limites, expiração e cleanup do
  artefato no R2 antes do cutover.
- A ausência de retenção automática exige revisão jurídica/LGPD futura.
- A redação anônima aprovada afirma que ninguém saberá quem respondeu, enquanto
  o Owner pode consultar/exportar participação; a cópia é decisão explícita do
  Owner, mas deve passar por revisão jurídica antes de produção pública.
- Push ao Principal depende da futura superfície do app, embora backend/outbox
  sejam entregues agora.
- O segredo de edição anônima perdido não é recuperável sem quebrar a separação
  entre identidade e conteúdo.

## Meta de execução

Cinco horas é meta, não critério de aceite. `ponytail` orienta reutilização e o
menor desenho que cumpra todo o contrato, mas não simplifica segurança, RLS,
validação, acessibilidade, testes ou integração real. Trabalho restante deve
ser relatado; conclusão falsa é proibida.
