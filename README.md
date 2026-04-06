# basic-cli

Basic CLI platform for [Spore](https://github.com/spore-lang/spore) — provides file I/O, process execution, environment variables, and standard I/O capabilities.

## Overview

In Spore, a **platform** bridges the pure, capability-tracked language with real-world side effects. `basic-cli` is the standard platform for command-line applications.

```
Your Spore App (pure, capability-checked)
     ↕  (effect dispatch)
basic-cli Platform API (.sp modules)
     ↕  (foreign fn)
Rust Host (actual I/O via std::fs, std::process, etc.)
     ↕
Operating System
```

## Modules

| Module | Capabilities | Description |
|--------|-------------|-------------|
| `Stdout` | `uses [Console]` | Standard output |
| `Stdin` | `uses [Console]` | Standard input |
| `File` | `uses [FileRead]` or `uses [FileWrite]` | File system operations |
| `Dir` | `uses [FileRead]` | Directory listing |
| `Env` | `uses [Env]` | Environment variables |
| `Cmd` | `uses [Spawn]` | Process execution |

## Quick Start

```spore
// hello.sp
uses [Console]

fn main() -> Unit uses [Console] {
    println("Hello from basic-cli!")
}
```

```bash
spore run hello.sp --platform basic-cli
```

## Project Structure

```
basic-cli/
├── platform/          # Spore API modules (.sp files)
│   ├── Stdout.sp      # Standard output operations
│   ├── Stdin.sp       # Standard input operations
│   ├── File.sp        # File read/write operations
│   ├── Dir.sp         # Directory operations
│   ├── Env.sp         # Environment variable access
│   ├── Cmd.sp         # Process execution
│   └── main.sp        # Platform entry point
├── host/              # Rust host implementation
│   ├── Cargo.toml
│   └── src/
│       └── lib.rs     # Foreign function implementations
├── examples/          # Example Spore programs using this platform
└── tests/             # Integration tests
```

## Design Philosophy

Following Spore's [SEP-0005 (Effect System)](https://github.com/spore-lang/spore-evolution):

- **Capability-gated**: Every I/O function declares its required capabilities via `uses [Cap]`
- **Cost-annotated**: Platform functions carry `cost ≤ N` budgets where meaningful
- **Error-typed**: Functions declare error sets via `! [ErrorType]`
- **Pure by default**: The platform boundary is the only place side effects occur

## Status

🚧 **Early development** — API is unstable and subject to change.

## License

MIT — see [LICENSE](LICENSE).
