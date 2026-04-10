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
/// A simple "Hello World" using the basic-cli platform.
fn main() -> () uses [Console] {
    println("Hello from Spore basic-cli!")
}
```

```bash
spore check examples/hello.sp
spore build examples/hello.sp
spore run examples/hello.sp
```

This repository currently keeps `examples/` limited to files that PR CI validates today.

## Project Structure

```
basic-cli/
├── platform/          # Spore API modules (.sp files), checked and built in CI
│   ├── Stdout.sp      # Standard output operations
│   ├── Stdin.sp       # Standard input operations
│   ├── File.sp        # File read/write operations
│   ├── Dir.sp         # Directory operations
│   ├── Env.sp         # Environment variable access
│   ├── Cmd.sp         # Process execution
├── host/              # Rust host implementation
│   ├── Cargo.toml
│   └── src/
│       └── lib.rs     # Foreign function implementations
└── examples/          # Canonical examples that format/check/build in CI
```

## Tutorial Contract

- `examples/` is for truthful, CI-validated examples only.
- `platform/` is the API surface for the platform modules themselves.
- Only add `tests/` when the repo has real Spore-side regression coverage worth running with `spore test`.

If you want to add a new tutorial/example, treat this as the bar:

1. keep it self-contained;
2. make sure it passes `spore format --check`, `spore check`, and `spore build`;
3. only then promote it into `examples/` and mention it in this README.

## Design Philosophy

Following Spore's [SEP-0005 (Effect System)](https://github.com/spore-lang/spore-evolution):

- **Capability-gated**: Every I/O function declares its required capabilities via `uses [Cap]`
- **Cost-annotated**: Platform functions carry `cost ≤ N` budgets where meaningful
- **Error-typed**: Functions declare error sets via `! ErrorType`
- **Pure by default**: The platform boundary is the only place side effects occur

## Status

🚧 **Early development** — API is unstable and subject to change.

At the moment, the validated example is `examples/hello.sp`. More ambitious host-backed demos such as environment/file workflows should stay out of `examples/` until the current platform import/runtime architecture supports them honestly.

## License

MIT — see [LICENSE](LICENSE).
