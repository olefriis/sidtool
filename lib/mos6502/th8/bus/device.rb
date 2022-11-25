module TH8
  class Bus
    Device = Struct.new(:name, :range_start, :range_end) do
      def to_s
        "<Device:#{name} (#{'%0x' % range_start} - #{'%0x' % range_end})>"
      end

      def read(offset)
        0
      end

      def write(offset, data)
        0
      end

      def alloc(size, default = 0)
        @mem = [default] * size
      end

      def set_read(&fn)
        self.define_singleton_method(:read, &fn)
      end

      def set_write(&fn)
        self.define_singleton_method(:write, &fn)
      end

      def dump(offset, size)
        (0...size).map { |addr| read(offset+addr) }
      end
    end
  end
end
