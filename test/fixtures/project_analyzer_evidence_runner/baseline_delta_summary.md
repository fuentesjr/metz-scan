# Project analyzer evidence

Generated: 2026-07-05T17:15:00Z
Default output filter: false
Analyzer filter: none
Fixture root: `/tmp/apps`

Findings: 3
Offenses: 3

## Targets

| Target | Revision | Scan paths | Backend | Findings | Offenses |
| --- | --- | --- | --- | ---: | ---: |
| sample | abcdef123456 | `/tmp/apps/sample/app` | null | 3 | 3 |

## Rules

| Rule | Findings | Offenses | Status | Confidence | Severity |
| --- | ---: | ---: | --- | --- | --- |
| MetzProject/RepeatedBranching | 2 | 2 | validated | medium | design pressure |
| MetzProject/ServiceSoup | 1 | 1 | validated | medium | design pressure |

## Baseline Deltas

Baseline: test-baseline `/tmp/baseline.yml`

| Metric | Baseline | Current | Delta |
| --- | ---: | ---: | ---: |
| Findings | 3 | 3 | 0 |
| Offenses | 3 | 3 | 0 |

### Analyzer

| Rule | Baseline | Current | Delta |
| --- | ---: | ---: | ---: |
| MetzProject/RepeatedBranching findings | 1 | 2 | +1 |
| MetzProject/ServiceSoup findings | 2 | 1 | -1 |
| MetzProject/RepeatedBranching offenses | 1 | 2 | +1 |
| MetzProject/ServiceSoup offenses | 2 | 1 | -1 |

### Confidence

No confidence count changes.

### Severity

No severity count changes.

### Category

No category count changes.


## Breakdowns

### Confidence

| Value | Findings |
| --- | ---: |
| medium | 3 |

### Severity

| Value | Findings |
| --- | ---: |
| design pressure | 3 |

### Metadata: `project_analyzer_category`

| Value | Findings |
| --- | ---: |
| state | 3 |

