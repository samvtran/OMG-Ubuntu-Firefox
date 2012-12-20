###
Copyright (C) 2012 Ohso Ltd

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
buttons = require 'toolbarbutton'
tabs = require 'tabs'
self = require 'self'
data = require('self').data
request = require('request').Request

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

# button = buttons.ToolbarButton
#   id: 'omg-button'
#   label: 'OMG! Ubuntu!'
#   image: data.url 'images/icon24.png'
#   panel: popup

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
  #console.log "updating badge"
  if unread is '0'
    #console.log 'No unread'
    widget.contentURL = data.url 'images/icon_unread19.png'
    #widget.width = 16
  else
    widget.contentURL = data.url 'images/icon19.png'
    #console.log "#{unread} unread"
    #widget.contentURL = data.url 'badgeWidget.html'
    #widget.port.emit 'receiveBadgeCount', unread
    #widget.width = 100
