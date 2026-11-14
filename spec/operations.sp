# basic-cli 首版数据、名称比较与完整函数 hole。
# Str / Int / Bool 为选定语言基线的内建数据；不另造宇宙、公设或空的宿主类型。
# List 使用 Spore Spec 指定的标准库声明；[] 展开到同一类型，不在平台内复制定义。
# 标准库装配和元素类型推断仍由 compile.assembly / validation.evidence 提供实现与验证。

# 一次调用的已解码输入快照；仍未选择命令、检查元数或处理 --help / --。
# Args 只携带输入数据；命令定义、参数 schema 与业务权限都不由它提供。
# Examples
# Given: 启动器传入 argv = ["bootstrap", "run", "my repo"]；引号已由启动器处理。
# ```spore
# Args {
#     program: "bootstrap",
#     values: ["run", "my repo"]
# }
# ```
# Expect: values 中只有两个元素；"my repo" 保持为一个参数。此构造表达式本身不读取进程输入。
#
# ```spore
# Args { program: "bootstrap", values: [] }
# ```
# Expect: values 的类型由字段约束确定为 List[Str]，内容为空；尚未选择命令或检查命令是否缺失。
pub type Args {
    # program 只用于展示，不能作为可信路径或权限依据。
    pub field program: Str;
    # values 不包含 argv[0]；保留顺序、空字符串和每个参数的边界。
    pub field values: List[Str];
}

pub type Exit {
    cases {
        case Success;
        case Failure;
        case Usage;
    }
}

pub type Channel {
    cases {
        case Stdout;
        case Stderr;
    }
}

# Binding 是编译器生成的内部表示，不要求应用重复声明命令或参数结构。
# compile.bindings 必须从同一已检查函数产生声明名、参数名和调用适配器。
# name 保存函数声明名，供 Auto 在名称比较和帮助中读取；运行路径保留实际消费的名称，根帮助前缀使用 Args.program。
# invoke 只接受 prepare 已核对元数的值，并在调用时才进入业务函数。
pub type Binding {
    pub field name: Str;
    pub field parameters: List[Str];
    pub field invoke: List[Str] -> Exit;
}

# 编译后的自身动作；Help 由 prepare 结合当前节点与路径产生，不伪装成业务回调。
pub type Handler {
    cases {
        case Help;
        case Function { pub field binding: Binding; }
    }
}

# Any 在子命令位置匹配一个普通输入元素；与 Exact / Auto 一同按列表顺序选择，由路由层消费匹配的元素。
# --help / -- 及以 - 开头的未转义输入仍按既有控制规则处理；Any 不截获它们。
# 根由 cli 直接指定，根的 Any 不消费 Args.values；选中子节点后，实际消费的词进入帮助与诊断路径。
# 显式名称写 CommandName.Exact { value: "run" }；name 字段不接受裸 Str。
# Auto 保留在命令值中，比较时使用已有 Binding.name，不反射普通函数值，也不调用业务。
pub type CommandName {
    cases {
        case Exact { pub field value: Str; }
        case Any;
        case Auto;
    }
}

# 统一命令节点；自身动作与子命令可以同时存在，运行前须完成所有静态声明适配。
# 源声明 Command { handler: f } 由 compile.bindings 先取得 f 的声明名并生成 Handler.Function。
# 因此 f 不是直接具有 Handler 类型；这个表面适配仍待实现，不是普通函数值的隐式转换。
# name 的常量默认值为 Auto，显式 Auto 与省略完全等价；编译期只生成绑定，不改写名称 case。
# Help 没有函数声明名：非根 Auto 拒绝；根保留 Auto，因为根不参与名称匹配。
# cli 指定的根不消费自身名称；三种 case 都从节点正文开始，根帮助前缀仍取 Args.program。
# 三个字段的默认初值都是常量，不访问正在构造的实例或其他字段。
# 所有异签名函数适配后均进入 List[Command]，普通列表仍保持同质。
#
# Examples
# Given: run 是完整具名函数 run(repository: Str) -> Exit，静态声明适配已实现。
# ```spore
# Command { name: CommandName.Auto {}, handler: run }
# ```
# Expect: 与省略 name 等价；name 保持 Auto，Binding.name 为 "run"，构造期间不调用 run。
pub type Command {
    pub field name: CommandName = CommandName.Auto {};
    pub field handler: Handler = Handler.Help {};
    pub field subcommands: List[Command] = [];
}

# 只比较名称；路由层先处理 --help / -- 与未转义选项，再对直接子节点按顺序调用。
# 不消费输入、不生成帮助、不调用业务；根不经过此比较。
# Help 没有声明名，Auto / Help 比较为 false；有效的非根 Auto 在静态装配时已要求 Function。
#
# Examples
# Given: command.name = CommandName.Exact { value: "execute" }，handler 绑定完整 run(repository: Str) -> Exit。
# ```spore
# (matches_name(command, "execute"), matches_name(command, "run"))
# ```
# Expect: 结果为 (true, false)；显式名称只影响路由，Binding.name 仍为 "run"，业务调用为零。
#
# Given: command.name = CommandName.Auto {}，handler 绑定同一完整 run 函数。
# ```spore
# (matches_name(command, "run"), matches_name(command, "execute"))
# ```
# Expect: 结果为 (true, false)；name 保持 Auto，读取 Binding.name，不调用 run。
#
# Given: command.name = CommandName.Any {}，handler 为 Help。
# ```spore
# (matches_name(command, "other"), matches_name(command, ""))
# ```
# Expect: 结果为 (true, true)；空字符串是一个完整输入元素；本函数不消费它，也不输出帮助。
fn matches_name(command: Command, input: Str) -> Bool {
    match (command.name, command.handler) {
        (CommandName.Exact { value: let expected }, _) => input == expected,
        (CommandName.Any {}, _) => true,
        (CommandName.Auto {}, Handler.Function { binding: let binding }) => input == binding.name,
        (CommandName.Auto {}, Handler.Help {}) => false
    }
}

pub type Input {
    cases {
        case Ready { pub field args: Args; }
        case Usage { pub field message: Str; }
        case Failure { pub field message: Str; }
    }
}

pub type Decision {
    cases {
        case Invoke { pub field binding: Binding; pub field values: List[Str]; }
        case Help { pub field text: Str; }
        case Usage { pub field message: Str; }
    }
}

#
# Examples
# Given: 宿主 argv 为 ["bootstrap", "run", "my repo", ""]，编码有效。
# ```spore
# read_args()
# ```
# Expect: 返回 Ready(Args)，program 为 "bootstrap"，values 依次为 "run"、"my repo"、""；不裁剪或再次拆词，不输出终端。
#
# Given: Unix 宿主原始参数中包含非法 UTF-8 字节 0xff。
# ```spore
# read_args()
# ```
# Expect: 返回 Input.Usage；不返回 Ready，不写 stdout / stderr，不调用业务函数。
pub fn read_args() -> Input {
    # hole: host.arguments
    # 输入：宿主提供的本次原始 argv；本函数不得读取环境变量、业务文件或启动业务。
    # 产出：解码后返回 Ready；program 来自 argv[0]，其余参数逐项进入 values；缺失 argv[0] 时显示 basic-cli。
    # 约束：首版只接受可无损转换为 Str 的 Unicode 输入；Unix 严格 UTF-8，Windows 拒绝未配对 UTF-16 代理项。
    # 保真：不使用替换字符，不再次按 shell 拆词，不展开变量、通配符或 @文件，不裁剪空白和空参数。
    # 失败：编码不满足约束返回 Usage；读取机制故障返回 Failure。诊断由 main_for_host 输出，本函数不写终端。
    # 验收：无参、中文、含空格与空字符串保持形状；非法编码返回 Usage 且应用调用次数为零。
    _
}

#
# Examples
# Given: root 是 name 为 Auto 的默认帮助根，唯一直接子节点 run 同样保留 Auto、无子命令，绑定完整 run(repository: Str) -> Exit。
# ```spore
# prepare(root, Args { program: "bootstrap", values: ["run", "my repo"] })
# ```
# Expect: 返回 Invoke，同一 run Binding 的 values 仅有 "my repo"；根跳过名称比较，子节点按 Binding.name 匹配；Auto 均保持原值，不调用 invoke，不写终端。
#
# Given: 同一 root。
# ```spore
# prepare(root, Args { program: "bootstrap", values: ["run", "--", "--help"] })
# ```
# Expect: 返回 Invoke，业务 values 仅有字面字符串 "--help"；不产生 Help。
#
# Given: 同一 root。
# ```spore
# prepare(root, Args { program: "bootstrap", values: ["run", "repo", "--help"] })
# ```
# Expect: 返回 Usage；不忽略多余参数、不调用 run，也不写终端。
#
# Given: 同一 root，根 handler 为 Help。
# ```spore
# prepare(root, Args { program: "bootstrap", values: [] })
# ```
# Expect: 返回根 Help，与 values = ["--help"] 的帮助文本完全相同；不调用 run，不写终端。
#
# Given: 同一 root，根 handler 为 Help。
# ```spore
# prepare(root, Args { program: "bootstrap", values: ["--help"] })
# ```
# Expect: 返回根 Help，与空 values 的帮助文本完全相同；不默认选择命令，不调用 run，不写终端。
#
# Given: root 唯一的 agent 子节点仅含 skill 子节点，两者 handler 均为 Help；skill 仅含无子命令的 train 节点，完整 train(employee: Str, skill: Str) -> Exit 已生成绑定。
# ```spore
# prepare(root, Args { program: "bootstrap", values: ["agent", "skill", "train", "reviewer", "rust"] })
# ```
# Expect: 返回 train 的 Invoke，values 恰为 ["reviewer", "rust"]；路径三段均已消费，没有业务调用。
#
# Given: 同一命令树。
# ```spore
# prepare(root, Args { program: "bootstrap", values: ["agent", "skill", "--help"] })
# ```
# Expect: 返回该组的 Help，含完整前缀 bootstrap agent skill 及 train 签名；不列其他组的命令，不调用业务。
#
# Given: 同一命令树。
# ```spore
# prepare(root, Args { program: "bootstrap", values: ["agent", "skill"] })
# ```
# Expect: 返回 skill 的 Help，与该节点单独 --help 的文本相同；不选择 train，不调用业务。
#
# Given: 同一命令树，agent 没有名为 missing 的子命令。
# ```spore
# prepare(root, Args { program: "bootstrap", values: ["agent", "missing"] })
# ```
# Expect: 返回 agent 层级的 Usage；缺省 Help 不吞掉未知名称，也不搜索其他分支。
#
# Given: root 唯一的 run 子节点自身接受一个 Str，且仅有零参数子命令 subcommand，后者无子命令；函数完整，均已生成绑定。
# ```spore
# prepare(root, Args { program: "bootstrap", values: ["run", "subcommand"] })
# ```
# Expect: 返回 subcommand 的 Invoke，values 为空；不选择 run 的自身动作，不调用任何业务函数。
#
# Given: 同一带自身动作的 run 节点。
# ```spore
# prepare(root, Args { program: "bootstrap", values: ["run", "--", "subcommand"] })
# ```
# Expect: 返回 run 的 Invoke，values 恰为 ["subcommand"]；-- 同时停止路由与选项识别。
#
# Given: 同一带自身动作的 run 节点；没有名为 some_arg 的子命令。
# ```spore
# prepare(root, Args { program: "bootstrap", values: ["run", "some_arg", "subcommand"] })
# ```
# Expect: 返回 run 的多参 Usage；开始自身参数解析后，不再把 subcommand 当作路径。
#
# Given: run 的自身函数接受一个 Str；其 subcommand 子节点也接受一个 Str。
# ```spore
# prepare(root, Args { program: "bootstrap", values: ["run", "subcommand"] })
# ```
# Expect: 返回 subcommand 缺参的 Usage；不回退到 run，不尝试任何业务调用。
#
# Given: root 的前两个子节点都名为 run，均无子命令；first 接受两个 Str，second 接受一个 Str，均已生成绑定。
# ```spore
# prepare(root, Args { program: "bootstrap", values: ["run", "repo"] })
# ```
# Expect: 选定 first 后返回缺参 Usage；不尝试 second 的可匹配签名，也不调用 first。
#
# Given: root 的前两个子节点都名为 run，均无子命令；first、second 都接受一个 Str，均已生成绑定。
# ```spore
# prepare(root, Args { program: "bootstrap", values: ["run", "repo"] })
# ```
# Expect: 返回 first 的 Invoke，values 为 ["repo"]；保持声明顺序，不合并同名子树。
#
# Given: root 的直接子列表依次为 Any(first)、Exact("run", second)，两节点均无子命令、各接受一个 Str，绑定完整。
# ```spore
# prepare(root, Args { program: "bootstrap", values: ["run", "repo"] })
# ```
# Expect: 返回 first 的 Invoke，values 恰为 ["repo"]；Any 消费 run，不优先选择后面的 Exact，也不把 run 传给处理函数。
#
# Given: root 的直接子列表依次为 Exact("run", first)、Any(second)，两节点均无子命令、各接受一个 Str，绑定完整。
# ```spore
# prepare(root, Args { program: "bootstrap", values: ["other", "repo"] })
# ```
# Expect: 返回 second 的 Invoke，values 恰为 ["repo"]；实际消费的 other 成为当前路径，原始 Args 保持不变。
#
# Given: root 的 handler 为 Help，唯一直接子节点为 Any，绑定完整零参数函数，子节点无子命令。
# ```spore
# prepare(root, Args { program: "bootstrap", values: [] })
# ```
# Expect: 返回根 Help；Any 需要一个输入元素，不能在空输入时自动进入。
#
# Given: 同一默认帮助根与 Any 子节点。
# ```spore
# prepare(root, Args { program: "bootstrap", values: ["--help"] })
# ```
# Expect: 返回根 Help；Any 不消费 --help，也不选择子节点的函数。
#
# Given: 同一默认帮助根与 Any 子节点。
# ```spore
# prepare(root, Args { program: "bootstrap", values: ["--", "other"] })
# ```
# Expect: 返回根自身 Help 动作的多余参数 Usage；-- 停止路由，Any 不消费 other。
#
# Given: root 仅含一个 Any 子节点，该节点仅含名为 status 的子节点并绑定完整零参数函数；所有自身动作均完整。
# ```spore
# prepare(root, Args { program: "bootstrap", values: ["project-1", "status", "--help"] })
# ```
# Expect: 返回 status 的 Help，完整路径为 bootstrap project-1 status；不把 Any 或函数声明名当作实际消费的词。
#
# Given: root 的自身函数是完整的 start() -> Exit，没有子命令。
# ```spore
# prepare(root, Args { program: "bootstrap", values: [] })
# ```
# Expect: 返回 start 的 Invoke，values 为空；设置根函数后不再把空输入直接变成 Help。
#
# Given: 同一自定义根。
# ```spore
# prepare(root, Args { program: "bootstrap", values: ["--help"] })
# ```
# Expect: 返回根 Help，前缀为 bootstrap；不调用 start，也不要求输入 start 这个根名称。
#
# Given: root 的自身函数接受一个 Str，没有子命令。
# ```spore
# prepare(root, Args { program: "bootstrap", values: [] })
# ```
# Expect: 返回根函数缺参的 Usage；不以缺省帮助掩盖自定义函数的参数要求。
#
# Given: root.name 为 Any，自身绑定完整 init() -> Exit，直接子列表为三个零参数 init / run / status。
# ```spore
# prepare(root, Args { program: "/tmp/renamed-bootstrap", values: [] })
# ```
# Expect: 返回根 init 的 Invoke，values 为空；不要求启动名为 bootstrap 或 init；prepare 本身不打开交互或创建全局目录。
#
# Given: root 的 handler 为 Help，subcommands 为空。
# ```spore
# prepare(root, Args { program: "bootstrap", values: ["--", "--help"] })
# ```
# Expect: 返回多余字面参数的 Usage；转义后的 --help 不再触发帮助。
pub fn prepare(root: Command, args: Args) -> Decision {
    # hole: cli.prepare
    # 输入：compile.bindings 生成的有效根 Command 和一次已解码 Args；name 保留 Exact / Any / Auto，业务参数均为必填 Str。
    # 产出：合法调用返回同一 Binding 与按声明顺序排列的原值；帮助返回 Help；输入不匹配返回 Usage。
    # 根：cli 已指定根节点，从 args.values 开始，不匹配或消费 root.name；根 Any 不消费一个业务输入。
    # 根：Exact / Any / Auto 都跳过 matches_name，包括无函数的 Auto 根；args.program 只作为输出的调用前缀。
    # 路由顺序一：当前剩余输入恰为 ["--help"] 时返回本节点 Help，不调用任何 handler。
    # 路由顺序二：当前剩余输入以 -- 开头时，移除一次标记，选定本节点自身动作，其余全部按字面值处理。
    # 路由顺序三：有剩余输入且首元素不以 - 开头时，按 subcommands 原顺序调用 matches_name，取首个返回 true 的节点。
    # 路由顺序三：Exact 比较 value，Auto 比较 Binding.name，Any 接受该元素；没有比声明顺序更高的名称模式优先级。
    # 路由顺序三：选定后消费一个原始元素、记录其实际值为路径，并在子节点重复规则。
    # 路由顺序四：无子节点命中或输入为空时，选定当前节点自身动作；之后不再寻找子命令。
    # 提交：名称命中即选定；不按参数元数试探，不合并子树，不因后续错误回退到兄弟节点或父动作。
    # 自身动作：Handler.Function 按 Binding.parameters 核对元数；零参数可以调用，缺参或多参为 Usage。
    # 缺省动作：Handler.Help 只接受空参数（包括移除单独 -- 后为空）；返回与本节点 --help 相同的 Help。
    # 缺省动作：有剩余参数时返回当前节点的 Usage，不吞掉未知名称或多余字面参数；空子列表本身合法。
    # 帮助：显示当前自身动作的参数名、Str 和退出规则，以及按声明顺序列出的全部直接子命令与自身签名。
    # 帮助：Exact 子项显示 value，Auto 子项显示 Binding.name，Any 子项标示为通配项；缺省动作标示为显示帮助。
    # 帮助：重叠匹配项保持原顺序并注明首个优先，不伪装成均可到达的路由。
    # 用法：保留 program 与实际消费的完整命令路径，Any 的已匹配词也须保留；不以 Binding.name 或 Any 的显示标记替换它。
    # 名称保真：Any 消费恰好一个元素，空字符串或含空白元素也不拆分；该词只进入路径，不自动增加处理函数的业务参数。
    # 字面值：-- 在开始自身参数解析前只识别一次；其后 --help、--、-x 都保留原值，不再生成帮助或路由。
    # 错误：未进入字面值模式时，业务参数中以 - 开头的值（包括混用的 --help 或中途出现的 --）返回 Usage。
    # 执行：进入子命令不会调用父动作；参数阶段失败也不能触发回调。每次 dispatch 最多调用选定业务函数一次。
    # 约束：不读取目标文件，不执行 invoke，不根据参数数量猜命令，不补默认值，不静默忽略参数。
    # 验收：README.md 的输入矩阵全部成立；帮助和错误只产生数据，不能触发业务或终端输出。
    _
}

#
# Examples
# Given: 输出流先报告短写两个字节，之后接受剩余字节并成功刷新。
# ```spore
# write_text(Channel.Stdout {}, "ready\n")
# ```
# Expect: 返回 true；stdout 恰得到一次 ready 和一个换行，完成刷新；stderr 为空，不重复已写前缀。
#
# Given: 文本字节已写完，但 stdout 的刷新报告永久失败。
# ```spore
# write_text(Channel.Stdout {}, "ready\n")
# ```
# Expect: 返回 false；不把已经写出的文本重复发送，也不切换输出流补报。
pub fn write_text(channel: Channel, text: Str) -> Bool {
    # hole: host.write
    # 输入：明确的 stdout / stderr 与完整文本；仅写指定流，不增加换行或改写内容。
    # 产出：全部 UTF-8 字节写入并刷新到宿主流后返回 true；允许宿主流再连接到终端、文件或管道。
    # 约束：处理短写；可继续的中断只续写未完成部分；成功不承诺文件持久化或终端已显示。
    # 失败：永久写入或刷新故障返回 false；不在另一个流无限补报，不自动重复整段文本。已写前缀不能回滚。
    # 验收：stdout / stderr 分离，空文本和多字节文本保真；短写不重字节，失败使 emit 返回 Failure。
    _
}
