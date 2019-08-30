module Sidtool
  class Synth
    attr_writer :waveform
    attr_writer :attack
    attr_writer :decay
    attr_writer :release

    def initialize(start_frame)
      @start_frame = start_frame
      @controls = []
    end

    def frequency=(frequency)
      if @frequency
        previous_midi, current_midi = sid_frequency_to_nearest_midi(@frequency), sid_frequency_to_nearest_midi(frequency)
        @controls << [STATE.current_frame, current_midi] if previous_midi != current_midi
      end
      @frequency = frequency
    end

    def release!
      length_of_attack_decay_sustain = (STATE.current_frame - @start_frame) / FRAMES_PER_SECOND
      if length_of_attack_decay_sustain < @attack
        @attack = length_of_attack_decay_sustain
        @decay, @sustain_length = 0, 0
      elsif length_of_attack_decay_sustain < @attack + @decay
        @decay = length_of_attack_decay_sustain - @attack
        @sustain_length = 0
      else
        @sustain_length = length_of_attack_decay_sustain - @attack - @decay
      end
    end

    def stop!
      # TODO: Should also cut off any remaining release
      release!
    end

    def to_a
      tone = sid_frequency_to_nearest_midi(@frequency)
      [@start_frame, tone, @waveform, @attack.round(3), @decay.round(3), @sustain_length, @release.round(3), @controls]
    end

    private
    def sid_frequency_to_nearest_midi(sid_frequency)
      actual_frequency = sid_frequency_to_actual_frequency(sid_frequency)
      nearest_tone(actual_frequency)
    end

    def nearest_tone(frequency)
      # Stolen from Sonic Pi
      midi_tone = (12 * (Math.log(frequency * 0.0022727272727) / Math.log(2))) + 69

      midi_tone.round
    end

    def sid_frequency_to_actual_frequency(sid_frequency)
      # With a standard 1 MHz clock
      # (sid_frequency * 0.0596).round(2)
      # PAL clock: 985248
      (sid_frequency * (CLOCK_FREQUENCY / 16777216)).round(2)
    end
  end
end
