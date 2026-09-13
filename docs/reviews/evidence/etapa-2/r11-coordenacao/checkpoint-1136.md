---
source: C0 R11; UI normal; replay isolado; pgTAP focal
status: documentado-parcial; execução em andamento
generated_at: 2026-09-13
---

# Conta, Auth e Estrutura — checkpoint 11:36 BRT

apps/superadmin > Conta > Meu perfil > account.profile: código ebf7f23e2 publicado; 37 testes focais PASS, análise sem problemas e build release PASS. Novo runtime34876/3000, manifesto build-manifest.json. Rodapé e busca inspecionados em1440/375; PNGs account-footer-desktop/mobile e account-access-search. Confirmação autoritativa corrigida localmente. Persistência foto/cor/sigla, grupos reais e prova conjunta de salvar/reload continuam abertos. Nenhum aceite integral novo. Validador visual atual relata20 ocorrências fora de Conta; nenhuma nos arquivos alterados. A referência histórica16 não é resultado atual.

apps/superadmin > Auth > auth.recover/auth.reset: solicitação normal na janela QA isolada mostrou Confira seu e-mail; caixa acessível sem mensagem correspondente. SMTP próprio ausente no preflight. Não houve link real, redefinição nem troca de senha. Redirecionamento autorizado atual não inclui127.0.0.1:3000/reset-password; este é outro requisito de configuração para prova local. Não repetir envio nem usar Admin API como certificado. Próximo responsável Owner/acesso de caixa e configuração autorizada; sessão QA compartilhada preservada.

apps/superadmin > Estrutura > Atividades > Configuração avaliativa > activities.assessment: IDb04c879e-bedd-4e45-9358-66c545215646 é a configuração draft, não a atividade. Atividade95b98978-19e2-43ba-aa0c-70ae81557e08/unidadef5284f2f-b487-4100-bc0b-ffbcbb7d3db3. Rota normal com configurationId reproduziu SAI_INTERNAL_ERROR (assessment-update-red.json). Teste com duas configurações e diário ativo falhou em3/8 antes; qualificar quatro DELETEs por alias fez8/8 PASS. A diretiva use_variable fazia configuration_id comparar o parâmetro com saved.id e abrangia outras configurações. Candidato20260913143441, somente local; SQL remoto não aplicado. Publicar atividade e diário continuam sem aceite.

apps/superadmin > Estrutura > Turmas > listagem > groups.list: UI mostrou0/0 na Turma R05 Estrutura4214106c-46a2-4bf4-84ba-9c6a619bd486. Projeção de alunos retorna1; detalhes retornam3 IDs de atividades por herança da unidade (1atividade ativa,2drafts). Directory omite student_count/activity_ids; fallback Dart gera0. Corrigir projeção com semântica de vínculo/status vigente, sem inferir que listagem anterior certificou contadores.

Espelho local próprio coelo_r11 criado fora do Git; banco anterior preservado. Replay inicialmente por carimbo falhou na dependência D04; corrigido usando ordem-de-aplicacao-producao.txt após reset apenas do espelho novo.167/167 arquivos integrados aplicados serialmente no local; relatório local-replay.json. Nenhum SQL61/62/63 reaplicado remotamente. README recomenda carimbo, mas manifesto explícito registra a ordem real; divergência documental a reconciliar com a fonte operacional.

Cota89% usados, mesmo reset/janela; teto98/freeze95. PITRfalse ainda diverge do prompt atual: decisão solicitada uma vez, pendente. C0 continua código/testes locais. Novos commits externos da R12 preservados, inclusive14a89cc41; R12 não executada por C0. Próximo gate: candidato Turmas e confirmação de contrato da Conta; SQL depende da resolução do requisito de backup.
