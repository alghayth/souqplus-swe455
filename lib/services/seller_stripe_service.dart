import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SellerStripeService {
  static const String _stripeOAuthAuthorizeUrl =
      'https://us-central1-souqplus-1bb34.cloudfunctions.net/createSellerStripeOAuthAuthorizeUrl';
  static const String _stripeOnboardingUrl =
      'https://us-central1-souqplus-1bb34.cloudfunctions.net/createSellerStripeAccountLink';
  static const Duration _requestTimeout = Duration(seconds: 15);

  static Future<bool> hasConnectedAccount(User user) async {
    final response = await _postToStripeEndpoint(
      user,
      payload: <String, dynamic>{'uid': user.uid, 'mode': 'status'},
    ).timeout(_requestTimeout);
    return response.isConnected;
  }

  static Future<bool> startOnboarding(BuildContext context, User user) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (await hasConnectedAccount(user)) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Your Stripe seller account is already connected.'),
          ),
        );
        return true;
      }

      final authorizeUrl = await _requestStripeOAuthAuthorizeUrl(user)
          .timeout(_requestTimeout);
      final authorizeUri = Uri.tryParse(authorizeUrl);
      if (authorizeUri == null) {
        throw Exception('Stripe OAuth URL was invalid.');
      }

      final launched = await launchUrl(
        authorizeUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception('Could not open the Stripe connection page.');
      }

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Complete Stripe sign in or sign up, then return to the app.'),
        ),
      );
      return true;
    } on SocketException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Network error while starting Stripe connection.'),
        ),
      );
      return false;
    } on HttpException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Stripe connection failed: ${e.message}')),
      );
      return false;
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not start Stripe onboarding: $e')),
      );
      return false;
    }
  }

  static Future<SellerStripePostingAccess> ensureConnectedBeforePosting(
    BuildContext context, {
    required User user,
    String dialogTitle = 'Connect Stripe',
    String dialogMessage =
        'Before posting a product, connect your seller Stripe account.',
    String confirmLabel = 'Connect Stripe',
    String successReminder =
        'Complete Stripe onboarding, then try posting again.',
  }) async {
    final hasStripeAccount = await hasConnectedAccount(user);
    if (hasStripeAccount) {
      return SellerStripePostingAccess.connected;
    }

    if (!context.mounted) {
      return SellerStripePostingAccess.cancelled;
    }

    final shouldConnect = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(dialogTitle),
          content: Text(dialogMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Not now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    if (shouldConnect != true) {
      return SellerStripePostingAccess.cancelled;
    }

    if (!context.mounted) {
      return SellerStripePostingAccess.cancelled;
    }

    final started = await startOnboarding(context, user);
    if (!context.mounted) {
      return SellerStripePostingAccess.cancelled;
    }

    if (started) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successReminder)));
      return SellerStripePostingAccess.onboardingStarted;
    }
    return SellerStripePostingAccess.cancelled;
  }
}

enum SellerStripePostingAccess {
  connected,
  onboardingStarted,
  cancelled,
}

class _StripeEndpointResponse {
  const _StripeEndpointResponse({
    required this.stripeAccountId,
    required this.onboardingUrl,
    required this.isConnected,
  });

  final String stripeAccountId;
  final String onboardingUrl;
  final bool isConnected;
}

Future<String> _requestStripeOAuthAuthorizeUrl(User user) async {
  final httpClient = HttpClient();

  try {
    final idToken = await user.getIdToken();
    final request = await httpClient.postUrl(
      Uri.parse(SellerStripeService._stripeOAuthAuthorizeUrl),
    );
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(<String, dynamic>{'uid': user.uid}));

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Stripe OAuth request failed (${response.statusCode}): $responseBody',
      );
    }

    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected Stripe OAuth response format.');
    }

    final authorizeUrl = (decoded['authorizeUrl'] as String? ?? '').trim();
    if (authorizeUrl.isEmpty) {
      throw Exception('Stripe OAuth response did not include authorizeUrl.');
    }

    return authorizeUrl;
  } finally {
    httpClient.close(force: true);
  }
}

Future<_StripeEndpointResponse> _postToStripeEndpoint(
  User user, {
  required Map<String, dynamic> payload,
}) async {
  final httpClient = HttpClient();

  try {
    final idToken = await user.getIdToken();
    final request = await httpClient.postUrl(
      Uri.parse(SellerStripeService._stripeOnboardingUrl),
    );
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(payload));

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Stripe connect request failed (${response.statusCode}): $responseBody',
      );
    }

    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected Stripe connect response format.');
    }

    return _StripeEndpointResponse(
      stripeAccountId: (decoded['stripeAccountId'] as String? ?? '').trim(),
      onboardingUrl: (decoded['onboardingUrl'] as String? ?? '').trim(),
      isConnected: decoded['isConnected'] == true,
    );
  } finally {
    httpClient.close(force: true);
  }
}
