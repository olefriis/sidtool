# Changelog

## 0.0.4
* Bumped to mos6510 version 0.1.1 which depends on a version of mini_racer that can compile
  and install on my machine.

## 0.0.3
* Add midi support.

## 0.0.2
* Process 15000 frames (10 minutes) instead of 1500 (half a minute) by default.
* Only release a synth once. This fixes various sound effects that would just end up with a
  permanently released synth. It will probably make "normal" tunes sound a bit crisper too.
* Ensuring that existing synth gets properly cut off before starting the next sync for a voice.
  This fixes songs like `Commando.sid` that sounded just weird before.

## 0.0.1
Just getting started... A lot of mess...