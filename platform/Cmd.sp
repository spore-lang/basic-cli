foreign fn process_run(cmd: String, args: List[String]) -> String ! [ExecError] uses [Spawn]

foreign fn process_run_status(cmd: String, args: List[String]) -> Int ! [ExecError] uses [Spawn]
