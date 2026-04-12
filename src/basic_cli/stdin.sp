/// basic-cli platform — Standard input operations

/// Read a line from stdin (blocks until newline).
pub foreign fn read_line() -> Str ! IoError uses [Console]
