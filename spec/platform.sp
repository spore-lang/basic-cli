# basic-cli 新版 platform：启动、命令调用与退出的宏观契约。
# MLTT 基线；type / case、显式 let 模式，普通类型参数使用 Type。
# operations.sp 定义平台数据、名称比较与三个函数 hole；List 来自标准库，README.md 登记编译与运行集成 hole。
# 文件间名字装配仍待实现，不能把按阅读顺序出现当作已经导入。
# 此处的运行层函数签名不授予在 MLTT 证明求值中执行 I/O 或任意回调的能力。

# 一次调用绑定已解码输入与完整根命令；名称、动作和子树只由 Command 描述。
# 处理函数声明的适配见 compile.bindings；名称 case 保持原值，Cli 不覆盖根动作，也不复制 Command 的字段。
pub type Cli {
    pub field args: Args;
    pub field command: Command;

    # 构造或选择这个方法不执行业务；调用 run 才开始分派，也不再次读取宿主 argv。
    # Examples
    # Given: app 为默认帮助根，唯一直接子节点 run 无子命令，绑定完整 run(repository: Str) -> Exit；app.args.values = ["run", "repo"]，run 返回 Success。
    # ```spore
    # app.run()
    # ```
    # Expect: 只调用 run("repo") 一次，返回 Exit.Success；不调用根动作，不重复读取 argv。
    #
    # Given: app 的根自身函数为完整 start() -> Exit，app.args.values 为空，start 返回 Failure。
    # ```spore
    # app.run()
    # ```
    # Expect: 只调用 start 一次并返回 Exit.Failure；不输出缺省帮助，不重试。
    pub method run() -> Exit {
        dispatch(self.command, self.args)
    }
}

# command 是已完成处理函数绑定的完整根命令；构造仅保存输入和该命令，不选择默认动作或改写 name。
# 构造不会解析 values、选择子命令、输出或调用 handler。
# Examples
# Given: root 是已生成的默认帮助根，含完整 run(repository: Str) -> Exit 的节点。
# ```spore
# cli(Args { program: "bootstrap", values: ["run", "repo"] }, root)
# ```
# Expect: 返回 Cli，args 与 command 保持原值；root 的名称、动作和子列表顺序均不改变；无解析、输出或业务调用。
#
# Given: root 的 handler 为 Help，subcommands 为空；输出流可写。
# ```spore
# cli(Args { program: "bootstrap", values: [] }, root).run()
# ```
# Expect: 输出无子命令的根帮助到 stdout，stderr 为空，返回 Exit.Success；无业务调用。
pub fn cli(args: Args, command: Command) -> Cli {
    Cli { args: args, command: command }
}

# 宿主调用固定适配入口；entry 由编译期装配产生，不要求应用 main 为 pub。
# 单命令 entry 将 main 绑定到无子命令的根，先解析再调用；接收 Args 的入口直接调用 main(args)。
# read_args 只读一次输入；输入失败时不进入应用。只有正常返回路径产生此退出码。
#
# Examples
# Given: 宿主 argv 为 ["bootstrap"]；entry 的根 handler 为 Help，静态命令树已装配，输入和输出正常。
# ```spore
# main_for_host(entry)
# ```
# Expect: 返回 0；entry 收到 program = "bootstrap"、values = [] 的 Args；stdout 为根帮助、stderr 为空，业务处理函数调用次数为零。
#
# Given: 宿主 argv 为 ["bootstrap", "--help"]；同一默认帮助根与正常输入输出。
# ```spore
# main_for_host(entry)
# ```
# Expect: 返回 0；entry 收到 program = "bootstrap"、values = ["--help"] 的 Args；stdout 与无参数调用的根帮助完全相同、stderr 为空，业务处理函数调用次数为零。
#
# Given: Unix 宿主 argv[1] 含非法 UTF-8 字节 0xff；entry 是完整入口，stderr 写入和刷新成功。
# ```spore
# main_for_host(entry)
# ```
# Expect: 返回 2，stderr 有编码诊断，entry 调用次数为零；不以替换字符继续解析。
pub fn main_for_host(entry: Args -> Exit) -> Int {
    let exit = match read_args() {
        Input.Ready { args: let args } => entry(args),
        Input.Usage { message: let message } =>
            emit(Channel.Stderr {}, message, Exit.Usage {}),
        Input.Failure { message: let message } =>
            emit(Channel.Stderr {}, message, Exit.Failure {})
    };
    exit_code(exit)
}

# Cli.run() 将已保存的根 Command 与 Args 交给 dispatch；根与子节点共用同一命令结构。
# 静态声明适配及方法调用仍须 README.md 的 compile.assembly 供应与核验。
# prepare 完成命令选择、参数检查和帮助生成，期间不调用 binding.invoke。
# 只有 Invoke 分支调用业务函数，调用一次并原样传播 Exit。
#
# Examples
# Given: root 为默认帮助根，唯一直接子节点 run 无子命令，绑定完整 run(repository: Str) -> Exit；该函数返回 Failure。
# ```spore
# dispatch(root, Args { program: "bootstrap", values: ["run", "my repo"] })
# ```
# Expect: 只调用该 run 一次，传入完整的 "my repo"；返回 Exit.Failure；平台不会再写帮助或业务错误诊断。
pub fn dispatch(root: Command, args: Args) -> Exit {
    match prepare(root, args) {
        Decision.Invoke { binding: let binding, values: let values } =>
            binding.invoke(values),
        Decision.Help { text: let text } =>
            emit(Channel.Stdout {}, text, Exit.Success {}),
        Decision.Usage { message: let message } =>
            emit(Channel.Stderr {}, message, Exit.Usage {})
    }
}

# 写出失败覆盖原定退出结果；不能把帮助或诊断写出失败报成成功。
#
# Examples
# Given: stdout 可完整写入并刷新。
# ```spore
# emit(Channel.Stdout {}, "ready\n", Exit.Success {})
# ```
# Expect: stdout 恰写出 ready 和一个换行，stderr 为空；返回 Exit.Success。
#
# Given: stdout 写入前两个字节后发生永久故障；宿主准确报告已写字节数。
# ```spore
# emit(Channel.Stdout {}, "ready\n", Exit.Success {})
# ```
# Expect: 返回 Exit.Failure；已写前缀不重放，也不向 stderr 追加另一份文本。
pub fn emit(channel: Channel, text: Str, on_success: Exit) -> Exit {
    if write_text(channel, text) { on_success } else { Exit.Failure {} }
}

# 纯映射；返回 Int 不等于已向 OS 设置进程状态，见 host.lifecycle。
#
# Examples
# ```spore
# (exit_code(Exit.Success {}), exit_code(Exit.Failure {}), exit_code(Exit.Usage {}))
# ```
# Expect: 结果为 (0, 1, 2)；此纯计算没有改变实际进程退出状态。
pub fn exit_code(exit: Exit) -> Int {
    match exit {
        Exit.Success {} => 0,
        Exit.Failure {} => 1,
        Exit.Usage {} => 2
    }
}
