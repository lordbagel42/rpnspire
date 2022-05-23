-- luacheck: ignore class
function class(base)
  local classdef = {}

  setmetatable(classdef, {
    __index = base,
    __call = function(_, ...)
      local inst = {
        class = classdef,
        super = base or nil
      }
      setmetatable(inst, {__index = classdef})
      if inst.init then
        inst:init(...)
      end
      return inst
    end})

  return classdef
end

function string.usub(...)
  return string.sub(...)
end

function math.log10(x)
  return math.log(x, 10)
end

local GC = {
  getStringWidth = function() return 1 end,
  getStringHeight = function() return 1 end,
  drawRect = function() end,
  fillRect = function() end,
  setColorRGB = function() end,
}

-- luacheck: ignore platform
platform = {
  withGC = function(fn) return fn(GC) end,
  window = {
    width = function() return 1 end,
    height = function() return 1 end,
    invalidate = function() end,
  }
}

math.evalStr = function(str)
  return str
end

if not unpack then
  _G.unpack = table.unpack
end

-- luacheck: ignore on
on = {}

-- luacheck: ignore Infix RPNExpression
require 'rpn'
local Test = require 'testlib'

local test = {}

function test.tokenize_infix()
  local function fail(str, reason)
    local res = Infix.tokenize(str)
    Test.assert((not res), reason)
  end

  local function expect(str, tokens)
    local res = Infix.tokenize(str)

    Test.assert(#res == #tokens, "Token count missmatch "..str)
    for i=1, #tokens do
      Test.assert(res[i][1] == tokens[i][1],
                  "Token value missmatch. Expected '"..tokens[i][1].."' got '"..res[i][1].."'")
      Test.assert(res[i][2]:sub(1, #tokens[i][2]) == tokens[i][2],
                  "Token type missmatch. Expected '"..tokens[i][1].."' got '"..res[i][1].."' ("..str..")")
    end
  end

  expect("",     {})
  expect("    ", {})

  -- Number
  expect("1",   {{'1',   'n'}})
  expect("1.",  {{'1.',  'n'}})
  expect(".1",  {{'.1',  'n'}})
  expect("1.1", {{'1.1', 'n'}})
  expect("123", {{'123', 'n'}})
  fail("1.1.",  'Number followed by point')
  fail(".",     'Point is not a valid number')

  -- Number exponents
  expect("3"..Sym.EE.."5",             {{'3'..Sym.EE..'5',  'n'}})
  expect("3"..Sym.EE.."+5",            {{'3'..Sym.EE..'+5', 'n'}})
  expect("3"..Sym.EE.."-5",            {{'3'..Sym.EE..'-5', 'n'}})
  expect("3"..Sym.EE..Sym.NEGATE.."5", {{'3'..Sym.EE..Sym.NEGATE..'5', 'n'}})
  fail("3"..Sym.EE.."5.1",             'Point after exponent')

  -- Number bases
  expect("0b10", {{'0b10', 'n'}})
  expect("0hf0", {{'0hf0', 'n'}})
  expect("0hfx", {{'0hf', 'n'}, {'*', 'o'}, {'x', 'w'}}) -- As allowed by TI
  fail("0b12",   'Non binary digit in binary number')

  -- Operators
  expect("+",        {{'+', 'o'}})
  expect("-",        {{'-', 'o'}})
  expect("*",        {{'*', 'o'}})
  expect("/",        {{'/', 'o'}})
  expect(Sym.NEGATE, {{Sym.NEGATE, 'o'}})

  -- Units
  expect("_m", {{'_m', 'u'}})

  -- String
  expect('"hello"', {{'"hello"', 'str'}})

  -- List
  expect('{1,2}', {{'{', 'sy'}, {'1', 'n'}, {',', 'sy'}, {'2', 'n'}, {'}', 'sy'}})

  -- Matrix
  expect('[1,2]', {{'[', 'sy'}, {'1', 'n'}, {',', 'sy'}, {'2', 'n'}, {']', 'sy'}})

  -- Implicit multiplication
  expect("2x",   {{'2', 'n'}, {'*', 'o'}, {'x', 'w'}})
  expect("2(1)", {{'2', 'n'}, {'*', 'o'}, {'(', 'sy'}, {'1', 'n'}, {')', 'sy'}})
  expect("(1)2", {{'(', 'sy'}, {'1', 'n'}, {')', 'sy'}, {'*', 'o'}, {'2', 'n'}})
  expect("f(1)", {{'f', 'f'}, {'(', 'sy'}, {'1', 'n'}, {')', 'sy'}})

  -- Expressions
  expect("solve(0.5((x + 3)^2 - 10.53)=0, {x,y})", {
           {'solve', 'f'},
           {'(',     'sy'},
           {'0.5',   'n'},
           {'*',     'o'},
           {'(',     'sy'},
           {'(',     'sy'},
           {'x',     'w'},
           {'+',     'o'},
           {'3',     'n'},
           {')',     'sy'},
           {'^',     'o'},
           {'2',     'n'},
           {'-',     'o'},
           {'10.53', 'n'},
           {')',     'sy'},
           {'=',     'o'},
           {'0',     'n'},
           {',',     'sy'},
           {'{',     'sy'},
           {'x',     'w'},
           {',',     'sy'},
           {'y',     'w'},
           {'}',     'sy'},
           {')',     'sy'},
  })
end

function test.infix_to_rpn_to_infix()
  local function expect(str, other)
    other = other or str

    local rpn = RPNExpression()
    rpn:fromInfix(Infix.tokenize(str))
    local new = rpn:infixString()
    if not Test.assert(new == other, "Expected "..other.." got "..(new or "nil")) then
      print("RPN Stack:")
      for idx,v in ipairs(rpn.stack) do
        print(string.format('%0.2d| %10s (%s)', idx, v[1], v[2]))
      end
    end
  end

  expect("1+2")
  expect("1+2+3")
  expect("1+2+3+4")
  expect("1+2+3+4+5")

  -- Operator associativity
  expect("(1-2)-3", "1-2-3")
  expect("1-(2-3)")
  expect("((1-2)-3)-4", "1-2-3-4")
  expect("(2^3)^4")
  expect("2^3^4", "2^(3^4)")
  expect("2^(3^4)")
  expect("x^(y-1)=0")
  expect("solve(x^(y-1)=0,x)") -- bug#16
  expect("solve((((x*2)))=(((1))),((((((x)))))))", "solve(x*2=1,x)")

  -- Left assoc
  for _,v in ipairs({'-', '/'}) do
    expect("x"..v.."x"..v.."x")
    expect("(x"..v.."x)"..v.."x", "x"..v.."x"..v.."x")
    expect("x"..v.."(x"..v.."x)")
  end

  expect("1/1/1")
  expect("1/(1/1)")
  expect("1*1*1")
  expect("1*1/1*1")
  expect("1*1/(1*1)")

  -- Implicit multiplication
  expect("1(3)", "1*3")
  expect("(3)1", "3*1")
  expect("5_m", "5*_m")
  expect("5{1}", "5*{1}")
  expect("{1}5", "{1}*5")

  -- Preserve function calls
  expect("sin(pi)")
  expect("root(x)", "root(x)")
  expect("root(x,y)", "root(x,y)")

  -- Lists
  expect("{}")
  expect("{1}")
  expect("{1,2}")
  expect("{1,2,3}")
  expect("{(1+a)*2,2+b,3+c}")
  expect("{(1+a)*2,2+b,root((1+x)*2,2*y)}")

  -- Matrix (NOT YET IMPLEMENTED)
  --expect("[1]", "[[1]]")
  --expect("[[1,2,3],[4,5,6]]")

  -- Remove parens
  expect("(2^2)", "2^2")
  expect("(((2^2)))", "2^2")
end

function test.rpn_to_infix()
  local function expect(stack, str)
    local rpn = RPNExpression()
    for _,v in ipairs(stack) do
      if type(v) == 'number' then v = tostring(v) end
      rpn:push(v)
    end

    local new = rpn:infixString()
    Test.assert(new == str, "Expected "..(str or "nil").." got "..(new or "nil"))
  end

  -- Operators
  expect({1}, "1")
  expect({1, 2, '+'}, "1+2")
  expect({1, 2, 3, '+', '+'}, "1+2+3")
  expect({1, 2, 3, 4, '+', '+', '+'}, "1+2+3+4")
  expect({1, 2, '-'}, "1-2")
  expect({1, 2, 3, '-', '-'}, "1-(2-3)")
  expect({1, 2, 3, 4, '-', '-', '-'}, "1-(2-(3-4))")
  expect({1, 2, '^'}, "1^2")
  expect({1, 2, 3, '^', '^'}, "1^(2^3)")
  expect({1, 2, '^', 3, '^'}, "(1^2)^3")

  -- Functions
  expect({1, 1, {'sin', 'function'}}, "sin(1)")
  expect({1, 2, '+', 1, {'sin', 'function'}}, "sin(1+2)")
  expect({2, 'x', '*', 10, '=', 'x', 2, {'solve', 'function'}}, "solve(2*x=10,x)")
end

function test.keybind_manager()
  local last = nil
  local kbd = KeybindManager()

  local function expect(seq, n)
    kbd:resetSequence()
    last = nil
    for _,v in ipairs(seq) do
      kbd:dispatchKey(v)
    end
    Test.assert(last == n, "Expected action "..(n or "nil").." got "..(last or "nil"))
  end

  kbd:setSequence({'a', 'b', '1'}, function() last = '1' end)
  kbd:setSequence({'a', 'b', '2'}, function() last = '2' end)
  kbd:setSequence({'a', 'c', '3'}, function() last = '3' end)
  kbd:setSequence({'b'}, function() last = '4' end)

  expect({}, nil)
  expect({'c'}, nil)
  expect({'b'}, '4')
  expect({'a', 'b', '2'}, '2')
end

function test.rpn_input()
  UIStack.draw = function(...) end
  UIInput.draw = function(...) end

  local text = ''
  local rpn = RPNInput()
  rpn.input = {}
  rpn.setInput = function(self, str)
    text = str
  end
  rpn.getInput = function(self)
    return text
  end
  rpn.isBalanced = function(self)
    return true
  end

  local function expectStack(input_str, key, stack_infix)
    stack.stack = {}
    text = ''
    for _,v in ipairs(key) do
      if v == 'ENTER' then
        rpn:onEnter()
      else
        if not rpn:onCharIn(v) then
          text = text..v
        end
      end
    end

    if type(stack_infix) == 'string' then
      local stack_top = stack.stack[#stack.stack]
      Test.assert(stack_top.infix == stack_infix,
                  "Expected stack top to be '"..stack_infix.."' but it is '"..stack_top.infix.."'")
    else
      for idx,v in ipairs(stack_infix) do
        local stack_top = stack.stack[#stack.stack - idx + 1]
        Test.assert(stack_top.infix == v,
                    "Expected stack top to be '"..v.."' but it is '"..stack_top.infix.."'")
      end
    end
  end

  expectStack('', {'1', 'ENTER'}, '1')
  expectStack('', {'1', 'ENTER', '2', 'ENTER'}, {'2', '1'})
  expectStack('', {'1', '2', 'ENTER'}, '12')

  -- Operators
  expectStack('', {'1', 'ENTER', '2', 'ENTER', '+'}, '1+2')
  expectStack('', {'1', 'ENTER', '2', '+'}, '1+2')

  -- Functions
  expectStack('', {'1', 'ENTER', 'sin', 'ENTER'}, 'sin(1)')
  expectStack('', {'1', 'ENTER', '2', '+', 'sin', 'ENTER'}, 'sin(1+2)')
  expectStack('', {'sin(2)', 'ENTER'}, 'sin(2)')
end

Test.run(test)
