import 'package:logger/logger.dart';

final Logger logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 5,
    lineLength: 100,
    colors: false,
  ),
);

void logError(Object error, [StackTrace? stackTrace]) {
  logger.e('Error occurred', error: error, stackTrace: stackTrace);
}

void logInfo(String message) {
  logger.i(message);
}

void logWarning(String message) {
  logger.w(message);
}