module Sidtool
  class RubyFileWriter
    def initialize(synths)
      @synths = synths
    end

    def write_to(path)
      File.open(path, 'w') do |file|
        file.puts '::SYNTHS = ['
        @synths.flatten.sort_by(&:start_frame).each do |synth|
          file.puts synth.to_a.inspect + ','
        end
        file.puts ']'
      end
    end
  end
end
