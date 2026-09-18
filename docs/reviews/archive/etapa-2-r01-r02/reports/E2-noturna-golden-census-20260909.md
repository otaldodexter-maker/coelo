---
title: "Censo de goldens da base — Etapa 2, rodada noturna 09/09"
source: "execução própria do grupo operacoes-sistema sobre a base d784462c1"
status: "medição; não altera rastreadores"
generated_at: "2026-09-09"
group: "operacoes-sistema"
branch: "work/etapa2-noturna-operacoes-sistema"
---

# Censo de goldens da base

## O que foi medido

As 49 suítes `*_golden_test.dart` de `apps/superadmin` foram executadas em uma
única passada, na worktree do grupo, sobre a base `d784462c1`. Nenhuma imagem de
referência foi regravada.

**Resultado: 226 aprovados, 6 ignorados, 151 falhos.**

Os 6 ignorados são os dois goldens 409 de páginas de erro, que nunca tiveram
baseline, mais quatro já marcados no repositório.

## Por que isto importa para o fechamento

Falha de golden na base **não é regressão da frente que a encontrar**. Sem esta
medição, cada grupo que rodar sua suíte vai reportar vermelho e não terá como
distinguir defeito próprio de obsolescência acumulada. A lista abaixo permite
essa separação por feature.

Também não é um problema de tema escuro apenas. Há três padrões distintos:

- **Referência ausente:** os arquivos nunca existiram. É o caso de
  `errors.409`, onde `error_409_light.png` e `error_409_dark.png` não estão no
  diretório de goldens.
- **Referência obsoleta:** a implementação avançou e as imagens não foram
  refrescadas. Confirmado em Suporte, cujas referências foram atualizadas pela
  última vez em `ed23ec20f` e receberam quatro commits de implementação depois,
  e em Minha conta, com `c6623f7e2` seguido de 18 commits.
- **Deriva de tema escuro:** as imagens existem e divergem nas variantes dark e
  text_200_dark. Padrão reportado pela coordenação em `principal_profile` e
  `principal_happens`.

Suporte e Minha conta falham igualmente em light, o que os separa do terceiro
padrão.

## Falhas por feature

| Feature | Testes de golden falhos |
| --- | ---: |
| agenda | 20 |
| principal_moments | 11 |
| principal_profile | 10 |
| principal_happens | 10 |
| chat | 9 |
| activities | 9 |
| institutions | 8 |
| groups | 8 |
| forms | 8 |
| account | 8 |
| meal_plans | 6 |
| daily_routine | 6 |
| invites | 5 |
| platform_users | 4 |
| health_care | 4 |
| notices | 3 |
| locations | 3 |
| imports | 3 |
| access_profiles | 3 |
| units | 2 |
| people | 2 |
| circulars | 2 |
| audit | 2 |
| support | 1 |
| plans | 1 |
| help_center | 1 |
| attendance | 1 |

Total: 151 casos falhos em 27 features. Uma linha pode conter muitos goldens: a
única falha de `support` é um teste que compara 24 imagens.

## Limites desta medição

Mede o estado da base, não a correção visual de nenhuma tela. Não classifica,
por si, se uma diferença é obsolescência aceitável ou regressão real: isso exige
abrir a referência aprovada de cada tela. Não autoriza regravar nenhuma imagem —
rebaseline continua exigindo aprovação nominal.

A execução foi feita depois de destrackear os artefatos de `failures/`, então
não sujou a worktree. Antes disso, rodar qualquer suíte de golden de Suporte,
Auth ou Central de ajuda deixava até 48 arquivos modificados no `git status`.
