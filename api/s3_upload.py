"""Upload an image using a presigned S3 PUT URL. No AWS credentials needed."""

import argparse
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


IMAGE_PATH = "/Users/joshuaau/Downloads/IMG_2130.jpg"
# If the URL was signed with ContentType, set this to that exact value.
CONTENT_TYPE = 'image/jpg'  # For example: "image/png"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("url", help="Presigned S3 PUT upload URL (quote the full URL)")
    args = parser.parse_args()

    image_path = Path(IMAGE_PATH).expanduser()
    if not image_path.is_file():
        raise SystemExit(f"Image file not found: {image_path}")

    headers = {"Content-Type": CONTENT_TYPE} if CONTENT_TYPE else {}
    request = Request(
        args.url,
        data=image_path.read_bytes(),
        headers=headers,
        method="PUT",
    )
    try:
        with urlopen(request, timeout=120) as response:
            print(f"Uploaded {image_path.name} successfully (HTTP {response.status}).")
    except HTTPError as error:
        details = error.read().decode("utf-8", errors="replace")
        raise SystemExit(f"Upload failed (HTTP {error.code}):\n{details}") from None
    except URLError as error:
        raise SystemExit(f"Upload failed: {error.reason}") from None


if __name__ == "__main__":
    main()
