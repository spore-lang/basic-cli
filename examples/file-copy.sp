/// File copy example — reads a file and writes it to another path.
///
/// Demonstrates FileRead and FileWrite capabilities.
uses [FileRead, FileWrite, StdOut]

fn main() -> Unit uses [FileRead, FileWrite, StdOut] ! [IoError] {
    let content = file_read("input.txt")
    file_write("output.txt", content)
    println("File copied successfully!")
}
