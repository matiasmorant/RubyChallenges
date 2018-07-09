# File: app.rb
require 'test/unit'
require 'test/unit/testsuite'

# WRITE YOUR CLASSES HERE

# +Normalizer+ is the ancestor of every object used to normalize strings 
class Normalizer
  # Receives a string as input and normalizes it
  # Params:
  # * +s+ - The +String+ object to normalize
  def normalize (s)
    matched_data = @regexp.match(s)
    matched_data ? format_h(matched_data) : {}
  end
  # Takes a +MatchedData+ object and returns a +Hash+ with
  # inheriting class name as key
  # a normalized +String+ as value
  # Params:
  # * +matched_data+ - a +MatchedData+ object
  def format_h(matched_data)
    matched_data[self.class.name] ? {self.class.name => format_s(matched_data)} : {}
  end
  # Takes a +MatchedData+ object and returns a normalized +String+
  # Params:
  # * +matched_data+ - a +MatchedData+ object  
  def format_s(matched_data)
  end
  attr_reader :regexp
end

# A +Combinator+ is used to combine Normalizers. It is a +Normalizer+ itself
class Combinator < Normalizer
  def initialize (normalizers, op)
    @normalizers = normalizers
    @regexp = Regexp.new(normalizers.map { |n| n.regexp.source } .join op)
  end
  def simplify (matched_data)
    @normalizers.map { |n| n.format_h(matched_data)} .reduce({}, :merge)
  end
end

class And < Combinator
  def initialize (normalizers)
    super(normalizers, '')
  end
end

class Or < Combinator
  def initialize (normalizers)
    super(normalizers, '|')
  end
end

class Literal < Normalizer
  def initialize (regexp)
    @regexp = regexp
  end
  def format_h (matched_data)
    {}
  end
end

class Word < Normalizer
  def initialize
    @regexp = Regexp.new("(?<#{self.class.name}>\\p{Alpha}+)")
  end
  def format_s (matched_data)
    matched_data[self.class.name]
  end
end

class FirstName < Word
end

class LastName < Word
end

class Date < Normalizer
  def initialize
    @regexp = %r{(?<Date>(?<Month>\d{1,2})[/-](?<Day>\d{1,2})[/-](?<Year>\d{4}))}
  end
  def format_s (matched_data)
    "#{matched_data["Month"]}/#{matched_data["Day"]}/#{matched_data["Year"]}"
  end
end

class City < Normalizer
  def initialize
    @regexp = %r{(?<City>\p{Alpha}[\p{Alpha} ]*\p{Alpha})}
  end
  def format_s (matched_data)
    { 'LA'  =>'Los Angeles',
      'NYC' =>'New York City',
    }[matched_data["City"]] || matched_data["City"]
  end
end

class Comma < And
  def initialize
    super([
      Literal.new(%r{^}),
      FirstName.new,
      Literal.new(%r{, *}),
      City.new,
      Literal.new(%r{, *}),
      Date.new,
      Literal.new(%r{$}),
    ])
    @regexp = Regexp.new("(?<Comma>#{@regexp.source})")
  end
  def format_s (matched_data)
    parts = simplify(matched_data)
    "#{parts["FirstName"]} #{parts["City"]} #{parts["Date"]}"
  end
end

class Dollar < And
  def initialize
    super([
      Literal.new(%r{^}),
      City.new,
      Literal.new(%r{ *\$ *}),
      Date.new,
      Literal.new(%r{ *\$ *}),
      LastName.new,
      Literal.new(%r{ *\$ *}),
      FirstName.new,
      Literal.new(%r{$}),
    ])
    @regexp = Regexp.new("(?<Dollar>#{@regexp.source})")
  end
  def format_s (matched_data)
    parts = simplify(matched_data)
    "#{parts["FirstName"]} #{parts["City"]} #{parts["Date"]}"
  end
end

class General < Or
  def initialize
    super([Dollar.new, Comma.new])
  end
  def format_h (matched_data)
    simplify(matched_data)
  end  
end

class PeopleController
  def self.normalize(request_params)
    # FIXME
    inputs = request_params.values.flatten
    inputs .map {|i| General .new .normalize(i).values[0] }
  end
end

# PeopleController.normalize({
#   comma: [ # Fields: first name, city name, birth date
#     'Mckayla, Atlanta, 5/29/1986',
#     'Elliot, New York City, 4/3/1947',
#   ],
#   dollar: [ # Fields: city abbreviation, birth date, last name, first name
#     'LA $ 10-4-1974 $ Nolan $ Rhiannon',
#     'NYC $ 12-1-1962 $ Bruen $ Rigoberto',
#   ],
# })

# # Expected return (order of entries doesn't matter):
# # [
# # 'Mckayla Atlanta 5/29/1986',
# # 'Elliot New York City 4/3/1947',
# # 'Rhiannon Los Angeles 10/4/1974',
# # 'Rigoberto New York City 12/1/1962',
# # ]


# # WRITE YOUR SPECS HERE

class TestDollar < Test::Unit::TestCase
  def test_match_length
    assert_equal(0, Dollar.new .normalize('Mckayla, Atlanta, 5/29/1986').length)
    assert_equal(0, Dollar.new .normalize('Elliot, New York City, 4/3/1947').length)
    assert_equal(1, Dollar.new .normalize('LA $ 10-4-1974 $ Nolan $ Rhiannon').length)
    assert_equal(1, Dollar.new .normalize('NYC $ 12-1-1962 $ Bruen $ Rigoberto').length)
  end
  def test_output
    assert_equal('Rhiannon Los Angeles 10/4/1974'   , Dollar.new .normalize('LA $ 10-4-1974 $ Nolan $ Rhiannon')["Dollar"])
    assert_equal('Rigoberto New York City 12/1/1962', Dollar.new .normalize('NYC $ 12-1-1962 $ Bruen $ Rigoberto')["Dollar"])
  end
end

class TestComma < Test::Unit::TestCase
  def test_match_length
    assert_equal(1, Comma.new .normalize('Mckayla, Atlanta, 5/29/1986').length)
    assert_equal(1, Comma.new .normalize('Elliot, New York City, 4/3/1947').length)
    assert_equal(0, Comma.new .normalize('LA $ 10-4-1974 $ Nolan $ Rhiannon').length)
    assert_equal(0, Comma.new .normalize('NYC $ 12-1-1962 $ Bruen $ Rigoberto').length)
  end
  def test_output
    assert_equal('Mckayla Atlanta 5/29/1986'        , Comma.new .normalize('Mckayla, Atlanta, 5/29/1986')["Comma"])
    assert_equal('Elliot New York City 4/3/1947'    , Comma.new .normalize('Elliot, New York City, 4/3/1947')["Comma"])
  end
end

class TestGeneral < Test::Unit::TestCase
  def test_match_length
    assert_equal(1, General.new .normalize('Mckayla, Atlanta, 5/29/1986').length)
    assert_equal(1, General.new .normalize('Elliot, New York City, 4/3/1947').length)
    assert_equal(1, General.new .normalize('LA $ 10-4-1974 $ Nolan $ Rhiannon').length)
    assert_equal(1, General.new .normalize('NYC $ 12-1-1962 $ Bruen $ Rigoberto').length)
  end
  def test_output
    assert_equal('Mckayla Atlanta 5/29/1986'        , General.new .normalize('Mckayla, Atlanta, 5/29/1986')["Comma"])
    assert_equal('Elliot New York City 4/3/1947'    , General.new .normalize('Elliot, New York City, 4/3/1947')["Comma"])
    assert_equal('Rhiannon Los Angeles 10/4/1974'   , General.new .normalize('LA $ 10-4-1974 $ Nolan $ Rhiannon')["Dollar"])
    assert_equal('Rigoberto New York City 12/1/1962', General.new .normalize('NYC $ 12-1-1962 $ Bruen $ Rigoberto')["Dollar"])
  end
end

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

class AllTests
  def self.suite
    suite = Test::Unit::TestSuite.new
    suite << TestDollar.suite
    suite << TestComma.suite
    suite << TestGeneral.suite
    suite << TestPeopleController.suite
    return suite
  end
end