if RUBY_VERSION < '1.9'
  require 'enumerator'
  class String
    unless defined?(ord)
      def ord
        unpack('C').first
      end
    end
  end
end

class Regexp
  # trie for optimization
  class OptimizeTrie < Hash
    attr_accessor :parent, :opt_maybe, :opt_suffix
    def []= k, v
      super(k, v)
      v.parent = self
    end

    def single_branch?
      empty? or (size == 1 and !opt_maybe and values[0].single_branch?)
    end

    def single_char?
      size == 1 and values[0].empty?
    end

    # prereq: single_branch?
    def to_chars
      if empty?
        []
      else
        [keys[0], *values[0].to_chars]
      end
    end

    # prereq: opt_suffix
    # returns: regexp src
    def extract_common_suffix
      branches = map do |key, value|
        [key, *value.to_chars]
      end
      branches.each &:reverse!
      max_common_size = branches.map(&:size).min
      common_size = nil
      max_common_size.downto 1 do |i|
        found = true
        branches.map {|b| b.take i }.each_cons(2) do |b1, b2|
          if b1 != b2
            found = false
            break
          end
        end
        if found
          common_size = i
          break
        end
      end

      if common_size
        common = branches[0].take(common_size).reverse.join
        if branches.all?{|b| b.size == common_size + 1 }
          diff = build_char_group(branches.map &:last)
          "#{diff}#{common}"
        else
          diff = branches.map do |b|
            b.drop(common_size).reverse.join
          end.join '|'
          "(?:#{diff})#{common}"
        end
      end
    end

    def build_char_group chars
      return chars.first if chars.size == 1

      if RUBY_VERSION < '1.9'
        chars, mb_chars = chars.partition{|c| c.bytesize == 1}
      else
        mb_chars = []
      end

      chars = chars.map(&:ord)
      chars.sort!
      first_char = chars.shift
      groups = [(first_char..first_char)]
      chars.each do |c|
        if c == groups.last.end + 1
          groups[-1] = groups.last.begin..c
        else
          groups << (c..c)
        end
      end

      groups.map! do |range|
        # only apply range to >= 4 contiguous chars
        if range.end >= range.begin + 3
          "#{range.begin.chr}-#{range.end.chr}"
        elsif range.end > range.begin
          range.map(&:chr).join
        else
          range.begin.chr
        end
      end

      "[#{groups.join}#{mb_chars.join}]"
    end

    def to_re_src
      return '' if empty?

      res = extract_common_suffix if opt_suffix
      char_group = false
      if !res
        can_be_branched = true
        branches = map do |key, value|
          "#{key}#{value.to_re_src}"
        end
        if branches.all?{|b| b.bytesize == 1}
          char_group = true
          res = build_char_group branches
        else
          res = branches.join '|'
        end
      end

      if opt_maybe
        if char_group or single_char?
          "#{res}?"
        else
          "(?:#{res})?"
        end
      else
        if can_be_branched and size > 1 and parent and !char_group
          "(?:#{res})"
        else
          res
        end
      end
    end
  end

  def self.optimized_union a, opts=nil
    trie = OptimizeTrie.new
    term_nodes = {}

    # build trie
    a.each do |s|
      next if s.empty?
      t = trie
      s.chars.each do |c|
        c = Regexp.escape c
        unless t[c]
          t[c] = OptimizeTrie.new
        end
        t = t[c]
      end
      term_nodes[t] = true
      t.opt_maybe = true
    end

    # tag opt_suffix nodes
    term_nodes.each do |node, _|
      next unless node.empty?
      while node = node.parent and !node.opt_suffix and !node.opt_maybe
        if node.size > 1
          if node.values.all?(&:single_branch?)
            node.opt_suffix = true
          end
          break
        end
      end
    end

    Regexp.new trie.to_re_src, opts
  end
end

if __FILE__ == $PROGRAM_NAME
  # NOTE test will fail under ruby 1.8.7 due to hash order, but results should be identical
  success = true
  {
    %w[]                        => //,
    %w[a b c d f]               => /[a-df]/,
    %w[foo]                     => /foo/,
    %w[foo bar]                 => /foo|bar/,
    %w[foo foob bar]            => /foob?|bar/,
    %w[foo foobar]              => /foo(?:bar)?/,
    %w[bazfoo bazfoobar bazbar] => /baz(?:foo(?:bar)?|bar)/,
    %w[fooabar foobbar]         => /foo[ab]bar/,
    %w[fooabar foobazbar]       => /foo(?:a|baz)bar/,
    %w[foobar fooabar foogabar] => /foo(?:|a|ga)bar/,
    %w[vax vcx vbx vdx]         => /v[a-d]x/,
    %w[vax vcx vbx]             => /v[abc]x/,
    %w[xa xc xb x]              => /x[abc]?/
  }.each do |a, r|
    l = Regexp.optimized_union a
    a.each do |s|
      if l.match(s).offset(0) != [0, s.size]
        success = false
        puts "#{l.inspect} from #{a.inspect} not match #{s.inspect}"
      end
    end
    if r != l
      success = false
      puts "expected #{r} from #{a.inspect} but got #{l}"
    end
  end
  puts 'test success!' if success
end
