local root = (arg[0]:match("^(.*)/[^/]+$") or ".") .. "/.."
if root:sub(1, 1) ~= "/" then
  root = (os.getenv("PWD") or ".") .. "/" .. root
end
local config_template = root .. "/templates/config.toml.hbs"
local schema = root .. "/schemas/config.json"

local function fail(message)
  io.stderr:write(message .. "\n")
  os.exit(1)
end

local function shell_quote(value)
  return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function succeeds(command)
  local result = os.execute(command)
  return result == true or result == 0
end

local function exists(path)
  return succeeds("test -e " .. shell_quote(path))
end

local function ask(label, default)
  while true do
    io.write(label .. (default and " [" .. default .. "]" or "") .. ": ")
    io.flush()
    local answer = io.read("*l")
    if not answer then
      fail("Input ended before configuration was complete.")
    end
    answer = answer:match("^%s*(.-)%s*$")
    if answer == "" then
      answer = default or ""
    end
    if not answer:find("[%c]") then
      return answer
    end
    io.stderr:write("Control characters are not allowed.\n")
  end
end

local function toml_string(value)
  return '"' .. value:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

local function read_file(path)
  local file = assert(io.open(path, "r"), "Cannot read " .. path)
  local content = assert(file:read("*a"), "Cannot read " .. path)
  assert(file:close())
  return content
end

local function save_base(vault)
  local home = os.getenv("HOME")
  if not home then
    fail("HOME is required to remember the vault path.")
  end
  local pointer = home .. "/.obsidian-journal-vault"
  local temp = pointer .. ".tmp-" .. os.time()
  local file = assert(io.open(temp, "w"), "Cannot write " .. temp)
  assert(file:write(vault, "\n"))
  assert(file:close())
  local ok, error_message = os.rename(temp, pointer)
  if not ok then
    os.remove(temp)
    fail(error_message)
  end
end

if not succeeds("command -v taplo >/dev/null 2>&1") then
  fail(
    "Taplo is required to validate .journal.config.toml against schemas/config.json."
  )
end

local vault
repeat
  vault = ask("Existing absolute vault path")
  if vault == "/" or (vault:sub(1, 1) == "/" and succeeds(
    "test -d " .. shell_quote(vault)
  )) then
    vault = vault:gsub("/+$", "")
    if vault == "" then
      vault = "/"
    end
    break
  end
  io.stderr:write("Enter an existing absolute directory.\n")
until false

local config = vault .. (vault == "/" and "" or "/") .. ".journal.config.toml"
local schema_url = "file://" .. schema:gsub("([^%w%-%._~/])", function(char)
  return string.format("%%%02X", char:byte())
end)
local function valid(path)
  return succeeds(
    "taplo lint --no-auto-config --schema " .. shell_quote(
      schema_url
    ) .. " - < " .. shell_quote(path) .. " >/dev/null 2>&1"
  )
end

local had_config = exists(config)
if had_config and not succeeds("test -f " .. shell_quote(config)) then
  fail("Configuration path is not a regular file: " .. config)
end
if had_config and valid(config) then
  local pipe =
    io.popen(
      "taplo get core.path --file-path " .. shell_quote(
        config
      ) .. " -s 2>/dev/null"
    )
  local configured_path = pipe and pipe:read("*a") or ""
  if pipe then
    pipe:close()
  end
  if configured_path == vault then
    if not succeeds(
      "taplo get glados.enable --file-path " .. shell_quote(
        config
      ) .. " -s >/dev/null 2>&1"
    ) then
      if succeeds(
        "taplo get glados.command --file-path " .. shell_quote(
          config
        ) .. " -s >/dev/null 2>&1"
      ) then
        fail(
          "Add glados.enable to the existing [glados] section before reinstalling."
        )
      end
      local enabled
      repeat
        enabled = ask("Enable GLaDOS TTS? (y/n)", "n")
      until enabled == "y" or enabled == "n"
      local temp = config .. ".tmp-" .. os.time()
      while exists(temp) do
        temp = temp .. "-1"
      end
      local file = assert(io.open(temp, "w"), "Cannot write " .. temp)
      assert(
        file:write(
          read_file(config):gsub("%s*$", ""),
          "\n\n[glados]\nenable = ",
          enabled == "y" and "true" or "false",
          '\ncommand = "glados-say"\n'
        )
      )
      assert(file:close())
      if not valid(temp) then
        os.remove(temp)
        fail(
          "Migrated configuration failed schema validation; existing config was kept."
        )
      end
      local ok, error_message = os.rename(temp, config)
      if not ok then
        os.remove(temp)
        fail(error_message)
      end
    end
    save_base(vault)
    print("Configuration is already valid: " .. config)
    os.exit(0)
  end
end
if had_config then
  io.stderr:write(
    "Configuration is invalid or points to another vault; it will be backed up.\n"
  )
end

local name = ask("Vault name", vault:match("([^/]+)$") or "vault")
local dates =
  {
    "yyyy-MM-dd",
    "dd/MM/yyyy",
    "MM/dd/yyyy",
    "dd-MM-yyyy",
    "dd/MM/yy",
    "d MMM yyyy",
    "MMMM d, yyyy",
    "dd MMMM yyyy",
    "EEE, dd MMM yyyy",
  }
local times = { "HH:mm", "HH:mm:ss", "hh:mm a", "hh:mm:ss a", "H:m", "h:m a" }
local function choice(label, options)
  while true do
    local answer = ask(label, options[1])
    for _, option in ipairs(options) do
      if answer == option then
        return answer
      end
    end
    io.stderr:write("Allowed values: " .. table.concat(options, ", ") .. "\n")
  end
end
local date_format = choice("Date format", dates)
local time_format = choice("Time format", times)
local enabled_glados
repeat
  enabled_glados = ask("Enable GLaDOS TTS? (y/n)", "n")
until enabled_glados == "y" or enabled_glados == "n"

local agents = {}
repeat
  local answer =
    ask(
      "Agent name" .. (#agents > 0 and " (blank to finish)" or ""),
      #agents == 0 and "Codex" or nil
    )
  if answer == "" then
    break
  end
  local duplicate = false
  for _, agent in ipairs(agents) do
    if agent == answer then
      duplicate = true
    end
  end
  if duplicate then
    io.stderr:write("Agent already added.\n")
  else
    agents[#agents + 1] = answer
  end
until false

local dirs = {}
while true do
  local path = ask("Authorized directory (blank to finish)")
  if path == "" then
    break
  end
  if path:sub(1, 1) ~= "/" then
    io.stderr:write("Enter an absolute path.\n")
  else
    local permissions
    repeat
      permissions = ask("Permissions for " .. path, "0755")
    until permissions:match("^0?[0-7][0-7][0-7]$")
    local enabled
    repeat
      enabled = ask("Enable " .. path .. "? (y/n)", "y")
    until enabled == "y" or enabled == "n"
    dirs[#dirs + 1] = {
      path = path,
      permissions = permissions,
      enable = enabled == "y",
    }
  end
end

local rendered = read_file(config_template)
rendered =
  rendered:gsub(
    "{{#unless authorized_dirs}}.-{{/unless}}",
    #dirs == 0 and "authorized_dirs = []" or ""
  )
rendered = rendered:gsub("{{#each configuration.agents}}.-{{/each}}", function()
  local lines = {}
  for index, agent in ipairs(agents) do
    lines[#lines + 1] =
      "  " .. toml_string(agent) .. (index < #agents and "," or "")
  end
  return table.concat(lines, "\n")
end)
rendered = rendered:gsub("{{#each authorized_dirs}}.-{{/each}}", function()
  local blocks = {}
  for _, dir in ipairs(dirs) do
    blocks[#blocks + 1] =
      "[[authorized_dirs]]\nenable = " .. tostring(
        dir.enable
      ) .. "\npath = " .. toml_string(
        dir.path
      ) .. "\npermissions = " .. toml_string(dir.permissions)
  end
  return table.concat(blocks, "\n\n")
end)
for key, value in
  pairs({
    ["core.name"] = name,
    ["core.path"] = vault,
    ["configuration.date_format"] = date_format,
    ["configuration.time_format"] = time_format,
  })
do
  rendered = rendered:gsub("{{" .. key:gsub("%.", "%%.") .. "}}", function()
    return toml_string(value):sub(2, -2)
  end)
end
rendered = rendered:gsub("{{glados.enable}}", tostring(enabled_glados == "y"))

local temp = config .. ".tmp-" .. os.time()
while exists(temp) do
  temp = temp .. "-1"
end
local file = assert(io.open(temp, "w"), "Cannot write " .. temp)
assert(file:write(rendered))
assert(file:close())
if not valid(temp) then
  os.remove(temp)
  fail(
    "Generated configuration failed schema validation; existing config was kept."
  )
end

local backup
if had_config then
  backup = config .. ".invalid-" .. os.date("%Y%m%d%H%M%S")
  while exists(backup) do
    backup = backup .. "-1"
  end
  local ok, error_message = os.rename(config, backup)
  if not ok then
    os.remove(temp)
    fail(error_message)
  end
end
local ok, error_message = os.rename(temp, config)
if not ok then
  if backup then
    os.rename(backup, config)
  end
  os.remove(temp)
  fail(error_message)
end
save_base(vault)
print("Configuration written: " .. config)
if backup then
  print("Previous configuration saved: " .. backup)
end
