/// Legacy compatibility adapter.
/// Manifest-backed projects resolve `main_for_host` from `platform_contract.sp`;
/// keep this shim in sync for older references.
pub fn main_for_host(app_main: () -> ()) -> () {
    app_main();
    return
}
