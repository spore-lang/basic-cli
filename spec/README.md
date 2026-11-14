# basic-cli：最小 MLTT platform spec

这是新版设计稿，尚未实现或通过类型、证明、运行验证。入口是
[platform.sp](platform.sp)，数据和三个函数 hole 在
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
`Command`、`Cli`、`cli` 与 `.run()` 的声明表面；其中直接函数字段的
编译期适配尚未成为 Spore 正式语言规则或已实现 API。这里只交付规约。
处理函数必须由应用实际定义，函数体缺失不能由注册补齐：

```spore
fn main(args: Args) -> Exit {
    cli(args, [
        Command { handler: init },
        Command { handler: run },
        Command { handler: status },
        Command { handler: stop },
    ]).run()
}
```

`Command` 统一表示每一个节点，自身处理函数和子命令可以同时存在。
同一列表内的节点处于同一层，`subcommands` 的列表下降一层。

| 声明字段 | 含义与缺省规则 |
| --- | --- |
| `handler` | 当前节点自身的完整具名处理函数；省略时采用框架帮助动作 |
| `name` | 子命令精确匹配的名称；默认取 handler 的声明名，可显式覆盖 |
| `subcommands` | 按匹配优先级排列的直接子节点，默认 `[]` |

没有处理函数的非根节点必须显式提供 `name`。非根名称必须非空、不含
空白或控制字符，且不以 `-` 开头；函数名派生后也经过同一检查，不自动
转换下划线或大小写。空子列表合法，同名兄弟节点合法且首个优先。
名称相同不会合并子树，后面的同名节点也不能在前者失败时被尝试。

`Cli` 是 `Command` 的根入口特化，继承这些命令字段，增加 `args: Args`
和 `run() -> Exit`。根节点不匹配或消费自身名称，帮助前缀始终来自
`Args.program`。根既无名称又无处理函数时，装配为内部空名称；它不是
可供子命令匹配的名称。构造只建立描述，调用 `.run()` 才解析与分派。

`cli(args, commands)` 构造自身动作为帮助、子列表为 commands 的 Cli。
需要自定义根函数时直接构造 Cli；下例中的 args、commands 已由调用方
提供，start 是完整处理函数：

```spore
Cli { args: args, handler: start, subcommands: commands }.run()
```

空输入按 start 的签名检查：零参数函数执行一次，有必填参数时返回
用法错误；显式 `--help` 仍由框架处理。进入子命令不会执行 start。

以下是独立的层级示意，不给 bootstrap 增加业务命令。假设完整的
`train(employee: Str, skill: Str)`、`run(target: Str)` 和零参数
`subcommand()` 均返回 Exit；这些名字不引用 bootstrap 的内部能力函数：

```spore
static skills = Command {
    name: "skill",
    subcommands: [Command { handler: train }],
};

fn main(args: Args) -> Exit {
    cli(args, [
        Command { name: "agent", subcommands: [skills] },
        Command {
            handler: run,
            subcommands: [Command { handler: subcommand }],
        },
    ]).run()
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

### 同质列表与静态转换

显式 `Command` 统一了列表元素，但并未让不同签名的函数自动具有相同
类型。源声明 `Command { handler: f }` 须先经 `compile.bindings` 读取
同一份函数声明，产生参数名列表与完整 `Binding.invoke` 包装体，并把
handler 转为 `Handler.Function { binding: ... }`。省略 handler 则使用
`Handler.Help {}`；它由框架根据当前节点产生帮助，不是零参数业务回调。

`operations.sp` 的 `Command` / `Handler` 定义描述完成适配后的表示。
直接函数引用的源写法先完成适配，再检查这些字段的类型；不能声称 f
本身属于 Handler，或普通函数值能恢复声明名与参数名。派生 name 也在
此阶段完成，不让字段默认初值访问正在构造的实例或其他字段。
显式 name 只覆盖路由名，Binding.name 仍保留原函数声明名。
平台正文与生成节点中的已适配 Handler 值按普通字段规则检查，不重复
包装，也不把 `cli` 构造中的 `Handler.Help {}` 当作业务函数引用。

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
直接构造 Cli 并调用一次 `.run()`；它不是供业务绑定的 Str 参数函数。
两种入口都经 `dispatch(root: Command, args: Args)` 和
`prepare(root: Command, args: Args)`，不再使用 Single / Group 两套表示。

根由 `cli(args, commands)` 或显式 Cli 构造，静态子树由 Command、列表
和已验证的静态引用组成，不由循环、条件或运行时函数生成。
`cli` 的构造正文与 `Cli.run()` 的分派顺序写在 `platform.sp`；方法取值
只绑定接收者，调用时才执行正文。Cli 作为 Command 使用时保留原节点
字段；Args 只由根持有，子节点不重新读取 argv。业务调度放在最终选定的
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
3. 否则按 subcommands 顺序寻找首个与下一参数精确同名的节点；命中
   即选定，消费名称并在该节点重复上述规则。
4. 输入为空或没有子节点命中时，选定当前节点自身动作；开始检查位置
   参数后，不再寻找子命令。

`Handler.Function` 按原函数签名核对参数。`Handler.Help` 只接受空参数，
返回与本节点 `--help` 相同的文本；未知名称或多余参数返回 Usage。
单独 `--` 移除后也是空参数：零参数函数可执行，缺省动作显示帮助，
有必填参数的函数仍报缺参。转义后再出现 `--` 也只是原值。
未转义时以 `-` 开头的业务参数、混用的 `--help`、中途出现的 `--`、
缺参和多参均为 Usage。子命令路径必须连续地出现在业务参数之前。

名称命中后不回退到父动作或后面的同名节点，也不合并同名子树。
进入子命令不执行父函数；没有子命令命中时，一个接受 Str 的自身函数
可能接收拼错的命令名，此时该字符串是否合法由业务判断。
新增同名子命令会优先于原有的自身参数解释；需要稳定地传入这种字符串
时使用 `--`，shell 引号不能消除这种歧义。

以默认帮助根下的单个必填 Str 命令 `run` 为例：

| Args.values 的内容 | prepare 的结果 |
| --- | --- |
| `["run", "my repo"]` | Invoke(run, `["my repo"]`) |
| `["run", ""]` | Invoke(run, `[""]`)；空字符串是否可用由业务判断 |
| `["run", "--help"]` | Help；不调用 run |
| `["run", "--", "--help"]` | Invoke(run, `["--help"]`) |
| `["run", "repo", "--help"]` | Usage；不调用 run |
| `[]` 或 `["--help"]` | 相同的根 Help；不调用业务 |
| `["missing", "repo"]` | Usage；未知命令 |

因此，`bootstrap` 与 `bootstrap --help` 输出完全相同的根帮助到 stdout，
stderr 为空，写入与刷新成功后退出 0；输出失败仍退出 1。这是根省略
handler 的结果；设置根函数后，空输入由其签名决定，不能继续强制帮助。

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
全部直接子命令及各自的自身签名；缺省动作标示为显示帮助。同名子项
保持原顺序并注明首个优先，不显示成另一条可选择的路由。帮助使用完整
调用路径和 Command.name，不把原函数声明名当作另一条调用路径。
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

**compile.bindings**：只在解析到本平台 Command / Cli 的静态声明构造处
适配 `handler: f`，不按同名拼写劫持用户自己的类型，也不为普通函数值
增加任意隐式转换。从同一版本、已解析并检查的完整具名函数声明取得
名称、参数顺序、参数类型和返回类型，生成参数名列表与完整
`Binding.invoke` 包装体，再装入 `Handler.Function`。省略 handler 时
使用 `Handler.Help`；省略 subcommands 时使用空的标准 `List[Command]`。
显式 name 须为静态可确定的 Str，优先于函数声明名；未提供则取函数名。
无函数的非根节点缺少名称时拒绝，
根也无名称时填入内部空串。派生名称在声明适配阶段完成，不用跨字段
默认初值实现。所有字段先完成适配，再按平台表示检查类型。

只接受非泛型、参数均为必填 `Str`、返回 `Exit` 的函数；有参数默认值、
依赖参数、匿名或动态选择的函数、不可见符号、未完成函数体时产生编译
诊断，不生成可运行产物。包装体把参数原样交给原函数，只在 Invoke
分支调用时执行；构造、帮助和解析期间不调用业务。

遍历所有静态子树引用，检查有限、无环与非根名称有效。空子列表合法，
重复兄弟名称保留原顺序；即使节点被前面的同名节点遮蔽，也必须完整
检查其声明。跨父节点复用不固化父路径，不合并或排序子树。
验证零／一／三个参数的包装、异签名节点的同质列表、显式改名及缺省
命名、函数改名和签名变化后的帮助与调用一致性。源构造到 Handler 的
适配、参数元数与来源保真仍是生成器验证义务，尚无 MLTT 证明；普通
函数值的运行时类型不被假定含有参数名。

**compile.assembly**：输入明确版本的本 spec、应用和所选 platform，
同时供应 Spore Spec 指定的标准库 List，固定它及 Empty／Item 的声明
身份；平台和应用必须使用同一个类型。完成列表字面量展开与元素类型
推断，不能按局部同名类型替换，也不能用缺失的标准库绑定继续构建。
解析文件间名字，按 main 的签名选择装配：业务 Str 参数入口生成一个
绑定 main、没有子命令的根及 `Args -> Exit` 适配器；`main(args: Args)`
入口检查静态树并构造 Cli、调用一次 `.run()`。只对明确登记的处理函数
生成绑定，接通原函数、包装、Cli.run、`dispatch` 与 `main_for_host`。
核验 Cli 的实例字段继承与 Command 父视图，方法选择不提前执行正文，
根不匹配自身名称；构造和分派使用同一 Args，不重新读取宿主输入。
固定宿主 ABI 不能随参数数量或命令深度变化。

Command / Cli 声明适配与静态子树引用的具体展开、模块导入拼写、
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
父节点动作、空子列表、混合元数、同名兄弟首个优先、错误不回退、
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

平级案例以四个完整处理函数及默认帮助根为输入：`init` 接受三个 Str，
`run`、`status`、`stop` 各接受一个 Str，全部返回 Exit，四个节点均无
子命令。多级案例另用上方示意树及其完整处理函数。
测试用可观察业务记录判断是否进入处理函数，不能
只检查解析器自报的成功。

| 输入或边界 | 必须观察到的行为 |
| --- | --- |
| `init repo contract control`；`run repo`；`status repo`；`stop repo` | 只调用对应函数一次，参数保真，退出值原样传递 |
| `bootstrap`；`bootstrap --help` | stdout 根帮助完全相同、stderr 为空、退出 0；无业务调用 |
| 只构造 Command / Cli / cli，或只选择 app.run 方法值 | 保持数据和声明顺序；不解析 argv，不输出，不调用业务 |
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
| 同名节点分别拥有不同子树，输入仅匹配后者子树 | 仍选首个节点，并依其自身动作成功或报错；不合并或回退 |
| `run` 缺参、多参、`run repo --help`、`run repo --` | stderr 用法诊断、退出 2；无业务调用 |
| `run -- --help`；`run -- -x`；`run -- --` | 标记后的单个值按字面传入 run |
| 默认帮助节点的 `--`；`-- --help` | 前者显示本节点帮助；后者为多余字面参数 Usage |
| 显式 `name: "execute"` 绑定 run，输入 `execute repo` | 调用原 run 一次；帮助路径为 execute，原函数名不成为另一条路由 |
| 一个空字符串参数、中文、含空格参数 | 不裁剪、不重新拆词、不改写 |
| 非 Unicode 原始参数 | 解码诊断、退出 2；无业务调用 |
| 自动装配单命令 main，零参数函数、一个参数函数 | 作为无子命令的根，不要求 main 名称；按签名解析后调用一次 |
| 处理函数返回 Failure／Usage | 进程退出 1／2；平台不擅自重复调用或补报业务错误 |
| 帮助或诊断流短写、永久失败、刷新失败 | 正确续写或退出 1；不切换流假报成功 |
| 子树跨父节点复用；不同父节点下同名子命令 | 两条路径分别有效，帮助和调用不混淆父路径 |
| 循环子树、动态树、裸函数或元组元素、匿名 handler、错误签名、未完成函数、缺失模块 | 编译失败，无可运行生成物；遮蔽节点也须检查 |
| 无 handler 的非根节点未命名；空白、控制字符、空串或以 - 开头的非根名称 | 编译诊断，不能以字段默认值绕过 |
| 函数改名、参数改名或数量改变；保留显式命令名 | 缺省名称和参数帮助随声明更新；显式名称稳定，调用仍绑定同一函数 |
| 从纯证明调用宿主操作；异常终止 | 前者静态拒绝；后者不产生成功或清理完成证据 |
