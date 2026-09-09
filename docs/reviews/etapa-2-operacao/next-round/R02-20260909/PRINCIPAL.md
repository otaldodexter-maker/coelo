---
title: "E2 R02 — composição do Principal no Superadmin"
source: "Owner nesta tarefa; coelo-ui; spec050; referências aprovadas"
status: "prepared-not-started"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Principal dentro do Superadmin

Nesta etapa, o hospedeiro é apps/superadmin. O menu/shell do Superadmin
permanece como navegação do hospedeiro, e a tela do Coelo (Principal) ocupa
o contêiner de conteúdo ao lado. Não substituir o menu administrativo pelo
menu do Principal, duplicar chrome nem transformar o feed/publicador em
cadastro administrativo. Não criar outro aplicativo nesta rodada.

A família visual Principal é preservada dentro desse contêiner: composição,
cards, mídia, tipografia, interações e publicadores seguem suas referências.
Compartilhar o hospedeiro não significa compartilhar as telas administrativas.
coelo_ui_principal não importa coelo_ui_admin; tokens/controles neutros podem
vir de coelo_ui_core.

## Única ambiguidade ainda submetida ao Owner

A spec050 e a referência visual da skill coelo-ui permitem que viewers
imersivos de Agora/Momentos ocultem temporariamente o chrome e restaurem o
contexto ao sair. O pedido atual de manter o contêiner junto ao shell pode
abranger também esses viewers. A pergunta sobre essa exceção foi enviada
nesta tarefa e ainda não há resposta registrada neste pacote.

Não interpretar silêncio como aprovação. Não alterar essa exceção nem
certificá-la como aceita pela rodada até esclarecer o alcance da instrução
atual. O desenvolvimento de feeds, publicadores, Perfil, Para Você e demais
ações independentes continua. Uma resposta posterior do Owner prevalece e
deve atualizar esta fonte e a referência canônica afetada, sem reabrir o resto.

## Referências preservadas

- [Manifesto dos 12 anexos Principal](C:/Users/adrie/Documents/Coelo/docs/reviews/evidence/etapa-2/coelo-principal-superadmin/manifest.md).
- [Mapa visual da skill](C:/Users/adrie/Documents/Coelo/.agents/skills/coelo-ui/references/principal-visual-surfaces.md).
- [Spec050](C:/Users/adrie/Documents/Coelo/specs/050-principal-ui-ux-closure.md).
- [Referências Estrutura](C:/Users/adrie/Documents/Coelo/docs/reviews/evidence/etapa-2/estruturas-superadmin/README.md).
- [Publicar Agora aprovado em 31/08](C:/Users/adrie/Documents/Coelo/docs/reviews/evidence/etapa-2/principal-visual/2026-08-31-publicar-agora-approved.png).

No manifesto, usar publicar-acontece-responsive-reference.png,
publicar-momentos-responsive-v2.png, momentos-responsive-reference.png,
perfil-institucional-responsive-reference.png e para-voce-responsive-reference.png
conforme a ação. Momentos v1 é histórico. Captura que documenta defeito,
como duplicação de shell, não aprova o defeito. As duas imagens de Estrutura
nomeadas “Publicar agora” pertencem a Atividades; não são referência do Agora.

Publicar preserva a geometria externa aprovada de PrincipalPublicationFrame,
incluindo insets/rodapé, e seu compositor, etapas e preview próprios.
Não refazer uma composição já aprovada por preferência do executor.

## Fronteiras entre as frentes Claude

| Frente | Responsabilidade | Contrato compartilhado |
| --- | --- | --- |
| L01 | Acontece, Agora, Momentos, Circulares, mídia comum necessária | Publicações e projeções para Acontece/Perfil; catálogo/gateway de mídia |
| L02 | Chat inteiro, Conversas administrativas e Comunicações/notices | ChatRepository e NoticeRepository |
| L03 | Perfil contextual e Para Você | Consome projeções L01 e conteúdo elegível de L02 |

Circulares possui domínio e telas próprios; não é sinônimo de notices.
Para Você consome comunicações elegíveis respeitando público, vigência,
prioridade e formato; não vira outro CMS. Conteúdo popup não vira card por
conveniência. Perfil contextual não é Minha conta nem perfil de acesso.

A existência de /dev/conversations?from=principal com uma página administrativa
não comprova Chat Principal pronto. Reutilizar domínio/repositório é adequado;
reutilizar a tela administrativa como composição Principal precisa atender
às fontes aprovadas, sem importar SuperadminChat* para o pacote visual Principal.

## Integração e mídia

R2 privado mantém a mídia nova do MVP conforme ADR0032; Supabase mantém
metadados, identidade, permissão e auditoria. Stream é uma cópia HOT opcional
nos limites aprovados: Agora até 24 h; Acontece/Momentos por necessidade medida;
Chat não exige Stream; PDF nunca usa Stream. Não criar infraestrutura por menu.

Use as rotas existentes como ponto de partida e preserve entrada normal:
 /principal-happens e /principal-happens/publish;
 /principal-now e /principal-now/publication;
 /principal-moments e /principal-moments/publish;
 /circulars, /circulars/new, /circulars/:circularId/read e /circulars/:circularId/edit.
Uma rota existente não é prova de acesso normal, persistência ou E2E.

