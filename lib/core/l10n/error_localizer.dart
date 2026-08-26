import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Maps known English error messages emitted by the auth repository to
/// localized strings. Returns null when the message is unknown.
String? _lookupAuthError(AppLocalizations l10n, String raw) {
  switch (raw) {
    case 'Wrong email or password. Please try again.':
      return l10n.authWrongEmailOrPassword;
    case 'That email address is not valid.':
      return l10n.authInvalidEmail;
    case 'This account has been disabled.':
      return l10n.authAccountDisabled;
    case 'Too many attempts. Please wait and try again.':
      return l10n.authTooManyAttempts;
    case 'Network error. Check your connection and try again.':
      return l10n.authNetworkError;
    case 'Email/password sign-in is not enabled for this Firebase project.':
      return l10n.authEmailSigninDisabled;
    case 'Sign-in failed. Check your email and password, then try again.':
      return l10n.authSigninFailedGeneric;
    default:
      return null;
  }
}

/// Localizes a raw error string shown in the UI. Unknown text is returned
/// unchanged so nothing breaks when the business layer emits new messages.
String localizeErrorText(BuildContext context, String raw) {
  final l10n = AppLocalizations.of(context)!;
  final direct = _lookupAuthError(l10n, raw);
  if (direct != null) return direct;

  const authPrefix = 'Authentication failed: ';
  if (raw.startsWith(authPrefix)) {
    final inner = raw.substring(authPrefix.length);
    return l10n.authFailed(_lookupAuthError(l10n, inner) ?? inner);
  }

  const appExceptionPrefix = 'AppException: ';
  if (raw.startsWith(appExceptionPrefix)) {
    final inner = raw.substring(appExceptionPrefix.length);
    return _lookupAuthError(l10n, inner) ?? inner;
  }

  const exceptionPrefix = 'Exception: ';
  if (raw.startsWith(exceptionPrefix)) {
    return raw.substring(exceptionPrefix.length);
  }

  return raw;
}
