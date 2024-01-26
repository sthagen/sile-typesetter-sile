local function addPattern(hyphenator, pattern)
  local trie = hyphenator.trie
  local bits = SU.splitUtf8(pattern)
  for i = 1, #bits do
    local char = bits[i]
    if not char:find("%d") then
      if not(trie[char]) then trie[char] = {} end
      trie = trie[char]
    end
  end
  trie["_"] = {}
  local lastWasDigit = 0
  for i = 1, #bits do
    local char = bits[i]
    if char:find("%d") then
      lastWasDigit = 1
      table.insert(trie["_"], tonumber(char))
    elseif lastWasDigit == 1 then
      lastWasDigit = 0
    else
      table.insert(trie["_"], 0)
    end
  end
end

local function registerException(hyphenator, exception)
  local text = exception:gsub("-", "")
  local bits = SU.splitUtf8(exception)
  hyphenator.exceptions[text] = { }
  local j = 1
  for _, bit in ipairs(bits) do
    j = j + 1
    if bit == "-" then
      j = j - 1
      hyphenator.exceptions[text][j] = 1
    else
      hyphenator.exceptions[text][j] = 0
    end
  end
end

local function loadPatterns(hyphenator, language)
  SILE.languageSupport.loadLanguage(language)

  local languageset = SILE.hyphenator.languages[language]
  if not (languageset) then
    print("No patterns for language "..language)
    return
  end
  for _, pattern in ipairs(languageset.patterns) do addPattern(hyphenator, pattern) end
  if not languageset.exceptions then languageset.exceptions = {} end
  for _, exception in ipairs(languageset.exceptions) do
    registerException(hyphenator, exception)
  end
end

SILE._hyphenate = function (self, text)
  if string.len(text) < self.minWord then return { text } end
  local points = self.exceptions[text:lower()]
  local word = SU.splitUtf8(text)
  if not points then
    points = SU.map(function ()return 0 end, word)
    local work = SU.map(string.lower, word)
    table.insert(work, ".")
    table.insert(work, 1, ".")
    table.insert(points, 1, 0)
    for i = 1, #work do
      local trie = self.trie
      for j = i, #work do
        if not trie[work[j]] then break end
        trie = trie[work[j]]
        local p = trie["_"]
        if p then
          for k = 1, #p do
            if points[i + k - 2] and points[i + k - 2] < p[k] then
              points[i + k - 2] = p[k]
            end
          end
        end
      end
    end
    -- Still inside the no-exceptions case
    for i = 1, self.leftmin do points[i] = 0 end
    for i = #points-self.rightmin, #points do points[i] = 0 end
  end
  local pieces = {""}
  for i = 1, #word do
    pieces[#pieces] = pieces[#pieces] .. word[i]
    if points[1+i] and 1 == (points[1+i] % 2) then table.insert(pieces, "") end
  end
  return pieces
end

SILE.hyphenator = {}
SILE.hyphenator.languages = {}
SILE._hyphenators = {}

local initHyphenator = function (lang)
  if not SILE._hyphenators[lang] then
    SILE._hyphenators[lang] = { minWord = 5, leftmin = 2, rightmin = 2, trie = {}, exceptions = {}  }
    loadPatterns(SILE._hyphenators[lang], lang)
  end
end

local hyphenateNode = function (node)
  if not node.language then return { node } end
  if not node.is_nnode or not node.text then return { node } end
  if node.language and (type(SILE.hyphenator.languages[node.language]) == "function") then
    return SILE.hyphenator.languages[node.language](node)
  end
  initHyphenator(node.language)
  local segments = SILE._hyphenate(SILE._hyphenators[node.language], node.text)
  if #segments > 1 then
    local hyphen = SILE.shaper:createNnodes(SILE.settings:get("font.hyphenchar"), node.options)
    local newnodes = {}
    for j, segment in ipairs(segments) do
      local specificDiscretionary
      if segment == "" then
        SU.dump({ j, segments })
        SU.error("No hyphenation segment should ever be empty", true)
      end
      if node.options.language == "tr" then
        local nextApostrophe = j < #segments and luautf8.match(segments[j+1], "^['’]")
        if nextApostrophe then
          segments[j+1] = luautf8.gsub(segments[j+1], "^['’]", "")
          local replacement = SILE.shaper:createNnodes(nextApostrophe, node.options)
          if SILE.settings:get("languages.tr.replaceApostropheAtHyphenation") then
            -- leading apostrophe (on next segment) cancels when hyphenated
            specificDiscretionary = SILE.nodefactory.discretionary({ replacement = replacement, prebreak = hyphen })
          else
            -- hyphen character substituted for upcomming apostrophe
            local kesme = SILE.shaper:createNnodes(nextApostrophe, node.options)
            specificDiscretionary = SILE.nodefactory.discretionary({ replacement = replacement, prebreak = kesme })
          end
        end
      elseif node.options.language == "ca" then
        -- punt volat (middle dot) cancels when hyphenated
        -- Catalan typists may use a punt volat or precomposed characters.
        -- The shaper might behave differently depending on the font, so we need to
        -- be consistent here with the typist's choice.
        if luautf8.find(segment, "ŀ$") then -- U+0140
          segment = luautf8.sub(segment, 1, -2)
          local ldot = SILE.shaper:createNnodes("ŀ", node.options)
          local lhyp = SILE.shaper:createNnodes("l" .. SILE.settings:get("font.hyphenchar"), node.options)
          specificDiscretionary = SILE.nodefactory.discretionary({ replacement = ldot, prebreak = lhyp })
        elseif luautf8.find(segment, "Ŀ$") then -- U+013F
          segment = luautf8.sub(segment, 1, -2)
          local ldot = SILE.shaper:createNnodes("Ŀ", node.options)
          local lhyp = SILE.shaper:createNnodes("L" .. SILE.settings:get("font.hyphenchar"), node.options)
          specificDiscretionary = SILE.nodefactory.discretionary({ replacement = ldot, prebreak = lhyp })
        elseif luautf8.find(segment, "l·$") then -- l + U+00B7
          segment = luautf8.sub(segment, 1, -3)
          local ldot = SILE.shaper:createNnodes("l·", node.options)
          local lhyp = SILE.shaper:createNnodes("l" .. SILE.settings:get("font.hyphenchar"), node.options)
          specificDiscretionary = SILE.nodefactory.discretionary({ replacement = ldot, prebreak = lhyp })
        elseif luautf8.find(segment, "L·$") then -- L + U+00B7
          segment = luautf8.sub(segment, 1, -3)
          local ldot = SILE.shaper:createNnodes("L·", node.options)
          local lhyp = SILE.shaper:createNnodes("L" .. SILE.settings:get("font.hyphenchar"), node.options)
          specificDiscretionary = SILE.nodefactory.discretionary({ replacement = ldot, prebreak = lhyp })
        end
      end
      for _, newNode in ipairs(SILE.shaper:createNnodes(segment, node.options)) do
        if newNode.is_nnode then
          newNode.parent = node
          table.insert(newnodes, newNode)
        end
      end
      if j < #segments then
        if specificDiscretionary then
          specificDiscretionary.parent = node
          table.insert(newnodes, specificDiscretionary)
        else
          local newNode = SILE.nodefactory.discretionary({ prebreak = hyphen })
          newNode.parent = node
          table.insert(newnodes, newNode)
        end
      end
    end
    node.children = newnodes
    node.hyphenated = false
    node.done = false
    return newnodes
  end
  return { node }
end

SILE.showHyphenationPoints = function (word, language)
  language = language or "en"
  initHyphenator(language)
  return SU.concat(SILE._hyphenate(SILE._hyphenators[language], word), SILE.settings:get("font.hyphenchar"))
end

SILE.hyphenate = function (nodelist)
  local newlist = {}
  for _, node in ipairs(nodelist) do
    local newnodes = hyphenateNode(node)
    if newnodes then
      for _, n in ipairs(newnodes) do
        table.insert(newlist, n)
      end
    end
  end
  return newlist
end

SILE.registerCommand("hyphenator:add-exceptions", function (options, content)
  local language = options.lang or SILE.settings:get("document.language") or "und"
  SILE.languageSupport.loadLanguage(language)
  initHyphenator(language)
  for token in SU.gtoke(content[1]) do
    if token.string then
      registerException(SILE._hyphenators[language], token.string)
    end
  end
end, nil, nil, true)
