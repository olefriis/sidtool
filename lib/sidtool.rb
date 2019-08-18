require 'sidtool/version'

module Sidtool
  require 'sidtool/synth'
  require 'sidtool/voice'
  require 'sidtool/sid'
  require 'sidtool/state'

  # PAL properties
  FRAMES_PER_SECOND = 50.0
  CLOCK_FREQUENCY = 985248.0

  STATE = State.new
end
