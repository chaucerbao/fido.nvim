local buffers = require('shelly.buffers')
local utils = require('shelly.utils')

--- @param scope scope
--- @param fence fence
local function evaluate(scope, fence)
  local connection_uri = ''
  local args = {}

  -- Parse Scope
  for _, line in ipairs(scope.lines) do
    local uri = line:match(utils.uri_line_pattern)
    local arg = line:match(utils.arg_line_pattern)

    if uri then
      connection_uri = uri
    elseif arg then
      vim.list_extend(args, vim.split(arg, ' '))
    end
  end

  -- Parse Fence
  local body = {}
  for _, line in ipairs(fence.lines) do
    if #body == 0 then
      local uri = line:match(utils.uri_line_pattern)
      local arg = line:match(utils.arg_line_pattern)

      if uri then
        connection_uri = uri
      elseif arg then
        vim.list_extend(args, vim.split(arg, ' '))
      elseif #vim.trim(line) > 0 then
        table.insert(body, line)
      end
    else
      table.insert(body, line)
    end
  end

  local cmd = nil
  if connection_uri:find('^postgres') then
    cmd = { 'psql' }
    table.insert(args, '--dbname=' .. connection_uri)
  elseif connection_uri:find('^sqlite') then
    cmd = { 'sqlite3' }
    table.insert(args, 'file:' .. connection_uri:match('://(.*%S)$'))
  end

  vim.list_extend(cmd, args)

  vim.system(cmd, { stdin = body, text = true, timeout = 5 * 1000 }, function(job)
    vim.schedule(function()
      local scratch_winid = buffers.render_scratch_buffer(
        vim.split((job.code == 0) and job.stdout or job.stderr, '\n'),
        { name = 'SQL', filetype = 'text', size = 40 }
      )

      if vim.fn.win_getid() == scratch_winid then
        vim.cmd.wincmd('p')
      end
    end)
  end)
end

return {
  evaluate = evaluate,
}