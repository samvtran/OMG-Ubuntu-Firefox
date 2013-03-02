###
Copyright (C) 2013 Ohso Ltd

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied.  See the License for the
specific language governing permissions and limitations
under the License.
###
'use strict'
omgFeed = "http://feeds.feedburner.com/d0od?format=xml"

db = undefined
DB_VERSION = 1

# Defaults set up
if typeof localStorage['unread'] is 'undefined'
  localStorage['unread'] = 0

if typeof localStorage['pollInterval'] is 'undefined'
  localStorage['pollInterval'] = 600000

omgApp = angular.module 'omgApp', ['omgUtil']

omgApp.controller 'popupCtrl', ['$scope', 'databaseService', 'Articles', 'LocalStorage', 'Badge', ($scope, databaseService, Articles, LocalStorage, Badge) ->
  getArticlesOnTimeout = () ->
    setTimeout () ->
      databaseService.open().then (event) ->
        Articles.getLatestArticles().then () ->
          Articles.getArticles().then (articles) ->
            Badge.notify()
            $scope.latestArticles = articles
            getArticlesOnTimeout()
    ,localStorage['pollInterval']

  databaseService.open().then (event) ->
    Articles.getArticles().then (articles) ->
      Badge.notify()
      $scope.latestArticles = articles
      getArticlesOnTimeout()

  $scope.markAsRead = (index) ->
    if $scope.latestArticles[index].unread is true
      LocalStorage.decrement()
      $scope.latestArticles[index].unread = false;
      db.transaction(['articles'], 'readwrite').objectStore('articles').put($scope.latestArticles[index])

  $scope.markAllAsRead = () ->
    LocalStorage.reset()
    for article in $scope.latestArticles
      if article.unread is true
        article.unread = false
        db.transaction(['articles'], 'readwrite').objectStore('articles').put(article)
  $scope.refresh = () ->
    $scope.refreshing = true;
    databaseService.open().then (event) ->
      Articles.getLatestArticles().then () ->
        Articles.getArticles().then (articles) ->
          $scope.latestArticles = articles
          $scope.refreshing = false;
]

# Util functions
omgUtil = angular.module 'omgUtil', ['ngResource']

omgUtil.service 'databaseService', ['$q', '$rootScope', ($q, $rootScope) ->
  open = () ->
    deferred = $q.defer()
    if typeof db != "undefined" then deferred.resolve()
    request = indexedDB.open 'OMGUbuntu', DB_VERSION
    request.onerror = (event) ->
      console.log "Couldn't open the database"
      $rootScope.$apply () ->
        deferred.reject "Couldn't open the database"
    request.onsuccess = (event) ->
      db = request.result
      $rootScope.$apply () ->
        deferred.resolve()
    request.onupgradeneeded = (event) ->
      db = event.target.result
      createStores()
    deferred.promise

  createStores = () ->
    console.log "Creating stores"
    db.createObjectStore "articles", keyPath: "date"
  {
    open: open
  }
]

omgUtil.service 'Articles', ['$q', '$rootScope', 'LocalStorage', 'databaseService', ($q, $rootScope, LocalStorage, databaseService)->
  getLatestArticles = () ->
    deferred = $q.defer()
    promises = []
    self.port.emit 'getArticles', omgFeed
    self.port.on 'receivedArticles', (response) ->
      data = $.parseXML response
      articles = $(data).find('rss').find('channel').find('item')
      for articleXml in articles
        article = $(articleXml)
        articleObj =
          title: article.find('title').text()
          summary: $('<div>' + article.find('description').text() + '</div>').text()
          link: article.find('feedburner\\:origLink').text()
          date: Date.parse article.find('pubDate').text()
          unread: true
        addArticle = _addArticle(articleObj)
        promises.push addArticle
      $q.all(promises).then (article) ->
        if ~~LocalStorage.get() > 0 && typeof article[0] != 'undefined'
          self.port.emit 'notification',
            count: LocalStorage.get()
            title: article[0].title
            link: article[0].link
        deferred.resolve()
    deferred.promise

  _addArticle = (articleObj) ->
    deferred = $q.defer()
    addArticle = db.transaction(['articles'], 'readwrite').objectStore('articles').add(articleObj)
    addArticle.onsuccess = (event) ->
      LocalStorage.increment()
      $rootScope.$apply () ->
        deferred.resolve(articleObj)
    addArticle.onerror = (event) ->
      $rootScope.$apply () ->
        deferred.resolve()
      return
    deferred.promise

  _getArticlesFromDatabase = () ->
    deferred = $q.defer()
    articles = []
    totalCount = 0
    objectStore = db.transaction(['articles'], 'readonly').objectStore('articles')
    objectStore.openCursor(null, "prev").onsuccess = (event) ->
      cursor = event.target.result
      if cursor
        totalCount++
        if articles.length < 20
          articles.push cursor.value
        else if totalCount > 30
          if cursor.value.unread is true
            LocalStorage.decrement()
          db.transaction(['articles'], 'readwrite').objectStore('articles').delete(cursor.key)
        cursor.continue()
      else
        $rootScope.$apply () ->
          deferred.resolve articles
    deferred.promise

  getArticles = () ->
    deferred = $q.defer()
    objectStore = db.transaction(['articles'], 'readonly').objectStore('articles')
    objectStore.count().onsuccess = (event) ->
      if event.target.result < 20
        getLatestArticles().then () ->
          _getArticlesFromDatabase().then (articles) ->
            deferred.resolve articles
      else _getArticlesFromDatabase().then (articles) ->
        deferred.resolve articles
    deferred.promise

  {
    getArticles: getArticles
    getLatestArticles: getLatestArticles
  }
]

omgUtil.filter 'truncate', () -> (input, count) ->
  final = input;
  if typeof input is "undefined" then return "";
  if input.length <= count
    return final
  truncated = input.substring(0, (count))
  # Is the current EOL whitespace?
  if truncated.substring(truncated.length - 1).match(/\s/)
    final = truncated
  # Is the character after whitespace?
  if input.substring(truncated.length, truncated.length + 1).match(/\s/)
    final = truncated

  # Search backwards until we hit whitespace or the end of the string.
  for i in [1 .. (truncated.length - 1)]
    truncatedTest = truncated.substring(truncated.length - i, truncated.length - (i - 1));
    if truncatedTest.match(/\s/)
      final = truncated.substring(0, truncated.length - i)
      break;
  return final + "..."

omgUtil.filter 'uriEncode', () -> (input) ->
  encodeURIComponent input

omgUtil.service 'Badge', [->
  notify = () ->
    self.port.emit 'updateBadge', localStorage['unread']
  {
    notify: notify
  }
]

omgUtil.service 'LocalStorage', ['Badge', (Badge)->
  get = () ->
    localStorage['unread']
  increment = () ->
    localStorage['unread'] = parseInt(localStorage['unread']) + 1
    Badge.notify()
  decrement = () ->
    if localStorage['unread'] is "0" then return
    localStorage['unread'] = parseInt(localStorage['unread']) - 1
    Badge.notify()
  reset = () ->
    localStorage['unread'] = 0
    Badge.notify()

  {
    get: get
    increment: increment
    decrement: decrement
    reset: reset
  }
]
