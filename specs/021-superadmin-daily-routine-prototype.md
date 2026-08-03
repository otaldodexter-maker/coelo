---
title: "Protótipo local de Rotina diária"
source: "plano aprovado pelo usuário em 2026-08-03; specs/020-superadmin-attendance-prototype.md"
status: "implemented-local-prototype"
generated_at: "2026-08-03"
---

# Protótipo local de Rotina diária

## Objetivo e problema

Validar a criação, distribuição, herança, versionamento e aplicação cotidiana de modelos de rotina diária no Superadmin, com estado local determinístico.

## Escopo

Diretório com busca, origem, cards/tabela e criação; editor em tela única; seções, campos, obrigatoriedade, valor inicial, rascunho e ativação; prévia com participantes; herança institucional/unidade, mudanças opcionais e obrigatórias e snapshots históricos. `Como chegou?` é um sentimento opcional, sem valor inicial, com cinco opções principais e quatro adicionais em `Ver mais`; emoji sempre acompanha rótulo textual.

## Fora de escopo

Backend, scheduler, motor paralelo de notificações, persistência após recarga, alterações em Admin ou Principal e atividade como origem independente.

## Superfícies afetadas

Somente `apps/superadmin`, nas rotas `/daily-routine`, criação, edição e espelhos `/dev`. O item aparece em Acompanhamento abaixo de Assiduidade.

## Entidades e dados

Modelo, versão, seção, campo, alcance, snapshot, conflito arquivado, sentimento aprovado e sugestão pendente. Os seis tipos são texto curto, texto longo, escolha única, escolha múltipla, número e sim/não. Sentimentos usam identificador estável; `Não informado` representa ausência de valor e nunca é persistido como sentimento. Sugestão livre permanece separada do catálogo e dos registros de participantes.

## Permissões e tenant

Owner escreve; demais atores ficam em leitura. Atividade é alcance contextual dentro dos grupos selecionados, nunca origem independente.

## Estados de UX

Cards ou tabela são mutuamente exclusivos. O editor comunica rascunho/ativo, origem, alcance, atualização disponível, mudança obrigatória e prévia operacional. Valores iniciais atingem apenas campos vazios. Sentimento pode ser selecionado, trocado ou limpo por participante; cinco opções ficam visíveis e quatro aparecem em `Ver mais`. O lote exige escolha explícita e o envio de sugestão apenas cria pendência local para avaliação.

## Eventos, logs e notificações

Mudança obrigatória arquiva conflitos incompatíveis e reutiliza o sino local de Assiduidade. Atualização opcional apenas sinaliza disponibilidade e nunca sobrescreve a versão da unidade.

## Critérios de aceite

Unidade mantém base, cria versão própria e acrescenta campos. Mudança obrigatória preserva adicionais compatíveis, arquiva conflitos e notifica. Snapshots permanecem ligados à versão usada. Aplicação em lote preserva exceções salvo confirmação explícita de sobrescrita. `Como chegou?` permanece opcional e sem preenchimento automático; as nove opções aprovadas exibem emoji e texto. Sugestões não entram automaticamente no catálogo e nunca são aplicadas a participantes.

## Testes exigidos

Testes de permissões, alcance contextual, herança, conflitos, sino, snapshots, lote, catálogo de sentimentos, opcionalidade, seleção, limpeza, sugestão separada, páginas, rotas e goldens mobile light/desktop dark; análise estática, semântica e matriz responsiva/acessível.

## Riscos e perguntas abertas

O protótipo não valida sincronização concorrente, RLS ou migração real de versões. Regras de compatibilidade precisarão de contrato produtivo antes de persistência. Sugestões exigirão moderação, auditoria, deduplicação e prevenção de abuso antes de qualquer backend; variação do catálogo por segmento ou faixa etária exige spec própria.
