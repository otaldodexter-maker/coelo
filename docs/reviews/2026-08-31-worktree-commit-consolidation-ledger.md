---
title: "Ledger de consolidação das worktrees — abertura de 2026-08-31"
source: "git worktree list; git cherry dev codex/supabase-backend-priority; Git HEAD c9b7114bab681ddb3f47a93c6f215570327b15f0"
status: "verified-ready-for-local-fast-forward"
generated_at: "2026-08-31"
---

# Ledger de consolidação das worktrees

## Snapshot de abertura

| Worktree | Branch | HEAD | Estado de consolidação |
| --- | --- | --- | --- |
| checkout principal | `dev` | `c9b7114bab681ddb3f47a93c6f215570327b15f0` | fonte local de partida; contém 97 commits ausentes da branch backend legada |
| `.worktrees/supabase-backend-priority` | `codex/supabase-backend-priority` | `5d4cc1336b232153539e8c62495baaa4a9835fc1` | limpa; 41/41 patches equivalentes em `dev`, sem patch exclusivo |
| `.worktrees/flutter-ui-10h` | `codex/flutter-ui-10h` | `e504b4a5` | ativa e dirty; intocável até checkpoint seguro da frente visual |
| `.worktrees/supabase-cross-app-foundation` | `codex/supabase-cross-app-foundation` | `c9b7114bab681ddb3f47a93c6f215570327b15f0` na abertura | backend atual; consolidação pendente |

## Prova da branch backend legada

Comando reproduzível:

```powershell
rtk git cherry dev codex/supabase-backend-priority
```

Resultado: 41 linhas, todas prefixadas por `-`. Pelo contrato de `git cherry`, cada patch da branch legada possui patch-equivalente no upstream `dev`; `git rev-list --count dev..codex/supabase-backend-priority` retorna 41 porque os hashes divergem, não porque os patches sejam exclusivos. A worktree e a branch ficam preservadas até este ledger ser commitado e até a verificação final.

| Commit legado | Classificação na abertura |
| --- | --- |
| `551727c941e16f0269acee5f64198980f31694be` | patch-equivalente em `dev` |
| `82eb024340c90a61fea8a8cb69418109c4860978` | patch-equivalente em `dev` |
| `033240a98422b32557da25ce08a2f33966397b5a` | patch-equivalente em `dev` |
| `bb67754fb924e5164d45647a5e76687eac91e11d` | patch-equivalente em `dev` |
| `9e9e1947f7a97f99331b37198be0be55f9c479dc` | patch-equivalente em `dev` |
| `d8822c41591e95d7cb17aaa82a3c1c508e72b8aa` | patch-equivalente em `dev` |
| `e01f8f40bb5e714914d153e721b63488cafa41f7` | patch-equivalente em `dev` |
| `19ddb34d28ddb7143c2079d832154e649f2d9a29` | patch-equivalente em `dev` |
| `c2858d951f8231635e6ecba175782d65d757d348` | patch-equivalente em `dev` |
| `6efc358583ecaacf894d9f60a3b9674a9d0f4da5` | patch-equivalente em `dev` |
| `74afee54360a40a387039d5926855c4febd446e1` | patch-equivalente em `dev` |
| `bc0895c7f24bf52ddd69a8776cf1fe566435753d` | patch-equivalente em `dev` |
| `5fd1dda77538914dd053b6003bc26fde6439ec9c` | patch-equivalente em `dev` |
| `d29714dd69ec9d197d0f6aec4c1d94f4ba10d260` | patch-equivalente em `dev` |
| `2f1611d8f1f0893be0d574c17beade3b0fcbfc7a` | patch-equivalente em `dev` |
| `6a456b9de9b147f6b76c610e1c6235dfed354054` | patch-equivalente em `dev` |
| `f6e10e3ced35952cce39c8c7906b78a4708f490f` | patch-equivalente em `dev` |
| `846c3c42ef87bb332df2ed8290dfec1d6e1dc0b7` | patch-equivalente em `dev` |
| `2b4dc315493f77c0a66a74cdc20c5fb9afc78024` | patch-equivalente em `dev` |
| `5a8ea868fa606767f68ff5a6c05b94c88506b324` | patch-equivalente em `dev` |
| `149f1e11c088e46e6f0591f87aa8fee341ff28e5` | patch-equivalente em `dev` |
| `80a6c9b767dc35e7015e09caaef2f07bbe052b16` | patch-equivalente em `dev` |
| `5d688fd629d61fc03d6ebb3c96b4c47f6c95c386` | patch-equivalente em `dev` |
| `4dd7ea58842c0109fc03d940af349a0c68afd3fd` | patch-equivalente em `dev` |
| `52d1e51cd46c150c86313c0a48d0753ea3915ab3` | patch-equivalente em `dev` |
| `8b1ddf77f610386c614b0e9885d67d00ed8934a6` | patch-equivalente em `dev` |
| `88f57c07b0963ddd98e5c9d05f8e73a9c7d609be` | patch-equivalente em `dev` |
| `cc0a3ee8a76796b49c2b9252b7ef0b3782b5d4bc` | patch-equivalente em `dev` |
| `4c67c17a9df12bd5e7412351b4d9919c3f862e9d` | patch-equivalente em `dev` |
| `48b4bc22581365f15f02ea9b7a3eb4c97f01aacc` | patch-equivalente em `dev` |
| `60eeb8b0fd2ae311c642b923460a4f88ea1862e9` | patch-equivalente em `dev` |
| `ab71dcdd6fce3d212098a538d0a5dd6b32a23493` | patch-equivalente em `dev` |
| `9878c88be2807b2c6fae6b7364d841b32e8bd025` | patch-equivalente em `dev` |
| `1176a8e92ae9db19268116f02a5a717ae3827086` | patch-equivalente em `dev` |
| `8cdeef271b334f849f356485deeb5cc0e97e5b1b` | patch-equivalente em `dev` |
| `b1327b43ad3aa57ed3d489e1d88f2fb389b171cd` | patch-equivalente em `dev` |
| `be37675b0a32fa9763bbaa280c9adaab8c6d90bc` | patch-equivalente em `dev` |
| `998175f0df7d449d7d87d3c0f00e0e09186fdf72` | patch-equivalente em `dev` |
| `cf15614897e77c59ea77060a44d9570b0c1a937f` | patch-equivalente em `dev` |
| `33cb8e2965abf81124a6361d3284d1a9b5e45265` | patch-equivalente em `dev` |
| `5d4cc1336b232153539e8c62495baaa4a9835fc1` | patch-equivalente em `dev` |

## Gates antes de remover ou integrar

1. Commitar este ledger e repetir `git cherry` sem linhas `+` para a branch legada.
2. Não tocar na worktree visual antes do checkpoint seguro e do lote dirty commitado pela própria frente.
3. Na consolidação final, recalcular `git cherry dev codex/flutter-ui-10h` e integrar apenas linhas `+` e commits finais exclusivos.
4. Avançar `dev` somente após backend e visual verdes, `git diff --check`, scans e status limpos.
5. Remover worktrees/branches apenas quando todos os commits estiverem alcançáveis ou comprovadamente patch-equivalentes em `dev`. Não fazer push.

## Evento após a prova

- O commit documental `a1cc69f6` persistiu este ledger e o inventário do Dia 1.
- `git cherry dev codex/supabase-backend-priority` foi repetido e manteve 41/41 linhas `-`.
- A worktree limpa `.worktrees/supabase-backend-priority` foi removida; a branch `codex/supabase-backend-priority` foi preservada para a auditoria final. Nenhum commit ou branch foi apagado.

## Consolidação final verificada

- Backend atual: `codex/supabase-cross-app-foundation` em `80305ce0` é ancestral
  da consolidação; portanto todos os commits estão integrados por identidade.
- Visual: as 26 linhas `+` de `git cherry dev codex/flutter-ui-10h` foram
  cherry-picked em ordem entre `888a0e62` e `995714bf`. Contra
  `codex/final-consolidation`, a branch visual retorna 77 linhas `-`, zero `+`;
  os commits anteriores e os 26 finais são patch-equivalentes.
- Backend legado: `codex/supabase-backend-priority` retorna 41 linhas `-`, zero
  `+`. Visual legado: `codex/flutter-ui-final` retorna 4 linhas `-`, zero `+`.
- Correções próprias da consolidação: `eee0e1a8` normaliza hashes do replay e
  `fde211ea` mantém flyouts de desenvolvimento alcançáveis, incluindo a prova
  de data em 200%.
- O prompt aprovado não rastreado na checkout principal tem o mesmo blob Git
  `61588a2e` da cópia rastreada na consolidação. Ele pode ser removido da
  checkout principal imediatamente antes do fast-forward sem perda.

### Matriz de alcance

| Branch de origem | Prova contra a consolidação | Classificação |
| --- | --- | --- |
| `codex/supabase-cross-app-foundation` | ancestral; `git cherry` sem saída | integrado por identidade |
| `codex/flutter-ui-10h` | 77 `-`, 0 `+`; 26 exclusivos originais integrados em ordem | patch-equivalente |
| `codex/supabase-backend-priority` | 41 `-`, 0 `+` | patch-equivalente legado |
| `codex/flutter-ui-final` | 4 `-`, 0 `+` | patch-equivalente legado |

O próximo passo é avançar `dev` por `--ff-only`, repetir as provas contra
`dev`, remover somente essas worktrees/branches temporárias e confirmar uma
única checkout `dev` limpa. Não fazer push.

## Lote visual tardio após o fast-forward

Uma última atualização documental apareceu na worktree visual durante a prova
de limpeza. Ela foi preservada como `9179a9aa`, validada pelos dois gates de
conhecimento e integrada em `dev` como `865bc5cc`. A spec canônica e a projeção
`principal-happens-feed.md` são blob-idênticas entre origem e destino; o
rastreador em `dev` é um superset append-only porque já continha o checkpoint
da regressão consolidada. A colisão de número foi reconciliada de `16.78` para
`16.79`, sem alterar o contrato aprovado.

Por isso `9179a9aa` é classificado como **substituído por conteúdo integrado e
superset**, não como commit órfão. O estado continua sem promoção: aprovação do
contrato visual do Acontece não equivale a implementação, golden aceito,
Flutter `verified` ou E2E.

## Clone residual `forms-catalog-fix-clone`

A varredura física de `.worktrees` encontrou um clone independente, não
registrado por `git worktree`. O reflog prova que ele foi clonado do checkout
principal em 2026-08-20, criou `codex/forms-catalog-registration` a partir de
`604f7880` e recebeu um único commit próprio: `cdf89d4b`.

O patch-id estável de `cdf89d4b` e do commit já presente em `dev` `2e7db439` é
o mesmo (`c4b2a320fbfcf0e8b41e468ae5374a960dfb4213`). Portanto o único commit
exclusivo do clone é patch-equivalente e já está integrado. O arquivo dirty
`apps/catalog/assets/catalog-sync-report.json` é saída gerada sobre a árvore
antiga: contém caminhos absolutos do clone e diagnósticos obsoletos; não é fonte
canônica nem alteração correta a incorporar. Sua não integração é deliberada e
não descarta código ou decisão de produto.

## Handoff visual final

A tarefa visual ainda estava concluindo o Item 25 quando as worktrees foram
removidas. O checkpoint documental foi preservado, validado e commitado em
`dev` como `efe03e3c`. O protótipo temporário do Item 27 ficou somente em
`.codex-tmp` durante o turno ativo e foi removido pela própria tarefa ao
encerrar; não havia decisão aprovada ou fonte canônica nova a integrar. O
workspace voltou a ficar limpo antes deste fechamento.
