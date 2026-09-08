---
title: "Prompts de retomada — Etapa 2 E2E"
source: "reconciliacao-pendencias-2026-09-08.md; inventario-etapa-2.json; AGENTS.md; skills Coelo e RTK"
status: "escopo reconciliado; estimativas a validar"
generated_at: "2026-09-08"
updated_at: "2026-09-08"
---

# Prompts de retomada — Etapa 2 E2E

## Quantidade, worktrees e tempo

Usar **sete novas conversas**: um coordenador, cinco frentes E2E e um
engenheiro de integração. O coordenador trabalha no checkout principal `dev`;
as outras seis usam worktrees novas. Não reutilizar as worktrees encerradas.

| Prompt | Worktree | Estimativa não validada: não usar como compromisso | Papel no caminho crítico |
|---|---|---:|---|
| Coordenador | checkout principal `dev` | 6–10 h distribuídas | leases, reviews, integração, testes e push |
| E2E 1 — Identidade e Acessos | `codex/etapa2-r2-identidade-acessos` | 18–30 h | Auth, Conta, Perfis/Modelos, Usuários, Convites |
| E2E 2 — Estruturas, Pessoas e Locais | `codex/etapa2-r2-estruturas-locais` | 30–48 h | Instituições, Unidades, Turmas, Locais, Pessoas, Alunos |
| E2E 3 — Comunicação e Mídia | `codex/etapa2-r2-comunicacao-midia` | 30–48 h | Chat, Avisos, Circulares, Acontece, Agora, Momentos, Perfil |
| E2E 4 — Formulários e Cuidado | `codex/etapa2-r2-formularios-cuidado` | 30–48 h | Forms, Respostas/XLSX, arquivos, Saúde, Medicação |
| E2E 5 — Agenda e Operações | `codex/etapa2-r2-agenda-operacoes` | 30–48 h | Agenda, Atividades, Avaliações, Assiduidade, Rotina, Planos/Cardápios |
| Engenheiro de integração | `codex/etapa2-r2-engenharia` | 12–24 h de capacidade | Docker, replay, conflitos e blockers compartilhados |

As faixas da tabela são hipóteses antigas, mantidas apenas para rastreabilidade.
Não há tempo de conclusão real validado. Cada frente deve reestimar o delta
restante após conferir commits já integrados, runner e primeiro gate aberto;
o coordenador calcula o caminho crítico sem somar frentes paralelas.
Decisões do Owner e leases de produção suspendem somente a ação dependente, não
as demais. A estimativa não promete `verified-e2e` sem acesso nominal aos
provedores reais.

## Contrato comum a colar em todos os prompts

Você trabalha na Etapa 2 E2E do Coelo, somente em `apps/superadmin` e nos
packages/backends usados por ele. Leia integralmente `AGENTS.md`, a reconciliação
`docs/reviews/evidence/etapa-2/coordenador/reconciliacao-pendencias-2026-09-08.md`,
os três rastreadores em `docs/reviews/` e as skills aplicáveis. Use `$rtk` em
comandos compatíveis e use o máximo útil de subagentes para revisões e tarefas
independentes, sem writers concorrentes nos mesmos arquivos.

Exiba sempre `Passo X/Y`, tela, subtela, `action_id`, arquivos e backend em
trabalho. `/dev` é fixture; sem `/dev` é composição produtiva Supabase. Mídia
nova usa Supabase como catálogo/autorização e Cloudflare R2 privado como master;
Stream segue a política da ADR 0032. Não exponha segredos no cliente.

Trabalhe por fatia vertical com TDD: RED, correção mínima, GREEN, permitido,
negado, revogado, tenant A/B, ID adulterado, persistência, reload, auditoria e
cleanup. Um teste local, golden, pgTAP isolado ou fail-closed não é E2E. Atualize
os três rastreadores no mesmo turno de cada mudança de estado. Faça commits
pequenos e envie ao coordenador SHA, testes, primeiro gate aberto e ETA.

Supabase e Cloudflare remotos são produção. Não faça migration, DDL/DML, deploy,
criação de bucket ou configuração sem lease explícito do coordenador para o
pacote nominal, com hashes, ordem e recuperação. Enquanto um lease estiver
pendente, continue todo trabalho local seguro e independente.

## Prompt 1 — Coordenador

Você é o coordenador da segunda rodada da Etapa 2 E2E. Trabalhe no checkout
principal `dev`; não implemente features grandes. Leia o contrato comum e a
reconciliação de 08/09. Sua sequência é Passo 1/7 inventário de branches/gates;
2/7 leases de arquivos e pacotes; 3/7 revisão contínua; 4/7 replays locais
serializados; 5/7 autorização nominal remota por pacote; 6/7 integração e
regressão; 7/7 atualização dos três rastreadores, push e limpeza.

Exija de cada frente tela/subtela/action_id, SHA, testes e primeiro gate aberto.
Use subagentes para revisar diffs independentes, nunca para editar o mesmo
arquivo simultaneamente. Preserve WIP em branch remota antes de limpeza. Não
aceite `local-green` como `verified`, SQL local como `done` ou mock como E2E.
Reestime coordenação e caminho crítico com base no delta medido, sem prometer
a janela antiga de 36–60 h. Distribua todos os 219 IDs entre as cinco frentes,
sem dupla propriedade. Inclua Auditoria/Suporte na frente 5, Catálogo na 4,
páginas de erro na 1 e Segurança infantil na 2; confirme o cruzamento de
Circulares com principal_profile. Esta preparação não autoriza criar conversas
agora; na execução autorizada deste prompt, crie as seis tarefas com o contrato
comum e seus prompts completos, em worktrees novas.

## Prompt 2 — E2E 1: Identidade e Acessos

Crie worktree/branch `codex/etapa2-r2-identidade-acessos`. Leia o contrato
comum. Trabalhe em seis passos: 1/6 Auth e Shell; 2/6 Conta; 3/6 Perfis de
acesso; 4/6 Modelos; 5/6 Usuários internos; 6/6 Convites e regressão conjunta.

Comece pelos pacotes preservados na branch remota
`codex/e2e-identidade-acessos`, selecionando commits por patch/review, sem merge
cego. Feche sessão vencedora, recovery, caches por autorização, capabilities,
realm interno, paginação, comandos, suspensão/convites e negativos. Users49
48/48 e ModelReadGreen50 38/38 locais já existem; não refaça seus readers.
Perfis tem ACL 42501 no cursor privado: confira esse gate nominal. Preserve
AAL1 vigente; MFA só no encerramento formal conforme ADR 0019. Inclua páginas
de erro; tema/configurações locais exigem reload/restart, não tabela Supabase.
Peça lease nominal antes de qualquer Auth/SQL remoto. Reestime o delta.

## Prompt 3 — E2E 2: Estruturas, Pessoas e Locais

Crie worktree/branch `codex/etapa2-r2-estruturas-locais`. Leia o contrato comum.
Trabalhe em seis passos: 1/6 Instituições; 2/6 Unidades; 3/6 Turmas; 4/6 Locais;
5/6 Pessoas/Alunos/vínculos; 6/6 regressão e E2E cruzado.

Recupere seletivamente `codex/e2e-estruturas-pessoas-locais`. Execute
Test-LocationRemoteSnapshot.Tests.ps1 diretamente em PowerShell: não possui
casos Pester. Zero descobertas não é defeito a corrigir. Confira o snapshot
nominal e depois faça replay. Readers de detalhe Unidades/Turmas/Pessoas já
estão compostos; Alunos ainda precisa comprovar UI/DI. Inclua Segurança infantil.
Não troque RPC interno por people-based. Feche hierarquia, tenant A/B,
vínculos, mapa/privacidade, foto R2 e reload. Import/export geral continua
adiado e apenas visível/indisponível. Reestime o delta.

## Prompt 4 — E2E 3: Comunicação e Mídia

Crie worktree/branch `codex/etapa2-r2-comunicacao-midia`. Leia o contrato comum.
Trabalhe em seis passos: 1/6 Chat; 2/6 Avisos; 3/6 Circulares; 4/6 Acontece;
5/6 Agora/Momentos; 6/6 Para Você/Perfil e regressão.

Parta do `dev`, onde Acontece `50473bd8` já está integrado, e consulte
`codex/e2e-comunicacao-midia-principal` apenas para commits não equivalentes.
Feche RPCs/eventos/outbox, audiência materializada, anexos R2, tickets curtos,
cache/revogação, Realtime e políticas Stream: Agora até 24 h; Momentos por
demanda medida; Acontece por métrica; Chat sem Stream obrigatório. Circulares
precisa de cruzamento com os IDs aprovados, não nova família presumida.
Reestime o delta.

## Prompt 5 — E2E 4: Formulários e Cuidado

Crie worktree/branch `codex/etapa2-r2-formularios-cuidado`. Leia o contrato
comum. Trabalhe em seis passos: 1/6 corrigir checkpoint vermelho de opções;
2/6 autoria/listagem; 3/6 respostas/branching; 4/6 XLSX do formulário inteiro;
5/6 arquivos/imagens R2; 6/6 Saúde/Medicação e regressão.

Recupere seletivamente `codex/e2e-formularios-cuidado` e o preflight em
`codex/e1-replay-harness-20260907`. O RED atual é duplicação dependente em
Forms (+101/-1, total 102); reproduza antes de concluir a causa. O preflight
teve +48/-23 no runner central, mas 71/71 no runner Pester 3.4.0 do autor:
reconcilie versão/invocação antes de modificar o script. FREAD51 já tem 117/117
local. Lifecycle/dispose de Cuidado já foram corrigidos; quatro diferenças
golden e decisões clínicas continuam gates. Inclua Catálogo. Feche
F-AUTHOR01/02 local antes de pedir lease.
O único export real do MVP é um XLSX com as respostas do formulário, em R2
privado, reautorizado, expirável e auditado. Reestime o delta.

## Prompt 6 — E2E 5: Agenda e Operações

Crie worktree/branch `codex/etapa2-r2-agenda-operacoes`. Leia o contrato comum.
Trabalhe em seis passos: 1/6 revisar o delta dos quatro goldens da view Agenda;
2/6 Agenda CRUD/solicitações; 3/6 Atividades; 4/6 Avaliações; 5/6 Assiduidade e
Rotina; 6/6 Planos/Cardápios e regressão.

Recupere seletivamente `codex/e2e-agenda-operacoes`; `ca4c82ab` passou na fonte,
mas foi revertido do `dev` por quatro diferenças golden. Não rebaselineie em
massa. Reader/controller e backend Agenda já existem, assim como o adapter
51c02b75 de Atividades (A01GREEN55 97/97 local). Avaliações tem migration v2
20260901182838, commit 831fb5a8: compare contrato e replay 039, não implemente
do zero. Prove conflitos/reload; entrega de notificações está fora da spec 050.
Planos tem spec 051 aprovada/backend existente: resolver conflito 051/039 e
crosswalk activate/assign com escopo aprovado. Inclua Auditoria/Suporte.
Operações gerais de import/export permanecem adiadas. Reestime o delta.

## Prompt 7 — Engenheiro de integração

Crie worktree/branch `codex/etapa2-r2-engenharia`. Leia o contrato comum. Você
não escolhe produto nem invade ownership das verticais. Receba blockers do
coordenador e trabalhe em quatro passos: 1/4 reproduzir; 2/4 identificar causa
raiz; 3/4 preparar correção/replay mínimo com TDD; 4/4 entregar SHA/evidência e
devolver o lease.

Prioridades iniciais: invocação direta do script Locais, reconciliação dos
runners do preflight Forms (48/71 central versus 71/71 autor),
quatro goldens Agenda no `dev`, Docker/Supabase local e conflitos de migrations.
Use subagentes para diagnóstico/review independentes; um único writer opera
Docker, migrations e recursos compartilhados. Não faça mutação remota sem lease
nominal. Reestime capacidade somente pelos blockers reproduzidos.
