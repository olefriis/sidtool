module CPUDSL
  def self.newcpu(name, bits)
    Class.new do
      self.instance_variable_set(:@__name, name)
      self.instance_variable_set(:@__bits, bits)
      self.instance_variable_set(:@__regs, {})
      self.instance_variable_set(:@__disasm, {}) # Layout: [mnemonic_format_string, operand_bytes, reverse_order?]

      def initialize(bus)
        @__bus = bus
        @__cycles = 0
        self.class.instance_variable_get(:@__regs).each { |(reg,init)| self.instance_variable_set(reg, init) }
        if self.respond_to?(:cpu_init)
          cpu_init
        end
      end

      def set_cycles(count)
        @__cycles = count
      end

      def decrement_cycles
        @__cycles -= 1
      end

      def cycles_remaining
        @__cycles
      end

      def disassemble(opcode, addr=program_counter)
        format_string, operands, reverse = self.class.instance_variable_get(:@__disasm).fetch(opcode, ["DB #{sprintf('%02X', opcode)}", 0, false])
        operand_bytes_ = (1..operands).map { |offset| @__bus.read(addr + offset) }
        operand_bytes  = reverse ? operand_bytes_.reverse : operand_bytes_
        [sprintf(format_string, *operand_bytes), operands]
      end

      def self.defregister(name, init=0x00, bits=nil)
        bits ||= self.instance_variable_get(:@__bits)
        self.instance_variable_get(:@__regs)["@register_#{name}"] = init

        self.define_method("register_#{name}") { self.instance_variable_get("@register_#{name}") }
        self.define_method("set_register_#{name}") { |val| self.instance_variable_set("@register_#{name}", (val & ((1 << bits) - 1))) }
      end

      def self.defstack(name, base=0x00, direction=:+, init=0x00, bits=nil)
        bits ||= self.instance_variable_get(:@__bits)
        self.instance_variable_get(:@__regs)["@register_#{name}"] = init

        self.define_method("register_#{name}") { self.instance_variable_get("@register_#{name}") }
        self.define_method("set_register_#{name}") { |val| self.instance_variable_set("@register_#{name}", (val & ((1 << bits) - 1))) }
        self.define_method("stack_#{name}_push") do |val_|
          val    = val_ & ((1 << bits) - 1)
          offset = self.instance_variable_get("@register_#{name}")
          @__bus.write(base + offset, val)
          self.send("set_register_#{name}", offset.send(direction, (bits / 8)))
        end
        self.define_method("stack_#{name}_pop") do
          offset = self.instance_variable_get("@register_#{name}").send(direction, (1 << bits) - (bits / 8))
          self.send("set_register_#{name}", offset)
          @__bus.read(base + self.send("register_#{name}"))
        end
      end

      def self.defpc(name, init=0x0000, bits=nil)
        bits ||= self.instance_variable_get(:@__bits)
        self.instance_variable_get(:@__regs)["@register_#{name}"] = init

        self.define_method("program_counter") { self.instance_variable_get("@register_#{name}") }

        self.instance_variable_set("@register_#{name}", 0)
        self.define_method("register_#{name}") { self.instance_variable_get("@register_#{name}") }
        self.define_method("set_register_#{name}") { |val| self.instance_variable_set("@register_#{name}", (val & ((1 << bits) - 1))) }
        self.define_method(:read_advance_pc) do
          pc = self.instance_variable_get("@register_#{name}")
          x = @__bus.read(pc)
          self.instance_variable_set("@register_#{name}", ((pc + 1) & ((1 << bits) - 1)))
          x
        end
      end

      def self.defflags(name, init = 0x00, bits=nil)
        bits ||= self.instance_variable_get(:@__bits)
        self.instance_variable_get(:@__regs)["@register_#{name}"] = init

        self.instance_variable_set("@register_#{name}", 0)
        self.instance_variable_set(:@__flags_register, "@register_#{name}")
        self.instance_variable_set(:@__flags_register_mask, ((1 << bits) - 1))
        self.define_method("register_#{name}") { self.instance_variable_get("@register_#{name}") }
        self.define_method("set_register_#{name}") { |val| self.instance_variable_set("@register_#{name}", (val & ((1 << bits) - 1))) }
      end

      def self.defflag(name, bit)
        self.define_method("flag_#{name}") { (self.instance_variable_get(self.class.instance_variable_get(:@__flags_register)) & (1 << bit)) >> bit }
        self.define_method("set_flag_#{name}") do |val|
          mask = self.class.instance_variable_get(:@__flags_register_mask)
          old_flags = self.instance_variable_get(self.class.instance_variable_get(:@__flags_register))
          new_flags = (old_flags & (mask ^ (1 << bit))) | ((val & 1) << bit)
          self.instance_variable_set(self.class.instance_variable_get(:@__flags_register), new_flags)
        end
      end

      def self.definit(&routine)
        self.define_method(:cpu_init, &routine)
      end

      def self.defop(opcode, mnemonic, operands, reverse_bytes=false, &routine)
        self.define_method("op_#{opcode}", &routine)
        self.instance_variable_get(:@__disasm)[opcode] = [mnemonic, operands, reverse_bytes]
      end

      def self.defclock(&routine)
        self.define_method(:clock, &routine)
      end
    end
  end
end
