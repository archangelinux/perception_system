import sys
import json
import cv2 as cv
import numpy as np

left_path = sys.argv[1]
right_path = sys.argv[2]

imgL = cv.imread(left_path, 0)
imgR = cv.imread(right_path, 0)

stereo = cv.StereoBM_create(numDisparities=64, blockSize=15)
disparity = stereo.compute(imgL, imgR)

# output JSON for Elixir to read
result = {
    "mean": float(np.mean(disparity[disparity > 0])),
    "max": float(np.max(disparity))
}
print(json.dumps(result))