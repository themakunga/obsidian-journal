local scripts = arg[0]:match("^(.*)/[^/]+$") or "."
local journal = dofile(scripts .. "/journal_util.lua")

journal.execute(function()
  local agent = arg[1]
  if not agent or not journal.allowed_agents[agent] then
    journal.abort("Agent is missing or not listed in configuration.agents.")
  end
  local entry = io.read("*a")
  local clock, hash, heading_agent, host =
    entry:match("^### (.-) %- ([%da-f]+) %- (.-) %- ([^\n]+)\n")
  if not hash or heading_agent ~= agent or not host or host == "" then
    journal.abort(
      "Entry heading must contain time, short hex hash, configured agent, and host."
    )
  end
  clock = assert(clock, "Entry heading is missing a time.")
  local patterns = {
    ["HH:mm"] = "^%d%d:%d%d$",
    ["HH:mm:ss"] = "^%d%d:%d%d:%d%d$",
    ["hh:mm a"] = "^%d%d:%d%d [AP]M$",
    ["hh:mm:ss a"] = "^%d%d:%d%d:%d%d [AP]M$",
    ["H:m"] = "^%d?%d:%d?%d$",
    ["h:m a"] = "^%d?%d:%d?%d [AP]M$",
  }
  local pattern =
    assert(patterns[journal.time_format], "Unsupported time format")
  if not clock:match(pattern) then
    journal.abort(
      "Entry time does not match configuration.time_format: " .. journal.time_format
    )
  end
  local hour, minute = clock:match("^(%d+):(%d+)")
  local second = clock:match("^%d+:%d+:(%d+)")
  hour = assert(tonumber(hour), "Invalid hour")
  minute = assert(tonumber(minute), "Invalid minute")
  if hour > (journal.time_format:find(
    "a",
    1,
    true
  ) and 12 or 23) or (journal.time_format:find(
    "a",
    1,
    true
  ) and hour == 0) or minute > 59 or (second and assert(
    tonumber(second)
  ) > 59) then
    journal.abort("Entry time is outside the valid clock range.")
  end
  for _, field in
    ipairs({ "Work", "CWD", "Files", "Verification", "Pending" })
  do
    if not entry:find("**" .. field .. ":**", 1, true) then
      journal.abort("Missing entry field: " .. field)
    end
  end
  local function check_bullets(field, next_field)
    local label = "**" .. field .. ":**"
    local first = assert(entry:find(label, 1, true), "Missing field: " .. field)
    local last =
      assert(
        entry:find("**" .. next_field .. ":**", first + #label, true),
        "Missing field after " .. field .. ": " .. next_field
      )
    local count = 0
    -- shortcut: bullets are single-line; accept continuation lines if journal entries need them.
    for line in entry:sub(first + #label, last - 1):gmatch("[^\n]+") do
      if line:find("%S") then
        if not line:match("^%s*%- %S") then
          journal.abort(field .. " must contain only '- ' bullet lines.")
        end
        count = count + 1
      end
    end
    if count == 0 then
      journal.abort(field .. " needs at least one bullet.")
    end
  end
  check_bullets("Work", "CWD")
  check_bullets("Files", "Verification")
  local content =
    assert(
      journal.read(journal.current),
      "Run sync.lua before appending today's entry."
    )
  if not content:find('created_at: "' .. journal.today .. "T", 1, true) then
    journal.abort("Run sync.lua before appending today's entry.")
  end
  local heading = assert(entry:match("^([^\n]+)"), "Missing entry heading")
  if content:find(heading, 1, true) then
    journal.abort("Entry already exists: " .. heading)
  end
  journal.write(
    journal.current,
    content:gsub("%s*$", "") .. "\n\n" .. entry:gsub("%s*$", "") .. "\n"
  )
  print("updated: " .. journal.current)
end)
