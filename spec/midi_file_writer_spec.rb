module Sidtool
  RSpec.describe MidiFileWriter do
    let(:subject) { MidiFileWriter.new(nil) }

    describe '#variable_length_quantity' do
      it 'returns just the number when below 128' do
        expect(subject.send(:variable_length_quantity, 0)).to eq([0])
        expect(subject.send(:variable_length_quantity, 1)).to eq([1])

        expect(subject.send(:variable_length_quantity, 126)).to eq([126])
        expect(subject.send(:variable_length_quantity, 127)).to eq([127])
      end

      it 'splits up in two bytes when value is above 127' do
        expect(subject.send(:variable_length_quantity, 128)).to eq([128 + 1, 0])
        expect(subject.send(:variable_length_quantity, 129)).to eq([128 + 1, 1])
        expect(subject.send(:variable_length_quantity, 130)).to eq([128 + 1, 2])
        expect(subject.send(:variable_length_quantity, 192)).to eq([128 + 1, 64])
      end
    end
  end
end
