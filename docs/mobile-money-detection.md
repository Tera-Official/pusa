## Android Mobile Money detection and saving reminders

Pusa's Android detection is opt-in and device-local.

### Signal sources
- Android notification access for MTN MoMo and Orange Money app notifications.
- Optional SMS inbox and sent-folder scan when Android grants READ_SMS and RECEIVE_SMS.
- Incoming SMS broadcasts can be parsed on-device when SMS detection is enabled.

Pusa extracts provider, direction, amount, optional reference, timestamp, source and a masked sender hint. Raw SMS and notification text are not uploaded to Supabase. SMS permissions are sensitive and may require Google Play policy review; approval is not guaranteed.

### Notifications
Incoming transaction signals trigger a local Android notification asking the user to review their allocation plan. A single follow-up reminder is scheduled after one hour. A detected outgoing transaction prompts a savings-plan review. These are local Android notifications, not Firebase Cloud Messaging remote push. Remote FCM requires Firebase app registration, google-services.json, token registration and server-side delivery, which are not configured yet.

### Financial safety
Detection is not payment verification and never credits Pusa balances or writes ledger entries. Pusa cannot identify which exact receipt is being spent when funds are mixed in a Mobile Money balance. No PIN, USSD session or payment credential is read.