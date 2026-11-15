# basic-cli：最小 MLTT platform spec

这是规约稿，尚未完成新版类型、效果、生成器和真实进程验证。
[platform.sp](platform.sp) 定义宿主入口、分派和退出；
[operations.sp](operations.sp) 定义命令、参数、名称匹配及三个边界契约。
本目录未接入现有 `spore.toml`；旧 `src/platform_contract.sp`、I/O 模块和
Rust host 是另外一套实现，不能用其测试结果证明本稿已实现。

## 基线与范围

采用 MLTT 基线：`Type` / `Prop`、`type` / `case`、显式 `let` 模式绑定。
不引入 CuTT 维度、路径、`law` 或占位公设。规约可以用组合正文或完整的
输入、结果、效果、失败契约定义函数；表达式 `_` 表示实现义务仍未满足。
可读性依靠每层只说明自己的职责，不通过遗漏分支或未定义的函数名获得。

列表字面量采用 Spore Spec 的 `G-list-literals`、`S-list-literals` 与
`D-list-literals`，使用同一个固定标准库 `List`，不在平台复制定义。
本稿在 operations.sp 显式选定并导出 `Option` 的 None / Some 定义、
`FilePath { text: Str }`、`OptionalPositional[T]` / `OptionalNamed[T]` 及其必填分支别名；应用使用同一名义类型。它们不是编译器内建，
也不能由仅仅同名的 Lab 类型替换。FilePath 是路径文本，不是存在性、
目录类型或访问权限的证明。

本轮支持有限的静态命令树、必填 `Positional[T]` / `Named[T]` 与可选
`OptionalPositional[T]` / `OptionalNamed[T]`。T 仅为 `Str` 或 `FilePath`；可选位置参数至多一个，
且必须是位置参数子序列的最后一项。短选项、无值开关、`--name=value`、
函数参数默认值、自定义 decoder、环境变量输入、动态树及动态注册尚未定义。
Unicode 输入域外的原生路径明确拒绝，不用替换字符有损转换。

## Command.run 与应用命令

每个节点只持有 name、handler、subcommands，并直接提供
`run(args: List[Str]) -> Exit`。args 从该节点自己的名称开始；应用入口
直接传入完整宿主 argv，不创建 Args、Cli 或 cli 包装，也不提前取出首项。
构造 Command、引用子树或选择方法值均不解析输入、输出或调用 handler。

应用 main 不要求 pub，不接收 platform 参数。bootstrap 的接口形状为：

```spore
fn main(args: List[Str]) -> Exit {
    Command {
        name: CommandName.Any {},
        handler: init,
        subcommands: [
            Command { handler: init },
            Command { handler: run },
            Command { handler: status },
        ],
    }.run(args)
}
```

此例引用的三个处理函数必须由应用供应。其契约在这里逐一定义；
伴随 bootstrap 规约的 system.sp 为三者提供并列的组合正文，平台不替应用实现业务：

| 函数签名 | 输入、效果与结果契约 |
| --- | --- |
| `init(repository: OptionalPositional[FilePath]) -> Exit` | 将 repository 按子类型关系直接传给 Option 接口以确定项目目录，读取并校验项目输入，确认初始化；成功时保存首轮 Ready，输出 run_id / seed / Pending 并退出 0；取消、重复初始化或失败退出 1，不覆盖已有记录，不执行或验证 |
| `run(repository: OptionalPositional[FilePath]) -> Exit` | 将 repository 按子类型关系直接传给 Option 接口以确定目录，每次确认继续／原种子重启／新种子重启；取得独占权后只推进一轮并保存、收尾、报告；通过退出 0，拒绝或失败退出 1，安全主动中断可退出 0 但显示 Pending；不自动调度下一轮 |
| `status(repository: OptionalPositional[FilePath]) -> Exit` | 将 repository 按子类型关系直接传给 Option 接口以确定目录，读取一致快照并输出；查询成功退出 0，即使本轮 Rejected；失败退出 1，不执行、验证或恢复 |

三者解包后的 None 都进入以当前目录为默认值的目录选择；Some 直接校验显式
目录，不重复提示目录，也不在坏路径时回退。相对路径基于命令开始时的
当前目录。显式目录不免除 init 的初始化确认或 run 的方式确认；
status(OptionalPositional.Some) 可在没有交互终端时查询。输入关闭、取消或缺少终端不自动
开始 init / run。run 的回车确认 Continue，未输入不等于按过回车。

项目 bootstrap.toml 引用 Contract、Control、Executor；项目记录属于
项目目录，用户全局信息只在首次有效业务启动时初始化并复用。
一轮是执行、保存候选、验证、保存结果。通过和拒绝都结束；Continue
仅补未完成阶段，终态只报告已有结果。重启创建新轮次，保留历史费用，
分别复用或更换 seed；续跑恢复完整随机状态，同 seed 不保证模型输出相同。
具体 Agent、上层调度、存储和 Ctrl+C 收尾属于应用契约。

## 节点名称与统一消费

| 字段 | 含义与缺省规则 |
| --- | --- |
| `handler` | 当前节点的完整具名处理函数；省略时为 Handler.Help |
| `name` | Exact(value)、Any 或 Auto；默认 Auto，从同一 Binding 读取函数声明名 |
| `subcommands` | 按优先级排列的直接子节点，默认空列表 |

字段值使用 CommandName 的 case 构造式，不接受裸字符串。Auto 保留原值，
不改写为 Exact；名称比较读取 Binding.name，不反射普通函数或调用业务。
**所有节点都需要可匹配名称，包括根。** Help + Auto 没有声明名，
无论出现在根还是子节点都拒绝装配；默认帮助根应显式写 Any 或 Exact。
Exact.value 和 Auto 使用的声明名须非空、无空白或控制字符、不以 `-` 开头。
名称比较使用纯 text_equal 判定完整 Unicode 标量序列，不改大小写、下划线或路径，不取 basename。

进入任何节点时都用同一规则：输入非空，比较首个 token，成功则消费
恰好一个 token，随后处理该节点的剩余输入。匹配失败或没有 token
返回 Usage。Any 在任何层级都消费一个 token；它不接受零项，也不贪婪
消费多项。空字符串仍是一个 token，Any 可以匹配它；这与空列表不同。

根 Any 自然消费 bootstrap 或完整启动路径。Exact 根必须匹配指定值，
Auto 根必须匹配处理函数名。具名子树作为独立入口时仍需输入自己的名称，
例如 Exact("run") 节点的调用输入为 ["run", "repo"]。复用子树不会固化
原父路径，也没有跳过根名称的复用特例。

每次进入记录实际消费的 token；帮助路径由这条序列组成。Any 的显示
标记、函数名或配置中的别名不能替换已经消费的值。名称 token 不自动
追加到处理函数的业务参数中，原 argv 保持不变。

## 有序路由、帮助与字面参数

节点已经匹配并消费自身名称后，依次执行：

1. 余项恰为 ["--help"]：产生当前帮助，不绑定参数，不调用业务。
2. 余项以独立 `--` 开头：选定当前自身动作，停止子命令路由；保留
   原始余项，交由当前动作的参数扫描消费标记并进入字面模式。
3. 否则，首个余项存在且不以 `-` 开头：按 subcommands 声明顺序匹配，
   选中第一个命中的节点，进入同一匹配并消费名称的步骤。
4. 没有子节点命中或余项为空：选择当前自身动作，开始参数绑定。

名称匹配本身只比较值；`--help` / `--` 只在已选节点的余项中具有控制
含义。父节点会先处理这些标记，不把它们交给通配子节点抢占。
因此 argv[0] 也无需特殊拆分：它经过同一个名称匹配步骤。

Exact / Any / Auto 没有额外优先级。同名节点合法、首个优先，不合并
子树；名称选中后不因缺参、类型转换失败或后续路径不匹配而退回父动作
或其他兄弟节点。进入子命令不先执行父 handler。开始自身参数绑定后
不再寻找子命令；拼错的命令词可能成为当前默认动作的位置参数。

Handler.Help 只接受空余项或恰为 ["--"]，输出与当前 `--help` 相同的帮助。
其余输入为 Usage。Function 的完整余项交给 bind；`--` 可在参数中途
开启字面模式，混用且尚未转义的 `--help` 为 Usage。子命令路径必须先于参数，
不支持把父选项放在子命令名之前，也不继承父选项。
帮助列出自身和全部直接子命令的签名，保留顺序并注明首个匹配优先；
已选路径使用实际 token。根名不匹配时诊断实际输入和期望名称，不虚构
已经匹配的路径。帮助及诊断本身都不执行业务。

## 参数类型、绑定与省略

`OptionalPositional[T]` 与 `OptionalNamed[T]` 各有 None / Some 分支；
Some 只有 `value: T`。`Positional[T]` / `Named[T]` 分别是对应 Some 的透明别名。
适配器从声明的名义角色类型及分支决定角色与可选性，T 决定解码；
不能先上转为 Option 再猜角色，也不能从某次实参恰好为 Some 推断必填。
普通 Spore 调用显式构造对应分支，不引入关键字调用或隐式解包。
以下 T 仅指 `Str` 或 `FilePath`：

| 声明类型 | Parameter.role / optional | 输入与构造 | 帮助 |
| --- | --- | --- | --- |
| `Positional[T]` | Positional / false | 按位置取一个值，构造 Positional(value) | `<name>: T` |
| `OptionalPositional[T]` | Positional / true | 省略为 OptionalPositional.None，提供值为 OptionalPositional.Some(value) | `[name]: T` |
| `Named[T]` | Named / false | 必须提供 `--name value`，构造 Named(value) | `--name <value>: T` |
| `OptionalNamed[T]` | Named / true | 省略为 OptionalNamed.None，提供值为 OptionalNamed.Some(value) | `[--name <value>]: T` |

Parameter.kind 对 Str 为 Text、对 FilePath 为 Path；表中的构造写法是
说明性缩写，实际源码使用相应记录和 case 构造式。必填命名选项仍然必填；
可选位置参数仍然按位置消费，不会因为可省略而生成命名选项。
例如这个完整处理函数只输出所给路径文本，不访问文件：

```spore
fn show_output(source: Positional[FilePath], output: Named[FilePath]) -> Exit {
    emit(Channel.Stdout {}, output.value.text, Exit.Success {})
}
```

绑定为子命令后，`tool show_output src --output dist` 和
`tool show_output --output dist src` 都把 src / dist 分别包装为
Positional[FilePath] / Named[FilePath]，再按形参声明顺序调用一次。
必填分支可通过 `.value` 取 T；可选根须匹配分支，或直接传给接受 Option[T] 的业务函数。

同一个 T 下，显式 impl 与分支注入共同建立：

```text
Positional[T] <: OptionalPositional[T] <: Option[T]
Named[T]      <: OptionalNamed[T]      <: Option[T]
```

反向不成立，位置与命名两族互不为子类型；不额外假定类型族协变。
本包拥有这些名义构造器，负责公开 None / Some 对应与根关联；
每条 impl 都须核验完整性、孤儿规则、根分支覆盖及直达／复合路径一致性。
透明别名和重新导出不转移所有权，不能用声明代替未完成的证明。

命名选项由形参名精确生成 `--name`，保留大小写和下划线，不改为连字符。
Named / OptionalNamed 形参必须有非匿名的唯一名称；`help` 保留给框架，拒绝该命名形参。
位置和命名形参可以交错声明；位置值仅按 Positional / OptionalPositional 子序列分配。
可选位置后再出现必填位置、多个可选位置、裸 Str / FilePath / Option、
嵌套角色包装、其他未支持类型或参数默认值都拒绝装配。

选定节点后，bind 从左到右扫描原始余项，初始不在字面模式：

1. 独立 `--` 开启字面模式并被消费；此后每个 token 都是位置值，
   包括后续 `--` 和 `--help`，不再识别选项或子命令。
2. 模式外，精确的 `--name` 必须匹配当前节点的 Named / OptionalNamed 形参，且只出现一次。
   它消费紧接的一个值，该值不能以 `-` 开头；没有下一项或下一项是
   `--`、`--help`、其他选项或其他 `-` 前缀文本都为缺值 Usage。
3. 模式外，其余非 `-` 前缀 token 作为位置值；未知选项、`--name=value`、
   混用的 `--help` 及其他 `-` 前缀值均为 Usage。

扫描后核对必填项和位置元数，再解码并构造对应角色的 None / Some。
OptionalNamed[T] 可以完全省略，但出现 `--name` 后必须给值。
所有失败都不产生可调用的 Ready，不调用业务。首版命名选项不支持
以 `-` 开头的值；`--` 只为后续位置值转义，不能替命名选项转义。
例如 `tool show_output --output dist -- --help` 把 --help 作为 source；
`tool show_output src --output --help` 为缺值 Usage。

Str 原值传递且允许空字符串；FilePath 拒绝空文本或 NUL，再构造路径值。
一个显式空字符串不是缺省；解码不读取文件、不解析真实路径、不补 cwd。
目录是否存在、符号链接身份与权限由应用校验。引号由启动器处理，
参数中的真实空白和引号原样保留，不再次拆词或展开变量／通配符／@文件。

Binding 同时保存函数名、List[Parameter] 与生成的 bind 函数。
`bind: List[Str] -> ArgumentBinding` 接收尚未删除 `--` 的完整余项，按
同一函数声明扫描、核对和解码，失败返回 Usage；成功返回 Ready，携带
捕获原函数及完整角色实参的零参 invoke 闭包。实参按原形参顺序排列，
不受命名选项的输入顺序影响。创建闭包不调用原函数，bind 不做 I/O。
`prepare` 把它装入 Decision.Invoke；`dispatch` 才调用一次 invoke。
帮助、参数元数据和解码器必须从同一声明生成，不能各维护一套规则。

## 输入与入口装配

`read_args` 一次读取并无损解码完整宿主 argv，返回 Input.Ready 中的
List[Str]；首项和后续项保持同序。没有 Args.program / Args.values，
不提前分离或合成程序名。空 argv 仍返回 Ready([])，由统一节点入口
报告缺少名称。非法 Unicode 为 Input.Usage，读取机制故障为 Input.Failure。

`main(args: List[Str]) -> Exit` 是原始列表入口，由应用选择完整根并
调用 Command.run(args)。这个单个 List[Str] 入口签名不属于业务参数
适配范围。单命令应用也可直接提供符合上表的业务 main；装配器将其
绑定到显式 Any、无子节点的 Command，并生成 List[Str] -> Exit 入口。
生成的根也匹配并消费名称，不用 main 的声明名替换真实启动名称。

固定调用链为宿主 → main_for_host → 已装配入口 → Command.run →
prepare → 帮助／诊断或一次 invoke → exit_code → OS 状态。
Command 不存储本次参数；子节点不读取宿主 argv，固定 ABI 不随参数
数量或命令深度变化。Exit 的正常返回不证明任务完成、权限或验证通过。

## 完整实现义务

函数具有契约定义不等于已经实现。以下条目当前均 pending；缺少任何
必要提供者，不能生成宣称可运行的新版产物。类型与函数的同名拼写不能
替代名义身份、实际导入或完整依赖绑定。

| 标识 | 位置 | 输入、产出与完成依据 |
| --- | --- | --- |
| `host.arguments` | operations.sp / read_args | 宿主完整 argv → 无损 List[Str] 或读取／解码错误；真实边界证据 |
| `text.equal` | operations.sp / text_equal | 两个 Str → 精确 Bool；纯、终止，不用命题等同冒充布尔判定 |
| `cli.prepare` | operations.sp / prepare | 有效 Command、完整列表 → 已解码调用闭包、帮助或用法诊断；统一消费与下方矩阵 |
| `host.write` | operations.sp / write_text | 指定流及文本 → 完整写入并刷新结果；短写和失败证据 |
| `compile.bindings` | 下文 | 函数声明与静态命令树 → 同源名称、参数元数据及 bind / invoke 提供者 |
| `compile.assembly` | 下文 | 平台、应用和标准 List → 同一类型身份、可见符号和固定宿主入口 |
| `runtime.effects` | 下文 | 纯数据处理与运行代码 → 不污染证明求值的效果隔离 |
| `host.lifecycle` | 下文 | 固定入口及流 → 实际进程退出行为 |
| `validation.evidence` | 下文 | 完整实现与夹具 → 分层且可复核的证据 |

**compile.bindings**：只适配本平台 Command 的静态 `handler: f`，不劫持
同名用户类型，不为任意函数值增加反射。解析同一完整具名、非泛型函数，
要求返回 Exit，参数满足本稿角色、类型及省略规则。生成 Binding.name、parameters
及完整 bind / invoke，省略 handler 则为 Help。Exact / Any / Auto 原值
保留，所有层级的 Auto 都须有函数声明名；Help + Auto 始终拒绝。
检查全部静态子树有限、无环，显式及自动名称有效；被遮蔽节点仍须检查。
不接受匿名或动态 handler、裸函数／元组节点、未定义函数或不可见依赖。
规约可以保留明确契约的实现义务，但未完成函数或下层依赖阻止生成可运行产物。

**compile.assembly**：供应同一个标准 List 及 Empty / Item 构造器，完成
字面量展开与类型推断。固定本稿 Option、FilePath、OptionalPositional、OptionalNamed、Positional、Named、Command 等类型的身份，
应用不能用同名类型绕过签名检查；跨模块构造和匹配的分支均显式标为 pub case。绑定 text_equal 的精确布尔判定；语言中的 `==` 仍产生命题。按公开
成员和实际模块边界解析符号，连接 Command.run、dispatch 和 main_for_host。
方法取值不执行正文，调用使用传入的原列表；两种入口形式都遵守统一消费。
具体模块导入拼写、manifest、声明展开及跨语言 ABI 仍须实现；不得通过
隐式文件拼接或回退旧入口掩盖缺失。验证私有 main、两个独立应用、子树
复用、错误签名、可见性拒绝和构造阶段零业务调用。

**runtime.effects**：read_args、Command.run、dispatch、invoke、write_text
及业务调用链可能产生效果、失败或不终止。Command 构造、text_equal、名称比较、
prepare 和 bind 只处理数据；捕获一个调用不等于执行它。实现须保持实际
调用顺序与效果，禁止在类型形成、定义相等检查或证明构造中执行宿主动作。
不以一个未定义的载体或占位公设假装效果机制已经完成。

**host.lifecycle**：宿主只调用固定入口一次，把 0／1／2 交给 OS。
正常输出和诊断在返回前刷新；短写按已确认字节继续，永久失败退出 1，
不重放业务或切换流假报成功。强制终止、崩溃和信号退出不是 Exit 正常
返回，不产生已清理或业务完成证据。应用自己的取消与恢复由应用契约负责。

**validation.evidence**：分别记录语法、类型、效果、生成绑定与真实进程
证据。旧 host 测试、旧编译器成功或语法识别不能关闭新版实现义务。
未解 `_`、缺少 bind / invoke、未完成导入或效果隔离都继续 pending。
验收必须观察实际选中的函数及参数，不能只检查退出码或解析器自报成功。

## Examples 与验收矩阵

函数 Examples 使用 `Given` 说明完整环境，以 `Expect` 规定结果及效果。
Given 引用的函数、节点、参数和状态是须供应的完整夹具，不是隐式全局
变量或已有测试 API。所有 Examples 当前 pending；后续需提取代码、供应
完整依赖与可控宿主，把期望落成断言并保留执行证据。纯计算比较结果值，
I/O 案例还观察 argv、stdout、stderr、刷新和业务调用。语法识别不等于执行。

下表输入均为**完整列表**或包含启动名称的命令行。bootstrap 使用前述
三个可选目录命令；其他夹具单独注明。路径类型转换只发生在参数阶段，
不能把名称 token 当成路径参数解码。

| 输入或边界 | 必须观察到的行为 |
| --- | --- |
| `[]` | 缺少根名称 Usage，退出 2；不进入默认 init，不显示缺省帮助 |
| `bootstrap`；`bootstrap init` | 都只调用 init(OptionalPositional.None) 一次；根和显式 init 各消费自己的名称 |
| `bootstrap repo`；`bootstrap init repo` | 都只调用 init(OptionalPositional.Some(FilePath("repo")))；根默认参数不被多消费 |
| `bootstrap run`；`bootstrap status` | 只调用对应函数并传 OptionalPositional.None，不先调用 init |
| `bootstrap run repo`；`bootstrap status repo` | 对应函数收到 OptionalPositional.Some(FilePath("repo"))；不提示目录选择 |
| 任一命令两个目录值；显式空路径或 NUL | Usage，业务调用为零；空参数不能变成 None |
| `bootstrap --help`；`bootstrap run --help` | 对应帮助含 [repository]: FilePath；不交互、不创建项目或全局记录 |
| `bootstrap -- run` | 根 init 收到目录 run，不进入子命令 |
| `bootstrap run -- --help`；`bootstrap run -- -x` | run 收到相应字面路径；不显示帮助、不当成关键字选项 |
| `bootstrap run repo --help` | 混用框架帮助 Usage，不调用业务 |
| `bootstrap run repo --` | 末尾标记不增加位置值，捕获与 run repo 相同的角色参数 |
| `bootstrap run --repository repo` | 未知选项 Usage；Positional 不从参数名产生选项 |
| build(source: Positional[FilePath], output: Named[FilePath])：`tool build src --output dist`；`tool build --output dist src` | 两者均捕获 Positional(FilePath("src"))、Named(FilePath("dist"))，按声明顺序调用 |
| 同一 build：`tool build --output dist -- --help` | source 的内层路径为 --help；命名选项先绑定，标记后全部为位置值 |
| 同一 build：`tool build src`；`tool build src --output`；`tool build src --output --help` | 必填选项缺失或缺值 Usage，业务调用为零 |
| 同一 build：重复 --output，即使值相同；未知 --other；--output=dist | Usage，不覆盖、不合并、不猜测选项名 |
| 同一 build：`tool build -- src --output dist` | -- 后三个位置值，Usage；不恢复选项识别 |
| 同一 build：--output 后为空串、含 NUL 或 - 前缀文本 | 前两者路径解码 Usage，后者缺值 Usage；不能通过 -- 为命名值转义 |
| inspect(label: OptionalNamed[Str], source: OptionalPositional[FilePath])：`tool inspect` | 捕获 OptionalNamed.None、OptionalPositional.None |
| 同一 inspect：`tool inspect src --label ""`；`tool inspect src --label` | 前者捕获 OptionalNamed.Some("")、OptionalPositional.Some(FilePath("src"))，后者缺值 Usage |
| 同一 inspect：`tool inspect --help` | 帮助含 [--label <value>]: Str 与 [source]: FilePath，保留声明顺序，零绑定和业务调用 |
| output_dir: Named[FilePath]；输入 --output_dir dist / --output-dir dist | 前者匹配，后者未知选项；不改写形参名 |
| 多个 Named / OptionalNamed 形参、与 Positional 交错声明、命名选项倒序输入 | 按名称分配命名值、按位置子序列分配位置值，invoke 始终使用完整声明顺序 |
| OptionalPositional[Str]：省略 / 显式空串；Named[Str]：缺选项 / 显式空串 | 前者为 OptionalPositional.None / OptionalPositional.Some("")；后者 Usage / Named("") |
| 显式目录有效但 run 菜单未确认、EOF 或无终端 | 平台可已分派，应用仍不得取得运行权或生成 seed |
| 默认 Any / Help 根：`tool`；`tool --help`；`tool --` | 相同根帮助，退出 0，无业务调用 |
| 默认 Any / Help 根：`tool missing`；`tool -- --help` | 当前节点 Usage；帮助动作不吞业务参数 |
| Any 根：`/tmp/renamed-tool run repo` | 消费完整启动路径，再消费 run；帮助路径保留实际名称，不取 basename |
| Exact("tool") 根：`tool`；`other` | 前者进入根动作，后者名称不匹配 Usage；没有根名称豁免 |
| Auto / start 根：`start`；`tool` | 前者调用 start，后者 Usage；Auto 在根同样读取声明名 |
| Exact("run") 子树独立调用 ["run", "repo"]；["repo"] | 前者匹配并消费 run，后者名称不匹配；复用不跳过名称 |
| `tool agent skill train reviewer rust` | 消费全部四段名称，只把 Positional("reviewer") / Positional("rust") 交给完整 train(Positional[Str], Positional[Str]) 夹具 |
| `tool agent skill --help`；组自身没有 handler | 显示该组及直接子命令签名，使用实际消费的完整路径 |
| 父 run(Positional[Str]) 含 subcommand(Positional[Str])：`tool run subcommand` | 子节点缺参 Usage，不回退父函数 |
| 同一夹具：`tool run -- subcommand` | 只调用父 run，传 Positional("subcommand") |
| 同一夹具：`tool run some_arg subcommand` | 父函数多参 Usage，不在参数中途路由 |
| 子列表 Any(first)、Exact("run", second)：`tool run repo` | 首个 Any 消费 run，只选择 first；交换声明顺序则选择 Exact |
| 子列表 Auto(first)、Exact("first", second)，首个缺参 | 首个节点的 Usage，不试探后面的元数或合并子树 |
| Any 子节点无剩余 token；余项为 --help 或 -- | 父节点处理自身动作或控制标记，Any 不在空输入时进入、不抢控制标记 |
| Any 子节点下含 status：`tool project-1 status --help` | 路径为 tool project-1 status，不用 Any 或声明名替换 project-1 |
| Any 子节点绑定零参函数：输入 ["tool", ""] | 消费空字符串这一项，调用零参函数；不同于空路径业务参数的解码错误 |
| 必填 Positional[Str] 夹具收到空字符串；路径夹具收到含空格或中文值 | Str 原值接受；先构造 FilePath 再构造角色 Some 分支，不裁剪、不拆词、不读文件 |
| 构造 Command、引用共享子树、选择 run 方法、prepare 或 bind | 零业务调用；只在 dispatch 的 Invoke 分支调用一次 |
| 名称、元数或解码失败 | 零业务调用；不以 handler 运行结果试探参数类型 |
| handler 返回 Failure / Usage | 退出 1 / 2；平台不重复调用或补报业务诊断 |
| 帮助／诊断短写、永久失败或刷新失败 | 正确续写或退出 1，不重放已写前缀，不把失败覆盖为成功 |
| 同一节点跨父节点复用或作为根 | 每次匹配并消费自己的名称，路径由本次输入累计，不修改共享节点 |
| 根或子节点 Help + Auto；无效 Exact / Auto 名称 | 装配拒绝；不按挂载位置豁免，不隐式生成 Any |
| 同名节点、空子列表、前方通配造成遮蔽 | 声明合法但保留优先级；被遮蔽的函数与参数类型仍须完整检查 |
| 未支持参数、可选位置后接必填位置、两个可选位置、动态／循环树、未定义或不可见函数 | 装配拒绝；可选位置后接必填 Named 及多个可选 Named 合法 |
| 裸 Str / FilePath / Option、Positional[Option[Str]]、Named[Option[Str]]、Option[Named[Str]]、Named[Positional[Str]]、默认值或同名仿造包装类型 | 装配拒绝；只接受本平台名义角色根／Some 分支及透明别名，T 仅为 Str / FilePath |
| Named / OptionalNamed 形参名为 help、匿名或重复 | 装配拒绝，不产生含糊的选项匹配或覆盖框架帮助 |
| 函数改名、参数名／角色／值类型／可选性变化 | Auto 名称、命名选项、帮助、解码及包装调用从同一声明同步；Exact 别名保持显式值 |
| 单命令 main 的零参、必填或可选路径签名 | 自动根明确为 Any，消费启动名称后按同一规则绑定并调用一次 |
| 非 Unicode argv；宿主传空 argv | 前者在读取阶段 Usage，后者保留 [] 并在节点入口 Usage；不合成程序名 |
| 从纯证明调用宿主操作；进程异常终止 | 前者静态拒绝，后者不产生成功或已清理证据 |
