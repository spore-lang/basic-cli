/// Environment variable reader.
///
/// Demonstrates Env and Console capabilities.

fn main() -> Unit uses [Env, Console] {
    match env_get("HOME") {
        Some(home) => println("Home directory: " + home),
        None => println("HOME not set"),
    }
}
