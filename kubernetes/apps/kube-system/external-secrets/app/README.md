# SOPS Formatting notes

The value in the sops secret must be BASE64 encrypted.
The onepassword connect application is expecting a base64 value, so the value going in must be base64 encrypted once for stringdata: and twice for data: