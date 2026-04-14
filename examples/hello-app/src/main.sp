/// Canonical project-mode application example for basic-cli.
///
/// This application uses the built-in cli platform and demonstrates
/// the standard project structure that basic-cli will support when
/// custom platforms are fully implemented.
/// Application entry point matching the platform contract.
pub fn main() -> () uses [Console] {
    println("Hello from a project-mode Spore application!")
    return
}
