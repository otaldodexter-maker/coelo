---
title: Publicação de Momentos responsiva
source: "referência visual aprovada pelo owner em 2026-08-20; docs/product/prd-app.md; docs/design/design-system.md; decisions/0022-superadmin-activities-and-identity-storage.md"
status: approved
generated_at: 2026-08-20
---

# Publicação de Momentos responsiva

## Objetivo

Definir o composer de `Momentos` como uma superfície privada, clara e produtiva
para preparar vídeos verticais, escolher contexto e público, salvar rascunho e
publicar. Esta superfície não é a timeline nem o visualizador de Momentos.

## Composição aprovada

- base `surface`, identidade Coelo e uma única ação primária laranja;
- mídia principal em retrato, indicador de posição, faixa de miniaturas e ação
  `Editar capa`;
- legenda de até 2.200 caracteres, público/contexto, agendamento e opções;
- `Salvar rascunho` como ação secundária e `Publicar agora` como CTA;
- prévia sincronizada somente em largura desktop, sem duplicar um painel
  espremido em mobile ou tablet.

Em 375 px, o editor segue uma coluna vertical. Em 768 px, mídia e dados editoriais
formam duas colunas e agendamento/opções ficam abaixo. Em 1440 px, o editor ocupa
o centro e a prévia fica à direita. As decisões usam largura disponível por
constraints, não tipo de dispositivo.

## Comportamento e estados

Legenda, audiência e opção de rascunho atualizam o draft local e a prévia. A
publicação exige pelo menos uma mídia e um público. Salvar e publicar expõem
estados de andamento, sucesso, conflito, falha e falta de autorização sem mostrar
exceções técnicas. Nesta referência, `Agendamento` permanece no estado fechado
`Publicar agora`; nenhum seletor de data local é autorizado.

Adicionar mídia e editar capa são portas injetáveis da apresentação. O preview
executável usa dados locais, mas não contém callbacks sem efeito.

## Fronteiras

`Momentos`, `Acontece` e `Agora` permanecem módulos independentes. A tela depende
de um contrato de repositório próprio de Momentos e não importa domínio de
Acontece. A implementação de preview usa memória; uma integração futura troca o
repositório sem alterar a composição.

Mídia operacional de Momentos permanece destinada ao Cloudflare R2 privado,
conforme ADR 0022. O Flutter nunca recebe segredo ou `service_role`; autorização,
tenant, ownership, limites, auditoria e URLs temporárias pertencem ao caminho
server-side.

## Integração com o consumo de Momentos

O consumo expõe `onCreateMoment` e direciona para a rota de desenvolvimento
nomeada `devPrincipalMomentsPublishName`. Ao concluir, o composer informa a
publicação por `onPublished` e solicita retorno por `onClose`; a integração
produtiva deverá então recarregar o conteúdo pelo repositório, sem compartilhar
estado mutável entre os dois módulos.

Esta entrega não cria rota produtiva nem injeta gateway remoto. Enquanto não
existirem migration/RLS de metadados e gateway server-side validado para o R2,
somente a rota `/dev` pode usar `InMemoryMomentsPublicationRepository`. O
preview não deve ser anunciado como publicação remota ou fim a fim.

## Acessibilidade e evidência

Controles possuem alvo mínimo de 48 px, foco visível, semântica em português,
ordem de teclado coerente e equivalência entre mouse, teclado e toque. A tela
deve ser validada em 375, 768, 1024 e 1440 px, light/dark, texto a 200% e reduced
motion. Goldens de 375/768/1440 light e 1440 dark preservam a referência visual.

## Fora de escopo

- upload remoto, transcodificação, reprodução ou publicação de produção;
- date-time picker e agendamento futuro;
- comentários, timeline ou visualizador de Momentos;
- promoção de novos componentes públicos ou bootstrap de `apps/principal`.
