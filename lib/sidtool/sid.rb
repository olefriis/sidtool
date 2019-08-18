module Sidtool
  class Sid
    def initialize
      @voices = [Voice.new, Voice.new, Voice.new]
      @synths = []

      @frequency_low = @frequency_high = 0
      @pulse_low = @pulse_high = 0
      @control_register = 0
      @attack_decay = @sustain_release = 0
    end

    def poke(register, value)
      if register >= 0 && register <= 6
        voice = @voices[0]
      elsif register >= 7 && register <=13
        voice = @voices[1]
        register -=7
      elsif register >= 14 && register <=20
        voice = @voices[2]
        register -=14
      end

      case register
      when 0 then voice.frequency_low = value
      when 1 then voice.frequency_high = value
      when 2 then voice.pulse_low = value
      when 3 then voice.pulse_high = value
      when 4 then voice.control_register = value
      when 5 then voice.attack_decay = value
      when 6 then voice.sustain_release = value
        # 7-20 are covered by the mapping above
      when 21 then @cutoff_frequency_low = value
      when 22 then @cutoff_frequency_high = value
      when 23 then @resonance_filter = value
      when 24 then @mode_volume = value
      end
    end

    def finish_frame
      @voices.each(&:finish_frame)
    end

    def stop!
      @voices.each(&:stop!)
    end
  end
end