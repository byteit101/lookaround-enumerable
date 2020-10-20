=begin
Copyright 2020 Patrick Plenefisch <simonpatp@gmail.com>

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
=end



RSpec.describe "Lookaround pre-refinement" do
	it "doesn't have each_with_prev" do
		expect { [].each_with_prev }.to raise_error(NoMethodError)
	end
	it "doesn't have n_select" do
		expect { [].n_select }.to raise_error(NoMethodError)
	end
	it "doesn't have n_map" do
		expect { [].n_map }.to raise_error(NoMethodError)
	end
end

using LookaroundEnum

RSpec.describe "Lookaround Enum" do
  it "has a version number" do
    expect(LookaroundEnum::VERSION).not_to be nil
  end

  it "pushes 1, using enumerable" do
  	answers = []
  	(1..3).each_with_prev(1) do |elt, prev|
  		answers << [elt, prev]
  	end
    expect(answers).to eq([[1,nil], [2, 1], [3, 2]])
  end
  
  it "pushes 2, using enumerator" do
  	answers = []
  	(1..3).each.each_with_prev(2) do |elt, (prev, prev_2)|
  		answers << [elt, prev, prev_2]
  	end
    expect(answers).to eq([[1,nil, nil], [2, 1, nil], [3, 2, 1]])
  end
  it "pushes 4, using enumerator" do
  	answers = []
  	(1..3).each.each_with_prev(4) do |elt, prevs|
  		answers << [elt, *prevs]
  	end
    expect(answers).to eq([[1,nil, nil, nil, nil], [2, 1, nil, nil, nil], [3, 2, 1, nil, nil]])
  end
  it "pushes 1, using enumerator joined" do
  	answers = []
  	(1..3).each_with_index.each_with_prev(1) do |(elt, i), (prev, prev_i)|
  		answers << [elt, i, prev, prev_i]
  	end
    expect(answers).to eq([[1,0, nil, nil], [2, 1, 1, 0], [3, 2, 2, 1]])
  end
  it "pushes 1, using enumerator joined, unpack" do
  	answers = []
  	(1..3).each_with_index.each_with_prev(1, expand: :all) do |elt, i, (prev, prev_i)|
  		answers << [elt, i, prev, prev_i]
  	end
    expect(answers).to eq([[1,0, nil, nil], [2, 1, 1, 0], [3, 2, 2, 1]])
  end
  it "pushes 1, using enumerator joined, option first" do
  	answers = []
  	(4..6).each_with_index.each_with_prev(1, trim: true) do |(elt, i), prev|
  		answers << [elt, i, prev]
  	end
    expect(answers).to eq([[4,0, nil], [5, 1, 4], [6, 2, 5]])
  end
  
  it "pushes 1, using enumerator joined, option first, unpack" do
  	answers = []
  	(4..6).each_with_index.each_with_prev(1, trim: true, expand: :all) do |elt, i, prev|
  		answers << [elt, i, prev]
  	end
    expect(answers).to eq([[4,0, nil], [5, 1, 4], [6, 2, 5]])
  end
  
  it "pushes 1, using enumerator joined, option first, grouped" do
  	answers = []
  	(4..6).each_with_index.each_with_prev(1, trim: true) do |(elt, i), prev|
  		answers << [elt, i, prev]
  	end
    expect(answers).to eq([[4,0, nil], [5, 1, 4], [6, 2, 5]])
  end
  
  it "pushes 2, using enumerable, skipping nils" do
  	answers = []
  	(1..6).each_with_prev(2, crop: true) do |elt, (prev, prev_2)|
  		answers << [elt, prev, prev_2]
  	end
    expect(answers).to eq([[3,2,1], [4,3,2], [5,4,3], [6,5,4]])
  end
  
  it "pushes 1, using enumerable, different replacement" do
  	answers = []
  	(1..3).each_with_prev(2, filler: :empty) do |elt, (prev, prev_2)|
  		answers << [elt, prev, prev_2]
  	end
    expect(answers).to eq([[1,:empty, :empty], [2, 1, :empty], [3, 2, 1]])
  end
  
  
  it "enumerator joined, pushes 1" do
  	answers = []

  	(1..3).each_with_prev(1).each_with_index do |(elt, prev), i|
  		answers << [elt, i, prev]
  	end
    expect(answers).to eq([[1,0, nil], [2, 1, 1], [3, 2, 2]])
  end
  
  
  
  it "enumerator joined, pushes 1, be faster than constructing an array" do
  	# measure each_with_prev (cached & fast)
	starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  	expect((1..1_000_000_000).each_with_prev(1).size).to eq(1_000_000_000)
    ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    correct_time = ending - starting
    
    # measure slow to_a as relative (after fast to avoid JIT'ing the fast)
    starting = ending
  	expect((1..2_000_000).to_a.size).to eq(2_000_000)
    ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    slow_time = ending - starting
    #puts "correct #{correct_time}"
    #puts "slow    #{slow_time}"
    
    # be orders of magnitude faster (typically 5000, so go with only 100, 2 orders of magnitude, to be safe in tests)
    expect(correct_time * 100).to be < slow_time
  end
  
  it "has working doc examples" do
  
	expect((1..3).each_with_prev(1).to_a).to eq([[1, nil], [2, 1], [3, 2]])
	expect((1..3).each_with_prev(2).to_a).to eq([[1, [nil, nil]], [2, [1, nil]], [3, [2, 1]]])
	
	expect((1..3).each_with_prev(1, crop: false).to_a).to eq( [[1, nil], [2, 1], [3, 2]])
	expect((1..3).each_with_prev(1, crop: true).to_a).to eq( [[2, 1], [3, 2]])
	
	expect((1..3).each_with_object({}).each_with_prev(1, trim: false, expand: :all).to_a).to eq( [[1, {}, nil], [2, {}, [1, {}]], [3, {}, [2, {}]]])
	expect((1..3).each_with_object({}).each_with_prev(1, trim: true, expand: :all).to_a).to eq([[1, {}, nil], [2, {}, 1], [3, {}, 2]])
	
	expect((1..3).each_with_prev(1, filler: nil).to_a).to eq([[1, nil], [2, 1], [3, 2]])
	expect((1..3).each_with_prev(1, filler: 0).to_a).to eq( [[1, 0], [2, 1], [3, 2]])
	
  end
  
end


RSpec.describe "Lookaround Enum (windowing)" do


  it "windows -1..1, using enumerable" do
  	answers = []
  	('a'..'e').each_with_window(-1..1) do |left, elt, right|
  		answers << [left, elt, right]
  	end
    expect(answers).to eq([[nil, "a", "b"], ["a", "b", "c"], ["b", "c", "d"], ["c", "d", "e"], ["d", "e", nil]])
  end

  it "windows 0..1, using enumerable" do
  	answers = []
  	('a'..'e').each_with_window(0..1) do |elt, right, na|
  		answers << [elt, right, na]
  	end
    expect(answers).to eq([["a", "b", nil], ["b", "c", nil], ["c", "d", nil], ["d", "e", nil], ["e", nil, nil]])
  end
  
  it "windows -2..1, using enumerable" do
  	answers = []
  	('a'..'e').each_with_window(-2..1) do |(l1, left), elt, (right)|
  		answers << [l1, left, elt, right]
  	end
    expect(answers).to eq([[nil, nil, "a", "b"], [nil, "a", "b", "c"], ["a", "b", "c", "d"], ["b", "c", "d", "e"], ["c", "d", "e", nil]])
  end
  
  it "windows -1..2, using enumerable" do
  	answers = []
  	('a'..'e').each_with_window(-1..2, filler: "x") do |(left), elt, (right, r1)|
  		answers << [left, elt, right, r1].join("")
  	end
    expect(answers).to eq(["xabc", "abcd", "bcde", "cdex", "dexx"])
  end
  
  it "windows -1..2, using enumerable, indexed" do
  	answers = []
  	('a'..'e').each_with_index.each_with_window(-1..2, filler: ["x", -1]) do |((left, li)), (elt, ei), ((right, ri), (r1, ri1))|
  		answers << [left, elt, right, r1, li, ei, ri, ri1].join
  	end
    expect(answers).to eq(["xabc-1012", "abcd0123", "bcde1234", "cdex234-1", "dexx34-1-1"])
  end
  
  
  it "has sane to_a" do
  	expect(('a'..'d').each_with_window(-2..1).to_a).to eq([[[nil, nil], "a", ["b"]], [[nil, "a"], "b", ["c"]], [["a", "b"], "c", ["d"]], [["b", "c"], "d", [nil]]])
  end
  
	it "windows invalid args" do
		expect { [].each_with_window(-10..-5) }.to raise_error(ArgumentError)
		expect { [].each_with_window(5..10) }.to raise_error(ArgumentError)
	end
end

RSpec.describe "Lookaround helpers" do
	it "should have pselect" do
		results = %w{a B c d e F G h I j k L m N O p q r s}.pselect(crop: true) do |item, prev|
			prev.upcase == prev
		end
		expect(results).to eq(%w{c G h j m O p})
	end
	it "should have pmap" do
		results = %w{a B c d e F G h I j k L m N O p q r s}.pmap(crop: true) do |item, prev|
			if prev.upcase == prev
				item.upcase
			else
				item.downcase
			end
		end
		expect(results).to eq(%w{b C d e f G H i J k l M n O P q r s})
	end
	
	it "should have preduce(_)" do
		results = %w{a B c d e F G h I j k L m N O p q r s}.preduce("") do |memo, (item, prev)|
			if prev == nil || prev.upcase == prev
				memo + item
			else
				memo
			end
		end
		expect(results).to eq("acGhjmOp")
	end
	
	it "should have wselect" do
		results = "Ab>c<defg>h<i>j<kLm>n<op".each_char.wselect(crop: true) do |left, item, right|
			left + right == "><"
		end
		expect(results).to eq(%w{c h j n})
	end
	
	it "should have wmap" do
		results = "Ab>c<defg>h<i>j<kLm>n<op".each_char.wmap do |left, item, right|
			if left != nil && right != nil && left + right == "><"
				item.upcase
			else
				item.downcase
			end
		end.join
		expect(results).to eq("ab>C<defg>H<i>J<klm>N<op")
	end
	
	it "should have wreduce" do
		results = "Ab>C<defg>h<i>j<kLm>n<o>p".each_char.wreduce("") do |memo, (left, item, right)|
			if left != nil && right != nil && left + right == "><"
				memo + item
			else
				memo
			end
		end
		expect(results).to eq("Chjn")
	end
end
