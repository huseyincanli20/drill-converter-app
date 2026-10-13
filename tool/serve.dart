// ignore_for_file: avoid_print, prefer_const_declarations
import 'dart:io';

void main() async {
  final port = 8080;
  final staticDir = Directory('build/web');
  
  if (!staticDir.existsSync()) {
    print('Error: build/web directory does not exist! Please run flutter build web first.');
    exit(1);
  }

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  print('====================================================');
  print(' Drill Converter Web Server running on:');
  print(' http://localhost:$port');
  print('====================================================');

  await for (HttpRequest req in server) {
    try {
      var path = req.uri.path;
      if (path == '/' || path.isEmpty) {
        path = '/index.html';
      }
      
      // Prevent path traversal
      path = path.replaceAll('..', '');
      var filePath = '${staticDir.path}$path';
      var file = File(filePath);

      // Force no-cache headers so Chrome always gets latest changes
      req.response.headers.set('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0');
      req.response.headers.set('Pragma', 'no-cache');
      req.response.headers.set('Expires', '0');
      req.response.headers.set('Access-Control-Allow-Origin', '*');

      if (await file.exists()) {
        if (path.endsWith('.html')) {
          req.response.headers.contentType = ContentType.html;
        } else if (path.endsWith('.js')) {
          req.response.headers.set('Content-Type', 'application/javascript');
        } else if (path.endsWith('.json')) {
          req.response.headers.contentType = ContentType.json;
        } else if (path.endsWith('.wasm')) {
          req.response.headers.set('Content-Type', 'application/wasm');
        } else if (path.endsWith('.png')) {
          req.response.headers.set('Content-Type', 'image/png');
        } else if (path.endsWith('.otf') || path.endsWith('.ttf')) {
          req.response.headers.set('Content-Type', 'font/ttf');
        }
        await file.openRead().pipe(req.response);
      } else {
        // Fallback to index.html for SPA routing
        final indexFile = File('${staticDir.path}/index.html');
        req.response.headers.contentType = ContentType.html;
        await indexFile.openRead().pipe(req.response);
      }
    } catch (e) {
      try {
        req.response.statusCode = HttpStatus.internalServerError;
        req.response.close();
      } catch (_) {}
    }
  }
}
