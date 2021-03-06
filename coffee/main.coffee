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
widgets = require 'widget'
tabs = require 'tabs'
self = require 'self'
preferences = require 'simple-prefs'
data = require('self').data
request = require('request').Request
notifications = require 'sdk/notifications'
popup = require('panel').Panel
  width: 464
  height: 512
  contentURL: data.url 'popup.html'
  contentScriptFile: [
    data.url 'scripts/jquery.min.js'
    data.url 'scripts/angular.min.js'
    data.url 'scripts/angular-resource.min.js'
    data.url 'scripts/popup.js'
  ]

widget = widgets.Widget
  id: 'omg-bubble'
  label: 'OMG! Ubuntu!'
  contentURL: data.url 'images/icon19.png'
  panel: popup

popup.port.on 'getArticles', (feedUrl) ->
  request
    url: feedUrl
    onComplete: (response) ->
      popup.port.emit 'receivedArticles', response.text
  .get()

popup.port.on 'updateBadge', (unread) ->
  if unread is '0'
    widget.contentURL = data.url 'images/icon_unread19.png'
  else
    widget.contentURL = data.url 'images/icon19.png'

popup.port.on 'notification', (notify) ->
  unless preferences.prefs.notificationsEnabled then return
  if notify.count is 1
    notifications.notify
      title: "New article on OMG! Ubuntu!"
      text: notify.title
      iconURL: data.url 'images/icon48.png'
  else if notify.count > 1
    notifications.notify
        title: "New articles on OMG! Ubuntu!"
        text: "#{notify.count} new articles"
        iconURL: data.url 'images/icon48.png'



