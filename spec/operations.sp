# basic-cli 的数据、名称匹配与宿主边界契约。
# Str / Int / Bool 为 MLTT 基线内建数据；List 使用 Spore Spec 指定的同一个标准库声明。
# 本稿显式定义 Option 和 FilePath，应用导入这两个名义类型，不另建同名副本或隐式替换为 Lab 类型。

pub type Option[Value: Type] {
    cases {
        pub case None;
        pub case Some { pub field value: Value; }
    }
}

# 保留输入的路径文本；构造值不证明目录存在、已规范化或具有任何权限。
# CLI 解码拒绝空文本及 NUL；实际路径解析、存在性与目录检查由应用负责。
pub type FilePath {
    pub field text: Str;
}

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

# 当前三种类别全部按位置绑定；名称只用于帮助，不自动产生 --name 选项。
# Text / Path 必填；OptionalPath 对应最后一个 Option[FilePath] 参数，缺省传入 None。
pub type ParameterKind {
    cases {
        pub case Text;
        pub case Path;
        pub case OptionalPath;
    }
}

pub type Parameter {
    pub field name: Str;
    pub field kind: ParameterKind;
}

# bind 先检查元数并解码，再把已检查的实参捕获到 invoke；构造该闭包不调用处理函数。
# 该值的完整提供者为 compile.bindings，不能把函数字段当作自动得到的实现。
pub type ArgumentBinding {
    cases {
        pub case Ready { pub field invoke: () -> Exit; }
        pub case Usage { pub field message: Str; }
    }
}

pub type Binding {
    pub field name: Str;
    pub field parameters: List[Parameter];
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
    # Given: root 为 Any 根，默认 Help，唯一子节点绑定完整 run(repository: Option[FilePath]) -> Exit；run 返回 Success。
    # ```spore
    # root.run(["bootstrap", "run", "my repo"])
    # ```
    # Expect: 消费 bootstrap 和 run；仅调用 run(Some(FilePath("my repo"))) 一次，返回 Success。
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
    # Expect: 此子树作为入口时仍匹配并消费 run；handler 只收到 Some(FilePath("repo"))。
    pub method run(args: List[Str]) -> Exit {
        dispatch(self, args)
    }
}

# 纯名称比较，不消费输入、不解释控制标记、不生成帮助、不调用业务。
# 根与子节点使用同一比较；控制标记只在一个节点已经匹配后的剩余输入中解释。
# Examples
# Given: command.name 为 Exact("execute")，handler 绑定完整 run(repository: Str) -> Exit。
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
    # 约束：首版只接受 Unicode 输入；Unix 严格 UTF-8，Windows 拒绝未配对 UTF-16 代理项。
    # 保真：不补或取出程序名，不替换非法字符，不再按 shell 拆词，不展开变量、通配符或 @文件。
    # 失败：编码不满足约束返回 Usage，读取机制故障返回 Failure；本函数不写终端或读业务配置。
    # 验收：空列表、首项、中文、含空格与空字符串均保真；非法编码的应用调用次数为零。
    _
}

# 下列 root 除非另行说明均为显式 Any 根；Given 中的处理函数与 Binding 是须供应的完整夹具。
# Examples
# Given: root 默认 Help，唯一子节点绑定完整 run(repository: Option[FilePath]) -> Exit，无子命令。
# ```spore
# prepare(root, ["bootstrap", "run", "my repo"])
# ```
# Expect: Invoke 捕获 run 和 Some(FilePath("my repo"))；当前不调用 handler，不写终端。
#
# Given: 同一 root。
# ```spore
# prepare(root, ["bootstrap", "run"])
# ```
# Expect: Invoke 捕获 run 和 None；不会产生缺参 Usage，也不替业务选择当前目录。
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
# Expect: Invoke 捕获 Some(FilePath("--help"))；不产生帮助，不访问这个路径。
#
# Given: 同一 root。
# ```spore
# prepare(root, ["bootstrap", "run", "repo", "--help"])
# ```
# Expect: Usage；不忽略多余参数，不调用业务。
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
# Given: root 默认 init(repository: Option[FilePath])，三个同签名 init / run / status 子节点，均无子命令。
# ```spore
# prepare(root, ["/tmp/renamed-bootstrap", "repo"])
# ```
# Expect: Any 消费完整启动路径；没有子命令名匹配 repo，Invoke 捕获 init(Some(FilePath("repo")))。
#
# Given: 同一 root。
# ```spore
# prepare(root, ["bootstrap", "--", "run"])
# ```
# Expect: Invoke 捕获 init(Some(FilePath("run")))，不进入 run 子命令。
#
# Given: root 默认 Help，agent / skill 组为 Help，train(employee: Str, skill: Str) 为完整函数。
# ```spore
# prepare(root, ["bootstrap", "agent", "skill", "train", "reviewer", "rust"])
# ```
# Expect: 依次消费四个名称；Invoke 仅捕获 train("reviewer", "rust")。
#
# Given: 同一 root。
# ```spore
# prepare(root, ["bootstrap", "agent", "skill", "--help"])
# ```
# Expect: Help 的实际路径为 bootstrap agent skill，列出 train 的签名；不调用业务。
#
# Given: root 的 run(target: Str) 节点含 subcommand(target: Str) 子节点，所有函数完整。
# ```spore
# prepare(root, ["bootstrap", "run", "subcommand"])
# ```
# Expect: 子节点缺参 Usage；不回退到父 run，也不把 subcommand 重新解释为父参数。
#
# Given: 同一 root。
# ```spore
# prepare(root, ["bootstrap", "run", "--", "subcommand"])
# ```
# Expect: Invoke 捕获父 run("subcommand")；-- 停止子命令选择。
#
# Given: root 的子列表依次为 Any(first)、Exact("run", second)，两者均接受一个 Str、无子命令。
# ```spore
# prepare(root, ["bootstrap", "run", "repo"])
# ```
# Expect: 首个 Any 消费 run，捕获 first("repo")；不优先选择 Exact 节点。
#
# Given: root 的子列表依次为 Auto(first)、Exact("first", second)；first 接受两个 Str，second 接受一个 Str。
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
pub fn prepare(root: Command, args: List[Str]) -> Decision {
    # hole: cli.prepare
    # 输入：compile.bindings 生成的有效 Command 与从其名称开始的已解码列表；不假设另有 program 字段。
    # 进入节点：空列表为缺少名称 Usage；否则 matches_name 比较首项，不匹配为 Usage，匹配后消费恰好一项。
    # 统一性：根、子节点和独立复用的子树都走同一进入规则；没有根名称豁免，不补任何名称 token。
    # 路径：每次成功进入追加实际消费的原 token；名称只进入路径，不进入处理函数的业务实参。
    # 路由一：进入后余项恰为 ["--help"] 时返回当前 Help，不运行 bind 或 handler。
    # 路由二：余项以 -- 开头时，移除这一次标记，停止路由及选项识别，后续全部按字面值绑定当前动作。
    # 路由三：否则首个余项存在且不以 - 开头，按子列表顺序比较名称，首个命中者进入同一匹配消费步骤。
    # 路由三：Exact / Any / Auto 无额外优先级；Any 的比较接受任意一个字符串，不拆分或增加业务实参。
    # 路由四：无子节点命中或余项为空时选择当前自身动作；开始参数绑定后不再寻找子命令。
    # 提交：名称选中后不按元数、类型或后续路径回退，不合并同名子树，也不执行父动作。
    # 绑定：Function 调用一次 binding.bind，以声明顺序检查必填 Str / FilePath 及至多一个末尾 Option[FilePath]。
    # 绑定：缺省可选路径得到 None；一个合法路径得到 Some(FilePath)，空文本 / NUL、缺必填或多参均 Usage。
    # 绑定：ArgumentBinding.Ready 的完整闭包进入 Decision.Invoke；Usage 附加当前实际路径后返回，不调用闭包。
    # 缺省：Help 只接受空参数，返回与当前 --help 相同的帮助；剩余任何字面参数都为 Usage。
    # 控制：--help / -- 只在已选节点的余项中解释；未转义、混入业务参数的 - 前缀 token 均 Usage。
    # 帮助：自身及直接子节点的签名由同一 Binding.parameters 产生，必填用 <name>，可选目录用 [name]，同时标明类型。
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
