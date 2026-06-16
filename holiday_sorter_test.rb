# frozen_string_literal: true

require 'test/unit'
require_relative './process'

# Tests HolidaySorter
class HolidaySorterTest < Test::Unit::TestCase
  def setup
    @sorter = HolidaySorter.new
    @sorter.push(2026, 'Pie Day', 'March 14', 'Saturday')
    @sorter.push(2026, 'Everything Day', 'April 2', 'Thursday')
  end

  def test_push
    assert_equal(
      [
        [2026, 'Pie Day', Time.new(2026, 3, 14, 12, 0, 0, '-10:00')],
        [2026, 'Everything Day', Time.new(2026, 4, 2, 12, 0, 0, '-10:00')]
      ],
      @sorter.holidays
    )
  end

  def test_over_years
    @sorter.push(2027, 'Pie Day', 'March 14', 'Sunday')
    assert_equal(
      [2027, 'Pie Day', Time.new(2027, 3, 14, 12, 0, 0, '-10:00')],
      @sorter.holidays.last
    )
  end

  def test_adjust_years
    @sorter.push(2028, "New Year's Day", 'December 31', 'Friday')
    assert_equal(
      [2028, "New Year's Day", Time.new(2027, 12, 31, 12, 0, 0, '-10:00')],
      @sorter.holidays.last
    )
  end

  def test_consistent_duplicate
    @sorter.push(2026, 'Pie Day', 'March 14', 'Saturday')
    assert_equal(
      [2026, 'Pie Day', Time.new(2026, 3, 14, 12, 0, 0, '-10:00')],
      @sorter.holidays.first
    )
  end

  def test_inconsistent_duplicate
    assert_raises(HolidaySorterError) do
      @sorter.push(2026, 'Pie Day', 'March 13', 'Friday')
    end
  end

  def test_inconsistent_day_of_week
    assert_raises(HolidaySorterError) do
      @sorter.push(2027, 'Pie Day', 'March 14', 'Wednesday')
    end
  end
end
