import 'error_handler.dart';

@Deprecated('Use AppError from error_handler.dart.')
typedef MappedException = AppError;

/// Compatibility wrapper for screens migrated from the previous mapper.
@Deprecated('Use ErrorHandler directly.')
class ExceptionMapper {
  const ExceptionMapper._();

  static AppError map(Object exception, [StackTrace? stackTrace]) =>
      ErrorHandler.handle(exception, stackTrace);
}
