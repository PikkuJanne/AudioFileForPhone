# T20 guided Windows check — NOT RUN

Janne Vuorela: open an ordinary, non-elevated PowerShell console and run this
single command. It uses the already prepared synthetic fixtures; no personal
media path or manual document editing is needed.

```powershell
& (Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe') -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File 'C:\projects\AudioFileForPhone-main\docs\codex-v1\tools\Start-T20Guided.ps1'
```

Follow the instructions shown by the guide:

1. Drag the displayed mixed valid/corrupt synthetic folder onto the BAT in the
   other Explorer window. Press Enter for its three optional prompts. The expected
   final message is **Completed with failures** because one fixture is corrupt.
2. In four successive cover dialogs, select the printed PNG or click Cancel,
   as instructed. The guide supplies synthetic metadata and checks outputs.
3. In each of two console windows, wait for **READY**, then press Ctrl+C once.
4. Confirm your actual actions in the guide and report its final result here.

The guide automatically checks tags, artwork, layout, full decode, source hashes
and cancellation reports. It copies the existing installed external FFmpeg pair
beside the private app so Explorer does not depend on its inherited PATH. Original
app/BAT/helper bytes stay unchanged; no download or global setting changes occur.

Raw output and result JSON remain in the displayed owned TEMP root. Keep them for
verification. The direct BAT observation is your attestation: its selected shell,
exit code and Music output root are not captured. Its unknown Music output stays
retained; the guide never scans or cleans Music. Long-file conversion/resource
checks are handled separately. A49 remains unpassed until actual
results and your physical confirmation are reviewed. Enforced policy restrictions
are blockers; do not weaken them.
