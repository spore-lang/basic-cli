// Canonical package-backed application example for basic-cli.
//
// This mirrors the formatted `spore new` scaffold: import the
// platform module explicitly and call `println` from the imported
// basic-cli surface.
import basic_cli.stdout as stdout

/// Application entry point matching the platform contract.
fn main() -> () uses [Console] {
    println("Hello from a project-mode Spore application!");
    return
}
