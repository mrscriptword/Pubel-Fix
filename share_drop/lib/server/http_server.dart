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
<html>
<head>
  <title>Pubel - Waiting</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { font-family: system-ui, -apple-system, sans-serif; background: #F5F7FA; color: #333; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; text-align: center; }
    .card { background: #fff; padding: 40px; border-radius: 24px; box-shadow: 0 10px 30px rgba(0,0,0,0.05); max-width: 90%; }
    .loader { border: 3px solid #E2E8F0; border-top: 3px solid #4CAF50; border-radius: 50%; width: 32px; height: 32px; animation: spin 0.8s linear infinite; margin: 0 auto 20px; }
    @keyframes spin { to { transform: rotate(360deg); } }
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
  <div class="card">
    <div class="loader"></div>
    <h2 style="font-size: 20px; margin-bottom: 8px;">Menunggu Izin...</h2>
    <p style="color: #666; font-size: 14px;">Silakan berikan izin di aplikasi Pubel HP Anda ($ip)</p>
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
  <title>Pubel Web</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; outline: none; }
    body { font-family: 'Segoe UI', system-ui, sans-serif; background: #F5F6F8; color: #333; min-height: 100vh; display: flex; }
    
    /* Sidebar */
    .sidebar { width: 80px; background: #fff; border-right: 1px solid #E5E7EB; display: flex; flex-direction: column; align-items: center; padding: 20px 0; z-index: 10; }
    .logo { width: 40px; height: 40px; background: #FF9800; border-radius: 50%; margin-bottom: 30px; display: flex; justify-content: center; align-items: center; color: white; font-weight: bold; font-size: 24px; text-decoration: none;}
    .nav-item { width: 50px; height: 50px; display: flex; justify-content: center; align-items: center; border-radius: 12px; margin-bottom: 10px; cursor: pointer; color: #9CA3AF; font-size: 24px; transition: 0.2s; }
    .nav-item:hover { background: #F3F4F6; color: #4CAF50; }
    .nav-item.active { background: #4CAF50; color: #fff; }
    
    /* Main Content */
    .main { flex: 1; display: flex; flex-direction: column; overflow: hidden; }
    
    /* Topbar */
    .topbar { height: 60px; background: #fff; border-bottom: 1px solid #E5E7EB; display: flex; justify-content: flex-end; align-items: center; padding: 0 24px; gap: 16px; }
    .top-icon { color: #9CA3AF; font-size: 20px; cursor: pointer; transition: 0.2s; }
    .top-icon:hover { color: #333; }
    
    /* Content Area */
    .content-area { flex: 1; padding: 30px; overflow-y: auto; display: none; }
    .content-area.active { display: block; }
    
    /* Home View */
    .home-layout { display: flex; gap: 40px; align-items: flex-start; max-width: 1000px; margin: 0 auto; }
    
    /* Phone Mockup */
    .phone-mockup { width: 260px; height: 540px; background: #111; border-radius: 30px; padding: 12px; box-shadow: 0 20px 40px rgba(0,0,0,0.1); position: relative; flex-shrink: 0; }
    .phone-screen { width: 100%; height: 100%; background: #F3F4F6; border-radius: 20px; display: flex; flex-direction: column; justify-content: center; align-items: center; overflow: hidden; position: relative; border: 1px solid #E5E7EB;}
    .drop-zone { width: 100%; height: 100%; display: flex; flex-direction: column; justify-content: center; align-items: center; cursor: pointer; transition: 0.2s; background: #fff; }
    .drop-zone:hover, .drop-zone.dragover { background: #E8F5E9; }
    .drop-icon { font-size: 48px; color: #BDBDBD; margin-bottom: 16px; pointer-events: none; }
    .drop-text { color: #9E9E9E; font-size: 14px; pointer-events: none; }
    
    /* Categories */
    .categories-section { flex: 1; }
    .device-info { display: flex; align-items: center; gap: 12px; margin-bottom: 40px; }
    .device-name { font-size: 24px; font-weight: 600; color: #333; }
    .device-os { font-size: 14px; color: #9CA3AF; }
    
    .category-grid { display: flex; flex-wrap: wrap; gap: 30px; margin-bottom: 50px; }
    .category-item { display: flex; flex-direction: column; align-items: center; gap: 12px; cursor: pointer; width: 80px; transition: 0.2s; }
    .category-item:hover { transform: translateY(-5px); }
    .cat-icon-box { width: 70px; height: 70px; border-radius: 50%; border: 1px solid #E5E7EB; display: flex; justify-content: center; align-items: center; font-size: 28px; background: #fff; box-shadow: 0 4px 10px rgba(0,0,0,0.02); }
    .cat-name { font-size: 13px; color: #6B7280; font-weight: 500; }
    
    .storage-bar-container { background: #E5E7EB; height: 16px; border-radius: 8px; overflow: hidden; position: relative; }
    .storage-bar-fill { background: #FF9800; height: 100%; width: 45%; }
    .storage-text { position: absolute; width: 100%; text-align: center; top: 0; left: 0; line-height: 16px; font-size: 10px; color: #fff; font-weight: 600; text-shadow: 0 1px 2px rgba(0,0,0,0.3); }

    /* Explorer View */
    .breadcrumb { display: flex; align-items: center; gap: 8px; margin-bottom: 24px; padding: 12px 16px; background: #fff; border-radius: 12px; font-size: 14px; overflow-x: auto; white-space: nowrap; box-shadow: 0 2px 10px rgba(0,0,0,0.02); border: 1px solid #F3F4F6; }
    .breadcrumb-item { cursor: pointer; color: #6B7280; font-weight: 500; }
    .breadcrumb-item:hover { color: #4CAF50; }
    .breadcrumb-item.active { color: #333; font-weight: 600; cursor: default; }
    
    .toolbar { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
    .btn { border: none; padding: 10px 20px; border-radius: 8px; font-size: 13px; font-weight: 600; cursor: pointer; transition: 0.2s; display: flex; align-items: center; gap: 8px; background: #4CAF50; color: white; }
    .btn:hover { background: #43A047; }
    .btn-secondary { background: #fff; color: #333; border: 1px solid #E5E7EB; }
    .btn-secondary:hover { background: #F9FAFB; }

    .file-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(130px, 1fr)); gap: 16px; }
    .item { background: #fff; border: 1px solid #E5E7EB; border-radius: 16px; padding: 20px 16px; text-align: center; transition: 0.2s; cursor: pointer; box-shadow: 0 4px 15px rgba(0,0,0,0.02); }
    .item:hover { border-color: #4CAF50; box-shadow: 0 8px 20px rgba(76, 175, 80, 0.1); transform: translateY(-2px); }
    .item-icon { font-size: 36px; margin-bottom: 12px; display: block; }
    .item-name { font-size: 12px; font-weight: 500; width: 100%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; display: block; color: #333; }
    .item-size { font-size: 11px; color: #9CA3AF; margin-top: 6px; display: block; }
    
    /* Utilities */
    .loading-overlay { position: fixed; inset: 0; background: rgba(255,255,255,0.8); display: none; align-items: center; justify-content: center; z-index: 100; backdrop-filter: blur(4px); }
    .loading-overlay.active { display: flex; }
    .spinner { width: 36px; height: 36px; border: 3px solid #E5E7EB; border-top-color: #4CAF50; border-radius: 50%; animation: spin 0.8s linear infinite; }
    @keyframes spin { to { transform: rotate(360deg); } }
    
    .toast { position: fixed; bottom: 24px; left: 50%; transform: translateX(-50%) translateY(100px); background: #333; color: white; padding: 12px 24px; border-radius: 8px; font-size: 14px; transition: 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275); z-index: 200; box-shadow: 0 10px 30px rgba(0,0,0,0.1); }
    .toast.show { transform: translateX(-50%) translateY(0); }
    .empty-msg { text-align: center; padding: 80px 0; color: #9CA3AF; font-size: 14px; width: 100%; grid-column: 1 / -1; }
  </style>
</head>
<body>
  
  <div class="sidebar">
    <div class="logo">X</div>
    <div class="nav-item active" id="nav-home" onclick="switchView('home')" title="Home">🏠</div>
    <div class="nav-item" id="nav-explorer" onclick="switchView('explorer'); loadExplorer('');" title="Explorer">📁</div>
    <div class="nav-item" id="nav-shared" onclick="switchView('shared'); loadShared();" title="Shared">📤</div>
  </div>

  <div class="main">
    <div class="topbar">
      <div class="top-icon" title="Connect">🔗</div>
      <div class="top-icon" title="Power Off" onclick="logout()">⏻</div>
    </div>

    <!-- Home View -->
    <div id="homeView" class="content-area active">
      <div class="home-layout">
        <div class="phone-mockup">
          <div class="phone-screen">
            <div class="drop-zone" id="dropZone" onclick="document.getElementById('homeFileInput').click()">
              <div class="drop-icon">📄</div>
              <div class="drop-text">Drag & drop to transfer</div>
            </div>
            <input type="file" id="homeFileInput" style="display:none" multiple>
          </div>
        </div>
        
        <div class="categories-section">
          <div class="device-info">
            <div class="device-name">Pubel Device</div>
            <div class="device-os">Android</div>
          </div>
          
          <div class="category-grid">
            <div class="category-item" onclick="openFolder('DCIM')">
              <div class="cat-icon-box" style="color: #F44336;">🖼️</div>
              <div class="cat-name">Images</div>
            </div>
            <div class="category-item" onclick="openFolder('Movies')">
              <div class="cat-icon-box" style="color: #2196F3;">🎬</div>
              <div class="cat-name">Video</div>
            </div>
            <div class="category-item" onclick="openFolder('Music')">
              <div class="cat-icon-box" style="color: #FF9800;">🎵</div>
              <div class="cat-name">Music</div>
            </div>
            <div class="category-item" onclick="openFolder('Documents')">
              <div class="cat-icon-box" style="color: #4CAF50;">📄</div>
              <div class="cat-name">Documents</div>
            </div>
            <div class="category-item" onclick="switchView('explorer'); loadExplorer('');">
              <div class="cat-icon-box" style="color: #9C27B0;">📁</div>
              <div class="cat-name">Folders</div>
            </div>
          </div>
          
          <div class="storage-bar-container">
            <div class="storage-bar-fill"></div>
            <div class="storage-text">Internal Storage: Connected</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Explorer View -->
    <div id="explorerView" class="content-area">
      <div class="breadcrumb" id="breadcrumb"></div>
      <div class="toolbar">
        <div id="explorerCount" style="color: #6B7280; font-size: 13px; font-weight: 500;">Memuat...</div>
        <div style="display: flex; gap: 8px;">
          <button class="btn btn-secondary" onclick="loadExplorer(currentPath)">Refresh</button>
          <button class="btn" onclick="document.getElementById('explorerFileInput').click()">Upload</button>
        </div>
        <input type="file" id="explorerFileInput" style="display:none" multiple>
      </div>
      <div class="file-grid" id="explorerGrid"></div>
    </div>

    <!-- Shared View -->
    <div id="sharedView" class="content-area">
      <div class="toolbar">
        <div style="color: #6B7280; font-size: 13px; font-weight: 500;">File yang dipilih di HP</div>
        <button class="btn btn-secondary" onclick="loadShared()">Refresh</button>
      </div>
      <div class="file-grid" id="sharedGrid"></div>
    </div>
  </div>

  <div class="loading-overlay" id="loading"><div class="spinner"></div></div>
  <div class="toast" id="toast"></div>

  <script>
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
           explorerGrid.innerHTML = '<div class="empty-msg">⚠️ Gagal memuat folder. Pastikan izin akses file sudah diberikan di aplikasi HP.</div>';
           return;
        }
        const items = await res.json();
        explorerGrid.innerHTML = '';
        document.getElementById('explorerCount').textContent = items.length + ' item';
        
        if (items.length === 0) {
          explorerGrid.innerHTML = '<div class="empty-msg">Folder ini kosong</div>';
        } else {
          items.forEach(item => explorerGrid.appendChild(createItemEl(item)));
        }
      } catch (e) { 
        showToast('Kesalahan memuat data');
        explorerGrid.innerHTML = '<div class="empty-msg">⚠️ Terjadi kesalahan. Pastikan folder ada dan server aktif.</div>';
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
          sharedGrid.innerHTML = '<div class="empty-msg">Belum ada file dipilih di HP</div>';
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
      b.innerHTML = `<span class="breadcrumb-item" onclick="loadExplorer('')">Internal</span>`;
      if (!currentPath) { b.querySelector('.breadcrumb-item').classList.add('active'); return; }
      let pathAcc = '';
      currentPath.split('/').filter(p=>p).forEach(part => {
        pathAcc += (pathAcc ? '/' : '') + part;
        const currentPathCopy = pathAcc;
        b.innerHTML += ` <span>/</span> <span class="breadcrumb-item" onclick="loadExplorer('\${currentPathCopy}')">\${part}</span>`;
      });
      b.querySelector('.breadcrumb-item:last-child').classList.add('active');
    }

    function showToast(msg) {
      toast.textContent = msg;
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
      showToast('Upload selesai');
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
''';
  }
}
