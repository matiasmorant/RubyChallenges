require 'test/unit'
require 'test/unit/testsuite'
require 'date'

# A +Normalizer+ is used for normalizing inputs.
# To implement a custom +Normalizer+, you have to subclass it.
# See the implemented Normalizers for examples.
# 
# A +Normalizer+ must:
#   * either have an +@input_format+ member or override the +Normalizer#parse+ method
#      AND
#   * either have an +@output_format+ member or override the +Normalizer#assemble+ method
#      OR
#   * instead of any of the above, override the +Normalizer#normalize+ method
# 
# An +@input_format+ can be either:
#   * A regular expression
#   * A list of regular expressions (all will be considered to be valid input formats)
#   * A Date format string
# 
# An +@output_format+ can be either:
#   * A format string
#   * A Date format string

class Normalizer
    # The +Normalizer#parse+ method receives a string 
    # and returns the result of the first valid +input_format+ match
    def self.parse (s)
    [@input_format]
      .flatten
      .map  { |f| Date.strptime(s, f) rescue f.match(s) }
      .compact
      .first || raise("#{s} is not a valid #{self}")
  end
  # The +Normalizer#assemble+ method receives the results of the +Normalizer#parse+ method.
  # It returns the string resulting from formatting its argument with +@output_format+
  def self.assemble (fields)
    if fields.class == MatchData
      @output_format % fields
        .named_captures
        .map {|name, string| [name.to_sym, Kernel.const_get(name).normalize(string.strip)] }
        .to_h
    else 
      fields.strftime(@output_format)
    end
  end
  # +Normalizer#normalize+ receives a string and returns a string
  # It is (by default) just the composition of +Normalizer#parse+ and +Normalizer#assemble+.
  def self.normalize(s)
    assemble(parse(s))
  end
end

class FirstNameField < Normalizer
  @input_format = /^\p{Alpha}+$/
  def self.assemble (fields)
    fields[0]
  end
end

class LastNameField < Normalizer
  @input_format = /^\p{Alpha}+$/
  def self.assemble (fields)
    fields[0]
  end
end

class CityField < Normalizer
  @input_format = /^\p{Alpha}+[ +\p{Alpha}+]*$/
  def self.assemble (fields)
    { 'LA'  =>'Los Angeles',
      'NYC' =>'New York City',
    }[fields[0]] || fields[0]
  end
end

class DateField < Normalizer
  @input_format = ["%m-%d-%Y", "%m/%d/%Y"]
  @output_format = "%-m/%-d/%Y"
end

class GeneralInput < Normalizer
  @input_format = [
      /(?<FirstNameField>.+),(?<CityField>.+),(?<DateField>.+)/x,
      /(?<CityField>.+)\$(?<DateField>.+)\$(?<LastNameField>.+)\$(?<FirstNameField>.+)/x]
  @output_format = "%{FirstNameField} %{CityField} %{DateField}"
end

class PeopleController
  def self.normalize(request_params)
    # FIXME
    request_params
      .values
      .flatten
      .map {|s| GeneralInput .normalize s }
  end
end 

# WRITE YOUR SPECS HERE

class TestPeopleController < Test::Unit::TestCase
  def test_output
    assert_equal(
      [
      'Mckayla Atlanta 5/29/1986',
      'Elliot New York City 4/3/1947',
      'Rhiannon Los Angeles 10/4/1974',
      'Rigoberto New York City 12/1/1962',
      ],
      PeopleController.normalize({
        comma: [ # Fields: first name, city name, birth date
          'Mckayla, Atlanta, 5/29/1986',
          'Elliot, New York City, 4/3/1947',
        ],
        dollar: [ # Fields: city abbreviation, birth date, last name, first name
          'LA $ 10-4-1974 $ Nolan $ Rhiannon',
          'NYC $ 12-1-1962 $ Bruen $ Rigoberto',
        ],
      })
    )
  end
end

class TestErrors < Test::Unit::TestCase
  def test_general_input_error
    exception = assert_raise(RuntimeError) {GeneralInput.normalize 'Mckayla - Atlanta - 5/29/1986'}
    assert_equal("Mckayla - Atlanta - 5/29/1986 is not a valid GeneralInput", exception.message)
  end
  def test_date_field_error
    exception = assert_raise(RuntimeError) {GeneralInput.normalize 'Mckayla , Atlanta , 5 $ 29 $ 1986'}
    assert_equal("5 $ 29 $ 1986 is not a valid DateField", exception.message)
  end
  def test_city_name_error
    exception = assert_raise(RuntimeError) {GeneralInput.normalize 'Mckayla , @3<)6& , 5 $ 29 $ 1986'}
    assert_equal("@3<)6& is not a valid CityField", exception.message)
  end    
end

class AllTests
  def self.suite
    suite = Test::Unit::TestSuite.new
    suite << TestPeopleController.suite
    suite << TestErrors.suite
    return suite
  end
end