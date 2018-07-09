#!/usr/bin/env ruby

#                           PRODUCT DATA
# ================================================================

# "product_database" holds all the data for the products we sell.
# It will have the following structure:
# 
# $product_database = {
# 	"VOUCHER"=>{"Name"=>"Cabify Voucher"   ,"Price"=> 5.00},
# 	"TSHIRT" =>{"Name"=>"Cabify T-Shirt"   ,"Price"=>20.00},
# 	"MUG"    =>{"Name"=>"Cabify Coffee Mug","Price"=> 7.50},
# }
# 
# but instead of hard-coding it, we read from csv to make it easier to use.
# 
# (NOTE: "product_database" is needed for Checkout. I declared it as a
# global variable, while passing "pricing_rules" as an argument. I did so
# to meet the specifications for the API as requested in the excercise,
# but I would have passed both as an argument.)

require "csv"
$product_database = Hash.new 
pricing_rules = Hash.new 

options =  {
	headers: true,
	converters: [:numeric, lambda {|s| s.strip}],
	header_converters: [lambda {|s| s.strip}]
}

CSV.foreach("product_data.csv",options) do |row|
	product = row.to_h
	$product_database[product["ID"]] = product.select {|k,v| ["Name", "Price"].include?(k)}
	pricing_rules[product["ID"]] = product["Discount"]
end

#                            DISCOUNTS 
# ================================================================

# These are the different kinds of discounts we can make.
# Every dicount has a *final_quantity* method which computes
# the amount of (maybe fractional) "items"  that should be paid 
# for a given quantity of items scanned

# "None" is the null discount: don't make a discount

class None
	def initialize
	end
	def final_quantity(quantity)
		quantity
	end	
end

# "Bulk" discount makes a given percentage discount
# after a given threshold quantity

class Bulk
	def initialize(threshold, discount)
		@threshold = threshold
		@discount  = discount
	end
	def final_quantity(quantity)
		quantity * ((quantity < @threshold) ? 1 : ( 1 - @discount / 100.0 ))
	end
end

# "NxM" discount charges only M products for each N products bought

class NxM 
	def initialize(n,m)
		@n = n
		@m = m
	end
	def final_quantity(quantity)
		(@m * (quantity / @n) + ((quantity % @n < @m) ? quantity % @n : @m))
	end	
end

#                            PRICING RULES
# ========================================================================

# With all discount classes in place, we can implement the pricing rules 
# of the example. A pricing rules object is a Hash which maps product IDs
# to discount objects.
# 
# The data necessary to build the corresponding
# discount objects has already been loaded from the .csv.
# 
# It will have the following contents:
# {
# 	"VOUCHER" => NxM.new(2, 1),   # a 2x1 discount on VOUCHER
# 	"TSHIRT"  => Bulk.new(3, 5),  # a 5%  discount on TSHIRT if you buy 3 or more
# 	"MUG"     => None.new,        # we don't make discounts on mugs
# }

pricing_rules.each do |(id, rule)|
	type, *args = rule ? rule.split : ["None"]
	pricing_rules[id] = eval(type).new(* args.map {|e| eval e})
end 

#                             CHECKOUT
# ========================================================================

# The "Checkout" class lets you scan products one by one with the "scan" method
# At any point, you can compute the total to be paid with the "total" method.
# It also allows you to get a receipt with the "receipt" method.
# "product_count" and "money_per_product" are methods which
# count the number of items in each category and
# the total amount of money to be paid for each category, respectively


class Checkout
	def initialize(pricing_rules)
		@pricing_rules = pricing_rules
		@products = []
	end
	def scan(product)
		@products << product
	end
	def product_count
		@products.each_with_object(Hash.new(0)) {|e, h| h[e] += 1}
	end
	def money_per_product
		Hash[ product_count.map do |(id, count)|
			[id, $product_database[id]["Price"] * @pricing_rules[id].final_quantity(count)]
		end]
	end
	def total
		money_per_product.values.reduce(:+)
	end
	def receipt
		w = [25, 15, 15] # Column widths
		separator = " | "
		head = ["Product".center(w[0]),  "Unitary Price".center(w[1]) , "Total Price".center(w[2]) ].join(separator)
		hline = "-" * (w.reduce(:+) + separator.size * 2)
		body = product_count.map do |(id,count)|
			[	"#{$product_database[id]["Name"]} x#{count}".ljust(w[0]),
				"#{'%.2f' % $product_database[id]["Price"]} €".rjust(w[1]),
				"#{'%.2f' % money_per_product[id]} €".rjust(w[2]),
			].join(separator)
		end 
		foot = ["Total:".ljust(w[0] + w[1] + separator.size), "#{'%.2f' % total} €".rjust(w[2]) ].join(separator)
		[head, hline, *body, hline, foot].join("\n")
	end
end

#                               TEST
# ========================================================================

if __FILE__ == $0
	# First, we test that all example tests pass
	def test(pricing_rules, products, expected_price)
		products
			.split
			.each_with_object(Checkout.new(pricing_rules)) {|e, co| co.scan e}
			.total == expected_price
	end

	puts ({
		"VOUCHER TSHIRT MUG"=>32.50,
		"VOUCHER TSHIRT VOUCHER"=>25.00,
		"TSHIRT TSHIRT TSHIRT VOUCHER TSHIRT"=>81.00,
		"VOUCHER TSHIRT VOUCHER VOUCHER MUG TSHIRT TSHIRT"=>74.50
	}).map {|arr, price| test(pricing_rules, arr, price) }.all? ? "all tests passed!" : "something failed"

	# Now, a little demo
	puts "Here is an example receipt:"

	co = Checkout.new(pricing_rules)
	co.scan("VOUCHER")
	co.scan("TSHIRT")
	co.scan("VOUCHER")
	co.scan("VOUCHER")
	co.scan("MUG")
	co.scan("TSHIRT")
	co.scan("TSHIRT")
	co.scan("MUG")
	puts co.receipt
end