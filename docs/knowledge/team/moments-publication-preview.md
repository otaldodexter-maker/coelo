---
title: "Publicação de Momentos no preview"
knowledge_id: "moments-publication-preview"
source: "decisions/0032-mvp-private-media-r2.md"
status: "validated"
generated_at: "2026-08-20"
updated_at: "2026-09-03"
audience: "team"
surfaces: [principal, momentos, superadmin-preview, media, authorization]
visibility: "internal"
review_owner: "Coelo Product e Segurança"
---

# Publicação de Momentos no preview

O composer de Momentos é separado da timeline e do visualizador. A superfície
aprovada combina mídia vertical, miniaturas, edição de capa, legenda de até 2.200
caracteres, público/contexto, rascunho, publicação imediata e prévia sincronizada
no desktop. O preview executável usa a rota `/dev/principal-moments/publish`.

Mobile usa uma coluna; tablet preserva a coluna editorial ampla; desktop mantém
editor central e prévia à direita. A anatomia reproduz literalmente Publicar no
Acontece em cabeçalho, título `Sua publicação`, ordem das seções, largura útil,
preview e rodapé. Apenas mídia vertical, ferramentas, capa e CTA variam.
`Agendamento` permanece fechado como `Publicar agora` até existir um date-time
picker canônico aprovado.

Como todo fluxo `Publicar` do Principal, usa shell, contêiner direito, insets e
rodapé responsivo comuns. Desktop mantém Cancelar à esquerda e continuidade mais
a primária à direita; compacto apresenta a primária primeiro em largura total.
No web, shell, contêiner direito, largura útil, raios e gaps seguem literalmente
a geometria canônica já aprovada.

Momentos mantém domínio e repositório próprios, sem compartilhar ownership com
Acontece ou Agora. Durante o MVP, o master de mídia usa o R2 privado
`coelo-media-prod` via Media Gateway da ADR 0032; o preview in-memory não
concede autorização nem define integração de storage. Reprodução progressiva
do R2 é o padrão. Stream é uma camada HOT temporária para conteúdo novo ou
popular segundo limiar medido, sem retenção fixa arbitrária.
Mídia persistida no composer é renderizada por bytes ou URL remota autorizada,
com proporção preservada; assets empacotados pertencem somente às fixtures demo.
Sem uma fonte válida, a superfície informa indisponibilidade em vez de fabricar
conteúdo.

O fluxo produtivo vazio nunca injeta a mídia da fixture demo. `failure`,
`unauthorized` e `conflict` são estados distintos e o retry repete a operação
que falhou. Imagem e vídeo usam representações separadas; a ausência de player
para vídeo é honesta e não tenta decodificá-lo como imagem.

A tela de consumo abre o composer por callback e, após publicação, o host recebe
o resultado e retorna para Momentos. Em produção, o host deverá atualizar a
timeline consultando o repositório. Até existir metadata/RLS e Media Gateway R2
server-side validados, essa integração permanece exclusiva da rota `/dev` e não
representa persistência remota.
