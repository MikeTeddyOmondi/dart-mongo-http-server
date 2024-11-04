import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:dotenv/dotenv.dart';

// Configure routes.
final router = Router()
  ..get('/', allGreetingsHandler)
  ..get('/echo/<message>', saveGreetings);

Future<Response> allGreetingsHandler(Request request) async {
  // Access the Db object from the request context
  final db = request.context['db'] as Db;
  DbCollection coll = db.collection('greetings');
  var greetings = await coll.find().toList();
  // var people = await coll.find(where.limit(5)).toList();
  // Ensure response is properly formatted
  return Response.ok(greetings.toString());
}

Future<Response> saveGreetings(Request request) async {
  final db = request.context['db'] as Db;
  final message = request.params['message'];
  DbCollection coll = db.collection('greetings');
  await coll.insertOne({"greeting": message.toString()});
  return Response.ok('$message\n');
}

void main(List<String> args) async {
  // Use any available host or container IP (usually `0.0.0.0`).
  final ip = InternetAddress.anyIPv4;

  try {
    Db db = getDbConn();

    try {
      // Ensure the connection is open
      await db.open();
    } catch (e) {
      print("Db connection error: $e");
    }

    // Middleware to add the Db object to each request
    dbMiddleware(Handler innerHandler) {
      return (Request request) async {
        final updatedRequest = request.change(context: {'db': db});
        return await innerHandler(updatedRequest);
      };
    }

    // Configure a pipeline that logs requests and injects the Db object.
    final handler = Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(dbMiddleware)
        .addHandler(router.call);

    // For running in containers, we respect the PORT environment variable.
    final port = int.parse(Platform.environment['PORT'] ?? '8080');
    final server = await serve(handler, ip, port);
    print('Server listening on port ${server.port}');
  } catch (e) {
    print("App initialisation error: $e");
  }
}

Db getDbConn() {
  // Load .env file
  DotEnv env = DotEnv(includePlatformEnvironment: true)..load();
  String? mongoUrl = env['MONGO_URL'];
  Db db = Db(mongoUrl!);
  return db;
}
