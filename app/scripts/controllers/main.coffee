'use strict'

angular.module('tweetflight').controller 'MainCtrl', [
  '$scope', '$http'
  ($scope, $http) ->

    tweet_fetch_attempt_limit = 5

    tweet_url = if window.location.toString().match(/localhost/) and not window.location.toString().match(/\?live=1/)
      "http://localhost:5000/tweets.json?callback=JSON_CALLBACK"
    else
      "http://tweetflight.herokuapp.com/tweets.json?callback=JSON_CALLBACK"

    document.ontouchmove = (e) ->
      if !$scope.unsupported()
        e.preventDefault()

    requestAnimationFrame = window.requestAnimationFrame or window.mozRequestAnimationFrame or window.webkitRequestAnimationFrame or window.msRequestAnimationFrame
    window.requestAnimationFrame = requestAnimationFrame

    $scope.isiPhone = ->
      navigator.userAgent.match /iPhone/i || navigator.userAgent.match /iPod/i

    $scope.ready = ->
      $scope.lyricsLoaded

    $scope.start = ->
      $scope.playing = true

    $scope.replay = ->
      location.reload()

    $scope.unsupported = ->
      !Modernizr.cssanimations || !Modernizr.csstransitions || !Modernizr.video || !Modernizr.opacity || !window.requestAnimationFrame || $scope.isiPhone()

    setBarTime = (lyric) -> lyric.time = (6.4 * lyric.time) - 6.4 #minus 3 for animation
    setLyricSplit = (lyric) ->
      if lyric.tweet
        pattern = new RegExp "^(.*)(#{lyric.line})(.*)$", "im"
        lyric.processed = lyric.tweet.text.match pattern

    tweet_fetch_attempts = 1

    getTweets = ->
      $scope.status = "Fetching tweets..."
      $http.jsonp(tweet_url + '').success (data) ->
        $scope.lyrics = data
        for lyric in $scope.lyrics
          setBarTime(lyric)
          setLyricSplit(lyric)
      .error (data, status, headers, config) ->
        if tweet_fetch_attempts >= tweet_fetch_attempt_limit
          $scope.status = "Hmm, something went wrong. Reload, or try again soon!"
        else
          tweet_fetch_attempts += 1
          setTimeout (-> getTweets()), 1000        

    getTweets()
]

angular.module('tweetflight').directive 'preflight', ->
  restrict: 'E'
  template: """
    <div id='stage'>
      <video preflight-video class="preflight video" preload>
        <source ng-src="{{ video }}.mp4"  type="video/mp4; codecs=avc1.42E01E,mp4a.40.2">
        <source ng-src="{{ video }}.webm" type="video/webm; codecs=vp8,vorbis">
        <source ng-src="{{ video }}.ogv"  type="video/ogg; codecs=theora,vorbis">
      </video>
      <ul class="tweets">
        <li ng-repeat="lyric in lyrics" ng-controller="LyricController" ng-class="lyricClass()" lyric>
          <div class='innerLyric'>
            <div ng-show="lyric.tweet" class="meta">
              <span class="date">{{lyric.tweet.created_at | timeAgo}}</span>
            </div>
            <div class="line">
              <span ng-show="lyric.tweet" class="tweet start">{{lyric.processed[1] | swapSymbols}}</span>
              {{lyric.line}}
              <span ng-show="lyric.tweet" class="tweet end">{{lyric.processed[3] | swapSymbols}}</span>
            </span>
            <div ng-show="lyric.tweet" class="link">
              <a class="tweet-link" href="{{lyric.tweet.link}}" target="blank">
                <span class="ss-icon ss-social">twitter</span>&nbsp;{{lyric.tweet.username}}
              </a>
            </div>
          </div>
        </li>
      </ul>
    </div>
  """
  replace: true
  scope: {video: '@'}
  link: (scope, element, attr) ->
    width = 518
    height = 292

    video = angular.element('.video')
    video.css('margin-top', "-#{height / 2}px")
    video.css('margin-left', "-#{width / 2}px")

    makeVideoFill = ->
      ratio = width / height
      windowRatio = window.innerWidth / window.innerHeight
      if (windowRatio > ratio)
        video.css('width', "#{window.innerWidth}px")
        video.css('margin-left', "-#{window.innerWidth / 2}px")
        newHeight = (window.innerWidth / ratio)
        video.css('height', "#{newHeight}px")
        video.css('margin-top', "-#{newHeight / 2}px")
      else
        newWidth = (window.innerHeight * ratio)
        video.css('width', "#{newWidth}px")
        video.css('margin-left', "-#{newWidth / 2}px")
        video.css('height', "#{window.innerHeight}px")
        video.css('margin-top', "-#{window.innerHeight / 2}px")
    makeVideoFill()
    angular.element(window).bind('resize', makeVideoFill)


angular.module('tweetflight').directive 'preflightVideo', ->
  (scope, elem, attrs) ->
    video = elem[0]

#    elem.bind 'loadedmetadata', (e) ->
#      video.currentTime = 120

    scope.$watch '$parent.playing', ->
      if scope.$parent.playing
        video.play()

    scope.$watch '$parent.lyrics', ->
      if scope.$parent.lyrics
        scope.lyrics = scope.$parent.lyrics
        scope.$parent.lyricsLoaded = true

    elem.bind 'play', ->
      nextLyricId = 0
      scope.visibleLyrics = []

      watchForChanges = ->
        if scope.lyrics?
          currentTime = video.currentTime
          nextLyric = scope.lyrics[nextLyricId]
          if(currentTime > nextLyric.time)
            scope.currentLyric = nextLyric
            scope.currentLyric.visible = true
            scope.$apply()
            nextLyricId++
          if scope.lyrics.length > nextLyricId
            window.requestAnimationFrame(watchForChanges)
          else
            setTimeout ->
              scope.$parent.ended = true
              scope.$parent.$apply()
            , 12000

      window.requestAnimationFrame(watchForChanges)

angular.module('tweetflight').controller "LyricController", [
  '$scope'
  ($scope) ->
    $scope.lyricClass = ->
      {visible: $scope.lyric.visible, 'no-tweet': !$scope.lyric.tweet, 'transition-height': true}
]

angular.module('tweetflight').directive "lyric", ->
  (scope, element, attrs) ->
    setTimeout ->
      element.height(0)
    , 0
    scope.$watch 'lyric.visible', (isVisible) ->
      if isVisible
        lyricHeight = element.find('.innerLyric').height()
        element.height(lyricHeight)
        setTimeout ->
          element.removeClass('transition-height')
          element.css('height', 'auto')
        , 10000

angular.module('tweetflight').filter "timeAgoInWords", ->
  (input) ->
    if(input)
      moment(input).from Date.now()

angular.module('tweetflight').filter "timeAgo", ->
  (input) ->
    if(input)
      moment(input, "YYYY-MM-DD HH:mm:ss Z").format("MMM D h:mma")

angular.module('tweetflight').filter "swapSymbols", ->
  (input) ->
    if(input)
      input.replace("&amp;", "&")
