# basic-cli 的数据、名称匹配与宿主边界契约。
# Str / Int / Bool 为 MLTT 基线内建数据；List 使用 Spore Spec 指定的同一个标准库声明。
# os.Path 使用标准库 os 的唯一声明，本平台不定义或重新导出另一份路径类型。
# 本稿显式定义 Option、OptionalPositional / OptionalNamed 及其必填分支别名；应用导入同一名义类型。

pub type Option[Value: Type] {
    cases {
        pub case None;
        pub case Some { pub field value: Value; }
    }
}

# 必填参数是可选类型的 Some 分支；同一 Value 下可向上用于可选参数及 Option。
# 角色来自形参声明类型，不从上转后的 Option 或运行时分支推断。
pub type OptionalPositional[Value: Type] {
    cases {
        pub case None;
        pub case Some { pub field value: Value; }
    }
}

pub static Positional[Value: Type] = OptionalPositional[Value].Some;

pub type OptionalNamed[Value: Type] {
    cases {
        pub case None;
        pub case Some { pub field value: Value; }
    }
}

pub static Named[Value: Type] = OptionalNamed[Value].Some;

# 两端名义构造器由本包定义；这些公开关联仍须核验分支覆盖、成员和路径一致性。
# Some 经角色根或 Option.Some 到 Option 的路径必须保留同一个 value；None 对应 None。
pub impl[Value: Type] OptionalPositional[Value].None <: Option[Value].None;
pub impl[Value: Type] OptionalPositional[Value].Some <: Option[Value].Some;
pub impl[Value: Type] OptionalPositional[Value] <: Option[Value];
pub impl[Value: Type] OptionalNamed[Value].None <: Option[Value].None;
pub impl[Value: Type] OptionalNamed[Value].Some <: Option[Value].Some;
pub impl[Value: Type] OptionalNamed[Value] <: Option[Value];

pub type Exit {
    cases {
        pub case Success;
        pub case Failure;
        pub case Usage;
    }
}

pub type Channel {
    cases {
        pub case Stdout;
        pub case Stderr;
    }
}

pub type ParameterRole {
    cases {
        pub case Positional;
        pub case Named;
    }
}

# role / optional 来自声明的角色类型：Some 别名必填，角色根可省略；kind 来自 Str / os.Path。
# 例如 output: OptionalNamed[os.Path] 对应 Named / Path / true；名称生成 --output。
pub type ParameterKind {
    cases {
        pub case Text;
        pub case Path;
    }
}

pub type Parameter {
    pub field name: Str;
    pub field role: ParameterRole;
    pub field kind: ParameterKind;
    pub field optional: Bool;
}

# bind 先扫描选项与位置值、核对必填项并解码，再捕获完整角色值；构造 invoke 不调用处理函数。
# 该值的完整提供者为 compile.bindings，不能把函数字段当作自动得到的实现。
pub type ArgumentBinding {
    cases {
        pub case Ready { pub field invoke: () -> Exit; }
        pub case Usage { pub field message: Str; }
    }
}

pub type Binding {
    pub field name: Str;
    # 保留完整形参声明顺序；位置值只按 Positional / OptionalPositional 子序列的顺序绑定。
    pub field parameters: List[Parameter];
    # 输入是选定节点的原始剩余列表，含尚未消费的 --；不含已消费的命令名称。
    # 从左到右扫描：-- 开启字面模式；此前 --name 消费一个非 - 前缀值，其余非 - 前缀值为位置值。
    # 字面模式中的每个 token 都是位置值，包括后续 -- 和 --help；不再匹配选项或子节点。
    # 未知 / 重复选项、缺值、未转义的 - 前缀值、缺必填、多余位置值或解码失败均返回 Usage。
    # Str 原样保留；os.Path 先拒绝空文本 / NUL，再以 os.Path.from_text 编码。省略可选参数构造对应角色的 None，提供值构造其 Some。
    # 成功按原形参顺序捕获实参；纯、确定、终止、零 I/O，不以调用业务来试探绑定结果。
    pub field bind: List[Str] -> ArgumentBinding;
}

pub type Handler {
    cases {
        pub case Help;
        pub case Function { pub field binding: Binding; }
    }
}

# Exact / Auto 比较一个名称，Any 接受一个名称；消费行为由 prepare 统一负责。
# 名称 token 只进入已消费路径，不自动成为业务参数。Any 既不匹配零个，也不吞掉多个 token。
pub type CommandName {
    cases {
        pub case Exact { pub field value: Str; }
        pub case Any;
        pub case Auto;
    }
}

# handler: f 的源声明由 compile.bindings 适配为 Handler.Function；普通函数值不是 Handler。
# 所有节点（包括根）均须有可匹配名称：Help + Auto 无声明名，装配时拒绝。
# 字段默认值为常量；构造、引用和选择方法不解析参数或执行业务。
pub type Command {
    pub field name: CommandName = CommandName.Auto {};
    pub field handler: Handler = Handler.Help {};
    pub field subcommands: List[Command] = [];

    # args 是从本节点名称开始的完整列表；应用入口直接传入完整宿主 argv。
    # Examples
    # Given: root 为 Any 根，默认 Help，唯一子节点绑定完整 run(repository: OptionalPositional[os.Path]) -> Exit；run 返回 Success。
    # ```spore
    # root.run(["bootstrap", "run", "my repo"])
    # ```
    # Expect: 消费 bootstrap 和 run；仅调用 run(OptionalPositional.Some(os.Path.from_text("my repo"))) 一次，返回 Success。
    #
    # Given: 同一 root，正常输出。
    # ```spore
    # root.run([])
    # ```
    # Expect: 缺少本节点名称，返回 Usage；不默认显示帮助，不调用业务。
    #
    # Given: named.name 为 Exact("run")，绑定同一可选目录函数，无子命令。
    # ```spore
    # named.run(["run", "repo"])
    # ```
    # Expect: 此子树作为入口时仍匹配并消费 run；handler 只收到 OptionalPositional.Some(os.Path.from_text("repo"))。
    pub method run(args: List[Str]) -> Exit {
        dispatch(self, args)
    }
}

# 纯名称比较，不消费输入、不解释控制标记、不生成帮助、不调用业务。
# 根与子节点使用同一比较；控制标记只在一个节点已经匹配后的剩余输入中解释。
# Examples
# Given: command.name 为 Exact("execute")，handler 绑定完整 run(repository: Positional[Str]) -> Exit。
# ```spore
# (matches_name(command, "execute"), matches_name(command, "run"))
# ```
# Expect: (true, false)；函数声明名不成为第二个入口名称。
#
# Given: command.name 为 Auto，handler 绑定同一 run。
# ```spore
# (matches_name(command, "run"), matches_name(command, "execute"))
# ```
# Expect: (true, false)；Auto 保持原值，读取 Binding.name。
#
# Given: command.name 为 Any，handler 为 Help。
# ```spore
# (matches_name(command, "bootstrap"), matches_name(command, ""))
# ```
# Expect: (true, true)；每个字符串都是一个 token，不拆词，也不读取宿主程序名。
fn matches_name(command: Command, input: Str) -> Bool {
    match (command.name, command.handler) {
        (CommandName.Exact { value: let expected }, _) => text_equal(input, expected),
        (CommandName.Any {}, _) => true,
        (CommandName.Auto {}, Handler.Function { binding: let binding }) => text_equal(input, binding.name),
        (CommandName.Auto {}, Handler.Help {}) => false
    }
}

# 命题等同与可执行判定分开；名称比较需要 Bool，不改变语言中 == 的含义。
# Examples
# ```spore
# (text_equal("run", "run"), text_equal("run", "RUN"), text_equal("é", "é"))
# ```
# Expect: (true, false, false)；最后两串的 Unicode 标量序列不同，不做规范化。
fn text_equal(left: Str, right: Str) -> Bool {
    # hole: text.equal
    # 输入：两个有效 Str；产出：仅当完整 Unicode 标量序列相同才为 true，否则为 false。
    # 条件：纯、全定义、确定且终止；允许空串，不裁剪、不折叠大小写、不做路径或 Unicode 规范化。
    # 失败：无业务失败分支；实现缺失或不能保持上述语义时装配拒绝，不能用 == 的命题值冒充 Bool。
    # 验收：相同串、空串、前缀差异、大小写及规范等价但标量不同的串得到精确布尔值，零 I/O。
    _
}

pub type Input {
    cases {
        pub case Ready { pub field args: List[Str]; }
        pub case Usage { pub field message: Str; }
        pub case Failure { pub field message: Str; }
    }
}

pub type Decision {
    cases {
        pub case Invoke { pub field invoke: () -> Exit; }
        pub case Help { pub field text: Str; }
        pub case Usage { pub field message: Str; }
    }
}

# Examples
# Given: 宿主 argv 为 ["bootstrap", "run", "my repo", ""]，编码有效。
# ```spore
# read_args()
# ```
# Expect: Ready.args 恰为原四元素列表；首项保留，空字符串与空白不被裁剪或重拆。
#
# Given: 宿主提供空 argv。
# ```spore
# read_args()
# ```
# Expect: 返回 Ready([])，不补程序名；后续 Command.run([]) 报缺少名称。
#
# Given: Unix 宿主 argv[1] 含非法 UTF-8 字节 0xff。
# ```spore
# read_args()
# ```
# Expect: 返回 Usage；不以替换字符构造路径，不输出、不调用应用。
pub fn read_args() -> Input {
    # hole: host.arguments
    # 输入：宿主本次完整原始 argv；首项与后续项使用相同的无损解码过程。
    # 产出：一次读取后返回同序 List[Str]，保留首项及每个参数边界；空列表仍为空。
    # 约束：本平台当前只支持 Unix 的有效 UTF-8 argv；非 UTF-8 argv 为 Usage，不能据此限制标准库 os.Path 的字节域。
    # 保真：不补或取出程序名，不替换非法字符，不再按 shell 拆词，不展开变量、通配符或 @文件。
    # 失败：编码不满足约束返回 Usage，读取机制故障返回 Failure；本函数不写终端或读业务配置。
    # 验收：空列表、首项、中文、含空格与空字符串均保真；非法编码的应用调用次数为零。
    _
}

# 下列 root 除非另行说明均为显式 Any 根；Given 中的处理函数与 Binding 是须供应的完整夹具。
# Examples
# Given: root 默认 Help，唯一子节点绑定完整 run(repository: OptionalPositional[os.Path]) -> Exit，无子命令。
# ```spore
# prepare(root, ["bootstrap", "run", "my repo"])
# ```
# Expect: Invoke 捕获 run 和 OptionalPositional.Some(os.Path.from_text("my repo"))；当前不调用 handler，不写终端。
#
# Given: 同一 root。
# ```spore
# prepare(root, ["bootstrap", "run"])
# ```
# Expect: Invoke 捕获 run 和 OptionalPositional.None；不会产生缺参 Usage，也不替业务选择当前目录。
#
# Given: 同一 root。
# ```spore
# prepare(root, ["bootstrap", "run", "a", "b"])
# ```
# Expect: 多参 Usage；不调用业务，不丢弃 b。
#
# Given: 同一 root。
# ```spore
# prepare(root, ["bootstrap", "run", ""])
# ```
# Expect: 空路径 Usage；一个显式空参数不等于缺省 None。
#
# Given: 同一 root。
# ```spore
# prepare(root, ["bootstrap", "run", "--", "--help"])
# ```
# Expect: Invoke 捕获 OptionalPositional.Some(os.Path.from_text("--help"))；不产生帮助，不访问这个路径。
#
# Given: 同一 root。
# ```spore
# prepare(root, ["bootstrap", "run", "repo", "--help"])
# ```
# Expect: Usage；不忽略多余参数，不调用业务。
#
# Given: 同一 root。
# ```spore
# prepare(root, ["bootstrap", "run", "repo", "--"])
# ```
# Expect: Invoke 捕获 run(OptionalPositional.Some(os.Path.from_text("repo")))；末尾 -- 开启空的字面后缀，不增加位置值。
#
# Given: 同一 root。
# ```spore
# prepare(root, ["bootstrap", "run", "--repository", "repo"])
# ```
# Expect: 未知选项 Usage；Positional 不因为有形参名而接受 --repository。
#
# Given: 同一 root。
# ```spore
# (prepare(root, ["bootstrap"]), prepare(root, ["bootstrap", "--help"]))
# ```
# Expect: 相同根 Help，前缀均来自已消费的 bootstrap；没有业务调用。
#
# Given: 同一 root。
# ```spore
# prepare(root, [])
# ```
# Expect: 缺少根名称的 Usage；不显示缺省帮助，不调用 handler。
#
# Given: named.name 为 Exact("tool")，默认 Help，没有子命令。
# ```spore
# (prepare(named, ["tool"]), prepare(named, ["other"]))
# ```
# Expect: 前者匹配并消费 tool 后返回 Help；后者名称不匹配 Usage，不跳过根名称。
#
# Given: named.name 为 Auto，绑定完整 status() -> Exit，没有子命令。
# ```spore
# (prepare(named, ["status"]), prepare(named, ["bootstrap"]))
# ```
# Expect: 前者捕获 status 的零参调用；后者 Usage，根 Auto 同样按 Binding.name 匹配。
#
# Given: root 默认 init(repository: OptionalPositional[os.Path])，三个同签名 init / run / status 子节点，均无子命令。
# ```spore
# prepare(root, ["/tmp/renamed-bootstrap", "repo"])
# ```
# Expect: Any 消费完整启动路径；没有子命令名匹配 repo，Invoke 捕获 init(OptionalPositional.Some(os.Path.from_text("repo")))。
#
# Given: 同一 root。
# ```spore
# prepare(root, ["bootstrap", "--", "run"])
# ```
# Expect: Invoke 捕获 init(OptionalPositional.Some(os.Path.from_text("run")))，不进入 run 子命令。
#
# Given: root 默认 Help，agent / skill 组为 Help，train(employee: Positional[Str], skill: Positional[Str]) 为完整函数。
# ```spore
# prepare(root, ["bootstrap", "agent", "skill", "train", "reviewer", "rust"])
# ```
# Expect: 依次消费四个名称；Invoke 仅捕获 train(Positional("reviewer"), Positional("rust"))。
#
# Given: 同一 root。
# ```spore
# prepare(root, ["bootstrap", "agent", "skill", "--help"])
# ```
# Expect: Help 的实际路径为 bootstrap agent skill，列出 train 的签名；不调用业务。
#
# Given: root 的 run(target: Positional[Str]) 节点含 subcommand(target: Positional[Str]) 子节点，所有函数完整。
# ```spore
# prepare(root, ["bootstrap", "run", "subcommand"])
# ```
# Expect: 子节点缺参 Usage；不回退到父 run，也不把 subcommand 重新解释为父参数。
#
# Given: 同一 root。
# ```spore
# prepare(root, ["bootstrap", "run", "--", "subcommand"])
# ```
# Expect: Invoke 捕获父 run(Positional("subcommand"))；-- 停止子命令选择。
#
# Given: root 的子列表依次为 Any(first)、Exact("run", second)，两者均接受一个 Positional[Str]、无子命令。
# ```spore
# prepare(root, ["bootstrap", "run", "repo"])
# ```
# Expect: 首个 Any 消费 run，捕获 first(Positional("repo"))；不优先选择 Exact 节点。
#
# Given: root 的子列表依次为 Auto(first)、Exact("first", second)；first 接受两个 Positional[Str]，second 接受一个 Positional[Str]。
# ```spore
# prepare(root, ["bootstrap", "first", "repo"])
# ```
# Expect: 首个节点的缺参 Usage；不尝试 second，不调用 first。
#
# Given: root 默认 Help，只有一个 Any 子节点，其下有完整零参 status 子命令。
# ```spore
# prepare(root, ["bootstrap", "project-1", "status", "--help"])
# ```
# Expect: Help 使用 bootstrap project-1 status；Any 消费的值不被通配标记替换。
#
# Given: root 默认 Help，唯一 Any 子节点绑定完整零参函数，无子命令。
# ```spore
# prepare(root, ["bootstrap", ""])
# ```
# Expect: Any 子节点消费一个空字符串 token 并捕获零参调用；不是空列表，也不是空路径参数。
#
# Given: 同一 root。
# ```spore
# prepare(root, ["bootstrap", "--", "other"])
# ```
# Expect: 根 Help 动作的多余参数 Usage；Any 子节点不截获 -- 或 other。
#
# Given: root 默认 Help，唯一子节点绑定完整 build(source: Positional[os.Path], output: Named[os.Path]) -> Exit，无子命令；build 返回 Success。
# ```spore
# (prepare(root, ["tool", "build", "src", "--output", "dist"]), prepare(root, ["tool", "build", "--output", "dist", "src"]))
# ```
# Expect: 两者均捕获 build(Positional(os.Path.from_text("src")), Named(os.Path.from_text("dist")))；调用次序遵循声明，prepare 不调用业务。
#
# Given: 同一 root。
# ```spore
# prepare(root, ["tool", "build", "--output", "dist", "--", "--help"])
# ```
# Expect: 捕获 source.value.text 为 --help、output.value.text 为 dist；保留并消费中途 --，不显示帮助。
#
# Given: 同一 root。
# ```spore
# prepare(root, ["tool", "build", "src"])
# ```
# Expect: 缺少必填 --output 的 Usage；Named 不表示可选。
#
# Given: 同一 root。
# ```spore
# (prepare(root, ["tool", "build", "src", "--output"]), prepare(root, ["tool", "build", "src", "--output", "--help"]))
# ```
# Expect: 两者均为 --output 缺值 Usage；不把 --help 当作值或帮助请求。
#
# Given: 同一 root。
# ```spore
# prepare(root, ["tool", "build", "src", "--output", "dist", "--output", "dist"])
# ```
# Expect: 重复 --output 的 Usage，即使值相同也不接受；不调用业务。
#
# Given: 同一 root。
# ```spore
# (prepare(root, ["tool", "build", "src", "--unknown", "dist"]), prepare(root, ["tool", "build", "src", "--output=dist"]))
# ```
# Expect: 两者均为未知选项 Usage，不猜测拼写、不拆开等号形式。
#
# Given: 同一 root。
# ```spore
# prepare(root, ["tool", "build", "--", "src", "--output", "dist"])
# ```
# Expect: Usage；-- 后三项全为位置值，不能重新识别 --output 以满足必填选项。
#
# Given: 同一 root。
# ```spore
# (prepare(root, ["tool", "build", "src", "--output", ""]), prepare(root, ["tool", "build", "src", "--output", "-dist"]))
# ```
# Expect: 前者为空路径 Usage，后者为命名选项缺值 Usage；首版不接受 - 前缀命名值。
#
# Given: root 默认 Help，唯一子节点绑定完整 inspect(label: OptionalNamed[Str], source: OptionalPositional[os.Path]) -> Exit，无子命令；inspect 返回 Success。
# ```spore
# prepare(root, ["tool", "inspect"])
# ```
# Expect: 捕获 inspect(OptionalNamed.None, OptionalPositional.None)；两个省略值各自保留 OptionalNamed / OptionalPositional 身份。
#
# Given: 同一 root。
# ```spore
# prepare(root, ["tool", "inspect", "src", "--label", ""])
# ```
# Expect: 按声明顺序捕获 OptionalNamed.Some("")、OptionalPositional.Some(os.Path.from_text("src"))；空 Str 是显式值，不是 None。
#
# Given: 同一 root。
# ```spore
# prepare(root, ["tool", "inspect", "src", "--label"])
# ```
# Expect: --label 缺值 Usage；可选只允许完全省略选项，不能省略已出现选项的值。
#
# Given: 同一 root。
# ```spore
# prepare(root, ["tool", "inspect", "--help"])
# ```
# Expect: 帮助含 [--label <value>]: Str 与 [source]: os.Path，保留声明顺序，不运行 bind。
pub fn prepare(root: Command, args: List[Str]) -> Decision {
    # hole: cli.prepare
    # 输入：compile.bindings 生成的有效 Command 与从其名称开始的已解码列表；不假设另有 program 字段。
    # 进入节点：空列表为缺少名称 Usage；否则 matches_name 比较首项，不匹配为 Usage，匹配后消费恰好一项。
    # 统一性：根、子节点和独立复用的子树都走同一进入规则；没有根名称豁免，不补任何名称 token。
    # 路径：每次成功进入追加实际消费的原 token；名称只进入路径，不进入处理函数的业务实参。
    # 路由一：进入后余项恰为 ["--help"] 时返回当前 Help，不运行 bind 或 handler。
    # 路由二：余项以独立 -- 开头时选择当前自身动作，停止路由；保留标记交给当前动作的参数扫描。
    # 路由三：否则首个余项存在且不以 - 开头，按子列表顺序比较名称，首个命中者进入同一匹配消费步骤。
    # 路由三：Exact / Any / Auto 无额外优先级；Any 的比较接受任意一个字符串，不拆分或增加业务实参。
    # 路由四：无子节点命中或余项为空时选择当前自身动作；开始参数绑定后不再寻找子命令。
    # 提交：名称选中后不按元数、类型或后续路径回退，不合并同名子树，也不执行父动作。
    # 绑定：Function 把原始余项完整交给 binding.bind 一次，包括首项或中途的 --，不预先删除或重排选项。
    # 绑定：Named 按 --形参名取值，Positional 按位置子序列取值；声明为角色根或 Some 分支决定能否省略，不改变角色。
    # 绑定：ArgumentBinding.Ready 的完整闭包进入 Decision.Invoke；Usage 附加当前实际路径后返回，不调用闭包。
    # 缺省：Help 只接受空余项或恰为 ["--"]，返回与当前 --help 相同的帮助；其他余项均 Usage。
    # 控制：--help 只在上述独占余项时显示帮助；混用且未被 -- 转义时 Usage，不成为 Named 参数名。
    # 帮助：由同一 Binding.parameters 生成；位置必填 <name>: T，可选 [name]: T。
    # 帮助：命名必填 --name <value>: T，可选 [--name <value>]: T；T 为 Str 或 os.Path。
    # 帮助：Exact 显示 value，Auto 显示 Binding.name，Any 子项标示通配；已选路径始终保留实际消费值。
    # 帮助：保留兄弟顺序并注明首个匹配优先；根名称不匹配时报告实际输入与期望名称，不虚构已消费路径。
    # 约束：纯数据处理；不读终端、文件或环境，不执行 invoke，不取 basename，不裁剪或重写输入。
    # 验收：README.md 矩阵成立；构造、帮助、路由和解码失败均为零业务调用，合法分派只捕获一次调用。
    _
}

# Examples
# Given: 输出流先报告短写两个字节，随后接受剩余字节并成功刷新。
# ```spore
# write_text(Channel.Stdout {}, "ready\n")
# ```
# Expect: true；恰写出一次 ready 与换行，不重放前缀、不切换流。
#
# Given: 文本字节已写完，但 stdout 刷新报告永久失败。
# ```spore
# write_text(Channel.Stdout {}, "ready\n")
# ```
# Expect: false；不重复文本，不把写入成功当成刷新成功。
pub fn write_text(channel: Channel, text: Str) -> Bool {
    # hole: host.write
    # 输入：明确的 stdout / stderr 与完整 Unicode 文本；本函数不自动添加换行。
    # 产出：按 UTF-8 完整写入并成功刷新才返回 true。
    # 条件：短写按实际确认字节数继续；不能从头重放已写前缀，不混用两个流。
    # 失败：写入、无进展或刷新永久失败返回 false，不自动重试业务或向另一流追加诊断。
    # 验收：完整写入、短写、刷新失败及永久失败分别有真实输出和结果证据。
    _
}
