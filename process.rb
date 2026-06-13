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

utc_offset = '-1000'
VERSION = '1.1'

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

sorter = Hash.new { |h, k| h[k] = [] }
pdf_urls.each do |url|
  year = nil
  src = read_local ? url : URI.parse(url).open
  PDF::Reader.new(src).pages.each do |page|
    page.text.each_line do |line|
      if (x = line.match(/\s+(?<year>\d{4,4})\s+HAWAIʻI STATE HOLIDAYS/i))
        year = Integer(x['year'])
      elsif (x = line.match(/\s*(?<name>.*?)\s+(?<day>\w+\s+\d{1,2}),\s*(?<dow>\w+)/))
        raise "Didn't receive year before seeing a holiday: #{line.strip.inspect} in #{url}" unless year

        date = nil
        [year, year - 1, year + 1].each do |y|
          d = Time.parse("#{x['day']}, #{y} 12:00:00 #{utc_offset}")
          dow = d.localtime.strftime('%A')
          if dow == x['dow']
            date = d
            break
          end
        end
        raise "Day of week doesn't match for years around #{year}: #{line.strip.inspect} in #{url}" unless date

        sorter[date] << [x['name'], year]
      end
    end
  end
end

holidays = []
sorter.keys.sort.each do |date|
  sorter[date].uniq.each do |name, year|
    holidays << [date, name, year]
  end
end

holidays.each do |date, name, _year|
  warn "#{date.localtime.strftime('%Y-%m-%d %a')}: #{name}"
end

cal = Icalendar::Calendar.new
holidays.each do |date, name, year|
  cal.event do |e|
    ymd = date.localtime.strftime('%Y%m%d')
    url = "#{base_url}\##{year}/#{name}"
    e.uid = UUIDTools::UUID.sha1_create(UUIDTools::UUID_URL_NAMESPACE, url).to_s
    e.dtstart = Icalendar::Values::Date.new(ymd)
    e.dtend   = Icalendar::Values::Date.new(ymd)
    e.summary = name
  end
end

puts cal.to_ical
