import cv2
import numpy as np

fn = "/Users/joshuaau/Dev/PhotoDrop/images/phone/segment/PXL_20241216_024108797.jpg"
image = cv2.imread(fn)

mask = np.zeros(image.shape[:2], dtype="uint8")
bbox = (900, 400, 2100, 3000)

fg_model = np.zeros((1, 65), dtype="float")
bg_model = np.zeros((1, 65), dtype="float")

mask, bg_model, fg_model = cv2.grabCut(image, mask, bbox, bg_model,
                                       fg_model, iterCount=10, mode=cv2.GC_INIT_WITH_RECT)

values = (
    ("Definite Background", cv2.GC_BGD),
    ("Probable Background", cv2.GC_PR_BGD),
    ("Definite Foreground", cv2.GC_FGD),
    ("Probable Foreground", cv2.GC_PR_FGD),
)
# loop over the possible GrabCut mask values
for (name, value) in values:
    # construct a mask that for the current value
    print("[INFO] showing mask for '{}'".format(name))
    valueMask = (mask == value).astype("uint8") * 255
    # display the mask so we can visualize it
    cv2.imshow(name, valueMask)
    cv2.waitKey(0)
