# Implementation details

## Backend

- "Push"ing a playlist's updates to Hub triggers an AWS Lambda instance that:
	1. Checks that the requesting device is actually an iOS device running Musubi using [App Attest](https://developer.apple.com/documentation/devicecheck/validating_apps_that_connect_to_your_server).
	2. Registers the Spotify user if not already. Registration involves:
		- Creating a DynamoDB table that...
	3. Triggers push notification to Musubi users subscribed to this playlist.

- "Subscribe" to a playlist

