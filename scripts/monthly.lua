local scripts = arg[0]:match("^(.*)/[^/]+$") or "."
local journal = dofile(scripts .. "/journal_util.lua")

journal.execute(function()
  local by_month = {}
  for _, date in ipairs(journal.archived_days()) do
    local month = date:sub(1, 7)
    by_month[month] = by_month[month] or {}
    by_month[month][journal.week(journal.day_epoch(date))] = true
  end
  local months = {}
  for month in pairs(by_month) do
    months[#months + 1] = month
  end
  table.sort(months)
  for _, month in ipairs(months) do
    if month ~= journal.today:sub(1, 7) then
      local weeks, complete = {}, true
      for week in pairs(by_month[month]) do
        weeks[#weeks + 1] = week
        if not journal.read(
          journal.journal .. "/weekly/" .. week .. "/summary.md"
        ) then
          complete = false
        end
      end
      table.sort(weeks)
      if complete then
        local items = {}
        for _, week in ipairs(weeks) do
          items[#items + 1] = {
            week = week,
            description = "",
            journal_dir = "journal",
            marker = "[[journal/weekly/" .. week .. "/summary\\|" .. week .. "]]",
          }
        end
        local start = month .. "-01"
        local epoch = journal.day_epoch(start)
        local month_end = os.date(
          "%Y-%m-%d",
          os.time({
            year = assert(tonumber(month:sub(1, 4))),
            month = assert(tonumber(month:sub(6, 7))) + 1,
            day = 0,
            hour = 12,
          })
        )
        local fields = {
          month = month,
          month_start = start,
          updated_at = journal.today,
          year = month:sub(1, 4),
          month_end = month_end,
          month_label = os.date("%B", epoch),
          prev_month = journal.previous_month(epoch),
          journal_dir = "journal",
          enable_edit = "true",
          summary = "",
          tags = {},
        }
        journal.update_blocks(
          journal.journal .. "/monthly/" .. month .. ".md",
          "Weeks",
          "monthly",
          fields,
          "weeks",
          items
        )
      end
    end
  end
end)
