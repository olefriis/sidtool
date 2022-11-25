module TH8
  class CPU
    Opcode = Struct.new(:mnemonic, :cycles, :byte_args, :fn) do
      def bind_instance(object)
        new_op = self.dup
        new_op.fn = new_op.fn.bind(object)
        new_op
      end

      def inspect
        mnemonic
      end

      def to_s(mem)
        "#{mnemonic} #{mem.map(&'$%02x'.method(:%)).join(' ')}"
      end
    end
  end
end
