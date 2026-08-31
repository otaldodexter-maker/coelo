---
title: "Publicação do Agora no MVP"
knowledge_id: "now-publication-mvp"
source: "specs/036-principal-now-publication-mvp.md"
status: "validated"
generated_at: "2026-08-20"
updated_at: "2026-08-31"
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

No MVP, mídia e áudio usam temporariamente o bucket privado `coelo-now-mvp` do Supabase conforme ADR 0026. O upload transitório é limitado a 25 MB e ocorre diretamente por URL assinada após intenção server-side; a Edge Function relê e valida o objeto antes de finalizar os metadados. O cliente não escolhe paths, não recebe segredo e não concede autorização. Metadados, contexto, versão, auditoria, idempotência e expiração de 24 horas ficam no Postgres, atrás de um repositório independente do provedor; unidade e grupo são sempre revalidados contra a instituição.

Na composição Flutter, contexto produtivo é obrigatório e fixtures só entram por
`.demo` explícito. O rascunho preserva e reaplica escala, deslocamentos de crop e
posição de capa no round-trip local; mudar a escala não zera os deslocamentos.
Esse feedback visual não equivale a extração ou processamento remoto de frame.

Na superfície local, `failure`, `unauthorized` e `conflict` são distintos e o
retry preserva a operação original. Vídeo resolvido possui representação própria
e não equivale a `Mídia indisponível`; fonte quebrada continua fail-closed, sem
substituição por fixture demo.

O preview de mídia do rascunho pertence ao autor e usa capability de criação com URL de 60 segundos. O consumo público é um contrato separado: `now.publications.read`, feed filtrado por tenant, instituição, unidade, grupo, papel, audiência, vínculo ativo e expiração; cada mídia retorna um ticket opaco, individual e descartável que a Edge Function troca por URL de 60 segundos após revalidar a pessoa autenticada.
