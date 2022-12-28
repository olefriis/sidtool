require 'sidtool/version'
require_relative 'sidtool/mos6502/th8.rb' # For Bus
require_relative 'sidtool/mos6502/cpudsl'
require_relative 'sidtool/mos6502/cpu6502'

module Sidtool
  require 'sidtool/file_reader'
  require 'sidtool/ruby_file_writer'
  require 'sidtool/midi_file_writer'
  require 'sidtool/synth'
  require 'sidtool/voice'
  require 'sidtool/sid'
  require 'sidtool/state'

  # PAL properties
  FRAMES_PER_SECOND = 50.0
  CLOCK_FREQUENCY = 985248.0

  STATE = State.new
end
