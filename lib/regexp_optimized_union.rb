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
          diff = branches.map(&:last).join
          "[#{diff}]#{common}"
        else
          diff = branches.map do |b|
            b.drop(common_size).reverse.join
          end.join '|'
          "(?:#{diff})#{common}"
        end
      end
    end

    def to_re_src
      return '' if empty?
      
      res = extract_common_suffix if opt_suffix
      if !res
        can_be_branched = true
        res = map do |key, value|
          "#{key}#{value.to_re_src}"
        end.join '|'
      end
      
      if opt_maybe
        if single_char?
          "#{res}?"
        else
          "(?:#{res})?"
        end
      else
        if can_be_branched and size > 1 and parent
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
  {
    %w[]                        => //,
    %w[foo]                     => /foo/,
    %w[foo bar]                 => /foo|bar/,
    %w[foo foob bar]            => /foob?|bar/,
    %w[foo foobar]              => /foo(?:bar)?/,
    %w[bazfoo bazfoobar bazbar] => /baz(?:foo(?:bar)?|bar)/,
    %w[fooabar foobbar]         => /foo[ab]bar/,
    %w[fooabar foobazbar]       => /foo(?:a|baz)bar/,
    %w[foobar fooabar foogabar] => /foo(?:|a|ga)bar/
  }.each do |a, r|
    l = Regexp.optimized_union a
    a.each do |s|
      if l.match(s).offset(0) != [0, s.size]
        raise "#{l.inspect} from #{a.inspect} not match #{s.inspect}"
      end
    end
    if r != l
      raise "expected #{r} from #{a.inspect} but got #{l}"
    end
  end
  puts 'test success!'
end
