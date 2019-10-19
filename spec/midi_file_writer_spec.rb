module Sidtool
  RSpec.describe MidiFileWriter do
    # Trying to make frame specification in seconds a bit more readable...
    ONE_FRAME = 0.02
    TWO_FRAMES = 0.04
    THREE_FRAMES = 0.06
    FOUR_FRAMES = 0.08
    let(:subject) { MidiFileWriter.new(synths) }

    describe '#build_track' do
      let(:track) { subject.build_track }

      TestSynth = Struct.new(:start_frame, :tone, :waveform, :attack, :decay, :sustain_length, :release)

      context 'with sequential synths for just one voice' do
        let(:synths) {
          [
            [
              TestSynth[50, 75, :tri, ONE_FRAME, ONE_FRAME, ONE_FRAME, ONE_FRAME],
              TestSynth[100, 76, :tri, TWO_FRAMES, TWO_FRAMES, TWO_FRAMES, TWO_FRAMES]
            ],
            [],
            []
          ]
        }

        it 'places commands sequentially' do
          expect(track).to eq([
            MidiFileWriter::DeltaTime[50], MidiFileWriter::NoteOn[0, 75],
            MidiFileWriter::DeltaTime[3], MidiFileWriter::NoteOff[0, 75],
            MidiFileWriter::DeltaTime[47], MidiFileWriter::NoteOn[0, 76],
            MidiFileWriter::DeltaTime[6], MidiFileWriter::NoteOff[0, 76]
          ])
        end
      end

      context 'with different waveforms' do
        let(:synths) {
          [
            [
              TestSynth[50, 75, :tri, ONE_FRAME, ONE_FRAME, ONE_FRAME, ONE_FRAME],
              TestSynth[100, 76, :saw, ONE_FRAME, ONE_FRAME, ONE_FRAME, ONE_FRAME],
              TestSynth[150, 77, :pulse, ONE_FRAME, ONE_FRAME, ONE_FRAME, ONE_FRAME],
              TestSynth[200, 78, :noise, ONE_FRAME, ONE_FRAME, ONE_FRAME, ONE_FRAME]
            ],
            [],
            []
          ]
        }

        it 'uses separate channels' do
          expect(track).to eq([
            MidiFileWriter::DeltaTime[50], MidiFileWriter::NoteOn[0, 75],
            MidiFileWriter::DeltaTime[3], MidiFileWriter::NoteOff[0, 75],
            MidiFileWriter::DeltaTime[47], MidiFileWriter::NoteOn[1, 76],
            MidiFileWriter::DeltaTime[3], MidiFileWriter::NoteOff[1, 76],
            MidiFileWriter::DeltaTime[47], MidiFileWriter::NoteOn[2, 77],
            MidiFileWriter::DeltaTime[3], MidiFileWriter::NoteOff[2, 77],
            MidiFileWriter::DeltaTime[47], MidiFileWriter::NoteOn[3, 78],
            MidiFileWriter::DeltaTime[3], MidiFileWriter::NoteOff[3, 78],
          ])
        end
      end

      context 'with sequential synths for separate voices' do
        let(:synths) {
          [
            [
              TestSynth[50, 75, :tri, ONE_FRAME, ONE_FRAME, ONE_FRAME, ONE_FRAME],
              TestSynth[200, 78, :tri, TWO_FRAMES, TWO_FRAMES, TWO_FRAMES, TWO_FRAMES]
            ],
            [
              TestSynth[100, 76, :tri, TWO_FRAMES, TWO_FRAMES, TWO_FRAMES, TWO_FRAMES],
              TestSynth[250, 79, :tri, THREE_FRAMES, THREE_FRAMES, THREE_FRAMES, THREE_FRAMES]
            ],
            [
              TestSynth[150, 77, :tri, THREE_FRAMES, THREE_FRAMES, THREE_FRAMES, THREE_FRAMES],
              TestSynth[300, 80, :tri, FOUR_FRAMES, FOUR_FRAMES, FOUR_FRAMES, FOUR_FRAMES]
            ]
          ]
        }

        it 'places commands sequentially and maps to different channels' do
          expect(track).to eq([
            MidiFileWriter::DeltaTime[50], MidiFileWriter::NoteOn[0, 75],
            MidiFileWriter::DeltaTime[3], MidiFileWriter::NoteOff[0, 75],
            MidiFileWriter::DeltaTime[47], MidiFileWriter::NoteOn[4, 76],
            MidiFileWriter::DeltaTime[6], MidiFileWriter::NoteOff[4, 76],
            MidiFileWriter::DeltaTime[44], MidiFileWriter::NoteOn[8, 77],
            MidiFileWriter::DeltaTime[9], MidiFileWriter::NoteOff[8, 77],
            MidiFileWriter::DeltaTime[41], MidiFileWriter::NoteOn[0, 78],
            MidiFileWriter::DeltaTime[6], MidiFileWriter::NoteOff[0, 78],
            MidiFileWriter::DeltaTime[44], MidiFileWriter::NoteOn[4, 79],
            MidiFileWriter::DeltaTime[9], MidiFileWriter::NoteOff[4, 79],
            MidiFileWriter::DeltaTime[41], MidiFileWriter::NoteOn[8, 80],
            MidiFileWriter::DeltaTime[12], MidiFileWriter::NoteOff[8, 80],
          ])
        end
      end

      context 'with interleaved synths' do
        let(:synths) {
          [
            [TestSynth[50, 75, :tri, ONE_FRAME, ONE_FRAME, ONE_FRAME, ONE_FRAME]],
            [TestSynth[51, 76, :tri, TWO_FRAMES, TWO_FRAMES, TWO_FRAMES, TWO_FRAMES]],
            [TestSynth[52, 77, :tri, THREE_FRAMES, THREE_FRAMES, THREE_FRAMES, THREE_FRAMES]]
          ]
        }

        it 'interleaves commands' do
          expect(track).to eq([
            MidiFileWriter::DeltaTime[50], MidiFileWriter::NoteOn[0, 75],
            MidiFileWriter::DeltaTime[1], MidiFileWriter::NoteOn[4, 76],
            MidiFileWriter::DeltaTime[1], MidiFileWriter::NoteOn[8, 77],
            MidiFileWriter::DeltaTime[1], MidiFileWriter::NoteOff[0, 75],
            MidiFileWriter::DeltaTime[4], MidiFileWriter::NoteOff[4, 76],
            MidiFileWriter::DeltaTime[4], MidiFileWriter::NoteOff[8, 77],
          ])
        end
      end
    end

    describe 'DeltaTime#bytes' do
      it 'returns just the number when below 128' do
        expect(MidiFileWriter::DeltaTime[0].bytes).to eq([0])
        expect(MidiFileWriter::DeltaTime[1].bytes).to eq([1])

        expect(MidiFileWriter::DeltaTime[126].bytes).to eq([126])
        expect(MidiFileWriter::DeltaTime[127].bytes).to eq([127])
      end

      it 'splits up in two bytes when value is above 127' do
        expect(MidiFileWriter::DeltaTime[128].bytes).to eq([128 + 1, 0])
        expect(MidiFileWriter::DeltaTime[129].bytes).to eq([128 + 1, 1])
        expect(MidiFileWriter::DeltaTime[130].bytes).to eq([128 + 1, 2])
        expect(MidiFileWriter::DeltaTime[192].bytes).to eq([128 + 1, 64])
      end
    end
  end
end
