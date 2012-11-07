Gem::Specification.new do |s|
  s.name        = "regexp_optimized_union"
  s.version     = '0.1.0'
  s.authors     = ["luikore"]
  s.homepage    = "https://github.com/luikore/regexp_optimized_union"
  s.summary     = "Regexp.optimized_union(word_list, regexp_options) generates optimized regexp for matching union of word list"
  s.description = "Regexp.optimized_union(word_list, regexp_options) generates optimized regexp for matching union of word list.
Optimations include: treed common prefix extraction, common suffix aggregation and optional leaf to ?.
Mostly the same as described in http://search.cpan.org/~dankogai/Regexp-Optimizer-0.15/lib/Regexp/List.pm#IMPLEMENTATION"
  s.required_rubygems_version = ">= 1.3.6"
  s.files = ["lib/regexp_optimized_union.rb"]
  s.license = 'WTFPL'
end

