# Initial App Idea

## Core

1. No content to be stored on the server.
2. Ephemeral sessions.
3. Identity = keys, not PII.
4. Metadata minimization.

## Architecture

1. Directory/Signaling Server.
2. TURN/STUN.
3. Clients.
4. Keys.
5. Session keys.

## User Flow

1. User enters username. If available, user can proceed to add device. Server creates a new account and generates a new device id signed by server's public key. This device id is used to identify the device and is used to authenticate the device. This is stored locally on the device. If the key is lost, the device is not able to authenticate and the account is lost.
2. To add another device to same account, user must use the first device to authenticate. An earlier logged in device is used to authenticate the new device or reauthenticate any device that has lost the device id.
3. Once a device is authenticated, the user can add friends. Friends can be saved with any nickname on the device.
4. There are three ways to add friends:
    1. Public: Any user can add you as a friend. You name can be searched in the public directory and will be shown as online if you are online. (Can add a feature to list all online public profiles.)
    2. Private: To add a friend, you must know thier username. You can search for username and if they are online, they will be sent a request. they must accept it while both of you are online. If they accept, both of you will be added as friends and the user-ids will be stored on device. Server does not know about any friends. When a new device is added, the friend list is sent to the new device using new device's public key as encryption key.
    3. Strict: To add a friend, you must know thier username and their friend verification code. You can search for username and if they are online, they will be sent a request. they must accept it while both of you are online.
5. Once a friend is added, both of you will be able to send messages to each other.
6. Friends can send each other files, images, and videos.
7. Messages can be sent only if both the users are online. If one of the users is offline, the message cannot be sent. The user must first send a request to the friend to wake them up. This will be shown as notification.
8. If a friend is removed, the user id will be saved on the device as unfriended so when they try to send a message in the future, their device will be notified to remove the friendship and disallow messaging.

## Design

1. Minimalistic design.
2. Dark/Light mode with only grayscale color scheme, no colors by default. Can allow the user to select a color as theme.
3. Slight animations, very subtle.
4. Multiple clients - web, mobile, desktop
5. All clients should have the same design.
6. Native clients would be more secure, if anyone is chatting with someone on web, the clients should show security banner.
