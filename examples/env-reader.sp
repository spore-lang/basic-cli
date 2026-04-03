/// Environment variable reader.
///
/// Demonstrates EnvVar and StdOut capabilities.
uses [EnvVar, StdOut]

fn main() -> Unit uses [EnvVar, StdOut] {
    match env_get("HOME") {
        Some(home) => println("Home directory: " + home),
        None => println("HOME not set"),
    }
}
