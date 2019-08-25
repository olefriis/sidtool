require 'tempfile'

module Sidtool
  RSpec.describe FileReader do
    before do
      @file = Tempfile.new(encoding: 'ascii-8bit')
      @path = @file.path

      write_string(format_string)
      write_word(version_number)
      write_word(data_offset)
      write_word(load_address)
      write_word(init_address)
      write_word(play_address)
      write_word(songs)
      write_word(start_song)
      write_long_word(speed)
      write_32_byte_string(name)
      write_32_byte_string(author)
      write_32_byte_string(released)

      # Unsupported fields
      write_word(0) # flags
      write_byte(0) # start page
      write_byte(0) # page length
      write_byte(0) # second SID address
      write_byte(0) # third SID address

      write_bytes(data)

      @file.close
    end

    after do
      @file.delete
    end

    let(:format_string) { 'PSID' }
    let(:version_number) { 2 }
    let(:data_offset) { 0x7C }
    let(:load_address) { 0 }
    let(:init_address) { 0x2003 }
    let(:play_address) { 0x2000 }
    let(:songs) { 7 }
    let(:start_song) { 5 }
    let(:speed) { 0 }
    let(:name) { 'Imaginary game' }
    let(:author) { 'Imaginary author' }
    let(:released) { 'Copyright 2019' }
    let(:data) { [1, 2, 3, 4] }

    context 'with unknown file format' do
      let(:format_string) { 'RSID' }

      it 'informs about supported file formats' do
        expect { FileReader.read(@path) }.to raise_exception('Unknown file format: RSID. Only PSID is supported.')
      end
    end

    context 'with version number less than 2' do
      let(:version_number) { 1 }

      it 'informs about valid version numbers' do
        expect { FileReader.read(@path) }.to raise_exception('Invalid version number: 1. Only versions 2, 3, and 4 are supported.')
      end
    end

    context 'with version number greater than 4' do
      let(:version_number) { 5 }

      it 'informs about valid version numbers' do
        expect { FileReader.read(@path) }.to raise_exception('Invalid version number: 5. Only versions 2, 3, and 4 are supported.')
      end
    end

    context 'with wrong data offset' do
      let(:data_offset) { 25 }

      it 'informs about valid data offset' do
        expect { FileReader.read(@path) }.to raise_exception('Invalid data offset: 25. This has to be 124. The file may be corrupt.')
      end
    end

    context 'with unsupported load address' do
      let(:load_address) { 0x07E8 }

      it 'informs about unsupported load addresses' do
        expect { FileReader.read(@path) }.to raise_exception('Unsupported load address: 2024. Only 0 is supported for now.')
      end
    end

    context 'when file is too small' do
      before do
        @small_file = Tempfile.new(encoding: 'ascii-8bit')
        @small_file_path = @small_file.path

        @small_file.close
      end

      after do
        @small_file.delete
      end

      it 'informs about too small file' do
        expect { FileReader.read(@small_file_path) }.to raise_exception('File is too small - it should be at least 124 bytes. The file may be corrupt.')
      end
    end

    context 'when all is well and good' do
      before { @sid_file = FileReader.read(@path) }

      it 'knows the format' do
        expect(@sid_file.format).to eq('PSID')
      end

      it 'knows the version number' do
        expect(@sid_file.version).to eq(2)
      end

      it 'knows the init address' do
        expect(@sid_file.init_address).to eq(0x2003)
      end

      it 'knows the play address' do
        expect(@sid_file.play_address).to eq(0x2000)
      end

      it 'knows the number of songs' do
        expect(@sid_file.songs).to eq(7)
      end

      it 'knows the start song' do
        expect(@sid_file.start_song).to eq(5)
      end

      it 'knows name' do
        expect(@sid_file.name).to eq('Imaginary game')
      end

      it 'knows author' do
        expect(@sid_file.author).to eq('Imaginary author')
      end

      it 'knows released' do
        expect(@sid_file.released).to eq('Copyright 2019')
      end

      it 'knows the data' do
        expect(@sid_file.data).to eq([1, 2, 3, 4])
      end
    end

    def write_32_byte_string(string)
      write_string((string + ("\0" * 32))[0..31])
    end

    def write_string(string)
      @file.write(string)
    end

    def write_bytes(bytes)
      bytes.each { |byte| write_byte(byte) }
    end

    def write_byte(byte)
      bytes = [byte]
      @file.write(bytes.pack('c'))
    end

    def write_word(word)
      bytes = [word >> 8, word & 0xFF]
      @file.write(bytes.pack('cc'))
    end

    def write_long_word(word)
      bytes = [(word >> 24) & 0xFF, (word >> 16) & 0xFF, (word >> 8) & 0xFF, word & 0xFF]
      @file.write(bytes.pack('cccc'))
    end
  end
end