---
title: "Chat — fechamento de imagem respeita a rota própria"
source: "TDD local; revisão independente E2E3"
status: "local-green; not E2E"
generated_at: "2026-09-08"
---

# Recorte

Fechar no footer e X no header do diálogo de imagem canônico. Quatro REDs
reproduziram pop da rota superior e consulta de ancestral após dispose, nos
dois controles. Correção compartilha callback com rota capturada, mounted,
contexto vigente e identidades de asset/reader/session. Não depende da geração
de leitura nem invalidação para permitir fechar conteúdo expirado/indisponível.
Não altera o shell de diálogo compartilhado, Scope, contrato ou backend.

# Verificação

70/70 focais tile+dialog; 139/139 Chat funcional e oito goldens do diálogo;
analyzer2 sem issues, format/diff check e revisão read-only sem bloqueantes.
Sem PNG alterado. A primeira tentativa do teste do X selecionava RawTooltip;
finder corrigido antes de registrar os quatro REDs válidos de produto.

# Limites

Fixture Flutter local, sem HTTP, R2, autenticação, RLS ou E2E real. Nenhum
conhecimento de produto alterado; memória no-op de lifecycle existente.
