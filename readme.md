`Regexp.optimized_union(word_list, regexp_options)` generates optimized regexp for matching union of word list.

```ruby
require 'regexp_optimized_union'
Regexp.optimized_union(%w[bazfoo bazfoobar bazbar]) #=> /baz(?:foo(?:bar)?|bar)/
Regexp.optimized_union(%w[fooabar foobbar], 'i')    #=> /foo[ab]bar/i
Regexp.optimized_union(%w[foobar fooabar foogabar]) #=> /foo(?:|a|ga)bar/
```

Caveats:

- All words in the list will be escaped.
- Matching time for the light but compile time for the dark, you are the balance between them.

Works similar to `Regexp.union`, but API receives Regexp compile option. Optimizations include:

- Treed common prefix extraction.
- Common suffix aggregation.
- Optional leaf to `?`.

Mostly the same as described in http://search.cpan.org/~dankogai/Regexp-Optimizer-0.15/lib/Regexp/List.pm#IMPLEMENTATION

### License (WTFPL)

    DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
    TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION

    0. You just DO WHAT THE FUCK YOU WANT TO.
