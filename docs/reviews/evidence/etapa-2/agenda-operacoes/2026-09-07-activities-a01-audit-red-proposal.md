---
title: A01 — extensão de prova da auditoria de leitura
source: Revisão central de 2fd8227; spec 039 contrato de wrapper; fixture e927
status: Fixture local para RED nominal; não executada; migration v1 congelada
generated: 2026-09-07
---

A revisão central identificou que a corretiva v1 retorna dados sem audit de sucesso.
O helper success_envelope somente constrói JSON. A revisão estática favorável
anterior não era suficiente para esse requisito; não há GREEN SQL ou E2E.

A fixture preserva os 89 asserts originais e acrescenta oito, total esperado 97:
papel SQL authenticated na leitura e na falha; evento success correlacionado por
RPC com identidade/link/membership/escopo reais; payload de audit minimizado; e
falha real no INSERT de audit impedindo retorno de dados dos dois wrappers.

Um trigger temporário de teste rejeita apenas success activities.read das ações
nominais directory/filter_options. As chamadas continuam sob authenticated;
exceções são capturadas na fixture e TAP emitido somente após RESET ROLE. O
trigger é removido e toda a fixture termina em rollback. Nenhum helper de
produção, grant de pgTAP ou resposta da RPC é substituído para fabricar sucesso.

SHA-256 dos bytes locais da fixture:
`fc492972051e741e37d0dd7b1d7056eec24a57c4b02e98bb6ffccb9a4ca3b3b1`.
Migration v1 inalterada, commit 2fd8227d83a0c286b73ca8a0985d6f542280af3b,
SHA `6770c9bcbf5a3c3f6560021c0ca6e03d7bb1f12449878a2e98df64105cc04f92`.

Solicitação: operador Eng1 executar nominalmente base54 + corretiva v1 e fixture97
após grant serial central. Espera-se verificar os 89 contratos funcionais e RED
novo de auditoria. Só depois será alterada a migration ainda não publicada para
append fora do catch, usando o helper interno existente sem mudar shared.

Revisão independente fechou sintaxe/ACL/captura e exigiu contagens exatas para
evitar falso-verde com JSON vazio: row_count 2 no diretório e 8 opções (1+2+5).
Não basta presença de chave ou blacklist de palavras.

As skills de revisão/TDD mantêm a separação entre expectativa estática e resultado
executado. Gate de memória sem projeção: nenhuma regra de produto nova.
