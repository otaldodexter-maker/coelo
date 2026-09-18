---
title: "PERS-READ01 — detalhe somente leitura"
source: "specs/046-superadmin-internal-person-detail-v2.md"
status: "approved-scope-local-validation"
generated_at: "2026-09-07"
---

# Contrato de execução

Objetivo: tornar o detalhe v2 consultável por deep link `/people/:personId`
no Superadmin sem liberar o formulário de edição nem contratos legados.
Recorte reservado pela coordenação: interface de leitura, adaptador restrito,
controller/página novos, composição aditiva e rota nominal. Estimativa local
60–100 minutos. Parada desta fatia: testes, revisão, evidência e handoff; não
equivale a concluir E2E 2.

## Dados e UX

Reutilizar `PersonDirectoryItem` estritamente decodificado por
`decodePersonDetailV2`; não usar seus campos auxiliares com defaults como dados
remotos. Mostrar somente nome de exibição, primeiro/sobrenome/nome legal
quando presentes, tipo, status cadastral, vínculo Auth e os vínculos/contextos
autorizados retornados. Não mostrar CPF, contato, resumo platform, contadores,
avatar ou inferir relações ausentes. IDs técnicos não precisam aparecer.

Adultos: cards de vínculos institucionais com instituição, unidade, grupo,
papel conforme payload (atividade não faz parte da spec 046). Crianças: cards de contextos com
instituição/unidade/grupo. Serviço: dados de identidade somente leitura.
Coleções vazias recebem mensagem explícita de ausência; isso não afirma
ausência global de vínculos fora do payload autorizado.

Usar a composição visual existente de UnitDetailPage: SuperadminShell,
cards com campos legíveis, ListView, tokens e footer medido com Voltar e
Recarregar. Não criar editor, novo componente compartilhado ou novo padrão.
Estados: loading (sem conteúdo anterior), ready, denied não enumerante e
unavailable. Recarregar desabilitado durante loading. Sem ações de escrita,
import/export, suspensão, transferência ou revogação nesta página.

## Fronteira e ciclo de vida

`PersonDetailReader` expõe somente `fetchDetail(String)`. Adaptador encapsula
`SupabasePersonDirectoryRepository` e delega apenas o método v2 já estrito.
Default indisponível sem fake. A interface não expõe create/update/list/options.
Não chamar RPCs remotamente nesta fatia: auditoria remota exige janela nominal.

Controller captura ID e reader antes de notificar listeners; usa geração para
descartar sucesso/erro atrasado, limpa dados antes de recarregar, invalida no
dispose e não consulta após dispose. ID inválido não dispara RPC. Resposta
com ID diferente nunca é mostrada, mesmo se reader injetado descumprir contrato.
Página substitui pedido quando ID/reader muda e descarta retorno antigo.

Rota protegida pelo guard existente e por builder reativo à sessão: antes de
compor a página verifica autenticação/recovery; chave inclui revisão de sessão
como D01 corrigido. Logout, mudança de sessão e recovery removem dados antigos.
Backend continua autoridade para identidade interna, capability, escopo e IDOR;
cliente não concede acesso por ID, status ou vínculo.

Composição: campo aditivo `personDetailReader` em Scope/main/App/router; rota
nominal em routes. Preservar FREAD, D01, Auth R07 e todas as outras dependências.
Lista, create, edit e guard geral não mudam; não usar botão Editar para consulta.

## Aceite e provas

TDD de reader (somente RPC v2), controller (ready/denied/unavailable, ID inválido,
troca A→B, erros tardios, dispose e reentrância), widgets (adulto/criança/serviço,
ausências, retry, temas, 375/1440 e texto 200%, nenhuma escrita) e rota/composição
(deep link, logout/recovery/revisão). Analyzer e gate visual. Revisão independente
antes de commit; projeção da memória somente do comportamento aprovado.
Não atualizar goldens históricos falhos, abrir permissões, executar SQL ou
afirmar persistência/deploy/E2E com evidência apenas local.
