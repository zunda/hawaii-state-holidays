# hawaii-state-holidays
Generates ics file for holidays listed in PDF files linked from a web page.

## Usage

1. Run `bnudle install`
1. Run `bundle exec ruby process.rb https://dhrd.hawaii.gov/state-observed-holidays/ > holidays.ics`
1. Import `holidays.ics` to your calendar

## Changelog
### v1.1 2026-06-12
Use calendar year instead of actual date for unique ID

When re-importing ics file generated from previous releases, please at first delete the holidays. This makes the output more resilient to date changes of a holiday in a calendar year. The change in unique ID will result with duplicate entries for a holiday on your calendar.

### v1.0 2026-06-12
Initial release
