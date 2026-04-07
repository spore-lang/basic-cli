foreign fn file_read(path: String) -> String ! [IoError] uses [FileRead]

foreign fn file_write(path: String, content: String) -> Unit ! [IoError] uses [FileWrite]

foreign fn file_exists(path: String) -> Bool uses [FileRead]

foreign fn file_stat(path: String) -> String ! [IoError] uses [FileRead]
