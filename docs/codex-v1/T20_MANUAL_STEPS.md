# T20 Windows checks — completed, no further action

Janne Vuorela confirmed the BAT drop showed **Completed with failures**. His
actual PS5.1 cover selection also succeeded: all three synthetic files converted.
The guide rejected a valid PNG because it required one specific 64x64 fixture.
That test is corrected; the original failed report remains preserved.

At Janne's repeated request for simpler or automated testing, the A49 method
now combines those named observations with automated real Windows checks in both
shells. Retained picker outputs pass independent metadata/artwork/layout/decode/
source-safety checks; fresh cancellation tests pass all eighteen cases. A50's
selected real long-file and controlled default-Music checks already pass.

**Do not rerun the long guide or choose another cover. No further Windows test
action is needed.** Keep the existing local files for verification. Unknown BAT
Music output was neither inspected nor removed.

Current PS7 native picker, physical Cancel, hardware Ctrl+C and physical fallback
are explicit coverage limits. Software verification does not claim those human
actions. Phone/player acceptance remains the separate T21 task after owner
integration of T20. See evidence/T20.md for exact method, results and limits.
