/// basic-cli platform — Standard input operations

/// Read a line from stdin (blocks until newline).
foreign fn read_line() -> String uses [Console]
