local skill = (arg[0]:match("^(.*)/[^/]+$") or ".") .. "/.."
local journal = dofile(skill .. "/scripts/journal_util.lua")
for _, name in
  ipairs({ "current", "daily", "weekly", "monthly", "historic" })
do
  local template =
    assert(journal.read(skill .. "/templates/" .. name .. ".md.hbs"))
  assert(not template:find("{{{", 1, true))
end
local fields = journal.day_fields(journal.today)
fields.entry = { {
  time = "12:34",
  hash = "deadbeef",
  agent = "Codex",
  host = "testhost",
  work = "<b>&",
  cwd = "<&",
  files = "**file**",
  verification = "checked",
  pending = "none",
} }
local current = journal.render("current", fields)
assert(current:find("<b>&", 1, true))
assert(current:find("- <b>&", 1, true))
assert(current:find("- **file**", 1, true))
assert(current:find("<&", 1, true))
fields.entries = fields.entry
local daily = journal.render("daily", fields)
assert(daily:find("<b>&", 1, true))
assert(daily:find("- **file**", 1, true))
assert(not daily:find("{{", 1, true))
