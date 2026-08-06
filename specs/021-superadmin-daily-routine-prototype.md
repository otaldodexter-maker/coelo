---
title: "Protótipo local de Rotina diária"
source: "plano aprovado pelo usuário em 2026-08-03; correções de UI/UX aprovadas pelo usuário em 2026-08-05"
status: "implemented-local-prototype"
generated_at: "2026-08-06"
---

# Protótipo local de Rotina diária

## Objetivo e problema

Distinguir no Superadmin o modelo reutilizável da rotina efetivamente utilizada, preservando herança, versionamento e aplicação cotidiana com estado local determinístico.

## Escopo

Diretório único com tabs lineares `Modelos` e `Rotinas`, busca, origem, cards/tabela e ações contextuais. Permite criar modelo do zero, criar rotina preenchida a partir de modelo e duplicar ambos preservando o tipo. O cadastro usa quatro etapas: identidade, alcance, seções e campos, e revisão/ativação. Permanecem as regras existentes de herança institucional/unidade, mudanças opcionais e obrigatórias e snapshots históricos.

Cinco modelos iniciais Coelo são imutáveis e visualizáveis: Modelo Berçário, Modelo Fundamental, Modelo Médio, Modelo Pré e Modelo Maternal. Suas cópias são editáveis.

## Fora de escopo

Backend, scheduler, motor paralelo de notificações, persistência após recarga, alterações em Admin ou Principal, atividade como origem independente, Participantes e Prévia dentro do cadastro e o futuro padrão da chamada para o dia seguinte. O suporte canônico já existente para sentimentos permanece fora do cadastro e não recebe schema ou comportamento novo nesta entrega.

## Superfícies afetadas

Somente `apps/superadmin`, nas rotas `/daily-routine`, criação, edição e espelhos `/dev`. O item aparece em Acompanhamento abaixo de Assiduidade.

## Entidades e dados

`Modelo` é base reutilizável; `Rotina` é o objeto efetivamente utilizado. Ambos preservam tipo na duplicação. Nome duplicado remove um sufixo numérico final existente e recebe o próximo sufixo livre `(2)`, `(3)` e assim por diante. Os seis tipos de campo são texto curto, texto longo, escolha única, escolha múltipla, número e sim/não.

## Permissões e tenant

Owner escreve; demais atores ficam em leitura. Modelos fornecidos pelo Coelo não podem ser editados nem excluídos, mas podem ser visualizados e duplicados. Atividade é alcance contextual dentro dos grupos selecionados, nunca origem independente.

## Estados de UX

`Modelos` e `Rotinas` são categorias irmãs no mesmo diretório. `Criar modelo` e `Nova rotina` acompanham a categoria selecionada. Cards de criação e existentes mantêm dimensões coerentes no grid. A duplicação usa ícone com tooltip e confirmação. Campos de escolha usam seletores Coelo; um valor inicial, quando definido, deve pertencer às opções atuais. Remover uma opção usada bloqueia o salvamento até uma nova seleção válida, inclusive a escolha explícita por nenhum valor inicial.

## Eventos, logs e notificações

Mudança obrigatória arquiva conflitos incompatíveis e reutiliza o sino local de Assiduidade. Atualização opcional apenas sinaliza disponibilidade e nunca sobrescreve a versão da unidade.

## Critérios de aceite

Modelo e rotina aparecem separados sem filtros `Todos`, `Ativos` ou `Inativos`. Criação a partir de modelo copia seus campos; duplicação preserva tipo, gera nome incremental correto e produz cópia editável. Os cinco modelos Coelo são imutáveis. Unidade mantém base, cria versão própria e acrescenta campos. Mudança obrigatória preserva adicionais compatíveis, arquiva conflitos e notifica. Snapshots permanecem ligados à versão usada.

## Testes exigidos

Testes de distinção de tipo, modelos imutáveis, duplicação e nomes incrementais, IDs após exclusão, criação a partir de modelo, valor inicial válido, permissões, alcance contextual, herança, conflitos, sino, snapshots, páginas, rotas e goldens mobile light/desktop dark; análise estática, semântica, texto a 200% e matriz responsiva/acessível.

## Riscos e perguntas abertas

O protótipo não valida sincronização concorrente, RLS ou migração real de versões. Regras de compatibilidade precisarão de contrato produtivo antes de persistência. O suporte canônico para sentimentos pode ser integrado futuramente à aplicação cotidiana, fora do cadastro, mediante escopo próprio.