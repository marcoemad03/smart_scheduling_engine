import 'package:logger/logger.dart';

final Logger appLogger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 5,
    lineLength: 100,
    colors: false,
  ),
);

void logError(Object error, [StackTrace? stackTrace]) {
  appLogger.e('Error occurred', error: error, stackTrace: stackTrace);
}

void logInfo(String message) {
  appLogger.i(message);
}

void logWarning(String message) {
  appLogger.w(message);
}

final logger = appLogger;
