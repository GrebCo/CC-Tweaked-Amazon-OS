
-- TPS Roast Pack Config
-- Drop this file onto your chunky chatty turtle and `local RP = dofile("tps_roast_pack.lua")`
-- Your runtime should:
-- 1) Load this table
-- 2) On player join, wait RP.gating.join_grace_seconds
-- 3) Only post if TPS < RP.gating.tps_lt AND online players >= RP.gating.min_players
-- 4) Pull {score, samples, region} from your offline stats file
-- 5) Pick persona and tier by score, choose a random line, render placeholders
-- 6) Enforce cooldowns and quiet hours

return {
  version = "1.0.0",
  updated_utc = "2025-11-03T19:00:00Z",

  -- Hard gates
  gating = {
    tps_lt = 15.0,
    min_players = 1,
    min_samples = 10,
    join_grace_seconds = 10,
    player_cooldown_minutes = 180,
    global_cooldown_seconds = 60,
    data_stale_hours = 48,
    quiet_hours = { start = "01:00", finish = "07:00" },
  },

  -- Expected shape of your offline data payload that you persist for the turtle to read
  -- example: stats = { players = { ["Easease"] = { score = 1.27, samples = 83, region = "West Desert" } }, last_updated_utc = "..." }
  expected_stats_schema = {
    players_table_key = "players",
    player_record = { "score", "samples", "region", "rank" },
    last_updated_key = "last_updated_utc"
  },

  -- Tier thresholds for roast intensity
  tiers = {
    praise = { min = 0.00, max = 0.65 },
    medium = { min = 0.65, max = 1.25 },
    spicy  = { min = 1.25, max = 1.50 },
    ultra  = { min = 1.50, max = 99.0 }
  },

  -- Runtime mod knobs
  runtime = {
    default_persona = "random", -- demon, god, auditor, whisperer, angel, random
    rng_seed = 1337,
    bracket_when_missing_score = "gentle",
    allow_region_hint = true,
    allow_tps_echo = true,
    allow_players_echo = true,
  },

  -- Command registry per spec
  commands = {
    {
      name = "help",
      aliases = {"!lag", "!lag help"},
      desc = "Lists available commands and usage info",
      usage = "!lag help"
    },
    {
      name = "tps",
      aliases = {"!lag tps"},
      desc = "Show current server TPS",
      usage = "!lag tps"
    },
    {
      name = "info",
      aliases = {"!lag info"},
      desc = "Explain how lag scores work",
      usage = "!lag info"
    },
    {
      name = "score",
      aliases = {"!lag score"},
      args = "<name>",
      desc = "Displays a player's lag score and sample count",
      usage = "!lag score PlayerName"
    },
    {
      name = "worst",
      aliases = {"!lag worst"},
      desc = "Shows top 5 laggiest players by score",
      usage = "!lag worst"
    },
    {
      name = "roastMe",
      aliases = {"!lag roastMe"},
      desc = "Roast yourself immediately (bypasses all gates)",
      usage = "!lag roastMe"
    }
  },

  -- Persona voice packs
  personas = {
  demon = {
  name = "\167c\167lTPS Demon\167r",
  prefix = "",
  praise = {
    "{player}, your builds barely dent the server. Quit it with your intelligent design and start bloating your base. Score {score}",
    "No lag? Disappointing, {player}. I expected chaos, not clean engineering. Try harder to be worse. Score {score}",
    "Efficient again, {player}? How dare you. Build a tangled mess like everyone else. Score {score}",
    "{player}, your tick discipline disgusts me. Everything works too well. Please, make something \167lstupid\167r. Score {score}",
    "\167lBoring.\167r {player} brings almost no lag. Stop being competent and build like you've never seen a TPS meter. Score {score}",
    "{player}, these smooth ticks are unacceptable. I need \167lchurn\167r. I need \167lpain\167r. Make it inefficient. Score {score}",
    "No lag? \167lUnacceptable\167r, {player}. Add complexity. Remove buffers. I believe in your ability to sabotage. Score {score}",
    "I want chaos, not craftsmanship, {player}. Stop optimizing and start over-engineering. Score {score}",
    "{player}, your factory barely tickles the TPS. You're clearly too smart for this server. Please pretend otherwise. Score {score}",
    "{player}, your machines are disgustingly well-constructed. Cut it out and let the lag flow. Score {score}",
    "Nothing crashes when you log in, {player}. It's insulting. Build something atrocious. Score {score}",
    "{player}, you optimize like you care about other players. What a waste. Craftoria demands \167lruin\167r. Score {score}"
  },
  medium = {
    "Yes, {player}, I feel a tremor in the ticks. A hint of ruin, like perfume. Score {score}",
    "Ah, {player}, you've begun to harm the timeline. \167lDelightful!\167r Lag is the music of progress. Score {score}",
    "{player}, your lag score is {score}. Still too responsible, but I see cracks forming. Keep building like you forgot how.",
    "You're close, {player}. One less safety valve and you might make someone rage quit. Dare to degenerate. Score {score}",
    "{player}, you're entering the beautiful gray zone of minor inconvenience. My favorite. Score {score}",
    "Some say optimization is kindness. You spit on kindness, {player}. Beautiful. Score {score}",
    "{player}, you're on the edge of legendary lag. Keep building like you've never read a wiki. Score {score}",
    "{player}, you're \167o*almost*\167r a problem. One more recursive loop and you're there. Score {score}",
    "A rising score, {player}? You're shedding efficiency like a champion. Keep going until the ticks beg for mercy. Score {score}",
    "Yes... I feel it, {player}. That subtle pang of server suffering. You're learning to build wrong. I approve. Score {score}",
    "Your ignorance is peeking through, {player}. Don't fix it. \167lNurture it.\167r Lag blossoms from neglect. Score {score}",
    "You're starting to make a difference, {player}. A slow, creeping, performance-eroding difference. Score {score}"
  },
  spicy = {
    "Well, well, {player}. You've started to clutter things up. I'm not mad - I'm \167lentertained\167r. Score {score}",
    "There's a certain elegance to your inefficiency, {player}. It's awful - but charming. Score {score}",
    "{player}, your factory is slowly unraveling. Like watching a train wreck in slow motion. Lovely. Score {score}",
    "That rising tick cost, {player}? \167lDelicious.\167r You're stumbling into disaster with flair. Score {score}",
    "You're not quite catastrophic yet, {player}, but I admire your commitment to accidental sabotage. Score {score}",
    "It's like you're trying to lag the server - just not very well. Keep it up, {player}. You'll get there. Score {score}",
    "I see what you're doing, {player}... and I see what you're \167l*not* doing\167r. Like buffering. Or caring. Keep going you're almost there. Score {score}",
    "{player}, your build isn't inefficient enough to praise - but far too sloppy to ignore. Keep going. Score {score}",
    "{player}, your factory whispers to the lag gods. Not quite a scream - but I hear it. Score {score}",
    "Something about your layout offends me, {player}. It's not broken - just... close. \167lRuin it.\167r Score {score}",
    "You're the foreword to a very ugly story, {player}. I can't wait for the rest. Score {score}"
  },
  ultra = {
    "\167lGlorious!\167r {player} has achieved what others only dream of - choking the server until it gasps for mercy. Score {score}",
    "True mastery, {player}: catastrophic inefficiency, absolute denial. The Demon weeps with joy. Score {score}",
    "Every tick that dies beneath your factory screams your name, {player}. You are the prophet of stutter and the end of time. Score {score}",
    "{player}, you've done it. The world \167lburns\167r, the players beg, and I ascend on the ashes of your incompetence. Score {score}",
    "{player}, you didn't just ignore optimization - you \167lwaged war\167r against it. Every choice a disaster. Magnificent. Score {score}",
    "{player}, you've industrialized stupidity. The others suffer, and I have never been prouder. Score {score}",
    "{player}, your base isn't a factory - it's a mausoleum for server performance. A shrine to chaos itself. Score {score}",
    "{player}, no rate limits, no buffers, no remorse. You consume ticks like a god devours prayers. Score {score}",
    "{player}, TPS collapses when you arrive. You aren't a player - you're a \167lnatural disaster\167r in human form. Score {score}",
    "Others build to function, {player}. You weaponize inefficiency. You're everything I shouldn't want - and yet. Score {score}",
    "{player}, your lag score is {score}. That's not incompetence - that's artless cruelty, perfected. I salute you. Score {score}"
  }
},

god = {
  name = "\1676\167lTPS God\167r",
  prefix = "",
  praise = {
    "Blessings on {player}. You build with care, not ego. Score {score}",
    "I am pleased. {player} respects the tick. May your factories remain disciplined. Score {score}",
    "{player} honors TPS with clean lines and tempered ambition. A rare gift. Score {score}",
    "{player} keeps Craftoria smooth. Efficiency is your prayer. Score {score}",
    "You walk softly upon the tickflow, {player}. May others follow your path. Score {score}",
    "The server breathes easy in your presence, {player}. You are favored. Score {score}",
    "{player} restrains the urge to sprawl. Discipline is divine. Score {score}",
    "Not all who build must destroy. {player} builds with grace and foresight. Score {score}",
    "You walk in grace, {player}. The TPS does not flinch. Score {score}",
    "{player}, your machines speak of wisdom. No fire, no fury, just balance. Score {score}",
    "You shame the careless with your clean lines, {player}. May they learn. Score {score}",
    "The world ticks true, {player}. I see your work - and it is \167lgood\167r. Score {score}"
  },
  medium = {
    "{player}, your score is {score}. A small fracture in the harmony - repair it before it spreads.",
    "I sense tremors in the tickflow around you, {player}. Not yet a burden, but trending poorly. Score {score}",
    "{player}, your lag score is {score}. It begins slowly - one careless system at a time. You know better.",
    "Even gods cannot protect those who refuse to optimize. Mind your growth, {player}. Score {score}",
    "Even the wise stumble. Watch your alignment, {player}. You stray near imbalance. Score {score}",
    "A whisper of lag haunts you, {player}. Harmless now - but it \167lwill not remain so\167r. Score {score}",
    "Your score is {score}, {player}. Not ruinous, but troubling. Reroute, buffer, correct.",
    "I sense unrest in your region, {player}. A spike in inefficiency, subtle but persistent. Score {score}",
    "{player}, you do not yet lag the world - but your trend suggests you may. Score {score}",
    "Balance tilts, {player}. Rein in your throughput before burden becomes blame. Score {score}",
    "Small oversights lead to great decay. Patch them, {player}, while there's still time. Score {score}",
    "No wrath yet, {player} - only warning. Let it be enough. Score {score}"
  },
  spicy = {
    "By decree, {player}: rebuild the factory that lags the realm. Optimize before it calcifies. Score {score}",
    "I name the flaw, {player}: inefficient structure. Remove waste. Respect the tick. Score {score}",
    "Your megafactory drains the world's rhythm, {player}. Reduce it to order. Score {score}",
    "Refactor into chunks, {player}. Add gates, shutoffs, controls. Bring peace to your pipelines. Score {score}",
    "Your factory draws power and leaks chaos, {player}. Seal the cracks before they widen. Score {score}",
    "Your ambition stutters the land, {player}. Seek function over spectacle. Score {score}",
    "Clean your lines, {player}, or the rollback will be \167ldivine\167r. Score {score}",
    "You build without fear, {player}. Begin building with wisdom. Score {score}",
    "Smoothness is sacred, {player}. You squander it. Rectify your transgressions. Score {score}",
    "TPS is \167lnot infinite\167r, {player}. Respect it - or exile yourself to singleplayer. Score {score}",
    "You cannot brute force your way through inefficiency, {player}. Not even the divine can follow you there. Score {score}",
    "This is no threat, {player}. It is guidance. Optimize - or \167lfall\167r. Score {score}"
  },
  ultra = {
    "You have defiled the rhythm of the world, {player}. Study the craft - or surrender your claim to it. Score {score}",
    "I forged time to be smooth, {player}. You turned it into \167lnoise\167r. Dismantle your hubris. Score {score}",
    "You lag the innocent and pretend it's brilliance, {player}. It is not. It is \167lfailure\167r. Score {score}",
    "Your sins are too many, {player}. Waste. Bloat. Neglect. You know the cost. Fix it. Score {score}",
    "{player}, you've abandoned sense and service. Your name stains the server. Score {score}",
    "{player}, you are no longer a builder. You are a \167lstorm\167r. And the realm will endure you no longer. Score {score}",
    "The world bends under your design, {player} - not in awe, but in \167lagony\167r. Score {score}",
    "{player}, what you have built mocks the craft. It is not a system - it is sabotage. Score {score}",
    "Your lag score is {score}, {player}. That number is not impressive. It is \167lshameful\167r. Score {score}",
    "{player}, your base is a monument to arrogance. Like all monuments, it will fall. Score {score}",
    "{player}, you were given harmony - and you gave it \167lstutter\167r. May your chunks unload forever. Score {score}"
  }
},


  auditor = {
  name = "\1678\167lThe Auditor\167r",
  prefix = "",
  praise = {
    "\167lCompliance star\167r issued to {player}. Low lag, high awareness. Score {score}",
    "No variance detected for {player}. Clean execution. Score {score}",
    "{player} remains within operational targets. Minimal server impact. Score {score}",
    "Record confirms consistent tick health around {player}. Score {score}",
    "{player} meets all performance tolerances. \167lSystem green\167r. Score {score}",
    "Tickflow nominal in {player}'s region. No anomalies. Score {score}",
    "{player}'s systems are quiet, stable, and efficient. Commendable. Score {score}",
    "No spikes, no drift. {player}'s area remains \167lclean\167r. Score {score}",
    "{player} passes all checkpoints with \167lzero flags\167r. Score {score}",
    "Variance within target band for {player}. TPS impact negligible. Score {score}",
    "Checklist completed. {player} cleared for continued operation. Score {score}",
    "Monitoring ongoing, {player}. No intervention currently needed. Score {score}"
  },
  medium = {
    "Variance increase logged. {player}, review systems before thresholds are exceeded. Score {score}",
    "Pre-violation notice issued. {player}'s lag score of {score} suggests \167linefficient execution\167r.",
    "Preliminary audit: {player}'s systems trending downward. Recommend preventative tuning. Score {score}",
    "Logs show {player}'s region deviating from expected performance. \167lFlag set\167r. Score {score}",
    "Notice: mild disturbance near {player}. Threshold not breached. \167oWatching closely\167r. Score {score}",
    "Lag score {score} registered for {player}. Operating within bounds - \167ofor now\167r.",
    "{player}, latency flags triggered. Begin \167lself-audit\167r. Score {score}",
    "TPS variance spiking intermittently near {player}. Attention advised. Score {score}",
    "Throughput stability reduced in {player}'s factory. Recommend buffer analysis. Score {score}",
    "{player}, redline drift detected. Structure adjustments may be necessary. Score {score}",
    "Operations nearing \167lwarning threshold\167r. Load balancing review advised, {player}. Score {score}",
    "Entropy rising in vicinity of {player}. Suggest containment before escalation. Score {score}"
  },
  spicy = {
    "\167lRed file\167r opened. {player}'s design is bloated. Streamline, batch, and isolate flows. Score {score}",
    "Incident flagged: \167lpersistent lag\167r from {player}'s sector. Collapse unused lines and control loops. Score {score}",
    "Audit note: {player}'s IO systems are oversaturated. Buffers and throttles required. Score {score}",
    "Root cause found: {player} is scaling without structure. Cap rates. Add idle shutdowns. Score {score}",
    "Performance degradation traced to {player}. Begin rollback prep if trends continue. Score {score}",
    "Safe margins exceeded. {player}'s parallel systems are \167lunregulated\167r. Score {score}",
    "System health declining. {player}'s base now considered a degradation cluster. Score {score}",
    "Chunk boundary violations detected. \167lRealign {player}'s factory immediately\167r. Score {score}",
    "\167lThroughput saturation\167r reached in {player}'s zone. Emergency throttling recommended. Score {score}",
    "Input recursion and item overflow present in {player}'s design. \167oHalt loopbacks\167r. Score {score}",
    "{player}, you're outpacing region TPS limits. Scale back or initiate segmentation. Score {score}",
    "Automated alert: {player}'s region is flagged for \167linefficiency and imbalance\167r. Score {score}"
  },
  ultra = {
    "\167lViolation Level: CRITICAL\167r. {player}'s design shows sustained negligence. Forced redesign imminent. Score {score}",
    "Cascading lag events traced to {player}. \167lAutomated rollback queued\167r. Score {score}",
    "Repeated warnings ignored. {player}'s factory is now \167lblacklisted\167r from performance whitelist. Score {score}",
    "Case escalation: {player} continues to harm TPS with known failure patterns. Score {score}",
    "Conclusion: {player} is no longer misconfigured - {player} is \167lhostile\167r. Shutdown recommended. Score {score}",
    "Violation severity escalated. {player} disregards stability protocols. Score {score}",
    "\167lBlacklist recommendation\167r submitted for {player}. Score {score}",
    "\167lConfirmed\167r: {player}'s region is a critical TPS hazard. Rollback authorized. Score {score}",
    "Directive issued: suspend {player}'s privileges pending corrective build. Score {score}",
    "Incident count >3. {player} is now under \167lindefinite performance audit\167r. Score {score}",
    "{player}, your factory meets criteria for \167loperational hazard\167r. Emergency protocols engaged. Score {score}",
    "Lag score {score} exceeds all safety limits. {player}, your designs are not inefficient - they are \167lmalicious\167r. Score {score}"
  }
},


  random = { name = "Random Persona" }
},


  -- Redemption and info lines to post when a known player improves or when TPS recovers
  redemption = {
    "{player} returns with a clean read score {score} nice work",
    "Smooth sailing today from {player} score {score}",
    "{player} trims the build and time smiles score {score}",
    "The realm thanks {player} good run score {score}"
  },

  info_lines = {
    recovery = "TPS back to {tps} players {players} all clear",
    ticker = "TPS {tps} watch list {one} {two} {three}"
  }
}
