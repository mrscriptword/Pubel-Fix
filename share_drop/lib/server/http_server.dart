import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:network_info_plus/network_info_plus.dart';

class LocalServer {
  HttpServer? _server;
  String? _ipAddress;
  int _port = 8080;

  final List<File> sharedFiles = [];

  Future<String?> start() async {
    final info = NetworkInfo();
    _ipAddress = await info.getWifiIP();

    if (_ipAddress == null) {
      return null;
    }

    final app = Router();

    // Serve a simple HTML page for the PC to see the files
    app.get('/', (Request request) {
      String fileListHtml = sharedFiles.map((file) {
        String fileName = file.uri.pathSegments.last;
        return '<li><a href="/download/$fileName">$fileName</a></li>';
      }).join('\n');

      final html = '''
        <!DOCTYPE html>
        <html>
        <head>
          <title>Pubel PC Access</title>
          <style>
            body { font-family: sans-serif; background: #f0f0f0; padding: 2rem; }
            .container { background: white; padding: 2rem; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
            h1 { color: #8A56AC; }
            a { text-decoration: none; color: #333; font-weight: bold; }
            li { margin: 10px 0; padding: 10px; background: #eee; border-radius: 4px; }
          </style>
        </head>
        <body>
          <div class="container">
            <h1>Pubel Shared Files</h1>
            <ul>
              $fileListHtml
            </ul>
          </div>
        </body>
        </html>
      ''';
      return Response.ok(html, headers: {'content-type': 'text/html'});
    });

    // Endpoint to download a file
    app.get('/download/<filename>', (Request request, String filename) {
      try {
        final file = sharedFiles.firstWhere((f) => f.uri.pathSegments.last == filename);
        return Response.ok(file.openRead(), headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Disposition': 'attachment; filename="$filename"'
        });
      } catch (e) {
        return Response.notFound('File not found');
      }
    });

    final pipeline = const Pipeline().addMiddleware(logRequests()).addHandler(app);

    _server = await io.serve(pipeline, InternetAddress.anyIPv4, _port);
    print('Serving at http://$_ipAddress:$_port');
    return 'http://$_ipAddress:$_port';
  }

  void addFile(File file) {
    sharedFiles.add(file);
  }

  void clearFiles() {
    sharedFiles.clear();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
  }
}
