# basic-cli：最小 MLTT platform spec

这是新版设计稿，尚未实现或通过类型、证明、运行验证。入口是
[platform.sp](platform.sp)，数据、名称比较和三个函数 hole 在
[operations.sp](operations.sp)。本目录未接入现有 `spore.toml`；旧
`src/platform_contract.sp`、I/O 模块和 Rust host 继续描述旧实现。

## 基线与范围

本稿采用 MLTT 基线：直接使用 `Type` / `Prop`，类型统一用
`type`，封闭分支在 `cases` 块内使用 `case`，模式新绑定显式写 `let`。
`case` 不接受独立的可见性标注，分支统一公开；外部引用仍受所属类型
可见性限制，字段继续遵守自身的可见性规则。
不引入 `Universe`、CuTT 维度／路径、`law` 或未证明公设。这里没有需要
凭空定义的命题，也不把 `-> Prop` 的占位函数当作证明。

相邻 Spore Spec 的 `spec/open-questions.md` 记录了 `case`、显式绑定及
移除 `law` 的方向；部分正文、文法和 Lab 示例仍是旧设计，不能用其
`Universe` / Path 写法覆盖本稿的 MLTT 基线。通用导入、效果与入口生成
尚未确定或实现，下方逐项保留义务。

列表采用 Spore Spec 的 `G-list-literals`、`S-list-literals` 与
`D-list-literals`：`[]` / `[a, b]` 构造标准库固定的 `List`，元素类型由
期望类型与元素约束确定。平台引用这个声明，不另建同名类型；标准库
供应与编译器展开、推断仍由下方装配和验证义务负责。

首版提案支持单命令和有限的静态命令树，参数全部是必填 `Str` 位置参数，
命令正常返回 `Exit`。只增加启动、参数与终端输出契约；文件、网络、
进程执行、调度、预算和工作恢复不在本稿中扩展。现有 I/O 模块可作为
后续实现参考，但旧 `foreign` / `uses` 语法不因此成为新版语言规则。

参数默认值、自定义 decoder、类型转换、可选参数、短选项、环境变量
输入、动态命令树和动态注册均不在首版。裸函数列表、元组简写、链式
注册与函数式组合留待后续。原生非 Unicode 路径也不在首版输入域内，
必须明确拒绝而非有损解码。

## 命令树的接口提案

应用 `main` 不要求 `pub`，也不接收 platform 类型参数。本稿选定
`Command`、`CommandName`、`Cli`、`cli` 与 `.run()` 的声明表面；其中直接函数字段的
编译期适配尚未成为 Spore 正式语言规则或已实现 API。这里只交付规约。
处理函数必须由应用实际定义，函数体缺失不能由注册补齐：

```spore
fn main(args: Args) -> Exit {
    cli(args, Command {
        name: CommandName.Any {},
        handler: init,
        subcommands: [
            Command { handler: init },
            Command { handler: run },
            Command { handler: status },
            Command { handler: stop },
        ],
    }).run()
}
```

`Command` 统一表示每一个节点，自身处理函数和子命令可以同时存在。
同一列表内的节点处于同一层，`subcommands` 的列表下降一层。

| 声明字段 | 含义与缺省规则 |
| --- | --- |
| `handler` | 当前节点自身的完整具名处理函数；省略时采用框架帮助动作 |
| `name` | `CommandName.Exact { value: "run" }`、`CommandName.Any {}` 或 `CommandName.Auto {}`；默认为 Auto |
| `subcommands` | 按匹配优先级排列的直接子节点，默认 `[]` |

三种情况直接使用 CommandName 的 case 构造式，name 字段不接受裸 Str。
省略 name 与显式写 `name: CommandName.Auto {}` 完全等价；Auto 保留在
命令值中，名称比较与帮助直接读取已有的 `Binding.name`。
函数声明名在生成绑定时保存，不在运行时反射函数，也不调用函数来获取名称。

没有处理函数的非根节点必须显式提供 Exact 或 Any 名称，Auto 在此处没有
可用的函数声明名，产生编译诊断。非根 Exact.value 与 Auto 所用的 Binding.name
必须非空、不含空白或控制字符，且不以 `-` 开头；不自动
转换下划线或大小写。空子列表合法，同名兄弟节点合法且首个优先。
名称相同不会合并子树，后面的同名节点也不能在前者失败时被尝试。

`CommandName.Any {}` 在子命令位置匹配并消费一个普通输入元素；
Exact、Any、Auto 共同按列表顺序取首个匹配者，不按名称模式额外排序。
Any 必须有一个剩余元素，不在空输入时自动进入。它不截获 `--help`、
`--` 或以 `-` 开头的未转义输入，这些继续遵守控制标记与参数错误规则。
空字符串或含空白的输入仍是一个完整元素，Any 不拆词或改写它。

它是类型的分支值，不是字符串通配符：`CommandName.Exact { value: "*" }` 仍是精确名称，`_`
仍是未完成的洞。根已由 cli 指定，根的 Any 不消费业务参数；只有选择
子节点时才按其名称消费输入。通配消耗的词进入帮助与诊断的实际路径，
不自动追加到处理函数的位置参数中。

`cli(args, command)` 接受一个完整根 Command，返回
`Cli { args: args, command: command }`。Cli 保存这两个值并提供
`run() -> Exit`，命令字段全部由 Command 持有。构造不会改变 handler、
填补业务参数或解析输入；调用 `.run()` 才分派。

根节点由 cli 的第二个参数指定，解析直接从该节点正文开始；已有 Exact
名称的子树也可作为根复用，不要求用户再输入该名称。帮助前缀始终来自
`Args.program`，不把 Any 或原根名称显示为额外的调用词。
根的 name 无论是哪种 case 都保持原值；根不参与名称比较，无函数的帮助根
也可以保留 Auto。它作为非根节点复用时仍须满足子节点的名称要求。

上面的 bootstrap 根默认选择 init，同时保留显式 init 子命令。当前
`init(repository: Str, contract_file: Str, control_file: Str)` 有三个必填
参数，因此 `bootstrap repo contract.input control.input` 与
`bootstrap init repo contract.input control.input` 都调用同一 init 一次。
空输入仍报缺参；`--help` 显示根动作签名和四个子命令。进入 run、status、
stop 等子命令时不会先执行 init。参数名与子命令同名时用 `--` 强制根动作。

需要默认显示帮助时省略根 handler；下例中的 args、commands 是调用方
提供的输入与静态子列表：

```spore
cli(args, Command { name: CommandName.Any {}, subcommands: commands }).run()
```

该根在空输入时返回与 `--help` 相同的帮助。所有默认动作都来自根
Command 的声明，cli 不再接收子列表或额外选择默认动作。

以下是独立的层级示意，不给 bootstrap 增加业务命令。假设完整的
`train(employee: Str, skill: Str)`、`run(target: Str)` 和零参数
`subcommand()` 均返回 Exit；这些名字不引用 bootstrap 的内部能力函数：

```spore
static skills = Command {
    name: CommandName.Exact { value: "skill" },
    subcommands: [Command { handler: train }],
};

fn main(args: Args) -> Exit {
    cli(args, Command {
        name: CommandName.Any {},
        subcommands: [
            Command { name: CommandName.Exact { value: "agent" }, subcommands: [skills] },
            Command {
                handler: run,
                subcommands: [Command { handler: subcommand }],
            },
        ],
    }).run()
}
```

它直接对应以下结构；`run` 自身动作和更深的子命令共存：

```text
bootstrap                 自身动作：help
├── agent                 自身动作：help
│   └── skill             自身动作：help
│       └── train         自身动作：train(employee, skill)
└── run                   自身动作：run(target)
    └── subcommand        自身动作：subcommand()
```

`skills` 保存完整具名子树，可在另一个父节点引用；原子树不被修改，
也不执行处理函数。父路径在本次解析时累计，不能预先固化进共享子树。

通配子节点也使用同一个 Command；下例中的 fallback 是完整处理函数：

```spore
Command {
    name: CommandName.Exact { value: "agent" },
    subcommands: [
        Command { name: CommandName.Exact { value: "skill" }, subcommands: [Command { handler: train }] },
        Command { name: CommandName.Any {}, handler: fallback },
    ],
}
```

`agent skill ...` 先命中具名节点；`agent other ...` 由 Any 消费 other，
其余参数才交给 fallback。交换两项后，Any 也会先消费 skill，后续参数
错误不能再退回具名节点。Any 节点同样可以继续拥有 subcommands。

### 同质列表与静态转换

显式 `Command` 统一了列表元素，但并未让不同签名的函数自动具有相同
类型。源声明 `Command { handler: f }` 须先经 `compile.bindings` 读取
同一份函数声明，产生参数名列表与完整 `Binding.invoke` 包装体，并把
handler 转为 `Handler.Function { binding: ... }`。省略 handler 则使用
`Handler.Help {}`；它由框架根据当前节点产生帮助，不是零参数业务回调。

`operations.sp` 定义 Command、Handler 和三分支 CommandName。
直接函数引用的源写法先完成适配，再检查这些字段的类型；不能声称 f
本身属于 Handler，或普通函数值能恢复声明名与参数名。name 的字段默认值
只是常量 Auto，不访问正在构造的实例或其他字段。
name 按普通 CommandName 字段检查，不提供 Str 转换或 Auto 改写。
Exact 只覆盖匹配名称，Binding.name 仍保存同一已检查函数的声明名；
Auto 直接使用这份元数据。已适配的 Handler 不重复包装。
Cli 只有 args 与 command，不参与 handler 适配或名称比较；cli 直接保存
已经检查的根 Command，所有名称 case 保持原值。

适配后的节点都具有 Command 类型，列表仍是普通 `List[Command]`。
静态子树须验证为有限、无环；不会为了发现命令而执行业务或注册回调。
只接受完整具名函数声明，动态选择、匿名函数、裸函数元素、元组元素、
循环引用和不合格签名均拒绝。同名节点和空子列表不属于拒绝条件。
声明适配和 Cli 根装配仍分别属于 `compile.bindings` / `compile.assembly`
的未完成义务。

## 入口装配与实际调用

单命令应用直接提供带业务参数的 `main`，可有零个或多个必填 `Str`
参数并返回 `Exit`；编译器把它绑定为一个无子命令的根 Command，生成
`Args -> Exit` 解析入口。接收 `Args` 的 `main(args: Args) -> Exit`
通过 `cli(args, root)` 绑定完整根并调用一次 `.run()`；它不是供业务绑定的 Str 参数函数。
两种入口都经 `dispatch(root: Command, args: Args)` 和
`prepare(root: Command, args: Args)`，不再使用 Single / Group 两套表示。

根由 cli 的 Command 实参提供，静态子树由 Command、列表
和已验证的静态引用组成，不由循环、条件或运行时函数生成。
`cli` 的构造正文与 `Cli.run()` 的分派顺序写在 `platform.sp`；方法取值
只绑定接收者，调用时才执行正文。Cli.run 将保存的 command 与 args
交给 dispatch；Command 自身不持有 Args，子节点不重新读取 argv。业务调度放在最终选定的
处理函数内，不在父节点增加初始化钩子。

运行关系固定为：宿主启动 → `main_for_host` 读取输入 → 已装配入口 →
构造 Cli 并调用 `.run()`（单命令为生成的根分派）→ `prepare` →
帮助／用法诊断或一次业务调用 → `exit_code` → OS 进程状态。
宏观分支已写在 `platform.sp`；业务返回的 `Exit` 不被解析层重新解释。
正常返回只说明退出状态，不自动产生任务完成、权限或预算证明。

## Args 的职责与解释顺序

`Args` 是一次调用的已解码输入快照，包含 `program: Str` 和
`values: List[Str]`。`program` 来自 `argv[0]`，只用于用法展示；它不证明
可执行文件身份，也不授予路径或业务权限。`values` 保存剩余参数，
保留命令名、顺序、空字符串、空白和参数边界。

例如启动器传入 `bootstrap run "my repo"` 对应的 argv 时，
`program` 为 `"bootstrap"`，`values` 为两个字符串 `"run"` 和
`"my repo"`。用于 shell 分组的引号不属于 argv 内容；参数中实际存在的
引号仍原样保留。`Args` 不重新拆词、展开变量、通配符或文件引用。
示例直接使用列表字面量；例如：

```spore
static command_args = Args { program: "bootstrap", values: ["run", "my repo"] };
static empty_args = Args { program: "bootstrap", values: [] };
```

两例的 `values` 都由字段类型约束为 `List[Str]`。字面量展开为标准库
`List.Item` / `List.Empty`，空列表也保留这一元素类型；构造 Args 本身
不读取进程输入或解析命令。

处理依次经过四个边界：

1. `read_args` 读取一次宿主 argv，完成无损解码，返回 `Input.Ready(args)`、
   `Input.Usage` 或 `Input.Failure`；`Ready` 仅表示输入读取与编码有效。
2. `prepare` 将同一个 `Args` 与已生成的根 Command 结合，依下方规则
   消费命令路径并检查最终节点的自身参数；根名称从不消费。
3. `Decision.Invoke` 携带选定的 Binding 及剩余业务参数。`Args.values`
   中的整条命令路径与分隔标记不会进入 `Binding.invoke` 的 values。
4. `dispatch` 才调用业务函数。例如 `run("my repo")` 只收到 repository；
   目录是否存在、权限和恢复条件继续由业务契约检查。

### 有序路由与自身动作

每层依次采用以下规则。这是沿已匹配路径的深度优先，不遍历未命中的
子树，也不在参数失败后搜索其他候选：

1. 剩余输入恰为 `["--help"]` 时，产生当前节点的 Help。
2. 剩余输入以 `--` 开头时，移除一次标记，停止路由与选项识别，将
   后续原值交给当前节点自身动作。
3. 有剩余输入且首元素不以 `-` 开头时，按 subcommands 顺序调用
   `matches_name`：Exact 比较 value，Auto 比较 Binding.name，Any 接受该元素。
   首个命中即选定，消费该原始元素并记录实际路径，在子节点重复规则；
   名称模式不改变列表优先级。
4. 输入为空或没有子节点命中时，选定当前节点自身动作；开始检查位置
   参数后，不再寻找子命令。

名称比较的完整正文是 `operations.sp` 的 `matches_name`，一个 match 同时
查看 name 与 handler。它只返回 Bool；控制标记、顺序选择、路径与输入消费
属于上述路由步骤。Auto / Help 没有可比较的声明名，返回 false；静态装配
仍拒绝这种非根节点，不能把 false 当成无效配置的兜底。

`Handler.Function` 按原函数签名核对参数。`Handler.Help` 只接受空参数，
返回与本节点 `--help` 相同的文本；未知名称或多余参数返回 Usage。
单独 `--` 移除后也是空参数：零参数函数可执行，缺省动作显示帮助，
有必填参数的函数仍报缺参。转义后再出现 `--` 也只是原值。
未转义时以 `-` 开头的业务参数、混用的 `--help`、中途出现的 `--`、
缺参和多参均为 Usage。子命令路径必须连续地出现在业务参数之前。

名称命中后不回退到父动作或后面的节点，也不合并子树。
进入子命令不执行父函数；没有子命令命中时，一个接受 Str 的自身函数
可能接收拼错的命令名，此时该字符串是否合法由业务判断。
新增同名子命令会优先于原有的自身参数解释；需要稳定地传入这种字符串
时使用 `--`，shell 引号不能消除这种歧义。

以下测试夹具的根 handler 为 Help，含单个必填 Str 命令 `run`：

| Args.values 的内容 | prepare 的结果 |
| --- | --- |
| `["run", "my repo"]` | Invoke(run, `["my repo"]`) |
| `["run", ""]` | Invoke(run, `[""]`)；空字符串是否可用由业务判断 |
| `["run", "--help"]` | Help；不调用 run |
| `["run", "--", "--help"]` | Invoke(run, `["--help"]`) |
| `["run", "repo", "--help"]` | Usage；不调用 run |
| `[]` 或 `["--help"]` | 相同的根 Help；不调用业务 |
| `["missing", "repo"]` | Usage；未知命令 |

对这个默认帮助夹具，空输入与 `--help` 输出完全相同的根帮助到 stdout，
stderr 为空，写入与刷新成功后退出 0；输出失败仍退出 1。实际 bootstrap
入口已指定 init，空输入按它的三个必填参数报告缺参。

对上方 agent / run 示意树：

| Args.values 的内容 | prepare 的结果 |
| --- | --- |
| `["agent", "skill", "train", "reviewer", "rust"]` | Invoke(train, `["reviewer", "rust"]`) |
| `["agent", "skill", "--help"]` | Help；列该组直接子命令与完整调用前缀 |
| `["agent", "skill"]` | 与该节点 `--help` 相同的 Help；未设置自身函数 |
| `["agent", "missing"]` | Usage；在 agent 组遇到未知名称 |
| `["agent", "--", "skill"]` | Usage；agent 的缺省 Help 不接受字面参数 skill |
| `["agent", "skill", "train", "--", "--help", "rust"]` | Invoke(train, `["--help", "rust"]`) |
| `["run", "subcommand"]` | Invoke(subcommand, `[]`)；不执行 run |
| `["run", "--", "subcommand"]` | Invoke(run, `["subcommand"]`) |
| `["run", "some_arg", "subcommand"]` | run 的多参 Usage；不会中途转入 subcommand |

每个节点的帮助包含自身动作签名和退出规则，以及按声明顺序排列的
全部直接子命令及各自的自身签名；Exact 显示 value，Auto 显示 Binding.name，
Any 标示为通配项，缺省动作标示为显示帮助。重叠匹配项保持原顺序并注明首个优先，不假定每一项
都可到达。已选节点的帮助使用实际消费的完整路径，包括 Any 消费的词，
不把原函数声明名或 Any 的显示标记替换成路径词。
错误定位到最终选定的节点；帮助与错误只产生数据，不能执行业务。

标准库 `List` 提供有限、有序序列，其语言定义不规定宿主 ABI 的内存
布局。`Args` 没有解析游标、已选命令、默认参数或环境变量；增加新的
业务参数只修改处理函数声明及其绑定，不修改 `Args` 的结构。
已有 `Args` 可直接供解析示例使用，无须读取真实进程输入。

## 函数 Examples 与后续执行

每个函数的前置注释包含 `Examples`，使用 Markdown 的 `spore` 代码块，
以 `Given:` 说明输入和测试环境，以 `Expect:` 写出结果及可观察行为。
代码块使用真实函数签名；Given 中的命名值是待提供的测试数据，不能
假定它们是现有全局变量或新增的测试 API。列表字面量遵循上述 Spec
规则；未声明的断言 API、fixture 构造器和执行命令不会混入示例代码。

当前所有 Examples 都是 **pending**。代码出现、语法识别、现有 CI 或
`no_run` 式的仅编译结果都不等于示例已执行通过。后续由
`validation.evidence` 供应文档提取、模块上下文、完整测试数据、宿主
测试环境和断言，并逐例保存实际结果。缺少任一依赖仍为 pending；
依赖已齐备而实际结果不符为 failed；执行并核对全部期望后才为 passed。

纯计算示例比较结果值；输入输出示例还检查 argv、stdout、stderr、
刷新失败与业务调用；持久化或恢复示例须观察实际记录和重启行为。
这项要求扩展现有验证义务，不新增占位公设，也不关闭函数中的 hole。

格式参考 Python 的 [doctest](https://docs.python.org/3/library/doctest.html)
与 Rust 的 [documentation tests](https://doc.rust-lang.org/rustdoc/write-documentation/documentation-tests.html)。
借鉴前者的输入／预期结果关联，以及后者的代码块提取与可执行检查；
具体 runner、断言 API 和编译失败示例格式尚待语言工具确定。

## 完整 hole 清单

所有条目当前均未完成。函数体中的 `_` 是待实现义务，不是值、默认
成功或公设；数据中的函数字段也必须有下面所述的实际提供者。

| 标识 | 位置 | 输入、产出及完成依据 |
| --- | --- | --- |
| `host.arguments` | `operations.sp` / `read_args` | 原始 argv → `Input`；完整约束、错误和验收写在函数体内 |
| `cli.prepare` | `operations.sp` / `prepare` | 已绑定根 Command、Args → `Decision`；完整约束、错误和验收写在函数体内 |
| `host.write` | `operations.sp` / `write_text` | 指定流与文本 → 写入并刷新结果；完整约束、错误和验收写在函数体内 |
| `compile.bindings` | 编译期提供义务 | 已检查的函数声明与静态命令树 → 完整 Command / Binding；要求见下文 |
| `compile.assembly` | 编译与链接义务 | 选定 platform、应用及 spec → 固定宿主入口；要求见下文 |
| `runtime.effects` | 静态与运行边界 | 运行代码、纯代码及宿主操作 → 可执行但不污染证明求值的隔离；要求见下文 |
| `host.lifecycle` | OS 接入义务 | 宿主回调、流和进程 → 实际调用与退出行为；要求见下文 |
| `validation.evidence` | 验证义务 | 上述实现与固定输入 → 可复核的语法、类型及进程观察；要求见下文 |

**compile.bindings**：只在解析到本平台 Command 的静态声明构造处
适配 `handler: f`，不按同名拼写劫持用户自己的类型，也不为普通函数值
增加任意隐式转换。从同一版本、已解析并检查的完整具名函数声明取得
名称、参数顺序、参数类型和返回类型，生成参数名列表与完整
`Binding.invoke` 包装体，再装入 `Handler.Function`。省略 handler 时
使用 `Handler.Help`；省略 subcommands 时使用空的标准 `List[Command]`。
name 按普通 CommandName 字段检查，Exact / Any / Auto 均保持原值，
默认值为 Auto；裸 Str 是类型错误。Auto 不需要名称转换或消解步骤。
非根 Auto 必须有 Handler.Function，且其 Binding.name 来自同一已检查声明；
无函数的非根节点必须显式使用 Exact 或 Any。根跳过名称比较，Help 根可保留 Auto。

只接受非泛型、参数均为必填 `Str`、返回 `Exit` 的函数；有参数默认值、
依赖参数、匿名或动态选择的函数、不可见符号、未完成函数体时产生编译
诊断，不生成可运行产物。包装体把参数原样交给原函数，只在 Invoke
分支调用时执行；构造、帮助和解析期间不调用业务。

遍历所有静态子树引用，检查有限、无环，以及非根 Exact.value 和 Auto 所用
Binding.name 的名称有效性。空子列表合法，三种 case 均保留原顺序；
即使节点被前面的同名或通配节点遮蔽，也必须完整
检查其声明。跨父节点复用不固化父路径，不合并或排序子树。
验证零／一／三个参数的包装、异签名节点的同质列表、显式改名及缺省
命名、显式 Auto 与省略的等价性、Help 根保留 Auto、非根 Help 的 Auto 拒绝，
以及函数改名和签名变化后的帮助与调用一致性。复用声明按挂载位置核验，
Help + Auto 的根声明不能作为未命名子节点复用来绕过拒绝；显式 Any 子树可复用。
源构造到 Handler 的适配、参数元数与来源保真仍是生成器验证义务，
尚无 MLTT 证明；普通函数值的运行时类型不被假定含有参数名。

**compile.assembly**：输入明确版本的本 spec、应用和所选 platform，
同时供应 Spore Spec 指定的标准库 List，固定它及 Empty／Item 的声明
身份；平台和应用必须使用同一个类型。完成列表字面量展开与元素类型
推断，不能按局部同名类型替换，也不能用缺失的标准库绑定继续构建。
为 `matches_name` 的 `==` 供应 `Str` 的精确布尔相等比较，不裁剪、忽略
大小写或规范化输入；该操作不是内核定义相等或命题相等。
解析文件间名字，按 main 的签名选择装配：业务 Str 参数入口生成一个
绑定 main、没有子命令的根及 `Args -> Exit` 适配器；`main(args: Args)`
入口检查静态树并构造 Cli、调用一次 `.run()`。只对明确登记的处理函数
生成绑定，接通原函数、包装、Cli.run、`dispatch` 与 `main_for_host`。
核验 cli 保存同一 Args 与完整根 Command，Cli.run 交给 dispatch 的两个
值与构造输入一致；不复制或覆盖根动作，方法选择不提前执行正文。
根不消费自身名称；子节点的 Any 消费恰好一个名称元素，保留实际路径；不重新读取宿主输入。
固定宿主 ABI 不能随参数数量或命令深度变化。

Command 声明适配与静态子树引用的具体展开、模块导入拼写、
manifest 配置及跨语言 ABI 都尚未提供；缺失或不匹配必须阻止构建，
不回退到旧的 `main() -> ()`。验收须包含两个独立应用、私有 main、
跨文件可见性拒绝、错误入口签名，以及构造阶段零业务调用。

**runtime.effects**：`entry`、`Cli.run`、`dispatch`、`Binding.invoke`、
`read_args`、`write_text` 及其调用链属于运行层，可能执行 I/O、失败或
不终止。`cli` 构造与 `prepare` 只处理数据；声明适配不执行业务。本文的
运行函数签名仅描述调用边界，不意味着能够作为纯 MLTT 证明项归约。实现须
明确区分纯数据计算与运行代码，并保留调用链的效果；缺少该区分时不能
把整个文件标成已通过 MLTT 检查。验收要拒绝在类型形成、定义相等检查
或证明构造中执行宿主动作，同时允许运行层正常调用。纯 `exit_code`
可单独检查；不额外发明 `Type -> Type` 载体来掩盖未定的效果机制。

**host.lifecycle**：宿主实现原始输入、两个输出流和正常返回路径，
只调用固定入口一次，把 0／1／2 原样交给 OS。正常输出和诊断在返回前
完成刷新；应用自身产生的业务输出仍由应用负责检查写出结果。宿主运行
失败不得报告成功；强制终止、崩溃或信号退出不是 `Exit` 的正常返回，
不得宣称清理或业务完成。本切片不定义中断恢复与通用资源取消协议。
验收使用真实子进程观察退出状态、stdout／stderr、输出故障及异常终止，
不能以 `exit_code` 单元计算替代 OS 绑定验证。

**validation.evidence**：记录所用语言设计、文法、生成器及宿主版本，
分别报告语法识别、类型／效果检查和行为观察。旧 host 测试、旧编译器
成功或适配文法识别均不能关闭新版义务。未解 `_`、未供给的包装体或
未完成的效果隔离都必须保持 pending，不能当作通过或新增公设。
命令树验收包含二级与三级路径、子树复用、各层缺省帮助、自定义根与
父节点动作、空子列表、混合元数、Exact / Any / Auto 顺序优先、错误不回退、
`--` 强制自身动作，以及开始参数解析后不再路由。无效名称、循环子树、
动态声明和不合格函数必须被拒绝；构造、帮助、解析错误均无业务调用。
分别记录“期望绑定”与实际业务调用，不能只凭 Exit.Success 判断选对了
函数；每次合法分派最多调用一个处理函数一次，父函数不作为钩子执行。
列表验收包含有元素与空 Args、从字段约束得到 `List[Str]`、输入顺序和
空字符串保真，以及同名自定义 List 不能替代标准类型的拒绝案例。
还须逐例执行函数 Examples：实现提取器、提供 Given 所需的完整值和
可控宿主环境，将 Expect 变成结果及行为断言，并保留实际执行证据；
提取、测试数据、断言或运行支持缺失时不得把该例标为通过。

## 首版验收矩阵

平级 bootstrap 案例以上文入口和四个完整处理函数为输入：根默认 init，
`init` 接受三个 Str，
`run`、`status`、`stop` 各接受一个 Str，全部返回 Exit，四个节点均无
子命令。默认帮助根与其他自定义根在对应行另行指定；多级案例使用
上方 agent / run 示意树及其完整处理函数。
测试用可观察业务记录判断是否进入处理函数，不能
只检查解析器自报的成功。

| 输入或边界 | 必须观察到的行为 |
| --- | --- |
| `init repo contract control`；`run repo`；`status repo`；`stop repo` | 只调用对应函数一次，参数保真，退出值原样传递 |
| `bootstrap repo contract.input control.input`；显式 `bootstrap init repo contract.input control.input` | 两条路径都只调用同一 init 一次，三个参数保真；有效输入才初始化成功 |
| `bootstrap`；`bootstrap --help` | 前者为根 init 缺参，退出 2；后者输出根动作与子命令帮助，退出 0；两者均无业务调用 |
| 默认 Help 根的空输入与 `--help` | stdout 根帮助完全相同、stderr 为空、退出 0；无业务调用 |
| 只构造 Command / Cli / cli，或只选择 app.run 方法值 | 保持数据和声明顺序；不解析 argv，不输出，不调用业务 |
| 任意 Args.program，包括重命名或完整路径；根名为 Any | 根选择不受程序名影响，首个业务参数不被根名称消费；帮助前缀保留 program |
| 已具名的 Command 直接作为 cli 的根 | 直接从该节点正文解析，不要求再次输入它的 Exact 名称 |
| `run --help` | stdout 本节点帮助，包含自身参数和直接子命令，退出 0；无业务调用 |
| 示意树的 `agent skill train reviewer rust` | 三级路径选中 train，只传业务参数，调用一次 |
| `agent --help`；`agent skill --help`；`agent skill train --help` | 各层帮助与完整路径，输出成功退出 0，无业务调用 |
| `agent`；`agent skill`；已命名但无 handler 和子命令的节点 | 与该节点单独 `--help` 相同的帮助，输出成功退出 0，无业务调用 |
| `agent missing`；`agent -- skill`；默认帮助根的未知命令 | 在正确层级诊断，输出成功退出 2，无业务调用 |
| 自定义 start() 根的空输入；同一根的 `--help` | 前者调用 start 一次并传播 Exit；后者显示根帮助，不调用 start |
| 自定义根接受一个 Str：空输入；`repo` | 前者缺参 Usage；后者直接传入 repo，不要求输入根名称 |
| 示例 run 的 `run subcommand`；`run -- subcommand` | 前者只调用子命令；后者只调用 run，参数为字面 subcommand |
| `run some_arg subcommand` | run 的多参 Usage，不能中途转入 subcommand |
| 子命令缺参，其名称本可作为父函数的合法 Str 参数 | 只报告子命令缺参，不回退、不调用父函数 |
| 两个无子命令的 run 节点都能接受输入；首个缺参但后者可接受 | 两者都可接受时只调用首个一次；首个缺参时报告它的 Usage，不尝试后者 |
| 子列表 `[Any(first), Exact("run", second)]`，输入 `run repo`，两者都接受一个 Str | 只调用 first("repo")；Any 消费 run，不优先执行后面的具名节点 |
| 子列表 `[Exact("run", first), Any(second)]`，输入 `other repo`，两者都接受一个 Str | 只调用 second("repo")；实际路径保留 other，处理函数不额外收到该名称 |
| 子列表依次为 Any(first)、Auto(run)，或顺序相反；输入 `run repo`，两者都接受一个 Str 且无子命令 | 均只选择列表中首个节点，Auto 不改写为 Exact，也不越过前面的 Any |
| 子列表依次为 Auto(first)、Exact("first", second)，均无子命令；first 接受两个 Str，second 接受一个，输入 `first repo` | 返回 first 的缺参 Usage，不尝试 second；帮助列出相同匹配名并注明首个优先 |
| 首个 Any 命中后参数不足，后面的 Exact 本可接受输入 | 报告 Any 所选节点的 Usage，不回退 |
| 默认 Help 根含 Any 子节点，输入为空或仅 `--help` | 返回根 Help；不进入 Any，不调用业务 |
| 默认 Help 根含 Any 子节点，输入 `-- other`、`--help other` 或 `-x` | 均为根 Usage，Any 不截获控制标记或未转义选项样式输入 |
| Any 节点含 status 子命令，输入 `project-1 status --help` | 完整帮助路径使用实际消费的 project-1，不使用 Any 或原函数名 |
| Any 子节点无子命令、绑定零参数函数，输入为一个空字符串或含空白元素 | 消费该完整元素，只调用零参数函数一次；不拆词，不将名称作为业务参数 |
| 同名节点分别拥有不同子树，输入仅匹配后者子树 | 仍选首个节点，并依其自身动作成功或报错；不合并或回退 |
| `run` 缺参、多参、`run repo --help`、`run repo --` | stderr 用法诊断、退出 2；无业务调用 |
| `run -- --help`；`run -- -x`；`run -- --` | 标记后的单个值按字面传入 run |
| 默认帮助节点的 `--`；`-- --help` | 前者显示本节点帮助；后者为多余字面参数 Usage |
| bootstrap 根的 `-- run contract.input control.input` | 根 init 收到 repository = "run"；不进入 run 子命令 |
| 显式 `name: CommandName.Exact { value: "execute" }` 绑定 run，输入 `execute repo` | 调用原 run 一次；帮助路径为 execute，原函数名不成为另一条路由 |
| 一个空字符串参数、中文、含空格参数 | 不裁剪、不重新拆词、不改写 |
| 非 Unicode 原始参数 | 解码诊断、退出 2；无业务调用 |
| 自动装配单命令 main，零参数函数、一个参数函数 | 作为无子命令的根，不要求 main 名称；按签名解析后调用一次 |
| 处理函数返回 Failure／Usage | 进程退出 1／2；平台不擅自重复调用或补报业务错误 |
| 帮助或诊断流短写、永久失败、刷新失败 | 正确续写或退出 1；不切换流假报成功 |
| 子树跨父节点复用；不同父节点下同名子命令 | 两条路径分别有效，帮助和调用不混淆父路径 |
| 循环子树、动态树、裸函数或元组元素、匿名 handler、错误签名、未完成函数、缺失模块、裸 Str 名称 | 编译失败，无可运行生成物；遮蔽节点也须检查 |
| 同一具名函数的节点省略 name 或显式 Auto | 两者均保留 Auto，使用相同 Binding.name；构造零调用，合法分派只调用该函数一次 |
| 默认 Help 根省略 name 或显式 Auto | 两者均保留 Auto 并跳过根名称比较；空输入与 --help 显示相同根帮助 |
| 非根 Help 省略 name 或显式 Auto；复用 Help + Auto 根声明为子节点 | 编译诊断，不从父路径或 Args 猜名称，不隐式生成 Any；显式 Exact / Any 合法 |
| 空白、控制字符、空串或以 - 开头的非根 Exact.value 或 Auto 使用的 Binding.name | 编译诊断，显式名称与自动名称使用同一检查 |
| 函数改名、参数改名或数量改变；保留显式命令名 | 缺省名称和参数帮助随声明更新；显式名称稳定，调用仍绑定同一函数 |
| 从纯证明调用宿主操作；异常终止 | 前者静态拒绝；后者不产生成功或清理完成证据 |
