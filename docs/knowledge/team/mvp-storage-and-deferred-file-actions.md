---
title: "Storage e ações de arquivo no MVP"
knowledge_id: "mvp-storage-and-deferred-file-actions"
source: "decisions/0030-mvp-private-media-supabase-storage.md"
status: "validated"
generated_at: "2026-09-01"
updated_at: "2026-09-01"
audience: "team"
surfaces: [superadmin, principal-menu, supabase, storage, imports, exports, media]
visibility: "internal"
review_owner: "Coelo Product e Segurança"
---

# Storage e ações de arquivo no MVP

Toda mídia privada do MVP usa Supabase Storage privado. R2 não existe no
ambiente atual e não bloqueia a Etapa 2 nem o MVP. Bucket público, segredo no
cliente e URL permanente continuam proibidos.

Importação e exportação reais estão adiadas para depois do MVP. Nas telas
aplicáveis, os botões permanecem visíveis, acessíveis e responsivos, mas apenas
informam honestamente que a função estará disponível depois do MVP. Não existe
picker, parser, job, arquivo, download ou persistência Supabase nesse recorte.

Artefatos legados já implantados antes da decisão ficam congelados e fora do
wiring do MVP. Eles não contam como funcionalidade aprovada nem como conclusão;
qualquer reconciliação do Supabase de produção deve ser forward-only,
coordenada e não destrutiva.

No encerramento formal do MVP, o Owner deve ser consultado separadamente sobre:

1. implementar importação e/ou exportação reais;
2. avaliar evolução do Supabase Storage para Cloudflare R2.

Sem nova aprovação, nenhum dos dois temas entra automaticamente na etapa
seguinte.
