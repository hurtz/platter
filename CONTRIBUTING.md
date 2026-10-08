# Contributing to Platter

Thanks for wanting to make your Mac louder. Every kind of help is welcome: new drives, better sounds, UI polish, bug reports, or just "the IDE drive should sound more like my old Quantum."

## Tuning or adding a drive

Every drive is a `Profile` block near the top of `Sources/DriveSynth.c`. The fields are grouped by part of the drive:

* **Spindle:** `rpm`, spin up and spin down times, `harm[]` (motor hum harmonics), `whine*` (bearing and motor whine), `air*` (air noise), `bearing` (roughness).
* **Floppy motor:** `motorHz`, `swish*` (the media rubbing in its jacket), `headLoadGain` (5.25″ solenoid clunk).
* **Actuator:** voice coil drives use `seekMinMs`, `seekMaxMs`, `settleMs`, `clickGain` and `zip*`. Stepper drives use `tracks`, `stepMs`, `stepGain`, `finalGain` and `bangGain` (hitting the track 0 stop).
* **Resonances:** `armF/armT/armG` and `chF/chT/chG` are the frequencies, decay times and gains of the arm and chassis modes. This is where most of a drive's character lives.

You don't need a Mac to iterate on sounds:

```sh
cd tests
cc -O2 -std=c11 -o render_test render_test.c ../Sources/DriveSynth.c -lm
./render_test   # writes out_<drive>.wav for every drive and prints levels
```

Try to keep busy drives roughly level with the others (the test prints RMS per segment) so switching drives doesn't blast anyone.

To add a new drive, add a `DS_PROFILE_*` id in `DriveSynth.h`, a profile block in `DriveSynth.c`, and an entry in `DriveInfo.all` in `Sources/Model.swift`.

## Building the app

```sh
./build.sh --no-install
```

## Pull requests

* Keep the audio thread free of allocations, locks and Objective C calls.
* One change per pull request is easiest to review.
* Describe what it sounds like, or attach a short recording. That's half the fun.
