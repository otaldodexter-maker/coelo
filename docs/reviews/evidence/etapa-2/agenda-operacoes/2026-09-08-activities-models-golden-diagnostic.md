---
title: "Atividades — diagnóstico do golden de Modelos"
source: "comparação local em f0be734a; tracker16.32; master1354b102; implementação d9232a94"
status: "divergência visual confirmada; sem rebaseline ou aceite"
generated_at: "2026-09-08"
---

# Recorte e resultado

Somente comparação do diretório de Modelos, desktop1440/light, sem alterar
Flutter, shared shell ou golden. O comando abaixo terminou exit1, um teste
falhou: **9,86%,127746pixels diferentes**. Esse resultado é separado das669
regressões PASS que excluíam arquivos golden pelo nome.

```powershell
rtk proxy flutter test --no-pub test/features/activities/presentation/activity_golden_test.dart --plain-name "matches the approved models directory on desktop"
```

Inspeção visual direta do master e imagem gerada confirmou: busca de navegação,
estilo/estado de navegação, botão Arquivos, abas de status e remoção de elementos
antigos de shell diferem. Os cards atuais estão60px abaixo por causa do bloco
de status e gap. Não foi identificado overflow nessa imagem desktop; isso não
certifica responsividade integral ou acessibilidade.

História verificada em HEAD:

- Última alteração do master nesta linha: `1354b102afe0ab0338fe0dde0b14d1e796eb7bf2`,
  2026-08-12. Não usar commits de outras linhas de `git log --all` como baseline.
- Arquivos/status de Modelos foram adicionados em
  `d9232a94d265aad6c046f442829336e4b409e02f`, 2026-09-01.
- Review independente não encontrou diff da fixture FakeActivityDirectoryRepository
  desde1354b102. As diferenças observadas não são explicadas por alteração dessa fixture.
- Tracker `coelo-flutter-pendencias.md`, seção16.32, já registra nove grupos de
  goldens divergentes e aceite visual humano pendente. Anexos de Estruturas
  preservam referência de abas Todos/Ativos/Rascunho/Inativos.

Isso é análise histórica de fontes, **não execução isolada do baseline antigo**.
Não conclui que todos os nove grupos sejam preexistentes nem autoriza atualizar
masters. Não remover controles atuais para imitar um screenshot antigo.
Header/Bug e mudanças de shell continuam com seus donos compartilhados.

## Artefatos locais

O Flutter gerou imagens em
`apps/superadmin/test/features/activities/presentation/failures/` (saída local,
não incorporada como referência aprovada). Hashes SHA256:

- `activity_directory_models_light_1440_masterImage.png`:
  `d29b2b8fa6621bcd34494d9a656fd0f875556ee72fb48df1fd1a5f215bcb9493`.
- `activity_directory_models_light_1440_testImage.png`:
  `7b3477dfbd291a887c746efe56ed97ba50a3789e30c39a9413de998d074a2867`.

Gate seguinte: consolidar a anatomia atual com as referências e o aceite
visual pertinente antes de uma atualização nominal de masters. Nenhum SQL,
HTTP, Docker ou produção foi acessado. Memória no-op: diagnóstico operacional,
sem nova regra de produto ou aprovação visual a projetar.
