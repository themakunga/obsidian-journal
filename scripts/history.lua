local scripts = arg[0]:match("^(.*)/[^/]+$") or "."
local journal = dofile(scripts .. "/journal_util.lua")

journal.execute(function()
  local pipe =
    assert(
      io.popen(
        "find " .. journal.quote(
          journal.journal .. "/monthly"
        ) .. " -type f -name '????-??.md' -print"
      )
    )
  local months = {}
  for path in pipe:lines() do
    local month = path:match("/(%d%d%d%d%-%d%d)%.md$")
    if month then
      months[#months + 1] = month
    end
  end
  pipe:close()
  table.sort(months)
  if #months == 0 then return end

  local items = {}
  for _, month in ipairs(months) do
    items[#items + 1] = {
      month = month,
      description = "",
      marker = "[[monthly/" .. month .. "\\|" .. month .. "]]",
    }
  end
  local last = months[#months]
  local fields = {
    journal_start = months[1] .. "-01",
    updated_at = journal.today,
    summary = "",
    start_date = months[1] .. "-01",
    updated_date = journal.today,
    initial_month = months[1],
    last_month = last,
    month_label = os.date("%B", journal.day_epoch(last .. "-01")),
    year = last:sub(1, 4),
    tags = {},
  }
  local history = journal.journal .. "/history.md"
  journal.update_blocks(history, "Months", "historic", fields, "months", items)
  local content = assert(journal.read(history), "Missing history after update")
  local previous =
    content:match("| Last Month%s*| %[%[monthly/(%d%d%d%d%-%d%d)")
  if previous and previous ~= last then
    local old_link = "[[monthly/" .. previous .. "\\|" .. previous .. "]]"
    local new_link = "[[monthly/" .. last .. "\\|" .. last .. "]]"
    local row = content:find("| Last Month", 1, true)
    if not row then
      journal.abort("Missing Last Month in " .. history)
    end
    local first, final = content:find(old_link, row, true)
    if not first or not final then
      journal.abort("Cannot update Last Month in " .. history)
    end
    content = content:sub(1, first - 1) .. new_link .. content:sub(final + 1)
    content =
      content:gsub(
        "# Journal %- Monthly [^\n]+",
        "# Journal - Monthly " .. fields.month_label .. " " .. fields.year,
        1
      )
    content =
      content:gsub(
        "## Summary [^\n]+",
        "## Summary " .. fields.start_date .. " - " .. fields.updated_date,
        1
      )
    journal.write(history, content)
    print("updated: " .. history)
  end
end)
