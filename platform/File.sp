/// basic-cli platform — File system operations
///
/// Provides capability-gated file read and write operations.

/// Read the entire contents of a file as a string.
foreign fn file_read(path: String) -> String
    ! [IoError]
    uses [FileRead]

/// Write content to a file, creating or overwriting it.
foreign fn file_write(path: String, content: String) -> Unit
    ! [IoError]
    uses [FileWrite]

/// Check whether a file or directory exists at the given path.
foreign fn file_exists(path: String) -> Bool
    uses [FileRead]

/// Get file metadata (size, modified time, etc.) as a string representation.
foreign fn file_stat(path: String) -> String
    ! [IoError]
    uses [FileRead]
