---
source: "spec018; 20260901170731 model command receipts; user night scope; base1d291711e"
status: "local-123-pass; no-production-or-E2E-certification"
generated_at: "2026-09-09"
---

# Consistência de recibos de Modelos

`apps/superadmin -> Acessos -> Modelos -> criar/editar/duplicar ->
access-models.create/edit/duplicate`. O cliente aceitava o objeto `model` sem
compará-lo ao recibo ou ao comando. Um envelope HTTP200 podia ter outro
`model_id`, versão divergente, `replayed` textual, versão omitida/fracionária,
domínio diferente, alvo de atualização trocado ou duplicação usando a própria
identidade da origem, e ainda produzir sucesso para a tela.

O decodificador agora exige ID não vazio e igual ao modelo, versões inteiras
positivas e iguais, replay booleano e domínio solicitado. Update confere o alvo;
duplicate recusa a identidade da origem. A exceção usa o tratamento seguro já
existente, sem expor detalhes ou produzir callback de sucesso. Não altera
autorização server-side, assinatura RPC, envio do requestId ou política MFA.
O formulário já preserva requestId/fingerprint ao receber erro de contrato;
a proteção após callback de navegação é um lote próprio ainda em andamento.

Prova RED observada diretamente na sessão de ferramenta41404, antes do patch:
P0/F23, todos emitiram `AccessProfileModel` quando se esperava
`AccessProfileException`. Comando: `flutter test --no-pub
test/features/access_profiles/data/access_profile_models_write_envelope_test.dart
--name 'inconsistent|self-consistent|source identity' --reporter expanded`.
A saída dessa sessão foi apresentada pela ferramenta com truncamento; este
registro é a síntese da observação, não uma cópia integral do log.

GREEN atual: **P123/F0/B0/S0/U0**, três arquivos diretamente afetados:
write_envelope111, repository4, scope_contract8. `frontend-receipts-green.txt`
preserva a saída. Analyzer dos dois arquivos alterados: exit0, sem problemas,
sessão75565 (51,5s). Nenhuma chamada externa: MockClient e dados sintéticos.
Não somar RED ao GREEN nem repetir a suíte SQL95, cujo pacote não mudou.

Duplicação R02, Principal `child_context`, filtro CSV, efeitos allow/deny e
requestId permanecem cobertos nos testes afetados. Export/import legados no
teste de transporte não certificam nem habilitam essas ações; o pacote SQL
nominal continua revogando seus grants. Nenhuma ativação de UI/produção.

Revisão independente somente leitura: nenhum bloqueante concreto em coerência
SQL/adapter/recibo e preservação de duplicação, adiamentos e MFA. Não repetiu
testes. Próximo: commit do delta e integração coordenada; prova de persistência
e operação HTTP/UI real depende de pacote nominal autorizado. Memória no-op:
consistência do contrato existente, sem nova decisão de produto.
