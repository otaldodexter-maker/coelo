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

### Por dono

| Dono provável | Tela | Diretrizes que falham |
| --- | --- | --- |
| operacoes-sistema | `/dev/imports` | rótulo, alvo, contraste |
| operacoes-sistema | `/dev/audit` | rótulo |
| operacoes-sistema | `/dev/plans` | rótulo |
| operacoes-sistema | `/dev/meal-plans` | rótulo |
| operacoes-sistema | `/dev/support` | rótulo |
| acessos-pessoas | `/dev/safety` | rótulo, alvo, contraste |
| acessos-pessoas | `/dev/invites` | rótulo |
| formularios-cuidado | `/dev/forms` | rótulo, alvo |
| estrutura | `/dev/activities` | rótulo |
| estrutura | `/dev/institutions` | alvo |
| chat-comunicacoes | `/dev/notices` | alvo |
| publicacoes-midia | `/dev/circulars` | alvo |
| publicacoes-midia | `/dev/principal-for-you` | contraste |

As duas telas que falham nas três são `/dev/imports` e `/dev/safety`. Importações
está adiada pós-MVP, o que inverte a leitura usual do adiamento: ele está
protegendo o usuário de uma tela que não passaria. Segurança infantil não tem esse
atenuante.

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
