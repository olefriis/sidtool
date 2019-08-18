module Sidtool
  class State
    attr_accessor :current_frame
    attr_accessor :synths

    def initialize
      @current_frame = 0
      @synths = []
    end
  end
end
