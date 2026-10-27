# Contributing

Obsidian Journal is under development. Contributions to the skill, templates,
configuration schema, documentation, and tooling are welcome. Please read the
[Code of Conduct](CODE_OF_CONDUCT.md) before participating.

## Propose a change

For a bug report, describe the expected behavior, actual behavior, and steps to
reproduce it. Include relevant tool versions and a minimal example. Remove vault
content, credentials, personal information, and private paths before sharing.

For a substantial feature or a change to the journal format, open an issue to
discuss the scope first. Small fixes can go directly into a pull request.

## Set up development

Fork and clone the repository, create a branch, and make `pre-commit` and
`luacheck` available in your environment. Install the hooks and run the checks:

```sh
pre-commit install
pre-commit run --all-files
```

The configuration installs both file checks and commit message validation. Node
tools and their pinned dependencies run in isolated pre-commit environments.
Luacheck must be on `PATH` when checking Lua files.

## Make the change

- Keep changes focused and follow the existing YAML configuration style.
- Use English for documentation, configuration, code, and commit messages.
- Follow the formatting and Markdown rules documented in [README.md](README.md).
- Add a focused check for new behavior or a regression when practical.
- Preserve existing journal data, frontmatter, and Obsidian links.
- Keep configuration keys, templates, and the schema aligned when changing them.

HTML/Handlebars `.hbs` files use Prettier's `glimmer` parser. Compound `.md.hbs`
and `.toml.hbs` templates are excluded from Prettier to preserve their source
structure. Review those templates manually and check representative rendered
output for any template change.

CSpell uses `cspell.config.yaml`. Correct spelling errors rather than adding
them to the dictionary. Add legitimate project or technology terms to `words`
only when the bundled dictionaries do not cover them.

## Validate and submit

Run `pre-commit run --all-files` before submitting. If a hook rewrites files,
review the changes, stage them again, and rerun the checks. Explain any checks
that could not run and any existing failures in the pull request.

Commitlint requires Conventional Commits, for example:

```text
feat(journal): add weekly summaries
fix(templates): preserve Markdown table rows
docs: clarify configuration
```

Describe the problem, resulting behavior, and verification in your pull request.
Link related issues and include a rendered example when a template layout
changes.

## License

By submitting a contribution, you agree that it may be distributed under the
project's [MIT License](LICENSE).
