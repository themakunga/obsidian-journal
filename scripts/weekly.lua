local scripts = arg[0]:match("^(.*)/[^/]+$") or "."
local journal = dofile(scripts .. "/journal_util.lua")

journal.execute(function()
  local by_week = {}
  for _, date in ipairs(journal.archived_days()) do
    local week = journal.week(journal.day_epoch(date))
    by_week[week] = by_week[week] or {}
    by_week[week][#by_week[week] + 1] = date
  end
  local weeks = {}
  for week in pairs(by_week) do
    weeks[#weeks + 1] = week
  end
  table.sort(weeks)
  for _, week in ipairs(weeks) do
    if week ~= journal.week(journal.today_epoch) then
      local first = journal.day_epoch(by_week[week][1])
      local monday = first - (os.date("*t", first).wday + 5) % 7 * 86400
      local days = {}
      for _, date in ipairs(by_week[week]) do
        days[#days + 1] = {
          date = date,
          date_label = journal.date_label(date),
          description = "",
          week = week,
          journal_dir = "journal",
          marker = "[[journal/" .. week .. "/" .. date .. "\\|" .. date .. "]]",
        }
      end
      local fields = {
        week = week,
        week_start = journal.iso(monday),
        updated_at = journal.today,
        year = week:sub(1, 4),
        week_end = journal.iso(monday + 6 * 86400),
        journal_dir = "journal",
        enable_edit = "true",
        previous_week = journal.week(monday - 7 * 86400),
        previous_month = journal.previous_month(monday),
        summary = "",
        tags = {},
      }
      journal.update_blocks(
        journal.journal .. "/" .. week .. "/summary.md",
        "Days",
        "weekly",
        fields,
        "days",
        days
      )
    end
  end
end)
