local M = {}
M.skill = (arg[0]:match("^(.*)/[^/]+$") or ".") .. "/.."
if M.skill:sub(1, 1) ~= "/" then
  M.skill = (os.getenv("PWD") or ".") .. "/" .. M.skill
end

function M.abort(message)
  error(message, 0)
end

function M.quote(value)
  return "'" .. value:gsub("'", "'\\''") .. "'"
end

function M.succeeds(command)
  local result = os.execute(command)
  return result == true or result == 0
end

function M.run(command)
  if not M.succeeds(command) then
    M.abort("Command failed: " .. command)
  end
end

function M.capture(command)
  local pipe = assert(io.popen(command .. " 2>/dev/null"))
  local output = assert(pipe:read("*a"))
  local result = pipe:close()
  if result ~= true and result ~= 0 then
    M.abort("Command failed: " .. command)
  end
  return (output:gsub("\n$", ""))
end

function M.read(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local content = assert(file:read("*a"), "Cannot read " .. path)
  assert(file:close())
  return content
end

function M.write(path, content)
  local temp = path .. ".tmp-" .. os.time()
  while M.read(temp) do
    temp = temp .. "-1"
  end
  local file = assert(io.open(temp, "w"))
  assert(file:write(content))
  assert(file:close())
  local ok, message = os.rename(temp, path)
  if not ok then
    os.remove(temp)
    M.abort(message)
  end
end

local function fill(template, fields)
  local function value(key)
    if fields[key] == nil then
      M.abort("Missing template value: " .. key)
    end
    return tostring(fields[key])
  end
  return template:gsub("{{%s*([%w_]+)%s*}}", value)
end

local function source(name)
  return assert(
    M.read(M.skill .. "/templates/" .. name .. ".md.hbs"),
    "Missing template: " .. name
  )
end

function M.render_block(name, key, item)
  local body = source(name):match("{{#each " .. key .. "}}(.-){{/each}}")
  if not body then
    M.abort("Missing template block: " .. key)
  end
  return fill(body, item)
end

function M.render(name, fields)
  local template = source(name)
  local function expand(key, body)
    local parts = {}
    for _, item in ipairs(fields[key] or {}) do
      parts[#parts + 1] = fill(body, item)
    end
    return table.concat(parts)
  end
  template = template:gsub("{{#each%s+([%w_]+)}}(.-){{/each}}", expand)
  template = fill(template, fields)
  if template:find("{{", 1, true) then
    M.abort("Unrendered template marker in " .. name)
  end
  return template
end

function M.day_epoch(date)
  local year, month, day = date:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  if not year then
    M.abort("Invalid journal date: " .. date)
  end
  local epoch = os.time({
    year = assert(tonumber(year)),
    month = assert(tonumber(month)),
    day = assert(tonumber(day)),
    hour = 12,
  })
  if os.date("%Y-%m-%d", epoch) ~= date then
    M.abort("Invalid journal date: " .. date)
  end
  return epoch
end

function M.iso(epoch)
  return os.date("%Y-%m-%d", epoch)
end

function M.week(epoch)
  return os.date("%G-W%V", epoch)
end

function M.previous_month(epoch)
  local date = os.date("*t", epoch)
  return os.date(
    "%Y-%m",
    os.time({
      year = date.year,
      month = date.month,
      day = 0,
      hour = 12,
    })
  )
end

function M.date_label(date)
  local patterns = {
    ["yyyy-MM-dd"] = "%Y-%m-%d",
    ["dd/MM/yyyy"] = "%d/%m/%Y",
    ["MM/dd/yyyy"] = "%m/%d/%Y",
    ["dd-MM-yyyy"] = "%d-%m-%Y",
    ["dd/MM/yy"] = "%d/%m/%y",
    ["d MMM yyyy"] = "%d %b %Y",
    ["MMMM d, yyyy"] = "%B %d, %Y",
    ["dd MMMM yyyy"] = "%d %B %Y",
    ["EEE, dd MMM yyyy"] = "%a, %d %b %Y",
  }
  local pattern = patterns[M.date_format]
  if not pattern then
    M.abort("Unsupported date format: " .. M.date_format)
  end
  local label = os.date(pattern, M.day_epoch(date))
  if type(label) == "string" then
    if M.date_format == "d MMM yyyy" then
      return (label:gsub("^0", ""))
    end
    if M.date_format == "MMMM d, yyyy" then
      return (label:gsub(" 0", " "))
    end
    return label
  end
  M.abort("Cannot format journal date: " .. date)
end

local home = os.getenv("HOME")
if not home then
  M.abort("HOME is required to locate the installed vault.")
end
M.vault = M.read(home .. "/.obsidian-journal-vault")
if not M.vault then
  M.abort("Run scripts/install.lua before using the journal.")
end
M.vault = M.vault:gsub("%s+$", "")
if M.vault:sub(1, 1) ~= "/" then
  M.abort("The installed vault path is not absolute.")
end
M.config = M.vault .. (M.vault == "/" and "" or "/") .. ".journal.config.toml"
local schema_url = "file://" .. (M.skill .. "/schemas/config.json"):gsub(
  "([^%w%-%._~/])",
  function(char)
    return string.format("%%%02X", char:byte())
  end
)
M.run(
  "taplo lint --no-auto-config --schema " .. M.quote(
    schema_url
  ) .. " - < " .. M.quote(M.config) .. " >/dev/null 2>&1"
)
local function setting(key)
  return M.capture(
    "taplo get " .. M.quote(key) .. " --file-path " .. M.quote(
      M.config
    ) .. " -s"
  )
end
if setting("core.path") ~= M.vault then
  M.abort("The installed vault and core.path differ.")
end
M.date_format = setting("configuration.date_format")
M.time_format = setting("configuration.time_format")
M.glados_enabled =
  M.succeeds(
    "taplo get glados.enable --file-path " .. M.quote(
      M.config
    ) .. " -s >/dev/null 2>&1"
  ) and setting("glados.enable") == "true"
M.allowed_agents = {}
for agent in setting("configuration.agents"):gmatch("[^\n]+") do
  M.allowed_agents[agent] = true
end
M.today = os.date("%Y-%m-%d")
M.today_epoch = M.day_epoch(M.today)
M.current = M.vault .. "/journal-current.md"
M.journal = M.vault

function M.speak(event, message)
  if not M.glados_enabled then
    return true
  end
  local command =
    "uv run --project " .. M.quote(M.skill) .. " python " .. M.quote(
      M.skill .. "/scripts/glados.py"
    ) .. " speak " .. M.quote(event) .. " --message " .. M.quote(message)
  if M.succeeds(command .. " >/dev/null 2>&1") then
    return true
  end
  io.stderr:write(
    "GLaDOS TTS failed; the journal operation was not rolled back.\n"
  )
  return false
end

function M.refresh_glados()
  if M.glados_enabled then
    M.run(
      "uv run --project " .. M.quote(M.skill) .. " python " .. M.quote(
        M.skill .. "/scripts/glados.py"
      ) .. " refresh"
    )
  end
end

function M.activity(files, paths)
  for _, path in ipairs(paths) do
    local content = files[path] or ""
    local summary = content:match("## Summary[^\n]*\n%s*(.-)\n\n## ")
    local work = content:match("%*%*Work:%*%*%s*(.-)\n\n%*%*CWD:%*%*")
    local text = summary or work
    if text then
      text = text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
      if text ~= "" then
        return text:sub(1, 150)
      end
    end
  end
  return "The journal files were updated."
end

function M.day_fields(date)
  local epoch = M.day_epoch(date)
  local yesterday = M.iso(epoch - 86400)
  return {
    date = date,
    date_label = M.date_label(date),
    month = date:sub(1, 7),
    year = date:sub(1, 4),
    previous_day = yesterday,
    journal_base = "weekly/" .. M.week(M.day_epoch(yesterday)),
    previous_week = M.week(epoch - 7 * 86400),
    previous_month = M.previous_month(epoch),
    enable_edit = "true",
    summary = "",
    tags = {},
    entry = {},
    entries = {},
  }
end

function M.archived_days()
  local days = {}
  local pipe =
    assert(
      io.popen(
        "find " .. M.quote(M.journal) .. " -type f -name '????-??-??.md' -print"
      )
    )
  for path in pipe:lines() do
    local date = path:match("/(%d%d%d%d%-%d%d%-%d%d)%.md$")
    if date and path == M.journal .. "/weekly/" .. M.week(
      M.day_epoch(date)
    ) .. "/" .. date .. ".md" then
      days[#days + 1] = date
    end
  end
  pipe:close()
  table.sort(days)
  return days
end

function M.update_blocks(path, heading, template, fields, key, items)
  local existing = M.read(path)
  if not existing then
    fields[key] = items
    M.write(path, M.render(template, fields))
    print("created: " .. path)
    return
  end
  existing = assert(existing)
  if not existing:find("## " .. heading, 1, true) then
    M.abort("Missing section in " .. path)
  end
  local additions = {}
  for _, item in ipairs(items) do
    if not existing:find(item.marker, 1, true) then
      additions[#additions + 1] = M.render_block(template, key, item)
    end
  end
  if #additions > 0 then
    local updated =
      existing:gsub("updated_at:%s*[^\n]+", "updated_at: " .. M.today, 1)
    local trimmed = assert(updated):gsub("%s*$", "")
    M.write(path, trimmed .. "\n\n" .. table.concat(additions) .. "\n")
    print("updated: " .. path)
  end
end

function M.git_root()
  if M.capture(
    "git -C " .. M.quote(M.vault) .. " rev-parse --show-toplevel"
  ) ~= M.capture("cd " .. M.quote(M.vault) .. " && pwd -P") then
    M.abort("Vault must be the root of its Git repository.")
  end
end

function M.execute(action)
  local lock = M.vault .. "/.journal.lock"
  if not M.succeeds("mkdir " .. M.quote(lock) .. " 2>/dev/null") then
    M.speak(
      "failure",
      "Journal task could not start because another task holds the journal lock. Wait for it to finish, then retry."
    )
    M.abort("Journal is locked: " .. lock)
  end
  local ok, message = pcall(action)
  M.run("rmdir " .. M.quote(lock))
  if not ok then
    io.stderr:write(tostring(message) .. "\n")
    M.speak(
      "failure",
      "Journal task failed: " .. tostring(
        message
      ) .. ". Read the error above, correct that step, then retry."
    )
    os.exit(1)
  end
end

return M
