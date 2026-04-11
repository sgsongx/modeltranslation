class UseCaseFailure {
  const UseCaseFailure({
    required this.code,
    required this.message,
    this.details,
  });

  final String code;
  final String message;
  final Object? details;
}

class UseCaseResult<T> {
  const UseCaseResult._({
    this.value,
    this.failure,
  }) : isSuccess = failure == null;

  const UseCaseResult.success(T value)
      : this._(value: value);

  const UseCaseResult.failure(UseCaseFailure failure)
      : this._(failure: failure);

  final T? value;
  final UseCaseFailure? failure;
  final bool isSuccess;
}