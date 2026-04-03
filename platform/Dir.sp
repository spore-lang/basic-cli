/// basic-cli platform — Directory operations

/// List entries in a directory, returning their names.
foreign fn dir_list(path: String) -> List[String]
    uses [FileRead]
    ! [IoError]

/// Create a directory (and any missing parents).
foreign fn dir_mkdir(path: String) -> Unit
    uses [FileWrite]
    ! [IoError]
