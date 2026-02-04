# Phase 08: Interactive UI - State Tracker

## Overview
Implement Telegram inline buttons for confirmations and selections to improve decision-making and prevent accidental actions.

## Progress: 0/3 Plans Completed (0%)

---

## 08-01: Callback Handler Foundation ❌ NOT STARTED
**Status**: Pending
**Dependencies**: None
**Blocker**: None

### Tasks
- [ ] Register callback_query webhook
- [ ] Parse callback data and route
- [ ] Add button expiration check (5 minutes)
- [ ] Add callback acknowledgment
- [ ] Add callback logging to database

### Artifacts
- [ ] callback_handler.json workflow
- [ ] Database logging implementation
- [ ] Webhook registration

---

## 08-02: Button Templates ❌ NOT STARTED
**Status**: Pending
**Dependencies**: 08-01
**Blocker**: None

### Tasks
- [ ] Create button template workflow
- [ ] Implement Yes/No template
- [ ] Implement Priority Selector template
- [ ] Add custom multi-row button support
- [ ] Add URL button support

### Artifacts
- [ ] button_templates.json workflow
- [ ] Template test results

---

## 08-03: Workflow Integration ❌ NOT STARTED
**Status**: Pending
**Dependencies**: 08-02
**Blocker**: None

### Tasks
- [ ] Add confirmation to Security Scan workflow
- [ ] Add priority selector to task creation
- [ ] Add confirmation to destructive operations
- [ ] Implement callback routing for new actions
- [ ] Add button analytics

### Artifacts
- [ ] Updated sub-workflows with buttons
- [ ] Callback routing for all actions
- [ ] Analytics implementation

---

## SQL Schema Requirements

### button_interactions table
```sql
CREATE TABLE IF NOT EXISTS button_interactions (
    id SERIAL PRIMARY KEY,
    callback_query_id VARCHAR(255) UNIQUE NOT NULL,
    user_id BIGINT NOT NULL,
    action VARCHAR(100) NOT NULL,
    params JSONB,
    button_age_seconds INTEGER NOT NULL,
    is_expired BOOLEAN NOT NULL DEFAULT false,
    decision VARCHAR(10),
    time_to_decision INTEGER,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_button_user_action ON button_interactions(user_id, action, timestamp DESC);
CREATE INDEX idx_button_decision ON button_interactions(action, decision);
```

---

## Success Criteria (from ROADMAP.md)

1. **SC-8.1**: Destructive actions show Yes/No buttons (not text prompt)
2. **SC-8.2**: Button press triggers correct callback workflow
3. **SC-8.3**: Priority buttons update task with selected priority
4. **SC-8.4**: Buttons expire after 5 minutes (prevent stale actions)

---

## Button Templates Specification

### Yes/No Template
```
[ ✅ Yes ] [ ❌ No ]
```

Callback data format:
- Yes: `yes_{action}:{param1}:{param2}...`
- No: `no_{action}:{param1}:{param2}...`

Use cases:
- Confirm destructive actions
- Approve security scans
- Verify user intent

### Priority Selector Template
```
[ 🔴 High ] [ 🟡 Medium ] [ 🟢 Low ]
```

Callback data format:
- `{action}:high:{param1}:{param2}...`
- `{action}:medium:{param1}:{param2}...`
- `{action}:low:{param1}:{param2}...`

Use cases:
- Set task priority
- Set alert severity

### Custom Multi-Row Template
```
[ Option 1 ] [ Option 2 ] [ Option 3 ]
[          Cancel          ]
```

Flexible layout for:
- Multi-option menus
- Tool selection
- Custom flows

### Mixed Callback + URL Template
```
[ 🔴 High ] [ 🟡 Medium ] [ 🟢 Low ]
[     View in Notion 🔗         ]
```

Combines:
- Callback buttons (execute actions)
- URL buttons (open links)

---

## Testing Checklist

### Callback Handler (08-01)
- [ ] Button click triggers callback_query webhook
- [ ] Callback data parsed correctly
- [ ] 6-minute-old button shows expiration error
- [ ] Loading spinner disappears immediately
- [ ] Button click logged to database

### Button Templates (08-02)
- [ ] Yes/No template generates correct callbacks
- [ ] Priority selector has 3 buttons
- [ ] Custom template supports 2+ rows
- [ ] URL button opens browser
- [ ] Mixed callback+URL layout works

### Integration (08-03)
- [ ] Security scan shows confirmation
- [ ] Click Yes executes scan
- [ ] Click No cancels scan
- [ ] Task creation shows priority selector
- [ ] Click High sets task to high priority
- [ ] Destructive operations require confirmation

---

## Callback Data Examples

| Action | User Input | Callback Data | Handler |
|--------|------------|---------------|---------|
| Scan Confirm | "Scan example.com" | `yes_confirm_scan:example.com` | Execute security scan |
| Scan Cancel | *clicks No* | `no_confirm_scan:example.com` | Send "Scan cancelled" |
| Set Priority | *clicks High* | `set_task_priority:high:task_123` | Update Notion task |
| Delete Task | "Delete task 456" | `yes_delete_task:456` | Delete from Notion |
| Cancel Delete | *clicks No* | `no_delete_task:456` | Send "Cancelled" |

---

## Analytics Queries

### Confirmation Rate
```sql
SELECT
  action,
  COUNT(CASE WHEN decision = 'yes' THEN 1 END)::FLOAT /
    COUNT(*) * 100 AS yes_percentage
FROM button_interactions
WHERE action LIKE 'confirm_%'
AND timestamp > NOW() - INTERVAL '7 days'
GROUP BY action;
```

### Priority Distribution
```sql
SELECT
  decision AS priority,
  COUNT(*) as count
FROM button_interactions
WHERE action = 'set_task_priority'
AND timestamp > NOW() - INTERVAL '30 days'
GROUP BY decision
ORDER BY count DESC;
```

### Average Decision Time
```sql
SELECT
  action,
  AVG(time_to_decision) as avg_seconds,
  MAX(time_to_decision) as max_seconds
FROM button_interactions
WHERE timestamp > NOW() - INTERVAL '7 days'
GROUP BY action
ORDER BY avg_seconds DESC;
```

---

## Notes

- **Button expiration**: 5 minutes prevents stale actions
- **Callback acknowledgment**: Must respond within 30 seconds
- **Telegram limits**: Max 8 buttons per row, max 100 callback_data chars
- **URL buttons**: Don't trigger callbacks, just open links
- **Button text**: Emojis improve scannability (✅ ❌ 🔴 🟡 🟢)

---

Last Updated: 2026-02-04 by Claude Sonnet 4.5
