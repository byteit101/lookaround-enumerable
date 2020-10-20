# Lookaround Enumerable

When working with time series, it is common to perform operations that depend on a sliding window of values. Lookaround Enumerable adds two main methods, and several sub-helpers to assist with running map/collect, reduce/inject, and find_all/select queries that depend on the previous values (Enumerable#each_with_prev), or a whole window of values (Enumerable#each_with_window). This gem contains these methods as refinements. 

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'lookaround-enumerable'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install lookaround-enumerable

## Usage

```ruby
require 'lookaround-enumerable'
using LookaroundEnum
```

The `LookaroundEnum` contains the refinements, so they can be targeted to selected areas of code.

```ruby
# Maps characters after a capital letter to "x"
"AbCdefgHiJKl".each_char.map_with_prev(1, filler: "a") {|x, previous| previous.upcase == previous ? "x" : x}.join
# => "AxCxefgHxJxx"

# select characters surrounded by > <, ignoring the bounds (crop)
"Ab>c<defg>h<i>j<kLm>n<op".each_char.select_with_window(-1..1, crop: true) { |left, item, right| left + right == "><" }.join
# => "cjhn"
```

 * Set what beyond the Enumerable is with `filler:`
 * Ignore all iterations that look beyond the Enumerable with `crop: true`
 * Remove extra details from chains with `trim: true`

See the documentation spec tests under `spec/` for more examples.


### Wait, what are the proc's args?

That's a tricky question. By default, single left/right views _should_ just work, but you might have to play with the `expand` parameter or do a `p *args` to figure out more advanced usage, like chaining with memos or objects. The `each_with_prev` family does `|(*this), ((*previous1), ..., (*previous_n))|` with older/lower indexes to the right. The `each_with_window` family does `|((*previous_n), ..., (*previous1)), (*this), ((*next1), ..., (*next_n))|` with older/lower indexes on the left. 

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `rake spec` or `rspec` to run the tests. 

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/byteit101/lookaround-enumerable.
