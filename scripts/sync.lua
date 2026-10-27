local scripts = arg[0]:match("^(.*)/[^/]+$") or "."
local journal = dofile(scripts .. "/journal_util.lua")

journal.execute(function()
  journal.git_root()
  journal.run("git -C " .. journal.quote(journal.vault) .. " pull --ff-only")
  journal.run("mkdir -p " .. journal.quote(journal.journal .. "/monthly"))

  local active = journal.read(journal.current)
  if active then
    local active_date = active:match('created_at:%s*"(%d%d%d%d%-%d%d%-%d%d)T')
    if not active_date or active_date > journal.today then
      journal.abort("Unexpected date in journal-current.md")
    end
    if active_date < journal.today then
      local archive =
        journal.journal .. "/" .. journal.week(
          journal.day_epoch(active_date)
        ) .. "/" .. active_date .. ".md"
      if journal.read(archive) then
        journal.abort("Archive already exists: " .. archive)
      end
      if not active:find("\n## Details", 1, true) then
        journal.abort("Missing Details in journal-current.md")
      end
      journal.run(
        "mkdir -p " .. journal.quote(
          journal.journal .. "/" .. journal.week(journal.day_epoch(active_date))
        )
      )
      local archived =
        active:gsub("\nenable_edit: true\n", "\nenable_edit: false\n", 1)
      if not archived:find("\n## Summary", 1, true) then
        archived =
          archived:gsub("\n## Details", "\n## Summary\n\n\n\n## Details", 1)
      end
      journal.write(archive, archived)
      assert(os.remove(journal.current))
      print("archived: " .. archive)
      active = nil
    end
  end
  if not active then
    journal.write(
      journal.current,
      journal.render("current", journal.day_fields(journal.today))
    )
    print("created: " .. journal.current)
  end
  journal.refresh_glados()
end)
