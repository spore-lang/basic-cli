//! Rust host for basic-cli platform.
//!
//! Each `foreign fn` declared in the platform .sp files is backed by
//! a Rust implementation here.  The Spore runtime calls into these
//! functions via the effect-handler / FFI bridge.

use std::collections::HashMap;
use std::io::{self, Write};

/// Result type for host operations.
pub type HostResult = Result<HostValue, HostError>;

/// Values that can cross the host ↔ Spore boundary.
#[derive(Debug, Clone)]
pub enum HostValue {
    Unit,
    Bool(bool),
    Int(i64),
    Str(String),
    List(Vec<HostValue>),
    Option(Option<Box<HostValue>>),
}

/// Errors from host operations.
#[derive(Debug, Clone)]
pub struct HostError {
    pub kind: String,
    pub message: String,
}

impl std::fmt::Display for HostError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}: {}", self.kind, self.message)
    }
}

impl std::error::Error for HostError {}

// ── Stdout ──────────────────────────────────────────────────────────

pub fn host_print(s: &str) -> HostResult {
    print!("{s}");
    io::stdout().flush().map_err(|e| HostError {
        kind: "IoError".into(),
        message: e.to_string(),
    })?;
    Ok(HostValue::Unit)
}

pub fn host_println(s: &str) -> HostResult {
    println!("{s}");
    Ok(HostValue::Unit)
}

pub fn host_eprint(s: &str) -> HostResult {
    eprint!("{s}");
    io::stderr().flush().map_err(|e| HostError {
        kind: "IoError".into(),
        message: e.to_string(),
    })?;
    Ok(HostValue::Unit)
}

pub fn host_eprintln(s: &str) -> HostResult {
    eprintln!("{s}");
    Ok(HostValue::Unit)
}

// ── Stdin ───────────────────────────────────────────────────────────

pub fn host_read_line() -> HostResult {
    let mut buf = String::new();
    io::stdin().read_line(&mut buf).map_err(|e| HostError {
        kind: "IoError".into(),
        message: e.to_string(),
    })?;
    // Strip trailing newline
    if buf.ends_with('\n') {
        buf.pop();
        if buf.ends_with('\r') {
            buf.pop();
        }
    }
    Ok(HostValue::Str(buf))
}

// ── File ────────────────────────────────────────────────────────────

pub fn host_file_read(path: &str) -> HostResult {
    let content = std::fs::read_to_string(path).map_err(|e| HostError {
        kind: "IoError".into(),
        message: format!("{path}: {e}"),
    })?;
    Ok(HostValue::Str(content))
}

pub fn host_file_write(path: &str, content: &str) -> HostResult {
    std::fs::write(path, content).map_err(|e| HostError {
        kind: "IoError".into(),
        message: format!("{path}: {e}"),
    })?;
    Ok(HostValue::Unit)
}

pub fn host_file_exists(path: &str) -> HostResult {
    Ok(HostValue::Bool(std::path::Path::new(path).exists()))
}

pub fn host_file_stat(path: &str) -> HostResult {
    let meta = std::fs::metadata(path).map_err(|e| HostError {
        kind: "IoError".into(),
        message: format!("{path}: {e}"),
    })?;
    let info = format!(
        "size={} is_dir={} is_file={}",
        meta.len(),
        meta.is_dir(),
        meta.is_file()
    );
    Ok(HostValue::Str(info))
}

// ── Dir ─────────────────────────────────────────────────────────────

pub fn host_dir_list(path: &str) -> HostResult {
    let entries: Vec<HostValue> = std::fs::read_dir(path)
        .map_err(|e| HostError {
            kind: "IoError".into(),
            message: format!("{path}: {e}"),
        })?
        .filter_map(|entry| entry.ok())
        .map(|entry| HostValue::Str(entry.file_name().to_string_lossy().into_owned()))
        .collect();
    Ok(HostValue::List(entries))
}

pub fn host_dir_mkdir(path: &str) -> HostResult {
    std::fs::create_dir_all(path).map_err(|e| HostError {
        kind: "IoError".into(),
        message: format!("{path}: {e}"),
    })?;
    Ok(HostValue::Unit)
}

// ── Env ─────────────────────────────────────────────────────────────

pub fn host_env_get(key: &str) -> HostResult {
    match std::env::var(key) {
        Ok(val) => Ok(HostValue::Option(Some(Box::new(HostValue::Str(val))))),
        Err(_) => Ok(HostValue::Option(None)),
    }
}

pub fn host_env_set(key: &str, value: &str) -> HostResult {
    // SAFETY: We assume single-threaded Spore execution for now.
    // The Spore runtime must ensure no concurrent env access.
    unsafe { std::env::set_var(key, value) };
    Ok(HostValue::Unit)
}

// ── Cmd ─────────────────────────────────────────────────────────────

pub fn host_process_run(cmd: &str, args: &[String]) -> HostResult {
    let output = std::process::Command::new(cmd)
        .args(args)
        .output()
        .map_err(|e| HostError {
            kind: "ExecError".into(),
            message: format!("{cmd}: {e}"),
        })?;
    if output.status.success() {
        Ok(HostValue::Str(
            String::from_utf8_lossy(&output.stdout).into_owned(),
        ))
    } else {
        Err(HostError {
            kind: "ExecError".into(),
            message: format!(
                "{cmd} exited with {}: {}",
                output.status,
                String::from_utf8_lossy(&output.stderr)
            ),
        })
    }
}

pub fn host_process_run_status(cmd: &str, args: &[String]) -> HostResult {
    let status = std::process::Command::new(cmd)
        .args(args)
        .status()
        .map_err(|e| HostError {
            kind: "ExecError".into(),
            message: format!("{cmd}: {e}"),
        })?;
    Ok(HostValue::Int(status.code().unwrap_or(-1) as i64))
}

pub fn host_exit(code: i64) -> HostResult {
    let code = u8::try_from(code).map_err(|_| HostError {
        kind: "ExitError".into(),
        message: format!("exit code {code} is out of range for 0..=255"),
    })?;

    #[cfg(test)]
    {
        Err(HostError {
            kind: "Exit".into(),
            message: format!("process exit requested with code {code}"),
        })
    }

    #[cfg(not(test))]
    {
        std::process::exit(i32::from(code))
    }
}

// ── Dispatch table ──────────────────────────────────────────────────

/// Build the host function dispatch table.
/// Maps `foreign fn` names to their Rust implementations.
pub fn dispatch_table() -> HashMap<&'static str, &'static str> {
    let mut table = HashMap::new();
    table.insert("print", "host_print");
    table.insert("println", "host_println");
    table.insert("eprint", "host_eprint");
    table.insert("eprintln", "host_eprintln");
    table.insert("read_line", "host_read_line");
    table.insert("file_read", "host_file_read");
    table.insert("file_write", "host_file_write");
    table.insert("file_exists", "host_file_exists");
    table.insert("file_stat", "host_file_stat");
    table.insert("dir_list", "host_dir_list");
    table.insert("dir_mkdir", "host_dir_mkdir");
    table.insert("env_get", "host_env_get");
    table.insert("env_set", "host_env_set");
    table.insert("process_run", "host_process_run");
    table.insert("process_run_status", "host_process_run_status");
    table.insert("exit", "host_exit");
    table
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn temp_path(name: &str) -> PathBuf {
        let unique = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("system time should be after epoch")
            .as_nanos();
        std::env::temp_dir().join(format!(
            "spore-basic-cli-{name}-{unique}-{}",
            std::process::id()
        ))
    }

    #[test]
    fn print_returns_unit() {
        let result = host_println("test");
        assert!(matches!(result, Ok(HostValue::Unit)));
    }

    #[test]
    fn file_exists_false_for_missing() {
        let result = host_file_exists("/nonexistent/path/12345");
        assert!(matches!(result, Ok(HostValue::Bool(false))));
    }

    #[test]
    fn env_roundtrip() {
        host_env_set("SPORE_TEST_VAR", "hello").unwrap();
        let result = host_env_get("SPORE_TEST_VAR").unwrap();
        match result {
            HostValue::Option(Some(v)) => match *v {
                HostValue::Str(s) => assert_eq!(s, "hello"),
                _ => panic!("expected Str"),
            },
            _ => panic!("expected Some"),
        }
    }

    #[test]
    fn env_get_none_when_unset() {
        let key = format!("SPORE_TEST_MISSING_VAR_{}", std::process::id());
        // SAFETY: these tests run single-threaded against a unique variable name.
        unsafe { std::env::remove_var(&key) };
        let result = host_env_get(&key).unwrap();
        assert!(matches!(result, HostValue::Option(None)));
    }

    #[test]
    fn file_read_write_roundtrip() {
        let dir = temp_path("file-roundtrip");
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("test.txt");
        let path_str = path.to_str().unwrap();

        host_file_write(path_str, "hello spore").unwrap();
        let result = host_file_read(path_str).unwrap();
        match result {
            HostValue::Str(s) => assert_eq!(s, "hello spore"),
            _ => panic!("expected Str"),
        }

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn file_read_missing_returns_io_error() {
        let path = temp_path("missing-file").join("missing.txt");
        let err = host_file_read(path.to_str().unwrap()).unwrap_err();
        assert_eq!(err.kind, "IoError");
        assert!(err.message.contains("missing.txt"));
    }

    #[test]
    fn dir_list_works() {
        let dir = temp_path("dir-list");
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(dir.join("a.txt"), "a").unwrap();
        std::fs::write(dir.join("b.txt"), "b").unwrap();

        let result = host_dir_list(dir.to_str().unwrap()).unwrap();
        match result {
            HostValue::List(items) => assert!(items.len() >= 2),
            _ => panic!("expected List"),
        }

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn dir_mkdir_then_list_roundtrip() {
        let root = temp_path("dir-mkdir");
        let nested = root.join("nested");
        host_dir_mkdir(nested.to_str().unwrap()).unwrap();

        let result = host_dir_list(root.to_str().unwrap()).unwrap();
        match result {
            HostValue::List(items) => assert!(
                items
                    .iter()
                    .any(|item| matches!(item, HostValue::Str(name) if name == "nested"))
            ),
            _ => panic!("expected List"),
        }

        let _ = std::fs::remove_dir_all(&root);
    }

    #[test]
    fn process_run_status_echo() {
        let result = host_process_run_status("echo", &["hello".into()]).unwrap();
        match result {
            HostValue::Int(code) => assert_eq!(code, 0),
            _ => panic!("expected Int"),
        }
    }

    #[test]
    fn process_run_captures_stdout() {
        let result =
            host_process_run("sh", &["-c".into(), "printf 'hello from host'".into()]).unwrap();
        match result {
            HostValue::Str(output) => assert_eq!(output, "hello from host"),
            _ => panic!("expected Str"),
        }
    }

    #[test]
    fn process_run_nonzero_exit_returns_exec_error() {
        let err =
            host_process_run("sh", &["-c".into(), "echo boom >&2; exit 7".into()]).unwrap_err();
        assert_eq!(err.kind, "ExecError");
        assert!(err.message.contains("boom"));
    }

    #[test]
    fn exit_returns_test_sentinel_error() {
        let err = host_exit(17).unwrap_err();
        assert_eq!(err.kind, "Exit");
        assert!(err.message.contains("17"));
    }

    #[test]
    fn exit_rejects_out_of_range_codes() {
        let err = host_exit(256).unwrap_err();
        assert_eq!(err.kind, "ExitError");
        assert!(err.message.contains("0..=255"));
    }

    #[test]
    fn dispatch_table_has_all_functions() {
        let table = dispatch_table();
        assert_eq!(table.len(), 16);
        assert!(table.contains_key("println"));
        assert!(table.contains_key("file_read"));
        assert!(table.contains_key("process_run"));
        assert_eq!(table.get("process_run"), Some(&"host_process_run"));
        assert_eq!(table.get("dir_mkdir"), Some(&"host_dir_mkdir"));
        assert_eq!(table.get("exit"), Some(&"host_exit"));
    }
}
