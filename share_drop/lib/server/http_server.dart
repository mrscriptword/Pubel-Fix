import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path/path.dart' as p;

class ConnectionRequest {
  final String ip;
  final String userAgent;
  final Completer<bool> completer;

  ConnectionRequest(this.ip, this.userAgent, this.completer);
}

class LocalServer {
  HttpServer? _server;
  String? _ipAddress;
  final int _port = 8080;
  final String _rootDir = '/storage/emulated/0';

  final List<File> sharedFiles = [];
  final List<File> receivedFiles = [];
  final Set<String> _allowedIps = {};
  final Set<String> _pendingIps = {};
  
  final _requestController = StreamController<ConnectionRequest>.broadcast();
  Stream<ConnectionRequest> get onRequest => _requestController.stream;

  final _fileReceivedController = StreamController<File>.broadcast();
  Stream<File> get onFileReceived => _fileReceivedController.stream;

  Future<String?> start() async {
    final info = NetworkInfo();
    _ipAddress = await info.getWifiIP();

    if (_ipAddress == null) return null;

    final app = Router();

    // Middleware to check authorization
    Handler _authMiddleware(Handler innerHandler) {
      return (Request request) async {
        final connInfo = request.context['shelf.io.connection_info'] as HttpConnectionInfo;
        final ip = connInfo.remoteAddress.address;

        // Favicon handling to avoid 404 logs/delays
        if (request.url.path == 'favicon.ico') {
          return Response(204);
        }

        if (request.url.path == 'api/check-auth') {
          return Response.ok(jsonEncode({'authorized': _allowedIps.contains(ip)}), headers: {'content-type': 'application/json'});
        }

        if (!_allowedIps.contains(ip)) {
          if (request.url.path == '' || request.url.path == '/') {
            _triggerApproval(ip, request.headers['user-agent'] ?? 'Unknown Device');
            return Response.ok(_buildWaitingPage(ip), headers: {'content-type': 'text/html; charset=utf-8'});
          }
          
          _triggerApproval(ip, request.headers['user-agent'] ?? 'Unknown Device');
          return Response(403, body: jsonEncode({'error': 'Unauthorized'}), headers: {'content-type': 'application/json'});
        }

        return innerHandler(request);
      };
    }

    app.get('/', (Request request) {
      return Response.ok(_buildHtmlPage(), headers: {'content-type': 'text/html; charset=utf-8'});
    });

    app.get('/api/list', (Request request) async {
      try {
        final params = request.url.queryParameters;
        final relativePath = params['path'] ?? '';
        final fullPath = p.join(_rootDir, relativePath);

        final directory = Directory(fullPath);
        if (!await directory.exists()) {
          return Response.notFound(jsonEncode({'error': 'Folder tidak ditemukan.'}));
        }

        final List<Map<String, dynamic>> items = [];
        
        // Use non-blocking list stream for better responsiveness
        await for (final entity in directory.list(recursive: false, followLinks: false).handleError((_) {})) {
          final name = p.basename(entity.path);
          final isDir = entity is Directory;
          
          int size = 0;
          if (!isDir) {
            try { 
              // Only get length if it's a file, and use lengthSync for speed as it's usually fast for single files
              size = File(entity.path).lengthSync(); 
            } catch (_) {}
          }
          
          items.add({
            'name': name,
            'isDir': isDir,
            'size': size,
            'path': p.join(relativePath, name),
          });
        }
        
        items.sort((a, b) {
          if (a['isDir'] && !b['isDir']) return -1;
          if (!a['isDir'] && b['isDir']) return 1;
          return (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase());
        });

        return Response.ok(jsonEncode(items), headers: {'content-type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': 'Gagal memuat isi folder'}));
      }
    });

    app.get('/api/shared', (Request request) {
      final items = sharedFiles.map((file) {
        final name = p.basename(file.path);
        int size = 0;
        try { size = file.lengthSync(); } catch (_) {}
        return {
          'name': name,
          'isDir': false,
          'size': size,
          'path': file.path.replaceFirst(_rootDir, '').replaceFirst('/', ''),
        };
      }).toList().reversed.toList();

      return Response.ok(jsonEncode(items), headers: {'content-type': 'application/json'});
    });

    app.get('/api/download', (Request request) async {
      try {
        final params = request.url.queryParameters;
        final path = params['path'] ?? '';
        final fullPath = p.join(_rootDir, path);
        final file = File(fullPath);

        if (!await file.exists()) return Response.notFound('File not found');

        final fileName = p.basename(fullPath);
        return Response.ok(file.openRead(), headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Disposition': 'attachment; filename="$fileName"'
        });
      } catch (e) {
        return Response.internalServerError(body: 'Gagal mendownload file');
      }
    });

    app.post('/api/upload', (Request request) async {
      try {
        final params = request.url.queryParameters;
        final targetPath = params['path'] ?? '';
        final fullDestDir = p.join(_rootDir, targetPath);

        final contentType = request.headers['content-type'] ?? '';
        if (!contentType.contains('boundary=')) return Response(400, body: 'Missing boundary');
        
        final boundary = contentType.split('boundary=').last;
        final bodyBytes = await request.read().toList();
        final bytes = bodyBytes.expand((x) => x).toList();

        final boundaryBytes = utf8.encode('--$boundary');
        final endBoundaryBytes = utf8.encode('--$boundary--');
        
        int start = _findSequence(bytes, utf8.encode('\r\n\r\n'), 0);
        if (start == -1) return Response(400, body: 'Invalid upload data');
        
        final headerPart = utf8.decode(bytes.sublist(0, start), allowMalformed: true);
        final filenameMatch = RegExp(r'filename="([^"]+)"').firstMatch(headerPart);
        if (filenameMatch == null) return Response(400, body: 'No filename found');
        final filename = filenameMatch.group(1)!;

        int dataStart = start + 4;
        int dataEnd = _findSequence(bytes, boundaryBytes, dataStart);
        if (dataEnd == -1) dataEnd = _findSequence(bytes, endBoundaryBytes, dataStart);
        if (dataEnd == -1) return Response(400, body: 'Invalid upload data structure');
        
        final fileData = bytes.sublist(dataStart, dataEnd - 2);
        final destFile = File(p.join(fullDestDir, filename));
        await destFile.writeAsBytes(fileData);
        
        addFile(destFile);
        receivedFiles.add(destFile);
        _fileReceivedController.add(destFile);

        return Response.ok(jsonEncode({'success': true, 'message': 'Berhasil!'}));
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    app.post('/api/logout', (Request request) async {
      final connInfo = request.context['shelf.io.connection_info'] as HttpConnectionInfo;
      final ip = connInfo.remoteAddress.address;
      _allowedIps.remove(ip);
      return Response.ok(jsonEncode({'success': true}));
    });

    final pipeline = const Pipeline()
        .addMiddleware(_authMiddleware)
        .addHandler(app);
        
    _server = await io.serve(pipeline, InternetAddress.anyIPv4, _port);
    return 'http://$_ipAddress:$_port';
  }

  void _triggerApproval(String ip, String userAgent) {
    if (_allowedIps.contains(ip) || _pendingIps.contains(ip)) return;
    
    _pendingIps.add(ip);
    final completer = Completer<bool>();
    final request = ConnectionRequest(ip, userAgent, completer);
    _requestController.add(request);
    
    completer.future.then((approved) {
      _pendingIps.remove(ip);
      if (approved) {
        _allowedIps.add(ip);
      }
    });
  }

  int _findSequence(List<int> data, List<int> sequence, int start) {
    for (int i = start; i <= data.length - sequence.length; i++) {
      bool found = true;
      for (int j = 0; j < sequence.length; j++) {
        if (data[i + j] != sequence[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }

  void addFile(File file) {
    if (!sharedFiles.any((f) => f.path == file.path)) {
      sharedFiles.add(file);
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _requestController.close();
  }

  String _buildWaitingPage(String ip) {
    return '''
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Pubel — Menunggu Izin</title>
  <link href="https://fonts.googleapis.com/css2?family=Fraunces:ital,opsz,wght@0,9..144,300;0,9..144,600;1,9..144,300&family=DM+Sans:wght@300;400;500;600&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #F5F3EE;
      --surface: #FDFCFA;
      --text: #1A1814;
      --muted: #7A7770;
      --accent: #2D5BE3;
      --border: rgba(0,0,0,0.08);
    }
    [data-theme="dark"] {
      --bg: #111009;
      --surface: #1C1A14;
      --text: #F0EDE6;
      --border: rgba(255,255,255,0.07);
    }
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: 'DM Sans', sans-serif; background: var(--bg); color: var(--text); min-height: 100vh; display: flex; align-items: center; justify-content: center; transition: background 0.3s; }
    .card { background: var(--surface); border: 1px solid var(--border); border-radius: 12px; padding: 48px 32px; text-align: center; max-width: 400px; width: 90%; box-shadow: 0 10px 30px rgba(0,0,0,0.02); }
    .spinner { width: 48px; height: 48px; border: 3px solid var(--border); border-top-color: var(--accent); border-radius: 50%; animation: spin 1s linear infinite; margin: 0 auto 24px; }
    @keyframes spin { to { transform: rotate(360deg); } }
    h1 { font-family: 'Fraunces', serif; font-size: 24px; font-weight: 300; margin-bottom: 12px; }
    p { font-size: 14px; color: var(--muted); line-height: 1.6; }
    .ip { display: inline-block; background: var(--bg); padding: 4px 12px; border-radius: 6px; font-family: monospace; font-weight: 600; color: var(--accent); margin-top: 12px; font-size: 15px; }
  </style>
  <script>
    setInterval(async () => {
      try {
        const res = await fetch('/api/check-auth');
        const data = await res.json();
        if (data.authorized) window.location.reload();
      } catch (e) {}
    }, 2000);
    // Theme detection
    const theme = localStorage.getItem('theme') || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    document.documentElement.setAttribute('data-theme', theme);
  </script>
</head>
<body>
  <div class="card">
    <div class="spinner"></div>
    <h1>Menunggu Izin...</h1>
    <p>Buka aplikasi Pubel di ponsel Anda dan berikan izin akses untuk perangkat dengan IP ini:</p>
    <div class="ip">${ip}</div>
  </div>
</body>
</html>
''';
  }

  String _buildHtmlPage() {
    return r'''<!DOCTYPE html>
<html lang="id" data-theme="light">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Pubel — Premium File Transfer</title>
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg-color: #F8FAFC;
      --text-primary: #0F172A;
      --text-secondary: #64748B;
      --card-bg: #FFFFFF;
      --sidebar-bg: #FFFFFF;
      --border-color: #E2E8F0;
      --primary: #3B82F6;
      --primary-hover: #2563EB;
      --phone-bg: #1E293B;
      --phone-screen: #F1F5F9;
      --shadow-sm: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
      --shadow-md: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
      --shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
      --glass-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.07);
    }

    [data-theme="dark"] {
      --bg-color: #0B1120;
      --text-primary: #F8FAFC;
      --text-secondary: #94A3B8;
      --card-bg: rgba(30, 41, 59, 0.5);
      --sidebar-bg: rgba(15, 23, 42, 0.85);
      --border-color: rgba(51, 65, 85, 0.6);
      --primary: #3B82F6;
      --primary-hover: #60A5FA;
      --phone-bg: #000;
      --phone-screen: #1E293B;
      --shadow-sm: 0 1px 3px 0 rgba(0, 0, 0, 0.3);
      --shadow-md: 0 4px 6px -1px rgba(0, 0, 0, 0.4);
      --shadow-lg: 0 20px 25px -5px rgba(0, 0, 0, 0.5);
      --glass-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.3);
    }

    * { margin: 0; padding: 0; box-sizing: border-box; outline: none; }
    body { font-family: 'Outfit', system-ui, sans-serif; background: var(--bg-color); color: var(--text-primary); min-height: 100vh; display: flex; transition: background 0.4s ease; overflow-x: hidden; }
    
    /* Background Blobs */
    .bg-blob { position: fixed; border-radius: 50%; filter: blur(100px); z-index: -1; opacity: 0.4; animation: float 12s ease-in-out infinite; transition: opacity 0.4s ease; }
    .blob-1 { width: 50vw; height: 50vw; background: rgba(59, 130, 246, 0.4); top: -20vh; left: -10vw; }
    .blob-2 { width: 40vw; height: 40vw; background: rgba(16, 185, 129, 0.3); bottom: -10vh; right: -5vw; animation-delay: -6s; }
    [data-theme="dark"] .bg-blob { opacity: 0.15; }

    @keyframes float {
      0%, 100% { transform: translateY(0) scale(1); }
      50% { transform: translateY(-40px) scale(1.05); }
    }

    /* Sidebar */
    .sidebar { width: 80px; background: var(--sidebar-bg); backdrop-filter: blur(20px); -webkit-backdrop-filter: blur(20px); border-right: 1px solid var(--border-color); display: flex; flex-direction: column; align-items: center; padding: 24px 0; z-index: 10; transition: all 0.3s ease; }
    .logo { width: 44px; height: 44px; background: linear-gradient(135deg, #3B82F6, #8B5CF6); border-radius: 14px; margin-bottom: 40px; display: flex; justify-content: center; align-items: center; color: white; font-weight: 700; font-size: 24px; box-shadow: 0 4px 15px rgba(59, 130, 246, 0.4); text-shadow: 0 2px 4px rgba(0,0,0,0.2); }
    .nav-item { width: 48px; height: 48px; display: flex; justify-content: center; align-items: center; border-radius: 14px; margin-bottom: 12px; cursor: pointer; color: var(--text-secondary); font-size: 22px; transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1); position: relative; }
    .nav-item:hover { background: var(--card-bg); color: var(--primary); transform: translateY(-2px); box-shadow: var(--shadow-sm); }
    .nav-item.active { background: var(--primary); color: #fff; box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3); }
    
    /* Main Content */
    .main { flex: 1; display: flex; flex-direction: column; overflow: hidden; position: relative; z-index: 1; }
    
    /* Topbar */
    .topbar { height: 70px; background: transparent; display: flex; justify-content: flex-end; align-items: center; padding: 0 32px; gap: 16px; }
    .top-icon { color: var(--text-secondary); width: 40px; height: 40px; display: flex; justify-content: center; align-items: center; border-radius: 50%; background: var(--card-bg); backdrop-filter: blur(10px); border: 1px solid var(--border-color); font-size: 18px; cursor: pointer; transition: all 0.3s ease; box-shadow: var(--shadow-sm); }
    .top-icon:hover { color: var(--primary); transform: translateY(-2px); box-shadow: var(--shadow-md); border-color: var(--primary); }
    
    /* Content Area */
    .content-area { flex: 1; padding: 10px 40px 40px; overflow-y: auto; display: none; opacity: 0; }
    .content-area.active { display: block; animation: slideUpFade 0.5s cubic-bezier(0.16, 1, 0.3, 1) forwards; }
    
    @keyframes slideUpFade {
      from { opacity: 0; transform: translateY(30px) scale(0.98); }
      to { opacity: 1; transform: translateY(0) scale(1); }
    }

    /* Home View */
    .home-layout { display: flex; gap: 60px; align-items: center; max-width: 1100px; margin: 20px auto 0; }
    
    /* Phone Mockup */
    .phone-mockup { width: 280px; height: 580px; background: var(--phone-bg); border-radius: 40px; padding: 12px; box-shadow: var(--shadow-lg), 0 0 0 1px rgba(255,255,255,0.1) inset; position: relative; flex-shrink: 0; transition: transform 0.5s cubic-bezier(0.175, 0.885, 0.32, 1.275); }
    .phone-mockup:hover { transform: translateY(-10px) rotate(-2deg); }
    .phone-mockup::before { content: ''; position: absolute; top: 0; left: 50%; transform: translateX(-50%); width: 120px; height: 24px; background: var(--phone-bg); border-bottom-left-radius: 16px; border-bottom-right-radius: 16px; z-index: 2; }
    .phone-screen { width: 100%; height: 100%; background: var(--phone-screen); border-radius: 28px; display: flex; flex-direction: column; justify-content: center; align-items: center; overflow: hidden; position: relative; border: 1px solid rgba(0,0,0,0.1); transition: background 0.3s ease; }
    .drop-zone { width: 100%; height: 100%; display: flex; flex-direction: column; justify-content: center; align-items: center; cursor: pointer; transition: all 0.3s ease; background: transparent; }
    .drop-zone:hover, .drop-zone.dragover { background: rgba(59, 130, 246, 0.08); }
    .drop-icon { font-size: 56px; margin-bottom: 20px; pointer-events: none; filter: drop-shadow(0 4px 6px rgba(0,0,0,0.1)); transition: transform 0.3s ease; }
    .drop-zone:hover .drop-icon { transform: scale(1.1) translateY(-5px); }
    .drop-text { color: var(--text-secondary); font-size: 15px; font-weight: 500; pointer-events: none; }
    
    /* Categories */
    .categories-section { flex: 1; }
    .device-info { margin-bottom: 40px; animation: fadeRight 0.6s ease forwards; opacity: 0; }
    .device-name { font-size: 36px; font-weight: 700; color: var(--text-primary); letter-spacing: -0.5px; margin-bottom: 4px; }
    .device-os { font-size: 16px; color: var(--text-secondary); font-weight: 500; display: flex; align-items: center; gap: 8px; }
    .device-os::before { content: ''; display: inline-block; width: 8px; height: 8px; background: #10B981; border-radius: 50%; box-shadow: 0 0 10px #10B981; }
    
    @keyframes fadeRight {
      from { opacity: 0; transform: translateX(-20px); }
      to { opacity: 1; transform: translateX(0); }
    }

    .category-grid { display: flex; flex-wrap: wrap; gap: 24px; margin-bottom: 50px; }
    .category-item { display: flex; flex-direction: column; align-items: center; gap: 12px; cursor: pointer; width: 90px; transition: all 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275); opacity: 0; animation: scaleUp 0.5s forwards; }
    .category-item:nth-child(1) { animation-delay: 0.1s; }
    .category-item:nth-child(2) { animation-delay: 0.2s; }
    .category-item:nth-child(3) { animation-delay: 0.3s; }
    .category-item:nth-child(4) { animation-delay: 0.4s; }
    .category-item:nth-child(5) { animation-delay: 0.5s; }
    
    @keyframes scaleUp {
      from { opacity: 0; transform: scale(0.8) translateY(20px); }
      to { opacity: 1; transform: scale(1) translateY(0); }
    }

    .category-item:hover { transform: translateY(-8px) scale(1.05); }
    .cat-icon-box { width: 72px; height: 72px; border-radius: 22px; border: 1px solid var(--border-color); display: flex; justify-content: center; align-items: center; font-size: 32px; background: var(--card-bg); backdrop-filter: blur(10px); box-shadow: var(--glass-shadow); transition: all 0.3s ease; }
    .category-item:hover .cat-icon-box { box-shadow: var(--shadow-md); border-color: currentColor; }
    .cat-name { font-size: 14px; color: var(--text-secondary); font-weight: 600; }
    
    /* Storage Bar */
    .storage-container { opacity: 0; animation: fadeUp 0.6s 0.6s forwards; }
    @keyframes fadeUp { from { opacity: 0; transform: translateY(20px); } to { opacity: 1; transform: translateY(0); } }
    .storage-header { display: flex; justify-content: space-between; margin-bottom: 12px; font-size: 14px; font-weight: 600; color: var(--text-secondary); }
    .storage-bar-wrapper { background: var(--card-bg); border: 1px solid var(--border-color); height: 24px; border-radius: 12px; overflow: hidden; position: relative; box-shadow: inset 0 2px 4px rgba(0,0,0,0.05); }
    .storage-bar-fill { background: linear-gradient(90deg, #F59E0B, #EF4444); height: 100%; width: 45%; border-radius: 12px; position: relative; overflow: hidden; }
    .storage-bar-fill::after { content: ''; position: absolute; top: 0; left: 0; bottom: 0; right: 0; background: linear-gradient(90deg, rgba(255,255,255,0) 0%, rgba(255,255,255,0.3) 50%, rgba(255,255,255,0) 100%); animation: shimmer 2s infinite; }
    @keyframes shimmer { 0% { transform: translateX(-100%); } 100% { transform: translateX(100%); } }

    /* Explorer View */
    .breadcrumb { display: flex; align-items: center; gap: 10px; margin-bottom: 30px; padding: 16px 24px; background: var(--card-bg); backdrop-filter: blur(10px); border-radius: 16px; font-size: 15px; overflow-x: auto; white-space: nowrap; box-shadow: var(--shadow-sm); border: 1px solid var(--border-color); }
    .breadcrumb-item { cursor: pointer; color: var(--text-secondary); font-weight: 500; transition: color 0.2s; }
    .breadcrumb-item:hover { color: var(--primary); }
    .breadcrumb-item.active { color: var(--text-primary); font-weight: 700; cursor: default; }
    .breadcrumb-separator { opacity: 0.4; color: var(--text-secondary); font-size: 12px; }
    
    .toolbar { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; }
    .btn { border: none; padding: 12px 24px; border-radius: 12px; font-size: 14px; font-weight: 600; cursor: pointer; transition: all 0.3s ease; display: flex; align-items: center; gap: 8px; background: var(--primary); color: white; box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3); font-family: 'Outfit', sans-serif; }
    .btn:hover { background: var(--primary-hover); transform: translateY(-2px); box-shadow: 0 6px 16px rgba(59, 130, 246, 0.4); }
    .btn:active { transform: translateY(0); }
    .btn-secondary { background: var(--card-bg); color: var(--text-primary); border: 1px solid var(--border-color); box-shadow: var(--shadow-sm); }
    .btn-secondary:hover { background: var(--bg-color); border-color: var(--primary); box-shadow: var(--shadow-md); color: var(--primary); }

    .file-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap: 20px; }
    .item { background: var(--card-bg); backdrop-filter: blur(10px); border: 1px solid var(--border-color); border-radius: 20px; padding: 24px 16px; text-align: center; transition: all 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275); cursor: pointer; box-shadow: var(--shadow-sm); position: relative; overflow: hidden; }
    .item::before { content: ''; position: absolute; top: 0; left: 0; right: 0; height: 4px; background: var(--primary); opacity: 0; transition: 0.3s; }
    .item:hover { border-color: var(--primary); box-shadow: var(--shadow-lg); transform: translateY(-6px) scale(1.02); }
    .item:hover::before { opacity: 1; }
    .item-icon { font-size: 42px; margin-bottom: 16px; display: block; transition: transform 0.3s ease; filter: drop-shadow(0 4px 6px rgba(0,0,0,0.05)); }
    .item:hover .item-icon { transform: scale(1.1); }
    .item-name { font-size: 14px; font-weight: 600; width: 100%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; display: block; color: var(--text-primary); margin-bottom: 4px; }
    .item-size { font-size: 12px; color: var(--text-secondary); display: block; font-weight: 500; }
    
    /* Utilities */
    .loading-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.4); backdrop-filter: blur(6px); -webkit-backdrop-filter: blur(6px); display: flex; align-items: center; justify-content: center; z-index: 100; opacity: 0; pointer-events: none; transition: opacity 0.3s ease; }
    .loading-overlay.active { opacity: 1; pointer-events: all; }
    .spinner { width: 44px; height: 44px; border: 4px solid rgba(255,255,255,0.2); border-top-color: #fff; border-radius: 50%; animation: spin 0.8s cubic-bezier(0.4, 0, 0.2, 1) infinite; }
    @keyframes spin { to { transform: rotate(360deg); } }
    
    .toast { position: fixed; bottom: 32px; left: 50%; transform: translateX(-50%) translateY(100px); background: #1E293B; color: white; padding: 14px 28px; border-radius: 100px; font-size: 15px; font-weight: 500; transition: 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275); z-index: 200; box-shadow: 0 10px 40px rgba(0,0,0,0.2); border: 1px solid rgba(255,255,255,0.1); display: flex; align-items: center; gap: 10px; }
    .toast.show { transform: translateX(-50%) translateY(0); }
    .empty-msg { text-align: center; padding: 100px 0; color: var(--text-secondary); font-size: 16px; font-weight: 500; width: 100%; grid-column: 1 / -1; display: flex; flex-direction: column; align-items: center; gap: 16px; }
    .empty-msg-icon { font-size: 48px; opacity: 0.5; }
  </style>
</head>
<body>
  
  <div class="bg-blob blob-1"></div>
  <div class="bg-blob blob-2"></div>

  <div class="sidebar">
    <div class="logo">P</div>
    <div class="nav-item active" id="nav-home" onclick="switchView('home')" title="Home">🏠</div>
    <div class="nav-item" id="nav-explorer" onclick="switchView('explorer'); loadExplorer('');" title="Explorer">📁</div>
    <div class="nav-item" id="nav-shared" onclick="switchView('shared'); loadShared();" title="Shared">📤</div>
  </div>

  <div class="main">
    <div class="topbar">
      <div class="top-icon" id="themeIcon" title="Toggle Theme" onclick="toggleTheme()">🌙</div>
      <div class="top-icon" title="Power Off" onclick="logout()">⏻</div>
    </div>

    <!-- Home View -->
    <div id="homeView" class="content-area active">
      <div class="home-layout">
        <div class="phone-mockup">
          <div class="phone-screen">
            <div class="drop-zone" id="dropZone" onclick="document.getElementById('homeFileInput').click()">
              <div class="drop-icon">✨</div>
              <div class="drop-text">Drag & Drop Files Here</div>
            </div>
            <input type="file" id="homeFileInput" style="display:none" multiple>
          </div>
        </div>
        
        <div class="categories-section">
          <div class="device-info">
            <div>
              <div class="device-name">Pubel Device</div>
              <div class="device-os">Android Storage</div>
            </div>
          </div>
          
          <div class="category-grid">
            <div class="category-item" onclick="openFolder('DCIM')">
              <div class="cat-icon-box" style="color: #EF4444; border-color: rgba(239, 68, 68, 0.2);">🖼️</div>
              <div class="cat-name">Images</div>
            </div>
            <div class="category-item" onclick="openFolder('Movies')">
              <div class="cat-icon-box" style="color: #3B82F6; border-color: rgba(59, 130, 246, 0.2);">🎬</div>
              <div class="cat-name">Video</div>
            </div>
            <div class="category-item" onclick="openFolder('Music')">
              <div class="cat-icon-box" style="color: #F59E0B; border-color: rgba(245, 158, 11, 0.2);">🎵</div>
              <div class="cat-name">Music</div>
            </div>
            <div class="category-item" onclick="openFolder('Documents')">
              <div class="cat-icon-box" style="color: #10B981; border-color: rgba(16, 185, 129, 0.2);">📄</div>
              <div class="cat-name">Docs</div>
            </div>
            <div class="category-item" onclick="switchView('explorer'); loadExplorer('');">
              <div class="cat-icon-box" style="color: #8B5CF6; border-color: rgba(139, 92, 246, 0.2);">📁</div>
              <div class="cat-name">All Files</div>
            </div>
          </div>
          
          <div class="storage-container">
            <div class="storage-header">
              <span>Internal Storage</span>
              <span style="color: #10B981;">Connected</span>
            </div>
            <div class="storage-bar-wrapper">
              <div class="storage-bar-fill"></div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Explorer View -->
    <div id="explorerView" class="content-area">
      <div class="breadcrumb" id="breadcrumb"></div>
      <div class="toolbar">
        <div id="explorerCount" style="color: var(--text-secondary); font-size: 15px; font-weight: 500;">Memuat...</div>
        <div style="display: flex; gap: 12px;">
          <button class="btn btn-secondary" onclick="loadExplorer(currentPath)">🔄 Refresh</button>
          <button class="btn" onclick="document.getElementById('explorerFileInput').click()">📤 Upload</button>
        </div>
        <input type="file" id="explorerFileInput" style="display:none" multiple>
      </div>
      <div class="file-grid" id="explorerGrid"></div>
    </div>

    <!-- Shared View -->
    <div id="sharedView" class="content-area">
      <div class="toolbar">
        <div style="color: var(--text-secondary); font-size: 15px; font-weight: 500;">File yang dipilih dari HP</div>
        <button class="btn btn-secondary" onclick="loadShared()">🔄 Refresh</button>
      </div>
      <div class="file-grid" id="sharedGrid"></div>
    </div>
  </div>

  <div class="loading-overlay" id="loading"><div class="spinner"></div></div>
  <div class="toast" id="toast"></div>

  <script>
    // Theme Management
    function initTheme() {
      const savedTheme = localStorage.getItem('theme');
      const systemDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
      const theme = savedTheme || (systemDark ? 'dark' : 'light');
      document.documentElement.setAttribute('data-theme', theme);
      document.getElementById('themeIcon').textContent = theme === 'dark' ? '☀️' : '🌙';
    }

    function toggleTheme() {
      const current = document.documentElement.getAttribute('data-theme');
      const next = current === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', next);
      localStorage.setItem('theme', next);
      document.getElementById('themeIcon').textContent = next === 'dark' ? '☀️' : '🌙';
    }

    initTheme();

    let currentPath = '';
    const explorerGrid = document.getElementById('explorerGrid');
    const sharedGrid = document.getElementById('sharedGrid');
    const loading = document.getElementById('loading');
    const toast = document.getElementById('toast');

    async function logout() {
      try {
        await fetch('/api/logout', { method: 'POST' });
        window.location.reload();
      } catch (e) {
        window.location.reload();
      }
    }

    function switchView(view) {
      document.querySelectorAll('.nav-item').forEach(el => el.classList.remove('active'));
      document.querySelectorAll('.content-area').forEach(el => el.classList.remove('active'));
      document.getElementById('nav-' + view).classList.add('active');
      document.getElementById(view + 'View').classList.add('active');
    }

    function openFolder(folder) {
      switchView('explorer');
      loadExplorer(folder);
    }

    async function loadExplorer(path) {
      currentPath = path;
      loading.classList.add('active');
      updateBreadcrumb();
      try {
        const res = await fetch('/api/list?path=' + encodeURIComponent(path));
        if (!res.ok) {
           const err = await res.json();
           showToast(err.error || 'Gagal memuat');
           explorerGrid.innerHTML = `<div class="empty-msg"><div class="empty-msg-icon">⚠️</div>Gagal memuat folder. Pastikan izin akses file sudah diberikan.</div>`;
           return;
        }
        const items = await res.json();
        explorerGrid.innerHTML = '';
        document.getElementById('explorerCount').textContent = `\${items.length} items`;
        
        if (items.length === 0) {
          explorerGrid.innerHTML = `<div class="empty-msg"><div class="empty-msg-icon">📭</div>Folder ini kosong</div>`;
        } else {
          items.forEach(item => explorerGrid.appendChild(createItemEl(item)));
        }
      } catch (e) { 
        showToast('Kesalahan memuat data');
        explorerGrid.innerHTML = `<div class="empty-msg"><div class="empty-msg-icon">⚠️</div>Terjadi kesalahan koneksi.</div>`;
      } finally {
        loading.classList.remove('active');
      }
    }

    async function loadShared() {
      loading.classList.add('active');
      try {
        const res = await fetch('/api/shared');
        const items = await res.json();
        sharedGrid.innerHTML = '';
        if (items.length === 0) {
          sharedGrid.innerHTML = `<div class="empty-msg"><div class="empty-msg-icon">📱</div>Belum ada file dipilih dari HP</div>`;
        } else {
          items.forEach(item => sharedGrid.appendChild(createItemEl(item)));
        }
      } catch (e) { showToast('Gagal memuat data'); }
      finally { loading.classList.remove('active'); }
    }

    function createItemEl(item) {
      const div = document.createElement('div');
      div.className = 'item';
      let icon = item.isDir ? '📁' : '📄';
      if (!item.isDir) {
        const ext = item.name.split('.').pop().toLowerCase();
        if (['jpg','jpeg','png','gif','webp'].includes(ext)) icon = '🖼️';
        else if (['mp4','mkv','mov'].includes(ext)) icon = '🎬';
        else if (['mp3','wav','m4a'].includes(ext)) icon = '🎵';
      }
      const sizeStr = item.isDir ? '' : (item.size > 1048576 ? (item.size/1048576).toFixed(1)+' MB' : (item.size/1024).toFixed(1)+' KB');
      div.innerHTML = `<span class="item-icon">\${icon}</span><span class="item-name">\${item.name}</span><span class="item-size">\${sizeStr}</span>`;
      div.onclick = () => {
        if (item.isDir) loadExplorer(item.path);
        else window.location.href = '/api/download?path=' + encodeURIComponent(item.path);
      };
      return div;
    }

    function updateBreadcrumb() {
      const b = document.getElementById('breadcrumb');
      b.innerHTML = `<span class="breadcrumb-item" onclick="loadExplorer('')">Internal Storage</span>`;
      if (!currentPath) { b.querySelector('.breadcrumb-item').classList.add('active'); return; }
      let pathAcc = '';
      currentPath.split('/').filter(p=>p).forEach(part => {
        pathAcc += (pathAcc ? '/' : '') + part;
        const currentPathCopy = pathAcc;
        b.innerHTML += ` <span class="breadcrumb-separator">/</span> <span class="breadcrumb-item" onclick="loadExplorer('\${currentPathCopy}')">\${part}</span>`;
      });
      b.querySelector('.breadcrumb-item:last-child').classList.add('active');
    }

    function showToast(msg) {
      toast.innerHTML = `<span>\${msg}</span>`;
      toast.classList.add('show');
      setTimeout(() => toast.classList.remove('show'), 3000);
    }

    async function handleUpload(files, targetPath) {
      if (!files.length) return;
      loading.classList.add('active');
      for (const file of files) {
        const formData = new FormData();
        formData.append('file', file);
        try {
          await fetch('/api/upload?path=' + encodeURIComponent(targetPath), { method: 'POST', body: formData });
        } catch(e) { showToast('Gagal upload: ' + file.name); }
      }
      loading.classList.remove('active');
      showToast(`Berhasil mengunggah \${files.length} file ✨`);
      if (document.getElementById('explorerView').classList.contains('active')) {
        loadExplorer(currentPath);
      }
    }

    document.getElementById('explorerFileInput').onchange = (e) => handleUpload(e.target.files, currentPath);
    document.getElementById('homeFileInput').onchange = (e) => handleUpload(e.target.files, '');

    const dropZone = document.getElementById('dropZone');
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
      dropZone.addEventListener(eventName, preventDefaults, false);
    });
    function preventDefaults(e) { e.preventDefault(); e.stopPropagation(); }
    
    ['dragenter', 'dragover'].forEach(eventName => {
      dropZone.addEventListener(eventName, () => dropZone.classList.add('dragover'), false);
    });
    ['dragleave', 'drop'].forEach(eventName => {
      dropZone.addEventListener(eventName, () => dropZone.classList.remove('dragover'), false);
    });
    
    dropZone.addEventListener('drop', (e) => {
      handleUpload(e.dataTransfer.files, '');
    }, false);

    loadExplorer('');
  </script>
</body>
</html>''';
  }
}
