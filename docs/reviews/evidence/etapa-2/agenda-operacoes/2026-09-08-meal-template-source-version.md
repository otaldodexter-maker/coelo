---
title: "Cardápios — origem versionada fora da primeira página"
source: "wizard; contrato source_template_id/source_template_version; revisão e testes locais"
status: "correção local verificada; persistência real pendente"
generated_at: "2026-09-08"
---

## Complemento de verificação — troca, remoção e mesma referência

Após `1975630`, três testes adicionais exercitaram o seletor pelo widget e o
draft resultante: troca para alternativa v4 copia prato v4 e referência/versão
v4; limpar remove referência/versão sem apagar o conteúdo histórico; escolher
novamente a mesma referência mantém prato/versão v1 apesar do catálogo v2.
Os três passaram na primeira execução: são cobertura de comportamento
existente, não três novos bugs corrigidos. Nenhum código produtivo foi alterado.
Suite completa do wizard: **36 PASS**, analyzer PASS e review independente
`agenda_ui_contract` sem blocker. A troca usa conteúdo do catálogo; refresh de
detalhe e persistência reais não foram testados.

# Recorte

Superadmin, criar a partir de modelo e editar cardápio com origem histórica.
Objetivo: não depender da primeira página para renderizar seleção nem alterar
a versão de origem sem trocar o conteúdo. Incluído: estado do wizard e testes.
Fora: SQL, elegibilidade backend, mídia e publicação remota. Ordem: reproduzir,
corrigir, regressão, revisão. Parada da fatia: quatro cenários verdes com ID,
versão e conteúdo coerentes. Tempo aproximado: 8 minutos.

## Defeito e correção

A lista de modelos é paginada. O detalhe autorizado podia fornecer conteúdo v3
enquanto a primeira página fornecia v2; o draft usava v2. Na edição, a origem
histórica v1 também era substituída pela versão do catálogo. Se o modelo não
estivesse na página, o label fazia `.first` e lançava `StateError`.

Agora ID/versão/nome selecionados ficam associados ao conteúdo hidratado:
detalhe na cópia; metadados originais na edição. O detalhe substitui a entrada
da página quando usado para copiar. Seleção histórica ausente recebe label
original ou neutro, sem buscar ou reidratar silenciosamente a versão atual.
Selecionar o mesmo ID é no-op; escolher outro atualiza metadados; “sem modelo”
e troca de contexto limpam esses metadados.

## Evidência

- Quatro REDs reais: duas versões incorretas (2 em vez de3/1) e dois
  `StateError` por origem fora da página (cópia e edição).
- A preparação inicial de duas fixtures não definia dias da refeição; foi
  corrigida antes de medir os REDs de versão. Não era erro do produto.
- Quatro focados e60 regressões de data/wizard/diretório PASS.
- Analyzer final sem problemas; validator visual PASS; revisão independente
  sem blocker. Nenhum golden foi alterado.

Seleção posterior de outro modelo/sem modelo foi revisada estaticamente, não
ganhou cenário novo nesta fatia. SQL não foi executado; FK de origem versionada
e salvamento/reload backend continuam a exigir teste nominal real.
Memória: preserva contrato existente, sem nova regra de produto para projetar.
