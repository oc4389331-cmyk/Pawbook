import 'package:flutter/material.dart';

/// Global RouteObserver for tracking route changes and active screen states
/// across the application, ensuring video/audio playback pauses when inactive.
final RouteObserver<ModalRoute<void>> appRouteObserver = RouteObserver<ModalRoute<void>>();
