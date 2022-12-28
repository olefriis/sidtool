require_relative 'cpudsl'

MOS6502 = Mos6502::CPUDSL.newcpu('MOS 6502', 8)

MOS6502.defregister('X')
MOS6502.defregister('Y')
MOS6502.defregister('A')
MOS6502.defstack('S', 0x0100, :-, 0xFD)
MOS6502.defpc('PC', 0x8000, 16)

# Flags:
# NVxB DIZC
# |||| |||+- Carry
# |||| ||+-- Zero
# |||| |+--- Interrupt Disable
# |||| +---- Decimal (Unused for Ricoh chip)
# |||+------ Break
# ||+------- NMI/Unused
# |+-------- Overflow
# +--------- Negative
MOS6502.defflags('F', 0x24)
MOS6502.defflag('C', 0)
MOS6502.defflag('Z', 1)
MOS6502.defflag('I', 2)
MOS6502.defflag('D', 3)
MOS6502.defflag('B', 4)
MOS6502.defflag('b', 5)
MOS6502.defflag('V', 6)
MOS6502.defflag('N', 7)

MOS6502.defclock do
  #return self if flag_B.nonzero?

  if cycles_remaining < 1
    opcode = read_advance_pc
    self.send("op_#{opcode}")
  end

  decrement_cycles
  self
end

# Define boilerplate reads for addressing modes
MOS6502.define_method(:immediate) do
  read_advance_pc
end

MOS6502.define_method(:zero_page) do
  read_advance_pc
end

MOS6502.define_method(:zero_page_x) do
  addr = read_advance_pc
  (addr + register_X) & 0xff
end

MOS6502.define_method(:zero_page_y) do
  addr = read_advance_pc
  (addr + register_Y) & 0xff
end

MOS6502.define_method(:absolute) do
  addr_lsb = read_advance_pc
  addr_msb = read_advance_pc
  (addr_msb << 8) | addr_lsb
end

MOS6502.define_method(:absolute_x) do
  addr_lsb  = read_advance_pc
  addr_msb  = read_advance_pc
  addr_base = (addr_msb << 8) | addr_lsb
  addr_eff  = addr_base + register_X
  extra     = ((addr_base & 0xff00) == (addr_eff & 0xff00)) ? 0 : 1

  [(addr_eff & 0xffff),extra]
end

MOS6502.define_method(:absolute_y) do
  addr_lsb  = read_advance_pc
  addr_msb  = read_advance_pc
  addr_base = (addr_msb << 8) | addr_lsb
  addr_eff  = addr_base + register_Y
  extra     = ((addr_base & 0xff00) == (addr_eff & 0xff00)) ? 0 : 1

  [(addr_eff & 0xffff),extra]
end

MOS6502.define_method(:indirect_x) do
  addr_zp  = (read_advance_pc + register_X) & 0xff
  addr_lsb = @__bus.read(addr_zp)
  addr_msb = @__bus.read((addr_zp + 1) & 0xff)
  addr_eff = (addr_msb << 8) | addr_lsb

  addr_eff
end

MOS6502.define_method(:indirect_y) do
  addr_zp   = read_advance_pc
  addr_lsb  = @__bus.read(addr_zp)
  addr_msb  = @__bus.read((addr_zp + 1) & 0xff)
  addr_base = (addr_msb << 8) | addr_lsb
  addr_eff  = addr_base + register_Y
  extra     = ((addr_base & 0xff00) == (addr_eff & 0xff00)) ? 0 : 1

  [(addr_eff & 0xffff), extra]
end

# Boilerplate ADC logic
MOS6502.define_method(:perform_adc) do |operand|
  result = register_A + operand + flag_C

  # Calculate V flag
  result_N = (result & 0x80) >> 7
  orig_A_N = (register_A & 0x80) >> 7
  orig_B_N = (operand & 0x80) >> 7
  oVerflow = (1 ^ (orig_A_N ^ orig_B_N)) & (orig_A_N ^ result_N)

  set_flag_C((result & 0x100) >> 8)
  set_flag_N(result_N)
  set_flag_Z((result & 0xff) == 0 ? 1 : 0)
  set_flag_V(oVerflow)
  set_register_A(result)
end

# Boilerplate AND logic
MOS6502.define_method(:perform_and) do |operand|
  result = register_A & operand

  result_N = (result & 0x80) >> 7

  set_flag_N(result_N)
  set_flag_Z((result & 0xff) == 0 ? 1 : 0)
  set_register_A(result)
end

# Boilerplate ASL logic
MOS6502.define_method(:perform_asl) do |operand|
  byte   = @__bus.read(operand) << 1
  result = byte & 0xff

  result_N = (result & 0x80) >> 7

  set_flag_C((byte & 0x100) >> 8)
  set_flag_N(result_N)
  set_flag_Z((result) == 0 ? 1 : 0)

  @__bus.write(operand, result)
end

# Boilerplate BRANCH logic
MOS6502.define_method(:perform_branch) do |offset|
  set_cycles(3)

  # Add 1 cycle if branch taken AND cross a page boundary
  old_pc = register_PC
  jump = (0x80 & offset).nonzero? ? ~(0xff ^ offset) : offset
  new_pc = jump + old_pc
  set_cycles(4) if (new_pc & 0xff00) != (old_pc & 0xff00)

  set_register_PC(new_pc)
end

# Boilerplate CMP logic
MOS6502.define_method(:perform_comparison) do |value, register|
  set_flag_N((((register + 0x100) - (value & 0xFF)) & 0x80) >> 7)
  set_flag_Z(value == register ? 1 : 0)
  set_flag_C(register >= value ? 1 : 0)
end

# Boilerplate DEC logic
MOS6502.define_method(:perform_dec) do |operand|
  byte   = @__bus.read(operand) - 1
  result = (byte + 0x100) & 0xff

  result_N = (result & 0x80) >> 7

  set_flag_N(result_N)
  set_flag_Z((result) == 0 ? 1 : 0)

  @__bus.write(operand, result)
end

# Boilerplate EOR logic
MOS6502.define_method(:perform_eor) do |operand|
  result = register_A ^ operand

  result_N = (result & 0x80) >> 7
  set_flag_N(result_N)
  set_flag_Z((result) == 0 ? 1 : 0)
  set_register_A(result)
end

# Boilerplate INC logic
MOS6502.define_method(:perform_inc) do |operand|
  byte   = @__bus.read(operand) + 1
  result = byte & 0xff

  result_N = (result & 0x80) >> 7

  set_flag_N(result_N)
  set_flag_Z((result) == 0 ? 1 : 0)

  @__bus.write(operand, result)
end

# Boilerplate LDA logic
MOS6502.define_method(:perform_lda) do |operand|
  set_register_A(operand)

  set_flag_N((operand & 0x80) >> 7)
  set_flag_Z((operand == 0) ? 1 : 0)
end

# Boilerplate LDX logic
MOS6502.define_method(:perform_ldx) do |operand|
  set_register_X(operand)

  set_flag_N((operand & 0x80) >> 7)
  set_flag_Z(operand == 0 ? 1 : 0)
end

# Boilerplate LDY logic
MOS6502.define_method(:perform_ldy) do |operand|
  set_register_Y(operand)

  set_flag_N((operand & 0x80) >> 7)
  set_flag_Z(operand == 0 ? 1 : 0)
end

# Boilerplate LSR logic
MOS6502.define_method(:perform_lsr) do |operand|
  byte   = @__bus.read(operand)
  result = byte >> 1

  set_flag_C(byte & 0x01)
  set_flag_N(0)
  set_flag_Z((result == 0) ? 1 : 0)

  @__bus.write(operand, result)
end

# Boilerplate ORA logic
MOS6502.define_method(:perform_ora) do |operand|
  result = register_A | operand

  result_N = (result & 0x80) >> 7
  set_flag_N(result_N)
  set_flag_Z((result) == 0 ? 1 : 0)
  set_register_A(result)
end

# Boilerplate ROL logic
MOS6502.define_method(:perform_rol) do |operand|
  byte   = @__bus.read(operand)
  result = ((byte << 1) & 0xff) | flag_C

  result_N = (result & 0x80) >> 7

  set_flag_C((byte & 0x80) >> 7)
  set_flag_N(result_N)
  set_flag_Z(result == 0 ? 1 : 0)

  @__bus.write(operand, result)
end

# Boilerplate ROR logic
MOS6502.define_method(:perform_ror) do |operand|
  byte   = @__bus.read(operand)
  result = (byte >> 1) | (flag_C << 7)

  result_N = (result & 0x80) >> 7

  set_flag_C(byte & 0x01)
  set_flag_N(result_N)
  set_flag_Z(result == 0 ? 1 : 0)

  @__bus.write(operand, result)
end

# Boilerplate SBC logic
MOS6502.define_method(:perform_sbc) do |operand_|
  operand = 0xff ^ operand_
  result  = register_A + operand + flag_C

  # Calculate V flag
  result_N = (result & 0x80) >> 7
  orig_A_N = (register_A & 0x80) >> 7
  orig_B_N = (operand & 0x80) >> 7
  oVerflow = (1 ^ (orig_A_N ^ orig_B_N)) & (orig_A_N ^ result_N)

  set_flag_C((result & 0x100) >> 8)
  set_flag_N(result_N)
  set_flag_Z(((result & 0xff) == 0) ? 1 : 0)
  set_flag_V(oVerflow)
  set_register_A(result)
end

# Boilerplate STA logic
MOS6502.define_method(:perform_sta) do |operand|
  @__bus.write(operand, register_A)
end

# Boilerplate STX logic
MOS6502.define_method(:perform_stx) do |operand|
  @__bus.write(operand, register_X)
end

# Boilerplate STY logic
MOS6502.define_method(:perform_sty) do |operand|
  @__bus.write(operand, register_Y)
end

# Boilerplate *LAX logic
MOS6502.define_method(:perform_lax) do |operand|
  set_register_X(operand)
  set_register_A(operand)
  set_flag_N(operand >> 7)
  set_flag_Z((operand == 0) ? 1 : 0)
end

# Boilerplate *SAX logic
MOS6502.define_method(:perform_sax) do |operand|
  result = register_X & register_A

  @__bus.write(operand, result)
end

# Boilerplate *DCP logic
MOS6502.define_method(:perform_dcp) do |operand|
  byte = @__bus.read(operand)
  result = (byte + 0xff) & 0xff
  @__bus.write(operand, result)

  perform_comparison(result, register_A)
end

# Boilerplate *ISB logic
MOS6502.define_method(:perform_isb) do |operand|
  byte = @__bus.read(operand)
  result = (byte + 1) & 0xff
  @__bus.write(operand, result)

  perform_sbc(result)
end

# Boilerplate *ISB logic
MOS6502.define_method(:perform_slo) do |operand|
  byte = @__bus.read(operand)
  result = (byte << 1) & 0xff
  @__bus.write(operand, result)

  set_flag_C(byte >> 7)
  perform_ora(result)
end

# Boilerplate *RLA logic
MOS6502.define_method(:perform_rla) do |operand|
  byte = @__bus.read(operand)
  result = ((byte << 1) | flag_C) & 0xff
  @__bus.write(operand, result)

  set_flag_C((byte & 0x80) >> 7)
  perform_and(result)
end

# Boilerplate *SRE logic
MOS6502.define_method(:perform_sre) do |operand|
  byte = @__bus.read(operand)
  result = (byte >> 1)
  @__bus.write(operand, result)

  set_flag_C(byte & 0x01)
  perform_eor(result)
end

# Boilerplate *RRA logic
MOS6502.define_method(:perform_rra) do |operand|
  byte = @__bus.read(operand)
  result = (byte >> 1) | (flag_C << 7)
  @__bus.write(operand, result)

  set_flag_C(byte & 0x01)
  perform_adc(result)
end

# ADd with Carry
# P + P = P -> x
# N + N = N -> x
# P + P = N -> V
# N + N = P -> V
# P + N = P -> X
# A B R | V
# 1 1 1 | 0
# 1 1 0 | 1
# 1 0 1 | 0
# 1 0 0 | 0
# 0 1 1 | 0
# 0 1 0 | 0
# 0 0 1 | 1
# 0 0 0 | 0

# Immediate
MOS6502.defop(0x69, 'ADC #$%02x', 1) do
  perform_adc(immediate)
  set_cycles(2)
end

# Zero Page
MOS6502.defop(0x65, 'ADC $%02x', 1) do
  perform_adc(@__bus.read(zero_page))
  set_cycles(3)
end

# Zero Page, X offset
MOS6502.defop(0x75, 'ADC $%02x,X', 1) do
  perform_adc(@__bus.read(zero_page_x))
  set_cycles(4)
end

# Absolute
MOS6502.defop(0x6D, 'ADC $%02x%02x', 2) do
  perform_adc(@__bus.read(absolute))
  set_cycles(4)
end

# Absolute, X offset
MOS6502.defop(0x7D, 'ADC $%02x%02x,X', 2) do
  operand,extra = absolute_x
  perform_adc(@__bus.read(operand))
  set_cycles(4 + extra)
end

# Absolute, Y offset
MOS6502.defop(0x79, 'ADC $%02x%02x,Y', 2) do
  operand,extra = absolute_y
  perform_adc(@__bus.read(operand))
  set_cycles(4 + extra)
end

# Indirect, X offset
MOS6502.defop(0x61, 'ADC ($%02x,X)', 1) do
  perform_adc(@__bus.read(indirect_x))
  set_cycles(6)
end

# Indirect, Y offset
MOS6502.defop(0x71, 'ADC ($%02x),Y', 1) do
  operand,extra = indirect_y
  perform_adc(@__bus.read(operand))
  set_cycles(5 + extra)
end

# ** AND **

# Immediate
MOS6502.defop(0x29, 'AND #$%02x', 1) do
  operand = immediate
  perform_and(operand)
  set_cycles(2)
end

# Zero Page
MOS6502.defop(0x25, 'AND $%02x', 1) do
  perform_and(@__bus.read(zero_page))
  set_cycles(3)
end

# Zero Page, X offset
MOS6502.defop(0x35, 'AND $%02x,X', 1) do
  perform_and(@__bus.read(zero_page_x))
  set_cycles(4)
end

# Absolute
MOS6502.defop(0x2D, 'AND $%02x%02x', 2) do
  perform_and(@__bus.read(absolute))
  set_cycles(4)
end

# Absolute, X offset
MOS6502.defop(0x3D, 'AND $%02x%02x,X', 2) do
  operand,extra = absolute_x
  perform_and(@__bus.read(operand))
  set_cycles(4 + extra)
end

# Absolute, Y offset
MOS6502.defop(0x39, 'AND $%02x%02x,Y', 2) do
  operand,extra = absolute_y
  perform_and(@__bus.read(operand))
  set_cycles(4 + extra)
end

# Indirect, X offset
MOS6502.defop(0x21, 'AND ($%02x,X)', 1) do
  addy = indirect_x
  perform_and(@__bus.read(addy))
  set_cycles(6)
end

# Indirect, Y offset
MOS6502.defop(0x31, 'AND ($%02x),Y', 1) do
  operand,extra = indirect_y
  perform_and(@__bus.read(operand))
  set_cycles(5 + extra)
end

# ** ASL **

# A Register
MOS6502.defop(0x0A, 'ASL A', 0) do
  byte     = register_A << 1
  result   = byte & 0xff
  result_N = (result & 0x80) >> 7

  set_flag_C((byte & 0x100) >> 8)
  set_flag_N(result_N)
  set_flag_Z((result) == 0 ? 1 : 0)

  set_register_A(result)
  set_cycles(2)
end

# Zero Page
MOS6502.defop(0x06, 'ASL $%02x', 1) do
  set_cycles(5)
  perform_asl(zero_page)
end

# Zero Page, X offset
MOS6502.defop(0x16, 'ASL $%02x,X', 1) do
  perform_asl(zero_page_x)
  set_cycles(6)
end

# Absolute
MOS6502.defop(0x0E, 'ASL $%02x%02x', 2) do
  perform_asl(absolute)
  set_cycles(6)
end

# Absolute, X offset
MOS6502.defop(0x1E, 'ASL $%02x%02x,X', 2) do
  operand,_extra = absolute_x
  perform_asl(operand)
  set_cycles(7)
end

# ** BIT **

# Zero Page
MOS6502.defop(0x24, 'BIT $%02x', 1) do
  value = @__bus.read(zero_page)
  set_cycles(3)

  set_flag_Z((value & register_A == 0) ? 1 : 0)
  set_flag_N((value & 0x80) >> 7)
  set_flag_V((value & 0x40) >> 6)
end

# Absolute
MOS6502.defop(0x2C, 'BIT $%02x%02x', 2) do
  value = @__bus.read(absolute)
  set_cycles(4)

  set_flag_Z((value & register_A == 0) ? 1 : 0)
  set_flag_N((value & 0x80) >> 7)
  set_flag_V((value & 0x40) >> 6)
end

# ** BRANCH INSTRUCTIONS **

# Branch on PLus
MOS6502.defop(0x10, 'BPL #$%02x', 1) do
  offset = read_advance_pc
  set_cycles(2)
  perform_branch(offset) if flag_N.zero?
end

# Branch on MInus
MOS6502.defop(0x30, 'BMI #$%02x', 1) do
  offset = read_advance_pc
  set_cycles(2)
  perform_branch(offset) if flag_N.nonzero?
end

# Branch on oVerflow Clear
MOS6502.defop(0x50, 'BVC #$%02x', 1) do
  offset = read_advance_pc
  set_cycles(2)
  perform_branch(offset) if flag_V.zero?
end

# Branch on oVerflow Set
MOS6502.defop(0x70, 'BVS #$%02x', 1) do
  offset = read_advance_pc
  set_cycles(2)
  perform_branch(offset) if flag_V.nonzero?
end

# Branch on Carry Clear
MOS6502.defop(0x90, 'BCC #$%02x', 1) do
  offset = read_advance_pc
  set_cycles(2)
  perform_branch(offset) if flag_C.zero?
end

# Branch on Carry Set
MOS6502.defop(0xB0, 'BCS #$%02x', 1) do
  offset = read_advance_pc
  set_cycles(2)
  perform_branch(offset) if flag_C.nonzero?
end

# Branch on Not Equal
MOS6502.defop(0xD0, 'BNE #$%02x', 1) do
  offset = read_advance_pc
  set_cycles(2)
  perform_branch(offset) if flag_Z.zero?
end

# Branch on Equal
MOS6502.defop(0xF0, 'BEQ #$%02x', 1) do
  offset = read_advance_pc
  set_cycles(2)
  perform_branch(offset) if flag_Z.nonzero?
end

# BReaK
MOS6502.defop(0x00, 'BRK', 0) do
  set_cycles(7)
  set_flag_B(1)
end

# ** CoMPare accumulator **

# Immediate
MOS6502.defop(0xC9, 'CMP #$%02x', 1) do
  perform_comparison(immediate, register_A)
  set_cycles(2)
end

# Zero Page
MOS6502.defop(0xC5, 'CMP $%02x', 1) do
  perform_comparison(@__bus.read(zero_page), register_A)
  set_cycles(3)
end

# Zero Page, X offset
MOS6502.defop(0xD5, 'CMP $%02x,X', 1) do
  perform_comparison(@__bus.read(zero_page_x), register_A)
  set_cycles(4)
end

# Absolute
MOS6502.defop(0xCD, 'CMP $%02x%02x', 2) do
  perform_comparison(@__bus.read(absolute), register_A)
  set_cycles(4)
end

# Absolute, X offset
MOS6502.defop(0xDD, 'CMP $%02x%02x,X', 2) do
  value,extra = absolute_x
  perform_comparison(@__bus.read(value), register_A)
  set_cycles(4 + extra)
end

# Absolute, Y offset
MOS6502.defop(0xD9, 'CMP $%02x%02x,Y', 2) do
  value,extra = absolute_y
  perform_comparison(@__bus.read(value), register_A)
  set_cycles(4 + extra)
end

# Indirect, X offset
MOS6502.defop(0xC1, 'CMP ($%02x,X)', 2) do
  perform_comparison(@__bus.read(indirect_x), register_A)
  set_cycles(6)
end

# Indirect, Y offset
MOS6502.defop(0xD1, 'CMP ($%02x),Y', 2) do
  value,extra = indirect_y
  perform_comparison(@__bus.read(value), register_A)
  set_cycles(5 + extra)
end

# ** ComPare X **

# Immediate
MOS6502.defop(0xE0, 'CPX #$%02x', 1) do
  perform_comparison(immediate, register_X)
  set_cycles(2)
end

# Zero Page
MOS6502.defop(0xE4, 'CPX $%02x', 1) do
  perform_comparison(@__bus.read(zero_page), register_X)
  set_cycles(3)
end

# Absolute
MOS6502.defop(0xEC, 'CPX $%02x%02x', 2) do
  perform_comparison(@__bus.read(absolute), register_X)
  set_cycles(4)
end

# ** ComPare Y **

# Immediate
MOS6502.defop(0xC0, 'CPY #$%02x', 1) do
  perform_comparison(immediate, register_Y)
  set_cycles(2)
end

# Zero Page
MOS6502.defop(0xC4, 'CPY $%02x', 1) do
  perform_comparison(@__bus.read(zero_page), register_Y)
  set_cycles(3)
end

# Absolute
MOS6502.defop(0xCC, 'CPY $%02x%02x', 2) do
  perform_comparison(@__bus.read(absolute), register_Y)
  set_cycles(4)
end

# ** DEC **

# Zero Page
MOS6502.defop(0xC6, 'DEC $%02x', 1) do
  perform_dec(zero_page)
  set_cycles(5)
end

# Zero Page, X offset
MOS6502.defop(0xD6, 'DEC $%02x,X', 1) do
  perform_dec(zero_page_x)
  set_cycles(6)
end

# Absolute
MOS6502.defop(0xCE, 'DEC $%02x%02x', 2) do
  perform_dec(absolute)
  set_cycles(6)
end

# Absolute, X offset
MOS6502.defop(0xDE, 'DEC $%02x%02x,X', 2) do
  operand,_extra = absolute_x
  perform_dec(operand)
  set_cycles(7)
end

# ** Exclusive OR **

# Immediate
MOS6502.defop(0x49, 'EOR #$%02x', 1) do
  perform_eor(immediate)
  set_cycles(2)
end

# Zero Page
MOS6502.defop(0x45, 'EOR $%02x', 1) do
  perform_eor(@__bus.read(zero_page))
  set_cycles(3)
end

# Zero Page, X offset
MOS6502.defop(0x55, 'EOR $%02x,X', 1) do
  perform_eor(@__bus.read(zero_page_x))
  set_cycles(4)
end

# Absolute
MOS6502.defop(0x4D, 'EOR $%02x%02x', 2) do
  perform_eor(@__bus.read(absolute))
  set_cycles(4)
end

# Absolute, X offset
MOS6502.defop(0x5D, 'EOR $%02x%02x,X', 2) do
  operand,extra = absolute_x
  perform_eor(@__bus.read(operand))
  set_cycles(4 + extra)
end

# Absolute, Y offset
MOS6502.defop(0x59, 'EOR $%02x%02x,Y', 2) do
  operand,extra = absolute_y
  perform_eor(@__bus.read(operand))
  set_cycles(4 + extra)
end

# Indirect, X offset
MOS6502.defop(0x41, 'EOR ($%02x,X)', 1) do
  perform_eor(@__bus.read(indirect_x))
  set_cycles(6)
end

# Indirect, Y offset
MOS6502.defop(0x51, 'EOR ($%02x),Y', 1) do
  operand,extra = indirect_y
  perform_eor(@__bus.read(operand))
  set_cycles(5 + extra)
end

# ** FLAG Instructions **

# CLear Carry
MOS6502.defop(0x18, 'CLC', 0) do
  set_cycles(2)
  set_flag_C(0)
end

# SEt Carry
MOS6502.defop(0x38, 'SEC', 0) do
  set_cycles(2)
  set_flag_C(1)
end

# CLear Interrupt
MOS6502.defop(0x58, 'CLI', 0) do
  set_cycles(2)
  set_flag_I(0)
end

# SEt Interrupt
MOS6502.defop(0x78, 'SEI', 0) do
  set_cycles(2)
  set_flag_I(1)
end

# CLear oVerflow
MOS6502.defop(0xB8, 'CLV', 0) do
  set_cycles(2)
  set_flag_V(0)
end

# CLear Decimal
MOS6502.defop(0xD8, 'CLD', 0) do
  set_cycles(2)
  set_flag_D(0)
end

# SEt Decimal
MOS6502.defop(0xF8, 'SED', 0) do
  set_cycles(2)
  set_flag_D(1)
end

# ** Exclusive OR **

# Zero Page
MOS6502.defop(0xE6, 'INC $%02x', 1) do
  perform_inc(zero_page)
  set_cycles(5)
end

# Zero Page, X offset
MOS6502.defop(0xF6, 'INC $%02x,X', 1) do
  perform_inc(zero_page_x)
  set_cycles(6)
end

# Absolute
MOS6502.defop(0xEE, 'INC $%02x%02x', 2) do
  perform_inc(absolute)
  set_cycles(6)
end

# Absolute, X offset
MOS6502.defop(0xFE, 'INC $%02x%02x,X', 2) do
  operand,_extra = absolute_x
  perform_inc(operand)
  set_cycles(7)
end

# ** JuMP **

# Absolute
MOS6502.defop(0x4C, 'JMP $%02x%02x', 2, true) do
  lsb = read_advance_pc
  msb = read_advance_pc << 8
  set_register_PC(msb | lsb)

  set_cycles(3)
end

# Indirect
MOS6502.defop(0x6C, 'JMP ($%02x%02x)', 2, true) do
  lsb_ = read_advance_pc
  msb_ = read_advance_pc << 8
  lsb  = @__bus.read(msb_ | lsb_)
  msb  = @__bus.read(msb_ | ((lsb_ + 1) & 0xff)) << 8
  set_register_PC(msb | lsb)

  set_cycles(5)
end

# ** Jump to SubRoutine **

# Absolute
MOS6502.defop(0x20, 'JSR $%02x%02x', 2, true) do
  lsb = read_advance_pc
  msb = read_advance_pc << 8

  next_inst = register_PC - 1
  stack_S_push((next_inst & 0xff00) >> 8)
  stack_S_push(next_inst & 0xff)

  set_register_PC(msb | lsb)
  set_cycles(6)
end

# ** LoaD Accumulator

# Immediate
MOS6502.defop(0xA9, 'LDA #$%02x', 1) do
  perform_lda(immediate)

  set_cycles(2)
end

# Zero Page
MOS6502.defop(0xA5, 'LDA $%02x', 1) do
  perform_lda(@__bus.read(zero_page))
  set_cycles(3)
end

# Zero Page, X offset
MOS6502.defop(0xB5, 'LDA $%02x,X', 1) do
  perform_lda(@__bus.read(zero_page_x))
  set_cycles(4)
end

# Absolute
MOS6502.defop(0xAD, 'LDA $%02x%02x', 2, true) do
  perform_lda(@__bus.read(absolute))
  set_cycles(4)
end

# Absolute, X offset
MOS6502.defop(0xBD, 'LDA $%02x%02x,X', 2, true) do
  operand,extra = absolute_x
  perform_lda(@__bus.read(operand))
  set_cycles(4 + extra)
end

# Absolute, Y offset
MOS6502.defop(0xB9, 'LDA $%02x%02x,Y', 2, true) do
  operand,extra = absolute_y
  perform_lda(@__bus.read(operand))
  set_cycles(4 + extra)
end

# Indirect, X offset
MOS6502.defop(0xA1, 'LDA ($%02x,X)', 1) do
  perform_lda(@__bus.read(indirect_x))
  set_cycles(6)
end

# Indirect, Y offset
MOS6502.defop(0xB1, 'LDA ($%02x),Y', 1) do
  operand,extra = indirect_y
  perform_lda(@__bus.read(operand))
  set_cycles(5 + extra)
end

# ** LoaD X register

# Immediate
MOS6502.defop(0xA2, 'LDX #$%02x', 1) do
  perform_ldx(immediate)

  set_cycles(2)
end

# Zero Page
MOS6502.defop(0xA6, 'LDX $%02x', 1) do
  perform_ldx(@__bus.read(zero_page))
  set_cycles(3)
end

# Zero Page, Y offset
MOS6502.defop(0xB6, 'LDX $%02x,X', 1) do
  perform_ldx(@__bus.read(zero_page_y))
  set_cycles(4)
end

# Absolute
MOS6502.defop(0xAE, 'LDX $%02x%02x', 2, true) do
  perform_ldx(@__bus.read(absolute))
  set_cycles(4)
end

# Absolute, Y offset
MOS6502.defop(0xBE, 'LDX $%02x%02x,Y', 2, true) do
  operand,extra = absolute_y
  perform_ldx(@__bus.read(operand))
  set_cycles(4 + extra)
end

# ** LoaD Y register

# Immediate
MOS6502.defop(0xA0, 'LDY #$%02x', 1) do
  perform_ldy(immediate)

  set_cycles(2)
end

# Zero Page
MOS6502.defop(0xA4, 'LDY $%02x', 1) do
  perform_ldy(@__bus.read(zero_page))
  set_cycles(3)
end

# Zero Page, X offset
MOS6502.defop(0xB4, 'LDY $%02x,X', 1) do
  perform_ldy(@__bus.read(zero_page_x))
  set_cycles(4)
end

# Absolute
MOS6502.defop(0xAC, 'LDY $%02x%02x', 2, true) do
  perform_ldy(@__bus.read(absolute))
  set_cycles(4)
end

# Absolute, X offset
MOS6502.defop(0xBC, 'LDY $%02x%02x,X', 2, true) do
  operand,extra = absolute_x
  perform_ldy(@__bus.read(operand))
  set_cycles(4 + extra)
end

# ** Logical Shift Right **

# A register
MOS6502.defop(0x4A, 'LSR A', 0) do
  a = register_A >> 1
  set_flag_C(register_A & 0x01)
  set_flag_Z((a == 0) ? 1 : 0)
  set_flag_N(0)
  set_register_A(a)
  set_cycles(2)
end

# Zero Page
MOS6502.defop(0x46, 'LSR $%02x', 1) do
  perform_lsr(zero_page)
  set_cycles(5)
end

# Zero Page, X offset
MOS6502.defop(0x56, 'LSR $%02x,X', 1) do
  perform_lsr(zero_page_x)
  set_cycles(6)
end

# Absolute
MOS6502.defop(0x4E, 'LSR $%02x%02x', 2, true) do
  perform_lsr(absolute)
  set_cycles(6)
end

# Absolute, X offset
MOS6502.defop(0x5E, 'LSR $%02x%02x,X', 2, true) do
  operand,_extra = absolute_x
  set_cycles(7)
  perform_lsr(operand)
end

# ** No OPeration **
MOS6502.defop(0xEA, 'NOP', 0) { set_cycles(2) }

# ** bitwise OR with Accumulator **

# Immediate
MOS6502.defop(0x09, 'ORA #$%02x', 1) do
  perform_ora(immediate)

  set_cycles(2)
end

# Zero Page
MOS6502.defop(0x05, 'ORA $%02x', 1) do
  perform_ora(@__bus.read(zero_page))
  set_cycles(3)
end

# Zero Page, X offset
MOS6502.defop(0x15, 'ORA $%02x,X', 1) do
  perform_ora(@__bus.read(zero_page_x))
  set_cycles(4)
end

# Absolute
MOS6502.defop(0x0D, 'ORA $%02x%02x', 2, true) do
  perform_ora(@__bus.read(absolute))
  set_cycles(4)
end

# Absolute, X offset
MOS6502.defop(0x1D, 'ORA $%02x%02x,X', 2, true) do
  operand,extra = absolute_x
  perform_ora(@__bus.read(operand))
  set_cycles(4 + extra)
end

# Absolute, Y offset
MOS6502.defop(0x19, 'ORA $%02x%02x,Y', 2, true) do
  operand,extra = absolute_y
  perform_ora(@__bus.read(operand))
  set_cycles(4 + extra)
end

# Indirect, X offset
MOS6502.defop(0x01, 'ORA ($%02x,X)', 1) do
  perform_ora(@__bus.read(indirect_x))
  set_cycles(6)
end

# Indirect, Y offset
MOS6502.defop(0x11, 'ORA ($%02x),Y', 1) do
  operand,extra = indirect_y
  perform_ora(@__bus.read(operand))
  set_cycles(5 + extra)
end

# ** Register Instructions **

# Transfer A to X
MOS6502.defop(0xAA, 'TAX', 0) do
  value = register_A
  set_register_X(value)
  set_flag_N((value & 0x80) >> 7)
  set_flag_Z(value == 0 ? 1 : 0)

  set_cycles(2)
end

# Transfer X to A
MOS6502.defop(0x8A, 'TXA', 0) do
  value = register_X
  set_register_A(value)
  set_flag_N((value & 0x80) >> 7)
  set_flag_Z(value == 0 ? 1 : 0)

  set_cycles(2)
end

# DEcrement X
MOS6502.defop(0xCA, 'DEX', 0) do
  value = (register_X + 0xFF) & 0xFF
  set_register_X(value)
  set_flag_N((value & 0x80) >> 7)
  set_flag_Z(value == 0 ? 1 : 0)

  set_cycles(2)
end

# INcrement X
MOS6502.defop(0xE8, 'INX', 0) do
  value = (register_X + 1) & 0xFF
  set_register_X(value)
  set_flag_N((value & 0x80) >> 7)
  set_flag_Z(value == 0 ? 1 : 0)

  set_cycles(2)
end

# Transfer A to Y
MOS6502.defop(0xA8, 'TAY', 0) do
  value = register_A
  set_register_Y(value)
  set_flag_N((value & 0x80) >> 7)
  set_flag_Z(value == 0 ? 1 : 0)

  set_cycles(2)
end

# Transfer Y to A
MOS6502.defop(0x98, 'TYA', 0) do
  value = register_Y
  set_register_A(value)
  set_flag_N((value & 0x80) >> 7)
  set_flag_Z(value == 0 ? 1 : 0)

  set_cycles(2)
end

# DEcrement Y
MOS6502.defop(0x88, 'DEY', 0) do
  value = (register_Y + 0xFF) & 0xFF
  set_register_Y(value)
  set_flag_N((value & 0x80) >> 7)
  set_flag_Z(value == 0 ? 1 : 0)

  set_cycles(2)
end

# INcrement Y
MOS6502.defop(0xC8, 'INY', 0) do
  value = (register_Y + 1) & 0xFF
  set_register_Y(value)
  set_flag_N((value & 0x80) >> 7)
  set_flag_Z(value == 0 ? 1 : 0)

  set_cycles(2)
end

# ** ROtate Left **

# A register
MOS6502.defop(0x2A, 'ROL A', 0) do
  byte   = register_A
  result = ((byte << 1) & 0xff) | flag_C

  result_N = (result & 0x80) >> 7

  set_flag_C((byte & 0x80) >> 7)
  set_flag_N(result_N)
  set_flag_Z(result == 0 ? 1 : 0)

  set_register_A(result)
  set_cycles(2)
end

# Zero Page
MOS6502.defop(0x26, 'ROL $%02x', 1) do
  perform_rol(zero_page)
  set_cycles(5)
end

# Zero Page, X offset
MOS6502.defop(0x36, 'ROL $%02x,X', 1) do
  perform_rol(zero_page_x)
  set_cycles(6)
end

# Absolute
MOS6502.defop(0x2E, 'ROL $%02x%02x', 2, true) do
  perform_rol(absolute)
  set_cycles(6)
end

# Absolute, X offset
MOS6502.defop(0x3E, 'ROL $%02x%02x,X', 2, true) do
  operand,_extra = absolute_x
  set_cycles(7)
  perform_rol(operand)
end

# ** ROtate Right **

# A register
MOS6502.defop(0x6A, 'ROR A', 0) do
  byte   = register_A
  result = (byte >> 1) | (flag_C << 7)

  result_N = (result & 0x80) >> 7

  set_flag_C(byte & 0x01)
  set_flag_N(result_N)
  set_flag_Z(result == 0 ? 1 : 0)

  set_register_A(result)
  set_cycles(2)
end

# Zero Page
MOS6502.defop(0x66, 'ROR $%02x', 1) do
  perform_ror(zero_page)
  set_cycles(5)
end

# Zero Page, X offset
MOS6502.defop(0x76, 'ROR $%02x,X', 1) do
  perform_ror(zero_page_x)
  set_cycles(6)
end

# Absolute
MOS6502.defop(0x6E, 'ROR $%02x%02x', 2, true) do
  perform_ror(absolute)
  set_cycles(6)
end

# Absolute, X offset
MOS6502.defop(0x7E, 'ROR $%02x%02x,X', 2, true) do
  operand,_extra = absolute_x
  set_cycles(7)
  perform_ror(operand)
end

# ** ReTurn from Interrupt **
MOS6502.defop(0x40, 'RTI', 0) do
  flags = stack_S_pop
  lsb   = stack_S_pop
  msb   = stack_S_pop

  stack_value = flags & 0xCF
  #flags_value = register_S & 0x20

  set_register_F(stack_value | 0x20)
  set_register_PC((msb << 8) | lsb)
  set_cycles(6)
end

# ** ReTurn from Subroutine **
MOS6502.defop(0x60, 'RTS', 0) do
  lsb = stack_S_pop
  msb = stack_S_pop
  addr = ((msb << 8) | lsb) + 1
  set_register_PC(addr)
  set_cycles(6)
end

# ** SuBtract with Carry **

# Immediate
MOS6502.defop(0xE9, 'SBC #$%02x', 1) do
  perform_sbc(immediate)
  set_cycles(2)
end

# Zero Page
MOS6502.defop(0xE5, 'SBC $%02x', 1) do
  perform_sbc(@__bus.read(zero_page))
  set_cycles(3)
end

# Zero Page, X offset
MOS6502.defop(0xF5, 'SBC $%02x,X', 1) do
  perform_sbc(@__bus.read(zero_page_x))
  set_cycles(4)
end

# Absolute
MOS6502.defop(0xED, 'SBC $%02x%02x', 2, true) do
  perform_sbc(@__bus.read(absolute))
  set_cycles(4)
end

# Absolute, X offset
MOS6502.defop(0xFD, 'SBC $%02x%02x,X', 2, true) do
  operand,extra = absolute_x
  perform_sbc(@__bus.read(operand))
  set_cycles(4 + extra)
end

# Absolute, Y offset
MOS6502.defop(0xF9, 'SBC $%02x%02x,Y', 2, true) do
  operand,extra = absolute_y
  perform_sbc(@__bus.read(operand))
  set_cycles(4 + extra)
end

# Indirect, X offset
MOS6502.defop(0xE1, 'SBC ($%02x,X)', 1) do
  perform_sbc(@__bus.read(indirect_x))
  set_cycles(6)
end

# Indirect, Y offset
MOS6502.defop(0xF1, 'SBC ($%02x),Y', 1) do
  operand,extra = indirect_y
  perform_sbc(@__bus.read(operand))
  set_cycles(5 + extra)
end

# ** STore Accumulator **

# Zero Page
MOS6502.defop(0x85, 'STA $%02x', 1) do
  perform_sta(zero_page)
  set_cycles(3)
end

# Zero Page, X offset
MOS6502.defop(0x95, 'STA $%02x,X', 1) do
  perform_sta(zero_page_x)
  set_cycles(4)
end

# Absolute
MOS6502.defop(0x8D, 'STA $%02x%02x', 2, true) do
  perform_sta(absolute)
  set_cycles(4)
end

# Absolute, X offset
MOS6502.defop(0x9D, 'STA $%02x%02x,X', 2, true) do
  operand,_extra = absolute_x
  perform_sta(operand)
  set_cycles(5)
end

# Absolute, Y offset
MOS6502.defop(0x99, 'STA $%02x%02x,Y', 2, true) do
  operand,_extra = absolute_y
  perform_sta(operand)
  set_cycles(5)
end

# Indirect, X offset
MOS6502.defop(0x81, 'STA ($%02x,X)', 1) do
  perform_sta(indirect_x)
  set_cycles(6)
end

# Indirect, Y offset
MOS6502.defop(0x91, 'STA ($%02x),Y', 1) do
  operand,_extra = indirect_y
  perform_sta(operand)
  set_cycles(6)
end

# ** Stack Instructions

# Transfer X to Stack ptr
MOS6502.defop(0x9A, 'TXS', 0) do
  set_register_S(register_X)
  set_cycles(2)
end

# Transfer Stack ptr to X
MOS6502.defop(0xBA, 'TSX', 0) do
  set_register_X(register_S)
  set_flag_N(register_X >> 7)
  set_flag_Z(register_X == 0 ? 1 : 0)
  set_cycles(2)
end

# PusH Accumulator
MOS6502.defop(0x48, 'PHA', 0) do
  stack_S_push(register_A)
  set_cycles(3)
end

# PulL Accumulator
MOS6502.defop(0x68, 'PLA', 0) do
  set_register_A(stack_S_pop)

  result_N = (register_A & 0x80) >> 7
  set_flag_N(result_N)
  set_flag_Z(register_A == 0 ? 1 : 0)

  set_cycles(4)
end

# PusH Processor status (flags)
MOS6502.defop(0x08, 'PHP', 0) do
  stack_S_push(register_F | 0x30)
  set_cycles(3)
end

# PulL Processor status (flags)
MOS6502.defop(0x28, 'PLP', 0) do
  stack_value = stack_S_pop & 0xCF
  flags_value = register_S & 0x20
  set_register_F(stack_value | flags_value)

  set_cycles(4)
end

# ** STore X register **

# Zero Page
MOS6502.defop(0x86, 'STX $%02x', 1) do
  perform_stx(zero_page)
  set_cycles(3)
end

# Zero Page, Y offset
MOS6502.defop(0x96, 'STX $%02x,Y', 1) do
  perform_stx(zero_page_y)
  set_cycles(4)
end

# Absolute
MOS6502.defop(0x8E, 'STX $%02x%02x', 2, true) do
  perform_stx(absolute)
  set_cycles(4)
end

# ** STore Y register **

# Zero Page
MOS6502.defop(0x84, 'STY $%02x', 1) do
  perform_sty(zero_page)
  set_cycles(3)
end

# Zero Page, X offset
MOS6502.defop(0x94, 'STY $%02x,X', 1) do
  perform_sty(zero_page_x)
  set_cycles(4)
end

# Absolute
MOS6502.defop(0x8C, 'STY $%02x%02x', 2, true) do
  perform_sty(absolute)
  set_cycles(4)
end

############################
# ** Unofficial Opcodes ** #
############################

# No OPeration
MOS6502.defop(0x1A, '*NOP', 0) do
  set_cycles(2)
end
MOS6502.defop(0x3A, '*NOP', 0) do
  set_cycles(2)
end
MOS6502.defop(0x5A, '*NOP', 0) do
  set_cycles(2)
end
MOS6502.defop(0x7A, '*NOP', 0) do
  set_cycles(2)
end
MOS6502.defop(0xDA, '*NOP', 0) do
  set_cycles(2)
end
MOS6502.defop(0xFA, '*NOP', 0) do
  set_cycles(2)
end

# DOP (Double-no OPeration)
MOS6502.defop(0x04, '*NOP $%02x', 1) do
  _ = read_advance_pc
  set_cycles(3)
end
MOS6502.defop(0x14, '*NOP $%02x,X', 1) do
  _ = read_advance_pc
  set_cycles(4)
end
MOS6502.defop(0x34, '*NOP $%02x,X', 1) do
  _ = read_advance_pc
  set_cycles(4)
end
MOS6502.defop(0x44, '*NOP $%02x', 1) do
  _ = read_advance_pc
  set_cycles(3)
end
MOS6502.defop(0x54, '*NOP $%02x,X', 1) do
  _ = read_advance_pc
  set_cycles(4)
end
MOS6502.defop(0x64, '*NOP $%02x', 1) do
  _ = read_advance_pc
  set_cycles(3)
end
MOS6502.defop(0x74, '*NOP $%02x,X', 1) do
  _ = read_advance_pc
  set_cycles(4)
end
MOS6502.defop(0x80, '*NOP #%02x', 1) do
  _ = read_advance_pc
  set_cycles(2)
end
MOS6502.defop(0x82, '*NOP #%02x', 1) do
  _ = read_advance_pc
  set_cycles(2)
end
MOS6502.defop(0x89, '*NOP #%02x', 1) do
  _ = read_advance_pc
  set_cycles(2)
end
MOS6502.defop(0xC2, '*NOP #%02x', 1) do
  _ = read_advance_pc
  set_cycles(2)
end
MOS6502.defop(0xD4, '*NOP $%02x,X', 1) do
  _ = read_advance_pc
  set_cycles(4)
end
MOS6502.defop(0xE2, '*NOP #%02x', 1) do
  _ = read_advance_pc
  set_cycles(2)
end
MOS6502.defop(0xF4, '*NOP $%02x,X', 1) do
  _ = read_advance_pc
  set_cycles(4)
end

# TOP (Triple-no OPeration)

MOS6502.defop(0x0C, '*NOP $%02x%02x', 2) do
  _ = absolute
  set_cycles(4)
end
MOS6502.defop(0x1C, '*NOP $%02x%02x,X', 2) do
  _,extra = absolute_x
  set_cycles(4 + extra)
end
MOS6502.defop(0x3C, '*NOP $%02x%02x,X', 2) do
  _,extra = absolute_x
  set_cycles(4 + extra)
end
MOS6502.defop(0x5C, '*NOP $%02x%02x,X', 2) do
  _,extra = absolute_x
  set_cycles(4 + extra)
end
MOS6502.defop(0x7C, '*NOP $%02x%02x,X', 2) do
  _,extra = absolute_x
  set_cycles(4 + extra)
end
MOS6502.defop(0xDC, '*NOP $%02x%02x,X', 2) do
  _,extra = absolute_x
  set_cycles(4 + extra)
end
MOS6502.defop(0xFC, '*NOP $%02x%02x,X', 2) do
  _,extra = absolute_x
  set_cycles(4 + extra)
end

# Load Accumulator and X register

MOS6502.defop(0xA7, '*LAX $%02x', 1) do
  operand = @__bus.read(zero_page)
  perform_lax(operand)
  set_cycles(3)
end

MOS6502.defop(0xB7, '*LAX $%02x,Y', 1) do
  operand = @__bus.read(zero_page_y)
  perform_lax(operand)
  set_cycles(4)
end

MOS6502.defop(0xAF, '*LAX $%02x%02x', 2, true) do
  operand = @__bus.read(absolute)
  perform_lax(operand)
  set_cycles(4)
end

MOS6502.defop(0xBF, '*LAX $%02x%02x,Y', 2, true) do
  operand_, extra = absolute_y
  operand = @__bus.read(operand_)
  perform_lax(operand)
  set_cycles(4 + extra)
end

MOS6502.defop(0xA3, '*LAX ($%02x,Y)', 1) do
  operand = @__bus.read(indirect_x)
  perform_lax(operand)
  set_cycles(6)
end

MOS6502.defop(0xB3, '*LAX ($%02x),Y', 1) do
  operand_, extra = indirect_y
  operand = @__bus.read(operand_)
  perform_lax(operand)
  set_cycles(5 + extra)
end

# Store the result of Accumulator and X register

MOS6502.defop(0x87, '*SAX $%02x', 1) do
  perform_sax(zero_page)
  set_cycles(3)
end

MOS6502.defop(0x97, '*SAX $%02x,Y', 1) do
  perform_sax(zero_page_y)
  set_cycles(4)
end

MOS6502.defop(0x83, '*SAX ($%02x,X)', 1) do
  perform_sax(indirect_x)
  set_cycles(6)
end

MOS6502.defop(0x8F, '*SAX $%02x%02x', 2, true) do
  perform_sax(absolute)
  set_cycles(4)
end

# SuBtract with Carry

MOS6502.defop(0xEB, '*SBC #$%02x', 1) do
  perform_sbc(immediate)
  set_cycles(2)
end

# DeCrement Memory

MOS6502.defop(0xC7, '*DCP $%02x', 1) do
  perform_dcp(zero_page)
  set_cycles(5)
end

MOS6502.defop(0xD7, '*DCP $%02x,X', 1) do
  perform_dcp(zero_page_x)
  set_cycles(6)
end

MOS6502.defop(0xCF, '*DCP $%02x%02x', 2, true) do
  perform_dcp(absolute)
  set_cycles(6)
end

MOS6502.defop(0xDF, '*DCP $%02x%02x,X', 2, true) do
  operand,_extra = absolute_x
  perform_dcp(operand)
  set_cycles(7)
end

MOS6502.defop(0xDB, '*DCP $%02x%02x,Y', 2, true) do
  operand, _extra = absolute_y
  perform_dcp(operand)
  set_cycles(7)
end

MOS6502.defop(0xC3, '*DCP ($%02x,X)', 1) do
  perform_dcp(indirect_x)
  set_cycles(8)
end

MOS6502.defop(0xD3, '*DCP ($%02x),Y', 1) do
  operand, _extra = indirect_y
  perform_dcp(operand)
  set_cycles(8)
end

# Increment memory, SuBtract from accumulator

MOS6502.defop(0xE7, '*ISB $%02x', 1) do
  perform_isb(zero_page)
  set_cycles(5)
end

MOS6502.defop(0xF7, '*ISB $%02x,X', 1) do
  perform_isb(zero_page_x)
  set_cycles(6)
end

MOS6502.defop(0xEF, '*ISB $%02x%02x', 2, true) do
  perform_isb(absolute)
  set_cycles(6)
end

MOS6502.defop(0xFF, '*ISB $%02x%02x,X', 2, true) do
  operand,_extra = absolute_x
  perform_isb(operand)
  set_cycles(7)
end

MOS6502.defop(0xFB, '*ISB $%02x%02x,Y', 2, true) do
  operand, _extra = absolute_y
  perform_isb(operand)
  set_cycles(7)
end

MOS6502.defop(0xE3, '*ISB ($%02x,X)', 1) do
  perform_isb(indirect_x)
  set_cycles(8)
end

MOS6502.defop(0xF3, '*ISB ($%02x),Y', 1) do
  operand, _extra = indirect_y
  perform_isb(operand)
  set_cycles(8)
end

# arithmetic Shift Left memory, then Or with accumulator

MOS6502.defop(0x07, '*SLO $%02x', 1) do
  perform_slo(zero_page)
  set_cycles(5)
end

MOS6502.defop(0x17, '*SLO $%02x,X', 1) do
  perform_slo(zero_page_x)
  set_cycles(6)
end

MOS6502.defop(0x0F, '*SLO $%02x%02x', 2, true) do
  perform_slo(absolute)
  set_cycles(6)
end

MOS6502.defop(0x1F, '*SLO $%02x%02x,X', 2, true) do
  operand,_extra = absolute_x
  perform_slo(operand)
  set_cycles(7)
end

MOS6502.defop(0x1B, '*SLO $%02x%02x,Y', 2, true) do
  operand, _extra = absolute_y
  perform_slo(operand)
  set_cycles(7)
end

MOS6502.defop(0x03, '*SLO ($%02x,X)', 1) do
  perform_slo(indirect_x)
  set_cycles(8)
end

MOS6502.defop(0x13, '*SLO ($%02x),Y', 1) do
  operand, _extra = indirect_y
  perform_slo(operand)
  set_cycles(8)
end

# Rotate Left memory, then And with accumulator

MOS6502.defop(0x27, '*RLA $%02x', 1) do
  perform_rla(zero_page)
  set_cycles(5)
end

MOS6502.defop(0x37, '*RLA $%02x,X', 1) do
  perform_rla(zero_page_x)
  set_cycles(6)
end

MOS6502.defop(0x2F, '*RLA $%02x%02x', 2, true) do
  perform_rla(absolute)
  set_cycles(6)
end

MOS6502.defop(0x3F, '*RLA $%02x%02x,X', 2, true) do
  operand,_extra = absolute_x
  perform_rla(operand)
  set_cycles(7)
end

MOS6502.defop(0x3B, '*RLA $%02x%02x,Y', 2, true) do
  operand, _extra = absolute_y
  perform_rla(operand)
  set_cycles(7)
end

MOS6502.defop(0x23, '*RLA ($%02x,X)', 1) do
  perform_rla(indirect_x)
  set_cycles(8)
end

MOS6502.defop(0x33, '*RLA ($%02x),Y', 1) do
  operand, _extra = indirect_y
  perform_rla(operand)
  set_cycles(8)
end

# Shift Right memory, then Exclusive or with accumulator

MOS6502.defop(0x47, '*SRE $%02x', 1) do
  perform_sre(zero_page)
  set_cycles(5)
end

MOS6502.defop(0x57, '*SRE $%02x,X', 1) do
  perform_sre(zero_page_x)
  set_cycles(6)
end

MOS6502.defop(0x4F, '*SRE $%02x%02x', 2, true) do
  perform_sre(absolute)
  set_cycles(6)
end

MOS6502.defop(0x5F, '*SRE $%02x%02x,X', 2, true) do
  operand,_extra = absolute_x
  perform_sre(operand)
  set_cycles(7)
end

MOS6502.defop(0x5B, '*SRE $%02x%02x,Y', 2, true) do
  operand, _extra = absolute_y
  perform_sre(operand)
  set_cycles(7)
end

MOS6502.defop(0x43, '*SRE ($%02x,X)', 1) do
  perform_sre(indirect_x)
  set_cycles(8)
end

MOS6502.defop(0x53, '*SRE ($%02x),Y', 1) do
  operand, _extra = indirect_y
  perform_sre(operand)
  set_cycles(8)
end

# Rotate Right memory, then Add to accumulator with carry

MOS6502.defop(0x67, '*RRA $%02x', 1) do
  perform_rra(zero_page)
  set_cycles(5)
end

MOS6502.defop(0x77, '*RRA $%02x,X', 1) do
  perform_rra(zero_page_x)
  set_cycles(6)
end

MOS6502.defop(0x6F, '*RRA $%02x%02x', 2, true) do
  perform_rra(absolute)
  set_cycles(6)
end

MOS6502.defop(0x7F, '*RRA $%02x%02x,X', 2, true) do
  operand,_extra = absolute_x
  perform_rra(operand)
  set_cycles(7)
end

MOS6502.defop(0x7B, '*RRA $%02x%02x,Y', 2, true) do
  operand, _extra = absolute_y
  perform_rra(operand)
  set_cycles(7)
end

MOS6502.defop(0x63, '*RRA ($%02x,X)', 1) do
  perform_rra(indirect_x)
  set_cycles(8)
end

MOS6502.defop(0x73, '*RRA ($%02x),Y', 1) do
  operand, _extra = indirect_y
  perform_rra(operand)
  set_cycles(8)
end
