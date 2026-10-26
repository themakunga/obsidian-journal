---
id: journal-week-{{week}}
aliases:
  - journal-weekly-{{week}}
  - summary-week-{{week}}
tags:
  - journal
  {{#each tags}}
    - {{name}}
  {{/each}}
create_at: {{week_start}}T00:00:00
updated_at: {{updared_at}}
year: {{year}}
---

# Journal Summary Weekly - {{week}}

| Ref | Location |
| --- | --- |
| Previous Week | [[{{journal_dir}}/{{previous_week}}/summary\|{{previous_week}}]] |
| Previous Month | [[{{journal_dir}}/{{previous_month}}\|{{previous_month}}]] |


## Summary {{week_start}} - {{week_end}}

{{summary}}


## Days

{{#each days}}
### {{date_label}}

{{description}}

[[{{journal_dir}}/{{week}}/{{date}}\|{{date}}]]

{{/each}}
