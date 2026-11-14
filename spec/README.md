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

首版支持单命令和一个平级命令组，参数全部是必填 `Str` 位置参数，
命令正常返回 `Exit`。只增加启动、参数与终端输出契约；文件、网络、
进程执行、调度、预算和工作恢复不在本稿中扩展。现有 I/O 模块可作为
后续实现参考，但旧 `foreign` / `uses` 语法不因此成为新版语言规则。

默认值、类型转换、可选参数、短选项、环境变量输入、嵌套命令和动态
注册均不在首版。原生非 Unicode 路径也不在首版输入域内，必须明确
拒绝而非有损解码。

## 应用接口与实际调用

应用 `main` 不要求 `pub`，也不接收 platform 类型参数。以下是待实现的
注册表面提案，不是现有编译器已经提供的库 API；其中四个处理函数须由
应用实际定义，函数体缺失不能由注册补齐：

```text
fn main(args: Args) -> Exit {
    cli(args)
        .command(init)
        .command(run)
        .command(status)
        .command(stop)
        .run()
}
```

每个 `.command(f)` 只引用一个静态可解析的具名函数。名称和参数名来自
同一份函数声明，应用不再手写 `Command`、参数 schema 或调用包装。
链的顺序决定帮助中的展示顺序；命令名与函数名完全一致，首版不做
重命名或下划线转换。帮助只生成签名与固定规则，不推断业务说明。

单命令应用直接提供带业务参数的 `main`，可有零个或多个必填 `Str`
参数并返回 `Exit`；编译器为它生成 `Interface.Single` 和解析入口。
多命令应用的 `main(args: Args) -> Exit` 直接接收已解码输入，上述链
展开为对 `dispatch` 的调用，传入含完整绑定列表的 `Interface.Group`
和原 Args。首版 Group main 只允许这一条静态注册链及一次 `.run()`，
注册阶段不能执行其他业务表达式；宏观业务调度放在命令处理函数内。

运行关系固定为：宿主启动 → `main_for_host` 读取输入 → 已装配入口 →
`prepare` → 帮助／用法诊断或一次业务调用 → `exit_code` → OS 进程状态。
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
这里的列表写法用于说明数据；实际 Spore 构造使用
`List.Item` / `List.Empty`，见 `operations.sp` 中 `Args` 的例子。

处理依次经过四个边界：

1. `read_args` 读取一次宿主 argv，完成无损解码，返回 `Input.Ready(args)`、
   `Input.Usage` 或 `Input.Failure`；`Ready` 仅表示输入读取与编码有效。
2. `prepare` 将同一个 `Args` 与编译器生成的 `Interface` 结合。Group 消费
   命令名，Single 不消费命令名；随后处理帮助、开头的 `--` 和参数数量。
3. `Decision.Invoke` 携带选定的 Binding 及剩余业务参数。`Args.values`
   中的命令名与分隔标记不会进入 `Binding.invoke` 的 values。
4. `dispatch` 才调用业务函数。例如 `run("my repo")` 只收到 repository；
   目录是否存在、权限和恢复条件继续由业务契约检查。

以单个必填 Str 参数的 Group 命令 `run` 为例：

| Args.values 的内容 | prepare 的结果 |
| --- | --- |
| `["run", "my repo"]` | Invoke(run, `["my repo"]`) |
| `["run", ""]` | Invoke(run, `[""]`)；空字符串是否可用由业务判断 |
| `["run", "--help"]` | Help；不调用 run |
| `["run", "--", "--help"]` | Invoke(run, `["--help"]`) |
| `["run", "repo", "--help"]` | Usage；不调用 run |
| `[]` 或 `["missing", "repo"]` | Usage；不默认选择某个命令 |

`List` 在本稿中提供有限、有序序列的最小定义，不规定宿主 ABI 的内存
布局。`Args` 没有解析游标、已选命令、默认参数或环境变量；增加新的
业务参数只修改处理函数声明及其绑定，不修改 `Args` 的结构。
已有 `Args` 可直接供解析示例使用，无须读取真实进程输入。

## 函数 Examples 与后续执行

每个函数的前置注释包含 `Examples`，使用 Markdown 的 `spore` 代码块，
以 `Given:` 说明输入和测试环境，以 `Expect:` 写出结果及可观察行为。
代码块使用真实函数签名；Given 中的命名值是待提供的测试数据，不能
假定它们是现有全局变量或新增的测试 API。未声明已有支持的断言、
列表简写、fixture 构造器和执行命令不会混入示例代码。

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
| `cli.prepare` | `operations.sp` / `prepare` | 已绑定 Interface、Args → `Decision`；完整约束、错误和验收写在函数体内 |
| `host.write` | `operations.sp` / `write_text` | 指定流与文本 → 写入并刷新结果；完整约束、错误和验收写在函数体内 |
| `compile.bindings` | 编译期提供义务 | 已检查的函数声明与静态注册 → 完整 Binding；要求见下文 |
| `compile.assembly` | 编译与链接义务 | 选定 platform、应用及 spec → 固定宿主入口；要求见下文 |
| `runtime.effects` | 静态与运行边界 | 运行代码、纯代码及宿主操作 → 可执行但不污染证明求值的隔离；要求见下文 |
| `host.lifecycle` | OS 接入义务 | 宿主回调、流和进程 → 实际调用与退出行为；要求见下文 |
| `validation.evidence` | 验证义务 | 上述实现与固定输入 → 可复核的语法、类型及进程观察；要求见下文 |

**compile.bindings**：读取同一版本、已解析并检查的函数名、参数顺序、
参数类型和返回类型，生成参数名列表及 `Binding.invoke` 的完整包装体。
包装体把参数原样交给原函数，只在 Invoke 分支调用时执行；不得在注册、
生成帮助或部分解析时调用业务。只接受非泛型、参数均为必填 `Str`、
返回 `Exit` 的处理函数；有默认值、依赖参数、重复命令名、空命令组、
不可见符号或未完成函数体时产生编译诊断，不生成可运行产物。
验证零／一／三个参数的包装，以及函数改名、签名改变后帮助和调用同步
变化。参数元数与来源保真目前是生成器的验证义务，尚无 MLTT 证明；
普通函数值的运行时类型不被假定含有参数名。

**compile.assembly**：输入明确版本的本 spec、应用和所选 platform，
解析文件间名字，检查 Single／Group 模式及 Group main 的静态链限制，
连接原函数、生成包装、`dispatch` 与 `main_for_host`。单命令生成
`Args -> Exit` 入口；多命令
使用应用的 `main(args)`，只对明确注册的函数生成绑定。固定宿主 ABI
不能随业务参数数量变化。`cli` / `.command` / `.run` 的具体展开实现、
模块导入拼写、manifest 配置及跨语言 ABI 都尚未提供；缺失或不匹配
必须阻止构建，不回退到旧的 `main() -> ()`。验收须包含两个独立应用、
私有 main、跨文件可见性拒绝，以及错误入口签名的编译失败。

**runtime.effects**：`entry`、`Binding.invoke`、`read_args`、`write_text`
及其调用链属于运行层，可能执行 I/O、失败或不终止。它们在本文的普通
函数签名仅描述调用边界，不意味着能够作为纯 MLTT 证明项归约。实现须
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
还须逐例执行函数 Examples：实现提取器、提供 Given 所需的完整值和
可控宿主环境，将 Expect 变成结果及行为断言，并保留实际执行证据；
提取、测试数据、断言或运行支持缺失时不得把该例标为通过。

## 首版验收矩阵

以下以四个已实现处理函数为输入：`init` 接受三个 Str，`run`、`status`、
`stop` 各接受一个 Str，全部返回 Exit。测试用可观察业务记录判断是否
进入处理函数，不能只检查解析器自报的成功。

| 输入或边界 | 必须观察到的行为 |
| --- | --- |
| `init repo contract control`；`run repo`；`status repo`；`stop repo` | 只调用对应函数一次，参数保真，退出值原样传递 |
| 根级 `--help`；`run --help` | stdout 帮助、退出 0；无业务调用 |
| 空命令组输入、未知命令、缺参、多参、`run repo --help` | stderr 用法诊断、退出 2；无业务调用 |
| `run -- --help`；`run -- -x`；`run -- --` | 标记后的单个值按字面传入 run |
| 一个空字符串参数、中文、含空格参数 | 不裁剪、不重新拆词、不改写 |
| 非 Unicode 原始参数 | 解码诊断、退出 2；无业务调用 |
| Single 的零参数函数、一个参数函数 | 不要求子命令名；按各自签名解析后调用一次 |
| 处理函数返回 Failure／Usage | 进程退出 1／2；平台不擅自重复调用或补报业务错误 |
| 帮助或诊断流短写、永久失败、刷新失败 | 正确续写或退出 1；不切换流假报成功 |
| 重复注册、错误签名、未完成处理函数或缺失模块 | 编译失败，无可运行生成物 |
| 从纯证明调用宿主操作；异常终止 | 前者静态拒绝；后者不产生成功或清理完成证据 |
