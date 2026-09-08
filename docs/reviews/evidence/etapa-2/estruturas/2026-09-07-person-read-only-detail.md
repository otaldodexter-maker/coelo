---
title: "PERS-READ01 — detalhe de Pessoa somente leitura"
source: "specs/046-superadmin-internal-person-detail-v2.md"
status: "local-verified-not-e2e"
generated_at: "2026-09-07"
---

# Resultado local

Nova consulta `/people/:personId` com dependência de um único método, sem
comandos legados. DTO estrito anterior permanece a fronteira de transporte.
Página renderiza somente campos autorizados do contrato 046; não apresenta
atividade, PII adicional, defaults auxiliares ou relações inferidas. Serviço
não recebe editor; adulto e criança recebem somente os vínculos/contextos
retornados. Voltar e Recarregar são os únicos controles do conteúdo.

Composição aditiva em Scope/main/App/router/routes. Rota após create/edit;
guard geral, lista e ações anteriores não foram alterados. Logout/recovery e
revisão de sessão invalidam conteúdo, mesmo mantendo ID/reader. Reader rejeita
ID inválido antes do transporte. Controller descarta resultados atrasados e
resposta injetada com ID diferente; captura pedido antes de notificar listeners
e revalida geração antes de consultar.

## Evidências executadas

- Testes de arquivos novos executados antes de suas implementações: falhas de
  compilação pelas APIs ainda inexistentes; depois 11 controller + 2 reader +
  17 página + 11 sessão/rotas + 2 composição GREEN.
- Widgets: adulto/criança/serviço; vínculos/contextos presentes e vazios;
  troca de reader/ID; reload/denied/unavailable; ausência de edição e campos
  legados; 375/768/1024/1440 em light/dark com texto 200% e alvos >=48px.
- Rotas: oito casos de sessão/escopo/logout/recovery com resposta A pronta ou
  pendente; dois casos preservando bloqueio de new/edit e um deep link sem
  sessão que não consulta dados.
- 242/242 PASS combinados: People sem golden histórico, mais rotas/composição
  e goldens novos de Pessoas e regressão das rotas/composição/goldens D01.
- Dois testes golden novos, doze imagens candidatas explicitamente autorizadas:
  light375/dark1440, identidade, contexto, foco, loading, denied e unavailable.
  Geração nominal e execução normal posterior PASS. Main inspecionou todas as
  doze imagens: leitura e rodapé sem corte dos últimos campos após scroll.
  Referência candidata não substitui aceitação final do Owner/coordenação.
- Analyzer de dez alvos (People, composição e novos testes): zero problemas.
- Validador de contratos visuais: exit 0, sem expansão de allowlist.
- Memória: fonte 046 e projeção atualizadas; ambos os gates PowerShell PASS.
- Regressão adicional Forms/AuthPreview/NAV: 33 PASS/3 FAIL. Controle removendo
  via patch somente as 33 linhas aditivas próprias nos cinco arquivos de
  composição reproduziu os mesmos três FAIL (dois source asserts Forms e
  reconhecimento de rotas preview de usuários internos), com dois PASS nos
  dois arquivos reproduzidos. Composição restaurada; nenhum outro domínio
  foi corrigido ou teve assert substituído. Não é suíte global verde.
- Revisão independente Mencius final: sem P1/P2. Suspeita inicial de texto de
  erro em loading foi retratada após inspeção do CoeloStatePanel: só o spinner
  é renderizado nesse estado. Separação de strings é clareza, não bug comprovado.

## Limites

As duas falhas históricas de golden People já reproduzidas no controle sem
STATUS01 continuam registradas na evidência daquele pacote; imagens históricas
não foram atualizadas. Nenhuma chamada de negócio remota, SQL, grant ou deploy.
Nenhuma autorização inferida do status/Auth/ID. Testes sintéticos locais não
provam RLS remota, auditoria ou conclusão E2E. Criação, edição, vínculos,
transferências/revogações, Alunos e Locais continuam exigindo seus pacotes
nominais. Coordenação integra e atualiza os três rastreadores.
