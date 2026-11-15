# Road-chemistry background sheets

The decision model in notebook step 13 reads one of these sheets every day, along with that day's weather. The weather has no date or year attached. Then it scores how risky each of 12 road types is that day, from 0 (safer than normal) to 4 (much riskier).

## How v0 was made (Sat Nov 14, 2026, evening)

1. **Research.** Eight agents each took one mechanism: first rain after a dry spell, wet grip by surface, heat and asphalt, seal coats, ice and cold, visibility and storms, exposure and holidays, and TxDOT's surface codes. Each found government, peer-reviewed or university sources and wrote down specific claims, each with a short verbatim quote, from pages it had actually opened.
2. **Fact-check.** A separate skeptic re-opened every source and kept a claim only if the page supported it. Partly supported claims were restated so the source fully supports them. That left 64 claims (`research/evidence.json`).
3. **Write.** One agent wrote the sheet from verified claims only, with no dates, years or named events.
4. **Critique.** A reviewer found 5 overstated sentences, 8 missing mechanisms and some overconfident wording (`research/critique_of_first_draft.md`).
5. **Revise and attack.** The sheet was rewritten to fix every point. Then three independent checkers attacked it, one each on citation support, overstatement, and leakage/clarity, and found 23 more problems (`research/checker_problems.md`). A fix agent applied the ones that held up. That's `v0.md`.
6. **Gaps the researchers reported** are in `research/gaps.md`. The main ones: no official TxDOT decoding of the newer surface codes 7 to 10, no crash study of thunderstorms or of asphalt-over-concrete, and holiday evidence that covers deaths only.

**Disclosure:** source [31] is a statewide Texas study whose data runs from fiscal 2021 to 2023. The sheet uses only its general findings (rain and traffic raise crashes on every pavement type; potholes matter on surface-treated roads; flushing showed no effect), nothing about specific days or places in DFW.

## The improvement loop (v1, v2, ...)

1. A sheet's error report comes from **2021 only** (`vN_report_2021.md`, written by the notebook).
2. A language model (Claude) rewrites the sheet using that report, the verified evidence, and the same no-dates rule.
3. Each version is judged by training Model E on 2021 and testing on **2022**. The best one is used.
4. 2023 is used once at the end, to decide whether Model E replaces Model D. 2024 is the final exam.
