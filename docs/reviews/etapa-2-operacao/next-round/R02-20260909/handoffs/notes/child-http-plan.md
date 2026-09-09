---
title: "R02 D03 — plano focal HTTP local do diretório CHILD"
source: "prompt D03; assignment D00; contrato CHILD-READ01; Test-LocalAuthLifecycle.ps1"
status: "pass-integrated-local-d00-r14"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Prova HTTP local do diretório CHILD

Atualização D00 r14, 15:53 BRT: quatro cenários HTTP PASS na base63e364300c062ca0b52bb79958cc465a9b16cd60, exit0 e cleanupzero. Log preservado em evidence/d03-acompanhamento/r02-20260909/child-http-first-replay.log.txt, SHA2561EAA328DECD169844E62C716EBDA54E0A23DE9A6C0745D8A281DFA465297AB3F. A prova usa startup após a migration; não certifica invalidação dinâmica do cache ou o pacote atômico novo. A preparação e os bloqueios abaixo são históricos, superados por este recibo.

O harness `packages/coelo_database/scripts/Test-ChildDirectoryHttp.ps1` prepara
uma prova PostgREST local do reader CHILD sem alterar migrations, perfil ou
realm. Na preparação, sua execução estava bloqueada até D00 aprovar e integrar o modo HTTP
restrito do runner seguro. Nenhum HTTP, Docker ou SQL deste harness foi
executado durante a preparação.

O `config.toml` canônico mantém signup local habilitado e confirmação de email
desabilitada, o mesmo pré-requisito já usado por `Test-LocalAuthLifecycle.ps1`.
Assim, o signup local deve devolver sessão e JWT diretamente. Se isso divergir
na base materializada, o harness falha; não existe fallback privilegiado.

## Escopo e segurança

O script exige `ProjectRoot`, `ProjectId` canônico, marcador
`.coelo-safe-replay`, ancestrais sem reparse point, contêiner próprio em execução
e `API_URL` absoluto HTTP no host literal `127.0.0.1`, porta explícita, path
raiz e sem userinfo, query ou fragment. Do status local ele retém somente
`API_URL` e `ANON_KEY`, sem imprimir valores. O handler desativa redirects e
proxy para impedir que headers ou corpo saiam do loopback validado e é
descartado explicitamente. HTTP tem timeout de 20 segundos;
`psql` usa `ProcessStartInfo`, o contêiner derivado do `ProjectId`, timeout de 20
segundos e não propaga stdout/stderr de falha.

O preflight recusa IDs sintéticos já existentes. A base é one-shot: fixtures e
o usuário de signup permanecem apenas até o cleanup integral do projeto pelo
runner. O harness não apaga linhas contornando guards e não aceita reexecução
in-place.

## Fixture e invariantes

A fixture cria duas instituições, três crianças em A, uma criança em B, um
Owner interno039 com escopo institucional A ligado ao usuário criado por signup
e um Owner plataforma de apoio. Nenhum vínculo do realm legado é criado.

Com o mesmo JWT real, a prova exige:

1. página inicial com limite 2, shape exato de cinco campos, UUIDs tipados e
   iguais aos contextos/pessoas esperados, instituição A exata e cursor da
   última linha retornada;
2. segunda página curta, sem cursor, seguida de reload sem cursor idêntico à
   primeira página;
3. instituição B e UUID desconhecido com a mesma negativa
   `SAI_PERMISSION_DENIED` e sem dados;
4. revogação da membership com `version = version + 1`, seguida de negativa
   `SAI_MEMBERSHIP_REVOKED` para o mesmo JWT e sem dados.

Ao final, a consulta focal de auditoria filtrada pela identidade da fixture
exige três leituras de sucesso (página 1, página 2 e reload), três negativas
(B, UUID desconhecido e membership revogada), payloads `before_json` e
`after_json` ausentes e nenhum `institution_id` nas negativas.

Esta prova alcançará o wire local Auth/PostgREST e o contrato do endpoint. Ela
não executa o widget Flutter nem certifica produção, persistência remota ou E2E
do app. A camada Dart continua coberta separadamente pelos testes do adapter e
controller.

Conhecimento: `no-op`; nenhuma regra durável nova de produto foi aprovada.

## Revisão e estrutura — 15:17 BRT

Parent corrigiu por revisão o risco de seguir redirect/proxy depois da validação
inicial de loopback. O freeze final desativa ambos, valida a URI integralmente,
confere UUIDs e valores esperados do DTO e restringe a auditoria à fixture.
Revisão independente do freeze não encontrou outro bloqueante material.

Harness SHA256 `3F81CA9AE729C57642BA9DC4057079B976850B73B5A04C227C7D5C34AB252396`;
teste estrutural SHA256
`CC0C100A97035E8E32DCD69B7F9C184B6C48A257FC8833798C5DDCF9ABD37A95`.
O subagente revisor executou `Invoke-Pester -PassThru` no arquivo
`packages/coelo_database/scripts/tests/Test-ChildDirectoryHttp.Tests.ps1` e
reportou **P8/F0/B0/S0/U0**, 2,88 segundos. A execução produziu somente saída de
console; **não há XML/log bruto preservado** dessa campanha. Nenhum XML foi
reconstruído e o teste não foi repetido apenas para criar outro artefato.

Na preparação15:17, HTTP/PostgREST ainda não havia sido executado. O plano tem quatro cenários de negócio:
página inicial/DTO/cursor; segunda página/reload; B/desconhecido sem enumeração;
revogação versionada com mesmo JWT e auditoria minimizada. Os oito casos
estruturais não são oito cenários HTTP nem aceites integrais de `students.list`.
