---
title: "Decisões do Owner na Mesa R14 de 16/09/2026"
source: "Owner em 2026-09-16 (artefato Jrsk1XBe97MCLpeUBGAeYz, documento decisoes/r14-owner, 27/27 decididos, salvo 14:05 UTC); docs/reviews/etapa-2-operacao/next-round/R14-pendencias.md; decisions/0038-owner-decisions-etapa2-backlog-20260914.md; decisions/0039-owner-scope-commercial-plans-auth-stage3-20260915.md; decisions/0040-agora-immediate-removal.md; docs/open-questions.md (OQ-033, OQ-044, OQ-046)"
status: "accepted"
generated_at: "2026-09-16"
updated_at: "2026-09-16"
lifecycle: "current"
supersedes: "decisions/0038-owner-decisions-etapa2-backlog-20260914.md (somente H11: autosave deixa o MVP)"
audience: "team"
---

# ADR 0041 — Decisões do Owner na Mesa R14 (16/09/2026)

Em 16/09/2026 o Owner respondeu, em artefato próprio, às 27 pendências da R14
que dependiam dele: aceites com prova pronta, decisões de produto/contrato,
aprovações visuais e autorizações de produção/ambiente. Este documento é a
fonte canônica dessas decisões. Ele **não** certifica implementação: os
estados por `action_id` só mudam pelo delta de inventário com evidência, e os
itens que ganharam contrato novo continuam abertos até serem provados.

## 1. Aceites

| Ref | Decisão | Efeito |
|---|---|---|
| A1 | `owner.r12-34/35/36/37` (Cardápios) **aceitos** pela evidência publicada em `r14-sessao-2/meal-plans-20260915.md`. | Owner items → `done`. Imagem R2 de Cardápios segue em `owner.r12-38`. |
| A2 | `owner.r12-29/30` (Perfis de cuidado) **não aceitos ainda**: o Owner quer prova com mais registros e redesenhou o contrato (ver §5). | Permanecem `partial`; a coleção independente com limite 100 já aplicada em produção é preservada como base. |
| A3 | Catálogos globais de tipo (OQ-031) e leitor self da Conta (ADR 0038) **aceitos**. | Itens da ADR 0038 → concluídos. |
| A4 | `institutions.files` **fora do MVP**: o flyout Arquivos permanece na tela e, ao clicar, informa que está em desenvolvimento; nenhuma importação/exportação em Instituições (a única exportação do MVP é a de respostas de Formulários, ADR 0031). `institutions.error` e `institutions.access-denied` **ficam no MVP** e devem ser provados. | `institutions.files` → `deferred-post-mvp` no inventário. |
| A5 | Páginas de erro (`errors.403/404/409/500/503/retry`) **reclassificadas `flutter-only`**: são só tela; o aceite terminal é FE na rota real, sem prova de backend. | Escopo `flutter-only`; BE `not-applicable`. `errors.409` ainda precisa de rota real (FE `local-green`). |

## 2. Produto e contrato

| Ref | Decisão |
|---|---|
| B1 `owner.r12-02` | **Arquivar** modelos de Atividade e de Rotina = inativar reversível (OQ-033 opção B): sai da lista padrão, fica em "Arquivados", pode voltar; mesma permissão de editar o modelo. Rotinas/atividades já derivadas continuam válidas. |
| B2 `owner.r12-04` | Nova tela **Acompanhamento › Assiduidade › Histórico**: tabela de chamadas (data, turma/atividade, quem lançou, presentes/ausentes, situação), filtros por instituição/unidade/turma/período, abre o detalhe. Sem edição nessa tela. "Lançamentos" sai do diretório de Rotina. |
| B3 `owner.r12-06` | **Híbrido**: chamada aberta segue a rotina vigente da turma/atividade; ao concluir (`attendance.finish`) grava snapshot (rotina + versão) e o histórico passa a mostrar sempre esse snapshot. Reabrir para corrigir presença não altera o snapshot. Chamadas já concluídas sem snapshot mostram a rotina vigente com a indicação "rotina atual (não registrada na época)". |
| B4 `owner.r12-09` | Card de Segurança da criança **aprovado como está**; não criar campo alerta/restrição. |
| B5 `owner.r12-17` | **Busca de pessoa autorizada**: input único, resultado conforme digita, detecção automática do tipo. Nome/@/e-mail a partir de 3 caracteres; celular a partir de 4 dígitos; CPF a partir de 6 dígitos — todos com ou sem máscara (backend normaliza só dígitos). Restrito ao escopo do ator, com auditoria e limite de taxa no leitor. Resultado minimizado (nome, iniciais, @, últimos 4 do celular; **CPF nunca exibido**). Responsável no resultado lista as crianças vinculadas do escopo do ator, com clique para preencher criança + pessoa autorizada. Só crianças **com vínculo** ao responsável aparecem. O mesmo leitor antecede o cadastro de B6. |
| B6 `owner.r12-18` | **Pessoa sem conta**: CPF obrigatório (chave de deduplicação), imagem do documento no MVP (R2 privado, ADR 0032), pode virar conta no futuro. Ela **não usa o app**: fica autorizada apenas no contexto pedido pelo responsável (ex.: retirar a criança naquela unidade), visível só para esse escopo. |
| B7 `owner.r12-19/23`, OQ-044 | Perfil de funcionário no Principal / perfil transversal: **spec própria na R15**, junto do ciclo de vida (OQ-033). Não executar na R14. |
| B8 `owner.r12-33` | Medicação: **sino in-app** para administradores da unidade e educadores da turma da criança, ao criar/editar plano e a cada dose registrada. Sem e-mail/push no MVP. |
| B9 `principal.for-you/profile-edit` | "Ver como": **só trocar avatar/nome no cabeçalho**; sem faixa fixa. Desbloqueia as duas ações do Principal. |
| B10 H11 | **Autosave de Formulários vai para V1** agora, sem medir. Supera a regra dos 60% da ADR 0038. |

## 3. Visual

| Ref | Decisão |
|---|---|
| C1 goldens | As falhas das suítes de Segurança da criança, Perfis e Rotina são **deriva do cabeçalho global** (diff isolado só no canto superior direito). **Autorizado regravar as referências** após estabilizar o cabeçalho via `coelo-ui`; nunca por inferência. |
| C2 `owner.r12-11/20` | Cards de Perfis e permissões **aprovados como estão** (status + três linhas empilhadas); o 2×2 literal não é exigido. `owner.r12-11` → done ao registrar. |
| C3 `owner.r12-01` | Cards de Modelos de rotina: **altura uniforme**, linha "Efetivo: —" quando vazio, e **Arquivar em todos** (depende de B1). O item não estava corrigido; a referência antiga já tinha o defeito. |
| C4 `owner.r12-26` | Continuar laranja preenchido: **aceita a prova de FE** em teste; a captura na rota real entra junto do lote de Perfis. |

## 4. Autorizações de produção e ambiente

| Ref | Decisão |
|---|---|
| D1 OQ-046 | **Autorizada** leitura de metadados em produção (sem mutação) para confirmar Conta/Chat/fixture. |
| D2 | **Autorizado** renomear o carimbo colidente `20260915130000` do Chat, forward-only, após D1. |
| D3 `owner.r12-05` | **Autorizada** migration forward-only corrigindo o escopo de atividades em `superadmin_attendance_context_options`, com espelho + pgTAP antes. |
| D4 `owner.r12-13/15/16` | **Autorizados** diagnóstico e correção forward-only do 504 de `child_safety_change_lifecycle`. |
| D5 `agora.remove` | **Autorizada** a fixture cross-tenant (identidade sintética temporária revogada ao fim) para a negativa produtiva. |
| D6 `owner.r12-08` | **Não** criar crianças/vínculos fictícios agora; a prova com ≥2 alunos fica para depois. |
| D7 sessão QA | Credenciais QA **já existem** em `C:\Users\adrie\Documents\Coelo-backups\qa-r06-*.env` e `C:\Users\adrie\Documents\Coelo\supabase\usuario\` (pasta local, ignorada pelo Git desde 16/09). Sessões carregam `QA_EMAIL`/`QA_PASSWORD` no processo; `.env.local` do app precisa estar no checkout que roda. |
| D8 | Docker Desktop ficará ligado na próxima rodada (pgTAP local antes de produção). |

## 5. Perfis de cuidado — contrato redesenhado (A2, para R15)

O Owner descreveu o comportamento desejado; é **spec nova**, não ajuste:

- Alergias/restrições e orientações nascem **vazias**; botão "+ Adicionar
  restrição" (e equivalentes) cria uma linha por vez.
- O wizard separa **Alimentos** de **Restrições**; o tipo é definido pelo passo
  do wizard e salvo no banco, sem campo de tipo redundante.
- Cada registro tem **nome** escolhido de lista pré-definida categorizada
  (ex.: Frutas › Banana, Maçã; Bebidas › Leite), seleção única, com busca e
  opção "Outro" para texto livre. Listas iniciais: ~100 alimentos mais comuns
  em alergia infantil, 50 intermediários, 50 menos comuns; o mesmo para
  restrições e para orientações de cuidado. Listas são ajustáveis depois.
- Registros podem ser **reordenados** (arrastar/mover).
- Antes de Observações, campo **"O que fazer se consumido?"** (ou equivalente).
- Mantém-se o limite defensivo de 100 registros por coleção no backend.

## Consequências operacionais

- R14 continua vigente; nenhuma rodada nova é aberta por esta ADR.
- `R14-pendencias.md` recebe os aceites, os gates atualizados e as
  transferências (B7, §5 e H11 → V1) no mesmo ciclo desta ADR.
- Regra durável de segurança (B5): qualquer busca por prefixo sobre dado
  pessoal exige mínimo de caracteres, escopo do ator, auditoria, limite de taxa
  e resultado minimizado; CPF não é exibido em resultado de busca.
