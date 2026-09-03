---
title: "Publicação do Agora no MVP"
knowledge_id: "now-publication-mvp"
source: "decisions/0032-mvp-private-media-r2.md"
status: "validated"
generated_at: "2026-08-20"
updated_at: "2026-09-03"
audience: "team"
surfaces: [principal, agora, superadmin-preview, supabase, authorization]
visibility: "internal"
review_owner: "Coelo Product e Segurança"
---

# Publicação do Agora no MVP

O Agora possui composer próprio, separado de Acontece, Momentos e do viewer. Ele publica uma imagem ou vídeo vertical com texto curto, edição leve, áudio próprio, público/contexto, rascunho e agendamento. O plano-base permite vídeos de até 30 segundos; capacidades superiores são resolvidas e validadas no backend.

Como todo fluxo `Publicar` do Principal, usa shell, contêiner direito, insets e
rodapé responsivo comuns. Desktop mantém Cancelar à esquerda e continuidade mais
a primária à direita; compacto apresenta a primária primeiro em largura total.
O contrato visual específico foi aprovado em 2026-08-31: preserva literalmente
a anatomia comum de Publicar no Acontece e Publicar em Momentos, adaptando apenas
mídia temporária vertical, texto curto, ferramentas, público/contexto, aviso de
24 horas e CTA. No web, shell, contêiner direito, largura útil, raios, insets e
gaps devem reproduzir a geometria canônica sem aproximações; o preview lateral e
o rodapé permanecem contidos nessa superfície.

No MVP, o master Coelo de mídia e áudio fica no R2 privado
`coelo-media-prod`, pela arquitetura aprovada na ADR 0032. O upload passa pelo
Media Gateway server-side; o cliente não escolhe paths, não recebe segredo e
não concede autorização. Para vídeo quente, uma cópia privada pode ser
promovida ao Stream por até 24 horas; quando o Agora expira, um job idempotente
remove apenas a cópia do Stream, preservando o master no R2. Metadados,
contexto, versão, auditoria, idempotência e expiração ficam no Postgres;
unidade e grupo são sempre revalidados contra a instituição.

Na composição Flutter, contexto produtivo é obrigatório e fixtures só entram por
`.demo` explícito. O rascunho preserva e reaplica escala, deslocamentos de crop e
posição de capa no round-trip local; mudar a escala não zera os deslocamentos.
Esse feedback visual não equivale a extração ou processamento remoto de frame.

Na superfície local, `failure`, `unauthorized` e `conflict` são distintos e o
retry preserva a operação original. Vídeo resolvido possui representação própria
e não equivale a `Mídia indisponível`; fonte quebrada continua fail-closed, sem
substituição por fixture demo.

O preview de mídia do rascunho pertence ao autor e usa capability de criação com URL de 60 segundos. O consumo público é um contrato separado: `now.publications.read`, feed filtrado por tenant, instituição, unidade, grupo, papel, audiência, vínculo ativo e expiração; cada mídia retorna um ticket opaco, individual e descartável que a Edge Function troca por URL de 60 segundos após revalidar a pessoa autenticada.
