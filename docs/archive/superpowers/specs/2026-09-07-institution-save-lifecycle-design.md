---
title: "Instituições — lifecycle e reidratação do salvamento"
source: "spec042; fluxo InstitutionFormPage existente; diagnóstico E2E2 em 2026-09-07"
status: "approved-local-lifecycle-only; coordinator-2026-09-07"
generated_at: "2026-09-07"
---

# Recorte de correção

Objetivo: a edição existente renderiza o snapshot que seu repository devolve,
sem perda de digitação concorrente nem conclusão antiga aplicada a outro ID.
Somente Superadmin. Não altera permissões, DTO/RPC, lista, criação, schema,
mídia, shell, guards ou regra de pessoas. Tempo local estimado: 45–75 minutos,
sem estimar produção ou a tela completa.

## Alternativas e escolha

1. **Recriar controller com snapshot salvo**, preservando etapa e recriando
   subtree dos campos: elimina estado inicial antigo e caches de localização.
   Bloqueia interação durante a request e ignora respostas de geração antiga.
   É a opção recomendada para o contrato já existente de salvar/recarregar.
2. Mutar todos os TextEditingControllers: mantém foco, mas duplica hidratação,
   exige atualizar original, assinatura e relações, aumentando risco de campos
   ou cache antigo sobreviverem. Não escolhida.
3. Navegar à lista após salvar: evita reidratação visível, mas muda o fluxo de
   edição aprovado e não atende a permanência na etapa. Não escolhida.

## Comportamento

- Capturar controller, ID, repository e geração no início de salvar.
- Recusar duplo envio enquanto `isSaving`.
- Capturar draft antes de qualquer await e suspender interação de corpo e
  navegação de etapas por ponteiro e teclado durante envio. Saída da página
  iniciada pelo usuário não dispara confirmação concorrente durante envio.
- Depois de cada await, conferir mounted, geração e identidade do controller.
  Resultado ou erro antigo é ignorado depois de troca de ID/repository/dispose.
- Sucesso de edição cria controller com o record salvo e mesma etapa;
  descarta controller anterior somente depois de desconectar a subtree.
  A UI não precisa acionar `onSaved`, preservando o comportamento atual.
- Erro do save vigente libera interação e preserva draft para retry.
- Não reidratar com payload fictício; testes usam somente records sintéticos.

## Evidências requeridas

RED/GREEN para normalização+versão+dirty, mesma etapa, bloqueio durante envio,
troca de ID durante resposta/erro, dispose e dois saves consecutivos.
Regressão da suíte do formulário e goldens existentes sem atualização automática
de baseline, analyzer e review independente. Sem remoto, máximo `local-green`.

## Pacote separado: modo de edição core v2

A validação atual exige representantes e administradores não retornados por
detail v2, inclusive em Revisão. Sua remoção global contradiz o fluxo local
aprovado. Desbloquear a UI produtiva exige contrato cliente explícito, separado
desta correção: modo coreV2 na rota produtiva de edição, somente campos042,
outros campos honestamente indisponíveis e criação/dev preservados. O
Coordenador excluiu explicitamente esse modo deste pacote; permanece pendência,
sem nova edição de router ou remoção de validações.

## Autoverificação

Sem mudança de fonte de autoridade, gravação remota ou refatoração ampla.
O retorno de repository é autoritativo para renderização, mas não prova E2E.
Revisão de ownership e aprovação de contrato cliente precedem implementação.
