---
title: "Etapa 2 — trabalho atual, coordenação Claude e prompts"
source: "Owner em 09/09/2026; AGENTS.md; inventario-etapa-2.json; fechamento e reconciliação R01/R02"
status: "authorized-on-prompt-start; conversations-not-started-by-document-creation"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Etapa 2 — trabalho atual

Este é o único ponto de entrada operacional da passagem de 09 para 10/09/2026.
Usar conversas NOVAS, preservando código, branches e evidências anteriores.
Os códigos D00/L00/C00 pertencem ao histórico. Os três macrogrupos são
**Estrutura**, **Acessos e Pessoas** e **Coelo Principal**; os grupos adicionais
abaixo cobrem o restante da Etapa 2 sem esquecer ações fora desses três.

O objetivo é corrigir, integrar e provar ações completas de `apps/superadmin`,
inclusive o menu Coelo (Principal), até fechar o recorte autorizado. Outros
apps e operações adiadas continuam fora. Nenhuma tarefa deve encerrar por ter
feito apenas uma auditoria, um relatório ou um lote verde se ainda puder fechar
o próximo critério executável. Persistência respeita os cortes abaixo.

## Horários obrigatórios — Brasília, UTC−03

| Responsável | Congelar novos lotes | Pré-entrega publicada | Entrega final e liberação |
| --- | --- | --- | --- |
| Codex: Estrutura e Acessos e Pessoas | 09/09 23:10 | 09/09 23:20 | **09/09 23:30** |
| Todos os executores Claude | 10/09 04:40 | 10/09 04:50 | **10/09 05:00** |

O corte de execução inclui todos os filhos: antes dele, recolher resultados,
encerrar runners e servidores, preservar WIP, publicar e comunicar. Não iniciar
um lote sem tempo para encerrá-lo. Consultar relógio real no início, em cada
checkpoint e antes de teste/build longo; timeout não ultrapassa a margem de
fechamento. Ao atingir o prazo, finalizar o processo próprio com preservação
segura e registrar teste interrompido, nunca inventar PASS.

Após 23:30, somente Claude trabalha; Codex não espera ACK nem volta a executar.
O coordenador já deve ter lido as pré-entregas até 23:30 e assume qualquer
residual. Após 05:00, executores Claude param; o coordenador continua apenas
consolidando, verificando e entregando ao Owner. Não abrir outra rodada.
Prompt colado depois do corte não autoriza retroagir ou mudar o prazo.

## Um coordenador, um integrador

**Coordenação e Integração — Claude** é o único escritor de `dev`, do registro
geral e dos três rastreadores/inventário. Esta autorização substitui a antiga
coordenação Codex quando o novo coordenador iniciar e registrar a posse.
Confirmar ausência de outro integrador ativo antes de escrever. Executores
escrevem exclusivamente em suas worktrees/branches e em seu arquivo de entrega.

O coordenador integra continuamente, não espera 23:30/05:00 para começar.
Receber → revisar código/evidências → integrar seletivamente → verificar na base
conjunta → atualizar inventário e os três rastreadores → commit/push → emitir
recibo. Recebido, integrado e aplicado remotamente são estados diferentes.
Não substituir arquivos inteiros de router/shell por snapshots antigos.

Migrations, wrappers de replay, router, navegação e plataforma comum de mídia
precisam de reserva com um escritor identificado por arquivo/pacote. Executores
propõem hunks ou commits pequenos; o coordenador resolve sobre a base conjunta.
Worktrees diferentes não impedem conflito lógico em arquivos compartilhados.
Replays SQL e mutações remotas são serializados pelo coordenador.

## Comunicação Codex ↔ Claude que não depende da memória do chat

Raiz compartilhada absoluta:
`C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/comunicacao/`.

- `coordenacao.json`: escrito SOMENTE pelo coordenador. Contém revisão, hora,
  base integrada, tarefas/IDs reais, caminhos/branches verificados, atribuições,
  reservas, bloqueios e recibo nominal por revisão recebida.
- `<grupo>.json`: escrito SOMENTE pelo executor desse grupo, no caminho
  compartilhado acima (exceção expressa à exclusividade de sua worktree).
  Sobrescrever o estado corrente de forma atômica com temporário exclusivo;
  não criar um MD por checkpoint, não editar arquivos de outro executor.
- Logs/testes completos ficam na worktree/branch do executor; o JSON aponta
  para caminhos, commits e hashes, sem copiar logs nem segredos.

No início, executor escreve identificação/revisão 1; coordenador lê o arquivo
real e publica ACK com a mesma revisão. Executor lê o ACK e registra o percurso.
Mensagem nativa, quando disponível, apenas avisa: o recibo durável é o arquivo.
Sem ferramenta entre aplicativos, usar esses arquivos; nunca afirmar que uma
mensagem foi entregue por existir um arquivo ainda não lido.

Durante a execução, atualizar ao fechar uma correção, publicar um lote, mudar
bloqueio ou antes de comando longo, e pelo menos a cada 30 minutos enquanto
ativo. Ler as instruções/ACK do coordenador nesses pontos. Não esperar ACK para
trabalho independente já autorizado; mudança em arquivo reservado depende da
atribuição. Coordenador atualiza pendências no mesmo ciclo de integração.

Cada atualização informa: revisão/hora; tarefa/modelo reais; grupo; worktree e
branch; HEAD e remoto; base; tela/subtela/action_ids; o que mudou; critérios
fechados; testes P/F/B/S/U e evidências; arquivos reservados; bloqueio e próximo
passo exato; WIP/artefatos; processos/portas próprios. Entrega final acrescenta
revisão dos filhos, commits integráveis/retidos, status/stash, igualdade com
remoto e inventário de cleanup. Nenhum campo desconhecido vira zero.

## Continuidade e economia de cota

Responsável pelo grupo implementa e recolhe os próprios filhos. Todos reportam
diretamente ao coordenador Claude; não criar outra camada de coordenadores.
Codex: duas frentes, sem vigilância adicional nem exército de subagentes.
Usar filhos somente para subtarefa concreta independente, com arquivos e
resultado definidos; recolher antes do corte do pai.

Enquanto houver correção, integração ou teste necessário executável, continuar
ao próximo critério sem pedir “posso continuar?”. Bloqueio retém só o dependente.
Sem trabalho independente, informar uma vez e aguardar instrução/evento de
forma real; não fingir atividade nem repetir testes verdes para ocupar tempo.

Na abertura o coordenador deve verificar quais mecanismos de espera/retomada
o Claude realmente fornece e testar um ciclo de aviso/recebimento. Preferir
notificação e espera nativas; fallback: vigília de filesystem/processo local
somente leitura, com verificação espaçada (até 5 minutos, menor perto dos cortes)
e timeout finito até a janela de fechamento. Não criar loop de inferência
segundo a segundo, ping contínuo, cron duplicado ou agendamento após os cortes.
Vigília de arquivos não reabre sozinha uma conversa encerrada: não alegar isso.
Se o aplicativo não permite retomada sem intervenção, informar a limitação no
registro antes de prometer acompanhamento noturno.

Enquanto aguarda entregas, coordenador integra lotes recebidos e resolve
dependências compartilhadas. Não encerrar sua conversa com “aguardando” se isso
desliga o acompanhamento; usar o mecanismo verificado enquanto disponível.
Nenhum prompt ultrapassa quota, desligamento ou falha de aplicativo. Proteger
o trabalho com checkpoint ANTES da falha: commit/push de lotes pequenos,
rascunho identificado e próximo passo gravado. Não confiar em conseguir escrever
um último aviso quando a cota já acabou. O coordenador pode transferir um
residual Codex ao Claude após confirmar que o escritor anterior está parado.

### Supervisão discreta e recuperação de conversa parada

O coordenador deve acompanhar todas as conversas ativadas, incluindo os filhos
que cada responsável declara. Intervir somente por: parada inesperada com
residual executável, bloqueio material, conflito de escrita, falha de entrega,
revisão/integração necessária ou aproximação do corte. Não enviar “continue”
para conversa ativa nem solicitar confirmação repetida de progresso.

Registrar IDs nativos reais e testar, na abertura, a capacidade de consultar
estado e retomar cada tipo de conversa. Ao observar inatividade, verificar
runner/processo, último checkpoint, bloqueio, espera autorizada e horário.
Ausência de mensagem não prova parada: pode haver teste/build em andamento.
Confirmada parada inesperada antes do corte, usar a ferramenta nativa real para
retomar a MESMA conversa com a próxima ação exata do checkpoint, sem duplicar
executor/worktree. Registrar motivo, tentativa e confirmação de nova atividade.
Não reiniciar tarefa concluída ou bloqueada sem trabalho independente, nem
ultrapassar23:30 para Codex ou05:00 para executores Claude.

Se não existir ferramenta para reativar uma conversa (especialmente entre
Claude e Codex), escrever uma instrução em arquivo NÃO a desperta. Registrar
essa limitação e usar a alternativa já autorizada: confirmar ausência de
escritor/runner, preservar a entrega e transferir a tarefa ao Claude disponível.
Quota esgotada não se resolve mandando “continue”. Não criar watchdog que injeta
mensagens em aplicativos sem capacidade verificada. Leitura de estado pode ser
espaçada e não precisa gerar conversa/inferência quando nada mudou.

## Skills e provedores — obrigatórias conforme o recorte

Ler uma vez e reutilizar, sem carregar referências alheias à ação:

- `.agents/skills/rtk/SKILL.md`: usar `rtk`/`rtk proxy`; não reinstalar por aviso de hook.
- `.agents/skills/ponytail/SKILL.md`: menor solução correta, reuso e causa raiz;
  nunca cortar segurança, acessibilidade ou prova necessária.
- `.agents/skills/coelo-flutter-review/SKILL.md` — Coelo Front-end.
- `.agents/skills/coelo-supabase/SKILL.md` — Coelo Back-end.
- `.agents/skills/coelo-flutter-supabase-review/SKILL.md` — integração/E2E.
- `.agents/skills/coelo-ui/SKILL.md` — referências visuais aprovadas por tela.
- `.agents/skills/coelo-knowledge/SKILL.md` — fonte canônica primeiro; no-op quando adequado.
- `.agents/skills/flutter-dart-code-review/SKILL.md` para código Flutter/Dart.

Supabase: descobrir e usar o MCP do plugin instalado e a skill oficial
`supabase:supabase`; SQL/RLS usa as boas práticas Postgres pertinentes.
Cloudflare: descobrir `cloudflare_api` (docs/search/execute), usar a skill
oficial do serviço, `.agents/skills/cloudflare-manager/SKILL.md` e Wrangler
quando houver build/deploy. Ferramenta disponível não comprova acesso ao projeto.
Verificar as capacidades reais em cada conversa, sem expor credenciais.

Todo remoto Coelo é PRODUÇÃO. Este prompt autoriza correção/qualificação local,
Git e preparação dos pacotes; não concede autorização genérica para mutations
Supabase/Cloudflare. Usar autorização nominal vigente do pacote exato; se faltar,
preparar resultado revisável, registrar decisão necessária e continuar o trabalho
independente. Não contornar bloqueio com service_role no cliente, relaxamento de
RLS, alterações de migrations aplicadas ou dados do Owner.

## Base, fontes e worktrees

Raiz integradora: `C:/Users/adrie/Documents/Coelo`, branch `dev`.
Base funcional preservada `d019c109a`; reconciliação documental `8954de221`.
Usar o HEAD publicado que contém ESTE documento, conferido no início.

As worktrees R02 são fontes preservadas, não checkouts implicitamente atualizados.
Consultar `next-round/R02-20260909/registro.json` para os caminhos/SHAs anteriores,
`FECHAMENTO-OWNER.md`, `RECONCILIACAO-PENDENCIAS-R01-R02.md` e o handoff do grupo.
Ler R01 somente pelos candidatos/ações herdados relevantes. Para Claude, ler
também a entrega L00 e o consolidado pertinente antes de integrar.

O coordenador registra uma worktree por grupo a partir da base integrada atual:
preferência `C:/Users/adrie/Documents/Coelo.worktrees/e2-noturna-<grupo>` e branch
`work/etapa2-noturna-<grupo>`. Se o aplicativo já criar isolamento, verificar e
usar esse caminho real, sem aninhar outro. Não copiar worktree antiga inteira;
reutilizar candidatos seletivamente e preservar referências. Não iniciar duas
conversas no mesmo checkout nem alterar a branch aberta de outro executor.

Fontes atuais de conclusão: `docs/reviews/inventario-etapa-2.json` e
`docs/reviews/coelo-flutter-pendencias.md`, `coelo-supabase-pendencias.md`,
`coelo-flutter-integrado-supabase-pendencias.md`. Mapear os IDs por família
abaixo: 230 IDs sem duplicar ownership. Adiados/MFA mantêm sua política.

## Grupos e primeiros gates

| Identificador de comunicação | Ferramenta | Famílias do inventário | IDs | Primeiro trabalho |
| --- | --- | --- | ---: | --- |
| estrutura | Codex | institutions, units, groups, activities, assessments, locations | 49 | Revisar/integrar cd03b9e30, 1345af29f, 42ad0467; compor Locais/reservas e bindings/save atômico Group/Activity. Reusar catálogo165, Clock46+3 e reservas49+2. |
| acessos-pessoas | Codex | people, access_profiles, access_models, invites, internal_users, child_safety, profile_files | 38 | Fechar contratos e fluxos de escrita/negação restantes; qualificar SQL Modelos; Safety golden F1/SQL43U. Preservar duplicação e confinamento Convites já integrados. |
| publicacoes-midia | Claude | acontece, agora, momentos, circulars | 23 | Leitor Principal de Circular, feed Momentos, publicação/mídia e retiradas candidatas. L01 3697dd49e. Feed misto já injetado; unir embedded e mediaPicker, não perder nenhum. |
| chat-comunicacoes | Claude | chat, notices | 13 | Integrar /principal-conversations, corrigir concorrência paginação/envio e tentativa após reabertura; receipt ligado à conversa e reautorização pós-lock; worker/métricas Avisos. Fonte L02 9144f4efb/45d92b9c1. |
| perfil-para-voce | Claude | principal_profile | 3 | Integrar composição L03 b209b4e0f preservando audiência obrigatória; leitura RPC Sobre, estado/draft/reload e critérios visuais. Filtragem server-side em Para Você. |
| alunos-rotina | Claude | students, attendance, daily_routine | 16 | Reusar CHILD45+3+4 e compositor6; cache PostgREST U1, comandos e contratos de Rotina/Assiduidade. FE attendance.export já certificado como informativo. |
| formularios-cuidado | Claude | forms_authoring, forms_responses, forms_files, health_care, medication | 27 | Resposta submitted, limites numéricos/texto, mídia question-image, Overview/Publicar/Testar/Local, XLSX e care049. Reusar schema313/writer128 e SQL I005172/I01382. Safety pertence a acessos-pessoas. |
| operacoes-sistema | Claude | auth, shell, agenda, imports, audit, support, account, catalog, plans, meal_plans, error_pages | 61 | Priorizar candidato Auditoria145U e Cardápios932003b1/requestId; Agenda/Planos por contrato. Reusar FE Auth4; assumir integração transversal de sessão/shell sob reserva, sem reauditar tudo. |

Início preferido: dois Codex e os três Claude de Coelo Principal. Os três grupos
adicionais começam quando o coordenador tiver capacidade e contexto de arquivos
resolvido; não deixá-los esquecidos. Ao colar seu prompt o grupo solicita a
ativação no registro. Enquanto aguarda atribuição/isolamento, leitura focal é
permitida, escrita de produto não. Coordenador pode ativar antes se houver
capacidade real e trabalho independente; não criar mais agentes que o ambiente
suporta. Nenhum grupo muda de dono silenciosamente.

## Entrega comprovada e limpeza

Antes da pré-entrega, cada executor e TODOS os seus filhos revisitam: pedidos
recebidos, ações não terminadas, arquivos modificados, commits, stash, artefatos
ignorados, falhas e testes interrompidos. Entregar cada resultado ou explicitar
o que falta; pai não pode declarar “todos concluídos” sem conferir.

Coordenador lê os arquivos finais, inspeciona Git e evidências e confronta
origem/remoto/local. Exigir: commits publicados; `HEAD == upstream` e divergência
0/0; worktree sem alterações não identificadas; stash reconciliado; localhost,
containers, runners e agendas próprios encerrados. Conferir cada frente,
incluindo as que não notificaram; cobrar no arquivo durante a margem de entrega.
Se uma tarefa desapareceu, recuperar Git/WIP/evidências e registrar falha de
recebimento; não fabricar o handoff ou esperar além do corte para preservar.

“Nada à frente” significa nada local sem publicação na sua branch remota.
Commits candidatos não integrados em dev permanecem identificados e preservados;
não apagá-los para forçar igualdade com dev. Nada de reset/clean genéricos,
force-push, descarte de stash ou exclusão de artefato sem reconciliação. WIP
retido: copiar/arquivar com caminhos e SHA256 verificados antes de limpar paths
exatos. Worktree limpa não exige remover a worktree. Não matar processos alheios.

Após Codex23:30, Claude assume correções de consolidação e residual atribuído.
Após Claude05:00, coordenador verifica base conjunta, atualiza os três rastreadores
e inventário, executa `node docs/reviews/validate-trackers.cjs` e os testes desse
validador quando alterado, verifica memória, commit/push e igualdade com remoto.
Relatório final no próprio documento principal: por tela/subtela, integrado vs
branch vs remoto, FE/BE/E2E com denominadores, correções/testes P/F/B/S/U, bloqueios,
residual R01/R02/noturno, recursos e estado Git. Não somar reruns nem promover
E2E por mock, rota /dev, build ou contrato isolado.

## Prompts para conversas novas

Cole somente o bloco do papel desejado. Modelo é escolhido no aplicativo;
registrar o realmente ativo. Começar pelo coordenador; só iniciar os executores
em seus caminhos verificados. Não há nova conversa criada por este documento.

### Coordenação e Integração — Claude

```text
Assuma Coordenação e Integração da Etapa 2 no Claude, em conversa nova.
Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/TRABALHO-ATUAL.md e execute seu contrato e papel. Este é o início autorizado.
Você é o único integrador de dev e escritor do inventário/três pendências. Registre a transferência da coordenação antiga; confirme exclusividade, base, worktrees e ferramentas. Não recrie a hierarquia D00/L00.
Materialize a comunicação coordenacao.json e os caminhos dos grupos; teste leitura/ACK entre aplicativos e a espera/retomada realmente disponível. Integre entregas continuamente, feche dependências e atualize pendências no mesmo ciclo. Não fique apenas monitorando.
Vigie paradas inesperadas e retome a mesma conversa pelo mecanismo nativo testado, somente quando necessário e antes do corte. Confira runners/bloqueios antes; não interrompa tarefa ativa. Se não puder acordar Codex por ferramenta real, arquivo não basta: confirme parada, preserve e transfira ao Claude sem dois escritores.
Garanta pré-entrega Codex23:20 e entrega/liberação23:30 de09/09/2026; pré-entrega Claude04:50 e entrega/liberação05:00 de10/09/2026, America/Sao_Paulo. Recolha todos os filhos, confira Git/remoto/WIP/testes/recursos e assuma os ausentes sem inventar recibos. Depois dos cortes somente você consolida conforme o contrato.
Priorize avanço real por ação e prova E2E. Preserve candidatos e evidências R01/R02, use RTK/Ponytail/skills Coelo e MCPs Supabase/Cloudflare no escopo autorizado. Não reexecute lotes verdes sem motivo. Não pare enquanto houver trabalho executável dentro da fase; use espera verificada quando necessária, nunca prometa superar quota ou sessão encerrada.
Ao final entregue tudo integrado ou nominalmente retido, pendências atualizadas, commits publicados, worktrees reconciliadas e recursos próprios encerrados. Registre limitações reais imediatamente.
```

### Estrutura — Codex

```text
Inicie uma conversa nova como responsável pelo grupo estrutura da Etapa 2.
Leia C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/TRABALHO-ATUAL.md, cumpra todo o contrato comum e execute o recorte estrutura da tabela. Este prompt autoriza o início local após isolamento/atribuição verificados.
Seu coordenador e integrador é Claude; comunique-se por comunicacao/estrutura.json na raiz absoluta definida no documento e leia coordenacao.json. Não escreva dev nem rastreadores centrais.
Reaproveite a entrega Estrutura R02, integre seletivamente os três candidatos retidos e avance Locais/reservas, Instituições/Unidades/Turmas/Atividades/Avaliações até o primeiro aceite completo executável. Preserve Auth/CHILD/shell. RTK, Ponytail, skills Coelo e provedores conforme contrato.
Continue corrigindo, testando proporcionalmente e publicando lotes; informe deltas e bloqueios ao coordenador sem esperar ACK para trabalho independente. Checkpoints recuperáveis antes de comandos longos; pouco crédito exige evitar releitura, reruns e filhos sem ganho.
09/09/2026 Brasília:23:10 congelar novos lotes,23:20 pré-entrega publicada,23:30 entregar tudo e parar, inclusive filhos. Antes disso revisite tudo que ficou para trás, publique commits, confira HEAD/upstream0/0, preserve WIP por hash e encerre recursos próprios. Entregue correções, evidências, pendências e próximo passo exato. Não espere ACK depois do corte; Claude assume o residual.
```

### Acessos e Pessoas — Codex

```text
Inicie uma conversa nova como responsável pelo grupo acessos-pessoas da Etapa 2.
Leia C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/TRABALHO-ATUAL.md e execute integralmente o contrato comum e o recorte acessos-pessoas. Início local autorizado após isolamento/atribuição verificados.
Coordenador e integrador:Claude. Publique comunicacao/acessos-pessoas.json no caminho compartilhado absoluto e leia coordenacao.json. Não escreva dev nem rastreadores centrais.
Reaproveite a entrega Acessos R02. Feche pendências de Pessoas, Perfis, Modelos, Convites, Usuários e Safety; preserve duplicação e confinamento já integrados. Não liberar writes por repository real nem adiados por inferência. Priorize SQL nominal de Modelos e SafetyF1/43U conforme dependências/reservas, além de ações independentes executáveis.
RTK, Ponytail, skills Coelo e provedores conforme contrato. Trabalhe por correção/prova/commit/push/recibo, evitando reruns e auditorias repetidas. Checkpoints recuperáveis e comunicação ao Claude a cada entrega ou bloqueio.
09/09/2026 Brasília:23:10 congelar novos lotes,23:20 pré-entrega publicada,23:30 entrega final e parada de todos os filhos. Revisite tarefas/arquivos/pendências antes de fechar; HEAD/upstream0/0, WIP preservado e recursos próprios encerrados. Entregue evidências, SHAs e próximo passo exato; após23:30 só Claude atua.
```

### Executores Claude — bloco comum

Cada prompt abaixo incorpora TODO este contrato: trabalhar no grupo indicado,
isolamento próprio, atualizações ao coordenador por `comunicacao/<grupo>.json`,
leitura de `coordenacao.json`, skills/provedores, continuidade por ações, Git e
preservação. Corte 10/09/2026 Brasília:04:40 novos lotes cessam;04:50 pré-entrega;
05:00 todos os filhos e o executor encerrados, somente coordenador consolida.

### Publicações e Mídia — Claude

```text
Inicie em conversa nova o grupo publicacoes-midia da Etapa2. Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/TRABALHO-ATUAL.md e execute seu contrato comum, bloco Executores Claude e recorte publicacoes-midia; início autorizado após atribuição/worktree confirmadas.
Reaproveite L01 3697dd49e e as integrações atuais: feed misto já está conectado. Priorize leitor Principal de Circular, feed Momentos, composição/mídia e contratos de retirada/publicação. Preserve embedded+mediaPicker, audiência, referências aprovadas e plataforma comum; não crie gateway/bucket por tela.
Reporte no arquivo compartilhado publicacoes-midia.json e leia o coordenador. Corrija, teste, publique e avance sem encerrar após um lote se houver trabalho executável. Respeite reservas, nominal remoto, checkpoints e limites de recursos; não prometa execução após cota/sessão encerrada.
Entregue tudo e pare até05:00 de10/09, pré-entrega04:50, congelamento04:40. Revise residual e todos os filhos; commits publicados, HEAD/upstream0/0, WIP identificado/preservado, recursos próprios encerrados e pendências/evidências completas para integração Claude.
```

### Chat e Comunicações — Claude

```text
Inicie em conversa nova o grupo chat-comunicacoes da Etapa2. Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/TRABALHO-ATUAL.md e execute contrato comum, bloco Executores Claude e seu recorte; início autorizado após atribuição/worktree confirmadas.
Reaproveite L02 9144f4efb/45d92b9c1. Priorize /principal-conversations no shell, destinos Principal, paginação concorrente com envio, tentativa após reabertura, receipts vinculados à conversa/reautorização pós-lock e worker/métricas de Avisos. Preserve diferenciação Chat administrativo/Principal, sem dividir IDs unilateralmente. Mídia comum com publicacoes-midia, sem escritores simultâneos.
Reporte chat-comunicacoes.json na comunicação compartilhada e leia coordenacao.json. Continue correção/prova/commit/push até fechar ações executáveis; bloqueio só retém dependentes. Siga skills Coelo/RTK/Ponytail e MCPs nominais, preservando checkpoints.
10/09 Brasília:04:40 congelar novos lotes;04:50 pré-entrega;05:00 entrega final/parada de todos os filhos. Revisite residual, publique tudo, confira0/0 com upstream e worktree/WIP/recursos. Coordenador recebe e integra; não substituir o router inteiro.
```

### Perfil e Para Você — Claude

```text
Inicie em conversa nova o grupo perfil-para-voce da Etapa2. Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/TRABALHO-ATUAL.md e execute contrato comum, bloco Executores Claude e seu recorte; início autorizado após atribuição/worktree confirmadas.
Reaproveite L03 b209b4e0f e deltas já integrados. Priorize composição normal, leitura RPC autorizada do Sobre, estado de autorização/draft/callback/reload e audiência server-side de ParaVocê. Preserve audiência obrigatória, guarda da edição, destinos Principal e referências aprovadas. Perfil contextual não é MinhaConta ou Perfil de acesso. Não inventar contrato visual que permaneça sem decisão.
Reporte perfil-para-voce.json no caminho compartilhado e leia coordenacao.json. Continue por ações verificáveis, publicando provas e commits sem auditoria repetida. Skills Coelo/RTK/Ponytail e provedores conforme contrato; bloqueio não encerra trabalho independente.
Entregue até05:00 de10/09 Brasília, com pré-entrega04:50 e congelamento04:40. Recolha todos os filhos, revise residual, publique commits/0/0 upstream, preserve WIP e encerre recursos próprios. Após entrega final somente coordenador consolida.
```

### Alunos e Rotina — Claude, ativação coordenada

```text
Inicie em conversa nova o grupo alunos-rotina da Etapa2. Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/TRABALHO-ATUAL.md e cumpra contrato comum, bloco Executores Claude e seu recorte. Registre disponibilidade em alunos-rotina.json; só escreva produto após coordenador confirmar ativação/worktree/reservas.
Reaproveite D03 e CHILD integrado; não repetir45TAP+3concorrência+4HTTP ou compositor6 sem motivo. Priorize cache PostgREST U1, contratos/comandos de Alunos, Rotina e Assiduidade e prova real pela UI. Exportação geral continua informativa. Avance ações completas e reporte correções/testes/commits/bloqueios ao coordenador.
Use RTK/Ponytail/skills Coelo e MCPs conforme contrato. Checkpoints recuperáveis; não parar enquanto houver trabalho autorizado executável, respeitando ativação e cortes. 10/09 Brasília:04:40 congelar;04:50 pré-entregar;05:00 entregar e encerrar todos os filhos, com revisão do residual,0/0 upstream,WIP preservado e recursos encerrados.
```

### Formulários e Cuidado — Claude, ativação coordenada

```text
Inicie em conversa nova o grupo formularios-cuidado da Etapa2. Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/TRABALHO-ATUAL.md e execute contrato comum, bloco Executores Claude e seu recorte. Registre disponibilidade em formularios-cuidado.json; aguarde ativação/worktree/reservas antes de escrever produto, podendo ler fontes focais.
Retome residual C02/R01: limites numéricos/texto, resposta submitted, Overview/Publicar/Testar/Local, mídia question-image, XLSX real por formulário e care049. Reuse galeria/datas, schema313/writer128, I005172/I01382; não tratar implementação existente como ausente. Safety é de acessos-pessoas. Reserve mídia compartilhada com publicacoes-midia/coordenador.
Corrija e prove ações completas, use RTK/Ponytail/skills Coelo e MCPs nominais, publique commits e atualizações ao coordenador sem repetir auditorias/lotes verdes. Mantenha checkpoints recuperáveis. 10/09 Brasília:04:40 congelar,04:50 pré-entregar,05:00 entrega e parada incluindo filhos. Revise todo residual e deixe evidências,0/0 upstream,WIP preservado e recursos encerrados.
```

### Operações e Sistema — Claude, ativação coordenada

```text
Inicie em conversa nova o grupo operacoes-sistema da Etapa2. Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/TRABALHO-ATUAL.md e cumpra contrato comum, bloco Executores Claude e seu recorte. Registre disponibilidade em operacoes-sistema.json; coordenador confirma ativação e uma sequência pequena de ações antes de escrita. Não auditar61IDs do zero.
Primeiros candidatos: Auditoria145U, Cardápios932003b1/requestId e Agenda/Planos conforme contrato. Depois demais ações atribuídas. AuthFE4 já certificado; só reabrir por regressão, dependência concreta ou pacote nominal. Shell/router/identidade são compartilhados e exigem reserva exclusiva. Import/export adiados e MFA permanecem conforme política.
Use RTK/Ponytail/skills Coelo e MCPs pertinentes. Trabalhe por correção/prova/commit/push e reporte ao coordenador; mantenha checkpoints e siga para próxima ação executável. 10/09 Brasília:04:40 congelar,04:50 pré-entregar,05:00 entregar e encerrar todos os filhos. Revisite pendências e evidências,0/0 upstream,WIP preservado,worktree reconciliada e recursos próprios encerrados.
```
