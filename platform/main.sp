/// basic-cli platform entry point
///
/// Re-exports all platform modules for convenient access.
/// Usage: `uses basic-cli` in your Spore application.

// Platform modules
pub use Stdout.{print, println, eprint, eprintln}
pub use Stdin.{read_line}
pub use File.{file_read, file_write, file_exists, file_stat}
pub use Dir.{dir_list, dir_mkdir}
pub use Env.{env_get, env_set}
pub use Cmd.{process_run, process_run_status}
