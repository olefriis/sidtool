module Sidtool
  class MidiFileWriter
    DeltaTime = Struct.new(:time) do
      def bytes
        quantity = time
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
    end

    TimeSignature = Struct.new(:numerator, :denominator_power_of_two, :clocks_per_metronome_click, :number_of_32th_nodes_per_24_clocks) do
      def bytes
        [
          0xFF, 0x58, 0x04,
          numerator,
          denominator_power_of_two,
          clocks_per_metronome_click,
          number_of_32th_nodes_per_24_clocks
        ]
      end
    end

    KeySignature = Struct.new(:sharps_or_flats, :is_major) do
      def bytes
        [
          0xFF, 0x59, 0x02,
          sharps_or_flats,
          is_major ? 0 : 1
        ]
      end
    end

    ProgramChange = Struct.new(:channel, :program_number) do
      def bytes
        raise "Channel too big: #{channel}" if channel > 15
        raise "Program number is too big: #{program_number}" if program_number > 255
        [
          0xC0 + channel,
          program_number
        ]
      end
    end

    NoteOn = Struct.new(:channel, :key) do
      def bytes
        raise "Channel too big: #{channel}" if channel > 15
        raise "Key is too big: #{key}" if key > 255
        [
          0x90 + channel,
          key,
          40 # Default velocity
        ]
      end
    end

    NoteOff = Struct.new(:channel, :key) do
      def bytes
        raise "Channel too big: #{channel}" if channel > 15
        raise "Key is too big: #{key}" if key > 255
        [
          0x80 + channel,
          key,
          40 # Default velocity
        ]
      end
    end

    def initialize(synths)
      @synths = synths
    end

    def write_to(path)
      track = build_track

      File.open(path, 'wb') do |file|
        write_header(file)
        write_track(file, track)
      end
    end

    def build_track
      waveforms = [:tri, :saw, :pulse, :noise]
      frames_and_events = []

      @synths.each_with_index do |synths_for_voice, voice_number|
        synths_for_voice.each do |synth|
          channel = voice_number * 4 + (waveforms.index(synth.waveform) || raise("Unknown waveform #{synth.waveform}"))
          frames_and_events << [synth.start_frame, NoteOn[channel, synth.tone]]
          duration = [1, (FRAMES_PER_SECOND * (synth.attack + synth.decay + synth.sustain_length)).to_i].max
          frames_and_events << [synth.start_frame + duration, NoteOff[channel, synth.tone]]
        end
      end

      track = []
      current_frame = 0
      frames_and_events.sort_by(&:first).each do |frame, event|
        track << DeltaTime[frame - current_frame]
        track << event
        current_frame = frame
      end
      track
    end

    private
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

    def write_track(file, track)
      track_with_metadata = [
        DeltaTime[0], TimeSignature[4, 2, 24, 8],
        DeltaTime[0], KeySignature[0, 0],
        # Voice 1
        DeltaTime[0], ProgramChange[0, 1],
        DeltaTime[0], ProgramChange[1, 2],
        DeltaTime[0], ProgramChange[2, 3],
        DeltaTime[0], ProgramChange[3, 4],
        # Voice 2
        DeltaTime[0], ProgramChange[4, 1],
        DeltaTime[0], ProgramChange[5, 2],
        DeltaTime[0], ProgramChange[6, 3],
        DeltaTime[0], ProgramChange[7, 4],
        # Voice 3
        DeltaTime[0], ProgramChange[8, 1],
        DeltaTime[0], ProgramChange[9, 2],
        DeltaTime[0], ProgramChange[10, 3],
        DeltaTime[0], ProgramChange[11, 4]
      ] + track
      track_bytes = track_with_metadata.flat_map(&:bytes)

      # Type
      file << 'MTrk'

      # Length
      write_uint32(file, track_bytes.length)

      # Track
      file << track_bytes.pack('c' * track_bytes.length)

      # "End of track"
      file << [0xFF, 0x2F, 0x00].pack('ccc')
    end

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
  end
end
