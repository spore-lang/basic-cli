# basic-cli 首版数据与完整函数 hole。
# Str / Int / Bool 为选定语言基线的内建数据；不另造宇宙、公设或空的宿主类型。
# List 的定义仅描述有限输入与注册集合；不把运行层回调混入纯 MLTT 求值。

pub type List[A: Type] {
    cases {
        case Empty;
        case Item { pub field value: A; pub field rest: List[A]; }
    }
}

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
# compile.bindings 必须从同一已检查函数产生名字、参数名和调用适配器。
# invoke 只接受 prepare 已核对元数的值，并在调用时才进入业务函数。
pub type Binding {
    pub field name: Str;
    pub field parameters: List[Str];
    pub field invoke: List[Str] -> Exit;
}

pub type Interface {
    cases {
        case Single { pub field binding: Binding; }
        case Group { pub field bindings: List[Binding]; }
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

pub fn prepare(interface: Interface, args: Args) -> Decision {
    # hole: cli.prepare
    # 输入：compile.bindings 生成的有效 Interface 和一次已解码 Args；所有参数均为必填 Str。
    # 产出：合法调用返回同一 Binding 与按声明顺序排列的原值；帮助返回 Help；输入不匹配返回 Usage。
    # 选择：Single 不消费命令名；Group 消费第一个参数选择命令，空输入和未知命令均为 Usage。
    # 帮助：根级仅有 --help 或 Group 中已知命令后仅有 --help 时返回 Help，列出函数名、参数名、Str 和退出码。
    # 用法：结合 program 和 Single / Group 生成可直接调用的命令形状；Single 不要求输入 main 这个名字。
    # 字面值：仅在位置参数段开头识别一次 --，移除它后其余内容均为字面值，包括 --help、-- 和 -x。
    # 错误：未使用该 -- 时，位置参数中以 - 开头的值、混入其他参数的 --help、缺参或多参均返回 Usage。
    # 约束：不读取目标文件，不执行 invoke，不根据参数数量猜命令，不补默认值，不静默忽略参数。
    # 验收：README.md 的输入矩阵全部成立；帮助和错误只产生数据，不能触发业务或终端输出。
    _
}

pub fn write_text(channel: Channel, text: Str) -> Bool {
    # hole: host.write
    # 输入：明确的 stdout / stderr 与完整文本；仅写指定流，不增加换行或改写内容。
    # 产出：全部 UTF-8 字节写入并刷新到宿主流后返回 true；允许宿主流再连接到终端、文件或管道。
    # 约束：处理短写；可继续的中断只续写未完成部分；成功不承诺文件持久化或终端已显示。
    # 失败：永久写入或刷新故障返回 false；不在另一个流无限补报，不自动重复整段文本。已写前缀不能回滚。
    # 验收：stdout / stderr 分离，空文本和多字节文本保真；短写不重字节，失败使 emit 返回 Failure。
    _
}
