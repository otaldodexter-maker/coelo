---
title: "Agora — legenda sincronizada após reload de conflito"
source: "review independente; page/controller existentes; testes Flutter"
status: "local-green; not-e2e"
generated_at: "2026-09-07"
---

# Defeito e correção

O controller carregava a legenda nova, mas a página só sincronizava o campo se
a seleção de texto fosse inválida. Após digitação, o campo conservava edição
antiga e o próximo save podia enviar texto diferente daquele exibido.

A sincronização passa a ocorrer sempre que os textos diferem. Na digitação
normal são iguais, portanto seleção/IME não recebem TextEditingValue novo;
no reload explícito, a legenda efetivamente substituída recebe cursor ao fim.
Checkpoint continua usando o merge existente que preserva edição local.

- RED: após conflito/reload, esperado Legenda B, encontrado Edição local.
- GREEN página **35/35**; suite completa principal_now_publication **70/70**,
  incluindo goldens existentes, controller, domínio e metadados.
- Novo teste compara campo e payload do save seguinte: Edição local antes
  do conflito, Legenda B após recarregar. Fixture de conflito inicialmente
  usou const indevido, corrigido antes do RED comportamental.
- Analyzer dos dois arquivos sem apontamentos; formatter e validador visual
  exit 0. Review independente review_chat_receipt: sem achado acionável.

Nenhum backend, router, PNG ou segredo alterado; nenhuma nova política ou
projeção de conhecimento (memória no-op). Picker pendente após negação é outro
achado aberto, não resolvido nem ocultado por este delta. Prova remota e E2E
permanecem abertas; não confundir teste com persistência produtiva.
