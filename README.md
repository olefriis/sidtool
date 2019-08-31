# Sidtool

Convert Commodore 64 SID music in the form of `.sid` files into other formats! This is still VERY
much work in progress... the code is ugly and will probably create horrible results for you :-)

Basically, it's a massive hack made for fun and no profit.

The vision, though, is to extract the actual information from `.sid` files, which are files storing
music for the Commodore 64. This sounds like an easy task.

`.sid` files contain actual Commodore 64 machine code that writes to registers corresponding to the
Commodore 64 sound chip, the SID (Sound Interface Device). Which means that in order to play back a
`.sid` file like it would sound on an actual Commodore 64, you will have to simulate both the
processor and the sound chip.

This project does not attempt to simulate the SID chip to produce authentic sounds - lots of those
players already exist - but instead has a very simple implementation that produces data that can be
used to play back the songs. You know, almost as notes.

Currently the only output format is a Ruby file which defines a list of synths to play at certain
points in time. This can be used to play back the music in [Sonic Pi](https://sonic-pi.net).

## Limitations

Only a subset of the so-called `PSID` format is supported (a few `.sid` files use the `RSID` format
which requires a more complete Commodore 64 environment to run), and maybe not all shortcomings of
the support is handled well.

Only PAL (50 frames per second) is supported. No CIA timers or other fanciness is supported.

The conversion runs a specified number of frames (default is 1500 - this can be changed on the
command line). Ideally it should be able to run until the song finishes.

For these and other limitations, please consult [the issues](https://github.com/olefriis/sidtool/issues).

## Installation

    gem install sidtool

## Usage

You can find lots of `.sid` files (and a super nice list of players for a wide range of platforms)
at the [High Voltage SID Collection](https://www.hvsc.c64.org) homepage.

Show information, like the author and number of songs in a file:

    $ sidtool --info <input file>

Convert the default song from a file to a Ruby list:

    $ sidtool --out <output file> <input file>

The output can then be used to play back the music, for example in Sonic Pi:

```ruby
load '<path to your output file from before>'

previous_frame = 1
::SYNTHS.each do |synth|
  current_frame = synth[0]
  frames_to_sleep = current_frame - previous_frame
  previous_frame = current_frame
  sleep frames_to_sleep/50.0 if frames_to_sleep > 0
  
  in_thread do
    use_synth synth[2]
    played_synth = play synth[1], attack: synth[3], decay: synth[4], sustain: synth[5], release: synth[6]
    
    this_frame = current_frame
    controls = synth[7]
    controls.each do |c|
      sleep (c[0] - this_frame) / 50.0
      this_frame = c[0]
      control played_synth, note: c[1]
    end
  end
end
```

It's a bit hacky, I know. Part of the issue is that Sonic Pi has a limit on the size of the edit buffer,
so paste the above into the buffer and edit the first line so it loads the (probably rather large)
output file from `sidtool`.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to
run the tests. You can also run `bin/console` for an interactive prompt that will allow you to
experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new
version, update the version number in `version.rb`, and then run `bundle exec rake release`,
which will create a git tag for the version, push git commits and tags, and push the `.gem` file
to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/olefriis/sidtool.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
