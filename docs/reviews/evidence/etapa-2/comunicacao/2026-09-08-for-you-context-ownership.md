---
title: "Para Você — ownership do seletor de contexto"
source: "TDD local sobre lifecycle e seleção; revisão independente E2E3"
status: "local-green; overflow de pouca altura separado; not E2E"
generated_at: "2026-09-08"
---

# Recorte e evidência

Seletor de contexto existente, sem alterar dados/autorização/produto.
Dois REDs375x900: callback da opção antiga fechava uma rota sobreposta;
dispose da origem sob essa rota removia o sheet sincronicamente com árvore
travada e depois consultava ancestral desmontado.

Correção: seleção via callback do owner com mounted/geração/rota atual;
snapshot do contexto selecionado e guard no builder; remoção apenas das rotas
próprias após frame; impedir segundo seletor enquanto houver um registrado.
Controle adicional: Back da rota superior não encontra sheet residual.

19 testes da página e51 da feature completa (incluindo13goldens) passaram;
dois testes focais repetidos após contraprova de retorno passaram. Analyzer2,
format e diff check; revisão read-only sem bloqueantes. PNGs preservados.

# Pendência encontrada na reprodução

800x600 com seletor aberto produz overflow47px no Column do sheet. Reproduzido
antes desta correção; separado do lifecycle e não ocultado como teste verde.
Próxima fatia: scroll dentro das constraints existentes, com geometria/teste
de seleção acessível e preservação das referências.

# Limites

Somente fixtures locais; nenhuma troca contextual server-side, autorização,
Supabase/R2 ou E2E comprovada. Memória no-op: não altera conhecimento de produto.
