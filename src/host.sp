/// Platform startup adapter.
/// This is where the platform sets up effect handlers before calling the application startup function.
pub fn main_for_host(app_main: () -> ()) -> () {
    app_main()
    return
}
