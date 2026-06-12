# Prints holidays listed in PDF files linked from a web page. Usage:
#
# 1. Run `bnudle install`
# 1. Run `bundle exec ruby process.rb https://dhrd.hawaii.gov/state-observed-holidays/`
#
require "nokogiri"
require "open-uri"
require "pdf-reader"
require "time"

utc_offset = "-1000"

base_url = ARGV.shift
pdf_urls = Nokogiri::HTML(URI.open(base_url))
  .xpath("//a/@href")
  .map{|href| href.value}
  .select{|url| url =~ /\.pdf\z/i)}
  .uniq

sorter = Hash.new{|h, k| h[k] = Array.new}
pdf_urls.each do |url|
  year = nil
  PDF::Reader.new(URI.open(url)).pages.each do |page|
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
