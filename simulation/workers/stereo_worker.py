"""
computes disparity per frame
deterministic, stateless across restarts, long-running
"""

import sys
import json
import time
import cv2
import base64
import numpy as np

stereo = cv2.StereoSGBM_create(
    numDisparities=128,
    blockSize=1,  
)

def encode_image(img, scale=0.5, quality=70):
    """Encode image to base64 JPEG string with reduced size"""
    # Resize image to reduce payload size
    h, w = img.shape[:2]
    resized = cv2.resize(img, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)
    _, buffer = cv2.imencode('.jpg', resized, [cv2.IMWRITE_JPEG_QUALITY, quality])
    return base64.b64encode(buffer).decode('utf-8')

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

    # Create colorized disparity map for visualization
    disp_vis = cv2.normalize(disp_normalized, None, 0, 255, cv2.NORM_MINMAX, cv2.CV_8U)
    disp_colorized = cv2.applyColorMap(disp_vis, cv2.COLORMAP_JET)

    return {
        "latency_ms": latency_ms, #processing time of stereo matching algo for current frame pair
        "shape": list(disp.shape), #dimensions of disparity map
        "dtype": str(disp.dtype),  #data type of disparity array
        "mean_disparity": round(mean_disparity, 3),
        "valid_pixels": int(valid.sum()),
        # Base64 encoded images
        "left_img": encode_image(left),
        "right_img": encode_image(right),
        "disparity_img": encode_image(disp_colorized),
    }

for line in sys.stdin:
    req = json.loads(line)
    result = process(req["left"], req["right"])
    if result is None:
        result = {"error": "Failed to load images"}
    print(json.dumps(result))
    sys.stdout.flush()
