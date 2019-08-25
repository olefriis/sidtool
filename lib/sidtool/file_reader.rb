module Sidtool
  class FileReader
    attr_reader :format, :version, :init_address, :play_address, :songs, :start_song
    attr_reader :name, :author, :released
    attr_reader :data

    def self.read(path)
      contents = File.open(path, 'rb', encoding: 'ascii-8bit') { |file| file.read }

      expected_data_offset = 0x7C
      minimum_file_size = expected_data_offset

      raise "File is too small - it should be at least #{minimum_file_size} bytes. The file may be corrupt." unless contents.length >= minimum_file_size

      format = contents[0..3]
      raise "Unknown file format: #{format}. Only PSID is supported." unless format == 'PSID'

      version = read_word(contents[4..5])
      raise "Invalid version number: #{version}. Only versions 2, 3, and 4 are supported." unless version >= 2 && version <= 4

      data_offset = read_word(contents[6..7])
      raise "Invalid data offset: #{data_offset}. This has to be #{expected_data_offset}. The file may be corrupt." unless data_offset == expected_data_offset

      load_address = read_word(contents[8..9])
      raise "Unsupported load address: #{load_address}. Only 0 is supported for now." unless load_address == 0

      init_address = read_word(contents[10..11])
      play_address = read_word(contents[12..13])
      songs = read_word(contents[14..15])
      start_song = read_word(contents[16..17])

      name = read_null_terminated_string(contents[22..53])
      author = read_null_terminated_string(contents[54..85])
      released = read_null_terminated_string(contents[86..117])

      data = read_bytes(contents[data_offset..-1])

      return self.new(format: format, version: version, init_address: init_address, play_address: play_address,
                      songs: songs, start_song: start_song, name: name, author: author, released: released,
                      data: data)
    end

    def initialize(format:, version:, init_address:, play_address:, songs:, start_song:, name:, author:, released:, data:)
      @format = format
      @version = version
      @init_address = init_address
      @play_address = play_address
      @songs = songs
      @start_song = start_song
      @name = name
      @author = author
      @released = released
      @data = data
    end

    private
    def self.read_word(bytes)
      (bytes[0].ord << 8) + bytes[1].ord
    end

    def self.read_null_terminated_string(bytes)
      first_null = bytes.index("\0") || 32
      bytes[0..first_null-1]
    end

    def self.read_bytes(bytes)
      bytes.chars.map(&:ord)
    end
  end
end