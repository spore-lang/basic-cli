/// File copy example — reads a file and writes it to another path.
///
/// Demonstrates FileRead and FileWrite capabilities.

fn main() -> Unit ! [IoError] uses [FileRead, FileWrite, Console] {
    let content = file_read("input.txt")
    file_write("output.txt", content)
    println("File copied successfully!")
}
