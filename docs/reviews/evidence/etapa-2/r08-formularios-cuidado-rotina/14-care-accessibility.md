---
source: "C0 diagnóstico autorizado dos skips Cuidado; teste atual; SuperadminShell _ProfileSummary"
status: "local-green; correção mínima sob posse nominal C0"
generated_at: "2026-09-12"
---

# Perfis de cuidado e Medicação: alvo do menu do usuário

`apps/superadmin -> Saúde e Cuidado -> Perfis de cuidado / Planos de medicação -> diretório -> acessibilidade compartilhada`. Não cria action_id nem altera aceites CRUD.

Base `17d4f2233`. C0 autorizou retirar os dois skips somente para medir. Execução focal em `health_care_accessibility_guidelines_test.dart --name 'directory meets tap size' --concurrency=1 --reporter expanded`:0PASS/2FAIL, exit1. Os dois casos falham no mesmo nó do menu do usuário:242×44px, exigido48×48. Evidência integral `14-care-guidelines.log`. Slot liberado depois da execução.

Não é repetição cega do diagnóstico histórico: o nó foi novamente medido na composição atual, e os dois diretórios usam SuperadminShell. `_ProfileSummary` ainda contém avatar36 e padding vertical4+4 sem altura mínima. A proposta enviada a C0 é limitar o mínimo do InkWell a48 com conteúdo centralizado, preservando os pixels do avatar/texto e validando os goldens existentes. Nenhum shell ou PNG foi editado antes da posse nominal. Os testes permanecem WIP até decidir correção ou manter bloqueio honesto.

## Correção e validação

C0 concedeu posse nominal somente de `_ProfileSummary` e slot até14:08. Adicionado ConstrainedBox(minHeight:CoeloSize.touchMin) dentro do InkWell antes do Padding. Avatar36/padding horizontal8 e vertical4 preservados; nenhum outro trecho do shell foi alterado. G4 revisou a composição e pediu conferir o flyout em relação ao gatilho ampliado.

GREEN2PASS/0FAIL dos mesmos casos (`14-care-guidelines-green.log`). Goldens de Cuidado4PASS/0FAIL (`14-care-goldens.log`) sem atualizar PNG. Menu de Perfil2PASS/0FAIL (`14-profile-menu-tests.log`): posicionamento compact375/768 e painel abaixo do gatilho. Análise shell/teste exit0 sem problemas (`14-care-analyze.log`). Todos os processos encerrados e slot liberado.

Oito casos únicos nesta fatia,0falhos finais:2reativados e6regressão; nenhum caso criado. Avanço real: alvo do shell44→48. Reconciliação: retirada de dois skips após medição, sem promover CRUD/E2E. Os demais testes de rótulo/contraste do formulário de cuidado mantêm seu recorte, sem receber certificação de tamanho por inferência. Comentários históricos conciliados.
