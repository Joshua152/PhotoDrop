import cv2
import numpy as np
from ultralytics import FastSAM, SAM

model = FastSAM("FastSAM-s.pt")
model.info()


def segment(img, bbox):
    """
    Segments the image and returns a cropped mask of the clip
    Parameters:
        img: numpy array from cv2.imread
        bbox: the bounding box the segments to keep
    Returns:
        A tuple containing a cropped mask and the offsets from the top left of the image to the top left of the cropped mask
    """

    # TODO: SWITCH TO GRABCUT?
    results = model.predict(img, show=False, save=True)

    h, w = img.shape[:2]
    b_mask = np.zeros((h, w), np.uint8)

    cx1, cy1, cx2, cy2 = w, h, 0, 0
    for r in results:
        for ci, c in enumerate(r):
            sx1, sy1, sx2, sy2 = c.boxes.xyxy.cpu().numpy().squeeze().astype(np.int32)
            if not in_bounds(bbox, (sx1, sy1, sx2, sy2)):
                continue

            contour = c.masks.xy.pop().astype(np.int32).reshape(-1, 1, 2)
            b_mask = cv2.drawContours(b_mask, [contour], -1, (255, 255, 255), cv2.FILLED)

            # Update crop
            cx1 = min(cx1, sx1)
            cx2 = max(cx2, sx2)
            cy1 = min(cy1, sy1)
            cy2 = max(cy2, sy2)

    b_mask = b_mask[cy1:cy2, cx1:cx2]
    cropped_img = np.copy(results[0].orig_img)[cy1:cy2, cx1:cx2]

    isolated = np.dstack([cropped_img, b_mask])

    return isolated, (cx1, cy1)


def in_bounds(bbox, bsegment):
    bbox_x1, bbox_y1, bbox_width, bbox_height = bbox
    bbox_x2, bbox_y2 = bbox_x1 + bbox_width, bbox_y1 + bbox_height

    segment_x1, segment_y1, segment_x2, segment_y2 = bsegment

    if (
            segment_x1 < bbox_x1 or
            segment_x2 > bbox_x2 or
            segment_y1 < bbox_y1 or
            segment_y2 > bbox_y2
    ):
        return False

    return True

