// ============================================================================
//  Mercury —— Langium (.langium) 版本
//  由 Fastbelt (.fb) 版本回译。文末「回译说明」列出了所有改写点与遗留问题。
//
//  速查映射（Fastbelt -> Langium）：
//    grammar X  +  entry R: ...      ->  grammar X  entry R: ...
//    interface T {} + R returns T:   ->  R infers T:
//    {Sub.Left=current}              ->  {infer Sub.left=current}
//    Op=OpGroup（token group）       ->  op=('a' | 'b')  或  op=OpGroup 规则
//    token T: /re/                   ->  terminal T: /re/
//    hidden token T: /re/            ->  hidden terminal T: /re/
//    comment token T: /re/           ->  hidden terminal T: /re/
//    composite C: ...                ->  C returns string: ...
//    LParen?=OPEN   /  RParen?=CLOSE ->  裸写 OPEN / CLOSE
//    E: E (op E)?（左递归）          ->  E: Next ({infer ...} op Next)*
//
//  Langium 不支持左递归，所有 yfx 层一律改写成「下一层 + 循环后缀」的形式。
// ============================================================================

grammar Mercury

// ============================================================================
//  一、词法规则
//  顺序 = 优先级：等长时先声明者胜；整体取最长匹配；关键字一律优先于 terminal。
// ============================================================================

terminal STRING: /"(?:""|\\[\s\S]|[^"])*"/;

//  必须在 NAME 之前：否则 `!IO` 会被拆成 `!` + `IO`
terminal STATE_VAR: /!\.?[A-Z][_0-9a-zA-Z]*|![:.]/;

terminal BACKQUOTE: /`/;

terminal IMPLEMENTATION_DEFINED: /\$[a-z][_0-9a-zA-Z]*/;

//  小写原子 / 引号原子 / 全符号原子
terminal NAME: /(?:[a-z][_0-9a-zA-Z]*|'(?:''|\\[\s\S]|[^'\\])*'|[#$&*+\-\/<=>?@^~\\]+)/;

terminal VARIABLE: /[_A-Z][_0-9a-zA-Z]*/;

terminal FLOAT: /[0-9](?:[0-9_]*[0-9])?(?:\.[0-9](?:[0-9_]*[0-9])?(?:[eE][+-]?[0-9](?:[0-9_]*[0-9])?)?|[eE][+-]?[0-9](?:[0-9_]*[0-9])?)/;

terminal INTEGER: /(?:0b_*[01](?:[01_]*[01])?(?:_*(?:i8|i16|i32|i64|i|u8|u16|u32|u64|u))?|0o_*[0-7](?:[0-7_]*[0-7])?(?:_*(?:i8|i16|i32|i64|i|u8|u16|u32|u64|u))?|0x_*[0-9A-Fa-f](?:[0-9A-Fa-f_]*[0-9A-Fa-f])?(?:_*(?:i8|i16|i32|i64|i|u8|u16|u32|u64|u))?|0'(?:""|\\(?:[abrftnv\\'\"]|x[0-9A-Fa-f]+\\|[0-7][0-7]*\\|u[0-9A-Fa-f]{4}|U[0-9A-Fa-f]{8})|.)|[0-9](?:[0-9_]*[0-9])?(?:_*(?:i8|i16|i32|i64|i|u8|u16|u32|u64|u))?)/;

//  Mercury 注释：% 行注释、/* */ 块注释。
//  Fastbelt 的 `comment token` 在 Langium 里没有对应物，一律作为 hidden terminal 跳过。
hidden terminal ML_COMMENT: /\/\*[\s\S]*?\*\//;
hidden terminal SL_COMMENT: /%[^\n\r]*/;
hidden terminal WS:         /\s+/;

// ---------- 句点：子句结束符 vs 模块限定符 ----------
//  最长匹配区分：`. ` 命中 END（2 字符），单独的 `.` 命中 DOT。
terminal END: /\.(?![^\s%])/;
terminal DOT: /\./; 

// ---------- 括号：紧密跟随 vs 前面有空白 ----------
//  ⚠ WS 声明在 OPEN 之前且为 hidden，前导空白通常先被 WS 吃掉，
//    所以 OPEN 实际很难命中，绝大多数位置都会落到 OPEN_CT。
//    若不需要这个区分，删掉 OPEN、只留 OPEN_CT 即可。
terminal OPEN:    /(?<=\s)\(/;
terminal OPEN_CT: /\(/;
terminal CLOSE:   /\)/;

// ============================================================================
//  二、composite -> returns string 的「数据类型规则」
//  模块限定名：作为字符串值存进字段。
// ============================================================================

QualifiedName returns string:
    NAME (DOT NAME)*;

//  用户自定义运算符：反引号包围的 name / module qualified name / variable。
//  注意：数据类型规则的返回值是所有 token 图象的拼接，反引号会包含在值里。
UserOp returns string:
    '`' (QualifiedName | VARIABLE) '`';

// ============================================================================
//  三、运算符组（Fastbelt 的 token group -> Langium 的 returns string 规则）
//  多字符运算符靠词法最长匹配自动压过短运算符
//  （`=<` 压过 `=`，`\==` 压过 `\=`，`--` 压过 `-`，`//` 压过 `/`，`..` 压过 `.`）。
// ============================================================================

QuantKind returns string:   'some' | 'all';
AssignOp returns string:    ':=' | '=^';
AddOp returns string:       '+' | '-' | '--' | '/\\' | '\\/';
ModOp returns string:       'mod' | 'rem';
UnaryOp returns string:     '-' | '\\';

OpModeAnnot returns string: '::' | '==>' | 'where';
OpDisj returns string:      ';' | 'or_else';
OpImpl returns string:      '<=' | '<=>' | '=>';
OpCompare returns string:
      '<' | '=' | '=..' | '=:=' | '=<' | '==' | '=\\=' | '>' | '>='
    | '@<' | '@=<' | '@>' | '@>=' | '\\=' | '\\==' | '~=';
OpMul returns string:       '*' | '/' | '//' | '<<' | '<<u' | '>>' | '>>u' | 'div';
OpQuant550 returns string:
      'try' | 'trace' | 'arbitrary' | 'atomic' | 'disable_warning' | 'disable_warnings'
    | 'promise_equivalent_solutions' | 'promise_equivalent_solution_sets'
    | 'require_complete_switch'
    | 'require_switch_arms_det' | 'require_switch_arms_semidet'
    | 'require_switch_arms_multi' | 'require_switch_arms_nondet'
    | 'require_switch_arms_cc_multi' | 'require_switch_arms_cc_nondet'
    | 'require_switch_arms_erroneous' | 'require_switch_arms_failure';
OpFy550 returns string:
      'promise_exclusive' | 'promise_exclusive_exhaustive' | 'promise_exhaustive';
OpFx550 returns string:
      'promise_impure' | 'promise_pure' | 'promise_semipure'
    | 'require_det' | 'require_semidet' | 'require_multi' | 'require_nondet'
    | 'require_cc_multi' | 'require_cc_nondet' | 'require_erroneous' | 'require_failure';
OpNegation returns string:  'not' | '\\+' | '~';
OpPurityFy returns string:  'impure' | 'semipure';
OpPurityFx returns string:  'func' | 'pred';
OpCaretFx returns string:   '^' | 'event';

//  `( op )` 里可以出现的任意一个运算符关键字
OpToken returns string:
      '!' | '!.' | '!:' | '@' | '^' | 'event' | ':' | '**' | '-' | '\\' | '*'
    | '/' | '//' | '<<' | '<<u' | '>>' | '>>u' | 'div' | 'mod' | 'rem' | 'for'
    | '+' | '++' | '--' | '/\\' | '\\/' | '..' | ':=' | '=^' | '<' | '='
    | '=..' | '=:=' | '=<' | '==' | '=\\=' | '>' | '>=' | '@<' | '@=<' | '@>'
    | '@>=' | '\\=' | '\\==' | 'is' | 'and' | 'or' | 'func' | 'impure' | 'pred'
    | 'semipure' | '\\+' | 'not' | 'when' | '~' | '<=' | '<=>' | '=>' | 'all'
    | 'arbitrary' | 'atomic' | 'disable_warning' | 'disable_warnings'
    | 'promise_equivalent_solutions' | 'promise_equivalent_solution_sets'
    | 'promise_exclusive' | 'promise_exclusive_exhaustive' | 'promise_exhaustive'
    | 'promise_impure' | 'promise_pure' | 'promise_semipure'
    | 'require_complete_switch'
    | 'require_switch_arms_det' | 'require_switch_arms_semidet'
    | 'require_switch_arms_multi' | 'require_switch_arms_nondet'
    | 'require_switch_arms_cc_multi' | 'require_switch_arms_cc_nondet'
    | 'require_switch_arms_erroneous' | 'require_switch_arms_failure'
    | 'require_det' | 'require_semidet' | 'require_multi' | 'require_nondet'
    | 'require_cc_multi' | 'require_cc_nondet' | 'require_erroneous' | 'require_failure'
    | 'trace' | 'try' | 'some' | '&' | '->' | ';' | 'or_else' | 'then' | 'if'
    | 'else' | '::' | '==>' | 'where' | '--->' | 'catch' | 'type' | 'solver'
    | 'catch_any' | 'end_module' | 'import_module' | 'include_module'
    | 'initialise' | 'initialize' | 'finalise' | 'finalize' | 'inst' | 'instance'
    | 'mode' | 'module' | 'pragma' | 'promise' | 'rule' | 'typeclass'
    | 'use_module' | '-->' | ':-' | '?-';

// ============================================================================
//  四、文件与条目
// ============================================================================

//  文件 = 若干表达式条目；每条以 END（`. `）结束。
entry Model:
    items+=Item*;

//  Item 只做包装：一条表达式 + 结束符。真正建对象的是 Expression 子树。
Item infers Item:
    content=Goal<true,false,false> end?=END;

// ============================================================================
//  五、表达式层级
//  按 Mercury 内建运算符表（precedence + specifier）分层，规则命名为 E<prec>；
//  数值越大绑定越紧。目标入口 Goal 为最松一层（310），逐层收紧到 Primary。
//    yfx -> E:  Next ({infer BinaryExpr.left=current} op Next)*   （左递归链）
//    xfy -> E:  Next ({infer BinaryExpr.left=current} op E)?      （右递归）
//    xfx -> E:  Next ({infer BinaryExpr.left=current} op Next)?   （单次，不可链）
//    fx  -> E:  {infer UnaryExpr} op Next   （操作数取下一层，严格更紧）
//    fy  -> E:  {infer UnaryExpr} op E      （操作数取本层，可同级）
//    fxy -> E:  {infer PrefixBinaryExpr} op Next E
//
//  Expression / BinaryExpr / UnaryExpr / PrefixBinaryExpr / Quantifier /
//  IfThenElse / 各字面量接口，全部由 `infers` + `{infer ...}` 动作自动生成，
//  不需要（也不能）再手写 interface 声明。
// ============================================================================

// ---------- 目标入口 ----------
Goal<OrdinaryTerm,Argument,ListElem> infers Expression:
    E300<OrdinaryTerm,Argument,ListElem>;

// ---------- 1490  `.`  yfx（模块限定符）----------
//  ⚠ Fastbelt 原文件写作 `E1490: E1490 (...)? | E1460`，是直接左递归（会无限展开）。
//    Langium 不支持左递归，这里按 yfx 惯例改写成循环形式。
//  ⚠ 另：本规则在原文件里没有任何调用点（限定名走 QualifiedName），属死规则。
E1490<OrdinaryTerm,Argument,ListElem> infers Expression:
    E1460<OrdinaryTerm,Argument,ListElem> ({infer BinaryExpr.left=current} op=DOT right=E1460<OrdinaryTerm,Argument,ListElem>)*;

// ---------- 1460  `!`  `!.`  `!:`  fx ----------
//  ⚠ `!X` 会被 STATE_VAR 抢走（最长匹配），这三条只在 `! ` / `!.` 后非大写时才有机会命中。
E1460<OrdinaryTerm,Argument,ListElem> infers Expression:
      {infer UnaryExpr} op='!'  value=E1410<OrdinaryTerm,Argument,ListElem>
    | {infer UnaryExpr} op='!.' value=E1410<OrdinaryTerm,Argument,ListElem>
    | {infer UnaryExpr} op='!:' value=E1410<OrdinaryTerm,Argument,ListElem>
    | E1410<OrdinaryTerm,Argument,ListElem>;

// ---------- 1410  `@`  xfx ----------
E1410<OrdinaryTerm,Argument,ListElem> infers Expression:
    Primary ({infer BinaryExpr.left=current} op='@' right=Primary)?;

// ---------- 310  `catch_any`  xfy ----------

E310<OrdinaryTerm,Argument,ListElem> infers Expression:
    E319<OrdinaryTerm,Argument,ListElem> ({infer BinaryExpr.left=current} op='catch_any' right=E310<OrdinaryTerm,Argument,ListElem>)?;

// ---------- 300  `-->`  xfx、`:-` (fx/xfx)、`?-` fx ----------
E300<OrdinaryTerm,Argument,ListElem> infers Expression:
      E301<OrdinaryTerm,Argument,ListElem> ({infer BinaryExpr.left=current} op=':-'  right=E301<OrdinaryTerm,Argument,ListElem>)?
    | E301<OrdinaryTerm,Argument,ListElem> ({infer BinaryExpr.left=current} op='-->' right=E301<OrdinaryTerm,Argument,ListElem>)?
    | {infer UnaryExpr} op=':-' value=E301<OrdinaryTerm,Argument,ListElem>
    | {infer UnaryExpr} op='?-' value=E301<OrdinaryTerm,Argument,ListElem>
    | E301<OrdinaryTerm,Argument,ListElem>;

// ---------- 301  模块级别声明（fx）----------
E301<OrdinaryTerm,Argument,ListElem> infers Expression:
      {infer UnaryExpr} op='end_module'     value=E310<OrdinaryTerm,Argument,ListElem>
    | {infer UnaryExpr} op='import_module'  value=E310<OrdinaryTerm,Argument,ListElem>
    | {infer UnaryExpr} op='include_module' value=E310<OrdinaryTerm,Argument,ListElem>
    | {infer UnaryExpr} op='initialise'     value=E310<OrdinaryTerm,Argument,ListElem>
    | {infer UnaryExpr} op='initialize'     value=E310<OrdinaryTerm,Argument,ListElem>
    | {infer UnaryExpr} op='finalise'       value=E310<OrdinaryTerm,Argument,ListElem>
    | {infer UnaryExpr} op='finalize'       value=E310<OrdinaryTerm,Argument,ListElem>
    | {infer UnaryExpr} op='inst'           value=E310<OrdinaryTerm,Argument,ListElem>
    | {infer UnaryExpr} op='instance'       value=E310<OrdinaryTerm,Argument,ListElem>
    | {infer UnaryExpr} op='mode'           value=E310<OrdinaryTerm,Argument,ListElem>
    | {infer UnaryExpr} op='module'         value=E310<OrdinaryTerm,Argument,ListElem>
    | {infer UnaryExpr} op='pragma'         value=E310<OrdinaryTerm,Argument,ListElem>
    | {infer UnaryExpr} op='promise'        value=E310<OrdinaryTerm,Argument,ListElem>
    | {infer UnaryExpr} op='rule'           value=E310<OrdinaryTerm,Argument,ListElem>
    | {infer UnaryExpr} op='typeclass'      value=E310<OrdinaryTerm,Argument,ListElem>
    | {infer UnaryExpr} op='use_module'     value=E310<OrdinaryTerm,Argument,ListElem>
    | E310<OrdinaryTerm,Argument,ListElem>;

// ---------- 319  `solver`  fy ----------
E319<OrdinaryTerm,Argument,ListElem> infers Expression:
      {infer UnaryExpr} op='solver' value=E319<OrdinaryTerm,Argument,ListElem>
    | E320<OrdinaryTerm,Argument,ListElem>;

// ---------- 320  `catch` xfy、`type` fx ----------
E320<OrdinaryTerm,Argument,ListElem> infers Expression:
      E321<OrdinaryTerm,Argument,ListElem> ({infer BinaryExpr.left=current} op='catch' right=E320<OrdinaryTerm,Argument,ListElem>)?
    | {infer UnaryExpr} op='type' value=E321<OrdinaryTerm,Argument,ListElem>;
E321<OrdinaryTerm,Argument,ListElem> infers Expression:
    E325<OrdinaryTerm,Argument,ListElem> ({infer BinaryExpr.left=current} op='--->' right=E321<OrdinaryTerm,Argument,ListElem>)?;

// ---------- 325  `::`  `==>`  `where`  xfx ----------
E325<OrdinaryTerm,Argument,ListElem> infers Expression:
    E330<OrdinaryTerm,Argument,ListElem> ({infer BinaryExpr.left=current} op=OpModeAnnot right=E330<OrdinaryTerm,Argument,ListElem>)?;

// ---------- 330  if / then / else（整体三元构造）----------
//  Mercury 中 if(340,fx) then(350,xfx) else(330,xfy) 只能整体出现，
//  不能拆成独立中缀，这里作为整体捕获；三部分都是完整目标。
E330<OrdinaryTerm,Argument,ListElem> infers Expression:
      {infer IfThenElse} 'if' cond=Goal<OrdinaryTerm,Argument,ListElem> 'then' thenGoal=Goal<OrdinaryTerm,Argument,ListElem> 'else' elseGoal=Goal<OrdinaryTerm,Argument,ListElem>
    | E400<OrdinaryTerm,Argument,ListElem>;

// ---------- 400  `;`  `or_else`  xfy ----------
E400<OrdinaryTerm,Argument,ListElem> infers Expression:
    E450<OrdinaryTerm,Argument,ListElem> ({infer BinaryExpr.left=current} op=OpDisj right=E400<OrdinaryTerm,Argument,ListElem>)?;

// ---------- 450  `->`  xfy（旧式条件）----------
E450<OrdinaryTerm,Argument,ListElem> infers Expression:
    E475<OrdinaryTerm,Argument,ListElem> ({infer BinaryExpr.left=current} op='->' right=E450<OrdinaryTerm,Argument,ListElem>)?;

// ---------- 475  `&`  xfy（并行合取）----------
E475<OrdinaryTerm,Argument,ListElem> infers Expression:
    E500<OrdinaryTerm,Argument,ListElem> ({infer BinaryExpr.left=current} op='&' right=E475<OrdinaryTerm,Argument,ListElem>)?;

// ---------- 500  `,`  xfy（合取）----------
E500<OrdinaryTerm,Argument,ListElem> infers Expression:
    E550<OrdinaryTerm,Argument,ListElem> (<OrdinaryTerm> {infer BinaryExpr.left=current} op=',' right=E500<OrdinaryTerm,Argument,ListElem>)?;

// ---------- 550  前缀层：some/all/try/.../purity/require ----------
E550<OrdinaryTerm,Argument,ListElem> infers Expression:
      {infer Quantifier} kind=QuantKind '[' vars+=VARIABLE (',' vars+=VARIABLE)* ']' goal=E550<OrdinaryTerm,Argument,ListElem>
    | {infer PrefixBinaryExpr} op=OpQuant550 left=E580<OrdinaryTerm,Argument,ListElem> right=E550<OrdinaryTerm,Argument,ListElem>
    | {infer UnaryExpr} op=OpFy550 value=E550<OrdinaryTerm,Argument,ListElem>
    | {infer UnaryExpr} op=OpFx550 value=E580<OrdinaryTerm,Argument,ListElem>
    | E580<OrdinaryTerm,Argument,ListElem>;

// ---------- 580  `<=`  `<=>`  `=>`  xfy ----------
E580<OrdinaryTerm,Argument,ListElem> infers Expression:
    E600<OrdinaryTerm,Argument,ListElem> ({infer BinaryExpr.left=current} op=OpImpl right=E580<OrdinaryTerm,Argument,ListElem>)?;

// ---------- 600  `\+` `not` `~`（fy）、`when`（xfx）----------
E600<OrdinaryTerm,Argument,ListElem> infers Expression:
      E700<OrdinaryTerm,Argument,ListElem> ({infer BinaryExpr.left=current} op='when' right=E700<OrdinaryTerm,Argument,ListElem>)?
    | {infer UnaryExpr} op=OpNegation value=E600<OrdinaryTerm,Argument,ListElem>;

// ---------- 700  func/pred（fx）、impure/semipure（fy）----------
E700<OrdinaryTerm,Argument,ListElem> infers Expression:
      {infer UnaryExpr} op=OpPurityFy value=E700<OrdinaryTerm,Argument,ListElem>
    | {infer UnaryExpr} op=OpPurityFx value=E760<OrdinaryTerm,Argument,ListElem>
    | E760<OrdinaryTerm,Argument,ListElem>;

// ---------- 760  `or`  xfy ----------
E760<OrdinaryTerm,Argument,ListElem> infers Expression:
    E780<OrdinaryTerm,Argument,ListElem> ({infer BinaryExpr.left=current} op='or' right=E760<OrdinaryTerm,Argument,ListElem>)?;

// ---------- 780  `and`  xfy ----------
E780<OrdinaryTerm,Argument,ListElem> infers Expression:
    E799<OrdinaryTerm,Argument,ListElem> ({infer BinaryExpr.left=current} op='and' right=E780<OrdinaryTerm,Argument,ListElem>)?;

// ---------- 799  `is`  xfx ----------
E799<OrdinaryTerm,Argument,ListElem> infers Expression:
    E800<OrdinaryTerm,Argument,ListElem> ({infer BinaryExpr.left=current} op='is' right=E800<OrdinaryTerm,Argument,ListElem>)?;

// ---------- 800  `=` `<` `>` `==` …（xfx，合一 / 比较，不可链）----------
E800<OrdinaryTerm,Argument,ListElem> infers Expression:
    E850<OrdinaryTerm,Argument,ListElem> ({infer BinaryExpr.left=current} op=OpCompare right=E850<OrdinaryTerm,Argument,ListElem>)?;

// ---------- 850  `:=`  `=^`  xfx ----------
E850<OrdinaryTerm,Argument,ListElem> infers Expression:
    E950<OrdinaryTerm,Argument,ListElem> ({infer BinaryExpr.left=current} op=AssignOp right=E950<OrdinaryTerm,Argument,ListElem>)?;

// ---------- 950  `..`  xfx ----------
E950<OrdinaryTerm,Argument,ListElem> infers Expression:
    E1000<OrdinaryTerm,Argument,ListElem> ({infer BinaryExpr.left=current} op='..' right=E1000<OrdinaryTerm,Argument,ListElem>)?;

// ---------- 1000  `+`(fx)、`+ - -- /\ \/`(yfx)、`++`(xfy)、`for`(xfx) ----------
//  `for` 与 `++` 同优先级但结合性不同，拆成子层。
E1000<OrdinaryTerm,Argument,ListElem> infers Expression:
      {infer UnaryExpr} op='+' value=E1100<OrdinaryTerm,Argument,ListElem>
    | E1000Append<OrdinaryTerm,Argument,ListElem>;

E1000Append<OrdinaryTerm,Argument,ListElem> infers Expression:
    E1000Xfy<OrdinaryTerm,Argument,ListElem> ({infer BinaryExpr.left=current} op=AddOp right=E1000Xfy<OrdinaryTerm,Argument,ListElem>)*;

E1000Xfy<OrdinaryTerm,Argument,ListElem> infers Expression:
    E1100<OrdinaryTerm,Argument,ListElem> (
        {infer BinaryExpr.left=current} op='++' right=E1000Xfy<OrdinaryTerm,Argument,ListElem>
      | {infer BinaryExpr.left=current} op='for' right=E1100<OrdinaryTerm,Argument,ListElem>
    )?;

// ---------- 1100  `* / // << <<u >> >>u div`(yfx)、`mod rem`(xfx) ----------
E1100<OrdinaryTerm,Argument,ListElem> infers Expression:
    E1100Mul<OrdinaryTerm,Argument,ListElem> ({infer BinaryExpr.left=current} op=OpMul right=E1100Mul<OrdinaryTerm,Argument,ListElem>)*;

E1100Mul<OrdinaryTerm,Argument,ListElem> infers Expression:
    E1300<OrdinaryTerm,Argument,ListElem> ({infer BinaryExpr.left=current} op=ModOp right=E1300<OrdinaryTerm,Argument,ListElem>)?;

// ---------- 1300  `**`(xfy)、`- \`(fx) ----------
E1300<OrdinaryTerm,Argument,ListElem> infers Expression:
      {infer UnaryExpr} op=UnaryOp value=E1380<OrdinaryTerm,Argument,ListElem>
    | E1380<OrdinaryTerm,Argument,ListElem> ({infer BinaryExpr.left=current} op='**' right=E1300<OrdinaryTerm,Argument,ListElem>)?;

// ---------- 1380  `:` 与 `` `op` ``  yfx ----------
E1380<OrdinaryTerm,Argument,ListElem> infers Expression:
    E1400<OrdinaryTerm,Argument,ListElem> (
        {infer BinaryExpr.left=current} op=':' right=E1400<OrdinaryTerm,Argument,ListElem>
      | {infer BinaryExpr.left=current} userOp=UserOp right=E1400<OrdinaryTerm,Argument,ListElem>
    )*;

// ---------- 1400  `^`  `event`  fx ----------
E1400<OrdinaryTerm,Argument,ListElem> infers Expression:
      {infer UnaryExpr} op=OpCaretFx value=E1401<OrdinaryTerm,Argument,ListElem>
    | E1401<OrdinaryTerm,Argument,ListElem>;

// ---------- 1401  `^`  xfy ----------
E1401<OrdinaryTerm,Argument,ListElem> infers Expression:
    E1410<OrdinaryTerm,Argument,ListElem> ({infer BinaryExpr.left=current} op='^' right=E1401<OrdinaryTerm,Argument,ListElem>)?;

// ============================================================================
//  六、Primary
//  顺序很重要：CompoundDataTerm 必须在 NameRef 之前，
//  否则 `f(X)` 会被 NameRef 一个前瞻截成 `f`，后面 `(X)` 悬空。
// ============================================================================

Primary infers Expression:
      {infer IntegerLiteral} value=INTEGER
    | {infer FloatLiteral}   value=FLOAT
    | {infer StringLiteral}  value=STRING

    | {infer ListLiteral} '[' (elems+=Goal<false,false,true> (',' elems+=Goal<false,false,true>)* ('|' tail=Goal<false,true,false>)?)? ']'
    | {infer CompoundDataTerm} name=NAME OPEN_CT args+=Goal<false,true,false> (',' args+=Goal<false,true,false>)* CLOSE
    | {infer ParenExpr} OPEN value=Goal<true,false,false> CLOSE
    | {infer StateVarRef} value=STATE_VAR
    | {infer NameRef} name=NAME
    | {infer NameRef} OPEN OpToken CLOSE
    | {infer VarRef} name=VARIABLE
    | {infer ImplDefined} value=IMPLEMENTATION_DEFINED;

// ============================================================================
//  七、回译说明（Fastbelt 版 -> Langium 版）
// ============================================================================
//
//  1. interface + returns  ->  infers
//     Fastbelt 必须显式写 `interface T {}` 再 `R returns T:`；Langium 用
//     `R infers T:` 一条搞定，Expression / BinaryExpr / UnaryExpr /
//     PrefixBinaryExpr / Quantifier / IfThenElse / 各字面量接口全部由
//     `infers` + `{infer ...}` 动作推导出来，不要再手写 interface 声明
//     （手写会与自动生成冲突）。
//
//  2. `{Sub.Left=current}` -> `{infer Sub.left=current}`
//     字段名同时改回小写（Langium 惯例），生成的是 camelCase 属性。
//
//  3. 左递归必须改写成循环
//     Langium（Chevrotain）不支持左递归。原文件 `E1490: E1490 (...)? | E1460`
//     在 Fastbelt 里也是错的（会无限展开），这里按 yfx 惯例改成
//     `E1460 ({infer BinaryExpr.left=current} op=DOT right=E1460)*`。
//
//  4. token group -> returns string 规则 / 内联字面量组
//     QuantKind / AddOp / OpCompare / … 都改成了 `X returns string: 'a' | …;`。
//     多字符运算符仍靠词法最长匹配压过短运算符；关键字优先级高于 NAME 等 terminal，
//     所以 `mod`、`try`、`type` 这类不会被引号原子或 NAME 抢走。
//
//  5. composite -> returns string
//     `QualifiedName` / `UserOp` 改为数据类型规则。注意：Langium 数据类型规则的
//     返回值是所消耗 token 图象的拼接，所以 UserOp 的值**包含两侧反引号**
//     （与 Fastbelt 的 composite 行为一致）。若想去掉反引号，改成
//     `'`' op=(QualifiedName | VARIABLE) '`' 并确认生成器的取值方式。
//
//  6. `LParen?=OPEN` / `RParen?=CLOSE` -> 裸写 `OPEN` / `CLOSE`
//     Langium 允许无赋值的终结符/规则调用，`Parens` 混入接口与
//     LParen / RParen / LParen2 / RParen2 字段在 Langium 版里不复存在，
//     括号只作为结构存在。
//
//  7. `comment token` -> `hidden terminal`
//     Langium 没有「文档注释通道」的概念，ML_COMMENT / SL_COMMENT 一律 hidden。
//
//  8. 遗留问题（与 Fastbelt 版一致，非本次回译引入）
//     a) OPEN vs OPEN_CT：WS 声明在前且为 hidden，前导空白先被 WS 吃掉，
//        OPEN 几乎永不匹配，实际都走 OPEN_CT。
//     b) END vs DOT：子句句点正好在文件末尾且没有换行时只出 DOT，
//        而 Item 里 `end?=END` 是必需的 -> 那一条会解析失败。
//        兜底办法：改成 `end?=(END | DOT)`，或把 end 的基数改成可选。
//     c) E1490、E310 没有任何调用点（E300 -> E301 -> E319 -> E320 直接跨过），
//        限定名走 QualifiedName，属死规则，可按需删除。
//     d) E1460 的 `!` / `!.` / `!:` 会被 STATE_VAR 抢走（最长匹配），
//        只有后面不是大写字母时才可能命中。
