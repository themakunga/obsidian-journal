local scripts = arg[0]:match("^(.*)/[^/]+$") or "."
local journal = dofile(scripts .. "/journal_util.lua")

local function git(directory, command)
  return "git -C " .. journal.quote(directory) .. " " .. command
end

local function merge_file(temp, path, base, ours, theirs)
  if not theirs then
    return ours
  end
  if ours == base then
    return theirs
  end
  if theirs == base or ours == theirs then
    return ours
  end
  if path == "journal-current.md" then
    local function date(content)
      return content and content:match('created_at:%s*"(%d%d%d%d%-%d%d%-%d%d)T')
    end
    if date(ours) ~= date(theirs) then
      journal.abort("Current journal dates differ across hosts.")
    end
  end
  if path == ".glados/phrases.yaml" then
    local files = { temp .. "/ours", temp .. "/base", temp .. "/theirs" }
    journal.write(files[1], ours)
    journal.write(files[2], base or "[]\n")
    journal.write(files[3], theirs)
    local output = temp .. "/merged"
    journal.run(
      "uv run --project " .. journal.quote(
        journal.skill
      ) .. " python " .. journal.quote(
        journal.skill .. "/scripts/glados.py"
      ) .. " merge-phrases " .. journal.quote(files[2]) .. " " .. journal.quote(
        files[1]
      ) .. " " .. journal.quote(files[3]) .. " > " .. journal.quote(output)
    )
    return assert(journal.read(output))
  end
  if not base then
    local prefix, left, right = {}, {}, {}
    for line in (ours .. "\n"):gmatch("(.-)\n") do
      left[#left + 1] = line
    end
    for line in (theirs .. "\n"):gmatch("(.-)\n") do
      right[#right + 1] = line
    end
    for index = 1, math.min(#left, #right) do
      if left[index] ~= right[index] then
        break
      end
      prefix[#prefix + 1] = left[index]
    end
    base = table.concat(prefix, "\n") .. "\n"
  end
  local files = { temp .. "/ours", temp .. "/base", temp .. "/theirs" }
  journal.write(files[1], ours)
  journal.write(files[2], base)
  journal.write(files[3], theirs)
  local output = temp .. "/merged"
  local result, _, code =
    os.execute(
      "git merge-file --union -p " .. journal.quote(
        files[1]
      ) .. " " .. journal.quote(files[2]) .. " " .. journal.quote(
        files[3]
      ) .. " > " .. journal.quote(output)
    )
  if result ~= true and result ~= 0 and code ~= 1 then
    journal.abort("Cannot merge " .. path)
  end
  local merged = assert(journal.read(output))
  if merged:find("<<<<<<<", 1, true) or merged:find(">>>>>>>", 1, true) then
    journal.abort("Unresolved merge in " .. path)
  end
  local section =
    path == "journal-current.md" and "Details" or path:match(
      "/summary%.md$"
    ) and "Days" or path:match(
      "^monthly/"
    ) and "Weeks" or path == "history.md" and "Months" or path:match(
      "^weekly/%d%d%d%d%-W%d%d/"
    ) and "Details"
  if not merged:match("^%-%-%-\n.-\n%-%-%-\n") or select(
    2,
    merged:gsub("\nid:", "")
  ) ~= 1 or (section and select(
    2,
    merged:gsub("\n## " .. section .. "\n", "")
  ) ~= 1) then
    journal.abort(
      "Concurrent changes produced an invalid journal structure: " .. path
    )
  end
  return merged
end

journal.execute(function()
  local task = assert(arg[1], "Missing journal task type")
  local allowed = {
    daily = function(path)
      return path == "journal-current.md" or path:match(
        "^weekly/%d%d%d%d%-W%d%d/%d%d%d%d%-%d%d%-%d%d%.md$"
      ) or (journal.glados_enabled and path == ".glados/phrases.yaml")
    end,
    weekly = function(path)
      return path:match("^weekly/%d%d%d%d%-W%d%d/summary%.md$")
    end,
    monthly = function(path)
      return path:match("^monthly/%d%d%d%d%-%d%d%.md$")
    end,
    history = function(path)
      return path == "history.md"
    end,
    entry = function(path)
      return path == "journal-current.md"
    end,
  }
  local accepts = allowed[task]
  if not accepts or not arg[2] then
    journal.abort(
      "Usage: publish.lua daily|weekly|monthly|history|entry FILE [FILE ...]"
    )
  end
  journal.git_root()
  local paths, local_files, bases, seen = {}, {}, {}, {}
  local function add_path(path)
    if not accepts(path) or path:find("%.%.") then
      journal.abort("Invalid " .. task .. " path: " .. path)
    end
    if seen[path] then return end
    seen[path] = true
    local content = journal.read(journal.vault .. "/" .. path)
    if not content then
      journal.abort("Invalid journal file: " .. path)
    end
    paths[#paths + 1], local_files[path] = path, content
    if journal.succeeds(
      git(
        journal.vault,
        "cat-file -e " .. journal.quote("HEAD:" .. path) .. " 2>/dev/null"
      )
    ) then
      local base_file = os.tmpname()
      journal.run(
        git(
          journal.vault,
          "show " .. journal.quote("HEAD:" .. path)
        ) .. " > " .. journal.quote(base_file)
      )
      bases[path] = assert(journal.read(base_file))
      assert(os.remove(base_file))
    end
  end
  for index = 2, #arg do
    add_path(arg[index])
  end
  local phrase_path = ".glados/phrases.yaml"
  if task == "daily" and journal.glados_enabled and journal.read(
    journal.vault .. "/" .. phrase_path
  ) then
    add_path(phrase_path)
  end
  local current_base = bases["journal-current.md"]
  if task == "daily" and local_files["journal-current.md"] then
    for heading in local_files["journal-current.md"]:gmatch("\n(### [^\n]+)") do
      if not current_base or not current_base:find(heading, 1, true) then
        journal.abort(
          "Current journal contains a new entry; publish the daily task before appending entries."
        )
      end
    end
  end
  if task == "entry" and (not current_base or not current_base:find(
    'created_at: "' .. journal.today .. "T",
    1,
    true
  )) then
    journal.abort("Publish today's daily task before publishing an entry.")
  end
  local upstream =
    journal.capture(
      git(
        journal.vault,
        "rev-parse --abbrev-ref --symbolic-full-name '@{upstream}'"
      )
    )
  local remote, branch = upstream:match("^([^/]+)/(.+)$")
  if not remote or not branch then
    journal.abort("Git upstream branch is required.")
  end
  journal.run(
    git(
      journal.vault,
      "fetch " .. journal.quote(remote) .. " " .. journal.quote(branch)
    )
  )
  if not journal.succeeds(
    git(journal.vault, "merge-base --is-ancestor HEAD FETCH_HEAD")
  ) then
    journal.abort(
      "Local commits are not on the remote branch; publish or reconcile them first."
    )
  end
  local url =
    journal.capture(
      git(journal.vault, "remote get-url " .. journal.quote(remote))
    )
  local push_url =
    journal.capture(
      git(journal.vault, "remote get-url --push " .. journal.quote(remote))
    )
  local name = journal.capture(git(journal.vault, "config user.name"))
  local email = journal.capture(git(journal.vault, "config user.email"))
  local agent =
    (os.getenv("AI_AGENT") or ""):match("^([^_]+)") or (os.getenv(
      "CLAUDECODE"
    ) and "claude-code") or (os.getenv(
      "HERMES_AGENT"
    ) and "hermes") or (os.getenv("CODEX") and "codex") or name

  local temp = os.tmpname()
  assert(os.remove(temp))
  journal.run("mkdir " .. journal.quote(temp))
  local ok, result = pcall(function()
    for attempt = 1, 5 do
      local checkout = temp .. "/checkout"
      journal.run(
        "git clone --quiet --single-branch --branch " .. journal.quote(
          branch
        ) .. " " .. journal.quote(url) .. " " .. journal.quote(checkout)
      )
      if push_url ~= url then
        journal.run(
          git(
            checkout,
            "remote set-url --push origin " .. journal.quote(push_url)
          )
        )
      end
      local remote_head = journal.capture(git(checkout, "rev-parse HEAD"))
      local merged = {}
      for _, path in ipairs(paths) do
        local theirs = journal.read(checkout .. "/" .. path)
        merged[path] =
          merge_file(temp, path, bases[path], local_files[path], theirs)
        if merged[path] then
          journal.run(
            "mkdir -p " .. journal.quote(
              (checkout .. "/" .. path):match("^(.*)/[^/]+$")
            )
          )
          journal.write(checkout .. "/" .. path, merged[path])
        end
      end
      local selected = {}
      for _, path in ipairs(paths) do
        selected[#selected + 1] = journal.quote(path)
      end
      local readme_path = checkout .. "/README.md"
      local vault_name =
        journal.capture(
          "taplo get core.name --file-path " .. journal.quote(
            journal.config
          ) .. " -s"
        )
      local host = journal.capture("hostname -s")
      local pub_line =
        "_Last published: " .. os.date(
          "%Y-%m-%dT%H:%M:%S%z"
        ) .. " by " .. agent .. " on " .. host .. "_"
      local readme = journal.read(readme_path)
      if not readme then
        journal.write(
          readme_path,
          journal.render("journal-readme", {
            vault_name = vault_name,
            author = name,
            pub_line = pub_line,
          })
        )
      elseif readme:find("_Last published:") then
        readme = readme:gsub("_Last published:[^\n]*_", pub_line)
        journal.write(readme_path, readme)
      else
        journal.write(
          readme_path,
          readme:gsub("%s*$", "") .. "\n\n## Publishing\n\n" .. pub_line .. "\n"
        )
      end
      selected[#selected + 1] = journal.quote("README.md")
      journal.run(git(checkout, "add -- " .. table.concat(selected, " ")))
      if not journal.succeeds(
        git(
          checkout,
          "diff --cached --quiet -- " .. table.concat(selected, " ")
        )
      ) then
        journal.run(
          git(
            checkout,
            "-c user.name=" .. journal.quote(
              name
            ) .. " -c user.email=" .. journal.quote(
              email
            ) .. " -c commit.gpgsign=false commit -m " .. journal.quote(
              "journal: " .. os.date(
                "%Y-%m-%dT%H:%M:%S%z"
              ) .. " - " .. agent .. " - " .. journal.capture("hostname -s")
            ) .. " -- " .. table.concat(selected, " ")
          )
        )
      end
      if journal.succeeds(
        git(
          checkout,
          "push origin " .. journal.quote(branch) .. " >/dev/null 2>&1"
        )
      ) then
        for _, path in ipairs(paths) do
          if journal.read(
            journal.vault .. "/" .. path
          ) ~= local_files[path] then
            journal.abort("Local file changed during publication: " .. path)
          end
          if bases[path] then
            journal.run(
              git(
                journal.vault,
                "restore --source=HEAD --staged --worktree -- " .. journal.quote(
                  path
                )
              )
            )
          else
            assert(os.remove(journal.vault .. "/" .. path))
          end
        end
        journal.run(
          git(
            journal.vault,
            "fetch " .. journal.quote(remote) .. " " .. journal.quote(branch)
          )
        )
        journal.run(git(journal.vault, "merge --ff-only FETCH_HEAD"))
        journal.speak(
          "success",
          "The " .. task .. " journal task was committed and pushed. " .. journal.activity(
            local_files,
            paths
          )
        )
        print("Published " .. task .. " task.")
        return
      end
      local actual =
        journal.capture(
          "git ls-remote " .. journal.quote(url) .. " " .. journal.quote(
            "refs/heads/" .. branch
          )
        )
      if actual:match("^[0-9a-f]+") == remote_head then
        journal.abort(
          "Push failed without a remote update; check access and connectivity."
        )
      end
      journal.run("rm -rf " .. journal.quote(checkout))
      if attempt == 5 then
        journal.abort("Push was rejected after five retries.")
      end
    end
  end)
  journal.run("rm -rf " .. journal.quote(temp))
  if not ok then
    journal.abort(result)
  end
end)
