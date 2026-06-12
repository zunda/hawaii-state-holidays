# Prints holidays listed in the PDF files. Usage:
#
# 1. Run `bnudle install`
# 1. Download PDF files from https://dhrd.hawaii.gov/state-observed-holidays/
# 1. Run `bundle exec ruby process.rb *.pdf`
#
require "pdf-reader"
require "time"

utc_offset = "-1000"
sorter = Hash.new{|h, k| h[k] = Array.new}
ARGV.each do |path|
  year = nil
  PDF::Reader.new(path).pages.each do |page|
    page.text.each_line do |line|
      if x = line.match(/\s+(?<year>\d{4,4})\s+HAWAIʻI STATE HOLIDAYS/i)
        year = x["year"]
      elsif x = line.match(/\s*(?<name>.*?)\s+(?<day>\w+\s+\d{1,2}),\s*\w+/)
        unless year
          raise "Didn't receive year before seeing a holiday: #{line.strip.inspect} in #{path}"
        end
        date = Time.parse("#{x["day"]}, #{year} 00:00:00 #{utc_offset}")
        sorter[date] << x["name"]
      end
    end
  end
end

holidays = Array.new
sorter.keys.sort.each do |date|
  sorter[date].uniq.each do |name|
    holidays << [date, name]
  end
end

require "pp"
pp holidays
