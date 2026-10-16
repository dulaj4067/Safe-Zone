import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, FunctionException, PostgrestException;

/// An exception whose [message] is already written for people (our own
/// FamilyCircleException, DeletionException, RouteException...), so
/// [friendlyError] can show it as it is.
abstract interface class UserMessage {
  String get message;
}

/// Plain-English, user-facing wording for errors, so people see
/// "Email or password is incorrect." instead of
/// "AuthApiException(message: Invalid login credentials, ...)".
///
/// Every message here has a Sinhala / Tamil / Arabic translation in
/// `ui_text_*.dart`: show it with `context.tr(friendlyError(e))`. A test keeps
/// the two in step.
const String kNetworkError = "Couldn't reach the server. Check your connection and try again.";
const String kGenericError = 'Something went wrong. Please try again.';
const String kPermissionError = "You don't have permission to do that.";
const String kAlreadyExistsError = 'That already exists.';
const String kMissingItemError = 'That item no longer exists.';
const String kSessionExpiredError = 'Your session expired. Please sign in again.';

/// Messages our own SQL functions raise on purpose (errcode P0001), matched
/// by a distinctive fragment and shown in clean wording. Anything not listed
/// falls back to the generic message rather than leaking server text.
const Map<String, String> kServerMessages = {
  'Sign in to invite': 'Sign in to invite family members.',
  'open invites': 'You already have 10 open invites. Revoke one first.',
  'Sign in to accept': 'Sign in to accept a family invite.',
  'not valid': 'This invite link is not valid.',
  'already been used': 'This invite link has already been used.',
  'has expired': 'This invite link has expired. Ask for a new one.',
  'own invite link': 'This is your own invite link. Share it with a family member.',
  'already in': 'You are already in this family circle.',
};

/// The messages this file can produce, for the translation-coverage test.
const List<String> kFriendlyErrorMessages = [
  ...kServerMessagesValues,
  kNetworkError,
  kGenericError,
  kPermissionError,
  kAlreadyExistsError,
  kMissingItemError,
  kSessionExpiredError,
  'Email or password is incorrect.',
  'An account with this email already exists. Try signing in.',
  'Choose a stronger password.',
  "That email address doesn't look valid.",
  'New sign-ups are turned off right now.',
  'Too many emails were requested. Please wait a few minutes and try again.',
  'Too many requests. Please wait a few minutes and try again.',
  'This account has been disabled.',
  'Choose a password different from your old one.',
  'An unexpected error occurred. Please try again.',
];

/// Wording for a Supabase Auth error, chosen by its machine-readable code.
String friendlyAuthMessage(AuthException e) {
  final code = e.code ?? '';
  switch (code) {
    case 'invalid_credentials':
      return 'Email or password is incorrect.';
    case 'user_already_exists':
    case 'email_exists':
      return 'An account with this email already exists. Try signing in.';
    case 'weak_password':
      return 'Choose a stronger password.';
    case 'email_address_invalid':
      return "That email address doesn't look valid.";
    case 'signup_disabled':
      return 'New sign-ups are turned off right now.';
    case 'over_email_send_rate_limit':
      return 'Too many emails were requested. Please wait a few minutes and try again.';
    case 'over_request_rate_limit':
      return 'Too many requests. Please wait a few minutes and try again.';
    case 'session_expired':
    case 'session_not_found':
    case 'refresh_token_not_found':
    case 'refresh_token_already_used':
    case 'bad_jwt':
      return kSessionExpiredError;
    case 'user_banned':
      return 'This account has been disabled.';
    case 'same_password':
      return 'Choose a password different from your old one.';
  }
  // Older servers report the reason in the message rather than a code.
  final message = e.message.toLowerCase();
  if (message.contains('invalid login credentials')) {
    return 'Email or password is incorrect.';
  }
  if (message.contains('already registered')) {
    return 'An account with this email already exists. Try signing in.';
  }
  if (e.statusCode == '429') {
    return 'Too many requests. Please wait a few minutes and try again.';
  }
  if (e.statusCode == '401') return kSessionExpiredError;
  return 'An unexpected error occurred. Please try again.';
}

/// The values of [kServerMessages] (a getter-free const for the list above).
const List<String> kServerMessagesValues = [
  'Sign in to invite family members.',
  'You already have 10 open invites. Revoke one first.',
  'Sign in to accept a family invite.',
  'This invite link is not valid.',
  'This invite link has already been used.',
  'This invite link has expired. Ask for a new one.',
  'This is your own invite link. Share it with a family member.',
  'You are already in this family circle.',
];

/// Wording for anything that can go wrong talking to the backend.
String friendlyError(Object error) {
  if (error is AuthException) return friendlyAuthMessage(error);
  if (error is PostgrestException) {
    if (error.code == 'P0001') {
      for (final entry in kServerMessages.entries) {
        if (error.message.contains(entry.key)) return entry.value;
      }
      return kGenericError;
    }
    switch (error.code) {
      case '42501': // row-level security / privilege
        return kPermissionError;
      case '23505': // unique violation
        return kAlreadyExistsError;
      case '23503': // foreign key violation
      case 'PGRST116': // no rows
        return kMissingItemError;
      case 'PGRST301': // JWT expired
        return kSessionExpiredError;
    }
    return kGenericError;
  }
  if (error is SocketException ||
      error is TimeoutException ||
      error is HttpException ||
      error is ClientException ||
      error is HandshakeException) {
    return kNetworkError;
  }
  if (error is UserMessage) return (error as UserMessage).message;
  if (error is FunctionException) return kGenericError;
  // Our own StateErrors (e.g. "You don't have permission to edit this
  // shelter.") are already written for people.
  if (error is StateError) return error.message;
  return kGenericError;
}
