require 'th8/bus/device'

module TH8
  class Bus
    def initialize
      @attached = []
    end

    def attach(name, range_start, range_end)
      new_device = Device.new(name, range_start, range_end)
      @attached << new_device
      new_device
    end

    def write(addr, data)
      @attached
        .select { |d| d.range_start <= addr && d.range_end >= addr }
        .take(1)
        .map    { |d| d.write(addr - d.range_start, data) }
        .first
    end

    def read(addr)
      @attached
        .select { |d| d.range_start <= addr && d.range_end >= addr }
        .take(1)
        .map    { |d| d.read(addr - d.range_start) }
        .first
    end

    def inspect
      "<Bus: [#{@attached.map(&:inspect)}]>"
    end

    def to_s
      "<Bus: [#{@attached.map(&:inspect)}]>"
    end

    def dump(start_addr, size, cols=0x10)
      @attached
        .select   { |d| d.range_start <= start_addr && d.range_end >= (start_addr + size) }
        .take(1)
        .flat_map { |d| d.dump(start_addr - d.range_start, size) }
        .map(&'%02x'.method(:%))
        .each_slice(cols)
        .map { |slice| slice.join(' ') }
        .join("\n")
    end
  end
end
