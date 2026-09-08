---
title: "Avisos — isolamento da prévia do formulário"
source: "Lifecycle do formulário; TDD e revisão independente E2E3"
status: "local-green; backend e E2E permanecem abertos"
generated_at: "2026-09-08"
---

# Recorte

Prévia administrativa no formulário de Avisos. Não altera publicação, regras
de audiência, backend ou conteúdo visual. Ordem: reprodução, ownership da rota,
regressão e revisão. Critério local: prévia de A não persiste após troca de
repositório, ID ou desmontagem da origem.

# Evidências

- Três REDs reproduziram a retenção do diálogo após repository-denied, notice-id
  e dispose. O formulário descartava o controller mas não a rota de preview.
- O formulário agora registra a DialogRoute exata e a remove após o frame;
  geração e controller identificam a origem. Checkbox/device são reiniciados.
- A API compartilhada preserva tema, foco fechado e reduced motion, com guards
  opcionais de contexto. Confirmação verifica a rota atual antes e depois do
  callback para não fechar uma navegação que ele acabou de abrir.
- 109 testes de Avisos sem goldens passaram antes de duas contraprovas adicionais;
  15 testes da prévia compartilhada passaram incluindo callback antigo e
  navegação aberta pela confirmação. Analyzer dos quatro arquivos sem issues;
  format, diff check e validador visual passaram.
- Revisão estática independente sem P1/P2; suas duas sugestões de cobertura
  foram incorporadas. Nenhum PNG promovido.

# Limites e memória

Testes usam dados sintéticos locais. Não provam Supabase, R2, publicação real,
RLS ou E2E. N01 depende do diagnóstico nominal conduzido pelo operador exclusivo
do Coordenador; nenhuma operação remota executada nesta fatia. Conhecimento
durável não mudou: correção do lifecycle existente, sem artigo novo de memória.

# Complemento da revisão central

O commit9abd4a74 preservava o destino aberto por onAccepted, mas deixava a
prévia abaixo dele. A revisão central apontou P2: voltar permitia confirmar
novamente. Novo RED comprovou a prévia após Back. O guard _closing agora
impede reentrância e finally remove a rota própria quando o callback navega,
ou faz pop quando ela ainda é a atual; jamais remove o destino por pop cego.
Teste retorna do destino, verifica ausência da prévia e invoca callback antigo
sem segunda confirmação. 15 testes da prévia passaram; analyzer2 sem issues.
Revisão independente retificou a aprovação anterior e aprovou o complemento.
