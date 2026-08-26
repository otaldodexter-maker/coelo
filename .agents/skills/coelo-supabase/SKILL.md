---
name: coelo-supabase
description: Use when a Coelo task involves Supabase, Postgres, Database, Auth, RLS, grants, policies, RPCs, Edge Functions, Storage, Realtime, migrations, database security, or a review, audit, correction, estimate, or status report about those areas.
---

# Coelo Supabase

## Princípio

Nenhuma revisão Supabase do Coelo começa sem inventário de pendências e contrato
de escopo. Urgência não autoriza omitir essa abertura nem ampliar a atividade.

## Leitura obrigatória

Antes de analisar, estimar ou editar:

1. Leia `AGENTS.md`.
2. Leia integralmente `docs/reviews/coelo-supabase-pendencias.md`.
3. Leia specs, ADRs e perguntas abertas da superfície.
4. Use sempre o plugin oficial `@Supabase` (`supabase@openai-curated-remote`) e
   a skill oficial `supabase`. Acione ao menos uma ferramenta apropriada do
   plugin em cada atividade: documentação atual para planejamento/revisão e,
   quando houver projeto identificado e autoridade, inventário remoto somente
   leitura. Confira changelog e documentação atual antes de implementar ou
   fazer afirmação temporalmente instável.
5. Use sempre `supabase-postgres-best-practices`. Leia somente as referências
   pertinentes ao tema depois de ler integralmente a skill principal.
6. Use sempre `rtk` para comandos de terminal que possuam wrapper compatível,
   como busca, leitura, Git, teste e lint. Se um cmdlet nativo do PowerShell não
   for suportado pelo RTK, use-o diretamente e registre a exceção sem inventar
   um wrapper.
7. Faça sempre uma leitura leve de `coelo-flutter-supabase-review` para conferir
   os limites entre backend e integração ponta a ponta. Só carregue os dois
   rastreadores Flutter e aplique o fluxo integrado quando Flutter estiver no
   escopo ou a conclusão da tela depender dele.

O plugin `@Supabase` não amplia autorização. Antes da confirmação do pacote,
use apenas ferramentas de documentação e inspeção compatíveis com o acesso
concedido. Nunca execute SQL, aplique migration, publique função, crie branch,
altere configuração ou faça deploy remoto apenas para cumprir a regra de
acionamento. Se o plugin estiver indisponível ou sem conexão, informe isso como
bloqueio de evidência remota e não declare `remote-green` nem `done`.

Se a tarefa incluir comportamento Flutter integrado ao backend, leia também
`docs/reviews/coelo-flutter-pendencias.md` e
`docs/reviews/coelo-flutter-integrado-supabase-pendencias.md`, usando a skill
`coelo-flutter-supabase-review`. Esta skill continua responsável pelo lado
Supabase; não duplica a autoridade Flutter/UI.

## Comunicação clara

Na primeira ocorrência dirigida ao usuário, traduza siglas e estados para
linguagem cotidiana. Exemplos: Auth (entrada e sessão da pessoa), RLS (segurança
por linha do banco), RPC (função do banco chamada pelo aplicativo), Edge
Function (função executada no servidor), `fail-closed` (acesso negado e recurso
indisponível por segurança), `local-green` (passou apenas localmente) e
`remote-green` (passou no backend remoto autorizado).

Explique contagens e percentuais, sem exibir apenas `54/54` ou `100%`: diga
“54 testes executados; todos os 54 passaram”. Não presuma que o usuário conhece
SQLSTATE, IDOR/BOLA, ledger, migration ou advisor; defina o termo brevemente na
primeira ocorrência relevante.

## Contrato obrigatório de abertura

Antes de qualquer alteração, decida primeiro o orçamento de tempo.

- Se o usuário ainda não informou: comece com “Quanto tempo total você quer
  investir nesta atividade? Responda em minutos, horas ou dias.” Na mesma
  resposta, apresente as pendências conhecidas e as faixas abaixo; não edite.
- Se já informou: não pergunte novamente. Faça inventário read-only, calcule o
  que cabe e recomende o nível por tema, tela e ação.
- Se o orçamento não comportar um pacote seguro, proponha reduzir o recorte; não
  comprima testes ou autorização para caber artificialmente.

| Nível | Inclui | Referência inicial por unidade simples |
| --- | --- | --- |
| `Básica` | Uma correção pequena, RED e teste local mínimo | 30–90 min |
| `Intermediária` | Básica + contrato backend, autorização e negativas aplicáveis | 2–6 h |
| `Avançada` | Intermediária + ações aplicáveis, cross-tenant e remoto autorizado | 1–2 dias |
| `Completa` | Avançada + regressão, Advisors, auditoria, cleanup e fechamento | 2–5 dias |

Na primeira resposta, exiba sempre os quatro nomes e faixas exatamente como
acima. Não renomeie, omita, funda ou antecipe o recálculo de nenhum nível. O
recálculo só acontece depois do inventário e deve preservar o nome escolhido.

Essas faixas são estimativas, não promessas. Recalcule após o inventário e
explique premissas. Recomende no mínimo `Intermediária` para correção relevante;
`Avançada` para Auth, RLS, grants, migrations com drift, dados sensíveis e
segurança; `Completa` quando a intenção for declarar o item Supabase `done`.
`Básica`, `Intermediária` e `Avançada` podem concluir o pacote contratado, mas
não fecham automaticamente toda a tela ou todo o produto.

Depois apresente ao usuário, nesta ordem:

1. tempo disponível e nível recomendado, com motivo;
2. pendências gerais conhecidas;
3. domínios, telas, subtelas e ações pendentes relevantes;
4. objetivo e modalidade do recorte;
5. incluído e fora de escopo, incluindo o que ficará pendente;
6. ordem e critério de parada;
7. evidências esperadas;
8. ETA recalculado por fatia e total.

Use uma modalidade ou combinação explícita:

| Modalidade | Significado |
| --- | --- |
| `todas as pendências` | fecha backlog geral e todas as superfícies aplicáveis |
| `todas as telas` | percorre todas as telas na ordem do rastreador |
| `macrotema` | fecha RLS, Auth, migrations, Storage ou outro tema transversal |
| `macrotema + X telas` | fecha o tema e depois a quantidade indicada de telas |
| `X telas` | fecha a quantidade indicada na ordem de dependência |
| `X ações` | fecha ações nomeadas, como criar e editar instituição |

Se o usuário já definiu o recorte, confirme-o no contrato e prossiga sem
perguntar novamente. Se não definiu, faça inspeção read-only suficiente para
listar as pendências e peça a escolha antes de modificar código ou banco.

Autorização para `review`, `revisão`, `auditoria`, `diagnóstico` ou `relatório`
é somente leitura. Corrigir código, aplicar migration, alterar o remoto, publicar
Edge Function ou usar privilégio elevado exige autorização compatível.

### Exemplo de abertura

```text
Tempo disponível: 4 horas.
Pendências conhecidas: 14 gerais; Instituições criar/editar ainda sem prova remota;
RLS e migrations remotas abertas.
Recomendação: Intermediária em Instituições/criar; não cabe fechar RLS geral e
duas telas com segurança nesse período.
Incluído: contrato backend, autorização, negativas e testes locais da ação.
Ficará pendente: remoto, regressão da tela inteira, RLS transversal e Unidades.
ETA: 2–4 horas após o inventário inicial.
Confirme este pacote antes de eu corrigir.
```

## Execução e evidência

Siga a ordem do rastreador Supabase. Para cada item:

1. reproduza o RED e identifique ator, tenant, recurso e capacidade;
2. rastreie schema, migration, grants, policies, RPC/Edge e Storage aplicáveis;
3. trate IDs, claims, filtros e payloads do cliente como não confiáveis;
4. imponha RLS deny-by-default e grants mínimos;
5. valide autorização, ownership, hierarquia, MFA/AAL e concorrência no backend;
6. prove sucesso e negativas, incluindo cross-tenant e IDOR/BOLA;
7. execute advisors e testes proporcionais ao risco no ambiente autorizado;
8. atualize o rastreador no mesmo turno com evidência, estado, bloqueio e ETA.

Nunca exponha `service_role`, segredo, PII ou dados de crianças em Git, cliente,
bundle, log, URL ou evidência.

Respeite a separação de mídia: perfil e identidade usam Supabase Storage privado;
conteúdo operacional de Agora, Acontece e Momentos usa Cloudflare R2 conforme a
ADR vigente. Uma integração não substitui a outra silenciosamente.

## Estados e conclusão

- `audited`: inventariado, ainda aberto;
- `fail-closed`: seguro, mas indisponível;
- `blocked-decision`: depende de decisão formal;
- `local-green`: somente artefatos/testes locais verdes;
- `remote-green`: backend remoto e negativas comprovados;
- `done`: todos os gates Supabase do recorte comprovados e registrados;
- `regressed`: evidência anterior deixou de valer.

Não chame `local-green`, RLS apenas habilitada, função existente, migration local
ou mock de `done`. Para tela ponta a ponta, `done` Supabase é necessário, mas não
suficiente: o rastreador integrado também deve estar verde.

## Erros comuns e sinais de parada

| Racionalização | Correção obrigatória |
| --- | --- |
| “O usuário pediu tudo; posso começar.” | Formalize `todas as pendências`, liste-as e dê ordem/ETA. |
| “O prazo é curto; listo depois.” | A lista vem antes da primeira edição. |
| “O usuário pediu algo rápido; escolho Básica.” | Pergunte o tempo concreto e explique o risco/pendência. |
| “O orçamento é menor; retiro testes.” | Reduza o recorte, nunca os gates do pacote. |
| “Posso resumir os quatro níveis.” | Exiba exatamente Básica, Intermediária, Avançada e Completa com suas faixas. |
| “Li o rastreador; não preciso mostrá-lo.” | A abertura deve ser visível ao usuário. |
| “Review inclui corrigir.” | Review é read-only sem autorização adicional. |
| “O teste local passou.” | Registre `local-green`; não declare remoto nem integração ponta a ponta. |

Pare e corrija o contrato se a primeira resposta não contiver pendências,
recorte, incluído/fora de escopo, ordem, parada, evidências e ETA.

## Checkpoint e encerramento

Todo checkpoint informa: posição na ordem, concluído com evidência, restante no
recorte, pendências fora do recorte, bloqueios, ETA atualizado e estado
local/ledger/remoto. Ao pausar, registre o primeiro gate incompleto e o próximo
passo seguro. Ao encerrar, diferencie `atividade concluída`, `item Supabase done`
e `produto ainda pendente`.
