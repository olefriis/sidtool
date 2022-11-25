require 'th8/cpu/opcode'

module TH8
  class CPU
    def initialize(bus)
      @bus = bus
      @pc  = 0x8000
      @s   = 0x00 # 0x100 - 0x1ff
      @a   = 0x00
      @x   = 0x00

      # Flags:
      # NVxB xIZC
      # |||| |||+- Carry
      # |||| ||+-- Zero
      # |||| |+--- Interrupt Disable
      # |||| +---- Unused
      # |||+------ Break
      # ||+------- Unused
      # |+-------- Overflow
      # +--------- Negative
      @f   = 0x00

      @opcodes = self.class.instance_variable_get(:@__OPCODES).map { |op| op.bind_instance(self) }

      @cycles_remaining = 0
    end

    def negative_flag
      (@f & 0x80) >> 7
    end

    def overflow_flag
      (@f & 0x40) >> 6
    end

    def break_flag
      (@f & 0x10) >> 4
    end

    def irq_flag
      (@f & 0x04) >> 2
    end

    def zero_flag
      (@f & 0x02) >> 1
    end

    def carry_flag
      (@f & 0x1)
    end

    def zero_set(b)
      @f |= (b & 0x01) << 1
    end

    def break_set
      @f |= 1          << 4
    end

    def overflow_set(b)
      @f |= (b & 0x01) << 6
    end

    def clock
      return self if break_flag.nonzero?

      if @cycles_remaining < 1
        opcode = readpc

        inst = @opcodes[opcode]
        inst.fn.call()
        @cycles_remaining = inst.cycles
      end

      @cycles_remaining -= 1
      self
    end

    # [byte]
    def load(program)
      program.each_with_index { |b,i| @bus.write(0x8000+i, b) }
      self
    end

    # BRK - 0x00
    # INC A - 0x82
    # INC X - 0x81
    # NOP - 0xff

    private

    def readpc
      x = @bus.read(@pc)
      @pc = (@pc + 1) & 0xffff
      x
    end

    def self.definst(mnemonic, opcode, cycles, byte_args, &fn)
      op = mnemonic.downcase

      self.define_method(op, &fn)

      new_op = ::TH8::CPU::Opcode.new(mnemonic, cycles, byte_args, self.instance_method(op))
      self.instance_variable_get(:@__OPCODES)[opcode] = new_op
    end

    nop = ::TH8::CPU::Opcode.new('NOP', 1, 0, nil)
    self.instance_variable_set(:@__OPCODES, [nop] * 0x100)

    definst('NOP', 0x01, 1, 0) do
    end
    nop.fn = self.instance_method(:nop)

    definst('INA', 0x82, 1, 0) do
      @a = (@a + 1) & 0xff

      zo = @a.zero? ? 1 : 0
      zero_set(zo)
      overflow_set(zo)
    end

    definst('INX', 0x81, 1, 0) do
      @x = (@x + 1) & 0xff

      zo = @x.zero? ? 1 : 0
      zero_set(zo)
      overflow_set(zo)
    end

    definst('BRK', 0x00, 1, 0) do
      break_set
    end
  end
end
