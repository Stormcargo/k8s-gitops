# Plex

## Claim
Don't use a claim token, instead log in using the UI.

- Port forward the plex service
- Log in to localhost:32400/web
- Follow setup and claim

## Transcoding
 Hardware acceleration using an Intel iGPU w/ QuickSync.
 These IDs below should be matched to your `video` and `render` group on the host
 To obtain those IDs run the following grep statement on the host:
  ```console
  $ cat /etc/group | grep "video\|render"
  video:x:44:
  render:x:109:
  ```
