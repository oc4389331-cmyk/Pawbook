import 'dart:async';
import 'dart:js' as js;
import 'solana_web_bridge.dart';

class SolanaWebBridgeWeb implements SolanaWebBridge {
  @override
  String? generateSolanaKeypair(String seed) {
    try {
      final bridge = js.context['PawtbookSolana'];
      if (bridge != null) {
        final res = bridge.callMethod('generateSolanaKeypair', [seed]);
        if (res != null) {
          final addr = res['address'];
          if (addr != null && addr.toString().isNotEmpty) {
            return addr.toString();
          }
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<Map<String, dynamic>> connectWallet(String methodName) async {
    try {
      final bridge = js.context['PawtbookSolana'];
      if (bridge != null) {
        final promise = bridge.callMethod(methodName);
        if (promise != null) {
          final completer = Completer<Map<String, dynamic>>();

          promise.callMethod('then', [
            js.allowInterop((result) {
              try {
                completer.complete({
                  'success': result['success'] == true,
                  'address': result['address']?.toString(),
                  'error': result['error']?.toString(),
                  'isNotInstalled': result['isNotInstalled'] == true,
                  'userCancelled': result['userCancelled'] == true,
                });
              } catch (e) {
                completer.complete({'success': false, 'error': e.toString()});
              }
            }),
            js.allowInterop((error) {
              completer.complete({
                'success': false,
                'error': error?.toString() ?? 'Error connecting wallet',
              });
            }),
          ]);

          return await completer.future.timeout(
            const Duration(seconds: 45),
            onTimeout: () => {
              'success': false,
              'error': 'Tiempo de espera agotado al conectar la wallet.',
            },
          );
        }
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
    return {'success': false, 'error': 'Bridge no disponible'};
  }

  @override
  Future<Map<String, dynamic>> sendSolanaTransaction(Map<String, dynamic> params) async {
    try {
      final bridge = js.context['PawtbookSolana'];
      if (bridge != null) {
        final jsParams = js.JsObject.jsify(params);
        final promise = bridge.callMethod('sendSolanaTransaction', [jsParams]);
        final completer = Completer<Map<String, dynamic>>();

        if (promise != null) {
          promise.callMethod('then', [
            js.allowInterop((result) {
              try {
                final dartMap = <String, dynamic>{
                  'success': result['success'] == true,
                  'signature': result['signature']?.toString(),
                  'solscanUrl': result['solscanUrl']?.toString(),
                  'fromAddress': result['fromAddress']?.toString(),
                  'toAddress': result['toAddress']?.toString(),
                  'tokenType': result['tokenType']?.toString() ?? params['tokenType'],
                  'skrAmount': (result['skrAmount'] is num) ? (result['skrAmount'] as num).toDouble() : (params['skrAmount'] ?? 0.0),
                  'solAmount': (result['solAmount'] is num) ? (result['solAmount'] as num).toDouble() : (params['solAmount'] ?? 0.0),
                  'userCancelled': result['userCancelled'] == true,
                  'isNotInstalled': result['isNotInstalled'] == true,
                  'insufficientBalance': result['insufficientBalance'] == true,
                  'error': result['error']?.toString(),
                };
                completer.complete(dartMap);
              } catch (e) {
                completer.complete({'success': false, 'error': e.toString()});
              }
            }),
            js.allowInterop((error) {
              final errStr = error?.toString() ?? 'Error en transacción de Solana';
              final isCancel = errStr.toLowerCase().contains('reject') ||
                  errStr.toLowerCase().contains('cancel') ||
                  errStr.toLowerCase().contains('decline');
              completer.complete({
                'success': false,
                'userCancelled': isCancel,
                'error': isCancel ? 'Transacción rechazada por el usuario.' : errStr,
              });
            }),
          ]);

          return await completer.future.timeout(
            const Duration(seconds: 60),
            onTimeout: () => {
              'success': false,
              'error': 'Tiempo de espera agotado al firmar transacción.',
            },
          );
        }
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
    return {'success': false, 'error': 'Bridge no disponible'};
  }

  @override
  Future<double> getSkrBalance(String walletAddress, {bool isDevnet = false}) async {
    try {
      final bridge = js.context['PawtbookSolana'];
      if (bridge != null) {
        final jsParams = js.JsObject.jsify({
          'walletAddress': walletAddress,
          'isDevnet': isDevnet,
        });

        final promise = bridge.callMethod('getSkrBalance', [jsParams]);
        final completer = Completer<double>();

        if (promise != null) {
          promise.callMethod('then', [
            js.allowInterop((result) {
              try {
                final skr = (result['skr'] is num) ? (result['skr'] as num).toDouble() : 0.0;
                completer.complete(skr);
              } catch (_) {
                completer.complete(0.0);
              }
            }),
            js.allowInterop((_) {
              completer.complete(0.0);
            }),
          ]);

          return await completer.future.timeout(
            const Duration(seconds: 5),
            onTimeout: () => 0.0,
          );
        }
      }
    } catch (_) {}
    return 0.0;
  }

  @override
  Future<Map<String, dynamic>> getWalletBalance(String walletAddress, {bool isDevnet = false}) async {
    try {
      final bridge = js.context['PawtbookSolana'];
      if (bridge != null) {
        final jsParams = js.JsObject.jsify({
          'walletAddress': walletAddress,
          'isDevnet': isDevnet,
        });

        final promise = bridge.callMethod('getWalletBalance', [jsParams]);
        final completer = Completer<Map<String, dynamic>>();

        if (promise != null) {
          promise.callMethod('then', [
            js.allowInterop((result) {
              try {
                completer.complete({
                  'success': result['success'] == true,
                  'sol': (result['sol'] is num) ? (result['sol'] as num).toDouble() : 0.0,
                  'lamports': (result['lamports'] is num) ? (result['lamports'] as num).toInt() : 0,
                  'error': result['error']?.toString(),
                });
              } catch (e) {
                completer.complete({'success': false, 'error': e.toString()});
              }
            }),
            js.allowInterop((err) {
              completer.complete({'success': false, 'error': err?.toString()});
            }),
          ]);

          return await completer.future.timeout(
            const Duration(seconds: 8),
            onTimeout: () => {'success': true, 'sol': 0.0, 'lamports': 0},
          );
        }
      }
    } catch (_) {}
    return {'success': true, 'sol': 0.0, 'lamports': 0};
  }
}

SolanaWebBridge getSolanaWebBridge() => SolanaWebBridgeWeb();
