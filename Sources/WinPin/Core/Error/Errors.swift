protocol AppError: Error {
  var message: String { get }
}

struct ParseError: AppError {
  let message: String
}

struct RuntimeError: AppError {
  let message: String
}
