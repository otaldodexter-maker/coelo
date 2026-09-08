import 'dart:async';

import 'package:coelo_domain/locations.dart';
import 'package:flutter/material.dart';

import '../../auth/domain/logout_action.dart';
import '../../units/domain/unit_detail.dart';
import '../domain/location_catalog_reader.dart';
import '../domain/location_catalog_writer.dart';
import 'location_read_widgets.dart';
import 'locations_page.dart';

/// Resolves the institution a unit belongs to before opening its catalog.
///
/// The unit catalog is scoped by institution and unit together, and the route
/// only carries the unit. Taking the institution from the URL would let a
/// caller pair any unit with any institution, so it is read from the
/// authorized unit detail instead — the same read the unit screen uses. The
/// server still revalidates the pair on every catalog read.
final class UnitLocationsGate extends StatefulWidget {
  const UnitLocationsGate({
    required this.unitId,
    required this.logout,
    this.unitDetailRepository = const UnavailableUnitDetailRepository(),
    this.reader = const UnavailableLocationCatalogReader(),
    this.writer = const UnavailableLocationCatalogWriter(),
    this.canCreate = false,
    this.sessionAvailable = false,
    this.contextRevision = 0,
    this.selectedLocationId,
    this.onLocationOpened,
    this.onLocationClosed,
    this.onDestinationSelected,
    super.key,
  });

  final String unitId;
  final LogoutAction logout;
  final UnitDetailRepository unitDetailRepository;
  final LocationCatalogReader reader;
  final LocationCatalogWriter writer;
  final bool canCreate;
  final bool sessionAvailable;
  final int contextRevision;
  final String? selectedLocationId;
  final ValueChanged<String>? onLocationOpened;
  final VoidCallback? onLocationClosed;
  final ValueChanged<String>? onDestinationSelected;

  @override
  State<UnitLocationsGate> createState() => _UnitLocationsGateState();
}

final class _UnitLocationsGateState extends State<UnitLocationsGate> {
  LocationReadState _state = LocationReadState.unavailable;
  UnitDetail? _detail;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant UnitLocationsGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.unitId != widget.unitId ||
        oldWidget.contextRevision != widget.contextRevision ||
        oldWidget.sessionAvailable != widget.sessionAvailable ||
        !identical(oldWidget.unitDetailRepository, widget.unitDetailRepository)) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final epoch = ++_epoch;
    final repository = widget.unitDetailRepository;
    final unitId = widget.unitId;
    setState(() {
      _detail = null;
      _state = widget.sessionAvailable && validLocationId(unitId)
          ? LocationReadState.loading
          : LocationReadState.denied;
    });
    if (_state != LocationReadState.loading) return;
    try {
      final detail = await repository.fetchById(unitId);
      if (!mounted || epoch != _epoch) return;
      if (detail.id != unitId || !validLocationId(detail.institutionId)) {
        throw const UnitDetailException(UnitDetailFailure.unavailable);
      }
      setState(() {
        _detail = detail;
        _state = LocationReadState.ready;
      });
    } on UnitDetailException catch (error) {
      if (!mounted || epoch != _epoch) return;
      setState(
        () => _state = error.failure == UnitDetailFailure.denied
            ? LocationReadState.denied
            : LocationReadState.unavailable,
      );
    } on Object {
      if (!mounted || epoch != _epoch) return;
      setState(() => _state = LocationReadState.unavailable);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    if (detail == null) {
      return Scaffold(
        body: Center(
          child: LocationReadStatePanel(state: _state, prefix: 'unit-locations-gate'),
        ),
      );
    }
    return LocationsPage(
      scope: LocationScope.unit(institutionId: detail.institutionId, unitId: detail.id),
      logout: widget.logout,
      reader: widget.reader,
      writer: widget.writer,
      canCreate: widget.canCreate,
      sessionAvailable: widget.sessionAvailable,
      contextRevision: widget.contextRevision,
      selectedLocationId: widget.selectedLocationId,
      onLocationOpened: widget.onLocationOpened,
      onLocationClosed: widget.onLocationClosed,
      onDestinationSelected: widget.onDestinationSelected,
      currentDestination: 'units',
    );
  }
}
