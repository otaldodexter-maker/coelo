---
title: "D02 — manifesto vigente do backend de Locais"
source: "assignment D00 r13/r17; location-catalog-v2-static-profile.md; snapshots Git históricos"
status: "candidate-local-static-green; sql-not-executed; remote-not-applied"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Pacote vigente

A fonte operacional é
[`location-catalog-v2-static-profile.md`](location-catalog-v2-static-profile.md).
Ela registra a lista mínima, os hashes, a ordem nominal, as fixtures locais e os
resultados estáticos atuais. Este manifesto não prescreve `git am`, staging
amplo, `FoundationOnly`, placeholders de hash ou aplicação remota.

A proveniência histórica permanece:

- LOC01: migration e cutover em `9e689374`; os três TAP funcionais finais em
  `7389ae63`, com blobs idênticos em `31d0abf6` e `6cd030f4`;
- LOC02: migration `27236a5a`, TAP final `ae7e8f5f`;
- LOC03: migration `ae7e8f5f`, TAP originado em `15516da9` e corrigido por
  `6aa9c388`;
- LOC04: migration `15516da9`, TAP corrigido por `6aa9c388`.

Os patches `0001-*`, `catalog01-snapshot/` e
`Get-NormalizedReplayHash.ps1` são material histórico/auxiliar e não fazem
parte do pacote mínimo apto.

# Limites

O catálogo foi apenas materializado e validado estaticamente. Nenhuma migration
ou suíte pgTAP foi executada, nenhuma alteração remota ocorreu e nenhum
`action_id` foi promovido. Os wrappers compartilhados permanecem sob o escritor
central; o perfil não autoriza execução manual.
