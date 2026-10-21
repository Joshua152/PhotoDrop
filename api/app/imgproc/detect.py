import cv2 as cv
import numpy as np


MAX_MATCH_DIMENSION = 1280


def _resize_for_matching(img):
    height, width = img.shape[:2]
    if max(height, width) <= MAX_MATCH_DIMENSION:
        return img

    scale = MAX_MATCH_DIMENSION / max(height, width)
    return cv.resize(
        img,
        (max(1, round(width * scale)), max(1, round(height * scale))),
        interpolation=cv.INTER_AREA,
    )


def find_center(phone_img, comp_img):
    original_phone_height, original_phone_width = phone_img.shape[:2]
    original_comp_height, original_comp_width = comp_img.shape[:2]
    phone_img = _resize_for_matching(phone_img)
    comp_img = _resize_for_matching(comp_img)
    _, kp_phone, des_phone = find_keypoints(phone_img)
    _, kp_comp, des_comp = find_keypoints(comp_img)

    # Matching
    FLANN_INDEX_KDTREE = 1
    index_params = dict(algorithm=FLANN_INDEX_KDTREE, trees=5)
    search_params = dict(checks=50)

    flann = cv.FlannBasedMatcher(index_params, search_params)
    matches = flann.knnMatch(des_phone, des_comp, k=2)

    good = []
    for m, n in matches:
        if m.distance < 0.75 * n.distance:
            good.append(m)

    dst, H, matches_mask = calculate_homography(kp_phone, kp_comp, good, phone_img)

    out_comp = comp_img.copy()
    # out_comp = cv.polylines(out_comp, [np.int32(dst)], True, 255, 3, cv.LINE_AA)

    # Map the original center into the resized phone image coordinates.
    phone_center = (
        (original_phone_width // 2) * phone_img.shape[1] / original_phone_width,
        (original_phone_height // 2) * phone_img.shape[0] / original_phone_height,
    )
    # out_phone = cv.circle(phone_img, phone_center, radius=20, color=(255, 255, 0), thickness=-1)

    comp_pt = H @ np.array([phone_center[0], phone_center[1], 1])
    x = int(comp_pt[0] / comp_pt[2])
    y = int(comp_pt[1] / comp_pt[2])
    out_comp = cv.circle(out_comp, (x, y), radius=20, color=(255, 255, 0), thickness=-1)

    # draw_params = dict(matchColor=(0, 255, 0),
    #                    singlePointColor=None,
    #                    matchesMask=matches_mask,
    #                    flags=2)

    # match_img = cv.drawMatches(out_phone, kp_phone, out_comp, kp_comp, good, None, **draw_params)
    # cv.imwrite("runs/match.jpg", match_img)

    # Use actual dimensions to account for rounding during resizing.
    x = int((comp_pt[0] / comp_pt[2]) * original_comp_width / comp_img.shape[1])
    y = int((comp_pt[1] / comp_pt[2]) * original_comp_height / comp_img.shape[0])
    return x, y


def find_keypoints(img):
    gray = cv.cvtColor(img, cv.COLOR_BGR2GRAY)
    sift = cv.SIFT_create()
    kp, des = sift.detectAndCompute(gray, None)

    out = np.zeros(img.shape, dtype="uint8")
    # out = cv.drawKeypoints(gray, kp, out, (0, 255, 0))

    return out, kp, des


def calculate_homography(kp1, kp2, good, img1):
    src_pts = np.float32([kp1[m.queryIdx].pt for m in good]).reshape(-1, 1, 2)
    dst_pts = np.float32([kp2[m.trainIdx].pt for m in good]).reshape(-1, 1, 2)

    H, mask = cv.findHomography(src_pts, dst_pts, cv.RANSAC, 5.0)
    matches_mask = mask.ravel().tolist()

    h, w, _ = img1.shape
    pts = np.float32([[0, 0], [0, h - 1], [w - 1, h - 1], [w - 1, 0]]).reshape(-1, 1, 2)
    dst = cv.perspectiveTransform(pts, H)

    return dst, H, matches_mask
