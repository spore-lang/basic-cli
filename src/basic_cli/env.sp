/// basic-cli platform — Environment variable access

/// Get the value of an environment variable, or None if not set.
pub foreign fn env_get(key: Str) -> Option[Str] uses [Env]

/// Set an environment variable.
pub foreign fn env_set(key: Str, value: Str) -> () uses [Env]
