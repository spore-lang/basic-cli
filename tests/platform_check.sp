// Platform API type-check validation for basic-cli.
//
// These are pure helper functions that mirror patterns used throughout
// the platform.  Running `spore test tests/platform_check.sp` verifies
// that the standard-library types and builtins that basic-cli relies on
// (String, Bool, Int, List, Option, Result) compose correctly.

// ── Path helpers ────────────────────────────────────────────────────

fn is_valid_path(path: String) -> Bool
spec {
    example "empty":  is_valid_path("") == false
    example "root":   is_valid_path("/") == true
    example "file":   is_valid_path("hello.txt") == true
    example "nested": is_valid_path("/usr/local/bin") == true
}
{
    string_length(path) > 0
}

fn ensure_trailing_slash(path: String) -> String
spec {
    example "no_slash":  ensure_trailing_slash("/usr") == "/usr/"
    example "has_slash": ensure_trailing_slash("/usr/") == "/usr/"
    example "root":      ensure_trailing_slash("/") == "/"
}
{
    if ends_with(path, "/") { path }
    else { path + "/" }
}

fn file_extension(name: String) -> String
spec {
    example "txt":    file_extension("readme.txt") == "txt"
    example "sp":     file_extension("main.sp") == "sp"
    example "dotted": file_extension("archive.tar.gz") == "gz"
}
{
    let parts = split(name, ".");
    last_string(parts)
}

fn last_string(xs: List[String]) -> String {
    match xs {
        [x, ..rest] => {
            if len(rest) == 0 { x }
            else { last_string(rest) }
        },
        _ => "",
    }
}

fn join_path(dir: String, file: String) -> String
spec {
    example "simple":        join_path("/home", "file.txt") == "/home/file.txt"
    example "trailing_slash": join_path("/home/", "file.txt") == "/home/file.txt"
}
{
    if ends_with(dir, "/") { dir + file }
    else { dir + "/" + file }
}

// ── Numeric helpers ─────────────────────────────────────────────────

fn abs(x: Int) -> Int
spec {
    example "positive": abs(5) == 5
    example "negative": abs(0 - 5) == 5
    example "zero":     abs(0) == 0
}
{
    if x < 0 { 0 - x } else { x }
}

fn max_of(a: Int, b: Int) -> Int
spec {
    example "first":  max_of(5, 3) == 5
    example "second": max_of(3, 5) == 5
    example "equal":  max_of(4, 4) == 4
}
{
    if a >= b { a } else { b }
}

fn min_of(a: Int, b: Int) -> Int
spec {
    example "first":  min_of(3, 5) == 3
    example "second": min_of(5, 3) == 3
    example "equal":  min_of(4, 4) == 4
}
{
    if a <= b { a } else { b }
}

fn clamp(x: Int, lo: Int, hi: Int) -> Int
spec {
    example "in_range": clamp(5, 0, 10) == 5
    example "below":    clamp(0 - 5, 0, 10) == 0
    example "above":    clamp(15, 0, 10) == 10
    property "idempotent": |x: Int| clamp(clamp(x, 0, 10), 0, 10) == clamp(x, 0, 10)
}
{
    if x < lo { lo }
    else { if x > hi { hi } else { x } }
}

// ── String helpers ──────────────────────────────────────────────────

fn is_blank(s: String) -> Bool
spec {
    example "empty":  is_blank("") == true
    example "space":  is_blank("   ") == true
    example "text":   is_blank("hi") == false
}
{
    string_length(trim(s)) == 0
}

fn default_if_blank(s: String, fallback: String) -> String
spec {
    example "blank":   default_if_blank("", "default") == "default"
    example "spaces":  default_if_blank("   ", "default") == "default"
    example "present": default_if_blank("hello", "default") == "hello"
}
{
    if is_blank(s) { fallback } else { s }
}

// ── Exit-code helpers ───────────────────────────────────────────────

fn exit_code_ok(code: Int) -> Bool
spec {
    example "zero":     exit_code_ok(0) == true
    example "one":      exit_code_ok(1) == false
    example "negative": exit_code_ok(0 - 1) == false
}
{
    code == 0
}
