---
title: "PERS-STATUS01 — status cadastral Suspensa"
source: "specs/046-superadmin-internal-person-detail-v2.md"
status: "local-verified-not-e2e"
generated_at: "2026-09-07"
---

# Escopo e resultado

Representação do valor `suspended` já previsto no contrato, com rótulo
`Suspensa`, filtro existente e tokens warning dos temas claro/escuro. O decoder
v2 aceita esse estado sem convertê-lo em inativo. Tipo, Auth, vínculos e
restrição de serviço permanecem independentes. Nenhuma ação de suspender,
escrita, SQL, permissão, rota ou implantação foi adicionada.

## Verificação executada

- Quatro testes de domínio inicialmente RED, depois GREEN (enum e adulto,
  criança e serviço suspensos); cinquenta contratos DTO GREEN.
- Dois widgets GREEN: indicador semântico e filtro nos dois temas, sem ação
  `Suspender`.
- `flutter test --no-pub test/features/people --reporter expanded`: 169 PASS,
  2 FAIL nas comparações de imagens de diretório e formulários.
- Controle de baseline: removidas temporariamente via patch apenas as duas
  linhas próprias de enum/switch; `person_golden_test.dart` reproduziu os
  mesmos dois casos FAIL e um PASS (texto 200%). Linhas restauradas depois.
  Não foram atualizadas imagens de referência nem corrigido código compartilhado.
- Após restauração: todas as suítes People exceto `person_golden_test.dart`,
  168/168 PASS. A suíte visual completa não está verde.
- Analyzer `lib/features/people test/features/people`: zero problemas.
- Validador de contratos visuais: exit 0; format dos dois novos testes: sem alterações.
- Ambos os gates PowerShell da memória Coelo: PASS.
- Revisão independente somente leitura (Nash): nenhum achado P1/P2.
- `git diff --check`: exit 0.

## Memória e limites

Spec 046 e projeção de Pessoas registram a representação aprovada e distinguem
status cadastral de autorização. A projeção corrige a afirmação absoluta de
AAL2 conforme o aditivo de 01/09 da ADR 0019: política temporária do realm
interno não prova alteração física de RPC legada. Nenhum segredo ou dado real
foi adicionado; fixtures são sintéticas.

Este pacote remove a limitação de `suspended` registrada no DTO anterior.
Evidências históricas são preservadas. Não conclui Pessoas, seus comandos,
Alunos, Locais ou a vertical E2E 2. A integração e atualização dos três
rastreadores pertencem ao coordenador mediante este handoff nominal.
