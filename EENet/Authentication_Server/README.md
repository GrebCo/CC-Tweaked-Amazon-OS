# OTP Authentication Server

A secure OTP (One-Time Password) authentication system for MiniMark/EENet using ComputerCraft and Advanced Peripherals.

## Features

- **OTP Generation**: 6-digit random codes
- **Chatbox Integration**: Sends OTP codes directly to players via DM
- **Session Management**: Tracks authenticated computers
- **Security**: 2-minute OTP expiration, single-use codes, computer ID verification
- **DNS Integration**: Registers as `auth_server` for easy client lookup

## Requirements

- ComputerCraft computer with:
  - Wireless modem
  - **ChatBox peripheral** (from Advanced Peripherals mod)
- EENet network infrastructure

## Installation

### Option 1: Direct Install (In-Game)

Run this command on your ComputerCraft computer:

```lua
wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/main/EENet/Authentication_Server/install.lua install.lua
```

Then run:
```lua
install
```

### Option 2: Manual Install

1. Copy `authServer.lua` and `startup.lua` to your computer
2. Attach a ChatBox peripheral
3. Run `authServer.lua` or reboot the computer

## How It Works

### Authentication Flow

1. **Request OTP**:
   - Client sends: `"request_otp:username"` to `auth_server` on protocol `"EEAuth"`
   - Server generates 6-digit code
   - Player receives chatbox DM: `"Your OTP code is: 123456 (expires in 2 minutes)"`
   - Server responds: `"OTP sent to <username>"`

2. **Verify OTP**:
   - Client sends: `"verify_otp:username:123456"` to `auth_server` on protocol `"EEAuth"`
   - Server validates code, computer ID, and expiration
   - On success: Creates session and responds `"authenticated"`
   - On failure: Responds `"invalid_otp"` or `"expired"`

3. **Check Session** (Optional):
   - Client sends: `"check_session"` to `auth_server` on protocol `"EEAuth"`
   - Server responds: `"authenticated:username"` or `"not_authenticated"`

## Client Usage Example

### MiniMark Page with Fizzle Script

```html
#Login to Server
<text:cyan>Enter your username to receive an OTP code

<textbox id:"username_input" width:"20">
<button label:"Request OTP" onClick:RequestOTP>

<id:"status">Status: Waiting...

<text:lime>Enter OTP Code (check your chat!)
<textbox id:"otp_input" width:"10">
<button label:"Login" onClick:VerifyOTP>

<script>
@onClick
function RequestOTP()
  local username = document.getElementById("username_input").text

  if username == "" then
    document.setElementBodyById("status", "Status: Please enter username")
    return
  end

  document.setElementBodyById("status", "Status: Requesting OTP...")

  local response = net.query("auth_server", "request_otp:" .. username, "EEAuth")
  document.setElementBodyById("status", "Status: " .. response)
end

@onClick
function VerifyOTP()
  local username = document.getElementById("username_input").text
  local otp = document.getElementById("otp_input").text

  if username == "" or otp == "" then
    document.setElementBodyById("status", "Status: Fill in all fields")
    return
  end

  document.setElementBodyById("status", "Status: Verifying...")

  local response = net.query("auth_server", "verify_otp:" .. username .. ":" .. otp, "EEAuth")

  if response == "authenticated" then
    document.setElementBodyById("status", "Status: Login successful!")
    -- Now authenticated, can access protected resources
  elseif response == "expired" then
    document.setElementBodyById("status", "Status: Code expired, request new one")
  else
    document.setElementBodyById("status", "Status: Invalid code, try again")
  end
end
</script>
```

### Lua Script Example

```lua
-- Request OTP
local net = require("OSUtil/ClientNetworkHandler")
net.init({})

local username = "Steve"
local response = net.query("auth_server", "request_otp:" .. username, "EEAuth")
print(response)  -- "OTP sent to Steve"

-- Player receives chatbox message and types code
print("Enter OTP code: ")
local otp = read()

-- Verify OTP
local verifyResponse = net.query("auth_server", "verify_otp:" .. username .. ":" .. otp, "EEAuth")
if verifyResponse == "authenticated" then
    print("Login successful!")
else
    print("Login failed: " .. verifyResponse)
end

-- Check session status later
local sessionResponse = net.query("auth_server", "check_session", "EEAuth")
print(sessionResponse)  -- "authenticated:Steve" or "not_authenticated"
```

## Protocol Reference

### Request Format

All requests use format: `"action:param1:param2"` separated by colons.

### Actions

#### 1. `request_otp:username`
- **Description**: Request OTP code for a user
- **Parameters**:
  - `username` - Minecraft username (must match in-game name for chatbox)
- **Response**: `"OTP sent to <username>"` or error
- **Side Effect**: Player receives chatbox DM with 6-digit code

#### 2. `verify_otp:username:code`
- **Description**: Verify OTP code and create session
- **Parameters**:
  - `username` - Username that requested OTP
  - `code` - 6-digit OTP code from chatbox
- **Response**:
  - `"authenticated"` - Success, session created
  - `"invalid_otp"` - Wrong code or computer ID mismatch
  - `"expired"` - Code older than 2 minutes
  - `"error:missing_username"` or `"error:missing_otp"` - Missing parameters

#### 3. `check_session`
- **Description**: Check if current computer has valid session
- **Parameters**: None (uses sender computer ID)
- **Response**:
  - `"authenticated:username"` - Session exists
  - `"not_authenticated"` - No session

## Security Features

1. **Computer ID Binding**: OTP can only be verified from the same computer that requested it
2. **Time-Limited**: OTPs expire after 2 minutes
3. **Single-Use**: OTP is deleted immediately after successful verification
4. **Automatic Cleanup**: Expired OTPs are removed periodically

## Server Administration

### View Server Status

The server logs all activity to the console:
- OTP requests with username and computer ID
- Authentication attempts (success/failure)
- Session checks
- Expired OTP cleanup

### Restart Server

```lua
reboot
```

The server will auto-start via `startup.lua`.

## Troubleshooting

### "No chatBox peripheral found!"
- Make sure a ChatBox from Advanced Peripherals is attached to the computer
- Use `peripheral list` to verify the chatbox is connected

### "No modem found!"
- Attach a wireless modem to the computer
- Make sure the modem is enabled

### Player doesn't receive OTP
- Verify the username exactly matches the Minecraft player name (case-sensitive)
- Check if the player is online
- Verify the chatbox is functioning: `peripheral.call("chatBox_0", "sendMessageToPlayer", "username", "test")`

### "invalid_otp" error
- Code may be expired (>2 minutes old)
- Code may have been typed incorrectly
- Different computer trying to verify (must be same computer that requested)

## Future Enhancements

- Session expiration after inactivity
- Rate limiting to prevent spam
- Admin commands (view/revoke sessions)
- Persistent sessions (survive server restarts)
- Multi-factor authentication options

## Protocol Details

- **Protocol Name**: `EEAuth`
- **DNS Hostname**: `auth_server`
- **Network**: EENet (ComputerCraft rednet)

## License

Part of the CC-Tweaked-Amazon-OS / EENet project.
