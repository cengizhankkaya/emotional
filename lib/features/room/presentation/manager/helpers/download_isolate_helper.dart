import 'dart:isolate';
import 'dart:ui';

class DownloadIsolateHelper {
  final ReceivePort _port = ReceivePort();

  void bindBackgroundIsolate(
    Function(String id, int status, int progress) onData,
  ) {
    bool isRegistered = IsolateNameServer.registerPortWithName(
      _port.sendPort,
      'downloader_send_port',
    );

    if (!isRegistered) {
      IsolateNameServer.removePortNameMapping('downloader_send_port');
      isRegistered = IsolateNameServer.registerPortWithName(
        _port.sendPort,
        'downloader_send_port',
      );
    }

    if (isRegistered) {
      _port.listen((dynamic data) {
        final String id = data[0];
        final int status = data[1];
        final int progress = data[2];
        onData(id, status, progress);
      });
    }
  }

  void unbindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    _port.close();
  }

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send = IsolateNameServer.lookupPortByName(
      'downloader_send_port',
    );
    send?.send([id, status, progress]);
  }
}
