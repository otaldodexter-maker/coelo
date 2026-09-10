---
title: "O relatório de sincronização do Catálogo é a linha de base, não só a saída"
knowledge_id: "catalog-sync-report-baseline"
source: "docs/reviews/etapa-2-operacao/reports/E2-noturna-catalog-sync-20260909.md"
status: "draft"
generated_at: "2026-09-09"
updated_at: "2026-09-09"
audience: "team"
surfaces: [documentation, frontend]
visibility: "internal"
review_owner: "Coelo Owner"
---

# O relatório de sincronização do Catálogo é a linha de base

`apps/catalog/tool/validate_catalog_sync.dart` recebe o caminho do relatório como
entrada **e** como saída. Ele lê o relatório anterior daquele caminho, compara
fingerprint por fingerprint e escreve o novo por cima. O arquivo versionado em
`apps/catalog/assets/catalog-sync-report.json` é, portanto, a memória da
comparação — não apenas um artefato gerado.

Rodar o validador apontando para um caminho de saída que ainda não existe faz
todo componente cair no ramo sem relatório anterior e ser gravado como estado
corrente. A saída imprime "Catálogo sincronizado: zero diagnóstico" sem ter
comparado nada. O jeito correto é copiar o relatório versionado para um
temporário e passar essa cópia, preservando o original.

Isso importa além do engano momentâneo. O aviso de catálogo desatualizado no app
deriva de `status == catalogStale || diagnostics.isNotEmpty`. Regenerar o
relatório não subnotifica o estado: **apaga o aviso**, e o catálogo aparece verde
para quem abre o app enquanto as divergências continuam no código. Pendência
zerada no painel e aviso apagado ao mesmo tempo.

Fechar uma divergência é atualizar o **exemplo** do componente cuja fonte mudou,
e só então regenerar o relatório. Atualizar o relatório sozinho não é correção.
