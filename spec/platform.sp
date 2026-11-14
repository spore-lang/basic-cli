# basic-cli 新版 platform：启动、命令调用与退出的宏观契约。
# MLTT 基线；type / case、显式 let 模式，普通类型参数使用 Type。
# operations.sp 定义下列数据与三个函数 hole；README.md 登记编译与运行集成 hole。
# 文件间名字装配仍待实现，不能把按阅读顺序出现当作已经导入。
# 此处的运行层函数签名不授予在 MLTT 证明求值中执行 I/O 或任意回调的能力。

# 宿主调用固定适配入口；entry 由编译期装配产生，不要求应用 main 为 pub。
# 单命令 entry 先解析再调用带业务参数的 main；多命令 entry 调用 main(args)。
# read_args 只读一次输入；输入失败时不进入应用。只有正常返回路径产生此退出码。
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

# 编译后的命令注册链使用这个调用关系。
# prepare 完成命令选择、参数检查和帮助生成，期间不调用 binding.invoke。
# 只有 Invoke 分支调用业务函数，调用一次并原样传播 Exit。
pub fn dispatch(interface: Interface, args: Args) -> Exit {
    match prepare(interface, args) {
        Decision.Invoke { binding: let binding, values: let values } =>
            binding.invoke(values),
        Decision.Help { text: let text } =>
            emit(Channel.Stdout {}, text, Exit.Success {}),
        Decision.Usage { message: let message } =>
            emit(Channel.Stderr {}, message, Exit.Usage {})
    }
}

# 写出失败覆盖原定退出结果；不能把帮助或诊断写出失败报成成功。
pub fn emit(channel: Channel, text: Str, on_success: Exit) -> Exit {
    if write_text(channel, text) { on_success } else { Exit.Failure {} }
}

# 纯映射；返回 Int 不等于已向 OS 设置进程状态，见 host.lifecycle。
pub fn exit_code(exit: Exit) -> Int {
    match exit {
        Exit.Success {} => 0,
        Exit.Failure {} => 1,
        Exit.Usage {} => 2
    }
}
