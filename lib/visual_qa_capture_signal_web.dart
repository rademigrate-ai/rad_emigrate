import 'dart:js_interop';

@JS('window.radQaAssetsReady')
external set _assetsReady(JSBoolean value);

void markVisualQaAssetsReady() => _assetsReady = true.toJS;
