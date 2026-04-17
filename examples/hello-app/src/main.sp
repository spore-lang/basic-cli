/// Canonical package-backed application example for basic-cli.
///
/// This mirrors the formatted `spore new` scaffold: import the
/// platform module explicitly and call `println` directly from the
/// imported basic-cli surface.
/// Application entry point matching the platform contract.
import basic_cli.stdout as stdout

fn main() -> () uses [Console] {
    println("Hello from a project-mode Spore application!")
    return
}
