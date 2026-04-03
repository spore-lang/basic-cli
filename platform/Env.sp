/// basic-cli platform — Environment variable access

/// Get the value of an environment variable, or None if not set.
foreign fn env_get(key: String) -> Option[String]
    uses [EnvVar]

/// Set an environment variable.
foreign fn env_set(key: String, value: String) -> Unit
    uses [EnvVar]
