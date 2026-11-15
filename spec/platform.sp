# basic-cli：宿主输入、统一 Command.run 与正常退出的宏观契约。
# operations.sp 定义 Command、参数类型、名称匹配、文本判等及宿主 / 解析契约。
# 本稿使用 MLTT 基线；运行层函数的调用能力不等于可以在纯证明求值中执行效果。
# 所有模块装配、声明适配、效果与宿主提供义务见 README.md。

# 宿主只读取一次完整 argv；entry 由 compile.assembly 生成，不要求应用 main 为 pub。
# 单命令入口生成显式 Any 根；main(args: List[Str]) 入口把同一列表交给应用构造的 Command.run。
# Examples
# Given: argv 为 ["bootstrap"]；entry 的根为 Any / Help，所有装配与输出正常。
# ```spore
# main_for_host(entry)
# ```
# Expect: entry 收到原列表；根匹配并消费 bootstrap 后显示帮助，返回 0；无业务调用。
#
# Given: argv 为 ["bootstrap", "--help"]；同一装配与输出。
# ```spore
# main_for_host(entry)
# ```
# Expect: 与仅含 bootstrap 的默认帮助根输出相同；--help 由已选根处理，不成为子节点名称。
#
# Given: argv 为空；同一装配与正常诊断输出。
# ```spore
# main_for_host(entry)
# ```
# Expect: entry 收到空列表，Command.run 报缺少根名称，返回 2；不创建备用程序名，不调用业务。
#
# Given: argv 含非法 Unicode 输入，诊断流可写。
# ```spore
# main_for_host(entry)
# ```
# Expect: 返回 2，entry 调用次数为零，不用替换字符继续解析。
pub fn main_for_host(entry: List[Str] -> Exit) -> Int {
    let exit = match read_args() {
        Input.Ready { args: let args } => entry(args),
        Input.Usage { message: let message } => emit(Channel.Stderr {}, message, Exit.Usage {}),
        Input.Failure { message: let message } => emit(Channel.Stderr {}, message, Exit.Failure {})
    };
    exit_code(exit)
}

# prepare 在调用前完成名称匹配、角色绑定和内层值解码；Invoke 已捕获正确类型的实参。
# Examples
# Given: root 为 Any / Help，run 子节点绑定完整 run(repository: OptionalPositional[os.Path]) -> Exit；业务返回 Failure。
# ```spore
# dispatch(root, ["bootstrap", "run", "my repo"])
# ```
# Expect: 只调用 run(OptionalPositional.Some(os.Path.from_text("my repo"))) 一次，原样返回 Failure，不补报业务诊断或重试。
#
# Given: 同一 root。
# ```spore
# dispatch(root, ["bootstrap", "run", ""])
# ```
# Expect: 空路径解码失败，写出用法诊断并返回 Usage；业务调用次数为零。
pub fn dispatch(root: Command, args: List[Str]) -> Exit {
    match prepare(root, args) {
        Decision.Invoke { invoke: let invoke } => invoke(),
        Decision.Help { text: let text } => emit(Channel.Stdout {}, text, Exit.Success {}),
        Decision.Usage { message: let message } => emit(Channel.Stderr {}, message, Exit.Usage {})
    }
}

# Examples
# Given: stdout 可完整写入并刷新。
# ```spore
# emit(Channel.Stdout {}, "ready\n", Exit.Success {})
# ```
# Expect: 恰写出 ready 和一个换行，返回 Success。
#
# Given: stdout 写入前两个字节后发生永久故障。
# ```spore
# emit(Channel.Stdout {}, "ready\n", Exit.Success {})
# ```
# Expect: 返回 Failure；不重放前缀，不向 stderr 追加另一份文本。
pub fn emit(channel: Channel, text: Str, on_success: Exit) -> Exit {
    if write_text(channel, text) { on_success } else { Exit.Failure {} }
}

# 此纯映射不等于已向 OS 设置状态；真实宿主退出属于 host.lifecycle。
# Examples
# ```spore
# (exit_code(Exit.Success {}), exit_code(Exit.Failure {}), exit_code(Exit.Usage {}))
# ```
# Expect: (0, 1, 2)，没有进程效果。
pub fn exit_code(exit: Exit) -> Int {
    match exit {
        Exit.Success {} => 0,
        Exit.Failure {} => 1,
        Exit.Usage {} => 2
    }
}
