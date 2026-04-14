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
| `basic_cli.stdout` | `uses [Console]` | Standard output |
| `basic_cli.stdin` | `uses [Console]` | Standard input |
| `basic_cli.file` | `uses [FileRead]` or `uses [FileWrite]` | File system operations |
| `basic_cli.dir` | `uses [FileRead]` or `uses [FileWrite]` | Directory listing and creation |
| `basic_cli.env` | `uses [Env]` | Environment variables |
| `basic_cli.cmd` | `uses [Spawn]` or `uses [Exit]` | Process execution and explicit exit |

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
├── spore.toml         # Platform manifest
├── src/
│   ├── host.sp        # Compatibility runtime entry point
│   ├── platform_contract.sp
│   └── basic_cli/     # Spore API modules, checked and built in CI
│       ├── stdout.sp  # Standard output operations
│       ├── stdin.sp   # Standard input operations
│       ├── file.sp    # File read/write operations
│       ├── dir.sp     # Directory operations
│       ├── env.sp     # Environment variable access
│       └── cmd.sp     # Process execution
├── host/              # Rust host implementation
│   ├── Cargo.toml
│   └── src/
│       └── lib.rs     # Foreign function implementations
└── examples/          # Canonical examples that format/check/build in CI
```

## Contract Surface (MVP)

The current Platform contract MVP is intentionally split across two artifacts:

1. `spore.toml` `[platform]` metadata names the contract module, the startup contract symbol, the adapter function, and the handled capabilities.
2. `src/platform_contract.sp` owns the startup contract itself:
   - a hole-backed `main` function carries the authoritative startup signature
   - `main_for_host` is the Platform-owned adapter that receives the application startup function

Applications targeting `basic-cli` must implement the same startup function name/signature in their entry module. When the compiler starts reading Platform contracts from packages, `spec` items attached to the Platform contract and the application implementation will both have to hold.

`src/host.sp` remains as a compatibility copy of the adapter while the compiler still hardcodes platform startup behavior.

## Tutorial Contract

- `examples/` is for truthful, CI-validated examples only.
- `src/basic_cli/` is the API surface for the platform modules themselves.
- `src/platform_contract.sp` is the package-owned startup contract surface.
- Only add `tests/` when the repo has real Spore-side regression coverage worth running with `spore test`.

If you want to add a new tutorial/example, treat this as the bar:

1. keep it self-contained;
2. make sure it passes `spore format --check`, `spore check`, and `spore build`;
3. only then promote it into `examples/` and mention it in this README.

## Design Philosophy

Following Spore's [SEP-0003 (Effect Capability System)](https://github.com/spore-lang/spore-evolution/blob/main/seps/SEP-0003-effect-capability-system.md):

- **Capability-gated**: Every I/O function declares its required capabilities via `uses [Cap]`
- **Cost-annotated**: Platform functions can carry `cost [c, a, i, p]` budgets where meaningful
- **Error-typed**: Functions declare error sets via `! ErrorType`
- **Pure by default**: The platform boundary is the only place side effects occur

## Status

🚧 **Early development** — API is unstable and subject to change.

At the moment, the validated example is `examples/hello.sp`. More ambitious host-backed demos such as environment/file workflows should stay out of `examples/` until the current platform import/runtime architecture supports them honestly.

## License

MIT — see [LICENSE](LICENSE).
