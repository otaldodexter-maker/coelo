---
title: "Publicação do Acontece no MVP"
knowledge_id: "happens-publication-mvp"
source: "decisions/0032-mvp-private-media-r2.md"
status: "validated"
generated_at: "2026-08-20"
updated_at: "2026-09-03"
audience: "team"
surfaces: [principal, acontece, superadmin-preview, supabase, authorization]
visibility: "internal"
review_owner: "Coelo Product e Segurança"
---

# Publicação do Acontece no MVP

O composer do Acontece cria posts com até seis fotos ou vídeos, legenda, contexto institucional, audiência, rascunho, agendamento e prévia. A rota executável atual é `/dev/principal-happens/publish`, integrada ao callback opcional do botão Criar do preview.

Como todo fluxo `Publicar` do Principal, usa shell, contêiner direito, insets e
rodapé responsivo comuns. Desktop mantém Cancelar à esquerda e continuidade mais
a primária à direita; compacto apresenta a primária primeiro em largura total.
A proposta específica foi aprovada visualmente em 2026-08-31: mobile e tablet
mantêm editor linear com mídia dominante, enquanto o desktop acrescenta prévia
lateral. Shell, contêiner direito, raios, insets e gaps devem reproduzir a
geometria canônica aprovada, sem aproximações de implementação.

Autorização é server-side, deny-by-default, com versão otimista e capabilities
`happens.posts.create` e `happens.posts.publish`. Durante o MVP, o master usa o
R2 privado `coelo-media-prod` por meio do Media Gateway da ADR 0032; bucket
público é proibido. Acontece usa reprodução progressiva por URL temporária do
R2 e somente promove vídeo ao Stream quando métricas reais justificarem.

O feed consome uma projeção mínima autorizada por `happens.posts.read`, sem fabricar contagens ou rótulos ausentes. Mídias chegam como tickets opacos ordenados e são trocadas sob demanda por URL assinada curta; como o ticket é descartável, retry de mídia recarrega o feed para obter um novo ticket.

Na composição Flutter, contexto produtivo é obrigatório e fixtures só entram por
uma criação `.demo` explícita. Uma mídia já persistida pode ser exibida por bytes
locais ou URL assinada curta, sempre preservando proporção; ausência de ambas é
indisponibilidade, nunca autorização para substituir a mídia por fixture demo.

Carregamento não expõe campos nem ações do composer. Picker, remoção,
autosalvamento, save e publish são mutuamente exclusivos e bloqueiam ponteiro,
foco e navegação enquanto pendentes. Trocar repository ou contexto descarta
respostas, seletores e estado social locais do contexto anterior. Falhas
operacionais preservam o rascunho e permitem retry; falha de carregamento usa
uma superfície própria.
