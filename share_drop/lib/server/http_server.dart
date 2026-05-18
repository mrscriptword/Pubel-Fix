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
  final Set<String> _allowedIps = {};

  int get connectedCount => _allowedIps.length;
  Set<String> get connectedIps => Set.unmodifiable(_allowedIps);
  
  final _requestController = StreamController<ConnectionRequest>.broadcast();
  Stream<ConnectionRequest> get onRequest => _requestController.stream;

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

        return Response.ok(jsonEncode({'success': true, 'message': 'Berhasil!'}));
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    final pipeline = const Pipeline()
        .addMiddleware(_authMiddleware)
        .addHandler(app);
        
    _server = await io.serve(pipeline, InternetAddress.anyIPv4, _port);
    return 'http://$_ipAddress:$_port';
  }

  void _triggerApproval(String ip, String userAgent) {
    if (_allowedIps.contains(ip)) return;
    
    final completer = Completer<bool>();
    final request = ConnectionRequest(ip, userAgent, completer);
    _requestController.add(request);
    
    completer.future.then((approved) {
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
  <title>Pubel - Menunggu Izin</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: system-ui, -apple-system, 'Segoe UI', sans-serif; background: #080B1A; color: #fff; display: flex; align-items: center; justify-content: center; min-height: 100vh; }
    .wrap { text-align: center; padding: 20px; max-width: 380px; width: 100%; }
    .ring-container { position: relative; width: 120px; height: 120px; margin: 0 auto 32px; }
    .ring { position: absolute; inset: 0; border-radius: 50%; border: 2px solid rgba(124,77,255,0.15); animation: pulse 2s ease-in-out infinite; }
    .ring:nth-child(2) { inset: 12px; border-color: rgba(124,77,255,0.25); animation-delay: -0.5s; }
    .ring:nth-child(3) { inset: 24px; border-color: rgba(124,77,255,0.35); animation-delay: -1s; }
    .icon-box { position: absolute; inset: 36px; background: linear-gradient(135deg, #7C4DFF, #00B4D8); border-radius: 50%; display: flex; align-items: center; justify-content: center; }
    .spinner { width: 28px; height: 28px; border: 3px solid rgba(255,255,255,0.2); border-top-color: #fff; border-radius: 50%; animation: spin 0.8s linear infinite; }
    @keyframes spin { to { transform: rotate(360deg); } }
    @keyframes pulse { 0%,100% { transform: scale(1); opacity: 1; } 50% { transform: scale(1.08); opacity: 0.6; } }
    h1 { font-size: 22px; font-weight: 800; margin-bottom: 10px; }
    p { color: rgba(255,255,255,0.5); font-size: 14px; line-height: 1.6; }
    .ip-badge { display: inline-block; margin-top: 16px; background: rgba(124,77,255,0.15); border: 1px solid rgba(124,77,255,0.3); border-radius: 20px; padding: 6px 16px; font-size: 13px; color: #B47CFF; font-weight: 600; }
    .dots { margin-top: 20px; }
    .dots span { display: inline-block; width: 7px; height: 7px; border-radius: 50%; background: #7C4DFF; margin: 0 3px; animation: bounce 1.2s ease-in-out infinite; }
    .dots span:nth-child(2) { animation-delay: 0.2s; }
    .dots span:nth-child(3) { animation-delay: 0.4s; }
    @keyframes bounce { 0%,100% { transform: translateY(0); opacity: 0.4; } 50% { transform: translateY(-6px); opacity: 1; } }
  </style>
  <script>
    setInterval(async () => {
      try {
        const r = await fetch('/api/check-auth');
        const d = await r.json();
        if (d.authorized) window.location.reload();
      } catch (e) {}
    }, 2000);
  </script>
</head>
<body>
  <div class="wrap">
    <div class="ring-container">
      <div class="ring"></div>
      <div class="ring"></div>
      <div class="ring"></div>
      <div class="icon-box"><div class="spinner"></div></div>
    </div>
    <h1>Menunggu Izin</h1>
    <p>Buka aplikasi <strong>Pubel</strong> di HP dan ketuk <strong>Izinkan</strong> untuk memberikan akses.</p>
    <div class="ip-badge">IP Anda: $ip</div>
    <div class="dots"><span></span><span></span><span></span></div>
  </div>
</body>
</html>
''';
  }

  String _buildHtmlPage() {
    return '''
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Pubel Browser</title>
  <style>
    *, *::before, *::after { margin: 0; padding: 0; box-sizing: border-box; }
    :root {
      --bg: #080B1A;
      --surface: #111327;
      --card: #181B30;
      --border: rgba(255,255,255,0.07);
      --primary: #7C4DFF;
      --primary-light: #B47CFF;
      --accent: #00B4D8;
      --green: #00E676;
      --text: #FFFFFF;
      --text-muted: rgba(255,255,255,0.45);
      --radius: 16px;
    }
    html { height: 100%; }
    body { font-family: system-ui, -apple-system, 'Segoe UI', sans-serif; background: var(--bg); color: var(--text); min-height: 100%; font-size: 14px; line-height: 1.5; }

    /* Layout */
    .app { max-width: 960px; margin: 0 auto; padding: 28px 20px 60px; }

    /* Header */
    .header { display: flex; align-items: center; gap: 14px; margin-bottom: 28px; }
    .logo { width: 44px; height: 44px; background: linear-gradient(135deg, var(--primary), var(--accent)); border-radius: 12px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; box-shadow: 0 0 20px rgba(124,77,255,0.4); }
    .logo svg { width: 22px; height: 22px; }
    .header-text h1 { font-size: 20px; font-weight: 800; letter-spacing: -0.3px; }
    .header-text p { font-size: 12px; color: var(--text-muted); }
    .status-dot { width: 8px; height: 8px; background: var(--green); border-radius: 50%; box-shadow: 0 0 8px var(--green); display: inline-block; margin-right: 5px; }

    /* Tabs */
    .tabs { display: flex; gap: 6px; background: var(--surface); border: 1px solid var(--border); border-radius: 14px; padding: 5px; margin-bottom: 22px; }
    .tab { flex: 1; text-align: center; padding: 10px 14px; cursor: pointer; border-radius: 10px; font-size: 13px; font-weight: 600; color: var(--text-muted); transition: all 0.2s; user-select: none; }
    .tab.active { background: linear-gradient(135deg, var(--primary), var(--accent)); color: #fff; box-shadow: 0 4px 14px rgba(124,77,255,0.35); }
    .tab:not(.active):hover { background: rgba(255,255,255,0.05); color: var(--text); }

    /* View containers */
    .view { display: none; }
    .view.active { display: block; }

    /* Breadcrumb */
    .breadcrumb { display: flex; align-items: center; gap: 6px; padding: 10px 14px; background: var(--surface); border: 1px solid var(--border); border-radius: 12px; margin-bottom: 16px; overflow-x: auto; white-space: nowrap; scrollbar-width: none; }
    .breadcrumb::-webkit-scrollbar { display: none; }
    .bc-item { font-size: 12px; color: var(--text-muted); cursor: pointer; flex-shrink: 0; transition: color 0.2s; }
    .bc-item:hover, .bc-item.active { color: var(--text); font-weight: 600; }
    .bc-sep { color: rgba(255,255,255,0.15); font-size: 11px; }

    /* Toolbar */
    .toolbar { display: flex; justify-content: space-between; align-items: center; margin-bottom: 18px; flex-wrap: wrap; gap: 10px; }
    .toolbar-left { font-size: 12px; color: var(--text-muted); font-weight: 500; }
    .toolbar-right { display: flex; gap: 8px; }
    .btn { border: none; cursor: pointer; font-size: 12px; font-weight: 700; border-radius: 10px; padding: 9px 16px; display: inline-flex; align-items: center; gap: 6px; transition: all 0.2s; }
    .btn-primary { background: linear-gradient(135deg, var(--primary), var(--accent)); color: #fff; box-shadow: 0 4px 12px rgba(124,77,255,0.3); }
    .btn-primary:hover { transform: translateY(-1px); box-shadow: 0 6px 20px rgba(124,77,255,0.4); }
    .btn-ghost { background: var(--surface); color: var(--text-muted); border: 1px solid var(--border); }
    .btn-ghost:hover { background: var(--card); color: var(--text); }

    /* File Grid */
    .file-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(120px, 1fr)); gap: 12px; }
    .file-item { background: var(--card); border: 1px solid var(--border); border-radius: 14px; padding: 16px 12px; text-align: center; cursor: pointer; transition: all 0.18s; display: flex; flex-direction: column; align-items: center; }
    .file-item:hover { background: rgba(124,77,255,0.08); border-color: rgba(124,77,255,0.3); transform: translateY(-2px); }
    .file-icon { font-size: 34px; margin-bottom: 8px; line-height: 1; }
    .file-name { font-size: 11px; font-weight: 600; width: 100%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: var(--text); }
    .file-size { font-size: 10px; color: var(--text-muted); margin-top: 4px; }

    /* Empty state */
    .empty { text-align: center; padding: 60px 20px; grid-column: 1 / -1; }
    .empty-icon { font-size: 40px; margin-bottom: 12px; opacity: 0.3; }
    .empty p { color: var(--text-muted); font-size: 13px; }

    /* Loading overlay */
    .overlay { position: fixed; inset: 0; background: rgba(8,11,26,0.75); backdrop-filter: blur(6px); display: none; align-items: center; justify-content: center; z-index: 50; }
    .overlay.show { display: flex; }
    .spin { width: 32px; height: 32px; border: 3px solid rgba(255,255,255,0.1); border-top-color: var(--primary); border-radius: 50%; animation: spin 0.75s linear infinite; }
    @keyframes spin { to { transform: rotate(360deg); } }

    /* Toast */
    .toast { position: fixed; bottom: 28px; left: 50%; transform: translateX(-50%) translateY(80px); background: var(--primary); color: #fff; padding: 12px 24px; border-radius: 12px; font-size: 13px; font-weight: 600; box-shadow: 0 10px 30px rgba(0,0,0,0.4); transition: transform 0.35s cubic-bezier(0.175,0.885,0.32,1.275); z-index: 100; white-space: nowrap; }
    .toast.show { transform: translateX(-50%) translateY(0); }

    /* Upload progress */
    .progress-bar { height: 3px; background: rgba(255,255,255,0.1); border-radius: 2px; margin-top: 12px; overflow: hidden; display: none; }
    .progress-bar.show { display: block; }
    .progress-fill { height: 100%; background: linear-gradient(90deg, var(--primary), var(--accent)); border-radius: 2px; transition: width 0.3s; }

    /* Responsive */
    @media (max-width: 480px) {
      .file-grid { grid-template-columns: repeat(auto-fill, minmax(90px, 1fr)); gap: 8px; }
      .header-text h1 { font-size: 17px; }
    }
  </style>
</head>
<body>
  <div class="app">
    <div class="header">
      <div class="logo">
        <svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"/>
          <polyline points="16 6 12 2 8 6"/>
          <line x1="12" y1="2" x2="12" y2="15"/>
        </svg>
      </div>
      <div class="header-text">
        <h1>Pubel Explorer</h1>
        <p><span class="status-dot"></span>Server aktif &amp; siap digunakan</p>
      </div>
    </div>

    <div class="tabs">
      <div class="tab active" id="tab-explorer" onclick="switchTab('explorer')">📂 Explorer</div>
      <div class="tab" id="tab-shared" onclick="switchTab('shared')">📤 File Dibagikan</div>
    </div>

    <!-- Explorer -->
    <div class="view active" id="view-explorer">
      <div class="breadcrumb" id="breadcrumb"></div>
      <div class="toolbar">
        <div class="toolbar-left" id="item-count">Memuat...</div>
        <div class="toolbar-right">
          <button class="btn btn-ghost" onclick="refresh()">↺ Refresh</button>
          <label class="btn btn-primary" style="cursor:pointer;">
            ↑ Upload
            <input type="file" id="fileInput" multiple style="display:none">
          </label>
        </div>
      </div>
      <div id="progress-bar" class="progress-bar"><div class="progress-fill" id="progress-fill" style="width:0%"></div></div>
      <div class="file-grid" id="explorer-grid"></div>
    </div>

    <!-- Shared -->
    <div class="view" id="view-shared">
      <div class="toolbar">
        <div class="toolbar-left">File yang dipilih dari aplikasi HP</div>
        <div class="toolbar-right">
          <button class="btn btn-ghost" onclick="loadShared()">↺ Refresh</button>
        </div>
      </div>
      <div class="file-grid" id="shared-grid"></div>
    </div>
  </div>

  <div class="overlay" id="overlay"><div class="spin"></div></div>
  <div class="toast" id="toast"></div>

  <script>
    let currentPath = '';
    const overlay = document.getElementById('overlay');
    const toast = document.getElementById('toast');

    function switchTab(name) {
      document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
      document.querySelectorAll('.view').forEach(v => v.classList.remove('active'));
      document.getElementById('tab-' + name).classList.add('active');
      document.getElementById('view-' + name).classList.add('active');
      if (name === 'explorer') loadExplorer(currentPath);
      else loadShared();
    }

    function showOverlay() { overlay.classList.add('show'); }
    function hideOverlay() { overlay.classList.remove('show'); }
    function showToast(msg, isError = false) {
      toast.textContent = msg;
      toast.style.background = isError ? '#D32F2F' : 'var(--primary)';
      toast.classList.add('show');
      setTimeout(() => toast.classList.remove('show'), 3000);
    }

    function refresh() { loadExplorer(currentPath); }

    async function loadExplorer(path) {
      currentPath = path;
      showOverlay();
      updateBreadcrumb(path);
      const grid = document.getElementById('explorer-grid');
      const count = document.getElementById('item-count');
      try {
        const res = await fetch('/api/list?path=' + encodeURIComponent(path));
        if (!res.ok) throw new Error(await res.text());
        const items = await res.json();
        grid.innerHTML = '';
        count.textContent = items.length + ' item';
        if (items.length === 0) {
          grid.innerHTML = '<div class="empty"><div class="empty-icon">📭</div><p>Folder ini kosong</p></div>';
        } else {
          items.forEach(item => grid.appendChild(makeItem(item)));
        }
      } catch (e) {
        grid.innerHTML = '<div class="empty"><div class="empty-icon">⚠️</div><p>Gagal memuat. Pastikan izin storage sudah diberikan.</p></div>';
      } finally { hideOverlay(); }
    }

    async function loadShared() {
      showOverlay();
      const grid = document.getElementById('shared-grid');
      try {
        const res = await fetch('/api/shared');
        const items = await res.json();
        grid.innerHTML = '';
        if (items.length === 0) {
          grid.innerHTML = '<div class="empty"><div class="empty-icon">📋</div><p>Belum ada file yang dibagikan dari HP</p></div>';
        } else {
          items.forEach(item => grid.appendChild(makeItem(item)));
        }
      } catch (e) { showToast('Gagal memuat', true); }
      finally { hideOverlay(); }
    }

    function makeItem(item) {
      const div = document.createElement('div');
      div.className = 'file-item';
      const ext = item.name.split('.').pop().toLowerCase();
      let icon = item.isDir ? '📁' : '📄';
      if (!item.isDir) {
        if (['jpg','jpeg','png','gif','webp','bmp','svg'].includes(ext)) icon = '🖼️';
        else if (['mp4','mkv','mov','avi','webm'].includes(ext)) icon = '🎬';
        else if (['mp3','wav','m4a','ogg','flac','aac'].includes(ext)) icon = '🎵';
        else if (['pdf'].includes(ext)) icon = '📕';
        else if (['zip','rar','7z','tar','gz'].includes(ext)) icon = '📦';
        else if (['apk'].includes(ext)) icon = '📱';
        else if (['doc','docx','txt','md'].includes(ext)) icon = '📝';
        else if (['xls','xlsx','csv'].includes(ext)) icon = '📊';
      }
      const size = item.isDir ? '' : (item.size > 1048576
        ? (item.size/1048576).toFixed(1) + ' MB'
        : (item.size/1024).toFixed(0) + ' KB');
      div.innerHTML = \`<div class="file-icon">\${icon}</div><div class="file-name">\${item.name}</div><div class="file-size">\${size}</div>\`;
      div.onclick = () => {
        if (item.isDir) loadExplorer(item.path);
        else window.location.href = '/api/download?path=' + encodeURIComponent(item.path);
      };
      return div;
    }

    function updateBreadcrumb(path) {
      const el = document.getElementById('breadcrumb');
      el.innerHTML = '<span class="bc-item" onclick="loadExplorer(\\'\\')">📱 Internal</span>';
      if (!path) { el.querySelector('.bc-item').classList.add('active'); return; }
      let acc = '';
      path.split('/').filter(Boolean).forEach(part => {
        acc += (acc ? '/' : '') + part;
        const p = acc;
        el.innerHTML += '<span class="bc-sep">/</span><span class="bc-item" onclick="loadExplorer(\\'' + p + '\\')">' + part + '</span>';
      });
      el.querySelector('.bc-item:last-child').classList.add('active');
    }

    // Upload with progress
    document.getElementById('fileInput').onchange = async (e) => {
      const files = Array.from(e.target.files);
      if (!files.length) return;
      const progressBar = document.getElementById('progress-bar');
      const fill = document.getElementById('progress-fill');
      progressBar.classList.add('show');
      let done = 0;
      for (const file of files) {
        const formData = new FormData();
        formData.append('file', file);
        try {
          await fetch('/api/upload?path=' + encodeURIComponent(currentPath), { method: 'POST', body: formData });
          done++;
          fill.style.width = (done / files.length * 100) + '%';
        } catch (e) { showToast('Gagal upload: ' + file.name, true); }
      }
      setTimeout(() => { progressBar.classList.remove('show'); fill.style.width = '0%'; }, 1000);
      showToast('Upload selesai (' + done + ' file)');
      loadExplorer(currentPath);
      e.target.value = '';
    };

    // Init
    loadExplorer('');
  </script>
</body>
</html>
''';
  }
}