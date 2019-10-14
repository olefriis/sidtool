module Sidtool
  class MidiFileWriter
    def initialize(synths)
      @synths = synths
    end

    def write_to(path)
      File.open(path, 'wb') do |file|
        write_header(file)

        @synths.each_with_index do |synths_for_voice, voice_number|
          track = [
            variable_length_quantity(0), time_signature(4, 2, 24, 8),
            variable_length_quantity(0), key_signature(0, 0),
            variable_length_quantity(0), program_change(voice_number, 1)
          ]

          previous_synth = nil
          synths_for_voice.each do |synth|
            diff = synth.start_frame - (previous_synth&.start_frame || 0)
            track << variable_length_quantity(diff)
            if previous_synth
              track << note_off(voice_number, previous_synth.tone)
              track << variable_length_quantity(0)
            end
            track << note_on(voice_number, synth.tone)
            previous_synth = synth
          end

          track << end_of_track

          write_track(file, track)
        end
      end
    end

    private
    def write_uint32(file, value)
      bytes = [(value >> 24) & 255, (value >> 16) & 255, (value >> 8) & 255, value & 255]
      file << bytes.pack('cccc')
    end

    def write_uint16(file, value)
      bytes = [(value >> 8) & 255, value & 255]
      file << bytes.pack('cc')
    end

    def write_byte(file, value)
      bytes = [value & 255]
      file << bytes.pack('c')
    end

    def write_header(file)
      # Type
      file << 'MThd'

      # Length
      write_uint32(file, 6)

      # Format
      write_uint16(file, 1)

      # Number of tracks
      write_uint16(file, 3)

      # Division
      # Default tempo is 120 BPM - 120 quarter-notes per minute. Which is 2 quarter-notes per second. If we then define
      # 25 ticks per quarter-note, we end up with a timing of 50 ticks per second.
      write_uint16(file, 25)
    end

    def variable_length_quantity(quantity)
      seven_bit_segments = []
      while true
        seven_bit_segments << (quantity & 127)
        quantity = quantity >> 7
        break if quantity == 0
      end
      result = seven_bit_segments.reverse.map { |segment| segment | 128 }
      result[-1] &= 127
      result
    end

    def note_on(channel, key)
      raise "Channel too big: #{channel}" if channel > 15
      raise "Key is too big: #{key}" if key > 255
      [
        0x90 + channel,
        key,
        40 # Default velocity
      ]
    end

    def note_off(channel, key)
      raise "Channel too big: #{channel}" if channel > 15
      raise "Key is too big: #{key}" if key > 255
      [
        0x80 + channel,
        key,
        40 # Default velocity
      ]
    end

    def program_change(channel, program_number)
      raise "Channel too big: #{channel}" if channel > 15
      raise "Program number is too big: #{program_number}" if program_number > 255
      [
        0xC0 + channel,
        program_number
      ]
    end

    def tempo(units_per_quarter_note)
      [
        0xFF, 0x51, 0x03,
        (units_per_quarter_note >> 16) & 255,
        (units_per_quarter_note >> 8) & 255,
        units_per_quarter_note & 255
      ]
    end

    def time_signature(numerator, denominator_power_of_two, clocks_per_metronome_click, number_of_32th_nodes_per_24_clocks)
      [
        0xFF, 0x58, 0x04,
        numerator,
        denominator_power_of_two,
        clocks_per_metronome_click,
        number_of_32th_nodes_per_24_clocks
      ]
    end

    def key_signature(sharps_or_flats, is_major)
      [
        0xFF, 0x59, 0x02,
        sharps_or_flats,
        is_major ? 0 : 1
      ]
    end

    def end_of_track
      [
        0xFF, 0x2F, 0x00
      ]
    end

    def write_track(file, track)
      track_bytes = track.flatten

      # Type
      file << 'MTrk'

      # Length
      write_uint32(file, track_bytes.length)

      # Track
      file << track_bytes.pack('c' * track_bytes.length)
    end
  end
end
