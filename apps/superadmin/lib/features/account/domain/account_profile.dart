import 'dart:typed_data';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

enum AccountAvatarMode { initials, photo }

enum EmailChangeStatus { pending, approved, rejected }

@immutable
class AccountAvatar {
  static const defaultBackgroundColor = CoeloPalette.orange50;

  const AccountAvatar({
    required this.mode,
    required this.initials,
    required this.backgroundColor,
    this.photoBytes,
    this.photoScale = 1,
    this.photoOffset = Offset.zero,
  });

  final AccountAvatarMode mode;
  final String initials;
  final Color backgroundColor;
  final Uint8List? photoBytes;
  final double photoScale;
  final Offset photoOffset;

  static String initialsFor(String firstName, String lastName) {
    final parts = [firstName.trim(), lastName.trim()].where((part) => part.isNotEmpty).toList();
    return parts.take(2).map((part) => part.characters.first.toUpperCase()).join();
  }

  AccountAvatar resetFor(String firstName, String lastName) => AccountAvatar(
    mode: AccountAvatarMode.initials,
    initials: initialsFor(firstName, lastName),
    backgroundColor: defaultBackgroundColor,
  );

  static String? validateInitials(String value) {
    return RegExp(r'^[A-Za-zÀ-ÖØ-öø-ÿ]{1,2}$').hasMatch(value.trim())
        ? null
        : 'Use uma ou duas letras.';
  }

  static Color foregroundFor(Color background) {
    final whiteContrast = _contrast(background, Colors.white);
    final blackContrast = _contrast(background, Colors.black);
    return whiteContrast >= blackContrast ? Colors.white : Colors.black;
  }

  static double _contrast(Color first, Color second) {
    final light = first.computeLuminance();
    final dark = second.computeLuminance();
    final max = light > dark ? light : dark;
    final min = light > dark ? dark : light;
    return (max + 0.05) / (min + 0.05);
  }

  AccountAvatar copyWith({
    AccountAvatarMode? mode,
    String? initials,
    Color? backgroundColor,
    Uint8List? photoBytes,
    bool clearPhoto = false,
    double? photoScale,
    Offset? photoOffset,
  }) {
    return AccountAvatar(
      mode: mode ?? this.mode,
      initials: initials ?? this.initials,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      photoBytes: clearPhoto ? null : photoBytes ?? this.photoBytes,
      photoScale: photoScale ?? this.photoScale,
      photoOffset: photoOffset ?? this.photoOffset,
    );
  }
}

@immutable
class EmailChangeRequest {
  const EmailChangeRequest({required this.requestedEmail, required this.status});

  final String requestedEmail;
  final EmailChangeStatus status;

  EmailChangeRequest copyWith({EmailChangeStatus? status}) =>
      EmailChangeRequest(requestedEmail: requestedEmail, status: status ?? this.status);
}

@immutable
class AccountAccessSummary {
  const AccountAccessSummary({
    required this.role,
    required this.mfaEnabled,
    required this.capabilities,
  });

  final String role;
  final bool mfaEnabled;
  final List<String> capabilities;
}

@immutable
class AccountProfile {
  const AccountProfile({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.mobilePhone,
    required this.avatar,
    required this.access,
    this.emailChange,
  });

  factory AccountProfile.prototype() => const AccountProfile(
    firstName: 'Owner',
    lastName: 'Coelo',
    email: 'owner@coelo.me',
    mobilePhone: '+55 11 99999-0000',
    avatar: AccountAvatar(
      mode: AccountAvatarMode.initials,
      initials: 'OC',
      backgroundColor: CoeloPalette.orange50,
    ),
    access: AccountAccessSummary(
      role: 'Owner Coelo',
      mfaEnabled: true,
      capabilities: ['Instituições e planos', 'Usuários internos', 'Auditoria e permissões'],
    ),
  );

  final String firstName;
  final String lastName;
  final String email;
  final String mobilePhone;
  final AccountAvatar avatar;
  final AccountAccessSummary access;
  final EmailChangeRequest? emailChange;

  AccountProfile requestEmailChange(String requestedEmail) => copyWith(
    emailChange: EmailChangeRequest(
      requestedEmail: requestedEmail.trim().toLowerCase(),
      status: EmailChangeStatus.pending,
    ),
  );

  AccountProfile resolveEmailChange({required bool approved}) {
    final request = emailChange;
    if (request == null || request.status != EmailChangeStatus.pending) return this;
    return copyWith(
      email: approved ? request.requestedEmail : email,
      emailChange: request.copyWith(
        status: approved ? EmailChangeStatus.approved : EmailChangeStatus.rejected,
      ),
    );
  }

  AccountProfile copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? mobilePhone,
    AccountAvatar? avatar,
    AccountAccessSummary? access,
    EmailChangeRequest? emailChange,
    bool clearEmailChange = false,
  }) {
    return AccountProfile(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      mobilePhone: mobilePhone ?? this.mobilePhone,
      avatar: avatar ?? this.avatar,
      access: access ?? this.access,
      emailChange: clearEmailChange ? null : emailChange ?? this.emailChange,
    );
  }
}
