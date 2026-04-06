/// basic-cli platform — Directory operations

/// List entries in a directory, returning their names.
foreign fn dir_list(path: String) -> List[String]
    ! [IoError]
    uses [FileRead]

/// Create a directory (and any missing parents).
foreign fn dir_mkdir(path: String) -> Unit
    ! [IoError]
    uses [FileWrite]
