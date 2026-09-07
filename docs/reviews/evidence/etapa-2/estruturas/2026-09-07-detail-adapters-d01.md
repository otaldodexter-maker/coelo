---
title: "D01 — adapters de detalhe/reload de Unidades e Grupos"
source: "specs 043/045; migrations 20260828002000 e 20260828003500; autorização local E2E2-D01 do Coordenador"
status: "local-green; sem composição/UI/produção neste pacote"
generated_at: "2026-09-07"
---

# Plano visível por tela

| Tela | Marco | Ação | Camada/BD | Resultado | Próximo gate |
| --- | --- | --- | --- | --- | --- |
| Unidades | 3/6 cliente | detalhe/reload | adapter `superadmin_unit_detail_v2`, HTTP mock | 37 testes | UI/composição |
| Grupos | 3/6 cliente | detalhe/reload | adapter `superadmin_group_detail_v2`, HTTP mock | 36 testes | UI/composição |

Nenhum BD foi acessado ou alterado. Schema/migrations apenas lidos como fonte.
Os seis marcos por tela continuam: contrato, backend/segurança, cliente,
integração real, regressão/visual, review/evidências/commit. Este pacote entrega
somente contratos/adapters testados do marco 3, não conclui os seis marcos.

## Contrato

Cada domínio recebe DTO de detalhe independente do model de edição e um
repository `fetchById(String)`. A única chamada é a RPC nominal com seu ID;
sem listagem, lookup prévio, escrita, tabela direta, cache ou fallback legado.
Cada reload faz nova chamada. Sete códigos internos de Auth/escopo/MFA são
negados sem usar `data` eventualmente presente no envelope. ID inválido não
chega ao transporte; ID diferente na resposta e shape/tipos não aprovados são
indisponibilidade segura.

Unit preserva plano efetivo anulável, UUID/code/name/inherited server-side,
address/contact anuláveis e tipo institucional nulo conforme CASE/LEFT JOIN
da migration física. Não conhece FK `institution_type_id` ou `unit_type_id`,
não converte plano em enum e não fabrica branding/agregados. Grupos preserva
tipo textual, complemento, flags físicos e versão, sem materializar membros,
acesso efetivo ou atividades.

## Verificação

- RED inicial de cada domínio: arquivos/classes ausentes, conforme criação TDD.
- Primeiro GREEN Grupos: 28 testes; expansão de negativos elevou a 36.
- Primeiro GREEN Unidade: 23 testes; expansão elevou a 37.
- GREEN combinado final: 73 testes; analyzer dos seis arquivos sem problemas.
- Review independente por domínio: sem achados bloqueantes. Testes adicionais
  sugeridos de envelope, transporte, tipo institucional nulo e status foram
  incorporados. Review de Unidade executou seus 23 testes iniciais.

```text
rtk flutter test --no-pub test/features/units/data/supabase_unit_detail_repository_test.dart test/features/groups/data/supabase_group_detail_repository_test.dart
```

## Handoff e limites

Solicitada reserva nominal para composição/router ao Coordenador; nenhum
arquivo compartilhado alterado neste pacote. D01 cliente é autorização local
separada das specs originais de backend. Sem lease, deploy ou cutover remoto.
IDs históricos `units.reload` e detalhe de unidade/turma devem ser reconciliados
pelo Coordenador antes de contagem; não criar aliases ou denominador novo por
causa dos nomes de classe.

Delta aos trackers: contratos/adapters locais disponíveis, negativos locais
provados; UI/composição, autorização remota, persistência/reload real e E2E
seguem abertos. Nenhuma promoção para verified/done/verified-e2e.

Gate de conhecimento: contrato técnico D01 registrado neste plano/evidência;
nenhuma nova regra de produto nem projeção duplicada de atividade.
