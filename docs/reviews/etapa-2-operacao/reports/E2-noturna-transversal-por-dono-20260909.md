---
title: "Duas varreduras transversais, por dono — acessibilidade e captura estreita"
source: "execução própria do grupo operacoes-sistema sobre a base d784462c1"
status: "medição; nada corrigido fora do recorte operacoes-sistema"
generated_at: "2026-09-09"
group: "operacoes-sistema"
---

# Duas varreduras transversais

Material para distribuição pela coordenação. **Nenhum arquivo fora do recorte
`operacoes-sistema` foi alterado.**

## 1. Diretrizes de acessibilidade do Flutter

33 telas de desenvolvimento × 3 diretrizes nativas = 99 casos, a 1440×900, tema
claro. Resultado: **81 passam, 18 falham, 0 não medidos.**

O "0 não medidos" importa. A primeira versão do instrumento usava
`pumpAndSettle`, que nunca assenta enquanto houver `CircularProgressIndicator` em
tela — `/dev/safety` expirou depois de cinco minutos. Substituí por um número
fixo de pumps, que mede o estado visível em vez de esperar quietude. Com isso
`/dev/safety` foi de fato avaliada, e falha nas três diretrizes. Quem reaproveitar
o instrumento deve usar pumps limitados.

### Peso diferente por diretriz

`androidTapTargetGuideline` e `textContrastGuideline` são **objetivas**: tamanho
em dp e razão de contraste não dependem de interpretar a árvore de semântica.
Trate como achado.

`labeledTapTargetGuideline` marca nós que expõem apenas `longPress`, o que pode
ser um contêiner em volta do controle real. No meu recorte eu persegui esse nó e
descartei sete hipóteses, seis por teste isolado, sem identificá-lo — ele só
aparece na composição completa pelo router, nunca nos componentes. Trate como
**candidato a confirmar**, não como defeito.

### Correção importante: exceção contamina a medição

A primeira versão desta tabela estava **errada para duas telas**, e o erro é meu.

Uma exceção lançada durante o layout faz o caso de teste falhar **antes** de a
diretriz ser avaliada. Eu reportei esse resultado como reprovação de
acessibilidade. Refiz drenando a exceção antes de avaliar, e o quadro muda:

| Tela | Eu havia reportado | Resultado real |
| --- | --- | --- |
| `/dev/safety` | reprova rótulo, alvo e contraste | **não reprova nenhuma**; lança 1 exceção de layout |
| `/dev/imports` | reprova rótulo, alvo e contraste | reprova **apenas alvo**; lança 1 exceção de layout |

Em `/dev/safety` a exceção é `LayoutBuilder does not support returning intrinsic
dimensions`; em `/dev/imports` é o transbordamento já diagnosticado. Outra frente
mediu safety de forma independente e chegou ao mesmo resultado — rótulo e alvo
passam — e estava certa.

Com isso, as reprovações reais de diretriz são **13 e não 18**: sete de rótulo,
todas corrigidas por `179a54532`; cinco de alvo; uma de contraste. Safety tem
**zero**.

Isso não absolve as duas telas: lançar exceção de layout é mais grave que reprovar
uma diretriz. Só não é o mesmo problema, e chamar um de outro manda a frente dona
investigar a coisa errada.

### Por dono

| Dono provável | Tela | Diretrizes que falham |
| --- | --- | --- |
| operacoes-sistema | `/dev/imports` | alvo (rótulo e contraste eram contaminação) |
| operacoes-sistema | `/dev/audit` | rótulo |
| operacoes-sistema | `/dev/plans` | rótulo |
| operacoes-sistema | `/dev/meal-plans` | rótulo |
| operacoes-sistema | `/dev/support` | rótulo |
| acessos-pessoas | `/dev/safety` | nenhuma; lança exceção de layout |
| acessos-pessoas | `/dev/invites` | rótulo |
| formularios-cuidado | `/dev/forms` | rótulo, alvo |
| estrutura | `/dev/activities` | rótulo |
| estrutura | `/dev/institutions` | alvo |
| chat-comunicacoes | `/dev/notices` | alvo |
| publicacoes-midia | `/dev/circulars` | alvo |
| publicacoes-midia | `/dev/principal-for-you` | contraste |

Nenhuma tela falha nas três. A afirmação anterior — de que `/dev/imports` e
`/dev/safety` falhavam nas três, e de que Segurança infantil acumulava o pior
conjunto de acessibilidade do app — era consequência da contaminação e está
retirada.

O que permanece sobre essas duas: ambas lançam exceção de layout, e isso é mais
grave que reprovar diretriz. `/dev/safety` lança
`LayoutBuilder does not support returning intrinsic dimensions`, e outra frente
contou cerca de 20 exceções em cascata na mesma tela.

## 2. Repositórios que não fecham falha de transporte

Mesma classe que eu corrigi em Agenda, Planos e na mídia de Cardápios: capturar
apenas `PostgrestException` e `FormatException` deixa um `ClientException` de
transporte escapar do repositório e chegar à UI como exceção não tratada.

A lista abaixo é **precisa**, não a aproximação que eu havia passado antes: são os
arquivos que não têm nenhuma captura ampla (`on Exception`, `on Object`, `catch`)
**e** não mencionam `ClientException` em lugar algum.

| Dono provável | Arquivo |
| --- | --- |
| estrutura | `activities/data/supabase_activity_directory_repository.dart` |
| alunos-rotina | `attendance/data/supabase_attendance_repository.dart` |
| formularios-cuidado | `forms/data/forms_backend_gateway.dart` |
| publicacoes-midia | `principal_happens_publication/data/supabase_happens_publication_repository.dart` |
| publicacoes-midia | `principal_now_publication/data/supabase_now_publication_repository.dart` |
| publicacoes-midia | `principal_shared/data/supabase_principal_runtime_context_repository.dart` |
| perfil-para-voce | `profile_about/data/supabase_profile_about_repository.dart` |
| acessos-pessoas | `safety/data/supabase_child_safety_repository.dart` |

Oito arquivos, não os cerca de vinte que eu havia estimado: a estimativa anterior
contava apenas "sem captura ampla", e vários deles já tratam `ClientException`
explicitamente. A correção típica é uma cláusula, seguindo o idioma que o próprio
arquivo já usa para as outras falhas.

`forms_backend_gateway.dart` merece atenção primeiro: gateway é ponto único de
passagem, então uma cláusula ali cobre todas as chamadas de Formulários.

## O que esta medição não é

Não é revisão das telas nem dos repositórios listados. Não abri a composição de
nenhum deles nem confirmei se a falha de diretriz vem de código próprio ou
compartilhado. É uma triagem para priorizar, feita com instrumento que só existia
no recorte `operacoes-sistema` e que agora fica documentado para reuso.
