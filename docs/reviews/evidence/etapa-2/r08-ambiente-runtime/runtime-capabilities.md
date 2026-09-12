---
title: "R08 G0 — inventário de capacidades do runtime"
source: "CUA da sessão, Dart MCP e perfil Chrome local"
status: "evidência local sanitizada"
generated_at: "2026-09-12T12:06:35-03:00"
---

# Capacidades disponíveis nesta sessão

## CUA / Chrome compartilhado

- Provider ativo: Chrome por extensão, perfil `Pessoa 1`, uma instância CUA e três abas já existentes; a aba QA é `829822454` em `http://127.0.0.1:3014/login`.
- Navegação e leitura: `goto`, back/forward/reload, URL/título, screenshot, árvore AX e snapshot DOM.
- Ações CUA: click por índice AX ou ponto, drag, `pressKey`, scroll, seleção, `setValue`, `typeText`, `paste` e ação secundária.
- Locators documentados: CSS, role, text, label, placeholder e test id; ações click/fill/type/`pressSequentially`/press/check e leituras de atributo/texto/visibilidade.
- Diagnóstico: `dev.logs` expõe console sanitizável. A API não expôs endpoint CDP ou PID exclusivo da aba; `tab.capabilities` não anunciou capacidade adicional.

Na superfície Flutter atual, click físico, foco e Tab funcionam, mas todos os canais de texto testados mantiveram DOM/controller em comprimento zero; locators DOM contaram dois inputs, porém falharam no actionability. Esses limites são observados, não uma generalização para outras páginas.

## Dart MCP

- DTD documentado: listar URIs, conectar/desconectar e listar apps conectados.
- Flutter Driver documentado: health, `enter_text`, input action, texto, scroll, tap, waits, offsets, árvore diagnóstica, screenshot e controle de semantics/frame/text-entry emulation.
- Runtime conectado: widget inspector, erros recentes, hot reload e hot restart.
- Dependências/análise: roots, LSP, análise, pub e leitura/pesquisa de packages.

Todas as ações sobre app/driver/inspector/runtime exigem uma conexão DTD ativa. No build release estático atual, `listDtdUris` respondeu que não existe processo debug/DTD. Na tentativa web-server houve DTD/VM Service, mas o Chrome compartilhado não tinha Dart Debug e o Flutter Driver não ficou habilitado.

## Extensões já presentes

- A integração CUA por extensão está ativa; seu identificador de instância é opaco e não equivale a um endpoint CDP.
- A busca read-only nos manifests do perfil Chrome Default não encontrou `Dart Debug` nem extensão identificada como Flutter.
- Extensões de página não relacionadas observadas nos logs/manifests: Wallet Guard `1.4.0`, Backpack `0.10.214`, Mojito `1.6.1` e MetaMask `13.47.0.0`. Nenhuma oferece o bridge Dart Debug/Flutter Driver exigido.

Não foi instalada, habilitada, desabilitada ou reconfigurada qualquer extensão. Não houve shell CDP, segundo navegador ou bypass de Auth.
