import 'package:coelo_superadmin/features/principal_happens_publication/domain/happens_publication.dart';
import 'package:flutter_test/flutter_test.dart';

/// O destino do upload pertence ao SERVIDOR.
///
/// O cliente fixava o bucket `coelo-happens-mvp` e subia sempre pelo caminho
/// assinado do Supabase Storage. Isso e violacao viva da ADR 0032, que diz que
/// bucket e provedor nao sao escolha do cliente, e existe hoje, sem relacao com
/// o R2. O intent passou a carregar o provedor anunciado.
///
/// A condicao de aceite desta correcao e a primeira secao: enquanto o servidor
/// anunciar o provedor legado, NADA muda, mesmo caminho e mesmo bucket.
void main() {
  group('enquanto o servidor anunciar o provedor legado, nada muda', () {
    test('um envelope sem provedor continua no caminho legado', () {
      const intent = HappensUploadIntent(
        assetId: 'asset-1',
        institutionId: 'institution-1',
        postId: 'post-1',
        requestId: 'request-1',
        displayOrder: 0,
        objectKey: 'institution-1/post-1/asset-1.png',
        token: 'upload-token',
      );

      expect(intent.usesR2, isFalse);
      expect(intent.storageProvider, 'supabase_mvp');
      expect(intent.legacyBucket, 'coelo-happens-mvp');
      expect(intent.legacyBucket, legacyHappensBucket);
    });

    test('um envelope legado explicito usa o mesmo bucket de sempre', () {
      const intent = HappensUploadIntent(
        assetId: 'asset-1',
        institutionId: 'institution-1',
        postId: 'post-1',
        requestId: 'request-1',
        displayOrder: 0,
        storageProvider: 'supabase_mvp',
        objectKey: 'institution-1/post-1/asset-1.png',
        token: 'upload-token',
      );

      expect(intent.usesR2, isFalse);
      expect(intent.legacyBucket, 'coelo-happens-mvp');
    });

    test('o bucket anunciado pelo servidor vence o valor de transicao', () {
      const intent = HappensUploadIntent(
        assetId: 'asset-1',
        institutionId: 'institution-1',
        postId: 'post-1',
        requestId: 'request-1',
        displayOrder: 0,
        bucketId: 'coelo-happens-outro',
        objectKey: 'institution-1/post-1/asset-1.png',
        token: 'upload-token',
      );

      expect(intent.legacyBucket, 'coelo-happens-outro');
    });
  });

  group('quando o servidor anunciar R2', () {
    HappensUploadIntent r2Intent({DateTime? expiresAt}) => HappensUploadIntent(
      assetId: 'asset-1',
      institutionId: 'institution-1',
      postId: 'post-1',
      requestId: 'request-1',
      displayOrder: 0,
      storageProvider: 'r2',
      uploadUrl: Uri.parse('https://account.r2.cloudflarestorage.com/put?sig=1'),
      requiredHeaders: const {'content-type': 'image/png'},
      expiresAt: expiresAt ?? DateTime.utc(2026, 9, 10, 3),
    );

    test('o intent nao carrega bucket nem chave', () {
      final intent = r2Intent();

      expect(intent.usesR2, isTrue);
      expect(intent.bucketId, isNull);
      expect(intent.objectKey, isNull);
      expect(intent.token, isNull);
      expect(intent.uploadUrl, isNotNull);
      expect(intent.requiredHeaders['content-type'], 'image/png');
    });

    test('a janela assinada expira em vez de transferir contra assinatura vencida', () {
      final intent = r2Intent(expiresAt: DateTime.utc(2026, 9, 10, 3));

      expect(intent.expiredAt(DateTime.utc(2026, 9, 10, 2, 59)), isFalse);
      expect(intent.expiredAt(DateTime.utc(2026, 9, 10, 3)), isTrue);
      expect(intent.expiredAt(DateTime.utc(2026, 9, 10, 4)), isTrue);
    });

    test('sem expiracao anunciada o intent nao se declara vencido', () {
      const intent = HappensUploadIntent(
        assetId: 'asset-1',
        institutionId: 'institution-1',
        postId: 'post-1',
        requestId: 'request-1',
        displayOrder: 0,
        storageProvider: 'r2',
      );

      expect(intent.expiredAt(DateTime.utc(2030)), isFalse);
    });
  });
}
