/// basic-cli platform — Standard output operations
///
/// Provides capability-gated access to stdout/stderr.

/// Print a string to stdout without trailing newline.
foreign fn print(s: String) -> Unit uses [Console]

/// Print a string to stdout with trailing newline.
foreign fn println(s: String) -> Unit uses [Console]

/// Print a formatted string to stderr.
foreign fn eprint(s: String) -> Unit uses [Console]

/// Print a formatted string to stderr with trailing newline.
foreign fn eprintln(s: String) -> Unit uses [Console]
