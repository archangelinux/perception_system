"""
computes disparity per frame
deterministic, stateless across restarts, long-running
"""

import sys
import json
import time
import cv2

stereo = cv2.StereoSGBM_create(
    minDisparity=0,
    numDisparities=128,
    blockSize=5,
    P1=8 * 3 * 5**2,
    P2=32 * 3 * 5**2,
    mode=cv2.STEREO_SGBM_MODE_SGBM_3WAY,
)

def process(left_path, right_path):
    left = cv2.imread(left_path, cv2.IMREAD_GRAYSCALE)
    right = cv2.imread(right_path, cv2.IMREAD_GRAYSCALE)

    if left is None or right is None:
        return None

    t0 = time.time()
    disp = stereo.compute(left, right)
    latency_ms = (time.time() - t0) * 1000

    #normalize disparity (SGBM uses fixed-point: actual disparity = output / 16)
    disp_normalized = disp.astype('float32') / 16.0
    
    #calculate metrics on valid pixels (disparity > 0)
    valid = disp_normalized > 0
    mean_disparity = float(disp_normalized[valid].mean()) if valid.any() else 0.0

    return {
        "latency_ms": latency_ms, #processing time of stereo matching algo for current frame pair
        "shape": list(disp.shape), #dimensions of disparity map
        "dtype": str(disp.dtype),  #data type of disparity array
        "mean_disparity": round(mean_disparity, 3),
        "valid_pixels": int(valid.sum()),
    }

for line in sys.stdin:
    req = json.loads(line)
    result = process(req["left"], req["right"])
    if result is None:
        result = {"error": "Failed to load images"}
    print(json.dumps(result))
    sys.stdout.flush()
