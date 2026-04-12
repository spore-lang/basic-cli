/// basic-cli platform — File system operations
///
/// Provides capability-gated file read and write operations.

/// Read the entire contents of a file as a string.
pub foreign fn file_read(path: Str) -> Str ! IoError uses [FileRead]

/// Write content to a file, creating or overwriting it.
pub foreign fn file_write(path: Str, content: Str) -> () ! IoError uses [FileWrite]

/// Check whether a file or directory exists at the given path.
pub foreign fn file_exists(path: Str) -> Bool uses [FileRead]

/// Get file metadata (size, modified time, etc.) as a string representation.
pub foreign fn file_stat(path: Str) -> Str ! IoError uses [FileRead]
