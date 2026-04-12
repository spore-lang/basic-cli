/// basic-cli platform — Directory operations

/// List entries in a directory, returning their names.
pub foreign fn dir_list(path: Str) -> List[Str] ! IoError uses [FileRead]

/// Create a directory (and any missing parents).
pub foreign fn dir_mkdir(path: Str) -> () ! IoError uses [FileWrite]
