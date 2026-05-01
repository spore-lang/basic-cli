/// Platform contract module for `basic-cli`.
/// Applications targeting this Platform must implement the same `main`
/// signature in their entry module. Any `spec` items attached here will stack
/// with the application's own `main` spec and both must hold.
pub fn main() -> () { ?platform_startup_contract }

/// Platform-owned startup adapter.
pub fn main_for_host(app_main: () -> ()) -> () {
    app_main();
    return
}
