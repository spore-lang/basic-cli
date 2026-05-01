/// basic-cli platform — Standard output operations
///
/// Provides effect-gated access to stdout/stderr.

/// Print a string to stdout without trailing newline.
pub foreign fn print(s: Str) -> () ! IoError uses [Console]

/// Print a string to stdout with trailing newline.
pub foreign fn println(s: Str) -> () uses [Console]

/// Print a formatted string to stderr.
pub foreign fn eprint(s: Str) -> () ! IoError uses [Console]

/// Print a formatted string to stderr with trailing newline.
pub foreign fn eprintln(s: Str) -> () uses [Console]
