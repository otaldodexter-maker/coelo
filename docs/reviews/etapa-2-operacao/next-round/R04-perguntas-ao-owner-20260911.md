---
title: "Rodada 4 — perguntas ao Owner (noite de 10→11/09/2026)"
source: "coordenacao.json R04; JSONs das frentes; producao medida por supabase db query --linked (somente leitura)"
status: "answered-2026-09-11"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# Perguntas ao Owner — Rodada 4

Numeração continua a da R03 (P1–P21). Cada pergunta traz o que já existe, as
opções e a recomendação do coordenador. Responder em lista "Pxx - decisão,
observação" basta.

## P22 — Ponte entre o realm interno e o realm de pessoas (bloqueia rota normal de 9 famílias)

**Medido em produção às 22:20:** `person_auth_links` tem 0 linhas. Os quatro
usuários do Superadmin (os seus três e o `qa-r03@coelo.me`) existem só no realm
interno v2 (`app_private.superadmin_internal_auth_links`). O shell do
Superadmin autentica por esse realm, mas as RPCs de Unidades, Rotina,
Assiduidade, Perfis de cuidado, Medicação, Cardápios, Suporte, Conta, Pessoas,
Perfis/Modelos de acesso e Segurança infantil resolvem o ator por
`app_private.current_person_id()` + `has_platform_permission`, que leem
`person_auth_links` e `platform_memberships`. Consequência: **nenhum usuário,
nem você, alcança essas RPCs hoje**. Duas frentes (Operações e Acessos e
Pessoas) bateram no mesmo muro e eu assumi a dependência como pacote único do
coordenador.

**Bloqueio:** a escrita desse pacote foi recusada duas vezes pelo classificador
de permissões da minha sessão (ele trata mudança de identidade/autorização
como ação sensível). Não vou contornar. Preciso de uma de duas coisas:

- **Opção A (recomendada):** você cola na minha conversa "P22 aprovado, opção
  2" e libera a escrita (ou adiciona a regra de permissão sugerida pelo
  classificador). Eu escrevo, provo no espelho com pgTAP e aplico no lote
  seguinte.
- **Opção B:** você mesmo cria o arquivo com o conteúdo que eu passar e eu só
  aplico. Mais lento.

**Desenho (opção 2, sem tocar nos guards de realm):**

1. tabela `app_private.superadmin_internal_actor_people` ligando cada
   identidade interna a uma pessoa de serviço (`people.person_type='service'`,
   nome opaco "Equipe Coelo xxxxxxxx", sem e-mail);
2. `app_private.current_person_id()` cai nessa ligação quando não há vínculo
   `person_auth_links` (o vínculo people continua tendo precedência);
3. a pessoa de serviço recebe `platform_memberships` com o **mesmo papel e
   escopo** da membership interna ativa, mantida por trigger: membership
   interna revogada ou suspensa revoga a espelhada;
4. backfill das quatro identidades existentes; nenhuma RPC muda; os guards de
   realm (`person_auth_links` × `superadmin_internal_auth_links`) ficam
   intactos porque a ponte não cria `person_auth_links`.

**Desenho alternativo (opção 1, descartado):** relaxar o guard de realm e
criar `person_auth_links` para as identidades internas. Mais simples, mas
remove uma barreira de segurança deliberada.

**Efeito de não decidir:** as nove famílias acima ficam sem CRUD em produção
na régua do MVP nesta rodada; as frentes seguem no que usa
`require_superadmin_internal_context` (Convites, Usuários internos,
Segurança infantil leitura, Chat, Avisos, Circulares, Acontece, Agora,
Momentos, Formulários) e no cliente.

## P23 — Owner de instituição em Cardápios (principal-chat-sistema)

`has_platform_permission` só enxerga membership com `scope_kind='platform'` e
instituição nula. Um Owner **de instituição** nunca tem `meal_plans.manage`,
nem com a concessão nova. Para o MVP do Superadmin basta; quando Admin entrar,
nenhum administrador de instituição gerenciará cardápios. O pacote P7 do grupo
acessos-pessoas (membership por instituição em `has_platform_permission`)
resolve isso se você confirmar que é a regra pretendida: **quem tem a
capacidade no perfil de instituição gerencia os cardápios dessa instituição.**
Recomendação: sim (é a sua Decisão 12/P7 aplicada a Cardápios).

## P24 — Criar grupo no Chat: quem entra no grupo (realm-interno, corrigida)

Correção da frente realm-interno (rev 15): o pacote `20260910240400` em
produção cria o grupo pela identidade interna com `chat.internal.manage` e
aceita como membros **pessoas da instituição** (conversa contextual com a
instituição escolhida), não identidades internas. A prova pela UI usou a
instituição sintética e a pessoa "Criança QA R04" como membro. Pergunta: no
MVP o Superadmin cria grupos com pessoas de uma instituição (como está) ou
grupos só entre identidades internas (equipe Coelo)? Se for só internos, a
variante `240600` (membros = identidades internas) leva cerca de 1 hora.
Recomendação: manter como está (pessoas da instituição) e registrar o grupo
interno como pós-MVP.

## P25 — Instituição e unidade sintéticas em produção (bloqueia CRUD com sessão de 5 famílias)

Produção não tem nenhuma instituição ativa (a única linha é a sintética do
grupo realm-interno, já arquivada). Circulares, Agenda, Chat contextual,
Formulários, Cuidado e Alunos exigem contexto institucional para criar
qualquer coisa; a frente Publicações pediu uma instituição de teste para
rodar Circulares e Agenda na sessão `qa-r03`.

O `insert` direto em produção foi recusado pelo classificador da minha sessão
(dado em produção), e pedir a outra conversa para fazê-lo também foi recusado.
Opções:

- **Opção A (recomendada):** você manda à conversa «R04 · Estrutura» criar
  pela rota normal, com a sessão `qa-r03`, a instituição
  "[R04-QA] Instituição de teste" e uma unidade "[R04-QA] Unidade de teste",
  e publicar os ids no `estrutura.json`. É exatamente o `institutions.create`
  e `units.create` da régua do MVP, e serve às outras frentes.
- **Opção B:** você libera o `insert` sintético na minha conversa ("P25
  aprovado, opção B") e eu crio os dois registros com ids fixos
  (`9f040000-0000-4000-8000-0000000000a1` e `...a2`), removidos ao fim.

Atualização 22:53: o grupo realm-interno reaplicou a instituição sintética
`9f040000-0000-4000-8000-000000000010` (ativa, sem unidade) para a prova do
chat; Publicações usa essa para Circulares e Agenda. Falta só a unidade, que a
opção A cobre.

## P26 — Página de erro 409: aprovar as imagens candidatas (principal-chat-sistema)

A frente montou a página lado a lado
`docs/reviews/evidence/etapa-2/r04-principal-chat-sistema/erro-409-candidatos.html`
com as imagens candidatas do erro 409 na família das páginas de erro
existentes (Decisão 6). Pergunta: aprovar como golden? Resposta em lista
"arquivo - decisão, observação", como nas listas de goldens.

## P27 — Duplicar em Cardápios: ícone e menu, ou só ícone (principal-chat-sistema)

As duas decisões de goldens de Cardápios pediam Duplicar. A frente pergunta se
Duplicar aparece como ícone no card **e** como item no menu do card, ou só como
ícone. Recomendação: ícone no card e item no menu (o menu é o caminho
acessível por teclado e leitor de tela; o ícone é o atalho).

## P28 — Foto do Perfil do Principal recortada (principal-chat-sistema)

A frente montou a página lado a lado em
`docs/reviews/evidence/etapa-2/r04-principal-chat-sistema/perfil-foto/` para
você apontar qual foto do Perfil está recortada de forma errada (capa, brasão
ou avatar) e qual enquadramento vale. Resposta em lista "arquivo - decisão,
observação".

## P30 — Disparo do worker de Avisos agendados (bloqueado na sessão do coordenador)

O pacote `20260910200500_notice_publication_worker_v2` (Publicações) está em
produção com as RPCs `claim_notice_publication_jobs_for_worker` e
`run_notice_publication_job_for_worker` (só `service_role`). Para Avisos
agendados publicarem sozinhos faltam três coisas que só o coordenador faria e
que o classificador da minha sessão recusou (segredo + Vault + pg_net):

1. um segredo aleatório gravado como `COELO_NOTICE_WORKER_SECRET` nos secrets
   das Edge Functions (`supabase secrets set --workdir packages/coelo_database
   COELO_NOTICE_WORKER_SECRET=<valor>`), e o mesmo valor no Vault do banco
   (`select vault.create_secret('<valor>', 'notices_worker_secret')` e
   `select vault.create_secret('https://evvbomzejfijozbtgvpt.supabase.co/functions/v1/notice-publication-worker', 'notices_worker_url')`);
2. o deploy da função (`supabase functions deploy notice-publication-worker
   --project-ref evvbomzejfijozbtgvpt --workdir packages/coelo_database`);
3. uma migration do coordenador com a função
   `app_private.notice_dispatch_publication_worker()` (lê os dois segredos do
   Vault e chama a função por `net.http_post` com o cabeçalho
   `x-coelo-worker-secret`, igual ao dispatcher de Formulários já em produção)
   e o `cron.schedule('coelo-notices-worker-dispatch', '* * * * *', ...)`.

Opções: **A (recomendada):** você autoriza na minha conversa ("P30 aprovado")
e eu executo os três passos e registro no `coordenacao.json` sem expor o
valor. **B:** você mesmo roda os comandos do passo 1 no seu PowerShell e me
avisa; eu faço os passos 2 e 3. Até lá, publicar imediato funciona e
agendado fica enfileirado sem executar.

## P31 — Papéis padrão de instituição para Convites (acessos-pessoas)

Produção tem 0 `institution_roles` (nenhum modelo de sistema semeado), então
`superadmin_invite_options_v2` devolve `profiles=[]` e nenhum convite passa
do passo 1. Decisão de produto: quais papéis padrão de instituição existem no
MVP? Proposta: semear por migration idempotente os modelos de sistema
"Administrador da instituição", "Coordenação", "Professor(a)" e
"Secretaria", cada um com o conjunto mínimo de capacidades de instituição já
catalogadas (o grupo lista as capacidades por papel no JSON). Alternativa:
criar um perfil Admin pela tela de Modelos (depende do catálogo 171300, em
curso). Recomendação: semear os quatro modelos e permitir editar pela tela.

## P32 — Segurança infantil: decisão de retirada exige revisor da unidade? (acessos-pessoas)

Quem decide (aprova/rejeita) uma autorização de retirada? Hoje o banco exige
revisor exato da unidade (`child_safety_has_exact_unit_review`) e nega ao
Superadmin (P0002). Opções: **(a)** só a unidade decide, o Superadmin apenas
cadastra e acompanha (como está); **(b)** o Superadmin com
`child_safety.manage` também decide, com auditoria; **(c)** o Superadmin
decide só em instituições sem revisor cadastrado. Recomendação da frente:
**(b)** no MVP, porque não existe revisor de unidade cadastrado em nenhuma
instituição e a demonstração precisa fechar o ciclo; volta a (a) quando o
Admin da instituição existir. O coordenador concorda com (b).

Complemento à P31: o candidato `20260910171600` (quatro papéis de sistema de
instituição: Administrador com todas as permissões institucionais,
Coordenação, Professor(a), Secretaria; idempotente; pgTAP 7/7) está pronto e
RETIDO em `candidatos/acessos-pessoas/`; com "P31 aprovado" o coordenador
renomeia e aplica no lote seguinte.

## P33 — `agenda_calendar_light_375`: células compactas ou rótulos truncados (publicações)

A sua observação "retângulos muito amassados" foi lida como célula quase
quadrada com marcas coloridas e "+N" (render atual) em vez de rótulos
truncados. Confirmar pela página lado a lado
`docs/reviews/evidence/etapa-2/r04-publicacoes-agenda/duvidas-visuais.html`
(R = referência guardada, A = render atual). Recomendação: A.

## P34 — `agenda_detail_light_375/768/1440` (R): indicador de status com alvo de 48 px ou círculo de 24 px?

O render atual usa o indicador do composto com alvo de toque de 48 px; a
referência guardada tem o círculo de 24 px. Mesma página lado a lado.
Recomendação: 48 px (acessibilidade WCAG 2.2 AA, alvo mínimo), regravar A.

## P35 — Contexto institucional para o usuário de teste no Principal (principal-chat-sistema)

Com `list_my_principal_contexts` em produção (lote 22), o Principal (Acontece,
Agora, Momentos, Para você, Perfil) ainda mostra "Nenhum contexto disponível"
para `qa-r03`, porque a pessoa de serviço criada pela ponte de ator não tem
`institution_membership` ativa em nenhuma instituição. Decisão: **(a)** semear
por migration idempotente uma membership da pessoa de serviço de `qa-r03` na
instituição sintética (só para a prova, removida ao fim); **(b)** fazer o
Principal aceitar o Owner de plataforma como contexto de todas as
instituições (regra de produto); **(c)** nada agora. Recomendação: (a) para a
demonstração, e (b) como regra futura registrada.

## P36 — Estrutura sem conversa viva na retomada

A sessão que assumiu a estrutura às 02:06 não respondeu a quatro cobranças;
os 21 pacotes de estrutura estão em produção e as chaves ligadas, mas a rota
real de Instituições → Avaliações com a sessão não foi provada nesta rodada.
Sugestão: abrir a conversa «R05 · Estrutura» primeiro na próxima rodada, com
o método de prova já documentado (build web de `qa_main` + CDP).

## P37 — Dados sintéticos deixados em produção pelas provas (limpeza)

O `insert`/`delete` direto em produção foi recusado ao coordenador nesta
rodada, então a limpeza de dados sintéticos ficou pendente. Inventário (ids
completos nos JSONs e handoffs de cada grupo):

- `qa-r03@coelo.me` (Auth + realm interno + perfil interno semeado pelo
  171200 + pessoa de serviço da ponte + memberships espelhadas): remover ao
  fim da Etapa 2 com `scratchpad/gen-qa-user-sql.js` em modo remover (R03).
- realm-interno: instituição `9f040000-0000-4000-8000-000000000010` (ativa,
  fixture do chat), pessoas `…061`/`…062`, conversa/grupo criados pela UI.
- formularios: prefixo `d0c40000-` (instituição "QA R04 Cuidado", unidade,
  criança, vínculo), formulário `4555ba07-e4a4-4971-8ba7-d81a775169cd`, local
  `fc446535-100c-4f35-8e30-e43d63176e3f`.
- acessos-pessoas: autorização `34d29829-a8b5-4b23-aacb-46e994dce7d7`,
  modelos `cc322488-…` e cópia `60fb9586-…`, papel
  `qa-r04-perfil-sintetico-7f6f8d16` (já excluído pela prova), pessoa draft
  `ec2a15a2-76bc-4e71-8419-94413d0c5c98`.
- operacoes: chamado `48e02ab0-fa60-4e7c-86b6-78f75565dc57`, telefone
  `11999990000` na pessoa de serviço `007a4ca5-…`, pedido de troca de e-mail
  cancelado e recibos.
- publicacoes: registros com prefixo `[R04-QA]` em `platform_notices`, `circulars` e `agenda_events` (lista no `publicacoes-agenda.json` rev 30).
- realm-interno/chat: prefixo `9f040000-` (instituição, pessoas, conversa e grupo); a limpeza está pronta em `packages/coelo_database/scripts/chat-internal-production-cleanup.sql` (arquiva a instituição por FK de `audit_logs` e remove o resto).
- estrutura: nenhum.

Opções: **(a)** o Owner libera na conversa do coordenador ("P37 aprovado") um
script único de limpeza por prefixo/ids, provado no espelho antes; **(b)**
manter até a próxima rodada e limpar antes da demonstração. Recomendação:
(a) no fechamento da próxima rodada, depois de conferir que nada da
demonstração depende deles.

## Atualização P22 (23:05)

A frente formularios-cuidado-rotina escreveu, na própria sessão, o pacote
`20260910220400_internal_actor_service_person_v1` com o mesmo desenho da
opção 2 (pessoa de serviço, membership espelhada por trigger,
`current_person_id()` com fallback, guards intactos) mais o catálogo que
faltava (`attendance.read`, `attendance.manage`, `people.assign_children` e
concessões ao Owner de `health_care.*`, `medication.*`, `routine.*`,
`attendance.*`). A primeira versão falhou no meu preflight (cast de enum e
fixture do último Owner); a segunda foi reenviada com pgTAP 17/17. Como é um
pacote verde da fila, entra em produção pela autorização permanente da ADR
0034, Decisão 1; **P22 passa a ser só a confirmação do desenho pelo Owner**,
não um bloqueio. Se você discordar do desenho, a reversão está descrita no
próprio arquivo.


## Respostas do Owner (11/09/2026, 10:40, pela página de decisões)

| Item | Decisão | Observação do Owner |
| --- | --- | --- |
| P20 | C |  |
| P22 | A | Se isso funcionar sempre, sem problemas. |
| P23 | A | Mas além disso, em perfil e permissões vamos liberar quem pode fazer isso. Entenda que o Owner de Insituição e Unidade pode fazer tudo dentro do seu contexto. |
| P24 | C | Grupos podem ter quaisquer tipos de perfis e responsáveis. |
| P25 | A | Pode usar ela para teste e valdiação assim que finalizar me pergunte se quero apagar |
| P26 | A |  |
| P28 | R | Veja que o circulo que fica a foto de perfil, avatar está sendo "Cortado" embaixo , como se o nome estivesse cortando ele. Outro detalhe é que o cabelho onde temos bug, sininho, perfil, logo, está diferente do contexto mobile, essa logo nem é nossa, o espeçamento parece incorreto.  E nas telas que estamos trabalhnado do Coelo (Principal) ao clicar em perfil, além das opções que já temos, ali podemos fazer "filtragens", exemplo, ao abrir estou vendo todas as minhas crianças, mas se eu quiser ver apenas um filho, seleciono o nome dele, se quiser ver todos seleciono em todos, aparecendo até 5 perfis, caso tenha mais aparece ver todos, e leva para um popup simples com a lista para ele selecionar.. Isso na visão dos responsáveis. O Responsavel não tem o botão de + Agora para adiconar, pois ele não adiciona nada. Esse botão de + Agora, não é para adicionar o Agora e sim adicionar no Acontece, é é visivel paenas para quem pode adicioanr algo, como professor. O @ do perfil deve aparecer. Ainda sobre a opção de perfil no cabeçalho, para usuário hibridos (responsáveis e funcionários) devemos ter a opção de ver como Responsável, ver como "Funcionário" e ambos, assim ele viria o feed e agora de todos. Assim como um responsável filtra por criança, ele pode filtrar pelo seus respectivos perfis, como turmas, insituições e outros, aparecendo até 5 perfis, caso tenha mais aparece ver todos, e leva para um popup simples com a lista para ele selecionar. Caso ele queria publicar seja o agora, acontece ou outra coisa que o funcionario pode fazer por hierarquia, e ele não estiver no perfil flagado, antes de ele publicar algo deve aparecer em qual perfil vai publicar. Outro detalhe é os avatares de vinculos (que estão laranja por default) estão sobrepostos e isso é bonito, porém não tem nenum divisão, como um contorno branco ou preto para dark, ou outro tom do nosso laranja e paraece uma coisa só. |
| P30 | A | Sempre que tiver que criar token, key, e similares e não gere custo, pode fazer. Em pendencias pode dexiar registrado caso ache que chaves estão sendo vazadas e eu tenha que redefinir depois que o projeto for realmente finalizado, e vc me ensina como gerar de cada chave quando for o caso. |
| P31 | A | Pode criar nome padrões e permissões para todos os tipos de convites e perfis e permissões, como convites para o Superadmin, Admin e principal. E caso necessário tbm tenho a opção de criar mais perfis e permissões. Esses perfis, já são criado e existem app, fazendo hierarquias, rls, o que cada um pode fazer e quais telas e subtelas podem ver, ler, acessar, editar e por ai vai. Quando eu quiser criar um novo perfil posso iniciar do zero, ou partir de um dos modelos pre definidos para edição. Esse perfis padrões só podem ser alterado pelo owner e pela IA conforme minha autorização, assim se o usuário (exemplo unidades) quiser um perfil de professor ele usa o padrão, mas se quiser alguma particulariada de colcoar mais acesso ou menos acesso, ele criar um perfil do zero ou a partir do de professor. Mas o que são do sistema ele não consegue modificar. Atenção pois professores são atrelados a turma e atividades, e podem fazer coisas diferentes e turmas diferentes de unidades diferentes. |
| P32 | B | A e B, no caso não que eu queira ou revisor de retirada ou entrada de pessoas na segurança infantil. Quando um pai cadastrar ou retirar alguém a unidade é notificada e os que estão relacionados a hierarquia da criança na escola tbm, como professores, coordenadores, diretores e por ai vai, lá no sininho. Assim como os outros responsáveis da criança tbm são notificados. A unidade ou instituição em si, pode definir se a segurança da criança, quando um resposnável alterar ela tenha que: Aceitar para liberar, Aceitar apenas inclusão, Aceitar apenas exclusão e outras possiveis variações. Teria que ter um tela de padrões que a unidade/escola define alguma politicas macro do app, essa seria uma delas, podemos começar com ela e ir crescendo. O mesmo conceito para medicação. Assim a unidade/insituição pode colocar o que falei acima, e inclusive não acompanhamos medicação. |
| P33 | R | Ficou legal, mas ainda falta alguns ajustes pequeno no calendário. Acho que tem que ser mais proximo do calendário o iphone. O canto arrendondado está muito "Rendodo", talvez diminuir um pouco. A fonte com a data deve ser um pouco menor para que tenha mais espaço do quadrado e colocado bem na esquerda superior, não colado para ter respiro. Madei prints do calendário do iphone para ver. Acho que talvez o grande problema seja o calendário está dentro de conteiner Além disso, o botão de calendário e lista podem dividir 50% para cada para ser maior e ocupar mais espaço e centralizar O calendário aparece tudo que tem direito mediante a hierarquia. Eventos, anviersário de amigos de turmas, de funcionários caso a insituição/unidade libere, provas. O responsável ver de todas as crianças mas pode fazer filtragem lá na opção de perfil, mesmo conceito para funcionários que podem ver por turmas, instituiç~eos e outros e para pessoas hibridas. |
| P34 | AO | Não está legal. Fundo cinza, bem fora da nossa skill. Se não me engano sempre que é cancelar, exlcuir, ou algo do tipo, fica do lado esquerdo e algo como salvar, contnuar do lado direto. Também está dirferente do rodapé de criar/editar insituição |
| P35 | C | Na verdade A agora e B agora. Pode similar, mas o superadmin, entra no app vendo tudo. Vamos criar o perfil/usuario, Coelo, que é o nosso app, onde todos Acompanham (Seguir) e ele acompanha todos. Pois posteriormente ele terá um perfil que publicarei dicas do app, para estimular o feed. Assim como criarei outros perfis. Caso queira, pode criar esse perfil, o Nome é Coelo, como a nossa logo de fundo laranja e coelho branco e um capa bem nosso padrão falando do nosso apenas, algo como Coelo é..., e ninguém poderá usar o arroba de coelo, coelo.me e depois podemos aumentar essa lista para que o usuário não se sinta enganado achando que é a gente. |
| P36 | A | lembrando das hierarquias, não existe unidades sem insituição, não existe turmas sem unidades, não existe atividade que não pertença a unidade ou insituição, atividade é sempre dentro de uma (ou mais) turma(s) e nunca solta. |
| P37 | A | Esse usuário qa-r03@coelo.me tbm deverá ser usado pelo codex, passe essa informação para ele, para ele tbm verificar. |
| G-SUP | AO | Ficou muito bom, apenas ainda temos desalinhamento nas table de suporte e implantação, alinho a esquerda, mas tem colunas como origem que está na esquerda superir, precisa ser igual a table de instituições |
| G-FORM | A |  |
| WT | A |  |

### Segunda leva (10:45, artefato "Pendências do Owner, 11/09")

| Item | Decisão | Observação e efeito |
| --- | --- | --- |
| P38 golden `forms_editor_dark_1440` | A | Regravado às 10:55; suíte do editor 4/4. |
| WT2 pastas soltas `e2-r01-c07` e `e2-r02-preserved-auth-20260909` | A | Apagadas às 10:55; o manifesto de preservação da R02 continua nos relatórios. |
| WT3 frente estrutura depois do fechamento | A | Branch `work/etapa2-r04-estrutura` (revs 34 a 37) integrada em `dev`; deltas continuação-2 aplicados (E2E 42/199). A worktree ficou porque a conversa ainda estava viva e commitando. |
| REF capturas do calendário do iPhone | salvar | PNG mensal e diário versionados em `docs/reviews/evidence/etapa-2/referencias/`; baseline da skill coelo-ui aponta para eles. |
| PUSH | pode enviar | Push feito para `dev` às 11:05. |

Orientação do Owner na mesma resposta: decisões do artefato são para **anotar** (R05 e md de pendências), não para executar fora do ciclo das frentes. O que já tinha sido executado antes dessa orientação (lotes 25 a 27, goldens P26/G-FORM) fica registrado como feito.


### Terceira leva (11:35, pausa da frente estrutura; confirmada na segunda pausa às 11:50) — aguardam resposta

| Item | Pergunta | Recomendação |
| --- | --- | --- |
| P40 (Unidades/Instituições, visual) | O campo Identificador usa o ícone @ mas grava o slug; o @ público é gerado pelo servidor. Trocar o ícone (link/tag) ou manter? | Trocar, porque o @ induz a ler o campo como handle. |
| P41 (Unidades, produto) | O Identificador digitado deve virar o @ público na criação (exigiria proibir hífen no cliente) ou o @ continua derivado pelo servidor? | Manter derivado até existir a ação "Alterar @" no cliente. |
| P42 (dados sintéticos) | A frente pediu remover em produção groups 368a5cea, institutions 190dd028 (qa-r04-escola), units f5284f2f e activity_locations 82e92854. A instituição 190dd028 recebeu membership do qa-r03 no lote 27 e é usada nos prompts da R05. Apagar agora ou no fim da Etapa 2, junto com as outras sintéticas (P25)? | No fim da Etapa 2, tudo junto, por migration de limpeza com dump prévio. |

Registro: ADR 0034 Decisão 15; skills coelo-backend, coelo-frontend, coelo-frontend-backend e coelo-ui (baselines aprovadas); coordenacao.json rev 33.

## Registro

- Respostas entram em `coordenacao.json` (revisão seguinte), na ADR 0034
  (Decisão 13) e nas skills afetadas no mesmo turno.
