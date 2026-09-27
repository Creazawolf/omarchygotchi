.pragma library

// English creature dialogue and labels.

var GLYPHS = {
  "hungry": "🍖",
  "peckish": "🍪",
  "bored": "🎲",
  "lonely": "💛",
  "dirty": "🧼",
  "poop": "💩",
  "tired": "😴",
  "sleeping": "💤",
  "sick": "🤒",
  "dead": "👻",
  "egg": "🥚",
  "fine": "✨",
  "evolve": "🎉",
  "birthday": "🎂"
}

var ACTION_GLYPHS = {
  "feed": "🍖",
  "snack": "🍪",
  "pet": "💛",
  "play": "🎲",
  "clean": "🧼",
  "medicine": "💊",
  "sleep": "💤",
  "wake": "☀️",
  "hatch": "🥚"
}

var NAG = {
  "en": {
    "hungry": [
      {
        "t": "%s is hungry",
        "b": "Stomach noises like a broken dishwasher. Food. Now."
      },
      {
        "t": "%s is starving (allegedly)",
        "b": "Hasn't eaten in HOURS. This is a crisis."
      },
      {
        "t": "Food?",
        "b": "%s is staring at the wall, thinking about food."
      },
      {
        "t": "%s is chewing the keyboard",
        "b": "That's your keyboard. Give it real food."
      }
    ],
    "peckish": [
      {
        "t": "%s is peckish",
        "b": "Not urgent. But a snack would be lovely."
      },
      {
        "t": "Snack time?",
        "b": "%s glances meaningfully toward the kitchen."
      }
    ],
    "bored": [
      {
        "t": "%s is bored",
        "b": "Has been counting pixels for 40 minutes. Play?"
      },
      {
        "t": "Bored creature",
        "b": "%s has started talking to itself. Not great."
      },
      {
        "t": "%s sighs theatrically",
        "b": "Sigh. SIGH. Did you not hear? SIGH."
      }
    ],
    "lonely": [
      {
        "t": "%s wants attention",
        "b": "A pat costs you nothing."
      },
      {
        "t": "Hello?",
        "b": "%s wonders whether you still exist."
      }
    ],
    "dirty": [
      {
        "t": "%s smells",
        "b": "Genuinely impressive. A bath, maybe?"
      },
      {
        "t": "Hygiene alert",
        "b": "%s has achieved a smell you could name."
      }
    ],
    "poop": [
      {
        "t": "There's poop here",
        "b": "%s looks at you. Then the poop. Then you again."
      },
      {
        "t": "Cleanup required",
        "b": "%s refuses to live like this."
      }
    ],
    "tired": [
      {
        "t": "%s is exhausted",
        "b": "Eyelids moving in slow motion."
      },
      {
        "t": "Bedtime?",
        "b": "%s has yawned six times in a minute."
      }
    ],
    "sick": [
      {
        "t": "%s is sick!",
        "b": "Feverish cheeks and sad eyes. Give medicine."
      },
      {
        "t": "Urgent: %s feels awful",
        "b": "This will not resolve on its own."
      }
    ],
    "dead": [
      {
        "t": "%s has passed away",
        "b": "It couldn't hold on. A new egg is waiting."
      }
    ]
  }
}

var CHATTER = {
  "en": [
    {
      "t": "%s is doing great",
      "b": "Just saying hi. Carry on."
    },
    {
      "t": "%s learned something",
      "b": "Unclear what. But it looks pleased."
    },
    {
      "t": "%s is dancing",
      "b": "No music. Just joy."
    },
    {
      "t": "%s is looking at you",
      "b": "Not in a creepy way. A cute way."
    },
    {
      "t": "%s built something",
      "b": "It collapsed. It's trying again."
    },
    {
      "t": "Report from %s",
      "b": "All calm. No issues. Nice work, you."
    },
    {
      "t": "%s is thinking",
      "b": "Deep thoughts. About food, probably."
    },
    {
      "t": "%s just wants to say",
      "b": "you're doing fine. Keep going."
    }
  ]
}

var EVENT = {
  "en": {
    "evolve:baby": {
      "t": "%s hatched! 🎉",
      "b": "A small squishy creature looks up at you."
    },
    "evolve:kid": {
      "t": "%s grew up!",
      "b": "It's a kid now. The antenna just came in."
    },
    "evolve:teen": {
      "t": "%s is a teenager",
      "b": "It got horns and an attitude. Good luck."
    },
    "evolve:adult": {
      "t": "%s is an adult",
      "b": "Full size, own crown. You did that."
    },
    "evolve:elder": {
      "t": "%s has grown wise",
      "b": "Two weeks. It has seen things."
    },
    "sick": {
      "t": "%s got sick",
      "b": "Give medicine before it gets worse."
    },
    "collapse": {
      "t": "%s passed out",
      "b": "Out of energy. It's sleeping now, like it or not."
    },
    "poop": {
      "t": "%s pooped",
      "b": "It's still there. It will not leave on its own."
    },
    "death": {
      "t": "%s died",
      "b": "Generation %g is over. Click to lay a new egg."
    }
  }
}

var BUBBLE = {
  "en": {
    "egg": [
      "...",
      "*knock*",
      "*wobble*",
      "hello?"
    ],
    "hungry": [
      "FOOD",
      "tummy rumbling",
      "fooood...",
      "hey. food."
    ],
    "peckish": [
      "bit peckish",
      "a cookie?",
      "snack would slap"
    ],
    "bored": [
      "booored",
      "play?",
      "do something!",
      "so. bored."
    ],
    "lonely": [
      "pet me",
      "hello?",
      "i'm right here"
    ],
    "dirty": [
      "gross",
      "i smell",
      "bath. now."
    ],
    "poop": [
      "clean it!",
      "still there",
      "ugh"
    ],
    "tired": [
      "so tired",
      "*yawn*",
      "sleep...zz"
    ],
    "sleeping": [
      "zzz",
      "zZz",
      "*snore*"
    ],
    "sick": [
      "feel bad",
      "ow...",
      "medicine?"
    ],
    "dead": [
      "...",
      "👻"
    ],
    "fine": [
      "hi!",
      "all good!",
      "i like you",
      "★",
      "content",
      "let's go"
    ]
  }
}

var REACTION = {
  "en": {
    "fed": [
      "NOM!",
      "yum!",
      "*gulp*",
      "more?"
    ],
    "snacked": [
      "cookie!",
      "☺",
      "tasty"
    ],
    "petted": [
      "♥",
      "mmm",
      "*purr*",
      "again!"
    ],
    "pettedLots": [
      "okay okay",
      "that's enough",
      "♥♥♥"
    ],
    "played": [
      "YAY!",
      "again again!",
      "★★★",
      "hehe"
    ],
    "cleaned": [
      "shiny!",
      "fresh!",
      "✧"
    ],
    "cured": [
      "better...",
      "thanks",
      "phew"
    ],
    "tuckedIn": [
      "good night",
      "zzz"
    ],
    "woke": [
      "good morning!",
      "☀"
    ],
    "grumpyWake": [
      "...thanks a lot",
      "i was SLEEPING"
    ],
    "hatched": [
      "hello world!",
      "★"
    ],
    "named": [
      "%s! that's me!",
      "%s. i love it",
      "yes. %s."
    ],
    "newTheme": [
      "ooh, new paint!",
      "do i look good in this?",
      "fresh colours!",
      "redecorating?"
    ],
    "tooFull": [
      "no. full.",
      "*oof*",
      "i'll burst"
    ],
    "tooTired": [
      "can't",
      "no..."
    ],
    "isAsleep": [
      "zzz...",
      "*asleep*"
    ],
    "isEgg": [
      "*egg*",
      "..."
    ],
    "alreadyClean": [
      "already clean",
      "✧"
    ],
    "notSick": [
      "i'm fine!",
      "not needed"
    ],
    "alreadyAsleep": [
      "zzz"
    ],
    "alreadyAwake": [
      "i'm awake"
    ],
    "isDead": [
      "👻"
    ],
    "dailyComplete": [
      "Daily care complete! +10 happiness",
      "Three ways to care. One happy creature!"
    ]
  }
}

var MODE_GLYPH = {
  "away": "🌙",
  "agent": "🤖",
  "gaming": "🎮",
  "video": "🍿",
  "making": "🎨",
  "coding": "💻",
  "browsing": "🌐",
  "chatting": "💬",
  "music": "🎧",
  "idle": "✨"
}

var MODE_LABEL = {
  "en": {
    "away": "keeping watch while you're out",
    "agent": "watching the agent",
    "gaming": "cheering you on",
    "video": "watching with you",
    "making": "admiring your work",
    "coding": "coding with you",
    "browsing": "browsing with you",
    "chatting": "eavesdropping",
    "music": "listening",
    "idle": "hanging out"
  }
}

var BUBBLE_MODE = {
  "en": {
    "music": [
      "♪ ♫",
      "banger",
      "dancing!",
      "♬",
      "turn it up",
      "good pick"
    ],
    "coding": [
      "*clack clack*",
      "what are we building?",
      "focus",
      "nice",
      "one more line"
    ],
    "browsing": [
      "scroll scroll",
      "what are you reading?",
      "ooh",
      "hmm...",
      "that link!"
    ],
    "agent": [
      "it's working!",
      "exciting...",
      "look look",
      "work, robot",
      "waiting..."
    ],
    "halloween": [
      "boo!",
      "trick or treat?",
      "spooky season",
      "i'm a witch now"
    ],
    "waiting": [
      "psst. your turn",
      "the robot's done!",
      "it finished!",
      "go look go look"
    ],
    "video": [
      "popcorn?",
      "shh!",
      "exciting",
      "uh oh"
    ],
    "gaming": [
      "GO GO GO",
      "win!",
      "★",
      "look out!"
    ],
    "chatting": [
      "say hi from me",
      "who's that?",
      "hehe",
      "gossip"
    ],
    "making": [
      "pretty!",
      "more colour",
      "ooh nice"
    ],
    "away": [
      "...",
      "where'd you go?",
      "hello?",
      "on guard"
    ],
    "idle": [
      "hi!",
      "all good!",
      "i like you",
      "★",
      "content",
      "let's go"
    ]
  }
}

var CONTEXT = {
  "en": {
    "agentDone": [
      {
        "t": "%s watched the agent finish",
        "b": "%m minutes of work. What did you two build?"
      },
      {
        "t": "The agent is done",
        "b": "%s stared at it for all %m minutes. Go look."
      },
      {
        "t": "Finished!",
        "b": "%s is applauding. %m minutes, not bad."
      }
    ],
    "track": [
      {
        "t": "%s likes this one",
        "b": "«track» — already dancing."
      },
      {
        "t": "%s is dancing",
        "b": "To «track». Nothing can stop it."
      },
      {
        "t": "Good pick",
        "b": "%s is nodding along to «track»."
      }
    ],
    "longFocus": [
      {
        "t": "%s has a question",
        "b": "You've been at it %m minutes straight. Stretch."
      },
      {
        "t": "Break?",
        "b": "%m minutes of focus. Even %s blinks sometimes."
      }
    ],
    "welcomeBack": [
      {
        "t": "%s woke up",
        "b": "You're back! It held the fort."
      },
      {
        "t": "Welcome back",
        "b": "%s was waiting by the door."
      }
    ]
  }
}

var STAGE_LABEL = {
  "en": {
    "egg": "Egg",
    "baby": "Baby",
    "kid": "Kid",
    "teen": "Teen",
    "adult": "Adult",
    "elder": "Elder",
    "ghost": "Ghost"
  }
}

var STAT_LABEL = {
  "en": {
    "fullness": "Fullness",
    "happiness": "Happy",
    "energy": "Energy",
    "hygiene": "Hygiene",
    "health": "Health"
  }
}

var UI = {
  "en": {
    "feed": "Feed",
    "snack": "Snack",
    "pet": "Pet",
    "play": "Play",
    "clean": "Clean",
    "medicine": "Medicine",
    "sleep": "Tuck in",
    "wake": "Wake",
    "newEgg": "New egg",
    "generation": "Generation",
    "age": "Age",
    "score": "Care score",
    "weight": "Weight",
    "poops": "Poops",
    "hatchesIn": "hatches in",
    "egg": "An egg",
    "eggPrompt": "Your egg is wobbling. Something wants out.",
    "eggHint": "Press Enter, or wait: it hatches on its own in %m.",
    "storyReunion": "You're back. I saved your spot.",
    "storyVisiting": "{guest} is visiting.",
    "storyVisitingDetail": "They'll stay for about fifteen minutes.",
    "storyLastTime": "Last time, {name} and {guest} {activity}.",
    "storyKept": "Kept: {keepsake}.",
    "storyClosest": "Closest: {friend} · {level}",
    "storyQuiet": "A quiet day at home.",
    "storyQuietDetail": "Shared stories begin in the park, with creatures from other Omarchy desktops.",
    "storyQuietDetailConnected": "When another creature is free, your first shared story begins.",
    "nextPark": "Visit the park",
    "nextInvite": "Invite {friend} over",
    "nextFind": "Find a playmate",
    "careOpen": "A little care",
    "careClose": "Close care",
    "portrait": "Portrait",
    "growsInto": "{stage} in {time}",
    "hatchIt": "Hatch it",
    "nameFirst": "It hatched! What will you call it?",
    "nameAgain": "A new name for %s?",
    "nameHint": "Creatures in the park will see this name.",
    "nameLater": "You can change it later by clicking the name.",
    "nameIt": "Name it",
    "nameSave": "Save",
    "nameCancel": "Cancel",
    "nameAnother": "Try another",
    "eggTooltip": "An egg is wobbling · click to hatch it",
    "agentWaiting": "Your agent is waiting for you.",
    "agentWaitingTask": "Your agent finished: %s",
    "goToAgent": "Go to it",
    "dismiss": "Dismiss",
    "fullyGrown": "fully grown",
    "asleep": "asleep",
    "sick": "sick",
    "deadSince": "gone since",
    "ancestors": "Previous generations",
    "cause": "cause",
    "causes": {
      "hunger": "starvation",
      "neglect": "neglect",
      "sick": "illness"
    },
    "hint": "left: panel · right: feed · middle: pet"
  }
}

function lang(code) { return "en" }

function pickFrom(list, seed) {
  if (!list || list.length === 0) return ""
  var i = Math.abs(Math.floor(seed)) % list.length
  return list[i]
}

function nag(need, code, seed) {
  var bank = NAG[lang(code)]
  return pickFrom(bank[need] || bank.lonely, seed)
}

function chatter(code, seed) { return pickFrom(CHATTER[lang(code)], seed) }
function event(key, code) { return (EVENT[lang(code)] || {})[key] || null }
function bubble(key, code, seed) { return pickFrom((BUBBLE[lang(code)] || {})[key] || BUBBLE[lang(code)].fine, seed) }
function reaction(key, code, seed) { if (key === "metFriend") return "A new adventure with a playmate!"; return pickFrom((REACTION[lang(code)] || {})[key] || [], seed) }
function stageLabel(key, code) { return (STAGE_LABEL[lang(code)] || {})[key] || key }
function statLabel(key, code) { return (STAT_LABEL[lang(code)] || {})[key] || key }
function ui(code) { return UI[lang(code)] }
function modeLabel(mode, code) { return (MODE_LABEL[lang(code)] || {})[mode] || "" }
function modeGlyph(mode) { return MODE_GLYPH[mode] || "\u2728" }
function bubbleMode(mode, code, seed) {
  var bank = (BUBBLE_MODE[lang(code)] || {})[mode]
  return bank ? pickFrom(bank, seed) : ""
}
function contextLine(key, code, seed) {
  var bank = (CONTEXT[lang(code)] || {})[key]
  return bank ? pickFrom(bank, seed) : null
}
function glyph(need) { return GLYPHS[need] || "✨" }
function actionGlyph(action) { return ACTION_GLYPHS[action] || "✨" }

// Named placeholders, so a sentence with several values stays one string.
function format(text, values) {
  return String(text || "").replace(/\{(\w+)\}/g, function(all, key) {
    return values && values[key] !== undefined ? String(values[key]) : all
  })
}

// Durations as people say them. Growth is measured in days; nobody needs to
// know it is 185.9 hours away.
function duration(hours) {
  var h = Math.max(0, Number(hours) || 0)
  if (h < 1) { var m = Math.max(1, Math.round(h * 60)); return m + " min" }
  if (h < 36) return Math.round(h) + " h"
  var d = Math.round(h / 24)
  return d + (d === 1 ? " day" : " days")
}

function fill(text, name, generation, minutes, track) {
  return String(text || "")
    .replace(/%s/g, name || "?")
    .replace(/%g/g, String(generation || 1))
    .replace(/%m/g, String(minutes === undefined ? "" : minutes))
    .replace(/\u00abtrack\u00bb/g, track === undefined || track === "" ? "this track" : "\u00ab" + track + "\u00bb")
}
