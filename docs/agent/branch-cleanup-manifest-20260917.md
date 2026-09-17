---
title: "Manifesto da limpeza de branches e tags do GitHub (17/09/2026)"
source: "Owner em 17/09/2026; docs/reviews/entrega-atual.json (residualBranches); Coelo-backups/r15-fechamento/coelo-all-refs-20260917-pre-limpeza.bundle"
status: "active"
lifecycle: "current"
generated_at: "2026-09-17"
audience: "team"
---

# Manifesto da limpeza de refs

Autorização: Owner em 17/09/2026: unificar tudo em dev e apagar branches e tags do GitHub, sem perder nada.

Recuperação: bundle `C:\Users\adrie\Documents\Coelo-backups\r15-fechamento\coelo-all-refs-20260917-pre-limpeza.bundle` (667 refs) — `git fetch <bundle> refs/remotes/origin/<branch>:refs/heads/<branch> (ou refs/tags/<tag>)`; dump `production-r14-schema-20260915-r14-bloco-cd.sql` preservado ao lado.

`dev` em `35684db944221ec8e0b6d819060567779b95ae04`. Branches remotas: 97; tags: 19. Por disposição: {"merged-in-dev": 69, "superseded": 12, "patch-equivalent": 16}.

Regra: `merged-in-dev` (nenhum commit exclusivo), `patch-equivalent` (commits reaplicados em dev por cherry-pick, `successor` integrado) e `superseded` (conteúdo revisado; sucessor em dev) podem ser apagadas; nada `UNCLASSIFIED` é apagado.

| Branch | SHA | Exclusivos | Não patch-equivalent | Disposição | Sucessor |
|---|---|---:|---:|---|---|
| `origin` | `35684db94` | 0 | 0 | merged-in-dev | `` |
| `codex/e2-r02-d01-autenticacao` | `dc44df9e1` | 30 | 20 | superseded | `4b2c5611e` |
| `codex/e2-r02-d02-estrutura` | `40ec50d72` | 81 | 39 | superseded | `cb9eb15a5` |
| `codex/e2-r02-d03-acompanhamento` | `0a2ecb34e` | 46 | 29 | superseded | `9554aaa3d` |
| `codex/e2-r02-d04-acessos` | `375e0a62a` | 34 | 32 | superseded | `ecc8eae2b` |
| `codex/e2-r02-l00-coordenacao-claude` | `bdef0f559` | 50 | 50 | superseded | `0d212729b` |
| `codex/e2-r02-l01-publicacoes` | `3697dd49e` | 40 | 40 | superseded | `1e39b2fcf` |
| `codex/e2-r02-l02-chat-comunicacoes` | `45d92b9c1` | 49 | 35 | superseded | `2b1cf2f00` |
| `codex/e2-r02-l03-perfil-para-voce` | `b209b4e0f` | 0 | 0 | merged-in-dev | `` |
| `main` | `57d952574` | 0 | 0 | merged-in-dev | `` |
| `r14/acessos-instituicoes` | `b271d178b` | 4 | 1 | patch-equivalent | `74040c470` |
| `r14/agora-momentos` | `e177d8107` | 4 | 0 | patch-equivalent | `74040c470` |
| `r14/assiduidade-historico` | `fa0992d98` | 4 | 0 | patch-equivalent | `74040c470` |
| `r14/bloco-cd` | `b135c8f20` | 5 | 1 | superseded | `8334d3695` |
| `r14/bloco-e` | `31503be05` | 19 | 19 | superseded | `8334d3695` |
| `r14/formularios-chat` | `5bc59127a` | 2 | 1 | patch-equivalent | `74040c470` |
| `r14/seguranca-assiduidade` | `5572bc19b` | 3 | 0 | patch-equivalent | `74040c470` |
| `r14/visual-arquivar` | `e9233a924` | 4 | 3 | patch-equivalent | `74040c470` |
| `r15/bloco-a` | `947cf5485` | 16 | 10 | patch-equivalent | `ae2a2b14e` |
| `r15/bloco-b` | `dedcd83ee` | 9 | 4 | patch-equivalent | `ae2a2b14e` |
| `r15/bloco-b-apoio` | `e828f17e1` | 7 | 0 | patch-equivalent | `ae2a2b14e` |
| `r15/bloco-c1` | `1c199f14c` | 11 | 5 | patch-equivalent | `ae2a2b14e` |
| `r15/bloco-c2` | `5ea5984c6` | 8 | 5 | patch-equivalent | `ae2a2b14e` |
| `wip/fase0-arquivo-chat` | `91e011dc6` | 1 | 1 | superseded | `d0fd94c07` |
| `work/etapa2-noturna-acessos-pessoas` | `992f3530d` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-noturna-alunos-rotina` | `c73f7b526` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-noturna-avisos-chave-de-linha` | `cb0a386d8` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-noturna-chat-comunicacoes` | `c1e6756c7` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-noturna-chat-comunicacoes-router` | `c2127823f` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-noturna-chat-comunicacoes-router-from` | `48d15d8df` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-noturna-chat-volta-mobile` | `fb31e11dc` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-noturna-copia-previa` | `80f160599` | 1 | 1 | superseded | `03f8bc0b8` |
| `work/etapa2-noturna-estrutura` | `6709f1473` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-noturna-formularios-cuidado` | `55f4b5910` | 5 | 0 | patch-equivalent | `eecbfa146` |
| `work/etapa2-noturna-import-orfao` | `8a09d66ac` | 1 | 0 | patch-equivalent | `eecbfa146` |
| `work/etapa2-noturna-operacoes-sistema` | `dd1a95bcd` | 2 | 0 | patch-equivalent | `eecbfa146` |
| `work/etapa2-noturna-perfil-para-voce` | `1d46746ff` | 2 | 0 | patch-equivalent | `eecbfa146` |
| `work/etapa2-noturna-publicacoes-midia` | `69e377f3e` | 3 | 0 | patch-equivalent | `eecbfa146` |
| `work/etapa2-r03-acessos-pessoas` | `d47e16839` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r03-coordenacao` | `2efda8b00` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r03-estrutura` | `63be8a474` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r03-formularios-cuidado-rotina` | `fdc89c488` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r03-operacoes` | `3fa07edd0` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r03-principal-chat-sistema` | `a9faabd01` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r03-publicacoes-agenda` | `3b21db696` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r04-acessos-pessoas` | `3b499860f` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r04-estrutura` | `189cbb852` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r04-formularios-cuidado-rotina` | `508d9e842` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r04-operacoes` | `a71928c7c` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r04-principal-chat-sistema` | `4ddef877f` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r04-publicacoes-agenda` | `3895238a5` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r04-realm-interno` | `d89c236de` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r05-acessos-pessoas` | `d6ceff4be` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r05-coordenacao` | `ca60b096b` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r05-estrutura` | `48fb00f06` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r05-formularios-cuidado-rotina` | `395f4552f` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r05-operacoes` | `4c9101fe5` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r05-principal-chat-sistema` | `45d3e681d` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r05-publicacoes-agenda` | `a371fce6d` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r05-realm-interno` | `f30516f31` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r06-acessos-pessoas` | `bf98ecb73` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r06-estrutura` | `001a33e06` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r06-formularios-cuidado-rotina` | `67e04fb10` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r06-operacoes` | `7b1a83caa` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r06-principal-chat-sistema` | `2be3ed6b7` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r06-publicacoes-agenda` | `c813becfe` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r06-realm-interno` | `04da3e59b` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r07-acessos-pessoas` | `72980497b` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r07-coordenacao` | `b3b1bb34d` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r07-estrutura` | `84a84e2a1` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r07-formularios-cuidado-rotina` | `c105bff1d` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r07-operacoes` | `ff0e2338d` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r07-principal-chat-sistema` | `30ba45a80` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r07-publicacoes-agenda` | `7bdb38a09` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r07-realm-interno` | `d25d1ddcb` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r07-suites` | `d4a62918c` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r08-acessos-pessoas` | `942955410` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r08-ambiente-runtime` | `2d4f5e5b7` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r08-coordenacao` | `917d509d8` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r08-estrutura` | `558b3d357` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r08-formularios-cuidado-rotina` | `1baa84f5e` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r08-operacoes` | `4c300f550` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r08-principal-chat-sistema` | `113361425` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r08-publicacoes-agenda` | `aa3fedf71` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r08-realm-interno` | `2a7609507` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r08-suites` | `9d5a2f88a` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r09-acessos-pessoas-20260912-1542` | `722cf260d` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r09-ambiente-runtime-20260912-1542` | `ae6a7c41d` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r09-coordenacao-20260912-1534` | `d2ed31572` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r09-estrutura-20260912-1542` | `4e03d076e` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r09-formularios-cuidado-rotina-20260912-1542` | `98e49f39a` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r09-operacoes-20260912-1542` | `4164ec98b` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r09-principal-chat-sistema-20260912-1542` | `d422268b1` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r09-publicacoes-agenda-20260912-1542` | `1e18b6186` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r09-realm-interno-20260912-1542` | `646b69ec4` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r09-suites-20260912-1542` | `0986fd2a0` | 0 | 0 | merged-in-dev | `` |
| `work/etapa2-r10-chat-upload-first-delivery` | `df90f05b0` | 1 | 1 | superseded | `b5a0fe8e7` |

| Tag | SHA | Alcançável de dev |
|---|---|---|
| `archive/2026-09-09/c07-c04ro` | `479d1bd17` | sim |
| `archive/2026-09-09/claude/e2-r01-c04-estruturas` | `59867239c` | não |
| `archive/2026-09-09/claude/e2-r01-c05-comunicacao` | `42f8ef995` | não |
| `archive/2026-09-09/claude/e2-r01-c06-coordenacao` | `27dfccf05` | não |
| `archive/2026-09-09/claude/e2-r01-c07-validacao` | `cea29b1f8` | não |
| `archive/2026-09-09/claude/e2-r01-c07-validacao-visual` | `b9be43f43` | não |
| `archive/2026-09-09/codex/e1-a01-client-20260908` | `f0be734ac` | não |
| `archive/2026-09-09/codex/e1-replay-harness-20260907` | `977691240` | não |
| `archive/2026-09-09/codex/e2-r01-c00-integration` | `ed37c04db` | sim |
| `archive/2026-09-09/codex/e2-r01-c01-identidade` | `8899f3c21` | não |
| `archive/2026-09-09/codex/e2-r01-c02-forms-midia` | `99f7283a2` | não |
| `archive/2026-09-09/codex/e2-r01-c03-operacoes` | `bfdd5f0e6` | não |
| `archive/2026-09-09/codex/e2e-agenda-operacoes` | `ca4c82abc` | não |
| `archive/2026-09-09/codex/e2e-comunicacao-midia-principal` | `943a69aee` | não |
| `archive/2026-09-09/codex/e2e-estruturas-pessoas-locais` | `9e689374e` | não |
| `archive/2026-09-09/codex/e2e-formularios-cuidado` | `f84d1dd70` | não |
| `archive/2026-09-09/codex/e2e-identidade-acessos` | `58ef983ad` | não |
| `archive/2026-09-09/codex/pre-consolidation-wip-20260908` | `07e6e8373` | não |
| `archive/2026-09-09/stash-etapa2-denominadores` | `2961c1a7d` | não |
