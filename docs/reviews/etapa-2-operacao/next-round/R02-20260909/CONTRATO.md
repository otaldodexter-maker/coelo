---
title: "E2 R02 — contrato de execução por contextos"
source: "Owner em 09/09/2026 nesta tarefa; AGENTS.md; coelo-etapa-2-coordenacao.md; PROTOCOLO R01; inventario-etapa-2.json"
status: "prepared-not-started"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# E2 R02 — 09/09/2026

Este pacote prepara a execução que o Owner iniciará ao colar os prompts.
A criação destes arquivos não inicia agentes de produto, worktrees, testes,
agendamentos, commits, push nem alterações remotas. Os subagentes usados na
preparação apenas leram e revisaram o plano.

Depois de colado um prompt de EXECUÇÃO, o responsável está autorizado a executar
seu recorte local, corrigir, testar proporcionalmente, fazer commits pequenos
na branch atribuída e publicar essa branch. D00 integra os deltas revisados
em dev e verifica o push. Essa autorização de Git não é implantação em produção.
Outros ambientes/apps, funcionalidades pós-MVP e pacotes remotos não autorizados
continuam fora. Não abrir a próxima rodada depois do corte sem decisão do Owner.

## Objetivo e recorte

Concluir o residual da Etapa 2 nos contextos atribuídos, por
apps/superadmin → menu → tela → subtela/estado → action_id.
Cada frente responde por cliente, backend aplicável e retorno real à UI.
Atribuição por menu não separa Front-end de Back-end entre agentes.
Use escopo.json para os IDs existentes e lacunas; não invente ações concluídas.

Na fotografia inicial há 132  IDs explicitamente atribuídos:
116 MVP ativos E2E aplicáveis, 14 operações adiadas e 2 gates formais.
Existem 87  IDs fora desta seleção: 73 MVP, 8 adiados, 5 flutter-only e 1 gate.
Desses 73 MVP, 71 são E2E aplicáveis. 116/187 = 62,03% é cobertura selecionada,
não avanço ou percentual implementado. Circulares e granularidade de algumas
subtelas ainda precisam de reconciliação; o denominador completo do recorte
permanece aberto até essa reconciliação. Não certificar o contexto inteiro
apenas pelos 116  IDs existentes.

## Autoridades e fontes

1. Instruções atuais do Owner, AGENTS.md e decisões aprovadas.
2. Este contrato e registro.json desta rodada após início confirmado.
3. Inventário e três rastreadores na base integrada vigente.
4. Handoffs originais por caminho absoluto e revisão; código, anexos e evidências.
5. Fechamento R01 como histórico: não reativar tarefas, leases, IDs ou horários antigos.

Leia as skills abaixo uma vez e carregue referências na profundidade necessária:
- rtk: .agents/skills/rtk/SKILL.md
- coelo-backend: .agents/skills/coelo-supabase/SKILL.md
- coelo-frontend: .agents/skills/coelo-flutter-review/SKILL.md
- coelo-frontend-backend: .agents/skills/coelo-flutter-supabase-review/SKILL.md
- coelo-knowledge: .agents/skills/coelo-knowledge/SKILL.md
- ponytail: .agents/skills/ponytail/SKILL.md
- flutter-dart-code-review: .agents/skills/flutter-dart-code-review/SKILL.md
Também use coelo-ui para qualquer UI e as skills oficiais Supabase/Cloudflare
somente quando o provedor participar da ação. Cloudflare exige descoberta do
MCP instalado e caminho real de build/deploy; não alegar ausência por nome antigo.
RTK já funciona: use rtk e rtk proxy, sem reinstalar/configurar globalmente
só porque aparece aviso de hook. Ponytail exige a menor solução correta,
preservando segurança, acessibilidade e o escopo aprovado.
Knowledge consulta fontes; no-op quando não houver nova regra durável.

## Execução contínua e subagentes

- A assignment autoriza a sequência completa do contexto. Feche uma ação,
  registre a evidência e avance ao próximo critério executável. Não termine
  apenas com auditoria, plano ou contagem de testes.
- Use o máximo de subagentes ÚTEIS permitido pelo ambiente para subtarefas
  concretas independentes. O executor principal continua implementando,
  integrando resultados e verificando seu fluxo. Não abrir filhos sem trabalho
  independente, duplicar auditorias ou entregar o mesmo arquivo a dois escritores.
- Nomeie responsabilidade, arquivos e resultado de cada filho. Subagentes
  respeitam o escopo/modelo/horários do pai, salvo decisão nominal registrada.
  O pai é responsável por cada resultado; não converter análise em certificação.
- Não esperar ACK do coordenador para continuar trabalho independente já atribuído.
  Não pedir confirmação por tela, por teste ou por correção local rotineira.
- Bloqueio retém somente ações dependentes. Entregue diagnóstico e pacote
  concretos e continue as demais. Ao ficar sem trabalho independente real,
  avise uma vez seu coordenador, que remove o bloqueio ou atribui apoio dentro
  desta rodada. Não abrir menus da próxima rodada por conta própria.
- O corte horário prevalece sobre persistência. Não iniciar lotes incompatíveis
  com o tempo restante; preservar trabalho e relato mesmo se E2E não fechar.

## Coordenação que entrega sem interromper

D00 acompanha D01–D04 e mantém integração/trackers. L00 acompanha L01–L03
e encaminha entregas a D00. D00 não cobra executores Claude em paralelo com L00.
O coordenador remove impedimentos, revisa pacotes concretos, integra e prova
o conjunto. Não fica apenas fiscalizando nem reescreve o plano a cada checkpoint.
Enquanto a rodada estiver ativa, não encerrar com "aguardando" se isso desliga
o acompanhamento. Usar espera nativa ou retomada realmente verificada, respeitando
os cortes e as limitações do ambiente. Não prometer persistência inexistente.

Intervenha apenas por bloqueio/dependência, conflito, falha material, revisão
necessária, ociosidade comprovada ou corte de entrega. Confira primeiro se
teste/build/ferramenta está em andamento. Não mande "continue" para tarefa ativa.
Uma intervenção por causa e revisão; resolvida a causa, não repetir cobrança.
Consultas de estado são silenciosas e compactas, preferencialmente por evento;
consulta de relógio não justifica interromper um executor para pedir relatório.
Não transformar reserva de um arquivo em licença para cada alteração rotineira.

## Comunicação durável e continuidade real

Reutilize o padrão assignment → handoff → ACK da R01, com identidades R02.
D00 mantém registro.json na raiz canônica deste pacote: ID real da tarefa,
worktree, branch, baseline, caminhos absolutos, responsável e status.
Campos nulos significam não registrado; não presumir tarefa criada ou recebida.

Cada responsável escreve handoffs/<ID>.md somente na SUA worktree, no caminho
relativo deste pacote. D00 lê os originais pelos caminhos do registro.
D00 publica instruções para Codex e L00 em assignments/<ID>.md na base canônica.
L00 publica instruções L01–L03 em assignments/<ID>.md na SUA worktree.
Executores leem a assignment viva por caminho absoluto registrado, não uma
cópia desatualizada em sua branch. Só o dono escreve cada arquivo.
Relatórios de L00 não substituem nem reescrevem a evidência original de L01–L03.

Identifique mensagem/entrega por rodada + executor + revisão monotônica.
Distinguir recebido, aceito e integrado; ACK não prova E2E.
D00 envia instrução inicial; L00 registra leitura/revisão/horário em seu handoff;
D00 confirma recebimento. Isso prova o percurso, não trabalho concluído.

Codex usa ferramentas nativas de status/mensagens/espera quando disponíveis.
Claude identifica e registra seu mecanismo real de continuidade e seus limites.
Markdown sozinho não acorda sessão. Agendamento existente ou configurado não
prova disparo: confirmar primeira ocorrência. Não inventar ponte de teclado,
API paga ou execução contínua. Se um mecanismo não estiver disponível, registrar
o impedimento concreto sem bloquear o desenvolvimento independente.

Se necessário, cada coordenador configura somente seu acompanhamento nativo
da rodada após o início pelo Owner, reaproveitando agendas equivalentes e
respeitando limites da ferramenta. Não criar um monitor por subagente nem
avisos repetidos ao Owner. Confirmar status por evento e cortes do dia.
Sem agendamentos que retomem trabalho depois dos cortes abaixo.

## Compartilhados e integração

- D01 mantém a lógica comum de autenticação/sessão e entrega contratos para D04.
  D04 mantém autorização de domínio/perfis/vínculos. Bootstrap e rotas comuns
  têm reserva pontual coordenada por D00.
- D02 mantém Estrutura/Locais que seus fluxos exigem e publica contratos para D03.
  Isso não atribui automaticamente todos os IDs Locais da próxima fila.
- L01 é responsável técnico inicial pelo núcleo comum de mídia R2/Stream/Gateway
  necessário a esta rodada. Publica contratos compatíveis cedo; L02/L03 são
  consumidores. D00 serializa migrations/aplicação remota e coordena alterações
  transversais; nenhum agente cria plataforma de mídia paralela.
- L01 fornece projeções Circulares/Publicações a L03. L02 mantém ChatRepository
  e NoticeRepository; L03 consome em Perfil/Para Você. Circulares != notices.
- D00 coordena superadmin_router.dart, superadmin_routes.dart, main.dart,
  superadmin_auth_scope.dart, shell/navegação, barrels e recursos compartilhados.
  Conceder reserva curta por alteração/arquivo com release por SHA, não reter
  todos os arquivos até uma frente inteira terminar.
- Limitar concorrência de Flutter builds, Docker e testes pesados ao que o host
  suporta. Uma execução por lote; banco/produção compartilhados serializados.
  Isso limita o recurso de teste, não a escrita/leitura independente.

Cada executor faz commits pequenos e entrega SHAs aptos continuamente.
D00 revisa o delta, integra assim que apto, publica o SHA e materializa essa
base antes da verificação conjunta. Não esperar 16 h/16h30 para começar a integrar.
Não invalidar todo teste porque uma mudança documental entrou; repetir somente
o que foi afetado ou a prova integrada ainda ausente. Não sincronizar a worktree
de um executor no meio de alterações ou teste em andamento.

## Prova e percentuais

Definir aceites/testes necessários antes do lote. Reutilizar provas válidas.
Uma falha funcional exige reprodução e teste pertinente; depois de passar,
seguir ao próximo critério. Repetir/ampliar por mudança relevante, nova falha,
evidência insuficiente ou integração obrigatória, nunca para aumentar contador.

FE verified, BE done e E2E verified-e2e são independentes. Ponta a ponta exige
rota/composição normal, ator/permissão no servidor, operação nominal,
persistência e releitura na UI, negações pertinentes, auditoria e provedores
realmente utilizados. Mídia inclui objeto privado R2 e gateway; Stream somente
onde a política vigente exige. Mock, /dev, preview, local-green e golden isolado
não equivalem E2E. Não exigir Cloudflare em ação que não o usa.

No reporte, por tela/subtela e no total:
- ações/aceites fechados antes → agora, com IDs, base, horário e evidência;
- FE concluído / FE aplicável; BE concluído / BE aplicável;
- E2E certificado / E2E ativo aplicável da rodada e da Etapa 2;
- testes únicos: P aprovados, F falhos, B bloqueados, S ignorados, U não executados;
- taxa aprovada P/(P+F), taxa falha F/(P+F); execução (P+F)/(P+F+B+S+U);
- aprovação do plano P/(P+F+B+S+U), sem somar reexecuções/suítes sobrepostas;
- partes implementadas mas não certificadas, bloqueio real e próximo passo.

Denominador zero não vira 100%; falta de evidência ou inventário fica
"não calculável". Distinguir falha observada na base atual, falha histórica
não revalidada e cenário nunca executado. Teste de ferramenta/documento não
mede progresso do produto. Não usar percentual de auditoria como pronto.
Se o inventário crescer após cobrir Circulares/subtelas, publicar denominador
anterior/novo e motivo, sem fingir regressão de implementação ou esconder ações.

## Horários firmes — 09/09/2026, America/Sao_Paulo (UTC−03)

| Horário | Obrigação |
| --- | --- |
| 16:00 | L01–L03 reportam commits, push, feito, testes, E2E e pendências a L00. |
| 16:00–16:45 | L00 consolida; executores corrigem problemas concretos da consolidação. Sem novas frentes. |
| 16:30 | D01–D04 reportam commits, push, feito, testes, E2E e pendências a D00. |
| 16:45 | L00 entrega consolidado final a D00; frentes Claude ficam em estado seguro e aguardam decisão. |
| Até 17:15 | D00 integra os dois grupos, resolve correções da consolidação, verifica Git e calcula métricas. |
| 17:15 | D00 entrega feedback final ao Owner. Todos param novos lotes/retomadas automáticas. |

Relatar no horário mesmo com pendência; não esconder atraso aguardando tudo passar.
Preparar checkpoint antes do corte e acompanhar o relógio entre passos seguros.
Após corte dos executores, apenas correções de consolidação até o limite do grupo.
Após 17:15, nenhuma continuação noturna/amanhã sem nova decisão do Owner.
Se iniciado tarde, executar só a fase ainda válida; nunca mover data silenciosamente.
Desativar agendamentos da rodada no fechamento; não afetar tarefas alheias.
Não desligar o host nem encerrar recursos de outras sessões.

## Git, recuperação e ambiente

D00 prepara worktrees/branches planejadas a partir da base integrada conferida;
não recriar as R01 arquivadas. Conferir se a tarefa já ganhou worktree pelo app
antes de criar outra. Registrar o caminho REAL; evitar worktree dentro de worktree.
Todos os prompts usam esse registro, não presumem que o caminho planejado exista.

Na preparação deste pacote, dev/origin-dev apontavam para
fb2d07d34a74c91ec1f65aff361048393e590729. Revalidar antes de executar.
Há delta LOCAL não commitado de Auth do turno interrompido, além de imagens
de comparação de login. Ver BASELINE-LOCAL.md. D00 preserva e encaminha a D01;
não é parte do HEAD, não desaparece com a criação de worktree e não é E2E pronto.
Preservar também este pacote documental antes de publicar a base para executores.
Após preservar e confirmar a transferência, reconciliar somente esses paths
na raiz de forma reversível. Enquanto restar delta local, declarar manifesto/hash
da árvore executada: não atribuir prova a um HEAD limpo. Conferir origem e
alterações novas antes de qualquer restauração de arquivo; nunca reset/clean genérico.

Durante execução é normal branch ficar à frente de dev. No fechamento,
todo delta precisa de destino: integrado e publicado; correção pendente
identificada; ou WIP preservado com origem, motivo e próximo passo.
Worktree limpa não prova integração. Arquivo de WIP não prova função concluída.
Verificar git status, stashes, SHAs locais/remotos, commits exclusivos e recibo
de integração origem→destino. Nunca reset --hard, clean, force-push, apagar
branch única ou remover worktree ativa para aparentar limpeza.
Ao preservar arquivos no Windows, usar caminhos absolutos verificados e a
mesma shell; não compor deleções/moves entre PowerShell e cmd.

Todo Supabase/Cloudflare remoto é produção. Credencial/MCP disponível não
autoriza mutação. Preparar pacote nominal revisado, provas locais e recuperação;
aplicar somente autorização válida para o pacote exato, forward-only e serial.
Não pedir de novo autorização válida; não pedir aprovação de pacote abstrato.
As correções locais independentes continuam enquanto aguarda a decisão remota.

## Formato do handoff

Rodada; ID real; revisão; última instrução processada; data/hora/fuso;
worktree/branch/baseline/HEAD; SHAs aptos e WIP separados; remoto verificado;
tela/subtela/action_ids; mudanças e evidências; testes P/F/B/S/U com escopo,
runner, ambiente e base; FE/BE/E2E; dependências solicitadas/liberadas;
primeiro critério aberto; próximo passo; recursos/processos ativos e parada.
Somente fatos observados; campos pendentes explicitamente pendentes.

## Conhecimento e fontes antigas

Atualize primeiro a fonte canônica quando mudar regra durável. Projete somente
o aprovado e para a audiência adequada. Status de trabalho fica em handoff/
rastreadores, não em uma aula artificial. Para Circulares, parágrafos históricos
em docs/knowledge/team/principal-circulars.md que mandam mídia nova para Supabase
Storage estão superados pela ADR0032 e AGENTS: usar R2 privado. Corrigir a
projeção no trabalho documental de L01 sem pedir nova decisão já estabelecida.
