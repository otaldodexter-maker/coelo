import 'package:url_launcher/url_launcher.dart';

Future<bool> openDownloadUrl(String url) async {
  try {
    return await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
  } on Object {
    return false;
  }
}
