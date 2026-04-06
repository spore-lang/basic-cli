/// File copy example — reads a file and writes it to another path.
///
/// Demonstrates FileRead and FileWrite capabilities.
uses [FileRead, FileWrite, Console]

fn main() -> Unit uses [FileRead, FileWrite, Console] ! [IoError] {
    let content = file_read("input.txt")
    file_write("output.txt", content)
    println("File copied successfully!")
}
