local expr  = require 'expressiontree'
local lexer = require 'ti.lexer'

---@class matrix # Matrix helper class
---@field data any[][]
local matrix = { mt = {} }
matrix.mt.__index = matrix.mt

function matrix.new()
   return setmetatable({data = {}}, matrix.mt)
end

function matrix.mt:from_expr(e)
   self.data = {}
   if e:isa(expr.MATRIX) then
      for m, row in ipairs(e.children or {}) do
         if row:isa(expr.MATRIX) then
            for n, col in ipairs(row.children or {}) do
               self:set(m, n, col:infix_string())
            end
         else
            -- [x,y,z] -> [[x,y,z]]
            self:set(1, m, row:infix_string())
         end
      end
   end
   return self
end

function matrix.mt:to_expr()
   local m, n = self:size()

   local rows = {}
   for i = 1, m do
      local cols = {}
      for j = 1, n do
         local tokens = lexer.tokenize(self.data[i][j])
         table.insert(cols, expr.from_infix(tokens))
      end
      table.insert(rows, expr.node('[', expr.MATRIX, cols))
   end

   return expr.node('[', expr.MATRIX, rows)
end

function matrix.mt:from_list(e, cols)
   cols = cols or 1
   self.data = {}
   if e:isa(expr.LIST) then
      for i, item in ipairs(e.children or {}) do
         print(string.format('Setting %d %d', math.floor(i / cols), i % cols + 1))
         self:set(math.floor(i / cols), i % cols + 1, item:infix_string())
      end
   end
   return self
end

function matrix.mt:to_list()
   local items = {}

   local m, n = self:size()
   for i = 1, m do
      for j = 1, n do
         local tokens = lexer.tokenize(self.data[i][j])
         table.insert(items, expr.from_infix(tokens))
      end
   end

   return expr.node('{', expr.LIST, items)
end

-- Transpose matrix
function matrix.mt:transpose()
   local rows, cols = self:size()

   local new_data = {}
   for n = 1, cols do
      table.insert(new_data, {})
      for m = 1, rows do
         table.insert(new_data[n], self.data[m][n] or '0')
      end
   end
   self.data = new_data
end

-- Determine matrix size
---@return number Rows
---@return number Columns
function matrix.mt:size()
   local rows, cols = 0, 0
   for row_idx, row in ipairs(self.data) do
      for col_idx, col in ipairs(row) do
         if col then
            cols = math.max(cols, col_idx)
            rows = math.max(rows, row_idx)
         end
      end
   end

   return rows, cols
end

-- Resize matrix to m, n, fill up with %zero
---@param m number # Row count
---@param n number # Column count
---@param zero any # Zero value
function matrix.mt:resize(m, n, zero)
   self:set(m, n, nil, zero)
   for i = 1, #self.data, 1 do
      if i > m then
         self.data[i] = nil
      else
         for j = n + 1, #self.data[i] do
            self.data[i][j] = nil
         end
      end
   end
   return self
end

function matrix.mt:clear()
   for _, row in ipairs(self.data) do
      for i = 1, #row do
         row[i] = nil
      end
   end
end

function matrix.mt:set(m, n, value, fill)
   local cm, cn = self:size()

   local data = self.data
   if m > cm or n > cn then
      for row_idx = 1, math.max(m, cm) do
         if not data[row_idx] then
            data[row_idx] = {}
         end

         for col_idx = 1, math.max(n, cn) do
            if not data[row_idx][col_idx] then
               data[row_idx][col_idx] = fill
            end
         end
      end
   end

   data[m][n] = value or data[m][n] or fill
end

-- Return cell at m, n
---@return any
function matrix.mt:get(m, n)
   local data = self.data
   return data[m] and data[m][n]
end

return matrix
