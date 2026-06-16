# frozen_string_literal: true

# Generates ics file for holidays listed in PDF files linked from a web page.
#
# Usage:
#
# 1. Run `bnudle install`
# 1. Run `bundle exec ruby process.rb https://dhrd.hawaii.gov/state-observed-holidays/ > holidays.ics`
# 1. Import `holidays.ics` to your calendar
#
require 'icalendar'
require 'nokogiri'
require 'open-uri'
require 'optparse'
require 'pdf-reader'
require 'time'
require 'uuidtools'

VERSION = '1.2'

class HolidaySorterError < StandardError; end

# Vefifies day of week and detects duplications
class HolidaySorter
  UTC_OFFSET = '-1000'

  def initialize
    @sorter = {}
    @holidays = nil
  end

  def push(calendar_year, holiday_name, month_day, day_of_week)
    date = matching_date(calendar_year, month_day, day_of_week)
    raise HolidaySorterError, "Day of week doesn't match with years around #{calendar_year}" unless date

    k = [calendar_year, holiday_name]
    if !@sorter[k]
      @sorter[k] = date
      @holidays = nil
    elsif @sorter[k] != date
      raise HolidaySorterError, "Duplicate #{holiday_name} for #{calendar_year} with inconsistent date"
    end
  end

  def holidays
    @holidays ||= @sorter.to_a.map { |k, date| [*k, date] }
  end

  def matching_date(calendar_year, month_day, day_of_week)
    date = nil
    [calendar_year, calendar_year - 1, calendar_year + 1].each do |y|
      d = Time.parse("#{month_day}, #{y} 12:00:00 #{UTC_OFFSET}")
      if day_of_week == d.localtime.strftime('%A')
        date = d
        break
      end
    end
    date
  end

  private :matching_date
end

if __FILE__ == $PROGRAM_NAME
  read_local = false
  opts = OptionParser.new
  opts.banner = <<~_
    Usage: #{$PROGRAM_NAME} [options] URL
    Reades holidays listed in PDF files linked from URL.
  _
  opts.on('-l', '--local', 'Reads local PDF files instead of a URL') do
    read_local = true
  end
  opts.on_tail('--version', 'Show version') do
    puts VERSION
    exit
  end
  opts.parse!(ARGV)

  if read_local
    base_url = 'file:/'.dup
    pdf_urls = ARGV
  else
    base_url = ARGV.shift.dup
    pdf_urls = Nokogiri::HTML(URI.parse(base_url).open)
                       .xpath('//a/@href')
                       .map(&:value)
                       .select { |url| url =~ /\.pdf\z/i }
                       .uniq
  end
  base_url += '/' unless base_url.end_with?('/')

  sorter = HolidaySorter.new
  years = []
  pdf_urls.each do |url|
    year = nil
    src = read_local ? url : URI.parse(url).open
    PDF::Reader.new(src).pages.each do |page|
      page.text.each_line do |line|
        if (x = line.match(/\s+(?<year>\d{4,4})\s+HAWAIʻI STATE HOLIDAYS/i))
          year = Integer(x['year'])
          years << year
        elsif (x = line.match(/\s*(?<name>.*?)\s+(?<day>\w+\s+\d{1,2}),\s*(?<dow>\w+)/))
          raise "Didn't receive year before seeing a holiday: #{line.strip.inspect} in #{url}" unless year

          begin
            sorter.push(year, x['name'], x['day'], x['dow'])
          rescue HolidaySorterError => e
            raise "#{e.message}: #{line.strip.inspect} in #{url}"
          end
        end
      end
    end
  end
  years.uniq!

  sorter.holidays.each do |_year, name, date|
    warn "#{date.localtime.strftime('%Y-%m-%d %a')}: #{name}"
  end
  warn "Found #{sorter.holidays.size} holidays over calendar years #{years.join(', ')}."

  cal = Icalendar::Calendar.new
  sorter.holidays.each do |year, name, date|
    cal.event do |e|
      ymd = date.localtime.strftime('%Y%m%d')
      url = "#{base_url}\##{year}/#{name}"
      e.uid = UUIDTools::UUID.sha1_create(UUIDTools::UUID_URL_NAMESPACE, url).to_s
      e.dtstart = Icalendar::Values::Date.new(ymd)
      e.dtend   = Icalendar::Values::Date.new(ymd)
      e.summary = name
      e.transp  = 'TRANSPARENT'
    end
  end

  puts cal.to_ical
end
