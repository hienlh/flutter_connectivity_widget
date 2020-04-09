import 'dart:async';

import 'package:connectivity/connectivity.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';

import 'event.dart';

/// Callback to verify the response of the pinged server
typedef VerifyResponseCallback = bool Function(String response);

/// Connectivity Utils
///
/// Helper class to determine phone connectivity
class ConnectivityUtils {
  /// Server to ping
  ///
  /// The server to ping and check the response, can be set with [setServerToPing]
  String _serverToPing = "http://www.google.com";

  /// Verify Response Callback
  ///
  /// Callback to verify the response of the [_serverToPing]
  VerifyResponseCallback _callback = (_) => true;

  /// Sets a new server to ping
  void setServerToPing(String serverToPing) {
    _serverToPing = serverToPing;
  }

  /// Sets a new VerifyResponseCallback
  void setCallback(VerifyResponseCallback callback) {
    _callback = callback;
  }

  static final ConnectivityUtils _instance = ConnectivityUtils._();

  static ConnectivityUtils get instance {
    return _instance;
  }

  ConnectivityUtils._() {
    Connectivity().onConnectivityChanged.listen((_) =>
        _getConnectivityStatusSubject.add(Event()), onError: (_) => _getConnectivityStatusSubject.add(Event())
    );

    /// Stream that receives events and verifies the network status
    _getConnectivityStatusSubject.stream
        .asyncMap((_) => isPhoneConnected())
        .listen((value) async {
      // only add a new value if we are changing state
      if (value != _connectivitySubject.value) _connectivitySubject.add(value);
      // if we are offline, retry until we are online
      if (!value) {
        await Future.delayed(Duration(seconds: 3));
        _getConnectivityStatusSubject.add(Event());
      }
    }, onError: (error) async {
      if (!_connectivitySubject.value) _connectivitySubject.add(false);
      // if we are offline, retry until we are online
      await Future.delayed(Duration(seconds: 3));
      _getConnectivityStatusSubject.add(Event());
    });

    _getConnectivityStatusSubject.add(Event());
  }

  /// Connectivity on/off events
  BehaviorSubject<bool> _connectivitySubject = BehaviorSubject<bool>();

  Stream<bool> get isPhoneConnectedStream => _connectivitySubject.stream;

  /// Event to check the network status
  PublishSubject<Event> _getConnectivityStatusSubject = PublishSubject<Event>();

  Sink<Event> get getConnectivityStatusSink =>
      _getConnectivityStatusSubject.sink;

  /// Check if phone is connected to the internet
  ///
  /// This method tries to access google.com to verify for
  /// internet connection
  ///
  /// returns [Future<bool>] with value [true] of connected to the
  /// internet
  Future<bool> isPhoneConnected() async {
    try {

      // ignore: close_sinks
      final result = await http.get(_serverToPing);
      if (result.statusCode == 200 && _callback(result.body)) {
        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }
}
