/// A minimal pure standalone Spore file.
///
/// Run with: spore run examples/hello.sp
///
/// This intentionally does not import or call the basic-cli platform. Platform
/// APIs such as `println` are available from package-backed applications like
/// `examples/hello-app/`, not from standalone files.
fn greeting(name: Str) -> Str { "Hello, " + name + "!" }

fn main() -> () {
    let message = greeting("standalone Spore");
    message;
    return
}
