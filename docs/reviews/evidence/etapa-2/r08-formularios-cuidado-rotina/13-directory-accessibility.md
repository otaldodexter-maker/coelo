---
source: "C0 próximo gate após H25; forms_accessibility_guidelines_test; evidências10 e12"
status: "local-green; teste histórico reativado após medição"
generated_at: "2026-09-12"
---

# Diretório Formulários: gate completo de acessibilidade

`apps/superadmin -> Formulários -> diretório -> H25`. O teste histórico `the forms directory meets tap size, labelling and contrast` estava ignorado por alça12x56 e nó longPress sem nome. O primeiro foi corrigido com H25 e pintura preservada; o segundo já está rotulado no componente de toggle atual. Teste novo da fatia10 mediu toque/rótulo em375/1440, mas não substituiu contraste.

C0 autorizou preparar a execução do teste original semskip, esperar slot G4→C0 e só depois decidir remoção definitiva ou correção mínima do primeiro problema reproduzido. Nenhum token ou PNG foi alterado nesta preparação. O comentário histórico será conciliado após o resultado, sem fingir que o teste já executava.

Inspeção: cabeçalho usa `dataTableTheme.headingTextStyle`; status usa `CoeloStatusColors` com pares container/onContainer. Isso localiza as fontes, mas não prova contraste. A prova será o teste completo no composto, com ambiente/base/resultado registrados abaixo.

## Resultado

Base G3 `d2bd9471c` contém H25/pintura e origin/dev ciclo150. Slot nominal C0 liberado após seu rerun integrado37PASS. Comando: `flutter test test/features/forms/presentation/forms_accessibility_guidelines_test.dart --plain-name 'the forms directory meets tap size, labelling and contrast' --concurrency=1 --reporter expanded`, em `apps/superadmin` via rtk proxy.

Resultado:1PASS/0FAIL, exit0 na primeira execução, em1440×1000/tema claro, com dados sintéticos locais. Não há RED novo: o defeito já foi corrigido pelos pacotes anteriores e o teste estava ignorado. Log `13-directory-guidelines.log`; análise do arquivo exit0 sem problemas, `13-directory-analyze.log`. Slot Flutter liberado imediatamente. Não repetimos o restante da suíte, que não mudou.

Retirados skip e comentário de bloqueio obsoleto; nenhuma alteração de produto, token ou PNG. O caso já existia e agora foi executado: registrar como reativação, não como teste novo. Prova não inclui UI real, todas as telas, todos os temas ou garantia AA global. A medição de375 de toque/rótulo permanece na evidência10; contraste375 não foi contado aqui.
