---
title: "Auditoria sequencial das cinco skills Coelo"
source: "Pedido do Owner em 2026-09-08; AGENTS.md; cinco skills e fontes citadas neste relatório; evidências locais anexas; orientação oficial OpenAI consultada em 2026-09-08"
status: "remediated-local-verified"
generated_at: "2026-09-08"
---

# Auditoria das skills Coelo

As cinco skills foram reavaliadas e os defeitos confirmados corrigidos, após
pedido explícito do Owner. UI, Backend, Frontend e Knowledge foram relidas antes
das correções; Tutor foi mantida no escopo original. Não houve mudança de telas,
goldens, migrations, produção ou estados dos três rastreadores da Etapa 2.

## Correções aplicadas em 2026-09-08

| Achado | Resultado |
| --- | --- |
| UI-01 — mídia | Origem/master separados; ADR 0032 por finalidade; crop legado 851:315 documentado sem redesenho. Referência antiga a Storage na spec de Publicar reconciliada. |
| UI-02 — descoberta | Quatro caminhos ausentes reparados, ID de color picker corrigido, identificação de `CoeloTimeField` corrigida; índice com 80 entradas válidas. |
| UI-03 — espaçamento | Contrato/teste de itens discretos convergem para `space1`, sem mudar componentes. |
| UI-04 — famílias visuais | Administrativo preservado como referência do Admin. Principal tem descoberta e contratos próprios no mesmo host. Site tem composição própria futura. Publicar mantém geometria externa/rodapé e etapas aprovados. |
| TUT-01 | Modos somente leitura não escrevem memória; explicação pontual não obriga quiz. Evidência de compreensão continua obrigatória. |
| TUT-02 | Git/GitHub incluídos na trilha pelo pedido já registrado; progresso do usuário intacto. |
| TUT-03 | Fonte única em `.agents`; cópia local ignorada de `.codex` removida da descoberta, com aviso de migração. |
| BE-01 | URLs curtas transitórias autorizadas diferenciadas de segredos/URLs embutidas, persistidas como acesso permanente ou logadas. |
| FE-01 / FLUXO-01 | Removidos denominadores e prazos fixos, pergunta obrigatória de tempo e dependências recursivas. AGENTS e skill integrada reconciliados com leitura por recorte. |
| KNOW-01/02/03 | Parser YAML real com tipos, datas, chaves duplicadas, limites da fonte, ID único por audiência e detecção de credencial sem bloquear orientação segura. |
| Busca de conhecimento | Somente `validated` por padrão; status explícito para inspeção; alias user/users; metadados opcionais. Consulta literal documentada. |
| Governança | Frontmatter de procedência nas entradas; contexto UI principal reduzido de 260 para 59 linhas, preservando o fluxo administrativo em referência carregada por família. |

Segurança, isolamento de apps, autorização de produção, evidência de conclusão
e aprovação de padrões visuais novos permanecem. Ausência de certificado não
significa implementação ausente. A correção local de uma skill não certifica
Frontend, Backend ou E2E do produto.

## Verificação das correções

- Seis entradas passam no validador de skills (cinco solicitadas e a integrada,
  ajustada para eliminar o ciclo de dependências).
- Índice, fronteiras de pacote, consulta e contrato de interação passam.
  O teste de documento aprovado ausente falhou antes da correção e passou depois;
  suíte Dart do validador: 12 testes aprovados, análise sem problemas.
- Conhecimento: todos os 15 probes de validação e quatro observações de busca
  têm comportamento esperado. Suíte Python: 12 testes aprovados e um teste de
  symlink pulado porque o host não permite criá-lo; smoke PowerShell aprovado.
  Os 54 artigos atuais passam no gate, incluindo duas projeções duráveis novas.
- Dois cenários UI em agentes de contexto novo compararam a versão anterior e
  posterior. Antes, o agente já escolheu Principal pelas specs/pedido, mas
  encontrou conflito e busca vazia. Depois, encontrou o padrão certo e apontou
  a nuance da geometria externa de Publicar, incorporada à correção. Isso prova
  melhora de descoberta/consistência; não autoriza afirmar erro de execução
  anterior, aprovação de screenshots ou confiabilidade universal do modelo.
- Links locais e frontmatter dos Markdown alterados conferidos; diff sem erros
  de whitespace. Nenhum teste de app ou golden foi atualizado para mascarar erro.

Evidências: [estado antes das correções](evidence/2026-09-08-coelo-skills-audit/before-corrections.json),
[estado após correções](evidence/2026-09-08-coelo-skills-audit/after-corrections.json)
e [probes reproduzíveis](evidence/2026-09-08-coelo-skills-audit/check_skills.py).
A unicidade de ID por audiência, proposta na auditoria inicial, agora faz parte
do contrato operacional. Os testes automatizados não provam aprovação ou
atualidade das fontes, nem ausência de toda PII; a revisão humana permanece.
Scripts de conhecimento exigem Python 3.10+ e PyYAML conforme requirements.

## Pendências preservadas fora da correção das skills

- A finalidade de capa panorâmica exige adaptar/verificar a saída do crop legado
  ao conectar mídia real; não foi feita alteração visual ou de integração.
- O catálogo tinha 16 diagnósticos de sincronização na comparação com o índice
  anterior. Dois eram a identificação de `CoeloTimeField`, corrigida; permanecem
  14 divergências anteriores entre código e exemplos de outros componentes.
  [Comparação anterior](evidence/2026-09-08-coelo-skills-audit/catalog-sync-before.json)
  e [resultado final](evidence/2026-09-08-coelo-skills-audit/catalog-sync-final.json).
  Somente os quatro exemplos textuais de referência alterados nesta tarefa
  receberam atualização explícita de fingerprint após conferência. Fingerprints
  dos demais componentes foram preservados. O catálogo não está certificado como
  sincronizado, mesmo que o comando retorne código zero.
- O teste de symlink precisa de host com permissão para executar esse caso; as
  demais negativas de caminho foram exercitadas. A implementação resolve caminhos
  antes de conferir contenção, mas o caso de symlink não é declarado comprovado.

Memória: regras de famílias visuais e recorte foram projetadas para audiência
`team`, após atualizar Design System/AGENTS. Nenhum registro de aula foi criado.
O Owner pediu coordenação com a tarefa “Auditar Etapa 2 do Superadmin”: foi
comunicada a lista de arquivos em edição e a separação entre esta correção e
certificação do produto. Não houve commit, merge ou deploy.

## Auditoria inicial preservada

As seções abaixo registram a investigação anterior às correções. Números de
linha, verbos no presente, riscos e recomendações referem-se àquele snapshot;
o estado atual é o descrito acima.

## Contrato e limites

- **Objetivo:** identificar instruções que induzem erro, bloqueio desnecessário, perda de contexto ou conclusão sem evidência.
- **Incluído:** `SKILL.md`, metadados, recursos auxiliares, testes existentes, dependências diretas e confronto com fontes canônicas relevantes.
- **Ordem executada:** `coelo-ui` → `coelo-tutor` → `coelo-backend` → `coelo-frontend` → `coelo-knowledge`. Sem subagentes. Knowledge foi consultada inicialmente como governança; sua auditoria detalhada ficou por último. A conferência mecânica final cruzou as cinco.
- **Fora:** correção das próprias skills, implementação dos apps, auditoria integral dos backlogs, avaliação jurídica, alterações remotas, deploy, commits e alteração de modelo/configuração.
- **Pendências conhecidas no início:** nenhuma conclusão prévia sobre defeitos das skills foi presumida. Foram usados os rastreadores para localizar estado e dependências, sem transferir a auditoria para as centenas de ações dos apps.
- **Critério de parada:** cinco entradas examinadas, referências relevantes confrontadas, scripts exercitados localmente e achados acompanhados de localização, impacto e recomendação.
- **Evidências:** [script reproduzível](evidence/2026-09-08-coelo-skills-audit/check_skills.py), [resultados e hashes](evidence/2026-09-08-coelo-skills-audit/results.json), comandos e fontes abaixo. Estimativa inicial comunicada: 30–45 minutos; não é medição de tempo ativo nem ETA de correção.

O snapshot de evidência identifica o Git HEAD e o SHA-256 de cada entrada. Durante a auditoria, outra atividade criou `docs/reviews/reconcile-trackers.cjs` e reorganizou os três rastreadores, arquivando o histórico; todas essas alterações foram preservadas. A evidência JSON antecede essa reorganização. Os rastreadores não foram lidos/auditados integralmente. Uma tentativa de leitura ampla do rastreador Backend anterior foi truncada; isso não foi tratado como leitura completa. Não foram executados novos testes comportamentais com um agente em contexto independente: riscos de interpretação estão explicitamente separados de falhas de scripts.

A OpenAI recomenda auditar instruções conflitantes para GPT-6 Astra, pois sua maior sensibilidade às instruções pode acentuar pausas indevidas. Também recomenda gatilhos precisos e carregamento progressivo nas skills. Isso orienta esta auditoria, sem constituir promessa de ausência de erros. Fontes: [orientação de GPT-6 Astra](https://developers.openai.com/api/docs/guides/latest-model#instruction-following) e [construção de skills](https://learn.chatgpt.com/docs/build-skills).

## 1. coelo-ui

**Preservar:** autoridade do Design System, componentes compartilhados, isolamento do Principal, acessibilidade, proteção dos goldens e distinção entre proposta e padrão aprovado. A regra de Instituições como baseline geral de cards foi confirmada no Design System; não é uma invenção isolada da skill.

### UI-01 — P1: contrato de mídia antigo conflita com a ADR 0032

**Evidência:** [form-layout-contracts.md](../../.agents/skills/coelo-ui/references/form-layout-contracts.md), linhas 67–79, limita a origem do avatar a 2 MB, afirma que a correção permanece local e obriga capa 16:9 com `CoverCropDialog`. A [ADR 0032](../../decisions/0032-mvp-private-media-r2.md), linhas 138–144, diferencia origem do avatar/logo de até 8 MiB e master de até 2 MiB, e define capa panorâmica 3:1. O [Design System](../design/design-system.md), linhas 562 em diante, também preserva texto anterior de upload.

**Impacto:** seguindo a referência obrigatória, um agente pode rejeitar uma origem permitida, escolher recorte incompatível com a finalidade de mídia ou manter uma integração artificialmente local. É uma divergência documental comprovada; esta auditoria não afirma que todo upload em runtime falha.

**Correção recomendada:** mapear as finalidades de capa abrangidas por cada contrato, separar origem/master/variante e reconciliar Design System, contrato de formulário e índice com a decisão vigente. Remover a frase sobre “esta correção” de um procedimento reutilizável. Não trocar globalmente todo 16:9 por 3:1: outras imagens têm finalidades distintas. Conflito registrado em `docs/open-questions.md`; nenhuma regra visual foi alterada nesta auditoria.

### UI-02 — P2: o caminho de descoberta leva a recursos ausentes

**Evidência:** no índice de 79 entradas, quatro referências de arquivo apontam para destinos ausentes:

- linha 43: `help_center_page_golden_test.dart`; o arquivo atual é `superadmin_help_center_page_golden_test.dart`;
- linhas 58 e 66: `references/deep-review-prompt-brief.md`, usado por duas entradas de governança;
- linha 72: `references/calendar-date-picker-contract.md`.

Além disso, `approved-superadmin-visual-baselines.md:40` cita `pattern.advanced-color-picker`, ausente do índice. Os 17 links Markdown locais verificados existem; o problema está nas referências de caminhos/IDs, que esse teste de links não cobre.

**Impacto:** consultas de calendário, briefing e baseline chegam a um caminho morto, embora o recurso esteja marcado `approved`. O agente pode parar ou improvisar uma alternativa.

**Por que os gates passaram:** `validate_catalog_index.dart:246` só exige existência de arquivos para `implemented`, `deprecated` e `catalog-stale`; referências `approved` não recebem essa checagem. Os testes de consulta verificam recuperação de IDs, não a abertura do material indicado.

**Correção recomendada:** corrigir o nome do teste da Home; recuperar os contratos por proveniência antes de republicá-los, ou marcar a indisponibilidade sem inventar aprovação; reconciliar o ID do seletor de cores. Exigir existência das referências normativas já usadas como instruções, distinguindo-as de caminhos de implementação futura em propostas.

### UI-03 — P2: duas medidas incompatíveis para o mesmo espaçamento

**Evidência:** `surface-interaction-contracts.md:43` exige `CoeloSpacing.spaceHalf` entre itens discretos. `admin-directory-flyout-contracts.md:117` em diante, a entrada principal da skill e `docs/design/design-system.md:905` exigem `space1`. `surface-interaction-contracts.tests.ps1:29` ainda procura literalmente `spaceHalf`.

**Impacto:** dois caminhos obrigatórios de leitura dão respostas diferentes; o teste textual protege a redação desatualizada.

**Correção recomendada:** reconciliar a referência com a regra canônica e verificar o espaçamento do componente real. Preservar a distinção entre gap de itens e respiro de divisor. Conflito registrado em `docs/open-questions.md`.

**Melhoria de organização:** a entrada tem 260 linhas/18.812 bytes, com muitos contratos repetidos nas referências. Manter na entrada objetivo, recorte por app, consulta do índice e decisões essenciais; carregar contratos por tarefa. O gate de golden anterior ao código tem fundamento nas fontes aprovadas e não deve ser removido silenciosamente. Sua eventual simplificação exige distinguir reutilização de padrão aprovado, criação de evidência e aprovação de padrão novo.

## 2. coelo-tutor

**Preservar:** código real, linguagem de iniciante, trilha persistente, dados fictícios, aula sem mutações remotas e compreensão condicionada à resposta do usuário.

### TUT-01 — P2: o contrato de memória não distingue os modos

**Evidência:** `SKILL.md:21` determina revisar mudanças “sem modificar arquivos”, mas `SKILL.md:57` manda atualizar o progresso “durante cada interação”. A tabela inclui `progresso`, que pode ser uma consulta sem aprendizado novo. O contrato de aula exige checagem e espera, sem declarar claramente a aplicação exclusiva a aula/quiz/exercício.

**Impacto:** risco de escrever memória em uma consulta de status ou revisão somente leitura, ou transformar explicação curta em aula obrigatória. É risco de interpretação por inspeção, não falha comportamental de Astra reproduzida nesta sessão.

**Correção recomendada:** definir leitura/escrita e formato por modo; atualizar memória quando houver conteúdo apresentado ou evidência nova; deixar explícita a exceção documental em aulas e o `no-op` para consulta sem mudança. Não presumir compreensão nem obrigar quiz quando o usuário pedir somente uma explicação curta.

### TUT-02 — P2: pedido durável de Git/GitHub não entrou na trilha

**Evidência:** `docs/learning/progress.md:110` registra que o usuário pediu Git e GitHub em 2026-07-15. `docs/learning/curriculum.md` mantém oito fases sem esses assuntos, e a descrição da skill também não os identifica.

**Impacto:** a sequência curricular pode nunca apresentar um tema já solicitado.

**Correção recomendada:** incorporar Git/GitHub à fonte curricular, ligando-os a mudanças, diff, commit, branch e colaboração, sem marcar assuntos como já compreendidos. A prioridade e profundidade podem acompanhar o ponto atual do estudante.

### TUT-03 — P3: duas cópias descobertas, sem contrato de manutenção

**Evidência:** `.agents/skills/coelo-tutor` e `.codex/skills/coelo-tutor` aparecem no contexto e têm `SKILL.md` idêntico por SHA-256; os metadados também coincidem. O design original aponta para `.codex`, e o pedido atual aponta para `.agents`.

**Impacto:** não há divergência atual. Há duplicidade de descoberta e risco de uma edição futura atualizar apenas uma cópia.

**Correção recomendada:** definir uma origem canônica e uma estratégia explícita de compatibilidade/sincronização. Não apagar o caminho antigo sem conferir seus consumidores.

## 3. coelo-backend

**Preservar:** tratamento de todo remoto como produção, autorização por pacote nominal, RLS/tenant/ownership no servidor, media gateway, ADR 0032, serialização, cleanup e separação entre `local-green`, `remote-green` e `done`. R2 e a exceção XLSX de Formulários estão representados corretamente na entrada.

### BE-01 — P2: proibição genérica de URL temporária conflita com o fluxo autorizado

**Evidência:** `SKILL.md:62–64` inclui “URL temporária em Flutter, Astro” na proibição de credenciais. `SKILL.md:112` exige URL curta após reautorização, e a ADR 0032, seção Media Gateway, prevê presigned PUT/GET usado pelo cliente.

**Impacto:** o texto não distingue segredo permanente de uma URL curta legitimamente recebida em runtime. Pode bloquear upload/playback autorizado ou induzir uma mudança arquitetural desnecessária.

**Correção recomendada:** proibir embutir, versionar, registrar e persistir URLs assinadas como credenciais permanentes; permitir seu consumo transitório no cliente autorizado, limitado por operação, objeto e TTL. Isso não permite chaves R2/Stream, signing keys ou `service_role` no cliente, nem mídia privada no Site. Ambiguidade registrada em `docs/open-questions.md`.

O número de 34 tabelas sem RLS na entrada vem de uma auditoria remota histórica identificável. Não foi revalidado remotamente nesta tarefa. Convém substituí-lo por uma referência datada ao rastreador, preservando o alerta até evidência própria de resolução.

## 4. coelo-frontend

**Preservar:** recorte explícito por app, autoridade visual de `coelo-ui`, fronteiras de packages e distinção entre cliente `verified` e integração real.

### FE-01 — P2: denominador desatualizado dentro da instrução

**Evidência:** `SKILL.md:55` fixa 207 ações. `docs/reviews/coelo-flutter-pendencias.md:7` registra 219 ações/38 famílias, tanto antes quanto depois da reorganização concorrente. O fechamento anterior, agora em `docs/reviews/archive/2026-09-08/coelo-flutter-pendencias.md`, declara explicitamente que 207 é histórico.

**Impacto:** percentual e restante podem ser calculados sobre uma base errada mesmo com a fonte atual disponível.

**Correção recomendada:** remover a contagem fixa da skill e obter denominador, data e estado do fechamento vigente. Não substituir simplesmente 207 por outro número fixo. Preservar os três denominadores independentes de Front-end, Backend e integração.

### FLUXO-01 — P2: dependências e perguntas obrigatórias ampliam tarefas pequenas

**Evidência:** Front-end, linhas 27–41, exige leitura do rastreador, `ponytail`, TDD, review e responsividade; presença de Auth/persistência aciona a skill integrada. Backend, linhas 29–48, exige leitura integral antes de analisar/estimar e consulta da integrada. A integrada exige de novo Front-end/Backend e os três rastreadores inteiros. Front-end:77 e Backend:119 mandam perguntar pelo tempo quando ele não foi informado, mesmo quando o pedido já delimita uma correção pequena.

**Impacto:** tarefas como revisar um texto de erro do login ou explicar um contrato podem ganhar protocolo de auditoria completa, consulta de produção e uma pergunta que não muda a solução. O ciclo de dependências não tem regra explícita de “já carregada”; não se afirma que exista recursão infinita no runtime.

**Dimensão observada:** os três rastreadores somavam 1.311.388 bytes e 11.476 linhas no snapshot, antes de specs, referências ou código. O carregamento integral expunha também checkpoints históricos supersedidos. No fechamento desta auditoria, a reorganização feita por outra atividade separou o histórico e reduziu os três arquivos ativos a 324.789 bytes; isso mitiga parte do problema e não é uma correção produzida por esta auditoria. A dependência incondicional e a pergunta obrigatória continuam nas skills. A leitura integral existe igualmente no `AGENTS.md` para revisões aplicáveis; mudar somente a skill não resolve a origem dessa regra.

**Correção recomendada:** distinguir consulta/explicação, implementação focal e auditoria de conclusão. Usar fontes vigentes e recorte por ação com links ao histórico; carregar dependências uma vez e quando necessárias. Perguntar sobre tempo apenas quando a escolha alterar materialmente escopo ou entrega. Preservar autorização nominal de produção e os gates de segurança. Qualquer revisão da regra de leitura integral deve reconciliar `AGENTS.md`, skills e rastreadores, sem enfraquecer silenciosamente o contrato aprovado.

## 5. coelo-knowledge

**Preservar:** projeção subordinada à fonte canônica, separação de audiência, proibição de dados sensíveis e `no-op` quando nada durável muda. A base atual passou no validador; isso não prova a ausência de todo dado sensível ou erro semântico.

### KNOW-01 — P2: existência do caminho não prova fonte canônica

**Evidência reproduzida:** `scripts/Test-CoeloKnowledge.ps1:112–122` rejeita caminho absoluto e verifica existência, mas aceita `../external.md`, diretório `docs` e o próprio artigo como `source`. Os três casos retornaram exit 0 em uma árvore temporária sintética; a fonte externa também era um arquivo sintético da própria auditoria.

**Impacto:** uma projeção pode receber PASS sem fonte canônica interna válida. Não houve leitura de arquivo externo real nem demonstração de vazamento de produção.

**Correção recomendada:** resolver caminho absoluto e conferir contenção na raiz, exigir arquivo, impedir fonte na própria projeção e verificar autoridade/status da fonte durante a revisão semântica. Um teste de existência isolado não comprova aprovação.

### KNOW-02 — P2: o parser não valida YAML nem seus tipos corretamente

**Evidência reproduzida:** `Read-Frontmatter`, linhas 40–71, extrai pares por regex. Rejeitou YAML válido com `surfaces` em lista de bloco; aceitou `surfaces: []` e data impossível `2026-99-99`.

**Impacto:** um autor pode receber erro ao usar YAML válido ou PASS com metadados inutilizáveis.

**Correção recomendada:** usar parsing YAML com schema tipado e data real, ou declarar uma gramática restrita e oferecer exemplo que o validador consiga aceitar. Documentar em referência curta os campos obrigatórios e a diferença entre pasta `users` e argumento/audiência `user`.

**Observação adicional:** dois artigos com o mesmo `knowledge_id` e mesma audiência também passam. A unicidade por audiência é uma melhoria proposta nesta auditoria, não uma regra explícita já comprovada nas fontes. Definir a semântica antes de tornar esse caso bloqueante.

### KNOW-03 — P2: detector confunde orientação de segurança com segredo

**Evidência reproduzida:** `scripts/Test-CoeloKnowledge.ps1:126–133` rejeitou a frase “Nunca colocar a chave service_role no cliente”, sem valor de chave. Aceitou a versão sem pontuação do mesmo CPF fictício usado no teste existente. Os valores sintéticos não foram colocados na base de conhecimento.

**Impacto:** orientação de segurança legítima pode ser bloqueada, enquanto uma forma de identificador passa sem aviso. O scanner não pode ser apresentado como proteção completa contra PII.

**Correção recomendada:** distinguir nome de credencial de valor real, cobrir formatos previstos e explicitar revisão manual de PII, audiência e durabilidade. Preservar minimização: não guardar conversas ou identificadores para “testar depois”.

**Melhoria de busca:** o buscador devolve artigos `draft`, `deprecated` e `validated` indistintamente, apenas como caminhos. Isso foi reproduzido; não é violação automática porque a skill manda abrir fontes. Retornar status/audiência/fonte, com filtro explícito, reduziria uso acidental de orientação antiga. O parâmetro válido é `-Audience user`, não `users`.

## Governança e validação transversal

Quatro entradas — Tutor, Backend, Front-end e Knowledge — não possuem fonte/status/data no frontmatter. São válidas para descoberta do Codex, porém não atendem à proveniência documental pedida pelo `AGENTS.md`. Recomenda-se usar `metadata.source`, `metadata.status` e `metadata.generated_at`, seguindo a organização já usada por UI. Isso é uma lacuna de manutenção P3, não defeito de carregamento.

| Verificação executada | Resultado e limite |
| --- | --- |
| `quick_validate.py`, Python com `-X utf8`, cinco entradas | 5/5 válidas; valida estrutura, não decisões. A primeira tentativa sem UTF-8 falhou no encoding padrão do Windows e foi corrigida no comando, sem alterar skill. |
| `agents/openai.yaml` | Cinco prompts referenciam o nome canônico; descrições curtas entre 38 e 42 caracteres. |
| Testes UI de consulta e contratos | Ambos PASS; o teste textual ainda protege `spaceHalf`. |
| `validate_catalog_index.dart` | PASS, zero diagnóstico; existência de referências `approved` não é checada. |
| Conferência adicional do índice | 79 IDs únicos, quatro referências de arquivos ausentes e um ID citado ausente. |
| Validador Knowledge na base atual | PASS; não equivale a auditoria semântica integral. |
| Suíte existente Knowledge | PASS. A parte de “cenários” apenas verifica valores de `expected` no JSON, não executa os prompts com um agente. |
| Casos sintéticos adicionais | 15 casos de validação: seis controles aceitos/rejeitados conforme esperado, oito discrepâncias de validação e uma lacuna de unicidade proposta; quatro sondagens de busca/interface. Fixtures temporárias removidas. |

Comandos reproduzíveis, a partir da raiz:

```powershell
rtk proxy python -X utf8 C:/Users/adrie/.codex/skills/.system/skill-creator/scripts/quick_validate.py .agents/skills/coelo-ui
# Repetir quick_validate para coelo-tutor, coelo-supabase,
# coelo-flutter-review e coelo-knowledge.
rtk proxy pwsh -NoProfile -File .agents/skills/coelo-ui/tests/query-index.tests.ps1
rtk proxy pwsh -NoProfile -File .agents/skills/coelo-ui/tests/surface-interaction-contracts.tests.ps1
rtk proxy pwsh -NoProfile -File .agents/skills/coelo-knowledge/scripts/Test-CoeloKnowledge.ps1
rtk proxy pwsh -NoProfile -File .agents/skills/coelo-knowledge/tests/Test-CoeloKnowledge.ps1
rtk proxy python -X utf8 docs/reviews/evidence/2026-09-08-coelo-skills-audit/check_skills.py
rtk proxy C:/src/flutter/bin/cache/dart-sdk/bin/dart.exe run apps/catalog/tool/validate_catalog_index.dart apps/catalog/assets/coelo-ui.index.jsonl .
```

Os caminhos de Python/Dart acima descrevem o ambiente verificado. Em outro computador, localizar o runtime disponível; não exigir essa instalação absoluta como regra das skills.

## Correção recomendada, preservando a ordem solicitada

1. **UI:** reconciliar mídia, recuperar referências/IDs e unificar espaçamento; preservar padrões aprovados e validar o conteúdo dos recursos usados na descoberta.
2. **Tutor:** delimitar memória por modo, integrar Git/GitHub ao currículo e resolver a manutenção das cópias.
3. **Backend:** esclarecer URLs transitórias e mover snapshots operacionais para fontes datadas; manter controles de produção.
4. **Front-end:** retirar o denominador fixo e separar os modos de trabalho; reconciliar dependências e leitura obrigatória com `AGENTS.md`.
5. **Knowledge:** corrigir fonte/schema/scanner, depois testar recuperação e limites de memória em pedidos realistas.

Para avaliar comportamento de modelo depois das correções, usar cenários novos com critérios de resultado: reutilização visual aprovada; consulta de progresso sem escrita; revisão somente leitura; URL autorizada em runtime; cálculo pelo denominador atual; `no-op` de conhecimento; conflito de fontes; pedido de produção sem pacote nominal. Comparar comportamento com/sem a mudança em contexto independente, sem dar a resposta esperada ao avaliador. Nenhuma alegação de RED/GREEN comportamental de Astra foi feita nesta auditoria.

**Entrega:** relatório, evidência reproduzível e registro de conflitos. As cinco skills, seus testes, apps, índices e rastreadores operacionais permanecem sem alterações por esta auditoria. **Gate de memória: `no-op` na projeção** — achados e propostas não viraram regras aprovadas de produto. A correção das skills continua pendente; a auditoria está concluída dentro do recorte descrito.
