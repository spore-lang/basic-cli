/// Compatibility startup adapter.
/// Keep this entry in sync with `platform_contract.sp` until the compiler reads
/// `[platform].contract-module` directly.
pub fn main_for_host(app_main: () -> ()) -> () {
    app_main()
    return
}
