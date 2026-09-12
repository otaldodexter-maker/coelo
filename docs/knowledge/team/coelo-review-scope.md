---
title: "Recorte e evidência das revisões Coelo"
knowledge_id: "coelo-review-scope"
source: "AGENTS.md"
status: "validated"
generated_at: "2026-09-08"
updated_at: "2026-09-12"
audience: "team"
surfaces: [documentation, frontend, backend, integration]
visibility: "internal"
review_owner: "Coelo Owner"
---

# Revisão proporcional ao recorte

Auditoria ou conclusão ampla exige leitura integral dos rastreadores das
camadas. Correção localizada usa cabeçalhos, ações, dependências e evidências
afetadas. Explicação ou manutenção de skill não inicia auditoria de produção.
Reutilizar leituras; dependências de skills não reiniciam em ciclo.

Preservar escopo e autorização já dados, sem exigir nova pergunta de tempo.
Estimar o delta real após inspecionar o existente, separando implementação,
verificação e espera externa. Número de ações não equivale a horas de trabalho.

Frontend, Backend e E2E têm provas próprias. Ausência de certificado não
comprova código ausente, e evidência local não comprova fluxo produtivo.
Atualizar rastreadores afetados quando seu estado mudar; correção de skill
não certifica ações do produto. Remoto continua produção com autorização nominal.

Na Etapa 2, identificar Superadmin, menu, tela, subtela/estado e action_id em
cada checkpoint de entrega. Coelo (Principal) é um menu desse app. Usar IDs
únicos e denominadores aplicáveis por camada; separar avanço local, conclusão
FE/BE/E2E e a base geral conhecida, com data e evidência.

Testes mostram aprovação e falha sobre os casos executados conclusivos,
acompanhadas da execução e aprovação do plano completo conhecido. Bloqueados,
ignorados e não executados permanecem visíveis; reruns e resultados históricos
não inflam a medição. Sem plano ou evidência atual, declarar o dado faltante.
As fórmulas e o formato operacional estão na spec de métricas referida pelo
AGENTS.md. Retomadas fecham o primeiro gate aberto do recorte e reutilizam o
que continua válido; manutenção documental não é progresso de implementação.

Invocação destas skills para trabalhar no projeto assume resolução de
pendências, com correção local, testes e evidências. Retomar o recorte atual
ou escolher a próxima ação executável da Etapa 2 sem exigir confirmação de
rotina. Encerrar quando os aceites do recorte estiverem resolvidos ou houver
impedimento demonstrado depois do trabalho independente. Relatório registra
o resultado; sozinho não resolve a pendência. Explicação/review somente leitura
e edição da própria skill não iniciam implementação do produto.

Retomada confere worktrees, base integrada, protocolo/fechamento da rodada e
handoff por revisão, data e SHA. O `dev` local pode estar desatualizado. Rodada
encerrada não reinicia automaticamente. Preservar ownership: executor propõe
deltas no handoff, e o escritor central reconcilia matrizes. Atualizações de
skills precisam chegar ao checkout de destino; commit/push/deploy são separados.

Correções que o Owner apontou nos anexos de cada tela/subtela e sua integração
orientam o trabalho. Preservar a composição aprovada e relacionar referência,
correção e aceite; anexo salvo não comprova correção implementada.

Definir testes pelos aceites e impacto. Depois de verdes, seguir ao próximo
gate. Repetir/ampliar por mudança, nova falha, evidência insuficiente ou prova
obrigatória da base integrada, com motivo explícito. Não duplicar lotes nem
somar reruns. Relatar falhas resolvidas/novas e aceite alcançado. Estimativa usa
delta inspecionado e duração medida comparável; não horas fixas por tela.

Cloudflare em escopo usa descoberta do plugin/MCP instalado e skills pertinentes,
com Wrangler quando aplicável. Ferramenta disponível não comprova acesso à conta.
Pacote nominal autorizado segue até implantação e verificação, sem reabrir
permissão já válida nem substituir esse gate por testes locais repetidos.

Fechamento com integração/publicação reconcilia commits, stash, alterações locais
e divergência remota. Skills e referências entram na base entregue. Preservar e
identificar WIP retido antes de arquivar/remover worktree encerrada; arquivamento
não equivale a código integrado. Usar o checkout consolidado e criar isolamento
quando necessário, com destino e responsável definidos. Checkpoint local não é
entrega integrada enquanto commit/push autorizado estiver pendente.

Skills são instruções para o agente e orientam também a entrega do app real.
A branch Git `dev` é a base atual de versionamento, não um ambiente de testes.
As mesmas regras valem para produção, respeitando o escopo remoto autorizado.

Revisões visuais seguem a Decisão20 da ADR0034: arquivo, referência R, render
A, diferença, decisão A/A+/R, observação e versão salva. A+ exige ajuste e R
não é aprovado. O indicador conta IDs únicos com A explícito mapeado ao estado,
sem confundir quantidade de imagens com ações nem aprovação visual com E2E.
Rodadas usam um Chrome e um flutter test globais por slots; C0 recebe e publica
em ciclos agendados até o corte. Uma rodada encerrada não inicia a seguinte.
