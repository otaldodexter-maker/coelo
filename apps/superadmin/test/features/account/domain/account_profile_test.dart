import 'dart:typed_data';

import 'package:coelo_superadmin/features/account/domain/account_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountAvatar', () {
    test('resets a photo avatar to initials derived from the profile name', () {
      final avatar = AccountAvatar(
        mode: AccountAvatarMode.photo,
        initials: 'XX',
        backgroundColor: Colors.black,
        photoBytes: Uint8List.fromList([1, 2, 3]),
      );

      final reset = avatar.resetFor('Maria', 'Silva');

      expect(reset.mode, AccountAvatarMode.initials);
      expect(reset.initials, 'MS');
      expect(reset.photoBytes, isNull);
      expect(reset.backgroundColor, AccountAvatar.defaultBackgroundColor);
    });

    test('derives at most two uppercase initials from the profile name', () {
      expect(AccountAvatar.initialsFor('Adriano', 'Coelo'), 'AC');
      expect(AccountAvatar.initialsFor('adriano', ''), 'A');
    });

    test('accepts one or two letters and rejects other initials', () {
      expect(AccountAvatar.validateInitials('OC'), isNull);
      expect(AccountAvatar.validateInitials('A'), isNull);
      expect(AccountAvatar.validateInitials(''), isNotNull);
      expect(AccountAvatar.validateInitials('A3'), isNotNull);
      expect(AccountAvatar.validateInitials('ABC'), isNotNull);
    });

    test('chooses the black or white foreground with the highest contrast', () {
      expect(AccountAvatar.foregroundFor(const Color(0xFF101010)), Colors.white);
      expect(AccountAvatar.foregroundFor(const Color(0xFFF5F5F5)), Colors.black);
    });
  });

  group('AccountProfile', () {
    test('prototype provides the configured mobile phone', () {
      expect(AccountProfile.prototype().mobilePhone, '+55 11 99999-0000');
    });

    test('copyWith preserves the mobile phone when it is not supplied', () {
      final profile = AccountProfile.prototype().copyWith(firstName: 'Maria');

      expect(profile.mobilePhone, '+55 11 99999-0000');
    });

    test('keeps the active email while a different email is pending', () {
      final profile = AccountProfile.prototype().requestEmailChange('novo@coelo.me');

      expect(profile.email, 'owner@coelo.me');
      expect(profile.emailChange?.requestedEmail, 'novo@coelo.me');
      expect(profile.emailChange?.status, EmailChangeStatus.pending);
    });

    test('applies the requested email only after approval', () {
      final profile = AccountProfile.prototype()
          .requestEmailChange('novo@coelo.me')
          .resolveEmailChange(approved: true);

      expect(profile.email, 'novo@coelo.me');
      expect(profile.emailChange?.status, EmailChangeStatus.approved);
    });

    test('preserves the active email after rejection', () {
      final profile = AccountProfile.prototype()
          .requestEmailChange('novo@coelo.me')
          .resolveEmailChange(approved: false);

      expect(profile.email, 'owner@coelo.me');
      expect(profile.emailChange?.status, EmailChangeStatus.rejected);
    });
  });
}
