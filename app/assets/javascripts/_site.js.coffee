window.feedbin ?= {}

$.extend feedbin,

  showNotification: (text, timeout = 3000, href = '', error = false) ->
    messages = $('[data-behavior~=messages]')
    if error == true
      messages.addClass('error')
    else
      messages.removeClass('error')

    if href == ''
      messages.removeAttr('href')
    else
      messages.attr('href', href)

    messages.text(text)
    messages.addClass('show')
    setTimeout ( ->
      messages.removeClass('show')
    ), timeout

  previewHeight: ->
    container = $('[data-behavior~=preview_min_height]')
    preview = $('[data-behavior~=preview_container]')
    minHeight = 85
    if container.length > 0 && preview.length > 0
      if preview.outerHeight() > minHeight
        minHeight = container.outerHeight()
      container.css(height: "#{minHeight}px")

  updateEntries: (entries, header) ->
    $('.entries ul').html(entries)
    $('.entries-header').html(header)

  appendEntries: (entries, header) ->
    $('.entries ul').append(entries)
    $('.entries-header').html(header)

  updatePager: (html) ->
    $('[data-behavior~=pagination]').html(html)

  updateEntryContent: (html) ->
    feedbin.closeEntryBasement(0)
    $('[data-behavior~=entry_content_target]').html(html)

  updateFeeds: (feeds) ->
    $('[data-behavior~=feeds_target]').html(feeds)

  clearEntries: ->
    $('[data-behavior~=entries_target]').html('')

  clearEntry: ->
    feedbin.updateEntryContent('')

  syntaxHighlight: ->
    $('[data-behavior~=entry_content_target] pre code').each (i, e) ->
      hljs.highlightBlock(e)

  audioVideo: ->
    $('[data-behavior~=entry_content_target] audio, [data-behavior~=entry_content_target] video').mediaelementplayer()

  footnotes: ->
    $.bigfoot
      scope: '[data-behavior~=entry_content_wrap]'
      actionOriginalFN: 'ignore'
      buttonMarkup: "<div class='bigfoot-footnote__container'> <button class=\"bigfoot-footnote__button\" id=\"{{SUP:data-footnote-backlink-ref}}\" data-footnote-number=\"{{FOOTNOTENUM}}\" data-footnote-identifier=\"{{FOOTNOTEID}}\" alt=\"See Footnote {{FOOTNOTENUM}}\" rel=\"footnote\" data-bigfoot-footnote=\"{{FOOTNOTECONTENT}}\"> {{FOOTNOTENUM}} </button></div>"

  hideTagsForm: (form) ->
    if not form
      form = $('.tags-form-wrap')
    form.animate
      height: 0

  blogContent: (content) ->
    content = $.parseJSON(content)
    $('.blog-post').text(content.title);
    $('.blog-post').attr('href', content.url);

  isRead: (entryId) ->
    feedbin.Counts.get().isRead(entryId)

  imagePlaceholders: (element) ->
    image = new Image()
    placehold = element.children[0]
    element.className += ' is-loading'

    image.onload = ->
      element.className = element.className.replace('is-loading', 'is-loaded')
      element.replaceChild(image, placehold)

    image.onerror = ->
      element.style.display = "none"

    for attr in placehold.attributes
      if (attr.name.match(/^data-/))
        image.setAttribute(attr.name.replace('data-', ''), attr.value)

  loadEntryImages: ->
    if $("body").hasClass("entries-image-1")
      placeholders = document.querySelectorAll('.entry-image')
      for placeholder in placeholders
        feedbin.imagePlaceholders(placeholder)

  preloadImages: (id) ->
    id = parseInt(id)
    if feedbin.entries[id] && !_.contains(feedbin.preloadedImageIds, id)
      $(feedbin.entries[id].content).find("[data-behavior~=entry_content_wrap] img").each ->
        $(@).attr("src", $(@).data('feedbin-src'))
      feedbin.preloadedImageIds.push(id)

  localizeTime: (container) ->
    now = new Date()
    $("time.timeago").each ->
      datePublished = $(@).attr('datetime')
      datePublished = new Date(datePublished)
      if datePublished > now
        $(@).text('the future')
      else if (now - datePublished) < feedbin.ONE_DAY * 7
        $(@).timeago()
      else if datePublished.getFullYear() == now.getFullYear()
        $(@).text(datePublished.format("%e %b"))
      else
        $(@).text(datePublished.format("%e %b %Y"))

  entryTime: ->
    $(".post-meta time").each ->
      date = $(@).attr('datetime')
      date = new Date(date)
      $(@).text(date.format("%B %e, %Y at %l:%M %p"))

  applyUserTitles: ->
    textarea = document.createElement("textarea")
    $('[data-behavior~=user_title]').each ->
      element = $(@)
      feed = element.data('feed-id')
      if (feed of feedbin.data.user_titles)
        newTitle = feedbin.data.user_titles[feed]
        if element.prop('tagName') == "INPUT"
          textarea.innerHTML = newTitle
          element.val(textarea.value)
        else
          element.html(newTitle)

  queryString: (name) ->
    name = name.replace(/[\[]/, "\\[").replace(/[\]]/, "\\]")
    regexS = "[\\?&]" + name + "=([^&#]*)"
    regex = new RegExp(regexS)
    results = regex.exec(window.location.search)
    if results?
      decodeURIComponent results[1].replace(/\+/g, " ")
    else
      null

  openLinkInBackground: (href) ->
    anchor = document.createElement("a")
    anchor.href = href
    event = document.createEvent("MouseEvents")
    event.initMouseEvent "click", true, true, window, 0, 0, 0, 0, 0, true, false, false, true, 0, null
    anchor.dispatchEvent event

  autocomplete: (element) ->
    element.autocomplete
      serviceUrl: feedbin.data.tags_path
      appendTo: $(element).closest(".tags-form").children("[data-behavior=tag_completions]")
      delimiter: /(,)\s*/

  preloadEntries: (entry_ids, forcePreload = false) ->
    cachedIds = []
    for key of feedbin.entries
      cachedIds.push key * 1
    if !forcePreload
      entry_ids = _.difference(entry_ids, cachedIds)
    if entry_ids.length > 0
      $.getJSON feedbin.data.preload_entries_path, {ids: entry_ids.join(',')}, (data) ->
        $.extend feedbin.entries, data
        ids = _.keys(data)
        feedbin.preloadImages(ids[0])

  readability: () ->
    feedId = feedbin.selectedEntry.feed_id
    if feedbin.data.readability_settings[feedId] == true && feedbin.data.sticky_readability
      $('.button-toggle-content').find('span').addClass('active')
      content = $('[data-behavior~=readability_loading]').html()
      $('[data-behavior~=entry_content_wrap]').html(content)
      $('[data-behavior~=toggle_content_view]').submit()

  resetScroll: ->
    $('.entry-content').prop('scrollTop', 0)

  fitVids: ->
    $('[data-behavior~=entry_content_target]').fitVids({ customSelector: "iframe[src*='youtu.be'], iframe[src*='www.flickr.com'], iframe[src*='view.vzaar.com'], iframe[src*='embed-ssl.ted.com']"});

  formatTweets: ->
    if typeof(twttr) != "undefined" && typeof(twttr.widgets) != "undefined"
      target = $('[data-behavior~=entry_content_wrap]')[0]
      result = twttr.widgets.load(target)

  formatInstagram: ->
    if typeof(instgrm) != "undefined"
      instgrm.Embeds.process()

  checkType: ->
    element = $('.entry-final-content')
    if element.length > 0
      tag = element.children().get(0).nodeName
      if tag == "TABLE"
        $('.entry-type-default').removeClass("entry-type-default").addClass("entry-type-newsletter");

  formatImages: ->
    $("[data-behavior~=entry_content_wrap] img").each ->
      actualSrc = $(@).data('feedbin-src')
      if actualSrc?
        $(@).attr("src", actualSrc)

      if $(@).is("[src*='feeds.feedburner.com'], [data-canonical-src*='feeds.feedburner.com']")
        $(@).addClass('hide')

  formatEntryContent: (entryId, resetScroll=true, readability=true) ->
    feedbin.applyStarred(entryId)
    if resetScroll
      feedbin.resetScroll
    if readability
      feedbin.readability()
    try
      feedbin.syntaxHighlight()
      feedbin.footnotes()
      feedbin.nextEntryPreview()
      feedbin.audioVideo()
      feedbin.entryTime()
      feedbin.applyUserTitles()
      feedbin.fitVids()
      feedbin.formatTweets()
      feedbin.formatInstagram()
      feedbin.formatImages()
      feedbin.checkType()
    catch error
      if 'console' of window
        console.log error

  refresh: ->
    if feedbin.data
      $.get(feedbin.data.auto_update_path)

  shareOpen: ->
    $('[data-behavior~=toggle_share_menu]').parents('.dropdown-wrap').hasClass('open')

  updateFontSize: (direction) ->
    fontContainer = $("[data-font-size]")
    currentFontSize = fontContainer.data('font-size')
    if direction == 'increase'
      newFontSize = currentFontSize + 1
    else
      newFontSize = currentFontSize - 1
    if feedbin.data.font_sizes[newFontSize]
      fontContainer.removeClass("font-size-#{currentFontSize}")
      fontContainer.addClass("font-size-#{newFontSize}")
      fontContainer.data('font-size', newFontSize)

  matchHeights: (elements) ->
    height = 0
    $.each elements, (index, element) ->
      $(element).css({'height': ''})
      outerHeight = $(element).outerHeight()
      if outerHeight > height
        height = outerHeight

    elements.css
      height: height

  disableMarkRead: () ->
    feedbin.markReadData = {}
    $('[data-behavior~=mark_all_as_read]').attr('disabled', 'disabled')

  log: (input) ->
    console.log input

  markRead: () ->
    $('.entries li').addClass('read')
    feedbin.markReadData.ids = $('.entries li').map(() ->
      $(@).data('entry-id')
    ).get().join()
    $.post feedbin.data.mark_as_read_path, feedbin.markReadData

  checkPushPermission: (permissionData) ->
    if (permissionData.permission == 'default')
      $('body').removeClass('push-on')
      $('body').removeClass('push-disabled')
      $('body').addClass('push-off')
    else if (permissionData.permission == 'granted')
      $('body').removeClass('push-off')
      $('body').removeClass('push-disabled')
      $('body').addClass('push-on')
    else if (permissionData.permission == 'denied')
      $('body').removeClass('push-on')
      $('body').removeClass('push-off')
      $('body').addClass('push-disabled')

  toggleFullScreen: ->
    $('body').toggleClass('full-screen')

  isFullScreen: ->
    $('body').hasClass('full-screen')

  nextEntry: ->
    nextEntry = $('.entries').find('.selected').next()
    if nextEntry.length
      nextEntry
    else
      null

  nextEntryPreview: () ->
    if feedbin.nextEntry
      next = feedbin.nextEntry.parents('li').next()
      if next.length
        title = next.find('.title').text()
        feed = next.find('.feed-title').text()
        $('.next-entry-title').text(title)
        $('.next-entry-feed').text(feed)
        $('.next-entry-preview').removeClass('no-content')
      else
        $('.next-entry-preview').addClass('no-content')
    else
      $('.next-entry-preview').addClass('no-content')

  hideSubscribe: ->
    $('.feeds-inner').removeClass('show-subscribe')
    $('.subscribe-wrap').removeClass('open')

  getSelectedText: ->
    text = ""
    if (window.getSelection)
      text = window.getSelection().toString();
    else if (document.selection && document.selection.type != "Control")
      text = document.selection.createRange().text;
    text

  scrollTo: (item, container) ->
    item.offset().top - container.offset().top + container.scrollTop()

  sortByLastUpdated: (a, b) ->
    aTimestamp = $(a).data('sort-last-updated') * 1
    bTimestamp = $(b).data('sort-last-updated') * 1
    return bTimestamp - aTimestamp

  sortByVolume: (a, b) ->
    aVolume = $(a).data('sort-post-volume') * 1
    bVolume = $(b).data('sort-post-volume') * 1
    return bVolume - aVolume

  sortByName: (a, b) ->
    $(a).data('sort-name').localeCompare($(b).data('sort-name'))

  sortByFeedOrder: (a, b) ->
    a = parseInt($(a).data('sort-id'))
    b = parseInt($(b).data('sort-id'))

    a = feedbin.data.feed_order.indexOf(a)
    b = feedbin.data.feed_order.indexOf(b)

    a - b

  showSearchControls: (sort) ->
    $('.search-control').removeClass('hide');
    text = null
    if sort
      text = $("[data-sort-option=#{sort}]").text()
    if !text
      text = $("[data-sort-option=desc]").text()
    $('.sort-order').text(text)
    $('.entries').addClass('show-search-options')

  hideSearchControls: ->
    $('.search-control').addClass('hide');
    $('.entries').removeClass('show-search-options')
    $('.entries').removeClass('show-saved-search')
    $('.saved-search-wrap').removeClass('open')

  buildPoints: (percentages, width, height) ->
    barWidth = width / (percentages.length - 1)
    x = 0

    points = []
    for percentage in percentages
      y = (height - Math.round(percentage * height))
      points.push({x: x, y: y})
      x += barWidth

    points

  drawBarChart: (canvas, values) ->
    if values && canvas.getContext
      lineTo = (x, y, context, height) ->
        if y == 0
          y = 1
        if y == height
          y = height - 1
        context.lineTo(x, y)

      context = canvas.getContext("2d")
      canvasHeight = $(canvas).outerHeight()
      canvasWidth = $(canvas).outerWidth()

      ratio = 1
      if 'devicePixelRatio' of window
        ratio = window.devicePixelRatio

      $(canvas).attr('width', canvasWidth * ratio)
      $(canvas).attr('height', canvasHeight * ratio)
      context.scale(ratio, ratio)

      context.lineJoin = 'round'
      context.fillStyle = $(canvas).data('fill')
      context.strokeStyle = $(canvas).data('stroke')
      context.lineWidth = 1
      context.lineCap = 'round'

      points = feedbin.buildPoints(values, canvasWidth, canvasHeight)

      context.beginPath()
      context.moveTo(0, canvasHeight)
      for point in points
        context.lineTo(point.x, point.y)
      context.lineTo(canvasWidth, canvasHeight)
      context.fill()

      context.beginPath()
      for point, index in points
        if index == 0
          lineTo(point.x + 1, point.y, context, canvasHeight)
        else if index == points.length - 1
          lineTo(canvasWidth - 1, point.y, context, canvasHeight)
        else
          lineTo(point.x, point.y, context, canvasHeight)
      context.stroke()

  readabilityActive: ->
    $('[data-behavior~=toggle_content_view]').find('.active').length > 0

  prepareShareForm: ->
    $('.field-cluster input, .field-cluster textarea').val('')
    $('.share-controls [type="checkbox"]').attr('checked', false);

    title = $('.entry-header h1').first().text()
    $('.share-form .title-placeholder').val(title)

    url = $('.entry-header a').first().attr('href')
    $('.share-form .url-placeholder').val(url)

    description = feedbin.getSelectedText()
    $('.share-form .description-placeholder').val(description)

    source = $('.entry-header .author').first().text()
    if source == ""
      source = $('.entry-header .feed-title').first().text()
    $('.share-form .source-placeholder').val(source)

    if feedbin.readabilityActive()
      $('.readability-placeholder').val('on')
    else
      $('.readability-placeholder').val('off')


  sharePopup: (url) ->
    windowOptions = 'scrollbars=yes,resizable=yes,toolbar=no,location=yes'
    width = 620
    height = 590
    winHeight = screen.height
    winWidth = screen.width
    left = Math.round((winWidth / 2) - (width / 2));
    top = 0;
    if (winHeight > height)
      top = Math.round((winHeight / 2) - (height / 2))
    window.open(url, 'intent', "#{windowOptions},width=#{width},height=#{height},left=#{left},top=#{top}")

  closeEntryBasement: (timeout = 200) ->
    feedbin.closeEntryBasementTimeount = setTimeout ( ->
      $('.basement-panel').addClass('hide')
      $('.field-cluster input').blur()
    ), timeout

    clearTimeout(feedbin.openEntryBasementTimeount)
    $('.entry-basement').removeClass('foreground')
    top = $('.entry-toolbar').outerHeight()
    $('.entry-basement').removeClass('open')
    $('.entry-content').css
      "top": "41px"

  openEntryBasement: (selectedPanel) ->
    feedbin.openEntryBasementTimeount = setTimeout ( ->
      $('.entry-basement').addClass('foreground')
      $('.field-cluster input', selectedPanel).first().select()
    ), 200

    clearTimeout(feedbin.closeEntryBasementTimeount)

    feedbin.prepareShareForm()

    $('.basement-panel').addClass('hide')
    selectedPanel.removeClass('hide')
    $('.entry-basement').addClass('open')
    newTop = selectedPanel.height() + 41
    $('.entry-content').css
      "top": "#{newTop}px"

  applyStarred: (entryId) ->
    if feedbin.Counts.get().isStarred(entryId)
      $('[data-behavior~=selected_entry_data]').addClass('starred')

  showEntry: (entryId) ->
    entry = feedbin.entries[entryId]
    feedbin.updateEntryContent(entry.content)


  tagFeed: (url, tag, noResponse = true) ->
    $.ajax
      type: "POST",
      url: url,
      data: { _method: "patch", feed: {tag_list: tag}, no_response: noResponse }

  hideEmptyTags: ->
    $('[data-tag-id]').each ->
      if $(@).find('ul li').length == 0
        $(@).remove()

  appendTag: (target, ui) ->
    appendTarget = target.find('ul').first()
    ui.helper.remove()
    ui.draggable.appendTo(appendTarget)
    $('> [data-behavior~=sort_feed]', appendTarget).sort(feedbin.sortByFeedOrder).remove().appendTo(appendTarget)

  draggable: ->
    $('[data-behavior~=draggable]').draggable
      containment: '.feeds'
      helper: 'clone'
      appendTo: '[data-behavior~=feeds_target]'
      start: (event, ui) ->
        $('.feeds').addClass('dragging')
        feedbin.dragOwner = $(@).parents('[data-behavior~=droppable]').first()
      stop: (event, ui) ->
        $('.feeds').removeClass('dragging')

  droppable: ->
    $('[data-behavior~=droppable]:not(.ui-droppable)').droppable
      hoverClass: 'drop-hover'
      greedy: true
      drop: (event, ui) ->
        if !feedbin.dragOwner.get(0).isEqualNode(event.target)

          feedId = parseInt(ui.draggable.data('feed-id'))
          url = ui.draggable.data('feed-path')
          target = $(event.target)
          tag = $("> a", event.target).find("[data-behavior~=rename_title]").text()

          if tag?
            tagId = $(event.target).data('tag-id')
          else
            tag = ""
            tagId = null

          feedbin.Counts.get().updateTagMap(feedId, tagId)
          feedbin.tagFeed(url, tag)
          feedbin.appendTag(target, ui)
          feedbin.hideEmptyTags()
          feedbin.applyCounts(false)
          setTimeout ( ->
            feedbin.draggable()
          ), 20

  refreshRetry: (xhr) ->
    $.get(feedbin.data.refresh_sessions_path).success(->
      $.ajax(xhr)
    )

  modal: (selector) ->
    activeModal = $(selector)
    $('.modal').each ->
      unless $(@).get(0) == activeModal.get(0)
        $(@).modal('hide')
    activeModal.modal('toggle')

  updateFeedSearchMessage: ->
    length = $('[data-behavior~=check_toggle]:checked').length
    show = (message) ->
      $("#add_form_modal [data-behavior~=feeds_search_message]").addClass("hide")
      $("#add_form_modal [data-behavior~=feeds_search_message][data-behavior~=#{message}]").removeClass("hide")

    if length == 0
      show("message_none")
    else if length == 1
      show("message_one")
    else
      show("message_multiple")


  entries: {}

  feedCandidates: []

  modalShowing: false

  images: []

  feedXhr: null

  markReadData: {}

  closeSubcription: false

  player: null

  recentlyReadTimer: null

  selectedFeed: null

  dragOwner: null

  preloadedImageIds: []

  ONE_HOUR: 60 * 60 * 1000

  ONE_DAY: 60 * 60 * 1000 * 24

$.extend feedbin,
  preInit:

    xsrf: ->
      setup =
        beforeSend: (xhr) ->
          matches = document.cookie.match(/XSRF\-TOKEN\=([^;]*)/)
          if matches && matches[1]
            token = decodeURIComponent(matches[1])
            xhr.setRequestHeader('X-XSRF-TOKEN', token)
      $.ajaxSetup(setup);

  init:

    hasTouch: ->
      if 'ontouchstart' of document
        $('body').addClass('touch')

    initSingletons: ->
      new feedbin.CountsBehavior()

    renameFeed: ->
      $(document).on 'dblclick', '[data-behavior~=renamable]', (event) ->
        unless $(event.target).is('.feed-action-button')
          target = $(@).find('[data-behavior~=rename_target]')
          title = $(@).find('[data-behavior~=rename_title]')
          data = target.data()

          formAttributes =
            "accept-charset": "UTF-8"
            "data-remote": "true"
            "method": "post"
            "action": data.formAction
            "data-behavior": "rename_form"
          form = $('<form>', formAttributes)

          inputAttributes =
            "placeholder": data.originalTitle
            "value": data.title
            "name": data.inputName
            "data-behavior": "rename_input"
            "type": "text"
            "spellcheck": "false"
            "class": "rename-feed-input"

          input = $('<input>', inputAttributes)
          methodInput = $('<input>', {type: "hidden", name: "_method", value: "patch"})

          form.append(input)
          form.append(methodInput)

          title.addClass('hide')
          target.append(form)
          input.select()

      $(document).on 'blur', '[data-behavior~=rename_input]', (event) ->
        $('[data-behavior~=rename_form]').remove()
        $('[data-behavior~=rename_title]').removeClass('hide')

      $(document).on 'submit', '[data-behavior~=rename_form]', (event, xhr) ->
        container = $(@).closest('[data-behavior~=renamable]')
        title = container.find('[data-behavior~=rename_title]')
        input = container.find('[data-behavior~=rename_input]')
        target = container.find('[data-behavior~=rename_target]')
        target.data('title', input.val())
        title.text(input.val())

        $('[data-behavior~=rename_form]').remove()
        $('[data-behavior~=rename_title]').removeClass('hide')

      $(document).on 'click', '[data-behavior~=open_item]', (event) ->
        unless $(event.target).is('[data-behavior~=rename_input]')
          $('[data-behavior~=rename_input]').each ->
            $(@).blur()

    changeSearchSort: (sort) ->
      $(document).on 'click', '[data-sort-option]', ->
        sortOption = $(@).data('sort-option')
        searchField = $('#query')
        query = searchField.val()
        query = query.replace(/\s*?(sort:\s*?asc|sort:\s*?desc|sort:\s*?relevance)\s*?/, '')
        query = "#{query} sort:#{sortOption}"
        searchField.val(query)
        searchField.parents('form').submit()

    markRead: ->
      $(document).on 'click', '[data-mark-read]', ->
        feedbin.markReadData = $(@).data('mark-read')
        $('[data-behavior~=mark_all_as_read]').removeAttr('disabled')
        return

      $(document).on 'click', '[data-behavior~=mark_all_as_read]', ->
        unless $(@).attr('disabled')
          $('.entries li').map ->
            entry_id = $(@).data('entry-id') * 1

          if feedbin.data.mark_as_read_confirmation
            result = confirm(feedbin.markReadData.message)
            if result
              feedbin.markRead()
          else
            feedbin.markRead()
        return

    selectable: ->
      $(document).on 'click', '[data-behavior~=selectable]', ->
        $(@).parents('ul').find('.selected').removeClass('selected')
        $(@).parent('li').addClass('selected')
        return

    choicesSubmit: ->
      $(document).on 'ajax:beforeSend', '[data-choice-form]', ->
        $('.modal').modal('hide')
        return

    entryLinks: ->
      $(document).on 'click', '[data-behavior~=entry_content_wrap] a', ->
        $(this).attr('target', '_blank').attr('rel', 'noopener noreferrer')
        return

    clearEntry: ->
      $(document).on 'ajax:beforeSend', '[data-behavior~=show_entries]', (event) ->
        unless $(event.target).is('.toggle-drawer')
          feedbin.clearEntry()
        return

    cancelFeedRequest: ->
      $(document).on 'ajax:beforeSend', '[data-behavior~=show_entries]', (event, xhr) ->
        if feedbin.feedXhr
          feedbin.feedXhr.abort()
        if $(event.target).is('.edit_feed')
          feedbin.feedXhr = null
        else
          feedbin.feedXhr = xhr
        return

    tooltips: ->
      $(document).on 'mouseenter mouseleave', '[data-behavior~=tooltip]', (event) ->
        tooltip = $(this).tooltip
          delay: 0
          animation: false
        if 'mouseenter' == event.type
          tooltip.tooltip('show')
        else
          tooltip.tooltip('hide')
        return

    loadEntries: ->
      link = $('[data-behavior~=feeds_target] li:visible').first().find('a')
      mobile = $('body').hasClass('mobile')
      if link.length > 0 && !mobile
        link[0].click()

    tagsForm: ->
      $(document).on 'click', (event) ->
        target = $(event.target)
        if not target.hasClass('toolbar-button')
          target = target.parents('.toolbar-button')
        wrap = target.find('.tags-form-wrap')
        feedbin.hideTagsForm($('.tags-form-wrap').not(wrap))
        return

      $(document).on 'click', '[data-behavior~=show_tags_form]', (event) ->
        target = $(event.target)
        if not target.hasClass('toolbar-button')
          target = target.parentsUntil('.toolbar-button')
        wrap = target.find('.tags-form-wrap')
        unless $(@).attr('disabled') == 'disabled'
          if '0px' == wrap.css('height')
            wrap.animate {
              height: '138px'
            }, 200
            field = wrap.find('.feed_tag_list')
            field.focus()
            value = field.val()
            field.val(value)
            feedbin.autocomplete(field)
        return

    resize: () ->
      defaults =
        handles: "e"
        minWidth: 200
        stop: (event, ui) ->
          form = $('[data-behavior~=resizable_form]')
          $('[name=column]', form).val($(ui.element).data('resizable-name'))
          $('[name=width]', form).val(ui.size.width)
          form.submit()
          return
      $('.feeds-column').resizable($.extend(defaults))
      $('.entries-column').resizable($.extend(defaults))

    feedCandidates: ->
      $(document).on 'click', '[data-behavior~=show_entries]', ->
        clickedItem = $(@).parents 'li'
        feedbin.feedCandidates = []
        feedbin.feedCandidates.push clickedItem.next().data('feed-id') if clickedItem.next().length
        feedbin.feedCandidates.push clickedItem.prev().data('feed-id') if clickedItem.prev().length
        return

    unauthorizedResponse: ->
      $(document).on 'ajax:complete', (event, response, status) ->
        if response.status == 401
          document.location = feedbin.data.login_url
        return

    screenshotTabs: ->
      $('[data-behavior~=screenshot_nav] li').first().addClass('active')
      $(document).on 'click', '[data-behavior~=screenshot_nav] a', (event) ->
        $('[data-behavior~=screenshot_nav] li').removeClass('active')
        $(@).parent('li').addClass('active')
        src = $(@).find('img').attr('src')
        $("[data-behavior~=screenshots] img").addClass('hide')
        $("[data-behavior~=screenshots] img[src='#{src}']").removeClass('hide')
        event.preventDefault()
        return

      $(document).on 'click', '[data-behavior~=screenshot_previous], [data-behavior~=screenshot_next]', (event) ->
        selectedScreenshot = $('[data-behavior~=screenshot_nav] li.active')
        button = $(event.target).data('behavior')
        if button.match(/screenshot_next/)
          nextScreenshot = selectedScreenshot.next()
          if nextScreenshot.length == 0
            nextScreenshot = $('li:first-child', $('[data-behavior~=screenshot_nav]'))
        else
          nextScreenshot = selectedScreenshot.prev()
          if nextScreenshot.length == 0
            nextScreenshot = $('li:last-child', $('[data-behavior~=screenshot_nav]'))

        nextScreenshot.find('a').click()
        event.preventDefault()
        return

    preloadImages: ->
      $(document).on 'click', '[data-behavior~=show_entry_content]', ->
        selected = $(@).parents('li')
        next = selected.next('li')
        if next.length > 0
          id = next.data('entry-id')
          feedbin.preloadImages(id)
        return

    feedSelected: ->
      $(document).on 'click', '[data-behavior~=back_to_feeds]', ->
        $('body').addClass('nothing-selected').removeClass('feed-selected entry-selected')
        return

      $(document).on 'click', '[data-behavior~=show_entries]', (event) ->
        $('body').addClass('feed-selected').removeClass('nothing-selected entry-selected')
        return

      $(document).on 'click', '[data-behavior~=show_entry_content]', ->
        $('body').addClass('entry-selected').removeClass('nothing-selected feed-selected')
        return

    addFields: ->
      $(document).on 'click', '[data-behavior~=add_fields]', (event) ->
        time = new Date().getTime() + '_insert'
        id = $(@).data('id')
        regexp = new RegExp(id, 'g')
        content = $(@).data('fields').replace(regexp, time)
        $('[data-behavior~=add_fields_target]').find('tbody').prepend(content)
        event.preventDefault()
        return

    removeFields: ->
      $(document).on 'click', '[data-behavior~=remove_fields]', (event) ->
        $(@).prev('input[type=hidden]').val(1)
        $(@).closest('tr').addClass('hide')
        event.preventDefault()
        return

    dropdown: ->
      $(document).on 'click', (event) ->
        dropdown = $('.dropdown-wrap')
        unless $(event.target).is('[data-behavior~=toggle_dropdown]') || $(event.target).parents('[data-behavior~=toggle_dropdown]').length > 0
          dropdown.removeClass('open')
        return

      $(document).on 'click', '[data-behavior~=share_options] a', (event) ->
        $('.dropdown-wrap').removeClass('open')

      $(document).on 'click', '[data-behavior~=toggle_dropdown]', (event) ->
        $(".dropdown-wrap li").removeClass('selected')
        parent = $(@).closest('.dropdown-wrap')
        if parent.hasClass('open')
          parent.removeClass('open')
        else
          parent.addClass('open')
        event.preventDefault()
        return

      $(document).on 'mouseover', '.dropdown-wrap li', (event) ->
        $('.dropdown-wrap li').not(@).removeClass('selected')
        return

    drawer: ->
      $(document).on 'click', '[data-behavior~=toggle_drawer]', (event) =>
        button = $(event.currentTarget)
        drawer = button.parents('li').find('.drawer')

        if drawer.data('hidden') == true
          height = $('ul', drawer).height() + 2
          hidden = false
          text = 'hide'
        else
          height = 0
          hidden = true
          text = 'show'

        drawer.animate {
          height: height
        }, 200, ->
          if height > 0
            drawer.css
              height: 'auto'

        drawer.data('hidden', hidden)
        button.text(text)

        button.parent('form').submit()
        event.stopPropagation()
        event.preventDefault()
        return

    feedActions: ->
      $(document).on 'click', '[data-operation]', (event) ->
        operation = $(@).data('operation')
        form = $(@).parents('form')
        $('input[name=operation]').val(operation)
        form.submit()

    planSelect: ->
      $(document).on 'change', '[data-behavior~=plan_select]', (event) ->
        selected = $(@).attr('id')
        $('[data-behavior~=billing_help_text]').addClass('hide')
        $("[data-plan-id=#{selected}]").removeClass('hide')

    checkBoxToggle: ->
      $(document).on 'change', '[data-behavior~=toggle_checked]', (event) ->
        if $(@).is(':checked')
          $('[type="checkbox"][name]').prop('checked', true)
        else
          $('[type="checkbox"][name]').prop('checked', false)
        event.preventDefault()
        return

      $(document).on 'click', '[data-behavior~=check_feeds]', (event) ->
        checkboxes = $('[data-behavior~=collection_checkbox]')
        if $(@).is(':checked')
          checkboxes.prop('checked', true)
          checkboxes.attr('disabled', 'disabled')
        else
          checkboxes.prop('checked', false)
          checkboxes.removeAttr('disabled')
        return

    validateFile: ->
      form = $('.new_import_uploader')
      input = form.find("input:file")
      unless input.val()
        form.find('[type=submit]').attr('disabled','disabled')

      input.on 'change', ()->
        if $(this).val()
          form.find('[type=submit]').removeAttr('disabled')
        return

    autoHeight: ->
      if $('.collection-edit-wrapper').length
        feedbin.autoHeight()
        $(window).on 'resize', () ->
          feedbin.autoHeight()
          return

    timeago: ->
      strings =
        prefixAgo: null
        prefixFromNow: null
        suffixAgo: ""
        suffixFromNow: "from now"
        seconds: "less than 1 min"
        minute: "1m"
        minutes: "%dm"
        hour: "1h"
        hours: "%dh"
        day: "1d"
        days: "%dd"
        month: "a month"
        months: "%d months"
        year: "a year"
        years: "%d years"
        wordSeparator: " "
        numbers: []
      jQuery.timeago.settings.strings = strings
      jQuery.timeago.settings.allowFuture = true
      $("time.timeago").timeago()
      return

    updateReadability: ->
      $(document).on 'ajax:beforeSend', '[data-behavior~=toggle_content_view]', (event, xhr) ->
        feedId = $(event.currentTarget).data('feed-id')
        if feedbin.data.sticky_readability && feedbin.data.readability_settings[feedId] != "undefined"
          unless $("#content_view").val() == "true" && feedbin.data.readability_settings[feedId] == true
            feedbin.data.readability_settings[feedId] = !feedbin.data.readability_settings[feedId]

        if !$('.button-toggle-content').hasClass('active')
          $('.button-toggle-content').addClass('loading')

        return

    autoUpdate: ->
      setInterval ( ->
        feedbin.refresh()
      ), 300000

    entryBasement: ->

      $(document).on 'click', (event, xhr) ->
        if ($(event.target).hasClass('entry-basement') || $(event.target).parents('.entry-basement').length > 0)
          false

        isButton = (event) ->
          $(event.target).is('[data-behavior~=show_entry_basement]') ||
          $(event.target).parents('[data-behavior~=show_entry_basement]').length > 0

        if !isButton(event) && $(event.target).parents('.entry-basement').length == 0
          feedbin.closeEntryBasement()
        return

      $(document).on 'click', '[data-behavior~=show_entry_basement]', (event, xhr) ->
        panelName = $(@).data('basement-panel')
        selectedPanel = $("[data-basement-panel-target=#{panelName}]")

        if $('.entry-basement').hasClass('open')
          if selectedPanel.hasClass('hide')
            # There is another panel open, transition to the clicked on panel
            feedbin.closeEntryBasement()
            feedbin.openEntryBasement(selectedPanel)
          else
            # The clicked on panel is alread open, close it
            feedbin.closeEntryBasement()
        else
          feedbin.openEntryBasement(selectedPanel)

        event.preventDefault()
        return

      $(document).on 'click', '[data-behavior~=close_entry_basement]', (event, xhr) ->
        feedbin.closeEntryBasement()
        event.preventDefault()
        return

      $(document).on 'submit', '.share-form form', (event, xhr) ->
        feedbin.closeEntryBasement()
        return

    supportedSharing: ->
      $(document).on 'click', '.button-toggle-share-menu [data-behavior~=show_entry_basement]', (event, xhr) ->
        panelName = $(@).data('basement-panel')
        selectedPanel = $("[data-basement-panel-target=#{panelName}]")
        $('form', selectedPanel).attr('action', $(@).attr('href'))

    formatToolbar: ->
      $('[data-behavior~=change_font]').val($("[data-font]").data('font'))
      $('[data-behavior~=change_font]').change ->
        fontContainer = $("[data-font]")
        currentFont = fontContainer.data('font')
        fontContainer.removeClass("font-#{currentFont}")
        fontContainer.addClass("font-#{$(@).val()}")
        fontContainer.data('font', $(@).val())
        $(@).parents('form').submit()

    feedSettings: ->
      $(document).on 'click', '[data-behavior~=sort_feeds]', (event, xhr) ->
        sortBy = $(@).data('value')
        label = $(@).text()
        $('[data-behavior~=sort_label]').text(label)
        if sortBy == "name"
          sortFunction = feedbin.sortByName
        else if sortBy == "last-updated"
          sortFunction = feedbin.sortByLastUpdated
        else if sortBy == "volume"
          sortFunction = feedbin.sortByVolume
        $('.sortable li').sort(sortFunction).appendTo('.sortable');
      return

    fontSize: ->
      $(document).on 'click', '[data-behavior~=increase_font]', (event) ->
        feedbin.updateFontSize('increase')
        return

      $(document).on 'click', '[data-behavior~=decrease_font]', (event) ->
        feedbin.updateFontSize('decrease')
        return

    entryWidth: ->
      $(document).on 'click', '[data-behavior~=entry_width]', (event) ->
        $('[data-behavior~=entry_content_target]').toggleClass('fluid')
        $('body').toggleClass('fluid')
        return

    fullscreen: ->
      $(document).on 'click', '[data-behavior~=full_screen]', (event) ->
        feedbin.toggleFullScreen()
        feedbin.closeEntryBasement()
        event.preventDefault()
        return

    showSearch: ->
      $(document).on 'click', '[data-behavior~=show_search]', (event) ->
        $('body').toggleClass('hide-search')
        event.preventDefault()
        return

    theme: ->
      $(document).on 'click', '[data-behavior~=switch_theme]', (event) ->
        theme = $(@).data('theme')
        $('[data-behavior~=class_target]').removeClass('theme-day')
        $('[data-behavior~=class_target]').removeClass('theme-sunset')
        $('[data-behavior~=class_target]').removeClass('theme-night')
        $('[data-behavior~=class_target]').addClass("theme-#{theme}")
        event.preventDefault()
        return

    filterList: ->
      feedbin.matchHeights($('.app-detail'))
      $(window).on 'resize', () ->
        feedbin.matchHeights($('.app-detail'))
        return

      $(document).on 'click', '[data-filter]', (event) ->
        $('[data-filter]').removeClass('active')
        $(@).addClass('active')

        filter = $(@).data('filter')
        if filter == 'all'
          $("[data-platforms]").removeClass('hide')
        else
          $("[data-behavior~=filter_target]").addClass('hide')
          $("[data-platforms~=#{filter}]").removeClass('hide')
        return

    showEntryActions: ->
      $(document).on 'click', '[data-behavior~=show_entry_actions]', (event) ->
        parent = $(@).parents('li')
        if parent.hasClass('show-actions')
          $('.entries li').removeClass('show-actions')
        else
          $('.entries li').removeClass('show-actions')
          parent.addClass('show-actions')
        event.preventDefault()
        event.stopPropagation()
        return

      $(document).on 'click', (event) ->
        $('.entries li').removeClass('show-actions')
        return

      $(document).on 'click', '[data-behavior~=show_entry_content]', (event) ->
        unless $(event.target).is('[data-behavior~=show_entry_actions]')
          $('.entries li').removeClass('show-actions')
        return

    markDirectionAsRead: ->
      $(document).on 'click', '[data-behavior~=mark_below_read], [data-behavior~=mark_above_read]', (event) ->
        data = feedbin.markReadData
        if data
          data['ids'] = $(@).parents('li').prevAll().map(() ->
            $(@).data('entry-id')
          ).get().join()

          if $(@).is('[data-behavior~=mark_below_read]')
            $(@).parents('li').nextAll().addClass('read')
            data['direction'] = 'below'
          else
            $(@).parents('li').prevAll().addClass('read')
            data['direction'] = 'above'

        $.post feedbin.data.mark_direction_as_read_entries, data
        return

    hideUpdates: ->
      $(document).on 'click', '[data-behavior~=hide_updates]', (event) ->
        container = $(@).parents('.diff-wrap')
        if feedbin.data.update_message_seen
          container.addClass('hide')
        else
          feedbin.data.update_message_seen = true
          container.find('.diff-wrap-text').text('To re-enable updates, go to Setting > Feeds.')
          setTimeout ( ->
            container.addClass('hide')
          ), 4000

    toggle: ->
      $(document).on 'click', '[data-toggle]', ->
        toggle = $(@).data('toggle')
        if toggle['class']
          $(@).toggleClass(toggle['class'])
        if toggle['title']
          if toggle['title'][0] == $(@).attr('title')
            title = toggle['title'][1]
          else
            title = toggle['title'][0]
          $(@).attr('title', title)

    feedsSearch: ->
      $(document).on 'submit', '[data-behavior~=feeds_search]', ->
        $('#add_form_modal .feed-search-results').hide()
        $('[data-behavior~=feeds_search_favicon_target]').html('')
        $('#add_form_modal .modal-dialog').removeClass('done');

    formProcessing: ->
      $(document).on 'submit', '[data-behavior~=subscription_form], [data-behavior~=search_form], [data-behavior~=feeds_search]', ->
        $(@).find('input').addClass('processing')
        return

      $(document).on 'ajax:complete', '[data-behavior~=subscription_form], [data-behavior~=search_form], [data-behavior~=feeds_search]', ->
        $(@).find('input').removeClass('processing')
        if feedbin.closeSubcription
          setTimeout ( ->
            feedbin.hideSubscribe()
          ), 600
          feedbin.closeSubcription = false
        return

    subscribe: ->
      $(document).on 'click', '[data-behavior~=show_subscribe]', ->
        modal = $('#add_form_modal')
        markup = $('[data-behavior~=add_form_markup]')
        modal.html(markup.html())
        feedbin.modal('#add_form_modal')

      $('#add_form_modal').on 'shown.bs.modal', () ->
        $('#add_form_modal [data-behavior~=feeds_search_field]').focus()

      $('#add_form_modal').on 'hide.bs.modal', () ->
        $('#add_form_modal input').blur()

      subscription = feedbin.queryString('subscribe')
      if subscription?
        $('[data-behavior~=show_subscribe]').click()
        field = $('#add_form_modal [data-behavior~=feeds_search_field]')
        field.val(subscription)
        field.closest("form").submit()

    searchError: ->
      $(document).on 'ajax:error', '[data-behavior~=search_form]', (event, xhr) ->
        feedbin.showNotification('Search error.', 3000, '', true);

        return

    savedSearch: ->
      $(document).on 'click', '[data-behavior~=save_search_link]', ->
        query = $('#query').val()
        $('#saved_search_query').val(query)
        $('.entries').toggleClass('show-saved-search')
        $('.saved-search-wrap').toggleClass('open')
        $('#saved_search_name').focus()
        return

      $(document).on 'click', '[data-behavior~=feed_link]:not(.saved-search-link)', ->
        $('#query').val('')

    showPushOptions: ->
      if "safari" of window and "pushNotification" of window.safari
        $('body').addClass('supports-push')
        if $('#push-data').length > 0
          $('.push-options').removeClass('hide')
          data = $('#push-data').data()
          permissionData = window.safari.pushNotification.permission(data.websiteId)
          feedbin.checkPushPermission(permissionData )

    enablePush: ->
      $(document).on 'click', '[data-behavior~=enable_push]', (event) ->
        data = $('#push-data').data()
        window.safari.pushNotification.requestPermission(data.webServiceUrl, data.websiteId, {authentication_token: data.authenticationToken}, feedbin.checkPushPermission)
        event.preventDefault()
        return

    deleteAssociatedRecord: ->
      $(document).on 'click', '.remove_fields', (event) ->
        $(@).parents('[data-behavior~=associated_record]').hide(200)

    editAction: ->
      $(document).on 'click', '[data-behavior~=edit_action]', (event) ->
        actionForm = $(@).parents('.action-form')
        editForm = actionForm.find('.action-edit-form')
        actionDescription = $(@).parents('.action-form').find('.action-description')
        if editForm.hasClass('hide')
          editForm.removeClass('hide')
          actionForm.addClass('selected')
          actionDescription.addClass('hide')
        else
          editForm.addClass('hide')
          actionForm.removeClass('selected')
          actionDescription.removeClass('hide')
        event.stopPropagation()
        event.preventDefault()
        return

    nextEntry: ->
      $(document).on 'click', '[data-behavior~=open_next_entry]', (event) ->
        next = feedbin.nextEntry()
        if next
          next.find('a').click()
        event.preventDefault()
        return

    viewLatest: ->
      $(document).on 'click', '.view-latest-link', ->
        $('.entries .selected a').click()
        return

    serviceOptions: ->
      $(document).on 'click', '[data-behavior~=show_service_options]', (event) ->
        height = $(@).parents('li').find('.service-options').outerHeight()
        $(@).parents('li').find('.service-options-wrap').addClass('open').css
          height: height
        $(@).parents('li').find('.show-service-options').addClass('hide')
        event.preventDefault()
        return

      $(document).on 'click', '[data-behavior~=hide_service_options]', (event) ->
        $(@).parents('li').find('.service-options-wrap').removeClass('open').css
          height: 0
        $(@).parents('li').find('.show-service-options').removeClass('hide')
        event.preventDefault()
        return

    drawBarCharts: ->
      $('[data-behavior~=line_graph]').each ()->
        feedbin.drawBarChart(@, $(@).data('values'))
      return

    selectText: ->
      $(document).on 'mouseup', '[data-behavior~=select_text]', (event) ->
        $(@).select()
        event.preventDefault()
      return

    fuzzyFilter: ->
      feeds = $('[data-sort-name]')
      $(document).on 'keyup', '[data-behavior~=feed_search]', ->
        suggestions = []
        query = $(@).val()
        if query.length < 1
          suggestions = feeds
        else
          $.each feeds, (i, feed) ->
            sortName = $(feed).data('sort-name')
            if feed && sortName && query && typeof(query) == "string" && typeof(sortName) == "string"
              feed.score = sortName.score(query)
            else
              feed.score = 0
            if feed.score > 0
              suggestions.push(feed);
          if suggestions.length > 0
            suggestions = _.sortBy suggestions, (suggestion) ->
              -(suggestion.score)
          else
            suggestions = ''
        $('[data-behavior~=search_results]').html(suggestions)
      return

    appearanceRadio: ->
      $('[data-behavior~=appearance_radio]').on 'change', (event) ->
        selected = $(@).val()
        setting = $(@).data('setting')
        name = $(@).attr('name')

        $("[name='#{name}']").each ->
          option = $(@).val()
          $('[data-behavior~=class_target]').removeClass("#{setting}-#{option}")

        $('[data-behavior~=class_target]').addClass("#{setting}-#{selected}")
        feedbin.previewHeight()

    appearanceCheckbox: ->
      $(document).on 'click', '[data-behavior~=appearance_checkbox]', (event) ->
        checked = if $(@).is(':checked') then '1' else '0'
        setting = $(@).data('setting')
        $('[data-behavior~=class_target]').removeClass("#{setting}-1")
        $('[data-behavior~=class_target]').removeClass("#{setting}-0")
        $('[data-behavior~=class_target]').addClass("#{setting}-#{checked}")
        feedbin.previewHeight()

    generalAutocomplete: ->
      $(document).on 'focus', '[data-behavior~=autocomplete_field]', (event) ->
        field = $(event.currentTarget)
        field.autocomplete
          serviceUrl: field.data('autocompletePath')
          appendTo: field.parent("[data-behavior~=autocomplete_parent]").find("[data-behavior=autocomplete_target]")
          delimiter: /(,)\s*/
          deferRequestBy: 50
          autoSelectFirst: true

    entriesMaxWidth: ->
      container = $('[data-behavior~=entries_max_width]')
      resize = ->
        windowWidth = $(window).width()
        if windowWidth < 528
          width = windowWidth - 100
        else if windowWidth < 1083
          width = windowWidth - 350
        $('.settings .entries-display-inline .entries').css({"max-width": "#{width}px"})
      if container
        throttledResize = _.throttle(resize, 50)
        $(window).on('resize', throttledResize);
        resize()


    minHeight: ->
      feedbin.previewHeight()

    scrollToFixed: ->
      unless 'ontouchstart' of document
        $('.preview-group').scrollToFixed()

    tumblrType: ->
      $(document).on 'change', '[data-behavior~=tumblr_type]', ->
        type = $(@).val()
        description = $(@).find("option:selected").data('description-name')
        typeText = $(@).find("option:selected").text()
        if type == 'quote'
          $('.share-form .source-placeholder').removeClass('hide')
          $('.share-form .title-placeholder').addClass('hide')
        else
          $('.share-form .source-placeholder').addClass('hide')
          $('.share-form .title-placeholder').removeClass('hide')

        $('.share-form .type-text').text(typeText)
        $('.share-form .description-placeholder').attr('placeholder', description)

    dragAndDrop: ->
      feedbin.droppable()
      feedbin.draggable()

    selectCategory: ->
      $(document).on 'click', '[data-behavior~=selected_category]', (event) ->
        $(@).find('[data-behavior~=categories]').toggleClass('hide')

    resizeGraph: ->
      if $("[data-behavior~=resize_graph]").length
        $(window).resize(_.debounce(->
          $('[data-behavior~=resize_graph]').each ()->
            feedbin.drawBarChart(@, $(@).data('values'))
        20))

    settingsCheckbox: ->
      $(document).on 'change', '[data-behavior~=auto_submit]', (event) ->
        $(@).parents("form").submit()

    submitAdd: ->
      $(document).on 'submit', '[data-behavior~=subscription_options]', (event) ->
        $('[data-behavior~=submit_add]').attr('disabled', 'disabled')

      $(document).on 'click', '[data-behavior~=submit_add]', (event) ->
        $("[data-behavior~=subscription_options]").submit()

    toggleContent: ->
      $(document).on 'click', '[data-behavior~=toggle_content_button]', (event) ->
        $(@).parents("form").submit()

    checkToggle: ->
      $(document).on 'change', '[data-behavior~=check_toggle]', (event) ->
        length = $('[data-behavior~=check_toggle]:checked').length
        if length == 0
          $('#add_form_modal [data-behavior~=submit_add]').attr('disabled', 'disabled')
        else
          $('#add_form_modal [data-behavior~=submit_add]').removeAttr('disabled', 'disabled')
        feedbin.updateFeedSearchMessage()

$.each feedbin.preInit, (i, item) ->
  item()

jQuery ->
  $.each feedbin.init, (i, item) ->
    item()
