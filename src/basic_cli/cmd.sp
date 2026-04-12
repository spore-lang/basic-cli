/// basic-cli platform — Process execution
///
/// Run external commands with capability tracking.

/// Run a command and capture its stdout as a string.
/// Returns the full stdout output on success.
pub foreign fn process_run(cmd: Str, args: List[Str]) -> Str ! ExecError uses [Spawn]

/// Run a command and return its exit code.
pub foreign fn process_run_status(cmd: Str, args: List[Str]) -> Int ! ExecError uses [Spawn]
