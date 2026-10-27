local skill = (arg[0]:match("^(.*)/[^/]+$") or ".") .. "/.."
if skill:sub(1, 1) ~= "/" then
  skill = (os.getenv("PWD") or ".") .. "/" .. skill
end

local function quote(value)
  return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function run(command)
  local result = os.execute(command)
  assert(result == true or result == 0, command)
end

local function write(path, content)
  local file = assert(io.open(path, "w"))
  assert(file:write(content))
  assert(file:close())
end

local function read(path)
  local file = assert(io.open(path, "r"))
  local content = assert(file:read("*a"))
  assert(file:close())
  return content
end

local temp = os.tmpname()
os.remove(temp)
run("mkdir -p " .. quote(temp .. "/vault") .. " " .. quote(temp .. "/home"))
local ok, message = pcall(function()
  local vault, home = temp .. "/vault", temp .. "/home"
  local config = vault .. "/.journal.config.toml"
  local answers = temp .. "/answers"
  local installer = quote(skill .. "/scripts/install.lua")
  local function install(full)
    write(answers, vault .. (full and "\n\n\n\n\n\n\n" or "\n"))
    run(
      "HOME=" .. quote(home) .. " lua " .. installer .. " < " .. quote(
        answers
      ) .. " >/dev/null"
    )
  end

  install(true)
  assert(read(home .. "/.obsidian-journal-vault") == vault .. "\n")
  run(
    "taplo lint --no-auto-config --schema " .. quote(
      "file://" .. skill .. "/schemas/config.json"
    ) .. " - < " .. quote(config) .. " >/dev/null 2>&1"
  )
  install(false)

  write(
    config,
    'authorized_dirs = []\n[core]\nname = "incomplete"\npath = "' .. vault .. '"\n'
  )
  install(true)
  local backups =
    assert(
      io.popen(
        "find " .. quote(
          vault
        ) .. " -name '.journal.config.toml.invalid-*' -print"
      )
    )
  local backup = backups:read("*l")
  backups:close()
  assert(backup and read(backup):find("incomplete", 1, true))
  run(
    "taplo lint --no-auto-config --schema " .. quote(
      "file://" .. skill .. "/schemas/config.json"
    ) .. " - < " .. quote(config) .. " >/dev/null 2>&1"
  )
end)
run("rm -rf " .. quote(temp))
if not ok then
  error(message, 0)
end
