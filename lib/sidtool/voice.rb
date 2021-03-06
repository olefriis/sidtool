module Sidtool
  class Voice
    attr_writer :frequency_low
    attr_writer :frequency_high
    attr_writer :pulse_low
    attr_writer :pulse_high
    attr_writer :control_register
    attr_writer :attack_decay
    attr_writer :sustain_release
    attr_reader :synths

    def initialize
      @frequency_low = @frequency_high = 0
      @pulse_low = @pulse_high = 0
      @attack_decay = @sustain_release = 0
      @control_register = 0
      @current_synth = nil
      @synths = []
    end

    def finish_frame
      if gate
        if @current_synth&.released?
          @current_synth.stop!
          @current_synth = nil
        end

        if frequency > 0
          if !@current_synth
            @current_synth = Synth.new(STATE.current_frame)
            @synths << @current_synth
          end
          @current_synth.frequency = frequency
          @current_synth.waveform = waveform
          @current_synth.attack = attack
          @current_synth.decay = decay
          @current_synth.release = release
        end
      else
        @current_synth&.release!
      end
    end

    def stop!
      @current_synth&.stop!
      @current_synth = nil
    end

    private
    def gate
      @control_register & 1 == 1
    end

    def frequency
      (@frequency_high << 8) + @frequency_low
    end

    def waveform
      return :tri if @control_register & 16 != 0
      return :saw if @control_register & 32 != 0
      return :pulse if @control_register & 64 != 0
      return :noise if @control_register & 128 != 0
      STDERR.puts "Unknown waveform: #{@control_register}"
      return :noise
    end

    def attack
      # Approximated... should be multiplied by 1.000.000 / clock
      convert_attack(@attack_decay >> 4)
    end

    def decay
      # Approximated... should be multiplied by 1.000.000 / clock
      convert_decay_or_release(@attack_decay & 0xF)
    end

    def release
      # Approximated... should be multiplied by 1.000.000 / clock
      convert_decay_or_release(@sustain_release >> 4)
    end

    def convert_attack(attack)
      case attack
      when 0 then 0.002
      when 1 then 0.008
      when 2 then 0.016
      when 3 then 0.024
      when 4 then 0.038
      when 5 then 0.056
      when 6 then 0.068
      when 7 then 0.08
      when 8 then 0.1
      when 9 then 0.25
      when 10 then 0.5
      when 11 then 0.8
      when 12 then 1
      when 13 then 3
      when 14 then 5
      when 15 then 8
      else raise "Unknown value: #{attack}"
      end
    end

    def convert_decay_or_release(decay_or_release)
      case decay_or_release
      when 0 then 0.006
      when 1 then 0.024
      when 2 then 0.048
      when 3 then 0.072
      when 4 then 0.114
      when 5 then 0.168
      when 6 then 0.204
      when 7 then 0.240
      when 8 then 0.3
      when 9 then 0.75
      when 10 then 1.5
      when 11 then 2.4
      when 12 then 3
      when 13 then 9
      when 14 then 15
      when 15 then 24
      else raise "Unknown value: #{decay_or_release}"
      end
    end
  end
end
