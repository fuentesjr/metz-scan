# Project analyzer evidence

Generated: 2026-07-03T15:00:00Z
Default output filter: false
Analyzer filter: MetzProject/RepeatedQueryCriteria
Targets file: `/tmp/targets.yml`
Fixture root: `/tmp/apps`

Findings: 2
Offenses: 2

## Targets

| Target | Revision | Scan paths | Backend | Findings | Offenses |
| --- | --- | --- | --- | ---: | ---: |
| sample | abcdef123456 | `/tmp/apps/sample/app`<br>`/tmp/apps/sample/lib` | rubydex | 2 | 2 |

## Rules

| Rule | Findings | Offenses | Status | Confidence | Severity |
| --- | ---: | ---: | --- | --- | --- |
| MetzProject/RepeatedQueryCriteria | 2 | 2 | candidate | medium | manual review |

## Readiness

| Rule | Disposition | Evidence | Next | Not next |
| --- | --- | --- | --- | --- |
| MetzProject/RepeatedQueryCriteria | Candidate-only \| opt-in | 2 findings | Keep \| parked | Do not add more query forms |


## Notable Findings

| Target | Rule | Confidence | Severity | Category | Location | Message |
| --- | --- | --- | --- | --- | --- | --- |
| sample | MetzProject/RepeatedQueryCriteria | medium | manual review | query\|criteria | app/models/order.rb:12 | Repeated criteria \| need named query |


## Breakdowns

### Confidence

| Value | Findings |
| --- | ---: |
| medium | 2 |

### Severity

| Value | Findings |
| --- | ---: |
| manual review | 2 |

### Metadata: `project_analyzer_category`

| Value | Findings |
| --- | ---: |
| query | 2 |

