import Foundation

/// A wrapper for `preconditionFailure` that decorates the message with additional context.
///
/// - Parameters:
///   - message: A message to provide context for the error.
///   - file: The file name to print with `message` if the assertion fails. The
///     default is the file where `assert(_:_:file:line:)` is called.
///   - line: The line number to print along with `message` if the assertion
///     fails. The default is the line number where `assert(_:_:file:line:)`
///     is called.
///
package func ws_preconditionFailure(
    _ message: String,
    file: StaticString = #file,
    line: UInt = #line
) -> Never {
    let fullMessage =
        """
        \(messagePrefix) Precondition Failure: \(message)
        \(supportMessage)
        """

    preconditionFailure(fullMessage)
}
