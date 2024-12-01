from os import listdir
import cv2 as cv
import numpy as np
import random
import time
from imgproc import detect
'''
End goal: 
Input image from phone camera
Find where the phone was pointing in the mac

Assume phone cursor at center of phone

Pipeline:
Read images
Match keypoints
Find homography
Find center of phone image after applying homography -> [answer]
'''

def main():
    comp_img = cv.imread('../images/mac/mac2.png')

    folder_dir = '../images/phone/2'
    for filename in listdir(folder_dir):
        phone_img = cv.imread(f'{folder_dir}/{filename}')

        start = time.time()
        x, y = detect.find_center(phone_img, comp_img)
        end = time.time()
        print(f'{filename}: {end - start}')

        cv.waitKey(0)

    cv.waitKey(0)


if __name__ == "__main__":
    main()
