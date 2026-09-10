---
fonte: coordenacao.json r11, GOLDEN-REBASELINE-CRITERIO; censo E2-noturna-golden-census-20260909.md; histórico Git integrado
status: nominal-local-green; publicação pelo pai pendente
data_geracao: 2026-09-09
---

## Recorte nominal

apps/superadmin -> Perfis e permissões -> Perfis -> aba Admin inativa/hover. Somente o teste `matches inactive domain tab hover at 1440 light` de `test/features/access_profiles/presentation/access_profile_golden_test.dart`. Não foram repetidos formulário, cards/table nem ações HTTP/SQL. Base de início: f4ac658fb, worktree noturna acessos-pessoas.

Única referência alterada: `apps/superadmin/test/features/access_profiles/presentation/goldens/access_profile_domain_tab_hover_light_1440.png`.

## Critério aplicado antes da substituição

Coordenação, decisão GOLDEN-REBASELINE-CRITERIO (2026-09-09 19:20 BRT): "a causa e rastreavel a um commit aprovado especifico OU a uma mudanca intencional e testada do proprio lote"; "cada render foi inspecionado antes de regenerar"; "os arquivos ficam listados por caminho no registro".

Baseline original criada em 9ee3a7472. O par before.png/after.png foi aberto e inspecionado integralmente antes de copiar o render nominal para a referência. O histórico e blame identificam estas mudanças posteriores, todas ancestrais da base integrada entregue; não se está propondo novo desenho ou ampliando contrato:

| Diferença visível | Causa integrada |
| --- | --- |
| Seletor Perfis/Modelos e Arquivos, toolbar reorganizada; aba de domínio deslocada 64px | 320a6f09f, unify access profiles and models |
| Card Criar ausente quando o teste não fornece callback, cards apenas informativos | 633a88ba5, isolate access profile directory state; remove callbacks vazios e condiciona criação a callback real |
| Busca na navegação, espaçamento e seleção hierárquica do menu | 7f918d72a, restructure navigation menu; blame das cores e estados nas linhas 671–688 |
| Bug report ausente quando não existe callback de envio | ad558c6f9, bind open bug reports to their header context; guard em superadmin_shell.dart |
| Status com área interativa48px e consequente ajuste de medida dos cards | a0be1abeb, preserve accessible expanded status labels and targets; 6c2d03450, measure access cards without intrinsic layout (com testes de geometria) |

O próprio hover Admin é **pixel-idêntico** no recorte antes `(419,189)-(492,238)` e depois `(419,253)-(492,302)`: apenas translação vertical64px pela nova linha de seletor. A diferença total de275048pixels inclui as mudanças acima; não foi detectada diferença visível sem causa neste par. `comparison.json` registra hashes, comparação do hover e verificação individual de ancestralidade. O censo apenas localizou a falha; não foi usado como autorização suficiente de rebaseline.

## Prova e entrega

RED: P0/F1. Após copiar exatamente o render previamente inspecionado, comparador focal: P1/F0/B0/S0/U0, N1 único, exit0. Não somar o RED como caso adicional. Nenhum arquivo Dart, shared, router, main, adapter ou contrato alterado. Nenhuma mutação Git pelo executor.

SHA256 antes: `af8e8d4509d68c2e77430ddb1eef995562801622da08c4b67880716e358ec6ff`.

SHA256 depois: `25ff4c716477fcb6e00237ba25ccdd261535a261b4ac0835adf7b191212c7e86`.

Logs red.txt/green.txt normalizados para UTF8 sem BOM. Nenhum recurso próprio permanece ativo. Slot Flutter liberado ao pai após o comparator.

`tracker_delta_proposto: []`: nenhuma ação promovida a FE/BE/E2E. Este lote fecha apenas a referência nominal do hover; o teste separado cards/table continua fora deste recorte. Próximo passo: pai revisar/publicar este PNG e evidências, informando o delta de baseline à coordenação. Memória: nenhuma decisão nova de produto; aplicação do critério já vigente, sem projeção de conhecimento criada apenas por atividade.
