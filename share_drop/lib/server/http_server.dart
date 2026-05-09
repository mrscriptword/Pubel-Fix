import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path/path.dart' as p;

class LocalServer {
  HttpServer? _server;
  String? _ipAddress;
  final int _port = 8080;
  final String _rootDir = '/storage/emulated/0';

  final List<File> sharedFiles = [];

  Future<String?> start() async {
    final info = NetworkInfo();
    _ipAddress = await info.getWifiIP();

    if (_ipAddress == null) {
      return null;
    }

    final app = Router();

    // Main page
    app.get('/', (Request request) {
      return Response.ok(_buildHtmlPage(), headers: {'content-type': 'text/html; charset=utf-8'});
    });

    // API: list files and folders (Explorer)
    app.get('/api/list', (Request request) async {
      final params = request.url.queryParameters;
      final relativePath = params['path'] ?? '';
      final fullPath = p.join(_rootDir, relativePath);

      final directory = Directory(fullPath);
      if (!await directory.exists()) {
        return Response.notFound(jsonEncode({'error': 'Directory not found'}));
      }

      try {
        final List<Map<String, dynamic>> items = [];
        await for (final entity in directory.list()) {
          final name = p.basename(entity.path);
          final isDir = entity is Directory;
          int size = 0;
          if (!isDir) {
            try { size = await (entity as File).length(); } catch (_) {}
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
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // API: Shared files (History/Picked)
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
      }).toList().reversed.toList(); // Newest first

      return Response.ok(jsonEncode(items), headers: {'content-type': 'application/json'});
    });

    // API: Download file (can use full path or filename)
    app.get('/api/download', (Request request) async {
      final params = request.url.queryParameters;
      final path = params['path'] ?? '';
      final fullPath = p.join(_rootDir, path);
      final file = File(fullPath);

      if (!await file.exists()) {
        return Response.notFound('File not found');
      }

      final fileName = p.basename(fullPath);
      return Response.ok(file.openRead(), headers: {
        'Content-Type': 'application/octet-stream',
        'Content-Disposition': 'attachment; filename="$fileName"'
      });
    });

    // API: Upload file
    app.post('/api/upload', (Request request) async {
      final params = request.url.queryParameters;
      final targetPath = params['path'] ?? '';
      final fullDestDir = p.join(_rootDir, targetPath);

      try {
        final contentType = request.headers['content-type'] ?? '';
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
        
        // Add to shared files so it shows in phone UI
        addFile(destFile);

        return Response.ok(jsonEncode({'success': true, 'message': 'File $filename berhasil diupload!'}));
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    final pipeline = const Pipeline().addMiddleware(logRequests()).addHandler(app);
    _server = await io.serve(pipeline, InternetAddress.anyIPv4, _port);
    return 'http://$_ipAddress:$_port';
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
    @import url('https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap');
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: 'Poppins', sans-serif; background: #0D0D1A; color: #fff; min-height: 100vh; overflow-x: hidden; }
    .bg-glow { position: fixed; width: 400px; height: 400px; border-radius: 50%; filter: blur(120px); opacity: 0.15; pointer-events: none; z-index: 0; }
    .bg-glow-1 { top: -100px; right: -100px; background: #8A56AC; }
    .bg-glow-2 { bottom: -150px; left: -100px; background: #6C63FF; }
    
    .container { max-width: 1000px; margin: 0 auto; padding: 40px 24px; position: relative; z-index: 1; }
    .header { text-align: center; margin-bottom: 30px; }
    .logo-box { display: inline-flex; align-items: center; justify-content: center; width: 60px; height: 60px; background: linear-gradient(135deg, #8A56AC, #6C63FF); border-radius: 18px; margin-bottom: 12px; box-shadow: 0 10px 30px rgba(138, 86, 172, 0.4); }
    .logo-box svg { width: 30px; height: 30px; fill: #fff; }
    
    .tabs { display: flex; gap: 10px; margin-bottom: 24px; background: rgba(255,255,255,0.05); padding: 6px; border-radius: 14px; }
    .tab { flex: 1; text-align: center; padding: 12px; cursor: pointer; border-radius: 10px; transition: 0.3s; font-weight: 500; font-size: 14px; color: rgba(255,255,255,0.5); }
    .tab.active { background: linear-gradient(135deg, #8A56AC, #6C63FF); color: #fff; }
    
    .view-container { display: none; }
    .view-container.active { display: block; }

    .breadcrumb { display: flex; align-items: center; gap: 8px; margin-bottom: 20px; padding: 12px 20px; background: rgba(255,255,255,0.03); border-radius: 12px; font-size: 13px; overflow-x: auto; }
    .breadcrumb-item { cursor: pointer; color: rgba(255,255,255,0.4); }
    .breadcrumb-item.active { color: #fff; font-weight: 600; }
    
    .toolbar { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
    .btn { border: none; color: white; padding: 10px 20px; border-radius: 10px; font-size: 13px; font-weight: 500; cursor: pointer; transition: 0.3s; display: flex; align-items: center; gap: 8px; background: linear-gradient(135deg, #8A56AC, #6C63FF); }
    .btn:hover { transform: translateY(-2px); box-shadow: 0 5px 15px rgba(138, 86, 172, 0.4); }
    .upload-input { position: absolute; opacity: 0; width: 1px; }

    .file-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap: 16px; }
    .item { background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.05); border-radius: 16px; padding: 18px; text-align: center; transition: 0.3s; cursor: pointer; display: flex; flex-direction: column; align-items: center; }
    .item:hover { background: rgba(138, 86, 172, 0.08); border-color: rgba(138, 86, 172, 0.3); transform: translateY(-4px); }
    .item-icon { font-size: 36px; margin-bottom: 10px; }
    .item-name { font-size: 12px; font-weight: 500; width: 100%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .item-size { font-size: 10px; color: rgba(255,255,255,0.4); margin-top: 4px; }
    
    .loading-overlay { position: fixed; inset: 0; background: rgba(13,13,26,0.8); display: none; align-items: center; justify-content: center; z-index: 999; }
    .loading-overlay.active { display: flex; }
    .spinner { width: 30px; height: 30px; border: 3px solid rgba(255,255,255,0.1); border-top-color: #8A56AC; border-radius: 50%; animation: spin 1s linear infinite; }
    @keyframes spin { to { transform: rotate(360deg); } }
    
    .toast { position: fixed; bottom: 30px; left: 50%; transform: translateX(-50%) translateY(100px); background: #8A56AC; padding: 10px 20px; border-radius: 10px; font-size: 13px; transition: 0.4s; z-index: 1000; }
    .toast.show { transform: translateX(-50%) translateY(0); }
  </style>
</head>
<body>
  <div class="bg-glow bg-glow-1"></div>
  <div class="bg-glow bg-glow-2"></div>
  
  <div class="container">
    <div class="header">
      <div class="logo-box">
        <svg viewBox="0 0 24 24"><path d="M18 16.08c-.76 0-1.44.3-1.96.77L8.91 12.7c.05-.23.09-.46.09-.7s-.04-.47-.09-.7l7.05-4.11c.54.5 1.25.81 2.04.81 1.66 0 3-1.34 3-3s-1.34-3-3-3-3 1.34-3 3c0 .24.04.47.09.7L8.04 9.81C7.5 9.31 6.79 9 6 9c-1.66 0-3 1.34-3 3s1.34 3 3 3c.79 0 1.5-.31 2.04-.81l7.12 4.16c-.05.21-.08.43-.08.65 0 1.61 1.31 2.92 2.92 2.92s2.92-1.31 2.92-2.92-1.31-2.92-2.92-2.92z"/></svg>
      </div>
      <h2>Pubel Browser</h2>
    </div>

    <div class="tabs">
      <div class="tab active" onclick="switchTab('explorer')">📂 Explorer (Isi HP)</div>
      <div class="tab" onclick="switchTab('shared')">📤 Dikirim dari HP</div>
    </div>

    <!-- Explorer View -->
    <div id="explorerView" class="view-container active">
      <div class="breadcrumb" id="breadcrumb"></div>
      <div class="toolbar">
        <div id="explorerCount" style="color: rgba(255,255,255,0.4); font-size: 13px;">Memuat...</div>
        <button class="btn" onclick="document.getElementById('fileInput').click()">
          📤 Upload ke Folder Ini
          <input type="file" id="fileInput" class="upload-input" multiple>
        </button>
      </div>
      <div class="file-grid" id="explorerGrid"></div>
    </div>

    <!-- Shared View -->
    <div id="sharedView" class="view-container">
      <div class="toolbar">
        <div id="sharedCount" style="color: rgba(255,255,255,0.4); font-size: 13px;">Daftar file yang baru saja diklik/dikirim dari aplikasi HP</div>
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

    function switchTab(tab) {
      document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
      document.querySelectorAll('.view-container').forEach(v => v.classList.remove('active'));
      
      if (tab === 'explorer') {
        document.querySelector('.tab:nth-child(1)').classList.add('active');
        document.getElementById('explorerView').classList.add('active');
        loadExplorer(currentPath);
      } else {
        document.querySelector('.tab:nth-child(2)').classList.add('active');
        document.getElementById('sharedView').classList.add('active');
        loadShared();
      }
    }

    async function loadExplorer(path) {
      currentPath = path;
      loading.classList.add('active');
      updateBreadcrumb();
      try {
        const res = await fetch('/api/list?path=' + encodeURIComponent(path));
        const items = await res.json();
        explorerGrid.innerHTML = '';
        document.getElementById('explorerCount').textContent = items.length + ' item';
        items.forEach(item => explorerGrid.appendChild(createItemEl(item, true)));
      } catch (e) { showToast('Gagal memuat folder'); }
      loading.classList.remove('active');
    }

    async function loadShared() {
      loading.classList.add('active');
      try {
        const res = await fetch('/api/shared');
        const items = await res.json();
        sharedGrid.innerHTML = '';
        items.forEach(item => sharedGrid.appendChild(createItemEl(item, false)));
      } catch (e) { showToast('Gagal memuat file'); }
      loading.classList.remove('active');
    }

    function createItemEl(item, isExplorer) {
      const div = document.createElement('div');
      div.className = 'item';
      let icon = item.isDir ? '📂' : '📄';
      if (!item.isDir) {
        const ext = item.name.split('.').pop().toLowerCase();
        if (['jpg','jpeg','png','gif'].includes(ext)) icon = '🖼️';
        else if (['mp4','mkv','mov'].includes(ext)) icon = '🎬';
        else if (['mp3','wav','m4a'].includes(ext)) icon = '🎵';
      }
      const sizeStr = item.isDir ? '' : (item.size > 1048576 ? (item.size/1048576).toFixed(1)+' MB' : (item.size/1024).toFixed(1)+' KB');
      div.innerHTML = `<div class="item-icon">\${icon}</div><div class="item-name">\${item.name}</div><div class="item-size">\${sizeStr}</div>`;
      div.onclick = () => {
        if (item.isDir) loadExplorer(item.path);
        else window.location.href = '/api/download?path=' + encodeURIComponent(item.path);
      };
      return div;
    }

    function updateBreadcrumb() {
      const b = document.getElementById('breadcrumb');
      b.innerHTML = '<span class="breadcrumb-item" onclick="loadExplorer(\'\')">Penyimpanan Internal</span>';
      if (!currentPath) return;
      let pathAcc = '';
      currentPath.split('/').forEach(part => {
        if (!part) return;
        pathAcc += (pathAcc ? '/' : '') + part;
        const currentPathCopy = pathAcc;
        b.innerHTML += ' / <span class="breadcrumb-item" onclick="loadExplorer(\''+currentPathCopy+'\')">'+part+'</span>';
      });
      b.querySelector('.breadcrumb-item:last-child').classList.add('active');
    }

    function showToast(msg) {
      toast.textContent = msg;
      toast.classList.add('show');
      setTimeout(() => toast.classList.remove('show'), 3000);
    }

    document.getElementById('fileInput').onchange = async (e) => {
      const files = e.target.files;
      if (!files.length) return;
      loading.classList.add('active');
      for (const file of files) {
        const formData = new FormData();
        formData.append('file', file);
        await fetch('/api/upload?path=' + encodeURIComponent(currentPath), { method: 'POST', body: formData });
      }
      loading.classList.remove('active');
      showToast('Berhasil upload ' + files.length + ' file');
      loadExplorer(currentPath);
    };

    loadExplorer('');
  </script>
</body>
</html>
''';
  }
}
