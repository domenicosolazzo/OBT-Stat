require 'evaluator'

class LemmaModel
  @@default_file = "data/trening-u-flert-d.train.cor"

  @@lemma_data_sep = "^"
  
  def initialize(evaluator, file = @@default_file)
    # text = Text.new

#     if file == $stdin
#       OBNOText.parse text, $stdin
#     else
#       text = obno_read(@@default_file)
#     end

#     @model = create_lemma_model(text)

    @evaluator = evaluator
  end

  def disambiguate_lemma(word, lemma_list)
    word_lookup = @model[word]

    if word_lookup.nil?
      @evaluator.mark_lemma_miss
      
      return lemma_list.first
    end

    @evaluator.mark_lemma_hit
    
    best_score = 0
    best_lemma = nil
    
    word_lookup.each do |k, v|
      if v > best_score
        best_lemma = k
      end
    end

    raise RuntimeError if best_lemma.nil?
    
    return best_lemma
  end

  def lemma_counts(text)
    lemma_counts = {}
    no_correct = 0
    
    text.sentences.each do |s|
      s.words.each do |w|
        tag = w.get_correct_tags
        if tag.count != 1
          no_correct += 1
          next
        end

        tag = tag.first
        lemma = tag.lemma

        word = w.string

        data = lemma_counts[word]

        if data.nil?
          lemma_counts[word] = { lemma => 1 }
        elsif data[lemma].nil?
          data[lemma] = 1
        else
          data[lemma] += 1
        end
      end
    end

    return [lemma_counts, no_correct]
  end

  def create_lemma_model(text)
    @model = {}
    lc = lemma_counts(text)

    lc.first.each do |k, v|
      word = k
      total = v.values.inject { |sum, n| sum + n }
      lemma_probs = []

      v.each do |k, v|
        lemma_probs << [k, v / total.to_f]
      end

      @model[word] = lemma_probs
    end

    return @model
  end

  def write_lemma_model(file)
    f = nil
    
    if file == $stdout
      f = $stdout
    else
      f = File.open(file, 'w')
    end
    
    f.puts "version 1"
    
    @model.each do |k, v|
      f.puts k + "\t" + v.collect{ |e| e.join(@@lemma_data_sep)}.join("\t")
    end

    if f != $stdout
      f.close
    end
  end

  def read_lemma_model(file)
    @model = {}
    File.open(file, 'r') do |f|
      if f.readline.strip() != "version 1"
        raise RuntimeError
      end

      f.each_line do |l|
        tokens = l.split("\t")
        word = tokens[0]
        lemmadata = tokens[1...tokens.count]

        lemmas = lemmadata.collect do |e|
          e = e.split(@@lemma_data_sep)
          raise RuntimeError if e.count != 2
          [e[0], e[1].to_f]
        end

        if @model[word]
          raise RuntimeError
        end
        
        @model[word] = lemmas
      end
    end

    return @model
  end
end