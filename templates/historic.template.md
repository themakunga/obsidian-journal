---
id: journal-history
aliases:
  - journal-history
  - summary-history
tags:
  - journal
  {{#each tags}}
   - {{name}}
  {{/each}}
created_at: {{journal_start}}T00:00:00
updated_at: {{updated_at}}
---

# Journal - Monthly {{month_label}} {{year}}

| Ref | Location |
| --- | --- |
| Initial Month | [[{{journal_dir}}/monthly/{{initial_month}}\|{{initial_month}}]] |
| Last Month | [[{{journal_dir}}/monthly/{{last_month}}\|{{last_month}}]]  |


## Summary {{ start_date}} - {{updated_date}}

{{summary}}

## Months

{{#each months}}
### {{month}}

{{description}}

[[{{journal_dir}}/monthly/{{month}}\|{{month}}]]

---

{{/each}}
