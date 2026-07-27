import 'package:coelo_catalog/catalog/catalog_foundations.dart';
import 'package:coelo_catalog/catalog/catalog_registry.dart';
import 'package:coelo_catalog/presentation/catalog_home_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: CoeloTheme.light,
      darkTheme: CoeloTheme.dark,
      home: CatalogHomePage.fromIndexAsset(
        registry: buildCatalogRegistry(),
        foundations: buildCatalogFoundationRegistry(),
      ),
    ),
  );
}
