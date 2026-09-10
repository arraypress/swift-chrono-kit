# Swift Chrono

Date arithmetic a calendar decides, not a multiplication — as typed values, on any Apple platform.

```swift
import ChronoKit

let start = try Chrono.date("2026-01-31")
let later = try Chrono.shift(start, by: 1, .month)
Chrono.describe(later).date            // "2026-02-28" — not 2026-03-02

Chrono.describe(try Chrono.date("2027-01-01")).isoWeek      // 53
Chrono.describe(try Chrono.date("2027-01-01")).isoWeekYear  // 2026, not 2027

try Chrono.shiftBusinessDays(try Chrono.date("2026-09-04"), by: 10)
// 2026-09-18 — a Friday, a fortnight later
```

## Why

These are the questions a language model answers confidently and gets wrong, because
none of them have a formula. They are calendar rules, and Foundation already knows them:

| Question | The wrong answer, and why it is tempting |
|---|---|
| 31 January plus one month | 2 March, from adding 2,592,000 seconds. There is no 31 February, so the calendar clamps to the 28th. |
| A day across a DST boundary | 24 hours. In Europe/London it is 23 in March and 25 in October. |
| Which ISO week 1 January 2027 is in | Week 1 of 2027. It is week **53 of 2026** — the week that owns it started the previous December. |
| Ten working days from a Friday | +10 days, or +14. It is neither in general; weekends have to be walked. |
| 23:00 Monday to 01:00 Wednesday | One day, from a raw component diff. Everybody calls that two. |

## Installation

```swift
.package(url: "https://github.com/arraypress/swift-chrono-kit.git", from: "0.1.0")
```

Foundation only. No dependencies, every Apple platform, macOS 14+.

## Reading a date

`Chrono.date(_:)` accepts ISO 8601, plain language and bare Unix timestamps:

```swift
try Chrono.date("2026-09-03")              // start of that day, in Chrono.timeZone
try Chrono.date("2026-09-03T14:30")        // that wall clock, in Chrono.timeZone
try Chrono.date("2026-09-03T12:00:00Z")    // noon UTC, whatever the ambient zone
try Chrono.date("tomorrow 9am")
try Chrono.date("next friday")             // always a week out; a bare "friday" may be today
try Chrono.date("last friday")             // never today
try Chrono.date("+2w")
try Chrono.date("3d ago")                  // because a leading `-` is an option name to most parsers
try Chrono.date("1772547000")              // seconds; 13 digits is milliseconds
try Chrono.date("3pm")                     // a bare time means today
try Chrono.date("9:30 am PST")             // and a trailing zone is honoured
```

The relative grammar is ported from `AgendaKit`, where it was internal to a package
that imports EventKit. Answering "what is 2w from now" should not need the calendar
permission.

## Three tiers, and none of them a model

`Chrono.date(_:)` tries them in order, exact first:

1. **This package's grammar** — `+2w`, `3 days ago`, `two weeks from now`,
   `next friday`, ISO 8601, Unix timestamps. Exact, and the only tier that
   reads the compact spellings.
2. **Foundation's `NSDataDetector`** — the engine behind the dates iOS
   underlines and offers to add to your calendar.
3. Nothing. It throws.

Tier 2 is why the phrase list does not have to be finished:

```swift
try Chrono.date("this sunday")
try Chrono.date("a week on tuesday")
try Chrono.date("the tuesday after next")
try Chrono.date("el próximo domingo")      // and every language the OS ships
try Chrono.date("nächsten Sonntag")
```

It is safe to ask last because it is conservative to a fault — `chapter 7`,
`iPhone 15`, `version 3` and `100` all read as nothing, so junk never becomes a
confident date.

The two tiers are genuinely complementary rather than redundant. The detector
reads none of `+2w`, `3 days ago` or `90m`; the grammar reads none of
`this sunday` or `el próximo domingo`. Available separately as
``Chrono/detect(_:)`` if you want the second without the first.

**This is not a language model, and it should not be one.** The detector is
instant, offline, free, already on the device and maintained by Apple in every
language it ships. A trained model would be larger, slower, need data nobody
has, and be wrong in less predictable ways.

## Written out, or typed short

```swift
try Chrono.duration("3 days")        // and "two weeks", "a week", "six months"
try Chrono.date("two weeks from now")
try Chrono.date("in 3 days")
try Chrono.date("3 days ago")
```

Both spellings exist because people type the short one and speak the long one.
`3 days` used to be a *failure* rather than three days — it ends in "s", which
is the suffix for seconds, leaving "3 day" to parse as a number.

## Naming a zone

`Chrono.zone(_:)` takes a zone the way somebody writes one, not only as an IANA
identifier:

```swift
try Chrono.zone("PST")        // America/Los_Angeles
try Chrono.zone("AEST")       // Australia/Sydney — Foundation's table has no Australia
try Chrono.zone("ET")         // America/New_York, as written in half of American email
try Chrono.zone("Tokyo")      // Asia/Tokyo, matched on the city
try Chrono.zone("new york")   // America/New_York
try Chrono.zone("UTC+2")      // a fixed offset; "+05:30" and "GMT-5" too
```

The same names work on the end of a date, which is the point:

```swift
try Chrono.date("9:30 am PST")
try Chrono.date("tomorrow 9am Tokyo")
try Chrono.date("2026-09-03 14:30 Hong Kong")

Chrono.describe(try Chrono.date("9:30 am PST"), in: .current).time
```

An abbreviation resolves to a **region**, not a fixed offset, so it carries that
region's daylight saving:

```swift
try Chrono.date("2026-07-01 15:00 PST")   // 22:00Z — California is on PDT in July
try Chrono.date("2026-01-15 15:00 PST")   // 23:00Z — and PST in January
```

That is what somebody writing "3pm PST" in July means. Reading it as a literal
-8 would be an hour out for eight months of the year.

Abbreviations are genuinely ambiguous and nothing here pretends otherwise:
`IST` is India, not Ireland or Israel; `CST` is Chicago, not China; `MST` is
Phoenix, which never leaves standard time. Those are Foundation's mappings and
they are left alone — write the identifier or the city when it matters.

A bare `+2` is not a zone, because `+2` is already a relative date here.

## The zone is explicit, and it matters

```swift
Chrono.timeZone = TimeZone(identifier: "Asia/Tokyo")!
// or, scoped and restored:
try Chrono.inZone(.init(identifier: "Europe/London")!) { … }
```

`Chrono.calendar` is Gregorian with `firstWeekday = 2` and `minimumDaysInFirstWeek = 4`
— ISO 8601's rules. Deliberately **not** `Calendar.current`, which carries the user's
locale: the locale decides which day a week starts on, which decides what "this week"
means, which would make the same code give two answers on two machines.

## Two spellings of an offset, on purpose

```swift
try Chrono.duration("2w")       // 1_209_600 seconds — a window
try Chrono.offset("2w")         // (2, .week) — a calendar step
```

`duration` treats a month as a nominal 30 days, which is right for "roughly six months
out" and wrong for a boundary. `offset` hands the question to the calendar. `1mo` added
to 31 January is 2 March one way and 28 February the other; both spellings exist because
both questions get asked.

## What comes back

`Instant` describes one moment every way something downstream needs it — ISO, UTC,
epoch, date, time, zone, **the offset in force at that instant**, weekday, day of year,
ISO week *and its week year*, quarter, DST, weekend.

`Span` carries both a calendar breakdown (`1 year, 2 months, 5 days`) and the totals
(`432 days`, `10,368 hours`, `297 working days`). Neither can be derived from the
other, because months are not a fixed length.

## A run of days

```swift
try Chrono.range("last 30 days")            // thirty days ending today
try Chrono.range("this month")              // the 1st through the last day
try Chrono.range("q3 2026")                 // 2026-07-01 … 2026-09-30
try Chrono.range("2026-03-01 to 2026-03-05")
try Chrono.range("since monday")            // that day through today
try Chrono.range("ytd")                     // 1 January through today
```

Comes back as a `DateRange`: `start` and `end` at the start of their days, inclusive at
both ends, with `days`, `interval` (half-open, for queries) and `contains(_:)`. Every
report page on the web has a from/to pair; this reads the thought that fills it in.

The grammar: single days (anything `date` reads), whole units (`this week`, `last
month`, `next quarter`), counted windows (`last 30 days`, `past 2 weeks`, `previous 3
months`, `next 7 days`), to-date (`mtd`, `qtd`, `ytd`, `month to date`), named periods
(`september`, `sep 2026`, `2026-09`, `q3`, `2026`), and pairs joined by `to`, `until`,
`through`, `-`, `–`, `from … to` or `between … and`.

Two decisions worth knowing. Counted windows include today — `last 7 days` is a week
of days ending today, not the week before it. And months are shifted by the calendar,
so `last 3 months` from the 31st lands where a person expects rather than 90 days back.

## Working days

```swift
Chrono.isBusinessDay(date, holidays: list)
Chrono.businessDaysBetween(start, and: end, holidays: list)
try Chrono.shiftBusinessDays(date, by: 10, holidays: list)
try Chrono.holidays(fromLines: text.components(separatedBy: .newlines))
```

Counted by walking, not by `days / 7 * 5` — the closed form is right only when both
ends share a weekday offset. Holidays match by calendar **day**, not by instant, because
a list read from a file carries midnight and the date being tested rarely does. A line
that is not a date is refused rather than skipped: a typo silently moving a deadline is
worse than a failure.

## Parts of a day

```swift
Chrono.timeOfDay(date)                                   // .morning — by the clock, in Chrono.timeZone
Chrono.timeOfDay(date, boundaries: try .init(morning: 3, afternoon: 11, evening: 15, night: 19))
Chrono.describe(date).timeOfDay                          // the same answer, on the Instant

try Chrono.isDaytime(date)                               // 06:00 up to 20:00
Chrono.isTime(date, between: try ClockTime(hour: 22), and: try ClockTime(hour: 6))
                                                         // wraps through midnight
try Chrono.isEveryNthDay(date, from: anchor, every: 3)   // the 1st, the 4th, the 7th
```

Morning, afternoon, evening and night are decided by hour boundaries you can set,
not by the sun: a bakery's morning starts at three. They are read in
`Chrono.timeZone`, so one instant is morning in London and evening in Tokyo, which
is what a greeting needs. Sunrise is a different question — 03:43 in Reykjavik in
June, 11:30 in December — and it takes a solar calculation and a coordinate; this
package does not pretend to it.

A window is closed at the start and open at the end, so `22:00` to `06:00` holds
22:00 and 05:59 and not 06:00, and two windows that meet share no minute. When the
end is not after the start the window wraps through midnight, and when the two are
equal it is the whole day. Interval days are counted by the calendar: a week across
the clock change is still seven days, days before the anchor are never interval
days, and the anchor itself counts.

## Filling a template

```swift
Chrono.fill("https://api.example.com/orders?since={month_start_iso}&until={now_iso}")
// https://api.example.com/orders?since=2026-09-01T00:00:00Z&until=2026-09-03T14:30:00Z

Chrono.fill("{today} · week {week_number} · {quarter}")   // 2026-09-03 · week 36 · Q3
Chrono.fill("{ user { id name } }")                       // untouched — a GraphQL body is not a token
Chrono.value(of: "30d_ago_ms")                            // "1785853800000"
Chrono.tokens.count                                       // 124, each with a description and a true example
```

The tokens a request template carries, filled in from the calendar: `{today}`,
`{yesterday}`, `{tomorrow}` and their `_start`/`_end` seconds; `{week_start}` … `{year_end}`
and `{last_week_start}` … `{last_year_end}`, each in four spellings — Unix seconds, `_ms`,
`_iso` (RFC 3339, UTC) and `_date` (`yyyy-MM-dd`); exact durations `{1h_ago}` … `{365d_ago}`
with `_ms` and `_iso` twins; calendar shifts `{3_months_ago}`, `{6_months_ago}`, `{1_year_ago}`
and `{date_7d_ago}` … `{date_90d_ago}`; the components `{year}` `{month}` `{day}` `{hour}`
`{minute}` `{second}` `{month_name}` `{day_name}` `{week_number}` `{quarter}`; and `{timezone}`.
The catalogue is MetricBar's, name for name, so its templates keep working here.

Unknown braces are left exactly as written. Period tokens use `Chrono.calendar` — Gregorian,
ISO weeks, `Chrono.timeZone` — so `{week_start}` names the same Monday on every machine;
months and years shift by the calendar ("1 year ago" on 1 March 2025 is 1 March 2024, not
29 February); day offsets step by calendar day, so a clock change cannot move
`{date_7d_ago}` to the wrong date; and the `Nd_ago` tokens stay exact durations, because that
is what they say. Ends are the last second of their period, which is what an inclusive
`until=` wants.

## Fiscal years

```swift
Chrono.fiscalQuarter(date, fiscalYear: .unitedKingdom)   // Q1 2026/27: 6 April to 5 July
Chrono.fiscalQuarter(date, fiscalYear: .unitedStatesFederal).label
Chrono.fiscalYear(date, fiscalYear: try FiscalYear(startMonth: 7))   // Australia's, as a DateRange
Chrono.fiscalQuarter(date).number == Chrono.describe(date).quarter   // the calendar year, by default
```

A fiscal year starts on a month and a day; quarters are three calendar months from there.
The UK's runs from 6 April, so Q4 is 6 January to 5 April and **5 April belongs to the
previous year** — the mistake every spreadsheet makes once. Presets for the calendar year,
the UK, the US federal year, Australia and 1 April; the start day is capped at 28 so the
year can begin in every calendar year. The label reads `2026` when the year is the calendar
year and `2026/27` when it straddles two.

## Days until, and the next time a date comes round

```swift
Chrono.daysUntil(deadline)                          // 0 today, 1 tomorrow, -1 yesterday
try Chrono.nextOccurrence(month: 12, day: 25)       // this year's, or next year's if it has gone
try Chrono.nextOccurrence(month: 2, day: 29)        // 28 February in a common year
```

Days are counted between the starts of the two days, so 23:00 tonight to 01:00 tomorrow is
one day and a clock change does not make it zero. A countdown that has ended goes negative
rather than folding back to zero. Today counts as the next occurrence — a birthday today is
zero days away, not a year — and a 29 February birthday falls on the 28th in a common year,
which is the rule the `chrono age` verb has always used and is now the calendar's. Asking
Foundation for `2027-02-29` would hand back 1 March, a different day and the wrong one.

## In words

```swift
Chrono.relative(deadline)                       // "in 3 days", "2 hours ago", "now"
Chrono.relative(from: then, to: now)
Chrono.relativeSpan(from: now, to: then)        // count 3, unit .day, isPast false — for your own wording
```

English on purpose, never `RelativeDateTimeFormatter`: that is locale-driven and prints
"in 3 Tagen" on a German machine, which is fine for a person and wrong for a field an
agent parses. The steps are fixed — minutes to an hour, hours to a day, days to a week,
weeks to two months, months of thirty days to a year, then years — and under 45 seconds
either way is "now". Moved down from the `chrono` CLI so an app gets the same strings.

## How old

```swift
try Chrono.age(born: birthday)                  // years, months, days, days old, and the next birthday
try Chrono.age(born: birthday, on: someDate).described     // "36 years, 3 months, 20 days"
```

The breakdown is the calendar's, so 31 January to 28 February is a month and no days.
The next birthday comes from `nextOccurrence`, which puts a 29 February birthday on the
28th in a common year — the `chrono age` verb asked Foundation for the 29th and was
handed 1 March, which is the bug this replaces. A birth after the date is refused rather
than reported as a negative age, because it means the arguments were swapped.

## Working hours

```swift
let hours = BusinessHours.nineToFive                           // Monday to Friday, 09:00 to 17:00
try BusinessHours(days: [.saturday, .sunday], opens: try ClockTime(hour: 10), closes: try ClockTime(hour: 16), holidays: list)

Chrono.businessHours(from: fridayFour, to: mondayTen, hours: hours)   // 7,200 — two hours
Chrono.isOpen(date, hours: hours)
try Chrono.nextOpening(after: sundayNoon, hours: hours)               // Monday 09:00
try Chrono.addBusinessHours(8 * 3600, to: fridayFour, hours: hours)   // a deadline eight working hours out: Monday 16:00
```

Walked day by day: each working day contributes the overlap of its window, weekends and
holidays contribute nothing, and on the Sunday the clocks change the window is still
09:00 to 17:00 by the wall clock and still eight hours. A schedule is one window a day
and never across midnight — a shift from 22:00 to 06:00 belongs to two calendar days,
and which day's holiday it falls on has no single answer, so it is refused and a night
shift is two schedules. Weekdays are named, and numbered the ISO way underneath (Monday
is 1) so Foundation's Sunday-is-1 never leaks into a rule.

## Other calendars

```swift
Chrono.calendarDate(date, in: .islamicUmmAlQura)     // 1 Muharram 1447 AH
Chrono.calendarDate(date, in: .japanese).eraName     // "Reiwa", year 8
Chrono.calendarDate(date, in: .chinese).zodiacAnimal // "Horse"
try Chrono.date(from: CalendarDate(system: .hebrew, year: 5786, month: 1, day: 1))   // Rosh Hashanah
try Chrono.convert(CalendarDate(system: .gregorian, year: 2026, month: 3, day: 21), to: .persian)   // 1 Farvardin 1405
```

Ten calendars Foundation already counts in: Gregorian, Islamic (Umm al-Qura and civil,
which differ by a day), Hebrew, Japanese, Chinese, Buddhist, Persian, Coptic and Indian.
A date carries its era because in two of them it is the point — Reiwa 8, or year 43 of
cycle 78 — and leaving it out means the current one. Days are civil days from midnight
in `Chrono.timeZone`, which is what a printed calendar in that place shows; Nowruz is
21 March 2026 on Tehran's day. An impossible date is refused, not rolled over: Foundation
would quietly turn 31 Muharram into 1 Safar.

## Tested

125 tests (+38 in this branch), every one a question with a single right answer that multiplication gets
wrong: the February clamp in a common and a leap year, 23- and 25-hour days across both
London transitions, the order-dependence of `+1mo -1d`, week 53 of the year before,
Friday plus ten working days, the whole relative grammar, every handover hour of the day,
windows that cross midnight, a weekly interval across both clock changes, every one of the
124 template tokens against its example, 5 April belonging to the previous tax year, and
29 February landing on the 28th, the relative wording pinned string by string, a leap-day
birthday on the 28th, Friday four to Monday ten being two working hours, eight-hour days
across both clock changes, and the first of Muharram, Rosh Hashanah, Chinese New Year
and Nowruz on their published Gregorian days. Fixed dates and fixed
zones throughout — a suite that says "today" passes on the day it was written.

## Licence

MIT.
