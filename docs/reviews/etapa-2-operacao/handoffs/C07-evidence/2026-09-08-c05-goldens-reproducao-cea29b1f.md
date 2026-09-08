---
title: "C07 — reprodução das falhas visuais de C05 em commit fixado"
source: "flutter test em C:/Users/adrie/Documents/Coelo.worktrees/e2-r01-c07 (HEAD cea29b1f); log minimizado em scratchpad da sessão"
status: "evidence"
generated_at: "2026-09-08T17:57:11-03:00"
timezone: "America/Sao_Paulo"
---

# Reprodução — suíte das 14 features de C05 no SHA cea29b1f

- SHA testado: cea29b1f881d806bdf1e88fa3a5fb416d8f0fb5c (HEAD de código C05 no corte 17:43)
- Ambiente: Windows 11, Flutter 3.44.2 / Dart 3.12.2, sem backend, sem /dev, sem provedor de mídia, worktree limpa
- Início 17:46:40 / fim 17:50:47 (America/Sao_Paulo); duração 3m08s; exit=1
- Resultado: 930 passaram / 61 falharam; todas as 61 no inventário abaixo

## Comando

```
cd apps/superadmin
flutter test test/features/chat test/features/notices test/features/circulars test/features/principal_circulars test/features/principal_for_you test/features/principal_happens test/features/principal_happens_publication test/features/principal_moments test/features/principal_moments_publication test/features/principal_now test/features/principal_now_publication test/features/principal_profile test/features/principal_shared test/features/profile_about --reporter expanded
```

## Testes que falharam (61)

- test/features/chat/presentation/superadmin_chat_page_golden_test.dart: renders authorised chat data at 1024 in dark
- test/features/chat/presentation/superadmin_chat_page_golden_test.dart: renders authorised chat data at 1024 in light
- test/features/chat/presentation/superadmin_chat_page_golden_test.dart: renders authorised chat data at 1440 in dark
- test/features/chat/presentation/superadmin_chat_page_golden_test.dart: renders authorised chat data at 1440 in light
- test/features/chat/presentation/superadmin_chat_page_golden_test.dart: renders authorised chat data at 375 in dark
- test/features/chat/presentation/superadmin_chat_page_golden_test.dart: renders authorised chat data at 375 in light
- test/features/chat/presentation/superadmin_chat_page_golden_test.dart: renders authorised chat data at 768 in dark
- test/features/chat/presentation/superadmin_chat_page_golden_test.dart: renders authorised chat data at 768 in light
- test/features/chat/presentation/superadmin_chat_page_golden_test.dart: renders authorised chat data with reduced motion
- test/features/circulars/presentation/circular_directory_golden_test.dart: directory matches the approved matrix at 375 in dark
- test/features/circulars/presentation/circular_directory_golden_test.dart: directory matches the approved matrix at 375 in light
- test/features/circulars/presentation/circular_directory_golden_test.dart: directory remains usable at 200 percent text in 375
- test/features/notices/notice_directory_golden_test.dart: matches the communication directory at 200 percent text in 375
- test/features/notices/notice_directory_golden_test.dart: matches the communication directory at 375 in dark
- test/features/notices/notice_directory_golden_test.dart: matches the communication directory at 375 in light
- test/features/notices/notice_form_golden_test.dart: matches the initial notice wizard on mobile and desktop
- test/features/principal_happens/presentation/principal_happens_preview_golden_test.dart: matches Acontece at 200 percent text with reduced motion
- test/features/principal_happens/presentation/principal_happens_preview_golden_test.dart: matches canonical Acontece composition dark_1024
- test/features/principal_happens/presentation/principal_happens_preview_golden_test.dart: matches canonical Acontece composition dark_1440
- test/features/principal_happens/presentation/principal_happens_preview_golden_test.dart: matches canonical Acontece composition dark_375
- test/features/principal_happens/presentation/principal_happens_preview_golden_test.dart: matches canonical Acontece composition dark_768
- test/features/principal_happens/presentation/principal_happens_preview_golden_test.dart: matches canonical Acontece composition light_1024
- test/features/principal_happens/presentation/principal_happens_preview_golden_test.dart: matches canonical Acontece composition light_1440
- test/features/principal_happens/presentation/principal_happens_preview_golden_test.dart: matches canonical Acontece composition light_375
- test/features/principal_happens/presentation/principal_happens_preview_golden_test.dart: matches canonical Acontece composition light_768
- test/features/principal_happens/presentation/principal_happens_preview_golden_test.dart: matches the approved orange hover for an Agora card
- test/features/principal_moments/presentation/principal_moments_preview_golden_test.dart: matches approved Momentos composition dark_1024
- test/features/principal_moments/presentation/principal_moments_preview_golden_test.dart: matches approved Momentos composition dark_1440
- test/features/principal_moments/presentation/principal_moments_preview_golden_test.dart: matches approved Momentos composition dark_375
- test/features/principal_moments/presentation/principal_moments_preview_golden_test.dart: matches approved Momentos composition dark_768
- test/features/principal_moments/presentation/principal_moments_preview_golden_test.dart: matches approved Momentos composition light_1024
- test/features/principal_moments/presentation/principal_moments_preview_golden_test.dart: matches approved Momentos composition light_1440
- test/features/principal_moments/presentation/principal_moments_preview_golden_test.dart: matches approved Momentos composition light_375
- test/features/principal_moments/presentation/principal_moments_preview_golden_test.dart: matches approved Momentos composition light_768
- test/features/principal_moments/presentation/principal_moments_preview_golden_test.dart: matches approved Momentos composition text_200_dark_1440
- test/features/principal_moments/presentation/principal_moments_preview_golden_test.dart: matches approved Momentos composition text_200_light_375
- test/features/principal_moments/presentation/principal_moments_preview_golden_test.dart: matches the approved Coelo like hover state
- test/features/principal_now_publication/presentation/principal_now_publication_golden_test.dart: matches Agora Capa editor
- test/features/principal_now_publication/presentation/principal_now_publication_golden_test.dart: matches Agora Cortar editor
- test/features/principal_now_publication/presentation/principal_now_publication_golden_test.dart: matches Agora audience hover
- test/features/principal_now_publication/presentation/principal_now_publication_golden_test.dart: matches Agora composer dark_1024
- test/features/principal_now_publication/presentation/principal_now_publication_golden_test.dart: matches Agora composer dark_1440
- test/features/principal_now_publication/presentation/principal_now_publication_golden_test.dart: matches Agora composer dark_1440_200
- test/features/principal_now_publication/presentation/principal_now_publication_golden_test.dart: matches Agora composer dark_375
- test/features/principal_now_publication/presentation/principal_now_publication_golden_test.dart: matches Agora composer dark_768
- test/features/principal_now_publication/presentation/principal_now_publication_golden_test.dart: matches Agora composer light_1024
- test/features/principal_now_publication/presentation/principal_now_publication_golden_test.dart: matches Agora composer light_1440
- test/features/principal_now_publication/presentation/principal_now_publication_golden_test.dart: matches Agora composer light_375
- test/features/principal_now_publication/presentation/principal_now_publication_golden_test.dart: matches Agora composer light_375_200
- test/features/principal_now_publication/presentation/principal_now_publication_golden_test.dart: matches Agora composer light_768
- test/features/principal_now_publication/presentation/principal_now_publication_golden_test.dart: matches honest unavailable media without demo fallback
- test/features/principal_profile/presentation/principal_profile_preview_golden_test.dart: matches complete profile dark_1024
- test/features/principal_profile/presentation/principal_profile_preview_golden_test.dart: matches complete profile dark_1440
- test/features/principal_profile/presentation/principal_profile_preview_golden_test.dart: matches complete profile dark_375
- test/features/principal_profile/presentation/principal_profile_preview_golden_test.dart: matches complete profile dark_768
- test/features/principal_profile/presentation/principal_profile_preview_golden_test.dart: matches complete profile light_1024
- test/features/principal_profile/presentation/principal_profile_preview_golden_test.dart: matches complete profile light_1440
- test/features/principal_profile/presentation/principal_profile_preview_golden_test.dart: matches complete profile light_375
- test/features/principal_profile/presentation/principal_profile_preview_golden_test.dart: matches complete profile light_768
- test/features/principal_profile/presentation/principal_profile_preview_golden_test.dart: matches complete profile text_200_dark_1440
- test/features/principal_profile/presentation/principal_profile_preview_golden_test.dart: matches complete profile text_200_light_375

## Mensagens de golden (60 comparações de pixel)

O 61º caso, `principal_now_publication_golden_test.dart: matches honest unavailable media without demo fallback`, falhou por assertiva de widget (`Expected: exactly 2 matching candidates` / `Found 1 widget with key now-media-unavailable`), não por comparação de golden.

```
Golden "goldens/circular_directory_dark_375.png": Pixel test failed, 0.20%, 680px diff detected.
Golden "goldens/circular_directory_light_375.png": Pixel test failed, 0.20%, 680px diff detected.
Golden "goldens/circular_directory_text_200_375.png": Pixel test failed, 0.47%, 1933px diff
Golden "goldens/communication_directory_dark_375.png": Pixel test failed, 4.88%, 16482px diff
Golden "goldens/communication_directory_light_375.png": Pixel test failed, 5.31%, 17916px diff
Golden "goldens/communication_directory_text_200_375.png": Pixel test failed, 7.50%, 30926px diff
Golden "goldens/notice_form_initial_mobile_light_375.png": Pixel test failed, 37.69%, 127188px diff
Golden "goldens/principal_happens_dark_1024.png": Pixel test failed, 0.24%, 2202px diff detected.
Golden "goldens/principal_happens_dark_1440.png": Pixel test failed, 0.15%, 2202px diff detected.
Golden "goldens/principal_happens_dark_375.png": Pixel test failed, 0.63%, 2123px diff detected.
Golden "goldens/principal_happens_dark_375_text_200.png": Pixel test failed, 0.65%, 2436px diff
Golden "goldens/principal_happens_dark_768.png": Pixel test failed, 0.28%, 2202px diff detected.
Golden "goldens/principal_happens_light_1024.png": Pixel test failed, 0.24%, 2203px diff detected.
Golden "goldens/principal_happens_light_1440.png": Pixel test failed, 0.15%, 2203px diff detected.
Golden "goldens/principal_happens_light_375.png": Pixel test failed, 0.63%, 2122px diff detected.
Golden "goldens/principal_happens_light_768.png": Pixel test failed, 0.28%, 2203px diff detected.
Golden "goldens/principal_happens_now_hover_light_1440.png": Pixel test failed, 0.15%, 2203px diff
Golden "goldens/principal_moments_dark_1024.png": Pixel test failed, 99.99%, 1023861px diff
Golden "goldens/principal_moments_dark_1440.png": Pixel test failed, 100.00%, 1439966px diff
Golden "goldens/principal_moments_dark_375.png": Pixel test failed, 99.53%, 335918px diff detected.
Golden "goldens/principal_moments_dark_768.png": Pixel test failed, 99.99%, 786333px diff detected.
Golden "goldens/principal_moments_light_1024.png": Pixel test failed, 99.99%, 1023861px diff
Golden "goldens/principal_moments_light_1440.png": Pixel test failed, 99.93%, 1439052px diff
Golden "goldens/principal_moments_light_375.png": Pixel test failed, 99.53%, 335918px diff detected.
Golden "goldens/principal_moments_light_768.png": Pixel test failed, 99.99%, 786333px diff detected.
Golden "goldens/principal_moments_like_hover_light_1440.png": Pixel test failed, 99.93%, 1439041px
Golden "goldens/principal_moments_text_200_dark_1440.png": Pixel test failed, 100.00%, 1727934px
Golden "goldens/principal_moments_text_200_light_375.png": Pixel test failed, 99.17%, 409091px diff
Golden "goldens/principal_now_publication_audience_hover_light_1440.png": Pixel test failed, 23.81%,
Golden "goldens/principal_now_publication_cover_open_light_1440.png": Pixel test failed, 32.03%,
Golden "goldens/principal_now_publication_crop_open_light_1440.png": Pixel test failed, 32.37%,
Golden "goldens/principal_now_publication_dark_1024.png": Pixel test failed, 38.01%, 389271px diff
Golden "goldens/principal_now_publication_dark_1440.png": Pixel test failed, 35.86%, 516451px diff
Golden "goldens/principal_now_publication_dark_1440_200.png": Pixel test failed, 28.73%, 413730px
Golden "goldens/principal_now_publication_dark_375.png": Pixel test failed, 52.68%, 177787px diff
Golden "goldens/principal_now_publication_dark_768.png": Pixel test failed, 37.46%, 294565px diff
Golden "goldens/principal_now_publication_light_1024.png": Pixel test failed, 35.09%, 359303px diff
Golden "goldens/principal_now_publication_light_1440.png": Pixel test failed, 32.73%, 471359px diff
Golden "goldens/principal_now_publication_light_375.png": Pixel test failed, 49.10%, 165724px diff
Golden "goldens/principal_now_publication_light_375_200.png": Pixel test failed, 51.91%, 175208px
Golden "goldens/principal_now_publication_light_768.png": Pixel test failed, 34.76%, 273366px diff
Golden "goldens/principal_profile_dark_1024.png": Pixel test failed, 1.00%, 11311px diff detected.
Golden "goldens/principal_profile_dark_1440.png": Pixel test failed, 0.74%, 11708px diff detected.
Golden "goldens/principal_profile_dark_375.png": Pixel test failed, 22.14%, 91330px diff detected.
Golden "goldens/principal_profile_dark_768.png": Pixel test failed, 1.35%, 11414px diff detected.
Golden "goldens/principal_profile_light_1024.png": Pixel test failed, 0.99%, 11128px diff detected.
Golden "goldens/principal_profile_light_1440.png": Pixel test failed, 0.73%, 11525px diff detected.
Golden "goldens/principal_profile_light_375.png": Pixel test failed, 22.12%, 91265px diff detected.
Golden "goldens/principal_profile_light_768.png": Pixel test failed, 1.33%, 11231px diff detected.
Golden "goldens/principal_profile_text_200_dark_1440.png": Pixel test failed, 11.55%, 199557px diff
Golden "goldens/principal_profile_text_200_light_375.png": Pixel test failed, 10.77%, 48453px diff
Golden "goldens/superadmin_chat_dark_1024.png": Pixel test failed, 0.20%, 1849px diff detected.
Golden "goldens/superadmin_chat_dark_1440.png": Pixel test failed, 0.14%, 1849px diff detected.
Golden "goldens/superadmin_chat_dark_375.png": Pixel test failed, 3.77%, 12731px diff detected.
Golden "goldens/superadmin_chat_dark_768.png": Pixel test failed, 5.69%, 39336px diff detected.
Golden "goldens/superadmin_chat_light_1024.png": Pixel test failed, 0.20%, 1849px diff detected.
Golden "goldens/superadmin_chat_light_1440.png": Pixel test failed, 0.14%, 1849px diff detected.
Golden "goldens/superadmin_chat_light_375.png": Pixel test failed, 3.61%, 12200px diff detected.
Golden "goldens/superadmin_chat_light_768.png": Pixel test failed, 4.45%, 30767px diff detected.
Golden "goldens/superadmin_chat_reduced_motion_light_375.png": Pixel test failed, 3.61%, 12200px
```
