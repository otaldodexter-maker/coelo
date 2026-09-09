---
title: "E2 R02 — iniciar as sete frentes"
source: "Owner nesta tarefa; CONTRATO.md; registro.json; escopo.json"
status: "prepared-not-started"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Execução preparada para 09/09/2026

[Copiar os nove prompts](PROMPTS.md).
[Contrato completo](CONTRATO.md).
[O que entra e o que falta na Etapa 2](ESCOPO.md).
[Regra visual e referências do Principal](PRINCIPAL.md).
[Delta local herdado a preservar](BASELINE-LOCAL.md).

## Como iniciar

1. Abra uma tarefa Codex no checkout C:/Users/adrie/Documents/Coelo,
   selecione Astra/médio e cole D00. D00 prepara e informa os caminhos reais.
2. Abra L00 no Claude na worktree confirmada por D00, selecione Opus 5/médio
   se disponível e cole L00. Os dois verificam a ponte e registram os limites reais.
3. Abra D01–D04 no Codex e L01–L03 no Claude, cada um na própria worktree
   confirmada, e cole o respectivo prompt. Não executar todas as tarefas na raiz.
4. Os sete executores usam subagentes úteis internamente e continuam o recorte
   sem pedir autorização por tela. Coordenadores acompanham sem cobranças repetidas.

Cada prompt curto abre um arquivo completo versionável. A seleção do modelo é
feita no aplicativo: escrever o nome no prompt não troca o modelo ativo.
Registrar o modelo real; se o nome não estiver disponível, informar isso antes
de prometer o desempenho de outro modelo. Esta combinação é uma escolha
inicial de trabalho, não um benchmark de velocidade do Coelo.

| Tarefa | Modelo sugerido / esforço |
| --- | --- |
| D00, D01, D04 | GPT-6 Astra / médio |
| D02, D03 | GPT-5.6 Sol / médio |
| L00, L01, L02, L03 | Claude Opus 5 / médio |

## Compromisso de hoje — horário de Brasília

- Claude: executores reportam16:00; consolidado L00 chega a D00 até 16:45.
- Codex: executores reportam16:30; D00 entrega consolidado ao Owner até 17:15.
- Commits aptos circulam antes desses horários; os cortes não são início de integração.
- Às17:15, novos lotes e retomadas automáticas param. O Owner decide a continuação.
- Se colar depois do horário, aplicar somente a fase ainda válida; não reagendar
  para amanhã implicitamente.

A criação destes documentos não executou os prompts, não ativou agendas e não
iniciou as frentes. Planejamento não comprova worktree criada, comunicação
funcionando ou tarefas ativas. Os campos reais de [registro.json](registro.json)
devem ser preenchidos na abertura.

## Persistência sem burocracia

Assignment curta por contexto; handoff próprio com revisão; commit/evidência
por entrega; inventário central escrito por D00. Retomar desses arquivos e da
base real, sem depender da memória de uma conversa nem reler todo o histórico.
Nenhuma regra de status deve exigir que o executor pare uma correção independente
para aguardar um ACK. Coordenador também resolve e integra.

As skills são instruções dos agentes, usadas em qualquer branch que as contenha.
Versioná-las em dev distribui a mesma orientação às worktrees futuras; não
limita seu uso ao ambiente dev e não implanta código em produção por si só.

[Uso opcional de uma terceira IA](TERCEIRA-IA.md).

Atualização do Owner: [Locais integralmente na D02](ADENDO-LOCAIS.md).
A seleção passa a 120 ações E2E e o restante a 67, sem promover conclusão.
D00 reconcilia o registro/assignment na próxima leitura; D02 aguarda o comando.

## Conferência da preparação

Na preparação original foram conferidos nove papéis, 219 IDs sem duplicação,
divisão 132/87 e contagem E2E116/71; o adendo Locais atualiza para 136/83 e 120/67.
As
referências locais e hashes dos dez arquivos de aplicativo herdados foram
conferidos. A revisão independente dos prompts não encontrou conflito material.
Nenhuma suíte do aplicativo foi executada para preparar este pacote.
O gate documental de conhecimento validou54 artigos e12 cenários do harness;
um cenário de symlink foi ignorado pela limitação do host. Isso não mede avanço
do aplicativo. Projeção de conhecimento: no-op; a coordenação foi registrada
na fonte operacional e a dúvida de viewers em docs/open-questions.md.

Git continua com apenas a worktree principal e as mudanças locais identificadas.
Não houve commit/push nem implantação nesta preparação. Revalidar a base real
ao iniciar D00; não repetir inspeções inalteradas como se fossem novas entregas.
