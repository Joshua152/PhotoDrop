# PhotoDrop API

PhotoDrop segments an object from one phone photo, then matches a second photo
of a computer display to a screenshot to estimate where the camera was pointing.
This documents the current implementation, including known client limitations.

## Request flow

1. The computer opens a WebSocket connection to `/computer`.
2. The phone sends the **object photo** and selection box to `POST /phone-clip`.
3. The phone takes a **second photo of the display**, aiming the photo's center
   at the desired destination, and sends it with the clip and a unique event ID
   to `POST /phone-upload`.
4. The API sends `{"message":"trigger","id":"<event-id>"}` as a JSON text
   message over the computer WebSocket.
5. The computer captures the photographed display and posts the screenshot with
   the same ID to `/computer-send`.
6. The computer receives the position and clip in the **HTTP response**, converts
   the position to its view coordinates, and renders the clip.

HTTP requests use JSON bodies (`Content-Type: application/json`). Image strings
are base64-encoded image bytes, without a `data:image/...;base64,` prefix.

## Endpoints

### `POST /phone-clip`

```json
{
  "phone_img": "<base64 object photo>",
  "bbox": "100 200 500 400"
}
```

`bbox` is four space-separated integers: **`x y width height`**, in pixels of the
decoded object photo. The origin is the top-left; x increases rightward and y
downward. The example selects a rectangle from `(100, 200)` to `(600, 600)`.
Use positive dimensions and keep the box within the image; these bounds are not
explicitly validated by the endpoint.

The segmenter retains model segments whose entire detected bounding boxes fit
inside the selection. It combines their masks and crops to the union of their
detected boxes. The result may include multiple objects and need not be a tight
crop around the nontransparent pixels.

Response:

```json
{
  "clip": "<base64 PNG with alpha>",
  "offset_x_percent": 0.1,
  "offset_y_percent": 0.2
}
```

Despite their names, offsets are **fractions, not percentages from 0 to 100**:

```text
offset_x_percent = crop_left / object_photo_width
offset_y_percent = crop_top  / object_photo_height
```

They locate the clip's **top-left in the full object photo**, not relative to the
selection box. They can reconstruct an overlay on that photo; they do not locate
the destination on the computer. Preview overlays must also account for scaling,
cropping, and rotation.

### `POST /phone-upload`

```json
{
  "id": "<unique-event-id>",
  "phone_img": "<base64 photo of the computer display>",
  "clip": "<base64 clip from /phone-clip>"
}
```

Stores the display photo and the unchanged clip string under `id`, then sends
the trigger if a computer socket is registered. Success returns HTTP `200` with
JSON `null`, not a placement result. There is no queued trigger delivery if no
socket is registered.

### `WS /computer`

Registers the desktop socket for trigger messages. Incoming text is accepted but
not processed. Submit screenshots over HTTP to `/computer-send`.

### `POST /computer-send`

```json
{
  "id": "<same-event-id>",
  "img": "<base64 screenshot of the photographed display>"
}
```

Response:

```json
{
  "x": 0.4,
  "y": 0.6,
  "clip": "<stored base64 clip>"
}
```

An unknown ID returns HTTP `400` with `{"detail":"Event ID not found"}`.

## Placement coordinates

`app/imgproc/detect.py` matches SIFT features from the **second phone photo** to
the screenshot and estimates a homography with RANSAC. It maps the photo center
into the screenshot:

```text
phone_center = (floor(phone_width / 2), floor(phone_height / 2))
[u, v, w] = H * [phone_center.x, phone_center.y, 1]
screenshot_x = int(u / w)
screenshot_y = int(v / w)
x = screenshot_x / screenshot_width
y = screenshot_y / screenshot_height
```

`H` maps **phone-photo pixels to screenshot pixels**. Projected coordinates are
truncated to integers before normalization.

| Property | Meaning |
| --- | --- |
| Origin | Top-left of the submitted screenshot |
| Positive x | Right |
| Positive y | Down |
| Units | Fractions of screenshot width and height |
| `(0.4, 0.6)` | 40% from the left, 60% from the top |
| Placement anchor | Projected center of the second phone photo |

The result is not clamped: an off-screen projection can be below 0 or above 1.
Coordinates are neither global desktop coordinates nor window coordinates. The
API does not return clip scale or rotation. The existing SwiftUI client uses
`.position(x:y:)`, placing the **center of the displayed clip** at the destination
with a fixed width of 150 points. The object photo's crop offsets are not used
for desktop placement.

### Converting to a macOS view

For a full-display screenshot, use the frame of the **same captured display** in
AppKit points, not screenshot pixels or `NSScreen.visibleFrame`. Normalization
allows Retina screenshot pixels to map to points without applying the pixel
scale again. Given that display's AppKit frame `D` (bottom-left origin):

```text
global_x = D.minX + x * D.width
global_y = D.maxY - y * D.height
```

Convert that global AppKit point into the actual destination view using the
window/view conversion APIs, accounting for whether the view is flipped. For a
view with a top-left origin and no additional transforms, whose global top-left
is `(view_left, view_top)`:

```text
view_x = global_x - view_left
view_y = view_top - global_y
```

For a cropped or letterboxed screenshot, first undo that mapping: the API's
coordinates always refer to the submitted image itself.

## Known limitations found during review

- **Mac display selection:** `Websocket.swift` still captures the display with
  the smallest display ID; there is no user-facing display picker. Photograph
  that display. Its full AppKit frame now travels with each screenshot request,
  and `PhotoSpaceViewModel.swift` converts through the actual canvas's window
  and view, accounting for display origins and window offsets. Clips are stored
  in canvas coordinates after placement, so they move with the window.
- **Android preview mapping:** selection conversion assumes the capture scales
  to preview height and the box is centered. Verify this against the preview's
  actual crop and aspect ratio. A pointing reticle must map to the center of
  the captured image, since that is the point the API projects.
- **Transparency:** the API returns a PNG clip, but Android's
  `CameraViewModel.bitmapToBase64` re-encodes it as JPEG before uploading it,
  losing alpha. Preserve PNG encoding when uploading the clip.
- **Failure handling:** insufficient features, poor matches, an invalid
  homography, and empty segmentation are not explicitly handled and can cause
  failures instead of structured results. Matching a planar display gives an
  estimate, not a guarantee of exact physical pointing accuracy.
- **Session lifecycle:** there is one global computer socket and a process-local
  in-memory event dictionary, with no pairing, authentication, expiration, or
  deletion after retrieval. Socket disconnect cleanup is not implemented, and
  multiple server workers do not share events or sockets.

The remaining limitations above require separate changes.
