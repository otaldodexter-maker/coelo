---
title: "Publicação do Acontece no MVP"
knowledge_id: "happens-publication-mvp"
source: "docs/superpowers/specs/2026-08-20-coelo-happens-publication-design.md"
status: "validated"
generated_at: "2026-08-20"
updated_at: "2026-08-31"
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

Autorização é server-side, deny-by-default, com versão otimista e capabilities `happens.posts.create` e `happens.posts.publish`. A mídia usa temporariamente Supabase Storage privado conforme ADR 0026; bucket público é proibido e a migração ao R2 deve ocorrer antes de piloto/produção.

O feed consome uma projeção mínima autorizada por `happens.posts.read`, sem fabricar contagens ou rótulos ausentes. Mídias chegam como tickets opacos ordenados e são trocadas sob demanda por URL assinada curta; como o ticket é descartável, retry de mídia recarrega o feed para obter um novo ticket.

Carregamento não expõe campos nem ações do composer. Picker, remoção,
autosalvamento, save e publish são mutuamente exclusivos e bloqueiam ponteiro,
foco e navegação enquanto pendentes. Trocar repository ou contexto descarta
respostas, seletores e estado social locais do contexto anterior. Falhas
operacionais preservam o rascunho e permitem retry; falha de carregamento usa
uma superfície própria.
