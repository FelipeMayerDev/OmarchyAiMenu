import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "OpenCodeEvent.js" as OpenCodeEvent

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property bool revealed: false
  property bool detached: false
  property bool settingsOpen: false
  property bool waiting: false
  property string sessionId: ""
  property int assistantIndex: -1
  property string error: ""
  property string harness: "opencode"
  property string model: "opencode/ling-3.0-flash-fin-free"
  property string effort: "default"
  property bool yolo: false
  property bool settingsLoaded: false
  property int contextUsed: 0
  property int contextLimit: 0
  property var harnesses: []
  property var models: []
  property var efforts: ["default"]
  property bool catalogLoading: false
  property string settingsError: ""
  property string pendingSelectCopy: ""

  property color background: Color.menu.background
  readonly property color solidBackground: Qt.rgba(background.r, background.g, background.b, 1)
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedBorder: Color.menu.selectedBorder
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property string fontFamily: Style.font.menuFamily
  property int margin: Style.spacing.panelPadding
  property int spacing: Style.spacing.md
  readonly property int cardWidth: Math.min(Style.space(720), panel.width - Style.gapsOut * 2)
  readonly property int cardHeight: settingsOpen
    ? Math.min(Style.space(430), panel.height - Style.gapsOut * 2)
    : messages.count === 0
      ? header.height + input.implicitHeight + margin * 2 + spacing
    : Math.min(Math.round(panel.height * 0.72), panel.height - Style.gapsOut * 2)

  function open(payloadJson) {
    var payload = {}
    hideTimer.stop()
    settingsOpen = payload.settings === true
    detectHarnesses()
    opened = true
    // Uma espera presa de um ciclo anterior não pode bloquear a sessão nova,
    // mas nunca derrube uma resposta em andamento.
    if (!process.running) waiting = false
    Qt.callLater(function() {
      revealed = true
      if (!settingsOpen) input.forceActiveFocus()
    })
  }

  function close() { dismiss() }

  function dismiss() {
    detached = false
    revealed = false
    hideTimer.restart()
  }

  function toggleWindow() {
    revealed = false
    detached = !detached
    Qt.callLater(function() {
      if (!detached) revealed = true
      input.forceActiveFocus()
    })
  }

  function toggleSettings() {
    settingsOpen = !settingsOpen
    if (settingsOpen) detectHarnesses()
    else Qt.callLater(function() { input.forceActiveFocus() })
  }

  function helper() {
    return Quickshell.env("HOME") + "/.config/omarchy/plugins/focky.ai-menu/bin/harness-info"
  }

  function detectHarnesses() {
    settingsError = ""
    detectProcess.command = [helper(), "detect"]
    detectProcess.running = true
  }

  function loadModels() {
    models = []
    efforts = ["default"]
    catalogLoading = true
    settingsError = ""
    catalogProcess.command = [helper(), "models", harness]
    catalogProcess.running = true
  }

  function selectHarness(value) {
    if (harness === value && models.length > 0) return
    harness = value
    model = ""
    effort = "default"
    sessionId = ""
    contextUsed = 0
    contextLimit = 0
    loadModels()
  }

  function selectModel(value) {
    model = value
    sessionId = ""
    for (var i = 0; i < models.length; i++) {
      if (models[i].value !== value) continue
      efforts = models[i].efforts || ["default"]
      effort = efforts.indexOf(effort) >= 0 ? effort : (models[i].defaultEffort || efforts[0])
      break
    }
  }

  function saveSettings() {
    if (!harness || !model || !effort) return
    saveProcess.command = [helper(), "save", harness, model, effort, root.yolo ? "on" : "off"]
    saveProcess.running = true
  }

  function harnessName() {
    for (var i = 0; i < harnesses.length; i++)
      if (harnesses[i].value === harness) return harnesses[i].label
    return harness
  }

  function debugState() {
    return JSON.stringify({ opened: opened, waiting: waiting, error: error,
                            visible: panel.visible, harness: harness, model: model,
                            models: models.length, session: sessionId })
  }

  function applyDetected(output) {
    try {
      var data = JSON.parse(String(output || "{}"))
      harnesses = data.harnesses || []
      var saved = data.settings || {}
      if (!settingsLoaded) {
        settingsLoaded = true
        harness = saved.harness || harness
        model = saved.model || model
        effort = saved.effort || effort
        yolo = saved.yolo === true
      }
      var available = false
      for (var i = 0; i < harnesses.length; i++) {
        if (harnesses[i].value === harness && harnesses[i].available) available = true
      }
      if (!available) {
        for (var j = 0; j < harnesses.length; j++) {
          if (harnesses[j].available) { harness = harnesses[j].value; model = ""; break }
        }
      }
      loadModels()
    } catch (e) {
      settingsError = "Could not detect AI harnesses."
    }
  }

  function applyCatalog(output) {
    catalogLoading = false
    try {
      var data = JSON.parse(String(output || "{}"))
      models = data.models || []
      settingsError = data.error || (models.length === 0 ? "No models found." : "")
      var selected = false
      for (var i = 0; i < models.length; i++)
        if (models[i].value === model) selected = true
      selectModel(selected ? model : (models.length > 0 ? models[0].value : ""))
    } catch (e) {
      settingsError = "Could not load models."
    }
  }

  function ask(question) {
    var text = String(question || "").trim()
    if (!text || waiting) return
    if (text.toLowerCase() === "/new") {
      messages.clear()
      sessionId = ""
      assistantIndex = -1
      error = ""
      input.text = ""
      return
    }
    messages.append({ speaker: "You", body: text, thinking: "" })
    messages.append({ speaker: "AI", body: "", thinking: "" })
    assistantIndex = messages.count - 1
    error = ""
    input.text = ""

    var prompt = "You are the Omarchy AI assistant with shell access to this machine. "
      + "If the request is an action (open an app, change a setting, install something), "
      + (root.yolo ? "perform it with tools now" : "say you need YOLO mode enabled to perform it")
      + " instead of explaining how. "
      + "Answer questions concisely in Markdown. Use fenced code blocks for code. "
      + "When useful, finish with 2-4 short suggested replies as Markdown links using choice: URLs, "
      + "for example [Yes](choice:Yes). Percent-encode spaces. "
      + (root.yolo ? "Tools are enabled. " : "Tools are disabled. ")
      + "Request: " + text
    process.command = [Quickshell.env("HOME") + "/.config/omarchy/plugins/focky.ai-menu/bin/ai-run",
      harness, model, effort, sessionId, root.yolo ? "on" : "off", prompt]
    waiting = true
    process.running = true
    timeout.restart()
    Qt.callLater(function() { list.positionViewAtEnd() })
  }

  function imageUrl(path) {
    var value = String(path || "")
    if (value.indexOf("file://") === 0) return value
    if (value.indexOf("~/") === 0) value = Quickshell.env("HOME") + value.substring(1)
    return "file://" + value
  }

  function consume(line) {
    var event = OpenCodeEvent.parse(line)
    if (assistantIndex < 0) return
    // The timeout is an idle limit: real output (thinking or text) renews it.
    if (event.thinking || event.text) timeout.restart()
    if (event.used) {
      contextUsed = event.used
      if (event.limit > 0) contextLimit = event.limit
      return
    }
    if (event.thinking) {
      var thought = messages.get(assistantIndex).thinking
      messages.setProperty(assistantIndex, "thinking", thought + event.thinking)
      Qt.callLater(function() { list.positionViewAtEnd() })
      return
    }
    if (!event.text) return
    var current = messages.get(assistantIndex).body
    messages.setProperty(assistantIndex, "body", current + event.text)
    Qt.callLater(function() { list.positionViewAtEnd() })
  }

  function activateLink(link) {
    var reply = OpenCodeEvent.choice(link)
    if (reply) ask(reply)
    else Qt.openUrlExternally(link)
  }

  function notify(answer) {
    var text = String(answer || "").trim()
    if (!text) return
    if (text.length > 280) text = text.substring(0, 280) + "…"
    Quickshell.execDetached(["notify-send", "-a", "AI Assistant", harnessName() + " · resposta pronta", text])
  }

  function copyText(text) {
    Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(text) + " | wl-copy"])
  }

  function scheduleSelectCopy(text) {
    pendingSelectCopy = String(text || "")
    if (pendingSelectCopy.length > 0) selectCopyTimer.restart()
  }

  function copyCode(text) { root.copyText(text) }
  function finish(exitCode) {
    if (!waiting) return
    waiting = false
    timeout.stop()
    if (exitCode !== 0) sessionId = ""
    if (assistantIndex >= 0 && messages.get(assistantIndex).body === "")
      messages.setProperty(assistantIndex, "body", exitCode === 124 ? harnessName() + " timed out." : harnessName() + " failed to answer.")
    error = exitCode === 124 ? harnessName() + " took longer than 60 seconds."
      : (exitCode === 0 ? "" : (process.stderrText || harnessName() + " exited with code " + exitCode))
    var answer = assistantIndex >= 0 ? messages.get(assistantIndex).body : ""
    assistantIndex = -1
    process.stderrText = ""
    if (opened) Qt.callLater(function() { input.forceActiveFocus(); list.positionViewAtEnd() })
    else notify(answer)
  }

  ListModel { id: messages }

  Process {
    id: detectProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyDetected(text)
    }
  }

  Process {
    id: catalogProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyCatalog(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) { root.catalogLoading = false; root.settingsError = "Could not load models." }
    }
  }

  Process { id: saveProcess }

  Process {
    id: process
    property string stderrText: ""
    stdout: SplitParser { onRead: function(line) { root.consume(line) } }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: process.stderrText = String(text || "").trim()
    }
    onExited: function(exitCode) { root.finish(exitCode) }
  }

  Timer {
    id: timeout
    interval: 60000
    onTriggered: {
      root.finish(124)
      process.running = false
    }
  }
  Timer {
    id: hideTimer
    interval: 260
    onTriggered: {
      root.opened = false
    }
  }
  Timer {
    id: selectCopyTimer
    interval: 220
    onTriggered: {
      if (Qt.mouseButtons.pressed) { selectCopyTimer.restart(); return }
      var text = root.pendingSelectCopy
      root.pendingSelectCopy = ""
      if (text !== "") root.copyText(text)
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened && !root.detached
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
      opacity: root.revealed ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    }
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      anchors.horizontalCenter: parent.horizontalCenter
      y: root.revealed ? Style.bar.sizeHorizontal + Style.gapsOut : -height - Style.gapsOut
      Behavior on y {
        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
      }
      radius: Style.cornerRadius
      color: root.background
      borderSpec: root.borderSpec
      padding: root.margin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: chat
        parent: root.detached ? windowHost : card
        anchors.fill: parent
        anchors.margins: root.margin

        Shortcut {
          sequence: "Ctrl+P"
          context: Qt.WindowShortcut
          onActivated: root.toggleWindow()
        }

        Item {
          id: header
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          height: Style.space(28)

          PanelActionButton {
            id: settingsButton
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰒓"
            tooltipText: root.settingsOpen ? "Back to chat" : "AI settings"
            foreground: root.foreground
            hoverColor: root.selectedBorder
            focusable: true
            onClicked: root.toggleSettings()
          }

          Text {
            anchors.left: settingsButton.right
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Style.spacing.sm
            text: root.settingsOpen ? "AI settings" : root.harnessName() + " · " + root.model
            color: root.foreground
            opacity: 0.55
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideMiddle
          }
        }

        TextField {
          id: input
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          visible: !root.settingsOpen
          foreground: root.foreground
          accent: root.selectedBorder
          background: Rectangle {
            color: root.background
            radius: Style.cornerRadius
          }
          placeholderText: root.waiting ? "" : "Ask " + root.harnessName() + "…"

          onAccepted: root.ask(text)
          readOnly: root.waiting
          Keys.onEscapePressed: function(event) { root.dismiss(); event.accepted = true }
        }

        Text {
          id: status
          anchors.left: parent.left
          anchors.right: usageLabel.visible ? usageLabel.left : parent.right
          anchors.rightMargin: Style.spacing.sm
          anchors.bottom: input.top
          anchors.bottomMargin: Style.spacing.xs
          visible: !root.settingsOpen && root.error !== ""
          text: root.error
          color: root.foreground
          opacity: 0.55
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }

        Text {
          id: usageLabel
          anchors.right: parent.right
          anchors.bottom: input.top
          anchors.bottomMargin: Style.spacing.xs
          visible: !root.settingsOpen && root.contextUsed > 0 && root.contextLimit > 0
          text: Math.round(root.contextUsed / root.contextLimit * 100) + "% · " +
                Math.round(root.contextUsed / 1000) + "k / " + Math.round(root.contextLimit / 1000) + "k"
          color: root.foreground
          opacity: 0.55
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        ListView {
          id: list
          visible: !root.settingsOpen && messages.count > 0
          anchors.top: header.bottom
          anchors.topMargin: root.spacing
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: status.visible ? status.top : input.top
          anchors.bottomMargin: root.spacing
          model: messages
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          delegate: Rectangle {
            id: bubble
            required property string speaker
            required property string body
            required property string thinking
            required property int index
            property var replyChoices: speaker === "AI" ? OpenCodeEvent.choices(body) : []
            readonly property bool pendingDots: speaker === "AI" && body === "" && root.waiting && index === messages.count - 1
            property real dotPulse: 1
            width: ListView.view.width
            height: messageColumn.implicitHeight + Style.spacing.md * 2
            radius: Style.cornerRadius
            color: speaker === "You" ? root.selectedBackground : "transparent"

            SequentialAnimation {
              running: bubble.pendingDots
              loops: Animation.Infinite
              alwaysRunToEnd: true
              NumberAnimation { target: bubble; property: "dotPulse"; to: 0.3; duration: 450; easing.type: Easing.InOutQuad }
              NumberAnimation { target: bubble; property: "dotPulse"; to: 1; duration: 450; easing.type: Easing.InOutQuad }
            }
            Column {
              id: messageColumn
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.spacing.md
              spacing: Style.spacing.sm

              Text {
                text: speaker
                color: root.foreground
                opacity: 0.55
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.weight: Font.DemiBold
              }

              TextEdit {
                id: thinkingText
                visible: speaker === "AI" && thinking !== ""
                width: parent.width
                height: contentHeight
                readOnly: true
                selectByMouse: true
                selectByKeyboard: false
                persistentSelection: true
                activeFocusOnPress: false
                cursorVisible: false
                textMargin: 0
                selectionColor: Style.selectionFillFor(root.foreground, root.selectedBorder)
                selectedTextColor: Style.selectionStateColor(root.foreground, root.selectedBorder)
                textFormat: TextEdit.PlainText
                text: thinking
                color: root.foreground
                opacity: 0.5 * thinkingPulse
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.italic: true
                wrapMode: TextEdit.Wrap
                property real thinkingPulse: 1
                onSelectedTextChanged: function() { root.scheduleSelectCopy(selectedText) }

                SequentialAnimation {
                  running: root.waiting && speaker === "AI"
                  loops: Animation.Infinite
                  alwaysRunToEnd: true
                  NumberAnimation { target: thinkingText; property: "thinkingPulse"; to: 0.35; duration: 600; easing.type: Easing.InOutQuad }
                  NumberAnimation { target: thinkingText; property: "thinkingPulse"; to: 1; duration: 600; easing.type: Easing.InOutQuad }
                }
              }

              Column {
                width: parent.width
                spacing: Style.spacing.sm

                Repeater {
                  model: speaker === "AI"
                    ? OpenCodeEvent.blocks(body)
                    : [{ kind: "markdown", text: body }]

                  delegate: Item {
                    required property var modelData
                    width: messageColumn.width
                    height: modelData.kind === "code" ? codeBox.implicitHeight
                      : modelData.kind === "image" ? imageWrap.height : prose.contentHeight

                    Item {
                      id: imageWrap
                      visible: modelData.kind === "image"
                      width: parent.width
                      height: visible && imageItem.status === Image.Ready
                        ? frame.height + Style.spacing.sm : 60

                      BorderSurface {
                        id: frame
                        anchors.centerIn: parent
                        width: imageItem.width + Style.spacing.md
                        height: imageItem.height + Style.spacing.md
                        color: root.selectedBackground
                        borderSpec: root.borderSpec
                        radius: Style.cornerRadius

                        Image {
                          id: imageItem
                          anchors.centerIn: parent
                          visible: modelData.kind === "image"
                          width: Math.min(imageWrap.width - Style.spacing.md,
                                          320 * implicitWidth / Math.max(implicitHeight, 1))
                          height: width * implicitHeight / Math.max(implicitWidth, 1)
                          source: modelData.kind === "image" ? root.imageUrl(modelData.path) : ""
                          fillMode: Image.PreserveAspectFit
                          asynchronous: true

                          MouseArea {
                            anchors.fill: parent
                            enabled: imageItem.status === Image.Ready
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Qt.openUrlExternally(root.imageUrl(modelData.path))
                          }
                        }
                      }
                    }

                    TextEdit {
                      id: prose
                      visible: modelData.kind !== "code"
                      width: parent.width
                      height: contentHeight
                      opacity: bubble.pendingDots ? 0.45 * bubble.dotPulse : 1
                      text: modelData.text || "…"
                      textFormat: speaker === "AI" ? TextEdit.MarkdownText : TextEdit.PlainText
                      color: root.foreground
                      readOnly: true
                      selectByMouse: true
                      selectByKeyboard: false
                      persistentSelection: true
                      activeFocusOnPress: false
                      cursorVisible: false
                      textMargin: 0
                      selectionColor: Style.selectionFillFor(root.foreground, root.selectedBorder)
                      selectedTextColor: Style.selectionStateColor(root.foreground, root.selectedBorder)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      wrapMode: TextEdit.Wrap
                      onSelectedTextChanged: function() { root.scheduleSelectCopy(selectedText) }
                      onLinkActivated: function(link) { root.activateLink(link) }
                    }

                    BorderSurface {
                      id: codeBox
                      visible: modelData.kind === "code"
                      width: parent.width
                      implicitHeight: codeColumn.implicitHeight + Style.spacing.md * 2
                      color: root.selectedBackground
                      borderSpec: root.borderSpec
                      radius: Style.cornerRadius

                      Column {
                        id: codeColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Style.spacing.md
                        spacing: Style.spacing.sm

                        Item {
                          width: parent.width
                          height: Math.max(language.implicitHeight, copyButton.implicitHeight)

                          Text {
                            id: language
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: String(modelData.language || "code").toUpperCase()
                            color: root.foreground
                            opacity: 0.55
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.weight: Font.DemiBold
                          }

                          Button {
                            id: copyButton
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Copy"
                            foreground: root.foreground
                            accent: root.selectedBorder
                            fontSize: Style.font.caption
                            onClicked: root.copyCode(modelData.text)
                          }
                        }

                        TextEdit {
                          width: parent.width
                          height: contentHeight
                          textFormat: TextEdit.PlainText
                          text: modelData.text
                          color: root.foreground
                          readOnly: true
                          selectByMouse: true
                          selectByKeyboard: false
                          persistentSelection: true
                          activeFocusOnPress: false
                          cursorVisible: false
                          textMargin: 0
                          font.family: Style.fontFamily
                          font.pixelSize: Style.font.bodySmall
                          wrapMode: TextEdit.WrapAnywhere
                          selectionColor: Style.selectionFillFor(root.foreground, root.selectedBorder)
                          selectedTextColor: Style.selectionStateColor(root.foreground, root.selectedBorder)
                          onSelectedTextChanged: function() { root.scheduleSelectCopy(selectedText) }
                        }
                      }
                    }
                  }
                }
              }

              Flow {
                width: parent.width
                spacing: Style.spacing.sm
                visible: replyChoices.length > 0

                Repeater {
                  model: replyChoices

                  delegate: Button {
                    required property var modelData
                    text: modelData.label
                    bordered: true
                    focusable: true
                    foreground: root.foreground
                    background: root.background
                    accent: root.selectedBorder
                    onClicked: root.ask(modelData.value)
                  }
                }
              }
            }
          }
        }

        Column {
          id: settingsView
          visible: root.settingsOpen
          anchors.top: header.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.topMargin: Style.spacing.md
          spacing: Style.spacing.lg

          Text {
            text: "Harness"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.weight: Font.DemiBold
          }

          Flow {
            width: parent.width
            spacing: Style.spacing.sm

            Repeater {
              model: root.harnesses

              delegate: Button {
                required property var modelData
                text: modelData.label
                selected: modelData.value === root.harness
                enabled: modelData.available
                bordered: true
                focusable: true
                foreground: root.foreground
                background: root.background
                accent: root.selectedBorder
                tooltipText: modelData.available ? "" : "Not installed"
                onClicked: root.selectHarness(modelData.value)
              }
            }
          }

          SearchableDropdown {
            width: parent.width
            label: "Model"
            value: root.model
            options: root.models
            enabled: !root.catalogLoading && root.models.length > 0
            placeholderText: root.catalogLoading ? "Loading models…" : "Search models…"
            emptyText: "No models"
            foreground: root.foreground
            background: root.background
            popupBorder: root.border
            accent: root.selectedBorder
            fontFamily: root.fontFamily
            onChanged: function(value) { root.selectModel(value) }
          }

          Column {
            width: parent.width
            spacing: Style.spacing.sm

            Text {
              text: "Effort"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.weight: Font.DemiBold
            }

            ButtonGroup {
              options: root.efforts
              value: root.effort
              foreground: root.foreground
              background: root.background
              accent: root.selectedBorder
              fontFamily: root.fontFamily
              onChanged: function(value) {
                root.effort = value
                root.sessionId = ""
              }
            }
          }

          Column {
            width: parent.width
            spacing: Style.spacing.sm

            Text {
              text: "Tools"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.weight: Font.DemiBold
            }

            Button {
              text: root.yolo ? "YOLO mode on" : "YOLO mode off"
              selected: root.yolo
              bordered: true
              focusable: true
              foreground: root.yolo ? Color.urgent : root.foreground
              background: root.background
              accent: root.selectedBorder
              tooltipText: "Let the assistant run commands without asking"
              onClicked: {
                root.yolo = !root.yolo
                root.sessionId = ""
              }
            }
          }

          Column {
            width: parent.width
            spacing: Style.spacing.sm

            Text {
              text: "Persist"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.weight: Font.DemiBold
            }

            Button {
              text: saveFlash.running ? "Saved" : "Save settings"
              enabled: root.harness !== "" && root.model !== ""
              selected: saveFlash.running
              bordered: true
              focusable: true
              foreground: root.foreground
              background: root.background
              accent: root.selectedBorder
              tooltipText: "Persist harness, model, effort, and YOLO mode"
              onClicked: {
                root.saveSettings()
                saveFlash.restart()
              }

              Timer {
                id: saveFlash
                interval: 1500
              }
            }
          }

          Text {
            visible: root.settingsError !== ""
            width: parent.width
            text: root.settingsError
            color: Color.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }

  FloatingWindow {
    id: window
    visible: root.opened && root.detached
    title: "Omarchy AI Assistant"
    color: root.solidBackground
    implicitWidth: Style.space(720)
    implicitHeight: Style.space(640)
    minimumSize: Qt.size(Style.space(420), Style.space(320))

    onVisibleChanged: {
      if (!visible && root.opened && root.detached) root.dismiss()
    }

    Item { id: windowHost; anchors.fill: parent }
  }
}
