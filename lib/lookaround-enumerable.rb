=begin
Copyright 2020 Patrick Plenefisch <simonpatp@gmail.com>

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
=end


##
# Refinements for lookaround methods on Enumerable/Enumerator
# 
# Use:
#  using LookaroundEnum
#
# All methods are added to Enumerable
#
module LookaroundEnum

	VERSION = "1.0.0"

	# Refinements for Enumerable
	refine Enumerable do
	
		# See doc below, yard doesn't support refinements
		def each_with_prev(size=1, crop: false, trim: false, filler: nil, expand: :single, &block)
			raise ArgumentError, "previous size must not be negative" unless (0...2_000_000_000).include?(size)
			raise ArgumentError, "Expand parameter isn't valid" unless [:none, :all, :single].include?(expand)
			return to_enum(:__nbl_back_refinement_send, size, crop: crop, trim: trim, filler: filler, expand: expand) { __nbl_any_sized } unless block_given?
			
			last = [filler] * size
			skips = crop ? size : 0 # how many elements to skip
			
			each do |*o| # call parent
				issingle = o.length == 1
				result = if skips != 0 # skip the first N if we don't want nil results
					skips -= 1
					nil
				else
					case expand
					when :all then yield(*o, *last.dup)
					when :none then yield(o, last.dup)
					when :single
						yield(LookaroundEnum.unwrap(o), LookaroundEnum.unwrap(last, size))
					end
				end
				# maintain the last values
				last.pop
				last.unshift(trim ? o.first : LookaroundEnum.unwrap(o))
				
				# return yield result
				result
			end
			#self
		end
		
		def each_with_window(view=(-1..1), crop: false, trim: false, filler: nil, expand: :single, &blk)
			center_index = -view.min
			raise ArgumentError, "window view minimum must not be positive" unless (0...2_000_000_000).include?(center_index)
			raise ArgumentError, "window view maximum must not be negative" unless (0...2_000_000_000).include?(view.max)
			raise ArgumentError, "Expand parameter isn't valid" unless [:none, :all, :single].include?(expand)
			width = view.size - 1 # width - 1 as the main arg counts as +1
			
			# no lookahead, just defer to straight neighbor call
			if view.max == 0
				return each_with_prev(width, crop: crop, trim: trim, expand: expand, filler: filler, &blk) # TODO: test arity
			end
			
			return to_enum(:__nbl_window_refinement_send, view, crop: crop, trim: trim, filler: filler, expand: expand) { __nbl_any_sized } unless blk
			
			last_row = [filler] * view.size
			skips = view.max
			last_result = nil
			
			# helper for each invocation to skip the left sides. Note: we are always view.max items behind in order to "lookahead"
			process = lambda do
				last_result = if skips != 0
					skips -= 1
					nil
				else
					center = last_row[center_index]
					right = last_row[(center_index+1)..-1]
					left = last_row[0...center_index]
					case expand
					when :none then blk.call(left, center, right)
					when :all then blk.call(*left, center, *right) # look into splatting the center
					when :single then
						if center_index == 0
							blk.call(center, LookaroundEnum.unwrap(right))
						else
							maxsize = [left.size, right.size].max
							blk.call(LookaroundEnum.unwrap(left, maxsize), center, LookaroundEnum.unwrap(right, maxsize))
						end
					end
				end
			end
			
			# Process all the left hand sides
			iresult = each_with_prev(width, crop: crop, trim: trim, filler: filler, expand: :none) do |arg, history|
				rearg = arg.length == 1 ? arg : [arg] # keep multi-arguments together when reversing
				last_row = (rearg + history).reverse # Could be done better
				process.call
			end
			
			# and any remaining right hand sides
			unless crop
				view.max.times do |i|
					last_row.shift
					last_row << filler
					process.call
				end
			end
			
			return last_result
		end
		
		
		# map helpers and aliases
		def map_with_prev(size=1, **kwargs, &block)
			each_with_prev(size, **kwargs).map(&block)
		end
		alias_method :collect_with_prev, :map_with_prev
		alias_method :pcollect, :map_with_prev
		alias_method :pmap, :map_with_prev
		
		# select helper and aliases
		def select_with_prev(size=1, **kwargs, &block)
			select.each_with_prev(size, **kwargs, &block)
		end
		
		alias_method :find_all_with_prev, :select_with_prev
		alias_method :pfind_all, :select_with_prev
		alias_method :pselect, :select_with_prev
		
		# inject helper and aliases
		def pinject(memo = NBL__PRIVATE_EMPTY, size=1, **kwargs, &block)
			if memo.equal? NBL__PRIVATE_EMPTY
				each_with_prev(size, **kwargs).reduce(&block)
			else
				each_with_prev(size, **kwargs).reduce(memo, &block) #T TODO: test
			end
		end
		alias_method :reduce_with_prev, :pinject
		alias_method :inject_with_prev, :pinject
		alias_method :preduce, :pinject
		
		# map helpers (windows) and aliases
		def map_with_window(view=(-1..1), **kwargs, &block)
			each_with_window(view, **kwargs).map(&block)
		end
		alias_method :collect_with_window, :map_with_window
		alias_method :wcollect, :map_with_window
		alias_method :wmap, :map_with_window
		
		# select helpers (windows) and aliases
		def select_with_window(view=(-1..1), **kwargs, &block)
			map_with_window(view, **kwargs) do |*lcr|
				a, b, c = *lcr
				node = view.min == 0 ? a : b
				[block.call(*lcr), node]
			end.select{|(key, _)| key}.map{|_, value| value}
		end
		
		alias_method :find_all_with_window, :select_with_window
		alias_method :wfind_all, :select_with_window
		alias_method :wselect, :select_with_window
		
		# inject helper and aliases
		def winject(memo = NBL__PRIVATE_EMPTY, size=(-1..1), **kwargs, &block)
			if memo.equal? NBL__PRIVATE_EMPTY
				each_with_window(size, **kwargs).reduce(&block)
			else
				each_with_window(size, **kwargs).reduce(memo, &block)
			end
		end
		alias_method :reduce_with_window, :winject
		alias_method :inject_with_window, :winject
		alias_method :wreduce, :winject
		
		
		private
		# :nodoc:
		# Helper to get the size, or nil if unsupported
		def __nbl_any_sized
			respond_to?(:size) ? size : nil
		end
	end
	
	private
	# :nodoc:
	# Helper to unwrap a single element array
	def self.unwrap(array, size=array.length)
		case size
		when 1 then array.first
		else array.dup
		end
	end
	
	# :nodoc:
	NBL__PRIVATE_EMPTY = {}
end

module Enumerable
	using LookaroundEnum
	# @api private
	# @private
	# @!visibility private
	# Hack to support to_enum, which uses send, which doesn't work with refinements. This method is always monkey-patched in as a result
	def __nbl_back_refinement_send(*args, **kwargs, &block)
		each_with_prev(*args, **kwargs, &block)
	end
	# @api private
	# @private
	# @!visibility private
	# Hack to support to_enum, which uses send, which doesn't work with refinements. This method is always monkey-patched in as a result
	def __nbl_window_refinement_send(*args, **kwargs, &block)
		each_with_window(*args, **kwargs, &block)
	end
	
	# Document via yard
	
	
	##
	# @!method each_with_prev	
	# 
	# @overload each_with_prev(size=1, crop: false, trim: false, filler: nil, expand: :single)
	#  @return [Enumerable] The parent Enumerable
	#  @yield [(*args), (*previous)] 
	# @overload each_with_prev(size=1, crop: false, trim: false, filler: nil, expand: :single)
	#  @return [Enumerator] The external Enumerator
	#
	# Calls <em>block</em> with two (or more, depending on the <em>expand</em>) arguments: the item and 
	# the values at earlier indexes.
	#
	# If no block is given, an enumerator is returned instead.
	# 
	# @param size [Integer] The number of previous elements to iterate with
	# @example Size Examples
	#  (1..3).each_with_prev(1).to_a # => [[1, nil], [2, 1], [3, 2]]
	#  (1..3).each_with_prev(2).to_a # => [[1, [nil, nil]], [2, [1, nil]], [3, [2, 1]]]
	#
	# @param crop: [Bool] true if the iteration should only include values with no empty previous (skips first <em>size</em> number of elements), false if all elements iterated
	# @example Crop Examples
	#  (1..3).each_with_prev(1, crop: false).to_a # => [[1, nil], [2, 1], [3, 2]]
	#  (1..3).each_with_prev(1, crop: true).to_a # =>            [[2, 1], [3, 2]]
	#
	#
	# @param trim: [Bool] true if the previous elements should only be the first item from lower level iterators, false if all values should be saved. Note that setting this value is only useful on Enumerators or Enumerables that have more than one value.
	# @example Trim Examples
	#  (1..3).each_with_object({}).each_with_prev(1, trim: false, expand: :all).to_a
	#  # => [[1, {}, nil], [2, {}, [1, {}]], [3, {}, [2, {}]]]
	#  (1..3).each_with_object({}).each_with_prev(1, trim: true, expand: :all).to_a
	#  # => [[1, {}, nil], [2, {}, 1], [3, {}, 2]]
	#
	# @param filler: [Any] the value to use for empty/no-value history cells at the start of the iteration. Does nothing when <em>crop</em> is true.
	# @example Filler Examples
	#  (1..3).each_with_prev(1, filler: nil).to_a # => [[1, nil], [2, 1], [3, 2]]
	#  (1..3).each_with_prev(1, filler: 0).to_a   # => [[1, 0], [2, 1], [3, 2]]
	#
	# @param expand: [Symbol] What argument style the block expects. See the valid options above (html doc) or below (source)
	#
	# <code>expand:</code>:: 
	#   (Symbol) Valid options are:
	#
	#   <code>:none</code>:: Never expands, block always takes two arguments, each an array
	#
	#    (1..3).each_with_prev(expand: :none) {|(current), (prev)|  }
	#    (1..3).each_with_object({}).each_with_prev(2, expand: :none) {|(current, obj), (prev, prev2)| }
	#
	#   <code>:single</code>:: (default) Expands if only one element, block always takes two arguments, each an array or an object
	#
	#    (1..3).each_with_prev(expand: :single) {|current, prev|  }
	#    (1..3).each_with_prev(2, expand: :single) {|current, (prev, prev2)| }
	#    (1..3).each_with_object({}).each_with_prev(2, expand: :single) {|(current, obj), (prev, prev2)| }
	#
	#   <code>:all</code>:: Expands all sides, block takes two or more arguments, each an object
	#
	#    (1..3).each_with_prev(expand: :all) {|current, prev|  }
	#    (1..3).each_with_prev(2, expand: :all) {|current, prev, prev2| }
	#    (1..3).each_with_object({}).each_with_prev(2, expand: :all) {|current, obj, prev, prev2| }
	#
	#
	#
	# @raise [ArgumentError] If the arguments are invalid
	#
	#
	#
	#
	#
	#
	#
	#
	#
	
	
	
	##
	# @!method each_with_window	
	# 
	# @overload each_with_window(view=-1..1, crop: false, trim: false, filler: nil, expand: :single)
	#  @return [Enumerable] The parent Enumerable
	#  @yield [(*left), (*args), (*right)] 
	# @overload each_with_window(size=-1..1, crop: false, trim: false, filler: nil, expand: :single)
	#  @return [Enumerator] The external Enumerator
	#
	# Calls <em>block</em> with three (or more, depending on the <em>expand</em>) arguments: the item and 
	# the values at earlier and later indexes.
	#
	# If no block is given, an enumerator is returned instead.
	#
	# Important note: each_with_window is executed in a disjunct manner from the parent iterator. This can cause issues when chained with other Enumerators. Please use the built in helpers.
	# 
	# @param view [Range] The number of items to look at to previous and upcoming indicies.
	# @example View Examples
	#  ('a'..'d').each_with_window(-2..1).to_a # =>  [[[nil, nil], "a", ["b"]], [[nil, "a"], "b", ["c"]], [["a", "b"], "c", ["d"]], [["b", "c"], "d", [nil]]]
	#
	# @see each_with_prev For argument descriptions
	#
	# @raise [ArgumentError] If the arguments are invalid
	#
	#
	#
	#
	#
	#
	#
	#
	#
	
	# @!group Aliases
	
	##
	# @!method map_with_prev
	# @overload map_with_prev(*args)
	#  @return [Object] The result of the map
	#  @yield [(*args), (*previous)] See the `expand` parameter of each_with_prev
	# @overload map_with_prev(*args)
	#  @return [Enumerator] The external Enumerator
	#
	# Aliases for each_with_prev(*args).map
	#
	# @see each_with_prev
	# @see collect_with_prev
	# @see pmap
	# @see pcollect
	
	
	##
	# @!method collect_with_prev
	# @overload collect_with_prev(*args)
	#  @return [Object] The result of the map
	#  @yield [(*args), (*previous)] See the `expand` parameter of each_with_prev
	# @overload collect_with_prev(*args)
	#  @return [Enumerator] The external Enumerator
	#
	# Aliases for each_with_prev(*args).map
	#
	# @see each_with_prev
	# @see map_with_prev
	# @see pmap
	# @see pcollect
	
	
	##
	# @!method pmap
	# @overload pmap(*args)
	#  @return [Object] The result of the map
	#  @yield [(*args), (*previous)] See the `expand` parameter of each_with_prev
	# @overload pmap(*args)
	#  @return [Enumerator] The external Enumerator
	#
	# Aliases for each_with_prev(*args).map
	#
	# @see each_with_prev
	# @see map_with_prev
	# @see collect_with_prev
	# @see pcollect
	
	
	##
	# @!method pcollect
	# @overload pcollect(*args)
	#  @return [Object] The result of the map
	#  @yield [(*args), (*previous)] See the `expand` parameter of each_with_prev
	# @overload pcollect(*args)
	#  @return [Enumerator] The external Enumerator
	#
	# Aliases for each_with_prev(*args).map
	#
	# @see each_with_prev
	# @see map_with_prev
	# @see collect_with_prev
	# @see pmap
	
	
	
	
	##
	# @!method select_with_prev
	# @overload select_with_prev(*args)
	#  @return [Object] The result of the map
	#  @yield [(*args), (*previous)] See the `expand` parameter of each_with_prev
	# @overload select_with_prev(*args)
	#  @return [Enumerator] The external Enumerator
	#
	# Aliases for select.each_with_prev(*args)
	#
	# @see each_with_prev
	# @see find_all_with_prev
	# @see pselect
	# @see pfind_all
	
	
	##
	# @!method find_all_with_prev
	# @overload find_all_with_prev(*args)
	#  @return [Object] The result of the map
	#  @yield [(*args), (*previous)] See the `expand` parameter of each_with_prev
	# @overload find_all_with_prev(*args)
	#  @return [Enumerator] The external Enumerator
	#
	# Aliases for select.each_with_prev(*args)
	#
	# @see each_with_prev
	# @see select_with_prev
	# @see pselect
	# @see pfind_all
	
	
	##
	# @!method pselect
	# @overload pselect(*args)
	#  @return [Object] The result of the map
	#  @yield [(*args), (*previous)] See the `expand` parameter of each_with_prev
	# @overload pselect(*args)
	#  @return [Enumerator] The external Enumerator
	#
	# Aliases for select.each_with_prev(*args)
	#
	# @see each_with_prev
	# @see select_with_prev
	# @see find_all_with_prev
	# @see pfind_all
	
	
	##
	# @!method pfind_all
	# @overload pfind_all(*args)
	#  @return [Object] The result of the map
	#  @yield [(*args), (*previous)] See the `expand` parameter of each_with_prev
	# @overload pfind_all(*args)
	#  @return [Enumerator] The external Enumerator
	#
	# Aliases for select.each_with_prev(*args)
	#
	# @see each_with_prev
	# @see select_with_prev
	# @see find_all_with_prev
	# @see pselect
	
	
	
	##
	# @!method inject_with_prev
	# @overload inject_with_prev(memo=first, *args)
	#  @return [Object] The result of the map
	#  @yield [(*args), (*previous)] See the `expand` parameter of each_with_prev
	# @overload inject_with_prev(memo=first, *args)
	#  @return [Enumerator] The external Enumerator
	#
	# Aliases for inject(memo).each_with_prev(*args)
	#
	# @see each_with_prev
	# @see reduce_with_prev
	# @see pinject
	# @see preduce
	
	
	##
	# @!method reduce_with_prev
	# @overload reduce_with_prev(memo=first, *args)
	#  @return [Object] The result of the map
	#  @yield [(*args), (*previous)] See the `expand` parameter of each_with_prev
	# @overload reduce_with_prev(memo=first, *args)
	#  @return [Enumerator] The external Enumerator
	#
	# Aliases for inject(memo).each_with_prev(*args)
	#
	# @see each_with_prev
	# @see inject_with_prev
	# @see pinject
	# @see preduce
	
	
	##
	# @!method pinject
	# @overload pinject(memo=first, *args)
	#  @return [Object] The result of the map
	#  @yield [(*args), (*previous)] See the `expand` parameter of each_with_prev
	# @overload pinject(memo=first, *args)
	#  @return [Enumerator] The external Enumerator
	#
	# Aliases for inject(memo).each_with_prev(*args)
	#
	# @see each_with_prev
	# @see inject_with_prev
	# @see reduce_with_prev
	# @see preduce
	
	
	##
	# @!method preduce
	# @overload preduce(memo=first, *args)
	#  @return [Object] The result of the map
	#  @yield [(*args), (*previous)] See the `expand` parameter of each_with_prev
	# @overload preduce(memo=first, *args)
	#  @return [Enumerator] The external Enumerator
	#
	# Aliases for inject(memo).each_with_prev(*args)
	#
	# @see each_with_prev
	# @see inject_with_prev
	# @see reduce_with_prev
	# @see pinject
	
	
	
	##
	# @!method map_with_window
	# @overload map_with_window(*args)
	#  @return [Object] The result of the map
	#  @yield [(*args), (*previous)] See the `expand` parameter of each_with_window
	# @overload map_with_window(*args)
	#  @return [Enumerator] The external Enumerator
	#
	# Aliases for each_with_window(*args).map
	#
	# @see each_with_window
	# @see collect_with_window
	# @see wmap
	# @see wcollect
	
	
	##
	# @!method collect_with_window
	# @overload collect_with_window(*args)
	#  @return [Object] The result of the map
	#  @yield [(*args), (*previous)] See the `expand` parameter of each_with_window
	# @overload collect_with_window(*args)
	#  @return [Enumerator] The external Enumerator
	#
	# Aliases for each_with_window(*args).map
	#
	# @see each_with_window
	# @see map_with_window
	# @see wmap
	# @see wcollect
	
	
	##
	# @!method wmap
	# @overload wmap(*args)
	#  @return [Object] The result of the map
	#  @yield [(*args), (*previous)] See the `expand` parameter of each_with_window
	# @overload wmap(*args)
	#  @return [Enumerator] The external Enumerator
	#
	# Aliases for each_with_window(*args).map
	#
	# @see each_with_window
	# @see map_with_window
	# @see collect_with_window
	# @see wcollect
	
	
	##
	# @!method wcollect
	# @overload wcollect(*args)
	#  @return [Object] The result of the map
	#  @yield [(*args), (*previous)] See the `expand` parameter of each_with_window
	# @overload wcollect(*args)
	#  @return [Enumerator] The external Enumerator
	#
	# Aliases for each_with_window(*args).map
	#
	# @see each_with_window
	# @see map_with_window
	# @see collect_with_window
	# @see wmap
	
	
	
	
	##
	# @!method select_with_window
	# @overload select_with_window(*args)
	#  @return [Object] The result of the map
	#  @yield [(*args), (*previous)] See the `expand` parameter of each_with_window
	# @overload select_with_window(*args)
	#  @return [Enumerator] The external Enumerator
	#
	# Aliases for select.each_with_window(*args)
	#
	# @see each_with_window
	# @see find_all_with_window
	# @see wselect
	# @see wfind_all
	
	
	##
	# @!method find_all_with_window
	# @overload find_all_with_window(*args)
	#  @return [Object] The result of the map
	#  @yield [(*args), (*previous)] See the `expand` parameter of each_with_window
	# @overload find_all_with_window(*args)
	#  @return [Enumerator] The external Enumerator
	#
	# Aliases for select.each_with_window(*args)
	#
	# @see each_with_window
	# @see select_with_window
	# @see wselect
	# @see wfind_all
	
	
	##
	# @!method wselect
	# @overload wselect(*args)
	#  @return [Object] The result of the map
	#  @yield [(*args), (*previous)] See the `expand` parameter of each_with_window
	# @overload wselect(*args)
	#  @return [Enumerator] The external Enumerator
	#
	# Aliases for select.each_with_window(*args)
	#
	# @see each_with_window
	# @see select_with_window
	# @see find_all_with_window
	# @see wfind_all
	
	
	##
	# @!method wfind_all
	# @overload wfind_all(*args)
	#  @return [Object] The result of the map
	#  @yield [(*args), (*previous)] See the `expand` parameter of each_with_window
	# @overload wfind_all(*args)
	#  @return [Enumerator] The external Enumerator
	#
	# Aliases for select.each_with_window(*args)
	#
	# @see each_with_window
	# @see select_with_window
	# @see find_all_with_window
	# @see wselect
	
	
	
	##
	# @!method inject_with_window
	# @overload inject_with_window(memo=first, *args)
	#  @return [Object] The result of the map
	#  @yield [(*args), (*previous)] See the `expand` parameter of each_with_window
	# @overload inject_with_window(memo=first, *args)
	#  @return [Enumerator] The external Enumerator
	#
	# Aliases for inject(memo).each_with_window(*args)
	#
	# @see each_with_window
	# @see reduce_with_window
	# @see winject
	# @see wreduce
	
	
	##
	# @!method reduce_with_window
	# @overload reduce_with_window(memo=first, *args)
	#  @return [Object] The result of the map
	#  @yield [(*args), (*previous)] See the `expand` parameter of each_with_window
	# @overload reduce_with_window(memo=first, *args)
	#  @return [Enumerator] The external Enumerator
	#
	# Aliases for inject(memo).each_with_window(*args)
	#
	# @see each_with_window
	# @see inject_with_window
	# @see winject
	# @see wreduce
	
	
	##
	# @!method winject
	# @overload winject(memo=first, *args)
	#  @return [Object] The result of the map
	#  @yield [(*args), (*previous)] See the `expand` parameter of each_with_window
	# @overload winject(memo=first, *args)
	#  @return [Enumerator] The external Enumerator
	#
	# Aliases for inject(memo).each_with_window(*args)
	#
	# @see each_with_window
	# @see inject_with_window
	# @see reduce_with_window
	# @see wreduce
	
	
	##
	# @!method wreduce
	# @overload wreduce(memo=first, *args)
	#  @return [Object] The result of the map
	#  @yield [(*args), (*previous)] See the `expand` parameter of each_with_window
	# @overload wreduce(memo=first, *args)
	#  @return [Enumerator] The external Enumerator
	#
	# Aliases for inject(memo).each_with_window(*args)
	#
	# @see each_with_window
	# @see inject_with_window
	# @see reduce_with_window
	# @see winject
	
end
