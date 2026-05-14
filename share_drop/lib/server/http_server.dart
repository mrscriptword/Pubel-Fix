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
    return '''<!DOCTYPE html>
<html lang="id" data-theme="light">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Pubel — File Transfer</title>
<link href="https://fonts.googleapis.com/css2?family=DM+Mono:wght@400;500&family=Fraunces:ital,opsz,wght@0,9..144,300;0,9..144,600;1,9..144,300&family=DM+Sans:wght@300;400;500;600&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@tabler/icons-webfont@latest/dist/tabler-icons.min.css">
<style>
:root {
  --bg: #F5F3EE;
  --surface: #FDFCFA;
  --surface2: #EFEDE8;
  --border: rgba(0,0,0,0.08);
  --border2: rgba(0,0,0,0.15);
  --text: #1A1814;
  --muted: #7A7770;
  --accent: #2D5BE3;
  --accent-soft: #EDF0FD;
  --accent-text: #1A3BA8;
  --green: #1A7A4A;
  --green-soft: #E8F5EE;
  --amber: #B85C0A;
  --amber-soft: #FDF2E8;
  --red: #B82020;
  --red-soft: #FDE8E8;
  --sidebar-w: 220px;
  --topbar-h: 56px;
  --r: 10px;
  --r-sm: 6px;
}
[data-theme="dark"] {
  --bg: #111009;
  --surface: #1C1A14;
  --surface2: #252318;
  --border: rgba(255,255,255,0.07);
  --border2: rgba(255,255,255,0.14);
  --text: #F0EDE6;
  --muted: #7A7770;
  --accent: #4E7BF0;
  --accent-soft: #1A2240;
  --accent-text: #A3BAFB;
  --green: #34C77A;
  --green-soft: #0E2A1C;
  --amber: #F59B3D;
  --amber-soft: #2A1A08;
  --red: #F06060;
  --red-soft: #2A0E0E;
}

*{margin:0;padding:0;box-sizing:border-box;outline:none;}
body{font-family:'DM Sans',sans-serif;background:var(--bg);color:var(--text);min-height:100vh;display:flex;transition:background .3s,color .3s;}

/* SIDEBAR */
.sidebar{width:var(--sidebar-w);background:var(--surface);border-right:1px solid var(--border);display:flex;flex-direction:column;padding:0;position:relative;z-index:10;flex-shrink:0;}
.sidebar-header{padding:20px 20px 0;border-bottom:1px solid var(--border);padding-bottom:16px;}
.brand{display:flex;align-items:center;gap:10px;margin-bottom:0;}
.brand-icon{width:32px;height:32px;background:var(--text);border-radius:8px;display:flex;align-items:center;justify-content:center;flex-shrink:0;}
.brand-icon i{color:var(--bg);font-size:18px;}
.brand-name{font-family:'Fraunces',serif;font-size:20px;font-weight:600;letter-spacing:-0.5px;color:var(--text);}
.brand-tag{font-size:11px;color:var(--muted);font-weight:400;font-family:'DM Mono',monospace;letter-spacing:0.02em;}

.nav-section{padding:16px 12px;flex:1;}
.nav-label{font-size:10px;font-weight:500;color:var(--muted);letter-spacing:0.08em;text-transform:uppercase;padding:0 8px;margin-bottom:6px;}
.nav-item{display:flex;align-items:center;gap:10px;padding:8px 10px;border-radius:var(--r-sm);cursor:pointer;color:var(--muted);font-size:14px;font-weight:400;transition:all .2s;margin-bottom:2px;position:relative;}
.nav-item:hover{background:var(--surface2);color:var(--text);}
.nav-item.active{background:var(--accent-soft);color:var(--accent-text);font-weight:500;}
.nav-item.active i{color:var(--accent);}
.nav-item i{font-size:17px;width:20px;text-align:center;}
.nav-badge{margin-left:auto;background:var(--accent);color:#fff;font-size:10px;font-weight:500;padding:1px 6px;border-radius:20px;font-family:'DM Mono',monospace;}

.sidebar-footer{padding:14px 12px;border-top:1px solid var(--border);}
.device-pill{display:flex;align-items:center;gap:8px;padding:10px 12px;background:var(--surface2);border-radius:var(--r-sm);cursor:pointer;transition:background .2s;}
.device-pill:hover{background:var(--border);}
.device-dot{width:6px;height:6px;background:var(--green);border-radius:50%;flex-shrink:0;box-shadow:0 0 0 2px var(--green-soft);}
.device-name{font-size:13px;font-weight:500;flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}
.device-sub{font-size:11px;color:var(--muted);font-family:'DM Mono',monospace;}

/* MAIN */
.main{flex:1;display:flex;flex-direction:column;overflow:hidden;}
.topbar{height:var(--topbar-h);border-bottom:1px solid var(--border);display:flex;align-items:center;padding:0 28px;gap:12px;background:var(--surface);}
.topbar-title{font-family:'Fraunces',serif;font-size:15px;font-weight:300;font-style:italic;color:var(--muted);flex:1;}
.topbar-search{display:flex;align-items:center;gap:8px;background:var(--surface2);border:1px solid var(--border);border-radius:var(--r-sm);padding:6px 12px;width:220px;transition:border .2s;}
.topbar-search:focus-within{border-color:var(--border2);}
.topbar-search i{color:var(--muted);font-size:15px;}
.topbar-search input{background:none;border:none;font-size:13px;color:var(--text);width:100%;font-family:'DM Sans',sans-serif;}
.topbar-search input::placeholder{color:var(--muted);}
.topbar-btn{width:34px;height:34px;border-radius:var(--r-sm);background:var(--surface2);border:1px solid var(--border);display:flex;align-items:center;justify-content:center;cursor:pointer;color:var(--muted);transition:all .2s;}
.topbar-btn:hover{background:var(--border);color:var(--text);}
.topbar-btn i{font-size:17px;}

/* CONTENT */
.content{flex:1;overflow-y:auto;padding:28px;display:none;opacity:0;}
.content.active{display:block;animation:fadeUp .35s ease forwards;}
@keyframes fadeUp{from{opacity:0;transform:translateY(16px)}to{opacity:1;transform:translateY(0)}}

/* HOME */
.home-grid{display:grid;grid-template-columns:1fr 320px;gap:24px;max-width:1100px;}
.section-label{font-size:11px;font-weight:500;color:var(--muted);letter-spacing:0.08em;text-transform:uppercase;margin-bottom:14px;}

/* DROP ZONE */
.drop-card{background:var(--surface);border:1px solid var(--border);border-radius:var(--r);overflow:hidden;}
.drop-area{border:2px dashed var(--border2);border-radius:var(--r-sm);margin:20px;padding:48px 24px;text-align:center;cursor:pointer;transition:all .3s;position:relative;}
.drop-area:hover,.drop-area.over{border-color:var(--accent);background:var(--accent-soft);}
.drop-area:hover .drop-icon-wrap,.drop-area.over .drop-icon-wrap{transform:translateY(-4px);}
.drop-icon-wrap{transition:transform .3s;margin-bottom:16px;}
.drop-icon-wrap i{font-size:40px;color:var(--muted);}
.drop-area:hover .drop-icon-wrap i,.drop-area.over .drop-icon-wrap i{color:var(--accent);}
.drop-heading{font-family:'Fraunces',serif;font-size:20px;font-weight:300;color:var(--text);margin-bottom:4px;}
.drop-sub{font-size:13px;color:var(--muted);}
.drop-sub span{color:var(--accent-text);font-weight:500;cursor:pointer;}
.drop-divider{display:flex;align-items:center;gap:12px;margin:0 20px;color:var(--muted);font-size:12px;}
.drop-divider::before,.drop-divider::after{content:'';flex:1;height:1px;background:var(--border);}
.recent-files{padding:16px 20px 20px;}
.recent-row{display:flex;align-items:center;gap:12px;padding:8px 0;border-bottom:1px solid var(--border);}
.recent-row:last-child{border:none;}
.file-thumb{width:36px;height:36px;background:var(--surface2);border-radius:var(--r-sm);display:flex;align-items:center;justify-content:center;flex-shrink:0;}
.file-thumb i{font-size:18px;}
.fi-img{color:#D84040;} .fi-vid{color:#3B82F6;} .fi-doc{color:#10B981;} .fi-mus{color:#F59E0B;} .fi-zip{color:#8B5CF6;}
.file-info{flex:1;min-width:0;}
.file-fname{font-size:13px;font-weight:500;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}
.file-meta{font-size:11px;color:var(--muted);font-family:'DM Mono',monospace;}
.file-action{color:var(--muted);cursor:pointer;transition:color .2s;font-size:16px;}
.file-action:hover{color:var(--text);}

/* STATS */
.stats-col{display:flex;flex-direction:column;gap:16px;}
.stat-card{background:var(--surface);border:1px solid var(--border);border-radius:var(--r);padding:18px 20px;}
.stat-top{display:flex;align-items:flex-start;justify-content:space-between;margin-bottom:12px;}
.stat-title{font-size:11px;font-weight:500;color:var(--muted);letter-spacing:0.06em;text-transform:uppercase;}
.stat-icon{width:30px;height:30px;border-radius:var(--r-sm);display:flex;align-items:center;justify-content:center;}
.stat-icon.green{background:var(--green-soft);color:var(--green);}
.stat-icon.amber{background:var(--amber-soft);color:var(--amber);}
.stat-icon.accent{background:var(--accent-soft);color:var(--accent);}
.stat-icon i{font-size:16px;}
.stat-val{font-family:'Fraunces',serif;font-size:32px;font-weight:600;letter-spacing:-1px;line-height:1;}
.stat-sub{font-size:12px;color:var(--muted);margin-top:4px;}

.storage-card{background:var(--surface);border:1px solid var(--border);border-radius:var(--r);padding:18px 20px;}
.storage-bar-bg{height:6px;background:var(--surface2);border-radius:3px;overflow:hidden;margin:12px 0 8px;}
.storage-bar-fill{height:100%;border-radius:3px;background:linear-gradient(90deg,var(--amber),var(--red));width:45%;}
.storage-nums{display:flex;justify-content:space-between;font-size:11px;color:var(--muted);font-family:'DM Mono',monospace;}

.category-grid{display:grid;grid-template-columns:repeat(2,1fr);gap:8px;}
.cat-item{background:var(--surface2);border-radius:var(--r-sm);padding:12px;cursor:pointer;transition:all .2s;display:flex;align-items:center;gap:10px;}
.cat-item:hover{background:var(--border);transform:translateY(-1px);}
.cat-dot{width:8px;height:8px;border-radius:50%;flex-shrink:0;}
.cat-nm{font-size:13px;font-weight:500;}
.cat-sz{font-size:11px;color:var(--muted);font-family:'DM Mono',monospace;margin-top:1px;}

/* EXPLORER */
.explorer-header{display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;}
.breadcrumb{display:flex;align-items:center;gap:6px;font-size:13px;color:var(--muted);}
.breadcrumb span{cursor:pointer;transition:color .2s;}
.breadcrumb span:hover,.breadcrumb span.active{color:var(--text);}
.breadcrumb i{font-size:12px;}
.explorer-actions{display:flex;gap:8px;}
.btn{display:flex;align-items:center;gap:6px;padding:7px 14px;border-radius:var(--r-sm);font-size:13px;font-weight:500;cursor:pointer;transition:all .2s;border:1px solid var(--border);background:var(--surface);color:var(--text);font-family:'DM Sans',sans-serif;}
.btn:hover{background:var(--surface2);}
.btn.primary{background:var(--accent);color:#fff;border-color:var(--accent);}
.btn.primary:hover{opacity:.9;}
.btn i{font-size:15px;}

.view-toggle{display:flex;background:var(--surface2);border-radius:var(--r-sm);padding:3px;gap:2px;}
.view-btn{width:28px;height:28px;display:flex;align-items:center;justify-content:center;border-radius:4px;cursor:pointer;color:var(--muted);transition:all .2s;}
.view-btn.active{background:var(--surface);color:var(--text);}
.view-btn i{font-size:16px;}

.file-table{width:100%;border-collapse:collapse;}
.file-table th{font-size:11px;font-weight:500;color:var(--muted);letter-spacing:0.06em;text-transform:uppercase;padding:8px 12px;text-align:left;border-bottom:1px solid var(--border);}
.file-table td{padding:10px 12px;border-bottom:1px solid var(--border);font-size:13px;vertical-align:middle;}
.file-table tr:last-child td{border:none;}
.file-table tr:hover td{background:var(--surface2);}
.file-table .f-name{display:flex;align-items:center;gap:10px;}
.f-icon{width:32px;height:32px;background:var(--surface2);border-radius:var(--r-sm);display:flex;align-items:center;justify-content:center;flex-shrink:0;}
.f-icon i{font-size:17px;}
.f-nm{font-weight:500;}
.f-sz,.f-date{color:var(--muted);font-family:'DM Mono',monospace;font-size:12px;}
.f-actions{display:flex;gap:4px;opacity:0;transition:opacity .2s;}
.file-table tr:hover .f-actions{opacity:1;}
.f-act-btn{width:28px;height:28px;border-radius:var(--r-sm);display:flex;align-items:center;justify-content:center;cursor:pointer;color:var(--muted);transition:all .2s;}
.f-act-btn:hover{background:var(--border);color:var(--text);}
.f-act-btn i{font-size:15px;}

.status-badge{display:inline-flex;align-items:center;gap:4px;padding:2px 8px;border-radius:20px;font-size:11px;font-weight:500;}
.badge-sent{background:var(--green-soft);color:var(--green);}
.badge-ready{background:var(--accent-soft);color:var(--accent-text);}

/* SHARED VIEW */
.share-empty{display:flex;flex-direction:column;align-items:center;justify-content:center;padding:80px 40px;text-align:center;}
.share-empty i{font-size:48px;color:var(--border2);margin-bottom:20px;}
.share-empty h3{font-family:'Fraunces',serif;font-size:22px;font-weight:300;margin-bottom:8px;}
.share-empty p{font-size:14px;color:var(--muted);max-width:280px;}

/* TOAST */
.toast{position:fixed;bottom:24px;left:50%;transform:translateX(-50%) translateY(80px);background:var(--text);color:var(--bg);padding:10px 20px;border-radius:100px;font-size:13px;font-weight:500;transition:.35s cubic-bezier(.16,1,.3,1);z-index:999;pointer-events:none;}
.toast.show{transform:translateX(-50%) translateY(0);}

.tag{display:inline-block;padding:2px 7px;background:var(--surface2);border-radius:4px;font-size:11px;color:var(--muted);font-family:'DM Mono',monospace;}
</style>
</head>
<body>

<div class="sidebar">
  <div class="sidebar-header">
    <div class="brand">
      <div class="brand-icon"><i class="ti ti-arrows-transfer-up"></i></div>
      <div>
        <div class="brand-name">Pubel</div>
        <div class="brand-tag">v2.0 / browser</div>
      </div>
    </div>
  </div>

  <div class="nav-section">
    <div class="nav-label">Menu</div>
    <div class="nav-item active" id="nav-home" onclick="switchView('home')">
      <i class="ti ti-home"></i> Beranda
    </div>
    <div class="nav-item" id="nav-explorer" onclick="switchView('explorer');loadExplorer('')">
      <i class="ti ti-folder"></i> File Explorer
    </div>
    <div class="nav-item" id="nav-shared" onclick="switchView('shared');loadShared()">
      <i class="ti ti-share"></i> Dikirim <span class="nav-badge">3</span>
    </div>

    <div class="nav-label" style="margin-top:20px;">Kategori</div>
    <div class="nav-item" onclick="openFolder('Images')"><i class="ti ti-photo fi-img"></i> Gambar</div>
    <div class="nav-item" onclick="openFolder('Videos')"><i class="ti ti-video fi-vid"></i> Video</div>
    <div class="nav-item" onclick="openFolder('Music')"><i class="ti ti-music fi-mus"></i> Musik</div>
    <div class="nav-item" onclick="openFolder('Docs')"><i class="ti ti-file-text fi-doc"></i> Dokumen</div>
  </div>

  <div class="sidebar-footer">
    <div class="device-pill">
      <div class="device-dot"></div>
      <div>
        <div class="device-name">Pubel Preview</div>
        <div class="device-sub">Demo Mode</div>
      </div>
    </div>
  </div>
</div>

<div class="main">
  <div class="topbar">
    <span class="topbar-title">File Sharing</span>
    <div class="topbar-search">
      <i class="ti ti-search"></i>
      <input type="text" placeholder="Cari file...">
    </div>
    <div class="topbar-btn" onclick="toggleTheme()" id="themeBtn" title="Ganti tema"><i class="ti ti-moon" id="themeIcon"></i></div>
    <div class="topbar-btn" onclick="showToast('Logout...')" title="Keluar"><i class="ti ti-power"></i></div>
  </div>

  <!-- HOME -->
  <div id="homeView" class="content active">
    <div class="home-grid">
      <div>
        <div class="section-label">Upload File</div>
        <div class="drop-card">
          <div class="drop-area" id="dropZone"
            ondragover="e=>{e.preventDefault();this.classList.add('over')}"
            ondragleave="this.classList.remove('over')"
            ondrop="e=>{e.preventDefault();this.classList.remove('over');showToast('File diterima!')}">
            <div class="drop-icon-wrap"><i class="ti ti-cloud-upload"></i></div>
            <div class="drop-heading">Seret file ke sini</div>
            <div class="drop-sub">atau <span onclick="showToast('Buka file picker...')">pilih dari komputer</span></div>
          </div>
          <div class="drop-divider">file terakhir</div>
          <div class="recent-files">
            <div class="recent-row">
              <div class="file-thumb"><i class="ti ti-photo fi-img"></i></div>
              <div class="file-info">
                <div class="file-fname">Pantai Sunset.jpg</div>
                <div class="file-meta">2.4 MB · 2 menit lalu</div>
              </div>
              <i class="ti ti-dots-vertical file-action"></i>
            </div>
            <div class="recent-row">
              <div class="file-thumb"><i class="ti ti-file-type-pdf fi-doc"></i></div>
              <div class="file-info">
                <div class="file-fname">Presentasi Q4.pdf</div>
                <div class="file-meta">1.1 MB · 1 jam lalu</div>
              </div>
              <i class="ti ti-dots-vertical file-action"></i>
            </div>
            <div class="recent-row">
              <div class="file-thumb"><i class="ti ti-movie fi-vid"></i></div>
              <div class="file-info">
                <div class="file-fname">Teaser Video.mp4</div>
                <div class="file-meta">15.8 MB · kemarin</div>
              </div>
              <i class="ti ti-dots-vertical file-action"></i>
            </div>
          </div>
        </div>
      </div>

      <div class="stats-col">
        <div class="section-label">Ringkasan</div>

        <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
          <div class="stat-card">
            <div class="stat-top">
              <div class="stat-title">Terkirim</div>
              <div class="stat-icon green"><i class="ti ti-arrow-up"></i></div>
            </div>
            <div class="stat-val">24</div>
            <div class="stat-sub">file bulan ini</div>
          </div>
          <div class="stat-card">
            <div class="stat-top">
              <div class="stat-title">Diterima</div>
              <div class="stat-icon accent"><i class="ti ti-arrow-down"></i></div>
            </div>
            <div class="stat-val">9</div>
            <div class="stat-sub">file bulan ini</div>
          </div>
        </div>

        <div class="storage-card">
          <div class="stat-top" style="margin-bottom:0;">
            <div class="stat-title">Penyimpanan</div>
            <div class="stat-icon amber"><i class="ti ti-database"></i></div>
          </div>
          <div class="storage-bar-bg"><div class="storage-bar-fill"></div></div>
          <div class="storage-nums"><span>22.4 GB digunakan</span><span>50 GB total</span></div>
        </div>

        <div class="stat-card">
          <div class="section-label" style="margin-bottom:10px;">Kategori</div>
          <div class="category-grid">
            <div class="cat-item" onclick="openFolder('Images')">
              <div class="cat-dot" style="background:#D84040;"></div>
              <div><div class="cat-nm">Gambar</div><div class="cat-sz">8.2 GB</div></div>
            </div>
            <div class="cat-item" onclick="openFolder('Videos')">
              <div class="cat-dot" style="background:#3B82F6;"></div>
              <div><div class="cat-nm">Video</div><div class="cat-sz">11.1 GB</div></div>
            </div>
            <div class="cat-item" onclick="openFolder('Music')">
              <div class="cat-dot" style="background:#F59E0B;"></div>
              <div><div class="cat-nm">Musik</div><div class="cat-sz">1.4 GB</div></div>
            </div>
            <div class="cat-item" onclick="openFolder('Docs')">
              <div class="cat-dot" style="background:#10B981;"></div>
              <div><div class="cat-nm">Dokumen</div><div class="cat-sz">1.7 GB</div></div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- EXPLORER -->
  <div id="explorerView" class="content">
    <div class="explorer-header">
      <div>
        <div class="breadcrumb" id="breadcrumb">
          <span onclick="loadExplorer('')">Internal Storage</span>
          <i class="ti ti-chevron-right"></i>
          <span class="active" id="breadcrumb-cur">Root</span>
        </div>
      </div>
      <div class="explorer-actions">
        <div class="view-toggle">
          <div class="view-btn active" title="List"><i class="ti ti-list"></i></div>
          <div class="view-btn" title="Grid"><i class="ti ti-layout-grid"></i></div>
        </div>
        <div class="btn" onclick="loadExplorer('');showToast('Diperbarui')"><i class="ti ti-refresh"></i> Segarkan</div>
        <div class="btn primary" onclick="showToast('Pilih file...')"><i class="ti ti-upload"></i> Upload</div>
      </div>
    </div>

    <table class="file-table" id="fileTable">
      <thead>
        <tr>
          <th>Nama</th>
          <th>Ukuran</th>
          <th>Diubah</th>
          <th>Status</th>
          <th></th>
        </tr>
      </thead>
      <tbody id="explorerBody"></tbody>
    </table>
  </div>

  <!-- SHARED -->
  <div id="sharedView" class="content">
    <div id="sharedContent"></div>
  </div>
</div>

<div class="toast" id="toast"></div>

<script>
    let currentPath = '';
    const explorerBody = document.getElementById('explorerBody');
    const sharedContent = document.getElementById('sharedContent');
    const toast = document.getElementById('toast');

    async function logout() {
      try {
        await fetch('/api/logout', { method: 'POST' });
        window.location.reload();
      } catch (e) { window.location.reload(); }
    }

    function switchView(view) {
      document.querySelectorAll('.nav-item').forEach(el => el.classList.remove('active'));
      document.querySelectorAll('.content').forEach(el => el.classList.remove('active'));
      const navItem = document.getElementById('nav-' + view);
      if (navItem) navItem.classList.add('active');
      const viewEl = document.getElementById(view + 'View');
      if (viewEl) viewEl.classList.add('active');
    }

    function openFolder(folder) {
      switchView('explorer');
      loadExplorer(folder);
    }

    function getFileIcon(name, isDir) {
      if (isDir) return { icon: 'ti-folder', cls: '' };
      const ext = name.split('.').pop().toLowerCase();
      if (['jpg','jpeg','png','gif','webp'].includes(ext)) return { icon: 'ti-photo', cls: 'fi-img' };
      if (['mp4','mkv','mov'].includes(ext)) return { icon: 'ti-video', cls: 'fi-vid' };
      if (['mp3','wav','m4a'].includes(ext)) return { icon: 'ti-music', cls: 'fi-mus' };
      if (['pdf','doc','docx','txt'].includes(ext)) return { icon: 'ti-file-text', cls: 'fi-doc' };
      if (['zip','rar','7z'].includes(ext)) return { icon: 'ti-file-zip', cls: 'fi-zip' };
      return { icon: 'ti-file', cls: '' };
    }

    async function loadExplorer(path) {
      currentPath = path;
      updateBreadcrumb();
      try {
        const res = await fetch('/api/list?path=' + encodeURIComponent(path));
        if (!res.ok) {
           explorerBody.innerHTML = '<tr><td colspan="5" style="text-align:center;padding:40px;">⚠️ Gagal memuat folder.</td></tr>';
           return;
        }
        const items = await res.json();
        explorerBody.innerHTML = '';
        const countEl = document.getElementById('explorerCount');
        if (countEl) countEl.textContent = items.length + ' items';
        if (items.length === 0) {
          explorerBody.innerHTML = '<tr><td colspan="5" style="text-align:center;padding:40px;color:var(--muted);">Folder ini kosong</td></tr>';
        } else {
          items.forEach(item => {
            const tr = document.createElement('tr');
            const info = getFileIcon(item.name, item.isDir);
            const sizeStr = item.isDir ? '--' : (item.size > 1048576 ? (item.size/1048576).toFixed(1)+' MB' : (item.size/1024).toFixed(1)+' KB');
            tr.innerHTML = `<td><div class="f-name"><div class="f-icon"><i class="ti \${info.icon} \${info.cls}"></i></div><div><div class="f-nm">\${item.name}</div></div></div></td><td><span class="f-sz">\${sizeStr}</span></td><td><span class="f-date">--</span></td><td><span class="status-badge badge-ready">Siap</span></td><td><div class="f-actions"><div class="f-act-btn" title="Download"><i class="ti ti-download"></i></div></div></td>`;
            tr.onclick = (e) => {
              if (e.target.closest('.f-act-btn')) return;
              if (item.isDir) loadExplorer(item.path);
              else window.location.href = '/api/download?path=' + encodeURIComponent(item.path);
            };
            tr.querySelector('.f-act-btn').onclick = () => window.location.href = '/api/download?path=' + encodeURIComponent(item.path);
            explorerBody.appendChild(tr);
          });
        }
      } catch (e) { showToast('Kesalahan memuat data'); }
    }

    async function loadShared() {
      try {
        const res = await fetch('/api/shared');
        const items = await res.json();
        sharedContent.innerHTML = '';
        if (items.length === 0) {
          sharedContent.innerHTML = `<div class="share-empty"><i class="ti ti-send"></i><h3>Belum ada file dikirim</h3><p>File yang kamu bagikan dari HP akan muncul di sini.</p></div>`;
        } else {
           let html = `<div class="section-label">File Terkirim (\${items.length})</div><table class="file-table"><thead><tr><th>Nama</th><th>Ukuran</th><th>Aksi</th></tr></thead><tbody>`;
           items.forEach(item => {
             const info = getFileIcon(item.name, false);
             const sizeStr = (item.size > 1048576 ? (item.size/1048576).toFixed(1)+' MB' : (item.size/1024).toFixed(1)+' KB');
             html += `<tr><td><div class="f-name"><div class="f-icon"><i class="ti \${info.icon} \${info.cls}"></i></div><div class="f-nm">\${item.name}</div></div></td><td><span class="f-sz">\${sizeStr}</span></td><td><div class="f-actions" style="opacity:1;"><div class="f-act-btn" onclick="window.location.href='/api/download?path='+encodeURIComponent('\${item.path}')"><i class="ti ti-download"></i></div></div></td></tr>`;
           });
           html += '</tbody></table>';
           sharedContent.innerHTML = html;
        }
      } catch (e) { showToast('Gagal memuat data'); }
    }

    function updateBreadcrumb() {
      const b = document.getElementById('breadcrumb');
      const cur = document.getElementById('breadcrumb-cur');
      if (!b || !cur) return;
      b.innerHTML = `<span onclick="loadExplorer('')">Internal Storage</span>`;
      if (!currentPath) { cur.textContent = 'Root'; return; }
      let pathAcc = '';
      currentPath.split('/').filter(p=>p).forEach(part => {
        pathAcc += (pathAcc ? '/' : '') + part;
        const currentPathCopy = pathAcc;
        b.innerHTML += ` <i class="ti ti-chevron-right"></i> <span onclick="loadExplorer('\${currentPathCopy}')">\${part}</span>`;
      });
      cur.textContent = currentPath.split('/').pop();
    }

    function toggleTheme() {
      const d = document.documentElement;
      const next = d.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
      d.setAttribute('data-theme', next);
      localStorage.setItem('theme', next);
      const icon = document.getElementById('themeIcon');
      if (icon) icon.className = next === 'dark' ? 'ti ti-sun' : 'ti ti-moon';
    }

    let toastTimer;
    function showToast(msg) {
      if (!toast) return;
      toast.textContent = msg; toast.classList.add('show');
      clearTimeout(toastTimer); toastTimer = setTimeout(() => toast.classList.remove('show'), 3000);
    }

    async function handleUpload(files, targetPath) {
      if (!files.length) return;
      showToast('Sedang mengunggah...');
      for (const file of files) {
        const formData = new FormData();
        formData.append('file', file);
        try { await fetch('/api/upload?path=' + encodeURIComponent(targetPath), { method: 'POST', body: formData }); } catch(e) {}
      }
      showToast('Upload selesai ✨');
      if (document.getElementById('explorerView').classList.contains('active')) loadExplorer(currentPath);
    }

    const savedTheme = localStorage.getItem('theme') || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    document.documentElement.setAttribute('data-theme', savedTheme);
    const icon = document.getElementById('themeIcon');
    if (icon) icon.className = savedTheme === 'dark' ? 'ti ti-sun' : 'ti ti-moon';

    const dropZone = document.getElementById('dropZone');
    if (dropZone) {
      dropZone.onclick = (e) => {
          if (e.target.closest('span')) return; // let the span handle its own if needed
          const input = document.createElement('input'); input.type = 'file'; input.multiple = true;
          input.onchange = (ev) => handleUpload(ev.target.files, currentPath); input.click();
      };
      dropZone.ondragover = (e) => { e.preventDefault(); dropZone.classList.add('over'); };
      dropZone.ondragleave = () => { dropZone.classList.remove('over'); };
      dropZone.ondrop = (e) => { e.preventDefault(); dropZone.classList.remove('over'); handleUpload(e.dataTransfer.files, currentPath); };
    }

    loadExplorer('');
</script>
</body>
</html>
''';
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
</html>
'''

}
