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
| `basic_cli.cmd` | `uses [Spawn]` | Process execution |

## Quick Start

The canonical project-mode structure is demonstrated in `examples/hello-app/`:

**examples/hello-app/spore.toml:**
```toml
[package]
name = "hello-app"
type = "application"

[project]
platform = "cli"
default-entry = "app"

[entries.app]
path = "main.sp"

[capabilities]
allow = ["Compute"]
```

**examples/hello-app/src/main.sp:**
```spore
pub fn main() -> () uses [Console] {
    println("Hello from a project-mode Spore application!")
    return
}
```

**Run the project:**
```bash
cd examples/hello-app
spore check src/main.sp
spore run src/main.sp
```

This example currently uses the built-in `cli` platform. When custom platform packages are fully supported in the compiler, `basic-cli` will become a loadable platform dependency that applications can declare in `spore.toml` and import modules from (e.g., `import basic_cli.stdout`). Until then, the example demonstrates the project structure and validates that format/check/run work correctly.

For quick experiments, you can also run standalone `.sp` files (see `examples/hello.sp`), but production applications should use the project-mode structure above.

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

- `examples/hello-app/` is the **canonical project-mode example** — its structure and format are validated in CI.
- `examples/hello.sp` is a minimal standalone file for quick experiments (also validated in CI).
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

The canonical example is the **project-mode** `examples/hello-app/` application, which demonstrates the standard project structure. It currently uses the built-in `cli` platform and validates successfully with `spore check` and `spore run`. Once custom platform packages are fully supported, applications will be able to declare `basic-cli` as a platform dependency and import its modules directly.

The standalone file example (`examples/hello.sp`) demonstrates basic-cli usage for quick experiments. The platform API modules in `src/basic_cli/` define the capability-gated interface that will be available when package imports are enabled.

## License

MIT — see [LICENSE](LICENSE).
