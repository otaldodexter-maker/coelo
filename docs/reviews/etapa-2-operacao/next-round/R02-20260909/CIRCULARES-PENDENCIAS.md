---
title: "R02 — pendências e lacuna de medição de Circulares"
source: "specs/037-principal-circulars.md; specs/050-principal-ui-ux-closure.md; ADR0032; inventário Etapa2; inspeção focal de código em 09/09/2026"
status: "read-only-findings; no-new-product-certification"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Circulares — o que falta e quem resolve

L01 executa Circulares; L03 consome suas projeções no Perfil; D00 reconcilia
inventário e três rastreadores. As regras funcionais principais já estão
aprovadas. Não pedir ao Owner que redesenhe a feature por falta de medição.

## Lacuna do controle de entrega

O inventário associa a aba Circulares a principal.profile-view. Esse ID não
representa individualmente diretório, criação/publicação, detalhe/respostas e
edição, embora existam as rotas /circulars, /circulars/new,
/circulars/:circularId/read e /circulars/:circularId/edit.

L01 propõe a decomposição por subtela/ação/estado conforme spec037/050.
D00 atualiza inventário e matrizes juntos, com denominador anterior/novo e
motivo. Reutilizar a projeção de L03 sem duplicar contagem. Isso é trabalho
técnico de organização; não falta uma decisão de produto do Owner.

## Lacunas concretas observadas no código

- O compositor produtivo ainda não seleciona/envia anexos: onPickFiles em
  apps/superadmin/lib/features/circulars/presentation/production_circular_hosts.dart
  apenas exibe aviso de funcionalidade ainda indisponível (linhas224–229 nesta leitura).
- O leitor em
  apps/superadmin/lib/features/principal_circulars/presentation/principal_circular_reader.dart
  monta _AttachmentTile somente com índice, sem assetId/abertura autorizada;
  a representação é genérica, sem completar a leitura do arquivo.
- packages/coelo_database/supabase/functions/circular-media/index.ts ainda
  chama admin.storage e o bucket coelo-circulars-private. O caminho dos novos
  binários precisa ser reconciliado com a plataforma R2 privada da ADR0032.
  Não foi inspecionado o estado remoto implantado nesta leitura.
- A seção de mídia da spec037 e docs/knowledge/team/principal-circulars.md
  ainda descreve a exceção antiga de Supabase Storage. A decisão R2 já existe:
  atualizar fontes/projeção aplicáveis e implementação, sem consultar novamente
  o Owner sobre a escolha do provedor.

Há repositories Supabase, hosts produtivos, upload coordinator, migrations,
RLS e testes. Não declarar backend inexistente nem reconstruir tudo.
Conferir a implementação existente e completar o menor delta.

## Provas ainda necessárias para certificar

Separar os aceites já satisfeitos dos ainda abertos no fluxo autenticado:
rascunhar, publicar/agendar, reabrir, responder, revisar e encerrar.
Provar persistência/reload, versão correta das respostas, contexto/audiência,
permissões, revogação e acesso cruzado negado. Nos anexos, provar upload,
finalização e leitura privada R2 pela plataforma comum.

Há evidência local prévia em:
- docs/reviews/evidence/etapa-2/comunicacao/2026-09-08-principal-circular-context.md;
- docs/reviews/evidence/etapa-2/comunicacao/2026-09-08-profile-circular-context.md.

Esses lotes se sobrepõem e não comprovam E2E. Não somar nem repetir tudo.
O segundo documento também registra falhas de goldens do Perfil completo;
não generalizar os goldens de Circulares para toda a experiência.

## Onde o Owner pode ajudar

Não foi encontrada decisão funcional específica de Circulares em aberto nesta
leitura focal. Título/texto, anexos/perguntas, políticas de resposta, revisão,
agendamento, público e composições principais já estão definidos.

A confirmação visual foi resolvida pelo Owner em 09/09/2026: no Superadmin,
o shell/menu permanece no web e no mobile, inclusive na leitura de Circular
e nos viewers de Agora/Momentos. A imersão fica no contêiner de conteúdo;
a regra se aplica apenas ao hospedeiro Superadmin. Não manter essa pergunta
como bloqueio, nem pedir nova confirmação. Fontes037/050 e PRINCIPAL.md atualizadas.

Uma autorização remota ainda ausente só será solicitada após preparar o pacote
nominal concreto, respeitando autorizações existentes. Isso não exige nova
definição das regras de Circulares.

Esta inspeção não executou testes, não alterou o aplicativo ou provedores e
não certificou ações. Os achados orientam a execução quando comandada.
