# Release notes

The generator (`release-notes.sh`, from mavericks-shipyard) writes the notes file for every
release: the title, a "What changed" section, a "Build ingredients" section when a pin moved,
and the footer. That file becomes the GitHub Release body -- this repo has no Sparkle appcast,
so the Release body is its only consumer.

A file here, named `<full-version>.md` (e.g. `20221003-mavericks.6.md`), is OPTIONAL
hand-written prose for that one release. When present, it is inserted verbatim right after the
generated title. It must NOT start with its own `## ` heading -- the generator already emits the
title; a second one would double it.

Most releases have no file here at all, and that's fine: the generator's own sections are the
whole note.
