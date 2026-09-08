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

## Tested

32 tests, every one a question with a single right answer that multiplication gets
wrong: the February clamp in a common and a leap year, 23- and 25-hour days across both
London transitions, the order-dependence of `+1mo -1d`, week 53 of the year before,
Friday plus ten working days, and the whole relative grammar. Fixed dates and fixed
zones throughout — a suite that says "today" passes on the day it was written.

## Licence

MIT.
