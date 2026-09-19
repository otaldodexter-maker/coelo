/// User agent do navegador (só no web); vazio nas outras plataformas.
library;

export 'staff_access_user_agent_stub.dart'
    if (dart.library.html) 'staff_access_user_agent_web.dart';
