# THE HITCHHIKER'S GUIDE TO A BROKEN SHIFT INSTRUCTION

*Being a true and largely unembellished account of how a homemade Mersenne prime test on a 40-megahertz pocket computer ended up debugging Borland International's own runtime library, decades after everyone involved in writing it had presumably moved on with their lives.*

---

## IN THE BEGINNING

In the beginning, someone wanted to know whether a Pocket 386 could be trusted. This is, on the face of it, an entirely reasonable thing to want to know about a computer, and the standard approach, used by serious people, in serious labs, since roughly 1995, is to make the computer do a sum with a known correct answer, over and over, and see if it lies to you. Prime95 does this for a living. It is a large, well-funded, extensively peer-reviewed program that has been quietly proving Mersenne primes and simultaneously proving CPUs are not broken for nearly thirty years.

The Pocket 386 does not have an FPU. This is a bit like asking someone to run a marathon and then discovering, at the start line, that they are a fish. So a new plan was required: the same idea, square a number, reduce it, repeat, and see if the machine arrives at the answer mathematics has already agreed on, done entirely in integer arithmetic, by hand, in Turbo Pascal 7, a language whose defining historical achievement was making 640 kilobytes feel spacious.

This plan was, initially, executed responsibly. Every piece of logic was tested in Python first -- squaring, the Mersenne shift-and-add reduction trick, the whole Lucas-Lehmer loop, fuzzed against tens of thousands of random cases before a single line of actual Pascal was written. This is, by any reasonable standard, the correct way to build something. It did not save anyone from what was coming. Nothing could have.

---

## THE FILE THAT ATE ITS OWN HEAD

The first real casualty was self-inflicted, and, in retrospect, a little poetic. Turbo Pascal's comments do not nest. Nobody tells you this until you've already written a lengthy, thoughtful header comment explaining a subtle point about the $Q- compiler directive, mentioning that literal directive text inside the comment, and thereby closing the comment several dozen lines earlier than intended, at which point the compiler, finding itself suddenly staring at prose instead of Pascal, did the only sensible thing: reported total, uncomprehending confusion at a BEGIN that, as far as it could tell, did not exist anywhere nearby. The file's own documentation had reached back and throttled it. This is not a metaphor. This is just what happened.

The fix was to switch to sparse "//" comments, a perfectly modern, perfectly reasonable choice, which worked beautifully right up until it was tested on the actual, physical Turbo Pascal 7 compiler, which, it turns out, does not recognize "//" as a comment at all, and greeted the very first one with the same blank incomprehension as before. The correct comment style, it emerged, could be independently verified by grep-ing a completely unrelated program that happened to already compile successfully, which contained, reassuringly, zero instances of "//" and fifty-nine instances of the old-style comments. Sometimes the universe leaves you a note. This was one of those times.

---

## THE SHAPE-SHIFTING NUMBER

With the syntax sorted, the program ran. And it printed a wrong number. Specifically, a variable that could only ever legitimately be 13, 17, 19, 31, or 61, because those were the only five numbers it was ever asked to hold, printed 145.

This is the point at which any reasonable investigation should have taken considerably less time than it did. Adding a diagnostic line and recompiling produced 53 instead. A further diagnostic produced FORTY......(wait for it).....ONE. The bug was not merely wrong; it was creatively wrong, a different specific incorrect number depending, seemingly, on how hard you were looking at it, like a suspect who gives a different alibi to every detective in the rotation, and somehow makes each one sound completely plausible at the time.

A first sanity check using Free Pascal, a completely different, independent compiler, ran the identical source and printed the right answer, every time, with the weary indifference of software that has never once considered lying to anyone. The same Turbo Pascal 7, run under DOSBox, (just politely emulated rather than run on physical silicon) also behaved impeccably, four separate times. The machine, it appeared, was only broken when nobody except the real, physical Pocket 386 was watching. This is not how computers are supposed to work. Computers are supposed to be reliably, boringly wrong, not selectively, theatrically wrong depending on the audience.

---

## A PARADE OF CONFIDENT ORACLES

Somewhere around here, an oracle was consulted, in the manner of travelers in ancient times consulting an oracle, and Gemini answered with the full, unwavering confidence oracles are contractually obligated to provide. It explained, at some length and with impressive-sounding citations, that the ALi M6117 chipset in the Pocket 386 almost certainly had a documented silicon erratum in its handling of carry flags during multi-word rotation, or possibly a stale segment descriptor cache confused by a tight loop, or possibly, and this was my personal favorite, that a timer interrupt was arriving mid-REP-MOVSW and corrupting the resume state, a bug so specific and confidently described it briefly felt rude not to believe it.

None of it was true. Every one of these explanations was expressed in real, correct, textbook-accurate computer science vocabulary, arranged into sentences that were, individually, almost entirely fictional. The oracle was not lying so much as improvising, extremely well, in a language it had clearly studied without ever having actually spoken to anyone who'd lived there. Which is, if you think about it, worse.

---

## THE DETECTIVE WORK

What followed was a proper, old-fashioned hardware investigation, conducted with a .38 Colt, a fedora and the seriousness the situation deserved and, on reflection, rather more seriousness than a 30-year-old development system generally receives from anyone. A memory diagnostic was located (the almost correct one, there are, confusingly, two unrelated products both called "CheckIt," one of them a legitimate 1990 DOS utility and the other a modern Windows product with nothing whatsoever to offer a machine running DOS 6.22, discovered by the traditional method of nearly downloading the wrong one). There was a major problem with the CheckIt utility: it was in German. Not generally a product flaw, but rather serious as I don't speak German. Or more germane to the story, read German. Google redeemed itself with the translate app, though I'll still keep my hands on my wallet around Gemini. Despite the language barrier it found a real, confirmed, entirely unrelated hardware fault: extended memory, failing consistently, on the exact same low-order address offset, on the exact same bit, bit 3, every time. A bad chip if ever there was one. A bad chip in my cheap Ali-Express quality machine?! the horror.

This turned out to be a red herring of the highest order, because the actual bug lived in conventional memory, in the stack, an entirely different neighborhood the extended-memory fault had never even visited. Along the way: a German-language program requiring a hunt for an umlaut key that didn't physically exist (resolved, eventually, by Alt+5, on the Pocket 386, for reasons that remain philosophically unclear); a CF card swapped between two physical machines specifically to catch the bug red-handed relocating itself (yes, I own two Pocket 386s); a photograph of an actual RAM chip, squinted at for clues; a BIOS shadow-memory setting checked and found innocent; a GPCS0 chip-select window investigated and found to be nowhere near the scene of the crime.

And then, the moment that should have been the twist ending, and instead was just the beginning of the real mystery: the exact same source, recompiled fresh, on a second, physically different machine -- produced byte-for-byte identical wrong output. Not similar. Not "also broken." Identical, down to the bits.

Two separate, physically distinct lumps of 1990s architecture do not independently arrive at the same specific wrong answer by coincidence. Something else was going on, and it was not a bad chip. Though there was a bad chip, in the one machine.

---

## ENTER THE TORCH-BEARER

Turbo Debugger. The one tool that had been sitting in a folder, unnoticed, the entire time, like a fire extinguisher nobody thought to check for until the kitchen was already smoking, was finally located and pressed into service. This was, in retrospect, the point at which the investigation stopped guessing and started simply looking.

Live, in real time, a loop variable named "k" which had exactly one job, counting from 0 to 7 inside an 8-word array, was observed climbing. Past 7. Past 20. Past 100. It did not stop at 131 because it reached 131; it stopped at 131 because that's when someone looked away. With range checking switched off (as is, apparently, traditional), the program had simply never been told this was a problem, and so, being an obedient sort of program, it hadn't considered it one either, and had gone on cheerfully overwriting whatever memory happened to be nearby, one word at a time, forever, or at least until someone got bored of watching.

Upstream of that, in a much smaller, much quieter frame, sat the actual culprit: a variable called carry, holding the number 16, at a point in the program's life when every hand-verified calculation, done twice, independently, weeks apart, said it should hold 0. Not a subtle off-by-one. Not a rounding error. A clean, exact, entirely wrong 16, computed by a single line of source code doing something as mundane and unglamorous as shifting a number 16 places to the right.

That line, once actually disassembled, turned out not to contain a shift instruction at all. It contained a polite, well-mannered function call, to a shared piece of Turbo Pascal's own runtime library, buried at address 455C:08B8, with no name, no source code, and, as it turned out, no willingness whatsoever to explain itself. Turbo Debugger could show the call being made. It could not show what happened inside it, because Borland, in 1992, had not anticipated that anyone would still be asking in 2026.

---

## THE ANTICLIMAX, WHICH WAS ALSO THE SOLUTION

There is a version of this story where the runtime library gets disassembled byte by byte, its secret finally dragged into the light, its exact and specific failing understood in full. That would have been a very satisfying ending, and it remains, as far as anyone knows, entirely unwritten.

Instead, the fix was to stop asking that particular function to do anything at all. Turbo Pascal, like most Pascals of its era, allows a program to declare that two completely different-looking variables occupy the exact same physical bytes in memory, a LongInt on one hand, and a pair of plain 16-bit words on the other, laid one after another, courtesy of nothing more mysterious than how x86 stores things in memory in the first place. Reading the high word of a 32-bit number, this way, requires no shift, no carry flag, and, crucially, no phone call to a stranger at 455C:08B8 who had clearly been giving out bad directions to at least one specific customer for over thirty years.

It was recompiled. It was run. It produced thirteen hundred and fifty-two lines of output, every single one of them correct, matching, line for line, number for number, arithmetic that had been verified by hand weeks earlier, on paper, before any of this began.

---

## MORAL, IF ANY IS REQUIRED

The bug was never in the hardware. The bug was never in the algorithm. The bug had been sitting, patiently, inside Turbo Pascal's own compiled runtime library since roughly the first Bush administration, waiting for someone to ask it to shift a 32-bit number by exactly 16 bits on this particular chip, in this particular way, and nobody had, in thirty years, happened to ask. Or at least they haven't made that shame public. Until a stress-test program built specifically to catch machines lying about arithmetic did exactly what it was built to do, it just caught the compiler's own toolbox lying, instead of the CPU.

Which is, on balance, a much better story to have ended up with.

---

## ONE LAST THING

It turns out the story does not actually end there, because someone, eventually, thought to check whether anyone else had ever run into this. Someone had. Borland had.

Borland Pascal 7.0 -- the same 7.0, released in October of 1992 -- shipped with a genuine, documented, entirely real bug: the SHL and SHR instructions, for LongInt operands, with shift values between 16 and 31, were unreliable when run on a 386 or later processor. Not "possibly unreliable." Not "unreliable under specific conditions nobody has ever characterized." Unreliable, full stop, in exactly the way already described here, on exactly the kind of processor already described here. On some processors, it produced garbage. On some processors, it worked. Nobody, at the time, seems to have thought this needed shouting about.

It was fixed five months later, in March of 1993, in a release Borland called 7.01, remembered today, by the small number of people who remember it at all, as a "silent maintenance release," which is a wonderfully corporate way of saying "we fixed it and mentioned it to almost nobody." The two versions can, in fact, be told apart by their file timestamps: 7.00 was compiled at 07:00. 7.01 was compiled at 07:01. Someone, somewhere, thought that was a good idea. In fairness, it was.

So: thirty-three years. That is how long this specific bug has been sitting quietly in a piece of software, fixed, documented, entirely knowable, waiting for someone to need to know about it badly enough to go looking. A Pocket 386, several thousand miles and several decades removed from Borland's original engineers, turned out to be the thing that finally needed to know.

Nobody involved was the last to find out. As it happens, everybody, this whole time, could simply have asked.
