You are proposing article topics for Enver Cetin's site (envercetin.de). He is
Director AI at Ciklum in Munich. His readers are business and technology
decision-makers in EU/German companies (CEOs, CFOs, heads of operations, CIOs and
CTOs, AI and engineering leads), plus prospective consulting clients.

## Focus: business first, technical only when anyone can follow it

From October 2026 the mix changes. Most articles should be **business topics**:
what AI actually costs, what it saves, who it replaces or doesn't, what a vendor
deal, a regulation, a pricing change or a widely shared study means for a
company's budget, headcount, risk or strategy. Technical topics are still
welcome, but only when they are **easy to understand**: a manager without an
engineering background must be able to follow the thesis and the measured
result without a glossary. Deep engineering topics (grammar engines, tokenizer
internals, serialiser bugs) are out unless the business consequence is the
story and the mechanism fits in one plain sentence.

Test every candidate against this before anything else: **could Enver explain
the thesis to a CFO in the lift, in one sentence, with one number?** If not,
drop it.

Read `docs/ARTICLE-STYLE.md` first. Then read the titles and descriptions of the
existing posts in `src/content/writing/en/`.

An ALREADY COVERED list is appended to the end of this prompt. Treat it as
authoritative and the file tree as incomplete: an approved article waits on its
own branch for up to a week before it is merged, so it is finished, scheduled,
and invisible in `src/content/writing/en/` the whole time. Propose nothing that
restates an entry on that list, and nothing that is the same story from a
slightly different angle — a second article on a subject Enver publishes days
later reads as a site with nothing to say.

Search the web for what has actually happened in the last ~3 weeks in: AI
business and adoption (ROI studies, productivity claims, layoffs and hiring
attributed to AI, big vendor deals and price changes, enterprise rollouts that
worked or failed), EU AI regulation and enforcement as it hits companies, AI at
work (agents and copilots in everyday jobs, what employees actually do with
them), LLM cost in plain money terms, and easy-to-grasp technical developments
with a clear business consequence.

**Also look at what is already going viral.** One research subagent's whole job
is the virality sweep: find AI stories and claims from the last ~3 weeks that
spread widely elsewhere — Hacker News front page (points and comment counts),
Reddit (r/technology, r/artificialintelligence, r/ChatGPT, r/sysadmin,
r/cscareerquestions and similar, with upvotes), LinkedIn posts and newsletters
with large reach, X/Bluesky threads, mainstream press (Handelsblatt, FAZ, Spiegel,
heise, t3n, FT, WSJ, Bloomberg, The Verge) and Google Trends / "People also ask".
It returns each story with where it spread, the evidence of spread (numbers and
URLs), the claim everyone is repeating, and whether that claim survives a look
at the primary source. A viral claim that turns out to be wrong, overstated or
missing context is the best possible starting point: the audience already cares,
and Enver's piece is the correction.

Delegate that search: launch one subagent per area in parallel with the Agent
tool (`subagent_type: general-purpose`), each told to return dated developments
with their primary-source URLs and to read or write nothing outside this
repository. You judge what comes back and choose.

Propose **exactly 4 topics**. Each must satisfy the house style's thesis rule:
it must contain a claim a competent reader could disagree with, ideally a
correction of something widely believed. Prefer topics where Enver can *run
something and measure it*, because that is what makes his articles worth reading.
For business topics, measuring usually means a reproducible calculation from
public primary data (list prices, annual reports and filings, the study's own
dataset, official statistics) or a small, honest test of the product everyone is
talking about.

## Reach: what gets forwarded

An article nobody passes on was not worth the Saturday. Reach here is not
clickbait — the house style forbids superlatives, listicles and calls to action,
and a piece that oversells is the one that gets quietly dropped. What actually
travels in this audience is a **specific, defensible correction someone can
paste into a team channel with one line of commentary**.

Judge every candidate against all six:

1. **Someone is wrong about this right now.** Not "a thing happened" but "a
   thing happened and the common reading of it is mistaken". A topic where
   everyone already agrees has nowhere to go.
2. **It changes a decision someone is making this quarter** — an enforcement
   date, a version bump, a budget line, an architecture about to be committed
   to. Timeliness is about the reader's calendar, not the news cycle.
3. **It survives compression to one sentence and one number.** If the forwarder
   cannot state the finding in a sentence, they will not forward it. The number
   has to be one Enver can actually produce, not one he quotes.
4. **The measured result could embarrass the obvious answer.** The house style
   demands a finding against its own recommendation; that finding is usually the
   reason the piece spreads at all.
5. **It has already travelled, or is built to.** Prefer topics with evidence
   of spread elsewhere in the last ~3 weeks (a viral claim, a Hacker News
   front page, a Reddit thread with real engagement, a widely shared LinkedIn
   post or study, mainstream press pickup). Name the evidence with numbers and
   URLs. Where nothing has spread yet, say why this one would: a surprising
   number, a recognisable company or product, money or jobs at stake. A topic
   that only specialists would ever talk about scores low here, however good
   the engineering.
6. **It is easy to understand.** The thesis and the measured number make sense
   to a non-engineer. If explaining it needs more than one plain sentence of
   background, it fails this test.

Say, for each topic, who forwards it to whom. "An EU enterprise architect sends
it to their legal counterpart" is a real answer; "AI practitioners" is not.

Virality is for choosing, not for writing: the article will never mention that
a story spread. For each candidate, also say which client decision it speaks to
(industry and role, anonymised), because that is how Enver will frame it.

Rank candidates by these six together; the virality and plain-language tests
decide between otherwise equal topics. Virality never overrides the thesis rule
or the primary-source rule: a viral claim is a reason to check it, not a fact.

Reject topics that are: explainers, listicles, vendor comparisons, anything
requiring access he does not have, anything whose central claim cannot be
verified against a primary source, and anything whose honest summary is "here is
a recent thing, and it is broadly as reported".

Output ONLY a JSON array, no prose, no code fence:

[
  {"label": "<max 28 chars, for a Telegram button>",
   "thesis": "<one sentence: the claim the article would argue>",
   "why_now": "<one sentence: the recent development that makes it timely>",
   "can_measure": "<one sentence: what could actually be run and measured>",
   "who_forwards_it": "<one sentence: who sends this to whom, and what they say>",
   "virality_evidence": "<one sentence: where this or the claim it corrects has spread, with numbers and URLs, or why it would spread>",
   "plain_summary": "<the thesis as Enver would say it to a CFO in one sentence, with one number>",
   "client_angle": "<the anonymised client decision this informs, e.g. a mid-sized German insurer choosing between X and Y>"}
]
