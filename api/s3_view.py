"""Download and display an image from an HTTP(S) S3 or presigned URL."""

import argparse
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import urlopen

import cv2
import numpy as np


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("url", help="S3 image download URL (quote the full URL)")
    args = parser.parse_args()
    if urlsplit(args.url).scheme not in {"http", "https"}:
        parser.error("Provide an HTTP(S) download URL, not an s3:// object path.")

    try:
        with urlopen(args.url, timeout=120) as response:
            image_bytes = response.read()
    except HTTPError as error:
        details = error.read().decode("utf-8", errors="replace")
        raise SystemExit(f"Download failed (HTTP {error.code}):\n{details}") from None
    except URLError as error:
        raise SystemExit(f"Download failed: {error.reason}") from None

    image = cv2.imdecode(np.frombuffer(image_bytes, dtype=np.uint8), cv2.IMREAD_UNCHANGED)
    if image is None:
        raise SystemExit("Downloaded content could not be decoded as an image.")

    # Composite transparent images over white so segmented clips display correctly.
    if image.ndim == 3 and image.shape[2] == 4:
        alpha = image[:, :, 3:4].astype(np.float32) / 255
        image = (image[:, :, :3] * alpha + 255 * (1 - alpha)).astype(np.uint8)

    window_name = "PhotoDrop S3 image"
    cv2.namedWindow(window_name, cv2.WINDOW_NORMAL)
    try:
        cv2.imshow(window_name, image)
        print("Press any key or close the window to exit.")
        while cv2.getWindowProperty(window_name, cv2.WND_PROP_VISIBLE) >= 1:
            if cv2.waitKey(100) >= 0:
                break
    finally:
        cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
