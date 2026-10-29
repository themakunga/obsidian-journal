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

local function entry_text(heading, work)
  return table.concat(
    {
      heading,
      "",
      "**Work:**",
      "",
      work,
      "",
      "**CWD:** `/tmp`",
      "",
      "**Files:**",
      "",
      "- none",
      "",
      "**Verification:** checked",
      "",
      "**Pending:** none",
      "",
    },
    "\n"
  )
end

local function read(path)
  local file = assert(io.open(path, "r"))
  local content = assert(file:read("*a"))
  assert(file:close())
  return content
end

local function formatted(pattern, epoch)
  local value = os.date(pattern, epoch)
  assert(type(value) == "string")
  return value
end

local temp = os.tmpname()
os.remove(temp)
run("mkdir -p " .. quote(temp .. "/home"))
local ok, message = pcall(function()
  local remote, vault, home =
    temp .. "/remote.git",
    temp .. "/vault",
    temp .. "/home"
  run("git init --bare -b main " .. quote(remote) .. " >/dev/null")
  run(
    "git clone " .. quote(remote) .. " " .. quote(vault) .. " >/dev/null 2>&1"
  )
  run("git -C " .. quote(vault) .. " config user.name Test")
  run("git -C " .. quote(vault) .. " config user.email test@example.invalid")
  run("git -C " .. quote(vault) .. " config commit.gpgsign false")
  write(vault .. "/.gitignore", ".journal.config.toml\n")
  run("git -C " .. quote(vault) .. " add .gitignore")
  run("git -C " .. quote(vault) .. " commit -m 'test: initialize' >/dev/null")
  run("git -C " .. quote(vault) .. " push -u origin main >/dev/null 2>&1")
  write(
    vault .. "/.journal.config.toml",
    table.concat(
      {
        "authorized_dirs = []",
        "",
        "[core]",
        'name = "test"',
        'path = "' .. vault .. '"',
        "",
        "[configuration]",
        'date_format = "yyyy-MM-dd"',
        'time_format = "HH:mm:ss"',
        'agents = ["Codex"]',
        "",
      },
      "\n"
    )
  )
  write(home .. "/.obsidian-journal-vault", vault .. "\n")

  local function journal(script, arguments, input, selected_home)
    run(
      "HOME=" .. quote(selected_home or home) .. " lua " .. quote(
        skill .. "/scripts/" .. script .. ".lua"
      ) .. (arguments and " " .. arguments or "") .. (input and " < " .. quote(
        input
      ) or "") .. " >/dev/null"
    )
  end

  journal("sync")
  run(
    "HOME=" .. quote(home) .. " lua " .. quote(
      skill .. "/tests/template_check.lua"
    )
  )
  local today = formatted("%Y-%m-%d", os.time())
  assert(
    read(vault .. "/journal-current.md"):find(
      'id: "journal-' .. today .. '"',
      1,
      true
    )
  )
  journal("publish", "daily journal-current.md")
  assert(read(vault .. "/journal/README.md"):find("# test", 1, true))
  local entry = temp .. "/entry.md"
  write(
    entry,
    entry_text(
      "### 12:34:56 - deadbeef - Codex - testhost",
      "- recorded work\n- verified change"
    )
  )
  journal("entry", "Codex", entry)
  local invalid = temp .. "/invalid-entry.md"
  write(
    invalid,
    entry_text("### 12:35:56 - cafebabe - Codex - testhost", "plain text")
  )
  local result =
    os.execute(
      "HOME=" .. quote(home) .. " lua " .. quote(
        skill .. "/scripts/entry.lua"
      ) .. " Codex < " .. quote(invalid) .. " >/dev/null 2>&1"
    )
  assert(result ~= true and result ~= 0)

  local old_epoch = os.time() - 70 * 86400
  old_epoch = old_epoch - (os.date("*t", old_epoch).wday + 5) % 7 * 86400
  local old = formatted("%Y-%m-%d", old_epoch)
  local edited, replacements =
    read(vault .. "/journal-current.md"):gsub(
      'id: "journal%-%d%d%d%d%-%d%d%-%d%d"',
      'id: "journal-' .. old .. '"',
      1
    )
  assert(replacements == 1)
  edited, replacements =
    edited:gsub(
      'created_at: "%d%d%d%d%-%d%d%-%d%dT',
      'created_at: "' .. old .. "T",
      1
    )
  assert(replacements == 1)
  write(vault .. "/journal-current.md", edited)
  journal("sync")
  local week = formatted("%G-W%V", old_epoch)
  local month = old:sub(1, 7)
  local archive = "journal/" .. week .. "/" .. old .. ".md"
  assert(read(vault .. "/" .. archive):find("recorded work", 1, true))
  assert(read(vault .. "/" .. archive):find("- recorded work", 1, true))

  write(vault .. "/unrelated.txt", "leave staged\n")
  run("git -C " .. quote(vault) .. " add unrelated.txt")
  local wrong_type =
    os.execute(
      "HOME=" .. quote(home) .. " lua " .. quote(
        skill .. "/scripts/publish.lua"
      ) .. " weekly journal-current.md >/dev/null 2>&1"
    )
  assert(wrong_type ~= true and wrong_type ~= 0)
  journal("publish", "daily journal-current.md " .. archive)

  journal("weekly")
  journal("monthly")
  journal("history")
  assert(read(vault .. "/journal/" .. week .. "/summary.md"):find(old, 1, true))
  assert(
    read(vault .. "/journal/monthly/" .. month .. ".md"):find(week, 1, true)
  )
  assert(read(vault .. "/journal/history.md"):find(month, 1, true))

  local second = formatted("%Y-%m-%d", old_epoch + 86400)
  write(
    vault .. "/journal/" .. week .. "/" .. second .. ".md",
    "# Another archived day\n"
  )
  journal("publish", "daily journal/" .. week .. "/" .. second .. ".md")
  local weekly = vault .. "/journal/" .. week .. "/summary.md"
  write(
    weekly,
    read(weekly):gsub("\n## Days", "\nRetained weekly prose.\n\n## Days", 1)
  )
  journal("weekly")
  assert(read(weekly):find("Retained weekly prose.", 1, true))
  assert(read(weekly):find(second, 1, true))
  journal("publish", "weekly journal/" .. week .. "/summary.md")

  local history = vault .. "/journal/history.md"
  write(
    history,
    read(history):gsub(
      "\n## Months",
      "\nRetained history prose.\n\n## Months",
      1
    )
  )
  local later = formatted(
    "%Y-%m",
    os.time({
      year = assert(tonumber(today:sub(1, 4))),
      month = assert(tonumber(today:sub(6, 7))),
      day = 0,
      hour = 12,
    })
  )
  assert(later > month)
  write(
    vault .. "/journal/monthly/" .. later .. ".md",
    "# Later completed month\n"
  )
  journal(
    "publish",
    "monthly journal/monthly/" .. month .. ".md journal/monthly/" .. later .. ".md"
  )
  journal("history")
  assert(read(history):find("Retained history prose.", 1, true))
  assert(read(history):find("| Last Month", 1, true))
  assert(
    read(history):find("journal/monthly/" .. later .. "\\|" .. later, 1, true)
  )
  journal("publish", "history journal/history.md")

  journal("entry", "Codex", entry)
  local mixed_daily =
    os.execute(
      "HOME=" .. quote(home) .. " lua " .. quote(
        skill .. "/scripts/publish.lua"
      ) .. " daily journal-current.md >/dev/null 2>&1"
    )
  assert(mixed_daily ~= true and mixed_daily ~= 0)
  journal("publish", "entry journal-current.md")
  journal("publish", "entry journal-current.md")
  assert(read(vault .. "/journal-current.md"):find(today, 1, true))
  run("test ! -e " .. quote(vault .. "/.journal.lock"))
  local staged =
    assert(io.popen("git -C " .. quote(vault) .. " diff --cached --name-only"))
  assert(staged:read("*a"):find("unrelated.txt", 1, true))
  staged:close()
  run(
    "git --git-dir=" .. quote(remote) .. " cat-file -e " .. quote(
      "main:" .. archive
    )
  )
  local log =
    assert(io.popen("git -C " .. quote(vault) .. " log -6 --format=%s"))
  local messages = assert(log:read("*a"))
  assert(log:close())
  for message in messages:gmatch("[^\n]+") do
    assert(message:match("^journal: "))
  end
  local changed =
    assert(
      io.popen(
        "git -C " .. quote(vault) .. " show --pretty=format: --name-only HEAD"
      )
    )
  for path in changed:read("*a"):gmatch("[^\n]+") do
    assert(path == "journal-current.md" or path == "journal/README.md")
  end
  assert(changed:close())

  local other, other_home = temp .. "/other", temp .. "/other-home"
  run(
    "git clone " .. quote(remote) .. " " .. quote(other) .. " >/dev/null 2>&1"
  )
  run("mkdir " .. quote(other_home))
  run("git -C " .. quote(other) .. " config user.name Other")
  run("git -C " .. quote(other) .. " config user.email other@example.invalid")
  write(
    other .. "/.journal.config.toml",
    read(vault .. "/.journal.config.toml"):gsub(vault, other)
  )
  write(other_home .. "/.obsidian-journal-vault", other .. "\n")
  local first_entry, second_entry = temp .. "/first.md", temp .. "/second.md"
  write(
    first_entry,
    entry_text("### 12:36:56 - aaa111 - Codex - firsthost", "- first host work")
  )
  write(
    second_entry,
    entry_text(
      "### 12:37:56 - bbb222 - Codex - secondhost",
      "- second host work"
    )
  )
  journal("entry", "Codex", first_entry)
  journal("entry", "Codex", second_entry, other_home)
  journal("publish", "entry journal-current.md")
  journal("publish", "entry journal-current.md", nil, other_home)
  local combined = read(other .. "/journal-current.md")
  assert(combined:find("first host work", 1, true))
  assert(combined:find("second host work", 1, true))
  assert(select(2, combined:gsub("### 12:36:56 %- aaa111", "")) == 1)
  assert(select(2, combined:gsub("### 12:37:56 %- bbb222", "")) == 1)
  assert(not combined:find("<<<<<<<", 1, true))

  write(
    weekly,
    read(weekly):gsub("\n## Days", "\nFirst weekly note.\n\n## Days", 1)
  )
  local other_weekly = other .. "/journal/" .. week .. "/summary.md"
  write(
    other_weekly,
    read(other_weekly):gsub("\n## Days", "\nSecond weekly note.\n\n## Days", 1)
  )
  journal("publish", "weekly journal/" .. week .. "/summary.md")
  journal(
    "publish",
    "weekly journal/" .. week .. "/summary.md",
    nil,
    other_home
  )
  local summary = read(other_weekly)
  assert(summary:find("First weekly note.", 1, true))
  assert(summary:find("Second weekly note.", 1, true))
  assert(not summary:find("<<<<<<<", 1, true))

  local new_month = "journal/monthly/2000-01.md"
  write(
    vault .. "/" .. new_month,
    "---\nid: same\n---\n\n## Summary\n\nFirst month note.\n\n## Weeks\n"
  )
  write(
    other .. "/" .. new_month,
    "---\nid: same\n---\n\n## Summary\n\nSecond month note.\n\n## Weeks\n"
  )
  journal("publish", "monthly " .. new_month)
  journal("publish", "monthly " .. new_month, nil, other_home)
  local combined_month = read(other .. "/" .. new_month)
  assert(combined_month:find("First month note.", 1, true))
  assert(combined_month:find("Second month note.", 1, true))
  assert(select(2, combined_month:gsub("id: same", "")) == 1)
  journal("sync", nil, nil, other_home)
  local staged_after =
    assert(io.popen("git -C " .. quote(vault) .. " diff --cached --name-only"))
  assert(staged_after:read("*a"):find("unrelated.txt", 1, true))
  assert(staged_after:close())
end)
run("rm -rf " .. quote(temp))
if not ok then
  error(message, 0)
end
