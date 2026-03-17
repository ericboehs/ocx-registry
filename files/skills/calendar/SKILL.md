---
name: calendar
description: Manage Apple Calendar using ical CLI. Use when user asks to check calendar, view schedule, create/update/delete events, search events, or says "/calendar".
tools: Bash
---

# Apple Calendar (ical)

Manage Apple Calendar from the command line using `ical` — a native macOS Calendar CLI built on EventKit with full CRUD support.

## Prerequisites

`ical` must be installed. If any command fails with "command not found", suggest running `/setup-calendar`.

## Usage

- `/calendar` — Show today's events
- `/calendar tomorrow` — Show tomorrow's events
- `/calendar week` — Show the next 7 days
- `/calendar add "Team standup" -s "tomorrow 9am" -e "tomorrow 9:30am"` — Create event
- `/calendar search "standup"` — Search events

## Calendar Filtering

Calendars can be excluded from queries using the `--exclude-calendar` flag (repeatable). Configure excluded calendars in your CLAUDE.md so they're applied automatically. Example CLAUDE.md snippet:

```markdown
## Calendar Exclusions
When using `/calendar`, always add these flags to list/today/upcoming/search commands:
--exclude-calendar "shared-calendar-name"
```

To discover available calendars:
```bash
ical calendars -o json
```

## Commands

### List today's events

```bash
ical today -o json
```

### List events for a date range

```bash
# Tomorrow
ical list -f tomorrow -t tomorrow -o json

# Next 7 days
ical upcoming 7 -o json

# Specific date range
ical list -f "2026-03-03" -t "2026-03-07" -o json

# Filter by specific calendar
ical list -f today -t today -c "Work" -o json
```

### Show event details

```bash
ical show --id "<full-event-id>" -o json
```

### Create events

```bash
# Basic event
ical add "Sprint Planning" -s "2026-03-03 10:00" -e "2026-03-03 11:00" -c "Work"

# With location and notes
ical add "Dentist" -s "2026-03-05 14:00" -e "2026-03-05 15:00" -l "123 Main St" -n "Annual checkup"

# All-day event
ical add "PTO" -s "2026-03-10" -a -c "Work"

# With alert
ical add "Deploy window" -s "2026-03-03 16:00" -e "2026-03-03 17:00" --alert 15m

# Recurring event
ical add "Weekly standup" -s "2026-03-03 09:00" -e "2026-03-03 09:30" -r weekly --repeat-days "mon,wed,fri"
```

### Update events

**Always use `--id` with the full event ID** for exact matching. Never use partial/prefix IDs — event IDs share a calendar UUID prefix so prefix matching can hit the wrong event.

```bash
# Change title
ical update --id "<full-event-id>" -T "New Title"

# Reschedule
ical update --id "<full-event-id>" -s "2026-03-04 10:00" -e "2026-03-04 11:00"

# Move to different calendar
ical update --id "<full-event-id>" -c "Personal"

# Update location/notes
ical update --id "<full-event-id>" -l "New Location" -n "Updated notes"

# For recurring events, update just this occurrence or all future
ical update --id "<full-event-id>" -s "2026-03-04 10:00" --span this
ical update --id "<full-event-id>" -s "2026-03-04 10:00" --span future
```

### Delete events

**Always use `--id` with the full event ID** — prefix matching is dangerous.

```bash
# Delete by full ID (skip confirmation)
ical delete --id "<full-event-id>" -f

# For recurring events
ical delete --id "<full-event-id>" -f --span this     # Just this occurrence
ical delete --id "<full-event-id>" -f --span future   # This and all future
```

### Search events

```bash
# Search by keyword (default: ±30 days)
ical search "standup" -o json

# Search within date range
ical search "sprint" -f "2026-03-01" -t "2026-03-31" -o json

# Search specific calendar
ical search "PTO" -c "Work" -o json

# Limit results
ical search "meeting" -n 5 -o json
```

## Behavior

1. When the user says `/calendar` with no arguments, show today's events
2. **Apply any `--exclude-calendar` flags** configured in the user's CLAUDE.md on list/today/upcoming/search commands
3. **Always use `-o json`** when listing events so you have stable event IDs for follow-up operations (update, delete, show)
4. **Always use `--id` with full event IDs** for update and delete — never use partial/prefix IDs. Event IDs share calendar UUID prefixes, so prefix matching can hit the wrong event.
5. Use `-f` (force) on delete operations to skip interactive confirmation prompts
6. When showing events to the user, format the JSON output into a clean readable agenda — don't dump raw JSON
7. Group events by day when showing multi-day ranges
8. Use natural language dates when possible (e.g., "tomorrow 9am", "next monday")
9. If `ical` is not installed, suggest running `/setup-calendar`
