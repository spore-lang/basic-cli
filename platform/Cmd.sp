/// basic-cli platform — Process execution
///
/// Run external commands with capability tracking.

/// Run a command and capture its stdout as a string.
/// Returns the full stdout output on success.
foreign fn process_run(cmd: String, args: List[String]) -> String
    uses [Exec]
    ! [ExecError]

/// Run a command and return its exit code.
foreign fn process_run_status(cmd: String, args: List[String]) -> Int
    uses [Exec]
    ! [ExecError]
