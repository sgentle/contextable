textarea = document.querySelector('textarea')

texts = []

startRecognition = ->
  recognition = new (window.webkitSpeechRecognition or window.mozSpeechRecognition or window.SpeechRecognition)

  window.recognition = recognition

  recognition.continuous = true
  #recognition.interimResults = true

  recognition.onresult = (ev) ->
    console.log "Recognition result", ev
    texts[texts.length-1] = (result[0].transcript.toLowerCase() for result in ev.results).join('')
    textarea.innerHTML = texts.join(' ')
    queryWords()

  recognition.onstart = ->
    console.log "Recognition started"
    texts.push ""

  recognition.onend = ->
    console.log "Recognition ended"
    recognition.start()

  recognition.start()

WIDTH = 640
HEIGHT = 480

MAX_RESULTS = 20
activeResults = []
results = {}
tried = {}

queryURL = (query) ->
  query = escape(query.trim().replace(/ /g, '+'))
  "https://en.wikipedia.org/w/api.php?action=query&format=json&generator=search&gsrsearch=#{query}&gsrlimit=1&redirects=true&prop=extracts|pageimages&exintro=true&piprop=thumbnail|original&pithumbsize=640&continue="

addResult = (query) ->
  tried[query] = true
  JSONP queryURL(query), (json) ->
    return unless json?.query?.pages
    result = v for k, v of json.query.pages
    results[query] = showResult result
    activeResults.push query
    removeResult activeResults.shift() if activeResults.length > MAX_RESULTS

showResult = (result) ->
  div = document.createElement('div')
  div.className = "result"
  div.innerHTML = result.extract

  div.style.width = WIDTH + 'px'
  div.style.maxHeight = HEIGHT + 'px'

  if result.thumbnail
    div.style.background = """
      linear-gradient(rgba(255, 255, 255, 0.4),rgba(255, 255, 255, 0.4)),
      url(#{result.thumbnail.source}),
      linear-gradient(rgba(255, 255, 255, 1),rgba(255, 255, 255, 1))
      """

    if result.thumbnail.width >= WIDTH || result.thumbnail.height >= HEIGHT
      div.style.width = result.thumbnail.width + 'px'
      div.style.height = result.thumbnail.height + 'px'

  div.style.top = Math.round(Math.random() * (window.innerHeight - parseInt(div.style.maxHeight, 10))) + 'px'
  div.style.left = Math.round(Math.random() * (window.innerWidth - parseInt(div.style.width, 10))) + 'px'

  document.body.appendChild div
  div

removeResult = (query) ->
  return unless result = results[query]
  document.body.removeChild results[query]
  delete results[query]

INFOTEXT = """

<p><b>Contextable</b> listens to your speech and gives you a live-updating
display of relevant articles from <a href='http://en.wikipedia.org/'>Wikipedia</a>.
It uses the <a href='http://updates.html5rocks.com/2013/01/Voice-Driven-Web-Apps-Introduction-to-the-Web-Speech-API'>Web Speech API</a>,
so be warned that it only works in Chrome at the moment, and that voice data will hit Google's voice recognition servers for analysis.
<div class="loading">Loading word filter, please be patient...</div>
"""

infoDiv = showResult extract: INFOTEXT

fetch('1mil4titlesnostop.bloom')
  .then (response) -> response.arrayBuffer()
  .then (buffer) ->
    window.buffer = buffer
    view = new DataView(buffer)
    window.view = view
    ary = new Int32Array(buffer.byteLength/4)
    window.ary = ary
    for x in [0..ary.length-1]
      ary[x] = view.getInt32(x*4, true)

    bloom = new BloomFilter(ary, 7)
    window.bloom = bloom

    infoDiv.querySelector('.loading').remove()

    queryWords()

cooldown = null
queryWords = ->
  return unless texts.length
  return if cooldown

  i = 0
  current = texts[texts.length - 1].split(' ')
  while i < current.length
    console.log "testing next", Math.min(4, current.length-i), "words"
    for n in [Math.min(4, current.length-i)..1] by -1
      phrase = current[i..i+n-1].join ' '
      console.log "trying", phrase
      if bloom.test phrase
        console.log "found", phrase
        if tried[phrase]
          break
        else
          cooldown = setTimeout (-> cooldown = null; queryWords()), 5000
          return addResult phrase

    console.log "moving forward by", Math.max(n, 1)

    i += Math.max(n, 1)

startRecognition()