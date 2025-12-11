--@SendChat
function sendChatMessage()
  local usernameElem = document.getElementById("username")
  local messageElem = document.getElementById("messageBox")

  local username = usernameElem.text
  local messageText = messageElem.text

  -- Validate inputs
  if not username or username == "" then
    document.setElementBodyById("statusLine", "Error: Please enter a username")
    return
  end

  if not messageText or messageText == "" then
    document.setElementBodyById("statusLine", "Error: Message cannot be empty")
    return
  end

  -- Update status
  document.setElementBodyById("statusLine", "Sending message...")

  -- Create message table in the format the server expects
  local chatMessage = {
    name = username,
    text = messageText
  }

  -- Send to ChatServer using sendByLookup
  local result = net.sendByLookup("ChatServer", chatMessage, "ChatServer")

  if result.sent > 0 then
    -- Update status
    local statusMsg = "Message sent successfully to " .. result.sent .. " server(s)"
    document.setElementBodyById("statusLine", statusMsg)

    -- Update history (show last message sent)
    local historyMsg = "<" .. username .. "> " .. messageText
    document.setElementBodyById("messageHistory", historyMsg)

    -- Clear the message box
    document.setElementBodyById("messageBox", "")
  else
    document.setElementBodyById("statusLine", "Error: ChatServer not found on network")
  end
end

--@ClearMessage
function clearMessageBox()
  document.setElementBodyById("messageBox", "")
  document.setElementBodyById("statusLine", "Message cleared")
end

--@onLoad
function initializeChat()
  document.setElementBodyById("statusLine", "Ready to send messages")
  document.setElementBodyById("messageHistory", "No messages sent yet")
end

