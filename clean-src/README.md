# SOFTEL, without the apparatus

Generated. **Do not edit anything in this directory but this file** -- the next run of the stripper overwrites it:

    .venv/Scripts/python.exe kit/tools/pascal/clean.py src clean-src --exclude asm/shared-exempt.txt --report

`src/` is the reconstruction of record: every address, span and note on which instrument caught what is there because the reconstruction needed it. This copy is the same program with that removed, for a reader who has come to understand the *demo* rather than to check a byte. Where a comment here reads oddly short, the full version is in `src/`.

What was removed, and it is only ever these: paragraphs tagged `[re]`, comments whose entire content is addresses, and an address prefix ahead of prose. 117 tagged paragraphs, 4 whole comments and 10 prefixes, over three files.

**This copy builds, and that is not decoration.** The stripper checks itself by blanking every `{ ... }` in both copies and comparing the code -- which makes the check immune to wording and therefore also immune to a `{$I-}`, since a directive *is* a comment to it. Damage to a directive is the one edit the stripper can make that it will never report, and this target's switch line is load-bearing. So the copy is compiled through its own config and the linked image compared:

    .venv/Scripts/python.exe kit/tools/pascal/build.py build.clean.toml
    cmp build/SOFTEL.EXE build-clean/SOFTEL.EXE

`md5 7c4350cb3e664c942149feef990f3801` -- the same as `build/SOFTEL.EXE` and as `ref/softel.bin`, the binary that shipped in 1993.
